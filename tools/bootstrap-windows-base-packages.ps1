$ErrorActionPreference = 'Stop'
. { iwr -useb https://omnitruck.cinc.sh/install.ps1 } | iex; install -version 17
Set-ExecutionPolicy Bypass -Scope Process -Force;. { iwr -useb https://chocolatey.org/install.ps1 } | iex
choco install -y git
Install-Module -Name Berkshelf -Force -AllowClobber
refreshenv

Remove-Item -Path osrf_jenkins_agent -Force -Recurse -ErrorAction SilentlyContinue
git clone --verbose --progress https://github.com/osrf/osrf_jenkins_agent.git -b jrivero/provision_packages
cd osrf_jenkins_agent
berks vendor berks-vendor-cookbooks
cd tools
C:\cinc-project\cinc\bin\cinc-solo.bat -c ..\solo.rb -j osrf-windows-agent-pkgs.solo.json 
Write-Host "Completed chef-solo result $?"
