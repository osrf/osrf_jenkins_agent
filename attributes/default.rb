# Linux user in the system to support the run of the Jenkins agent
default['osrfbuild']['agent']['linux_username'] = 'default_linux_username'
# Whenether the linux_username user in the base system will have access to
# sudo in the base system
default['osrfbuild']['agent']['sudo_access'] = true
# If set, the node will recieve the nodename value. This is useful for custom
# nodes such as a repository machine.
# If nil, the node name will be autogenerated from the provisioning code. This is
# used for generated build agents on demand.
default['osrfbuild']['agent']['nodename'] = nil
# If set to true, install common build tools for linux agents in the buildfarm
# If set to false, install just the Jenkins agent connection. Useful for
# special machines like the package repositories.
default['osrfbuild']['agent']['install_agent_build_setup'] = true
default['osrfbuild']['agent']['jenkins_url'] = "https://default_url.org"
default['osrfbuild']['agent']['java_args'] = ''
default['osrfbuild']['agent']['username'] = 'default_username'
default['osrfbuild']['agent']['description'] = 'default build agent description'
default['osrfbuild']['agent']['executors'] = 1
# if set to true, the provisioning will autogenerate the gpu labels
# if set to false, the value of ['osrfbuild']['agent']['labels']
# is respected. Note that the value here can be overloaded.
default['osrfbuild']['agent']['auto_generate_labels'] = true
