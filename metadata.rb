name "osrf_jenkins_agent"
maintainer "Jose Luis Rivero"
maintainer_email "jrivero@openrobotics.org"
license "Apache-2.0"
description "Configures a Jenkins agent for the OSRF build farm."
long_description "Configures a Jenkins agent for the OSRF build farm."
version "0.1.3"
chef_version ">= 14.0"

depends "docker", "=4.6.7" # In sync with chef-osrf private configurations
