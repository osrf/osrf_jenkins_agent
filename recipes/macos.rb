user 'jenkins' do
  home '/Users/jenkins'
  comment 'jenkins'
  if node['osrf_jenkins_agent']['macos']['jenkins_user_password']
    password node['osrf_jenkins_agent']['macos']['jenkins_user_password']
    secure_token_password node['osrf_jenkins_agent']['macos']['jenkins_user_password']
  end
end

