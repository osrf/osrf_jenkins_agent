name "osrf_jenkins_agent"
maintainer "Jose Luis Rivero"
maintainer_email "jrivero@openrobotics.org"
license "Apache-2.0"
description "Configures a Jenkins agent for the OSRF build farm."
long_description "Configures a Jenkins agent for the OSRF build farm."
version "0.1.4"
chef_version ">= 14.0"

if platform?('linux')
  # be careful if set a version on docker since it can conflict with other
  # repositories (chef-osrf)
  depends "docker"
end
