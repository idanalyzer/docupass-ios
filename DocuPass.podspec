Pod::Spec.new do |s|
  s.name             = 'DocuPass'
  s.version          = '0.2.1'
  s.summary          = 'Native in-app ID verification & KYC for iOS (ID Analyzer DocuPass).'
  s.description      = <<-DESC
    Embed ID Analyzer DocuPass identity verification natively inside your iOS app —
    document scanning, face match, and on-device active liveness — with no external
    browser and no WebView. Drop in one SwiftUI view, get a result callback.
  DESC
  s.homepage         = 'https://github.com/idanalyzer/docupass-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ID Analyzer' => 'support@idanalyzer.com' }
  s.source           = { :git => 'https://github.com/idanalyzer/docupass-ios.git', :tag => "v#{s.version}" }

  s.ios.deployment_target = '15.0'
  s.swift_version    = '5.9'

  # MediaPipeTasksVision is a static binary xcframework; packaging DocuPass as a
  # static framework lets that transitive dependency integrate (and is required
  # for `pod trunk push`, which has no --use-static-frameworks flag).
  s.static_framework = true

  s.source_files     = 'Sources/DocuPass/**/*.swift'
  s.resource_bundles = {
    'DocuPass' => ['Sources/DocuPass/Resources/face_landmarker.task', 'Sources/DocuPass/Resources/country.json']
  }

  s.frameworks       = 'SwiftUI', 'AVFoundation', 'UIKit', 'WebKit', 'CoreImage'
  s.dependency 'MediaPipeTasksVision', '~> 0.10'
end
