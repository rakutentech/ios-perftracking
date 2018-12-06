Pod::Spec.new do |s|
  s.name         = "RPerformanceTracking"
  s.version      = "1.2.0"
  s.authors      = "Rakuten Ecosystem Mobile"
  s.summary      = "Automatic performance tracking for all your applications."
  s.homepage     = "https://github.com/rakutentech/ios-perftracking"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.source       = { :git => "https://github.com/rakutentech/ios-perftracking.git", :tag => s.version.to_s }
  s.platform     = :ios, '10.0'
  s.requires_arc = true
  s.documentation_url = "https://github.com/rakutentech/ios-perftracking"
  s.pod_target_xcconfig = {
    'CLANG_ENABLE_MODULES'                                  => 'YES',
    'CLANG_MODULES_AUTOLINK'                                => 'YES',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
    'GCC_C_LANGUAGE_STANDARD'                               => 'gnu11',
    'OTHER_CFLAGS'                                          => "'-DRPT_SDK_VERSION=#{s.version.to_s}'"
  }
  s.user_target_xcconfig = {
    'CLANG_ENABLE_MODULES'                                  => 'YES',
    'CLANG_MODULES_AUTOLINK'                                => 'YES',
    'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES',
  }
  s.weak_frameworks = [
    'Foundation',
  ]
  s.source_files = "RPerformanceTracking/**/*.{h,m}"
  s.private_header_files = "RPerformanceTracking/Private/**/*.h"
  s.module_map = 'RPerformanceTracking/RPerformanceTracking.modulemap'
end
# vim:syntax=ruby:et:sts=2:sw=2:ts=2:ff=unix:
