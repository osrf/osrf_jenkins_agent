$ErrorActionPreference = 'Stop'
. { iwr -useb https://omnitruck.cinc.sh/install.ps1 } | iex; install -version 15
Set-ExecutionPolicy Bypass -Scope Process -Force;. { iwr -useb https://chocolatey.org/install.ps1 } | iex
choco install -y git
git clone --verbose --progress https://github.com/osrf/osrf_jenkins_agent.git
cd osrf_jenkins_agent\tools
C:\cinc-project\cinc\bin\cinc-solo.bat -c ..\chef\solo.rb -j .osrf-windows-agent-pkgs.solo.json 
Write-Host \"Completed chef-solo result $?\""
