# Provision a system with the base software

In order to bring only the software dependencies used by the build agent to build software but do not link it to the buildfarm
the helper script in this repository can be used. It will install chocolatey for installing git and chefdk and run chef
installations to create a development enviroment which includes different system installations (CUDA, Visual Studio, etc) and
the vcpkg installtion on `C:\vcpkg`.

To run the helper:


```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force;. { iwr -useb https://raw.githubusercontent.com/osrf/osrf_jenkins_agent/latest/tools/bootstrap-windows-base-packages.ps1 } | iex

# Close the powershell and reopen (to get the git installation correctly)
# run again

Set-ExecutionPolicy Bypass -Scope Process -Force;. { iwr -useb https://raw.githubusercontent.com/osrf/osrf_jenkins_agent/latest/tools/bootstrap-windows-base-packages.ps1 } | iex
```
