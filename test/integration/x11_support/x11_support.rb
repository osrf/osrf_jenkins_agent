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

control 'nvidia-packages-on-hold' do
  impact 'critical'
  title 'nvidia packages are held so they are never upgraded behind the loaded nvidia.ko'
  # Only meaningful once a driver is actually installed, which does not happen
  # on agents without a GPU. Match any nvidia-driver-* so the check does not
  # silently turn into a no-op the next time the driver branch is bumped.
  only_if('an nvidia driver is installed') do
    command("dpkg-query -W -f='${db:Status-Abbrev} ${Package}\\n' 'nvidia-driver-*' 2>/dev/null | grep -q '^ii'").exit_status.zero?
  end

  describe command('apt-mark showhold') do
    its('stdout') { should match /^nvidia-/ }
  end
end
