# Compiler cache of the Linux CI builds of release-tools (sccache).
#
# - The pinned static sccache release, at /usr/local/bin/sccache. release-tools
#   mounts it read-only into the containers of the builds that use the cache:
#   the sccache server runs the compiler, so it runs inside the container.
# - The AWS instance store at /srv/sccache. release-tools uses the shared cache
#   only when /srv/sccache is a mount point, and keeps its own layout inside.
#   A systemd unit sets it up at every boot, never fstab: the instance store
#   comes back empty after a stop, and not every instance type has one.

sccache = node['osrfbuild']['agent']['sccache']
linux_username = node['osrfbuild']['agent']['linux_username']
arch = node['kernel']['machine']
tarball_sha256 = sccache['checksums'][arch]

if tarball_sha256.nil?
  log "sccache: no release checksum for #{arch}, not installing it" do
    level :warn
  end
else
  release = "sccache-v#{sccache['version']}-#{arch}-unknown-linux-musl"
  tarball = ::File.join(Chef::Config[:file_cache_path], "#{release}.tar.gz")
  install_dir = "/opt/sccache/#{sccache['version']}"

  remote_file tarball do
    source "https://github.com/mozilla/sccache/releases/download/v#{sccache['version']}/#{release}.tar.gz"
    checksum tarball_sha256
  end

  directory install_dir do
    recursive true
  end

  # --no-same-owner: the release tarball stores uid 1001, which can be a real
  # user on the agent, and the binary ends up in the build containers
  execute "extract #{release}" do
    command "tar -xzf #{tarball} -C #{install_dir} --no-same-owner"
    creates "#{install_dir}/#{release}/sccache"
  end

  link '/usr/local/bin/sccache' do
    to "#{install_dir}/#{release}/sccache"
  end
end

cookbook_file '/usr/local/sbin/osrf-sccache-volume' do
  source 'sccache/osrf-sccache-volume'
  owner 'root'
  group 'root'
  mode '0755'
end

systemd_unit 'osrf-sccache-volume.service' do
  content <<~UNIT
    [Unit]
    Description=Instance store at /srv/sccache for the compiler cache of the CI builds
    Before=docker.service jenkins-agent.service

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=/usr/local/sbin/osrf-sccache-volume #{linux_username}

    [Install]
    WantedBy=multi-user.target
  UNIT
  action ['test'].include?(node.chef_environment) ? [:create, :enable] : [:create, :enable, :start]
end
