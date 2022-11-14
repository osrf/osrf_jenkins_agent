default['osrfbuild']['agent']['linux_username'] = 'default_linux_username'

# If set to true, install common build tools for linux agents in the buildfarm
# If set to false, install just the Jenkins agent connection. Useful for
# special machines like the package repositories.
default['osrfbuild']['agent']['install_agent_build_setup'] = true

default['osrfbuild']['agent']['jenkins_url'] = "https://default_url.org"
default['osrfbuild']['agent']['java_args'] = ''
default['osrfbuild']['agent']['username'] = 'default_username'
default['osrfbuild']['agent']['description'] = 'default build agent description'
default['osrfbuild']['agent']['executors'] = 1
# TODO tags
default['osrfbuild']['agent']['labels'] = %w(docker)
