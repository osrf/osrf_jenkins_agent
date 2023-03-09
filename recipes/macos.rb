macos_userdefaults "jenkins autologin" do
  domain "/Library/Preferences/com.apple.loginwindow"
  key "autoLoginUser"
  value "jenkins"
end
