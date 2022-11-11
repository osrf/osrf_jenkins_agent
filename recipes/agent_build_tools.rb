# Set of tools for the buildfarm Linux Build Agents

linux_username = node['osrfbuild']['agent']['linux_username']

# Problems with seccomp policy and Ubuntu Jammy images require at least version 20.10.12
# More info at: https://github.com/ignition-tooling/release-tools/issues/654#issue-1162900579
docker_installation_package 'default' do
  version '20.10.12'
  action :create
end

# Add agent user to the docker group to allow them to build and run docker
# containers.
group 'docker' do
  append true
  members linux_username
  action :manage # Group should be created by docker package.
end

%w[
  gnupg2
  groovy
  libffi-dev
  libssl-dev
  mercurial
  ntp
  pciutils
  qemu-user-static
  sudo
  x11-xserver-utils
  wget
].each do |pkg|
  package pkg
end

# Focal uses 18.04 repository
for repo_uri in ['https://nvidia.github.io/libnvidia-container/stable/ubuntu18.04/$(ARCH)',
                'https://nvidia.github.io/nvidia-container-runtime/stable/ubuntu18.04/$(ARCH)',
                'https://nvidia.github.io/nvidia-docker/ubuntu18.04/$(ARCH)'] do
  apt_repository "nvidia-docker#{repo_uri.hash}" do
    uri repo_uri
    distribution '/'
    key ['https://nvidia.github.io/nvidia-docker/gpgkey']
    action :add
    only_if { has_nvidia_support? }
  end
end

# install nvidia-docker2 is recommended although real support is via
# container-toolkit
package "nvidia-docker2" do
  only_if { has_nvidia_support? }
end

# GeForce GTX 550 Ti requires old 3xx.xx series
package 'nvidia-384' do
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

# gdm3 systemctl delete the display-manager systemctl when disabled
# be sure of installing lightdm after this and not before
service "gdm3" do
  action [:start, :disable]
  only_if { node['packages'].keys.include? "gdm3" }
  only_if { has_nvidia_support? }
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

# set lightdm as the display manager requires 3 commands
execute 'set-lightdm-display-manager debconf' do
  command 'echo set shared/default-x-display-manager lightdm | debconf-communicate'
  not_if 'grep lightdm /etc/X11/default-display-manager'
end
execute 'reconfigure-gdm3' do
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

