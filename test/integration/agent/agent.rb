# InSpec test for recipe osrf_jenkins_agent::default
control 'agent_user' do
  impact 'critical'
  title 'User jenkins should present in the system'
  # attributes are not directly accesible from inspec. Hardcoding user here
  describe user('default_linux_username') do
    it { should exist }
  end
end

control 'no_open_ports' do
  impact 'low'
  title 'Check no expected open ports exists'
  describe port(80) do
    it { should_not be_listening }
  end
end

control 'jenkins-agent' do
  impact 'critical'
  title 'jenkins-agent service should installed, not running'
  describe service('jenkins-agent') do
    it { should be_installed }
    # imposible to connect to server in tests, should not be up
    it { should_not be_enabled }
    it { should_not be_running }
  end
end
