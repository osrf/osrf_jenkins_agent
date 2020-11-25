default['osrf_buildfarm']['agent']['jenkins_url'] = "https://build.osrfoundation.org"
default['osrf_buildfarm']['agent']['agent_username'] = 'jenkins'
default['osrf_buildfarm']['agent']['java_args'] = ''
default['osrf_buildfarm']['agent']['username'] = 'admin'
default['osrf_buildfarm']['agent']['nodename'] = 'agent'
default['osrf_buildfarm']['agent']['description'] = 'build agent'
default['osrf_buildfarm']['agent']['executors'] = 1
# TODO tags
default['osrf_buildfarm']['agent']['labels'] = %w(docker)

