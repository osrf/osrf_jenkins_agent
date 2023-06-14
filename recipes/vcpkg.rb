vcpkg_dir = 'C:/vcpkg'

# TODO: (j-rivero): grab the snapshot tab from release-tools once the
# gz-collections.yaml is ready with that info
git vcpkg_dir do
  repository 'https://github.com/microsoft/vcpkg.git'
  revision '2022.02.23'
  action :sync
end

execute 'bootstrap-vcpkg' do
  command "#{vcpkg_dir}/bootstrap-vcpkg.bat"
  cwd vcpkg_dir
  action :run
end

chocolatey_package 'patch'

patches_temp = "#{vcpkg_dir}/.osrf_snapshot_patches"
patches_applied = "#{patches_temp}/PACTHES_APPLIED"

directory patches_temp do
  action :create
end

vcpkg_patches = %w(
  msys.patch
  release-only.patch
)

# Copy the .patch files to a temporary directory
vcpkg_patches.each do |file|
  cookbook_file "#{patches_temp}\#{file}" do
    source "vcpkg-patches/#{file}"
    action :create
    not_if { ::File.exist?(patches_applied) }
  end

  batch 'apply_patches' do
    cwd vcpkg_dir
    code "patch -p1 -i #{patches_temp}\#{file}"
    action :run
    not_if { ::File.exist?(patches_applied) }
  end
end

file patches_applied do
  action :create
  not_if { ::File.exist?(patches_applied) }
end
