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
  squid-deb-proxy
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
service "lightdm" do
  action [:start, :enable]
end


docker_installation_package "default" do
  setup_docker_repo true
end

remote_file "/tmp/nvidia-docker.gpgkey" do
  source "https://nvidia.github.io/nvidia-docker/gpgkey"
  # TODO check if key is already added.
  # not_if ...
end

execute "apt-key add /tmp/nvidia-docker.gpgkey" do
  # TODO check if key is already added.
  # not_if ...
end

apt_update "nvidia-docker" do
  action :nothing
end

remote_file "/etc/apt/sources.list.d/nvidia-docker.list" do
  source "https://nvidia.github.io/nvidia-docker/#{node["platform"]}#{node["platform_version"]}/nvidia-docker.list"
  notifies :update, "apt_update[nvidia-docker]", :immediate
end

package "nvidia-docker"
package "nvidia-modprobe"

user "jenkins" do
  shell "/bin/bash"
  manage_home true
end




