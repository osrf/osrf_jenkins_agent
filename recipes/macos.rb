# Install java

remote_file "/tmp/jdk8.pkg" do
  source "https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u362-b09/OpenJDK8U-jdk_x64_mac_hotspot_8u362b09.pkg"
  not_if "pkgutil --pkg-info net.temurin.8.jdk"
end

execute "install java" do
  command "installer -pkg /tmp/jdk8.pkg -target /"
  not_if "pkgutil --pkg-info net.temurin.8.jdk"
end

# Fetch swarm client jar
swarm_jar_path = "/Users/jenkins/swarm-client.jar"

remote_file swarm_jar_path do
  source "#{node['osrfbuild']['agent']['jenkins_url']}/swarm/swarm-client.jar"
  owner "jenkins"
end

# Map macOS platform version to version identifier
mac_version = case node["platform_version"] 
              when/\A11\./
                  "bigsur"
              when /\A12\./
                "monterey"
              when /\A13\./
                "ventura"
              else
                Chef::Fatal.log("macOS version #{node["platform_version"]} is not supported by this cookbook")
                raise
              end

agent_name = "mac-#{node["hostname"]}.#{mac_version}"
jenkins_agent_username = node['osrfbuild']['agent']['username']
jenkins_agent_user = data_bag_item('osrfbuild_jenkins_users', jenkins_agent_username)
labels = node['osrfbuild']['agent']['labels'].dup || Array.new
if node['osrfbuild']['agent']['auto_generate_labels']
  labels << "osx"
  labels << "osx_#{mac_version}"
end
description = "macOS #{mac_version} Jenkins agent"

directory "/Users/jenkins/log" do
  owner "jenkins"
  group "staff"
end


# Create workspace inside jenkins home directory
directory "/Users/jenkins/jenkins-agent" do
  owner "jenkins"
  group "staff"
end

launchd "org.osrfoundation.build.jenkins-agent.plist" do
  path "/Library/LaunchDaemons/org.osrfoundation.build.jenkins-agent.plist"
  keep_alive true
  run_at_load true
  username "jenkins"
  working_directory "/Users/jenkins"
  standard_in_path "/dev/null"
  standard_out_path "/Users/jenkins/log/jenkins-agent.out.log"
  standard_error_path "/Users/jenkins/log/jenkins-agent.err.log"
  process_type "Interactive"
  program_arguments %W[
    /usr/bin/java
    -jar
    #{swarm_jar_path}
    -url #{node['osrfbuild']['agent']['jenkins_url']}
    -name #{agent_name}
    -username #{jenkins_agent_user['username']}
    -password #{jenkins_agent_user['password']}
    -description #{description}
    -mode exclusive
    -executors 1
    -fsroot /Users/jenkins/jenkins-agent
    -disableClientsUniqueId
    -deleteExistingClients
    -labels #{labels.join(' ')}
  ]
  action [:create, :enable]
end
