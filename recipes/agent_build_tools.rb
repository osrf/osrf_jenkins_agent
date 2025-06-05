# Set of tools for the buildfarm Linux Build Agents

linux_username = node['osrfbuild']['agent']['linux_username']

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

apt_repository "nvidia-container-toolkit" do
  uri 'https://nvidia.github.io/libnvidia-container/stable/deb/$(ARCH)'
  distribution '/'
  key ['https://nvidia.github.io/libnvidia-container/gpgkey']
  action :add
  only_if { has_nvidia_support? }
end

package 'nvidia-container-toolkit' do
  only_if { has_nvidia_support? }
end

execute 'Configure nvidia-container-toolkit' do
  command 'nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker'
end

if has_nvidia_support? and nvidia_devices.size != 1
  Chef::Log.warn("There are multiple nvidia devices and I am only looking at the first!")
end
nvidia_device = if has_nvidia_support?
                  nvidia_devices.first['device']
                else
                  nil
                end

nvidia_driver = case nvidia_device
                when /GTX 550/
                  # Old optimus machine in OSRF office
                  'nvidia-384'
                when /GRID K520/
                  # AWS g2 instances
                  'nvidia-384'
                when /Tesla M60/
                  # AWS g3 instances
                  'nvidia-driver-470'
                when /Tesla T4/
                  # AWS g4dn instances
                  'nvidia-driver-470'
                when /Device 2237/
                  # AWS g5 instances
                  'nvidia-driver-470'
                when nil
                  # it doesn't really matter which driver we use
                  # if there is no nvidia device but specify
                  # one to avoid a warning.
                  'nvidia-driver-470'
                else
                  Chef::Log.warn("Untested GPU `#{nvidia_devices.first['device']}` being used. Assuming a functioning driver")
                  'nvidia-driver-470'
                end

package nvidia_driver do
  only_if { has_nvidia_support? }
end

package 'mesa-utils' do
  only_if { has_nvidia_support? }
end

cookbook_file '/etc/modprobe.d/blacklist-nvidia-nouveau.conf' do
  source 'blacklist-nvidia-nouveau.conf'
  mode '0744'
  only_if { has_nvidia_support? }
end

cookbook_file '/etc/X11/xorg.conf' do
  source 'xorg.conf.no_gpu'
  mode "0744"
  not_if { has_nvidia_support? }
end
# Detecting AWS GRID cards that needs special configuration
cookbook_file '/etc/X11/xorg.conf' do
  source 'xorg.conf.nvidia_aws'
  mode "0744"
  only_if { has_nvidia_grid_support? }
end
# Other NVIDIA cards use generic configuration
cookbook_file '/etc/X11/xorg.conf' do
  source 'xorg.conf.nvidia'
  mode "0744"
  only_if { has_nvidia_support? }
  not_if { has_nvidia_grid_support? }
end
# TODO: assuming :0 here is fragile
ENV['DISPLAY'] = ':0'

# lightdm seems to need unity-greeter and remove ubuntu-session to work out-of-the-box
# see: https://github.com/osrf/osrf_jenkins_agent/issues/25
package 'unity-greeter' do
  only_if { has_nvidia_support? }
end
package 'ubuntu-session' do
  only_if { has_nvidia_support? }
  action :purge
end

# Breaking X loading on AWS
package 'pulseaudio-module-bluetooth' do
  only_if { has_nvidia_support? }
  action :purge
end

package "lightdm"
cookbook_file "/etc/lightdm/xhost.sh" do
  source "lightdm/xhost.sh"
  mode "0744"
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

