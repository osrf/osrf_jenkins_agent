control 'no-x11-packages' do
  impact 'low'
  title 'Check that the system does not contain X11 packages'
  describe service('lightdm') do
    it { should_not be_installed }
  end
end
