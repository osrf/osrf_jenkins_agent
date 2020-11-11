# InSpec test for recipe osrf_jenkins_agent::default

describe user(node['osrf_buildfarm']['agent']['agent_username']), :skip do
  it { should exist }
end

# This is an example test, replace it with your own test.
describe port(80), :skip do
  it { should_not be_listening }
end

describe service("lightdm") do
    it { should be_enabled }
    it { should be_installed }
    it { should be_running }
end

describe service("jenkins-agent") do
    it { should be_enabled }
    it { should be_installed }
    it { should be_running }
end
