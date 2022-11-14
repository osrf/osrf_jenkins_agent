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
  end
end
