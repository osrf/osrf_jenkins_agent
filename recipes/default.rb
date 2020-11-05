#
# Cookbook:: osrf_jenkins_agent
# Recipe:: default
#
# Copyright:: 2020, Open Source Robotics Foundation.
#
apt_update "default" do
  action :periodic
  frequency 3600
end

%w[
  default-jre-headless
  gnupg2
  groovy
  libffi-dev
  libssl-dev
  mercurial
  ntp
  qemu-user-static
  sudo
  wget
].each do |pkg|
  package pkg
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
      "display-setup-script=/etc/lightdm/xhost.conf"
    lightdm_conf.insert_line_if_no_match %r{^display-setup-script=.*},
      "display-setup-script=/etc/lightdm/xhost.conf"
    lightdm_conf.write_file if lightdm_conf.unwritten_changes?
  end
end

# no lightdm for development
if ['github_ci'].include? node.chef_environment
  service "lightdm" do
    action [:start, :enable]
  end
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

docker_installation_package "default" do
  setup_docker_repo true
end
service "docker" do
  action [:start, :enable]
end

package "nvidia-modprobe" do
  notifies :restart, "service[docker]", :delayed
end

user "jenkins" do
  shell "/bin/bash"
  manage_home true
end
sudo "jenkins" do
  user "jenkins"
  nopasswd true
end
directory "/home/jenkins/jenkins-agent"
agent_jar_url = node["osrf_jenkins_agent"]["agent_jar_url"]
if agent_jar_url.nil? || agent_jar_url.empty?
  agent_jar_url = "#{node["osrf_jenkins_agent"]["jenkins_url"]}/jnlpJars/agent.jar"
end
remote_file "/home/jenkins/jenkins-agent/agent.jar" do
  source agent_jar_url
end
