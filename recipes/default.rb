#
# Cookbook:: osrf_jenkins_agent
# Recipe:: default
#
# Copyright:: 2020, Open Source Robotics Foundation.
#

agent_username = node['osrfbuild']['agent']['agent_username']
agent_homedir = "/home/#{agent_username}"

apt_update "default" do
  action :periodic
  frequency 3600
end

# Install docker from docker servers to get latest version supporting nvidia
# toolkit (at least 19.03)
docker_installation_package 'default' do
  version '20.10.2'
  action :create
end
%w[
  default-jre-headless
  gnupg2
  groovy
  libffi-dev
  libssl-dev
  mercurial
  ntp
  openjdk-8-jdk-headless
  pciutils
  qemu-user-static
  sudo
  x11-xserver-utils
  wget
].each do |pkg|
  package pkg
end

apt_repository 'nvidia-docker' do
  uri 'https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list'
  key ['https://nvidia.github.io/nvidia-docker/gpgkey']
  action :add
  only_if { has_nvidia_support? }
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

user agent_username  do
  shell "/bin/bash"
  manage_home true
end
sudo agent_username do
  user agent_username
  nopasswd true
end

# Add agent user to the docker group to allow them to build and run docker
# containers.
group 'docker' do
  append true
  members agent_username
  action :manage # Group should be created by docker package.
end


# TODO: how to read attributes from chef-osrf plugins into this cookbook
# swarm_client_version = node['jenkins-plugins']['swarm']
swarm_client_version = "3.24"
swarm_client_url = "https://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/#{swarm_client_version}/swarm-client-#{swarm_client_version}.jar"
swarm_client_jarfile_path = "/home/#{agent_username}/swarm-client-#{swarm_client_version}.jar"

# Download swarm client program from url and install it to the jenkins-agent user's home directory.
remote_file swarm_client_jarfile_path do
  source swarm_client_url
  owner agent_username
  group agent_username
  mode '0444'
end

# Compose node name. Use ip if hostname is localhost otherwise use localhost
# value. Add nv intermediate word if gpu is present
jenkins_username = node['osrfbuild']['agent']['username']
node_make_jobs = 3 # TODO: find a better way of handling make_jobs
node_base_name = node['hostname'] == 'localhost' ? node['ipaddress'] : node['hostname']
node_labels = node['osrfbuild']['agent']['labels']
node_name = "linux-#{node_base_name}.focal"

ruby_block 'set node name' do
  block do
    node_name = "linux-#{node_base_name}.nv.focal"
    # TODO: do not assume nvidia machines are powerful
    labels.join(["gpu-reliable", "gpu-nvidia", "large-memory", "large-disk"])
    node_make_jobs = 5
  end
  only_if { has_nvidia_support? }
end

agent_jenkins_user = search('osrfbuild_jenkins_users', "username:#{jenkins_username}").first
template '/etc/default/jenkins-agent' do
  source 'jenkins-agent.env.erb'
  variables Hash[
    java_args: node['osrfbuild']['agent']['java_args'],
    jarfile: swarm_client_jarfile_path,
    jenkins_url: node['osrfbuild']['agent']['jenkins_url'],
    username: jenkins_username,
    name: node_name,
    description: node['osrfbuild']['agent']['description'],
    executors: node['osrfbuild']['agent']['executors'],
    user_home: agent_homedir,
    labels: node_labels,
    make_jobs: node_make_jobs,
  ]
  notifies :restart, 'service[jenkins-agent]'
end

directory '/etc/jenkins-agent'
file '/etc/jenkins-agent/token' do
  content agent_jenkins_user['password']
  mode '0640'
  owner 'root'
  group agent_username
end

template '/etc/systemd/system/jenkins-agent.service' do
  source 'jenkins-agent.service.erb'
  variables Hash[
    service_name: 'jenkins-agent',
    username: agent_username,
  ]
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
  notifies :restart, 'service[jenkins-agent]'
end

execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

service 'jenkins-agent' do
  action [:start, :enable]
  # can not connect to server while testing
  not_if { node.chef_environment == "test" }
end
