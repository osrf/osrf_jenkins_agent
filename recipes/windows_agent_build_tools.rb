chocolatey_package 'meinberg-ntp'
# Used by release-tools particularly sdformat
chocolatey_package 'wget'

#  VS 2019 Community java 8 vcpkg-temp-cache

chocolatey_package 'python' do
  version [ '3.11.2' ]
end

chocolatey_package 'ruby' do
  version [ '3.1.3' ]
end

chocolatey_package 'cmake' do
  version [ '3.25' ]
end

chocolatey_package 'cuda' do
end

python_package 'vcstool' do
  action :install
end

python_package 'colcon-common-extensions' do
  action :install
end

# AdoptOpenJDK installer documentation https://adoptopenjdk.net/installation.html#windows-msi
windows_package 'openjdk' do
  options 'INSTALLLEVEL=1 /quiet'
  source 'https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u242-b08_openj9-0.18.1/OpenJDK8U-jdk_x64_windows_openj9_8u242b08_openj9-0.18.1.msi'
  action :install
end

windows_package 'Visual Studio 2019 Community' do
  source 'https://aka.ms/vs/16/release/vs_community.exe'
  installer_type :custom
  options '--passive --installPath "C:\\Program Files (x86)\\Microsoft Visual Studio\\2019\\Community"'
  action :install
end

# TODO (j-rivero): grab the snapshot tab from release-tools once the
# gz-collections.yaml is ready with that info
git 'C:/vcpkg' do
  repository 'https://github.com/microsoft/vcpkg.git'
  revision '2022.02.23'
  action :sync
end

execute 'bootstrap-vcpkg' do
  command 'C:/vcpkg/bootstrap-vcpkg.bat'
  cwd 'C:/vcpkg'
  action :run
end
