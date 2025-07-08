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
  title 'jenkins-agent service should installed and enabled'
  describe service('jenkins-agent') do
    it { should be_installed }
    it { should be_enabled }
    # Do not make any assumption about the running state since
    # it can be running or not depending possibly on connection timeouts    
  end
end

control 'check-no-nil-in-agents' do
  impact 'high'
  title 'Check that optional fields are not translated into nil strings'
  describe file('/etc/default/jenkins-agent') do
    its('content') { should_not match /nil/ }
  end
end

control 'check-no-default-docker-label' do
  impact 'high'
  title 'Check that no default docker label is being applied. Historically meant amd64-docker systems'
  describe file('/etc/default/jenkins-agent') do
    its('content') { should_not match /LABELS='.*docker.*'/ }
  end
end
