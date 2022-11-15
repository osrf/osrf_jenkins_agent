control 'check-fixed-name' do
  impact 'high'
  title 'Check that a custom name was applied to the agent'
  describe file('/etc/default/jenkins-agent') do
    its('content') { should match /NAME='my_custom_name'/ }
  end
end
