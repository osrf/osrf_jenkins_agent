ROOT = File.expand_path("..", __FILE__)
chef_repo_path ROOT
cookbook_path [ File.join(ROOT, '..'), File.join(ROOT, 'berks-vendor-cookbooks')]
environment_path File.join(ROOT, "test/integration/environments")