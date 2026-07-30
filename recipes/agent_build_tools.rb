# Set of tools for the buildfarm Linux Build Agents

linux_username = node['osrfbuild']['agent']['linux_username']

service 'accounts-daemon' do
  action :nothing
end

package 'docker.io'

# Add agent user to the docker group to allow them to build and run docker
# containers.
group 'docker' do
  append true
  members linux_username
  action :manage # Group should be created by docker package.
end

# NOTE: python 2 packages were used in the original release-tools code
# kept for transitioning and added the corresponding python3 packages
%w[
  bc
  git
  gnupg2
  gpgv
  groovy
  libffi-dev
  libssl-dev
  mercurial
  ntp
  pciutils
  python3-empy
  python3-psutil
  python3-setuptools
  qemu-user-static
  squid-deb-proxy
  sudo
  ubuntu-drivers-common
  wget
  x11-xserver-utils
].each do |pkg|
  package pkg
end

# Keep unattended-upgrades away from packages that cannot be swapped under a
# running agent. Dropped as a separate file in apt.conf.d so the distribution
# 50unattended-upgrades keeps providing the rest of the policy.
template '/etc/apt/apt.conf.d/51unattended-upgrades-osrf' do
  source '51unattended-upgrades-osrf.erb'
  mode '0644'
  owner 'root'
  group 'root'
  variables(
    blacklist: node['osrfbuild']['agent']['unattended_upgrades']['package_blacklist']
  )
end

if has_nvidia_support?
  apt_repository "nvidia-container-toolkit" do
    uri 'https://nvidia.github.io/libnvidia-container/stable/deb/$(ARCH)'
    distribution '/'
    key ['https://nvidia.github.io/libnvidia-container/gpgkey']
    action :add
  end

  package 'nvidia-container-toolkit'

  execute 'Configure nvidia-container-toolkit' do
    command 'nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker'
  end

  Chef::Log.warn("There are multiple nvidia devices and I am only looking at the first!") if nvidia_devices.size != 1

  package 'ubuntu-drivers-common' do
    only_if { has_nvidia_support? }
  end

  # Use the 535-server LTSB branch. Newer branches (>= 580) reference a
  # kernel symbol (drm_fbdev_ttm_driver_fbdev_probe) that linux-image-aws
  # 6.17 does not export, so nvidia-drm.ko fails to load and X falls back
  # to software rendering. 535 is the latest branch whose module loads
  # cleanly on the current Noble aws kernel.
  nvidia_driver_package = 'nvidia-driver-535-server'

  execute "install-#{nvidia_driver_package}" do
    command "apt-get install -y --no-install-recommends #{nvidia_driver_package}"
    only_if { has_nvidia_support? }
    not_if "dpkg-query -W -f='${Status}' #{nvidia_driver_package} 2>/dev/null | grep -q '^install ok installed$'"
  end

  # Freeze the nvidia packages so they are never upgraded behind the nvidia.ko
  # that is already loaded. When that happens the agent keeps looking healthy
  # to lspci while every GPU job fails at container start with
  #   failed to initialize NVML: Driver/library version mismatch
  # and it stays that way until the machine is rebooted.
  #
  # Hold the installed packages rather than just the metapackage: on noble
  # nvidia-driver-535-server is a transitional package whose dependency on
  # nvidia-driver-580-server carries no version, so holding it alone would not
  # keep the components still.
  #
  # This complements the unattended-upgrades blacklist above, which only covers
  # the automatic path. Upgrading the driver is a deliberate operation:
  # apt-mark unhold, converge, reboot.
  #
  # Shell snippet listing the installed nvidia packages that are not held yet.
  # It is used both as the guard and as the input of the hold, so the resource
  # only runs when there is something left to freeze.
  nvidia_packages_to_hold = <<~'CMD'.strip
    held=$(apt-mark showhold);
    dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'nvidia-*' 'libnvidia-*' 2>/dev/null |
      awk '$1 ~ /^ii/ { print $2 }' | sort -u |
      while read -r pkg; do echo "$held" | grep -qx "$pkg" || echo "$pkg"; done
  CMD

  execute 'hold-nvidia-packages' do
    command "#{nvidia_packages_to_hold} | xargs -r apt-mark hold"
    only_if { has_nvidia_support? }
    not_if %(test -z "$(#{nvidia_packages_to_hold})")
  end


  package 'mesa-utils'

  cookbook_file '/etc/modprobe.d/blacklist-nvidia-nouveau.conf' do
    source 'blacklist-nvidia-nouveau.conf'
    mode '0744'
  end

  cookbook_file '/etc/X11/xorg.conf' do
    source 'xorg.conf.no_gpu'
    mode "0744"
  end

  cookbook_file '/etc/X11/xorg.conf' do
    source 'xorg.conf.nvidia'
    mode "0744"
  end
