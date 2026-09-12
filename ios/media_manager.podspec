#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint media_manager.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'media_manager'
  s.version          = '1.0.2'
  s.summary          = 'Flutter plugin for browsing media, archives and documents on iOS.'
  s.description      = <<-DESC
A Flutter plugin for managing media files on iOS with paginated queries,
on-disk thumbnail caching, archive discovery (zip/rar/7z/ipa/…) and
storage permission handling.
                       DESC
  s.homepage         = 'https://github.com/SwanFlutter/media_manager'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'SwanFlutter' => 'swanflutter@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'media_manager/Sources/media_manager/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'media_manager_privacy' => ['media_manager/Sources/media_manager/PrivacyInfo.xcprivacy']}
end
