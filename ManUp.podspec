Pod::Spec.new do |s|
  s.name             = "ManUp"
  s.version          = "0.5"
  s.summary          = "A server side check of the app version and configuration options for your iOS/tvOS app."

  s.description      = <<-DESC
  Adds a server side check for a mandatory app update and server-side configuration options to your iOS/tvOS application.
                       DESC

  s.homepage         = "https://github.com/NextFaze/ManUp"
  s.license          = 'MIT'
  s.authors          = { "Jeremy Day" => "jer.day@gmail.com",
                         "Ric Santos" => "rics@ntos.me",
                         "Dan Silk" => "dsilk@nextfaze.com" }
  s.source           = { :git => "https://github.com/NextFaze/ManUp.git", :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'
  s.tvos.deployment_target = '9.0'

  s.requires_arc = true

  s.source_files = 'ManUp/*.{h,m}'
end
