# InSpec test for recipe osrf_jenkins_agent::default
control 'agent_user' do
  impact 'critical'
  title 'User jenkins should present in the system'
  # attributes are not directly accesible from inspec. Hardcoding user here
  describe user('jenkins') do
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

# Unable to make only_if to work with this check
if File.file?('/dev/nvidia0')
  control 'nvidia' do  
    impact 'critical'
    title 'nvidia support in nvidia nodes'
    describe file('/etc/X11/xorg.conf') do
      its('content') { should match /nvidia/ }
    end
  end
end


control 'lightdm' do
  impact 'critical'
  title 'lightdm service should be up and running'
  describe service('lightdm') do
      it { should be_enabled }
      it { should be_installed }
      it { should be_running }
  end
end

control 'jenkins-agent' do
  impact 'critical'
  title 'jenkins-agent service should be up and running'
  describe service('jenkins-agent') do
      it { should be_enabled }
      it { should be_installed }
      # imposible to connect to server in tests, should not be up
      it { should_not be_running }
  end
end
