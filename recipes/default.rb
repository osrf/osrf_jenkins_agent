#
# Cookbook:: osrf_jenkins_agent
# Recipe:: default
#
# Copyright:: 2020, Open Source Robotics Foundation.
#

agent_username = node['osrf_buildfarm']['agent']['agent_username']
agent_homedir = "/home/#{agent_username}"

apt_update "default" do
  action :periodic
  frequency 3600
end

%w[
  default-jre-headless
  docker.io
  gnupg2
  groovy
  libffi-dev
  libssl-dev
  mercurial
  ntp
  qemu-user-static
  sudo
  x11-xserver-utils
  wget
].each do |pkg|
  package pkg
end

cookbook_file '/etc/X11/xorg.conf' do
  source 'xorg.conf.no_gpu'
  mode "0744"
  not_if "ls /dev/nvidia*"
end
cookbook_file '/etc/X11/xorg.conf' do
  source 'xorg.conf.nvidia'
  mode "0744"
  only_if "ls /dev/nvidia*"
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
      "display-setup-script=/etc/lightdm/xhost.conf"
    lightdm_conf.insert_line_if_no_match %r{^display-setup-script=.*},
      "display-setup-script=/etc/lightdm/xhost.conf"
    lightdm_conf.write_file if lightdm_conf.unwritten_changes?
  end
end

# set lightdm as the display manager requires 3 commands
execute 'set-lighdm-display-manager debconf' do
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

group 'docker' do
  append true
  members agent_username
  action :manage # Group should be created by docker package.
end

directory "/home/#{agent_username}/jenkins-agent"
agent_jar_url = "#{node['osrf_buildfarm']['agent']['jenkins_url']}/jnlpJars/agent.jar"
agent_jarfile_path = "/home/#{agent_username}/jenkins-agent/agent.jar"
remote_file agent_jarfile_path do
  source agent_jar_url
  owner agent_username
  group agent_username
  mode '0444'
end

jenkins_username = node['osrf_buildfarm']['agent']['username']
agent_jenkins_user = search('osrf_buildfarm_jenkins_users', "username:#{jenkins_username}").first
template '/etc/default/jenkins-agent' do
  source 'jenkins-agent.env.erb'
  variables Hash[
    java_args: node['osrf_buildfarm']['agent']['java_args'],
    jarfile: agent_jarfile_path,
    jenkins_url: node['osrf_buildfarm']['jenkins_url'],
    username: jenkins_username,
    password: agent_jenkins_user['password'],
    name: node['osrf_buildfarm']['agent']['nodename'],
    description: node['osrf_buildfarm']['agent']['description'],
    executors: node['osrf_buildfarm']['agent']['executors'],
    user_home: agent_homedir,
    labels: node['osrf_buildfarm']['agent']['labels'],
  ]
  notifies :restart, 'service[jenkins-agent]'
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
end