end


# TODO: assuming :0 here is fragile
ENV['DISPLAY'] = ':0'

if has_nvidia_support?
  # lightdm seems to need unity-greeter and remove ubuntu-session to work out-of-the-box
  # see: https://github.com/osrf/osrf_jenkins_agent/issues/25
  package 'unity-greeter' do
    options '--no-install-recommends'
  end
  package 'ubuntu-session' do
    action :purge
  end
end


package "lightdm"
cookbook_file "/etc/lightdm/xhost.sh" do
  source "lightdm/xhost.sh"
  mode "0744"
  notifies :restart, "service[accounts-daemon]", :delayed # Needs a restart before lightdm
  notifies :restart, "service[lightdm]", :delayed
end
cookbook_file "/etc/lightdm/lightdm.conf" do
  source "lightdm/lightdm.conf"
  action :create_if_missing
end
ruby_block "Ensure display-setup-script" do
  block do
    lightdm_conf = Chef::Util::FileEdit.new("/etc/lightdm/lightdm.conf")
    lightdm_conf.search_file_replace_line %r{^display-setup-script=.*},
      "display-setup-script=/etc/lightdm/xhost.sh"
    lightdm_conf.insert_line_if_no_match %r{^display-setup-script=.*},
      "display-setup-script=/etc/lightdm/xhost.sh"
    lightdm_conf.write_file if lightdm_conf.unwritten_changes?
  end
end

# gdm3 will conflict with lightdm and make it not to start
package 'gdm3' do
  only_if { has_nvidia_support? }
  action :purge
end

# set lightdm as the display manager requires 3 commands
execute 'set-lightdm-display-manager debconf' do
  command 'echo set shared/default-x-display-manager lightdm | debconf-communicate'
  not_if 'grep lightdm /etc/X11/default-display-manager'
end
execute 'reconfigure-lightdm' do
  command 'dpkg-reconfigure lightdm'
  environment ({'DEBIAN_FRONTEND' => 'noninteractive', 'DEBCONF_NONINTERACTIVE_SEEN' => 'true'})
  not_if 'grep lightdm /etc/X11/default-display-manager'
end
execute 'set-lightdm-display-manager-etc' do
  command 'echo "/usr/sbin/lightdm" > /etc/X11/default-display-manager'
  not_if 'grep lightdm /etc/X11/default-display-manager'
end
service "lightdm" do
  action [:start, :enable]
end


package "squid-deb-proxy"
directory "/etc/squid-deb-proxy/mirror-dstdomain.acl.d" do
  recursive true
end
%w[11-ubuntuppa 12-osrfoundation 13-debian].each do |conf|
  cookbook_file "/etc/squid-deb-proxy/mirror-dstdomain.acl.d/#{conf}" do
    source "squid-deb-proxy/mirror-dstdomain.acl.d/#{conf}"
    notifies :restart, "service[squid-deb-proxy]", :delayed
  end
end
service "squid-deb-proxy" do
  action [:start, :enable]
end

