## Underautomated setup instructions
# This section lists operations which were resistant to initial attempts to
# automate them.
# Hopefully with time, effort, and documentation we can find ways to automate these steps as well.

# Start by checking for updates and running any pending OS updates.
# Do not do major macOS version upgrades, such as Monterey -> Ventura.

# `administrator` user should already exist and the password is available in Bitwarden.

# Create `jenkins` account with sudo / administrator access to the host.
# Set it up for passwordless sudo.

# Log in as the Jenkins user, leaving accessibility, siri, and apple ID sign in disabled during initial user setup.

# Enable autologin for Jenkins from Login options, this is required so that xquartz is started on system boot.

# Verify SSH and VNC remote access are enabled, which should already true for
# our hosted machines.
# Verify remote management is enabled _only_ for administrator

# Verify wifi and bluetooth are disabled, which should already be true for
# our hosted machines.

# Disable Spotlight indexing. It's worth doing globally but at the very least
# make sure that `/Users/jenkins` and `/usr/local` are disabled.

# In Energy Saver settings, verify that display and system sleep are disabled
# completely by setting them to Never. There is no attached display so this
# will not spend extra watts.


# Run `git` or `cc` so that macOS prompts you to install developer tools.

# Enable developer mode with `/usr/sbin/DevToolsSecurity -enable`

# As the `jenkins` user, install homebrew using the instructions on https://brew.sh

# Run `brew doctor` to verify that homebrew has no complaints post-installation.


# Install xquartz
remote_file "/tmp/xquartz.pkg" do
  source "https://github.com/XQuartz/XQuartz/releases/download/XQuartz-2.8.5/XQuartz-2.8.5.pkg"
  not_if "pkgutil --pkg-info org.xquartz.X11"
end

execute "install xquartz" do
  command "installer -pkg /tmp/xquartz.pkg -target /"
  not_if "pkgutil --pkg-info org.xquartz.X11"
end

directory "/Users/jenkins/Library/LaunchAgents" do
  owner "jenkins"
  group "staff"
  recursive true
end

launchd "org.xquartz.X11.plist" do
  path "/Users/jenkins/Library/LaunchAgents/org.xquartz.X11.plist"
  keep_alive true
  run_at_load true
  working_directory "/Users/jenkins"
  process_type "Interactive"
  program "/Applications/Utilities/XQuartz.app/Contents/MacOS/X11"
  action [:create, :enable]
end


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
  group "staff"
end

# Map macOS platform version to version identifier
mac_version = case node["platform_version"] 
              when/\A11\./
                  "bigsur"
              when /\A12\./
                "monterey"
              when /\A13\./
                "ventura"
              when /\A14\./
                "sonoma"
              when /\A15\./
                "sequoia"
              else
                Chef::Fatal.log("macOS version #{node["platform_version"]} is not supported by this cookbook")
                raise
              end

agent_name = "mac-#{node["hostname"]}.#{mac_version}"
jenkins_agent_username = node['osrfbuild']['agent']['username']
jenkins_agent_user = data_bag_item('osrfbuild_jenkins_users', jenkins_agent_username)
labels = node['osrfbuild']['agent']['labels'].dup || Array.new
hw = node['hardware']
description = "macOS #{hw['operating_system_version']} #{hw['current_processor_speed']} #{hw['cpu_type']} #{hw['physical_memory']} #{} Jenkins agent"
if node['osrfbuild']['agent']['auto_generate_labels']
  labels << "osx"
  labels << "osx_#{mac_version}"
  labels << hw['architecture']
end

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
    -jar #{swarm_jar_path}
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
    -e HOMEWBREW_FORCE_VENDOR_RUBY=1
    -e MAKE_JOBS=8
  ]
  action [:create, :enable]
end
