chocolatey_package 'meinberg-ntp'
# Used by release-tools particularly sdformat
chocolatey_package 'wget'

#  python 3.11.2 ruby 3.1.3 cmake 3.25 git 2.38.1 VS 2019 Community java 8 vcpkg-temp-cache
chocolatey_package 'cmake' do
  version [ '3.25' ]
end

# AdoptOpenJDK installer documentation https://adoptopenjdk.net/installation.html#windows-msi
windows_package 'openjdk' do
  options 'INSTALLLEVEL=1 /quiet'
  source 'https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u242-b08_openj9-0.18.1/OpenJDK8U-jdk_x64_windows_openj9_8u242b08_openj9-0.18.1.msi'
  action :install
end

