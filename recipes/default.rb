#
# Cookbook:: osrf_jenkins_agent
# Recipe:: default
#
# Copyright:: 2020, Open Source Robotics Foundation.
#

linux_username = node['osrfbuild']['agent']['linux_username']
agent_homedir = "/home/#{linux_username}"

user linux_username  do
  shell "/bin/bash"
  home "#{agent_homedir}"
  manage_home true
end
sudo linux_username do
  user linux_username
  nopasswd true
end

apt_update "default" do
  action :periodic
  frequency 3600
end

package 'default-jre-headless'

puts node['osrfbuild']['agent']['install_agent_build_setup']
include_recipe 'osrf_jenkins_agent::agent_build_tools' if node['osrfbuild']['agent']['install_agent_build_setup']

# TODO: how to read attributes from chef-osrf plugins into this cookbook
# swarm_client_version = node['jenkins-plugins']['swarm']
swarm_client_version = "3.24"
swarm_client_url = "https://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/#{swarm_client_version}/swarm-client-#{swarm_client_version}.jar"
swarm_client_jarfile_path = "#{agent_homedir}/swarm-client-#{swarm_client_version}.jar"

# Download swarm client program from url and install it to the jenkins-agent user's home directory.
remote_file swarm_client_jarfile_path do
  source swarm_client_url
  owner linux_username
  group linux_username
  mode '0444'
end

# Compose node name. Use ip if hostname is localhost otherwise use localhost
# value. Add nv intermediate word if gpu is present
jenkins_username = node['osrfbuild']['agent']['username']
node_make_jobs = 3 # TODO: find a better way of handling make_jobs
node_base_name = node['hostname'] == 'localhost' ? node['ipaddress'] : node['hostname']
node_labels = [ node['osrfbuild']['agent']['labels'] ]
node_name = "linux-#{node_base_name}.focal"

if has_nvidia_support?
    node_name = "linux-#{node_base_name}.nv.focal"
    # TODO: do not assume nvidia machines are powerful
    node_labels += ["gpu-reliable", "gpu-nvidia", "large-memory", "large-disk"]
    node_make_jobs = 5
end

# override node name if a nodename was given
node_name = node['osrfbuild']['agent']['nodename'] if node['osrfbuild']['agent']['nodename']

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
    labels: node_labels.join(' '),
    make_jobs: node_make_jobs,
  ]
  notifies :restart, 'service[jenkins-agent]'
end

directory '/etc/jenkins-agent'
file '/etc/jenkins-agent/token' do
  content agent_jenkins_user['password']
  mode '0640'
  owner 'root'
  group linux_username
end

template '/etc/systemd/system/jenkins-agent.service' do
  source 'jenkins-agent.service.erb'
  variables Hash[
    service_name: 'jenkins-agent',
    username: linux_username,
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
