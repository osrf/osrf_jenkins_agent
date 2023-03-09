macos_userdefaults "jenkins autologin" do
  domain "/Library/Preferences/com.apple.loginwindow"
  key "autoLoginUser"
  user :all
  value "jenkins"
end
