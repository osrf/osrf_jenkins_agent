include_recipe 'osrf_jenkins_agent::python'
include_recipe 'osrf_jenkins_agent::pip_installs'
include_recipe 'osrf_jenkins_agent::visual_studio'

chocolatey_package 'meinberg-ntp'

chocolatey_package 'wget'

chocolatey_package 'ruby' do
  version [ '3.1.3.1' ]
end

chocolatey_package 'cmake' do
  version [ '3.25' ]
end

chocolatey_package 'cuda'

# AdoptOpenJDK installer documentation https://adoptopenjdk.net/installation.html#windows-msi
windows_package 'openjdk' do
  options 'INSTALLLEVEL=1 /quiet'
  source 'https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u242-b08_openj9-0.18.1/OpenJDK8U-jdk_x64_windows_openj9_8u242b08_openj9-0.18.1.msi'
  action :install
end

include_recipe 'osrf_jenkins_agent::vcpkg'
