required_pip_packages = %w[
  vcstool
  colcon-common-extensions
]

# Use explicit location because python may not be on the PATH if chef-solo has not been run before
#
execute 'pip_update' do
  command lazy {
    "#{node.run_state[:python_dir]}\\python.exe -m pip install -U pip setuptools==59.6.0"
  }
end

execute 'pip_required' do
  command lazy {
    "#{node.run_state[:python_dir]}\\python.exe -m pip install -U #{required_pip_packages.join(' ')}"
  }
end
