name "osrf_jenkins_agent"
maintainer "Steven! Ragnarök"
maintainer_email "steven@openrobotics.org"
license "Apache-2.0"
description "Configures a Jenkins agent for the OSRF build farm."
long_description "Configures a Jenkins agent for the OSRF build farm."
version "0.1.0"
chef_version ">= 14.0"

# be careful if set a version on docker since it can conflict with other
# repositories (chef-osrf)
depends "docker"
