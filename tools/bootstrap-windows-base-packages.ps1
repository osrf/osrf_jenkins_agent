$ErrorActionPreference = 'Stop'
Set-ExecutionPolicy Bypass -Scope Process -Force;. { iwr -useb https://chocolatey.org/install.ps1 } | iex
choco install -y git chefdk
refreshenv
Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
Write-Host "NEEDS TO CLOSE POWERSHELL AND RUN AGAIN TO MAKE GIT WORK"

git clone --verbose --progress https://github.com/osrf/osrf_jenkins_agent.git -b jrivero/provision_packages
cd osrf_jenkins_agent\tools
chef-solo.bat -c ..\solo.rb -j osrf-windows-agent-pkgs.solo.json
Write-Host "Completed chef-solo result $?"
