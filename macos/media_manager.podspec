#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint media_manager.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'media_manager'
  s.version          = '1.0.3'
  s.summary          = 'Flutter plugin for browsing media, archives and documents on macOS.'
  s.description      = <<-DESC
A Flutter plugin for managing media files on macOS with paginated queries,
on-disk thumbnail caching, archive discovery (zip/rar/7z/dmg/…) and
file-system scanning.
                       DESC
  s.homepage         = 'https://github.com/SwanFlutter/media_manager'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'SwanFlutter' => 'swanflutter@example.com' }

  s.source           = { :path => '.' }
  s.source_files = 'media_manager/Sources/media_manager/**/*'

  # If your plugin requires a privacy manifest, for example if it collects user
  # data, update the PrivacyInfo.xcprivacy file to describe your plugin's
  # privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'media_manager_privacy' => ['media_manager/Sources/media_manager/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
