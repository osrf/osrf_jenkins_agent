# InSpec test for recipe osrf_jenkins_agent::default
control 'agent_user' do
  impact 'critical'
  describe 'User jenkins should present in the system'
  describe user(node['osrf_buildfarm']['agent']['agent_username']) do
    it { should exist }
  end
end

control 'no_open_ports' do
  impact 'low'
  describe 'Check no expected open ports exists'
  describe port(80) do
    it { should_not be_listening }
  end
end

control 'nvidia' do
  impact 'critical'
  title 'nvidia support in nvidia nodes'
  describe file('/etc/X11/xorg.conf') do
    its('content') { should match /nvidia/ }
  end

  only_if 'lspci -vv | grep -i nvidia'
end

control 'lightdm' do
  impact 'critical'
  title 'lightdm service should be up and running'
  describe service("lightdm") do
      it { should be_enabled }
      it { should be_installed }
      it { should be_running }
  end
end

control 'jenkins-agent' do
  impact 'critical'
  title 'jenkins-agent service should be up and running'
  describe service("jenkins-agent") do
      it { should be_enabled }
      it { should be_installed }
      it { should be_running }
  end
end
