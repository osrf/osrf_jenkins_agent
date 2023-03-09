macos_userdefaults "jenkins autologin" do
  domain "/Library/Preferences/com.apple.loginwindow"
  key "autoLoginUser"
  user :all
  value "jenkins"
end

execute "jenkins autologin" do
  command "defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser jenkins"
end
