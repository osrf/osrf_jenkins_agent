# Instance store of the AWS agents at /srv/ccache, for the compiler cache that
# the Linux CI builds of release-tools share between them. release-tools uses
# the shared cache only when /srv/ccache is a mount point, and takes its size
# from CCACHE_MAXSIZE in the agent environment (jenkins-agent.env.erb).
#
# A systemd unit sets it up at every boot, never fstab: the instance store
# comes back empty after a stop, and not every instance type has one.

linux_username = node['osrfbuild']['agent']['linux_username']

cookbook_file '/usr/local/sbin/osrf-ccache-volume' do
  source 'ccache/osrf-ccache-volume'
  owner 'root'
  group 'root'
  mode '0755'
end

systemd_unit 'osrf-ccache-volume.service' do
  content <<~UNIT
    [Unit]
    Description=Instance store at /srv/ccache for the compiler cache of the CI builds
    Before=docker.service jenkins-agent.service

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=/usr/local/sbin/osrf-ccache-volume #{linux_username}

    [Install]
    WantedBy=multi-user.target
  UNIT
  action ['test'].include?(node.chef_environment) ? [:create, :enable] : [:create, :enable, :start]
end
