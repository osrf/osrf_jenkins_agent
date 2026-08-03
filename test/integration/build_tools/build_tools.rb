# Checks for the osrf_jenkins_agent::agent_build_tools recipe. Only used by the
# suites that set install_agent_build_setup, so it must not be added to the
# agent-only suite.

control 'unattended-upgrades-blacklist' do
  impact 'high'
  title 'Packages that break a running agent when upgraded in place are excluded from unattended-upgrades'
  describe file('/etc/apt/apt.conf.d/51unattended-upgrades-osrf') do
    it { should exist }
    # 'nvidia-' does not cover 'libnvidia-': the entries are regexps anchored
    # at the start of the package name, so both prefixes are listed. The
    # (?!container) lookahead keeps nvidia-container-toolkit and
    # libnvidia-container* out of the freeze: they mount the host driver into
    # containers instead of shipping a copy of it, so they carry no
    # version-skew risk and must stay eligible for security updates.
    its('content') { should match /"nvidia-\(\?!container\)";/ }
    its('content') { should match /"libnvidia-\(\?!container\)";/ }
  end

  # The distribution 50unattended-upgrades must keep providing the rest of the
  # policy, so check the merged value and not only our own file
  describe command('apt-config dump Unattended-Upgrade::Package-Blacklist') do
    its('stdout') { should match /"nvidia-\(\?!container\)"/ }
    its('stdout') { should match /"libnvidia-\(\?!container\)"/ }
  end
end
