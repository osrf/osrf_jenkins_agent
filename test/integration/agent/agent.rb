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
  title 'jenkins-agent service should installed and running'
  describe service('jenkins-agent') do
    it { should be_installed }
    # imposible to connect to server in tests, should not be up
    it { should be_enabled }
    it { should be_running }
  end
end

control 'check-no-nil-in-agents' do
  impact 'high'
  title 'Check that optional fields are not translated into nil strings'
  describe file('/etc/default/jenkins-agent') do
    its('content') { should_not match /nil/ }
  end
end

control 'check-no-default-label' do
  impact 'high'
  title 'Check that no default label is being applied. arm agents do not use docker'
  describe file('/etc/default/jenkins-agent') do
    its('content') { should match /LABELS=''/ }
  end
end
