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
  execute 'install-nvidia-535-server' do
    command 'apt-get install -y --no-install-recommends nvidia-driver-535-server'
    only_if { has_nvidia_support? }
    not_if "dpkg-query -W -f='${Status}' nvidia-driver-535-server 2>/dev/null | grep -q '^install ok installed$'"
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

