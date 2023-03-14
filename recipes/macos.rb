# Install java

remote_file "/tmp/jdk8.pkg" do
  source "https://github.com/adoptium/temurin8-binaries/releases/download/jdk8u362-b09/OpenJDK8U-jdk_x64_mac_hotspot_8u362b09.pkg"
  not_if "pkgutil --pkg-info net.temurin.8.jdk"
end

execute "install java" do
  command "installer -pkg /tmp/jdk8.pkg -target /"
  not_if "pkgutil --pkg-info net.temurin.8.jdk"
end

# Create workspace

# Fetch swarm client jar

# Create launch service

# Start launch service
