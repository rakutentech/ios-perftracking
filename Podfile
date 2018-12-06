source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '10.0'
use_frameworks!

pod 'Kiwi',            '~> 3.0.0'
pod 'Underscore.m',    '~> 0.3.0'
pod 'OCMock',          '~> 3.2'
pod 'OHHTTPStubs',     '~> 4.7.0'
pod 'OHHTTPStubs/HTTPMessage'
pod 'RPerformanceTracking', :path => './RPerformanceTracking.podspec'

target 'UnitTests'
target 'FunctionalTests'


# For CI: This post install hook enables more warnings for the module's target
post_install do |installer|
  installer.pods_project.targets.select { |target| target.name == 'RPerformanceTracking' }.first.build_configurations.each do |config|
    config.build_settings.merge!({
      # Static code analyzer
      'CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED' => 'YES',
      'CLANG_ANALYZER_NONNULL' => 'YES',
      'CLANG_ANALYZER_SECURITY_FLOATLOOPCOUNTER' => 'YES',
      'CLANG_ANALYZER_SECURITY_INSECUREAPI_RAND' => 'YES',
      'CLANG_ANALYZER_SECURITY_INSECUREAPI_STRCPY' => 'YES',
      'CLANG_STATIC_ANALYZER_MODE' => 'deep',
      'RUN_CLANG_STATIC_ANALYZER' => 'YES',

      # Compiler warnings
      'CLANG_WARN_BOOL_CONVERSION' => 'YES',
      'CLANG_WARN_CONSTANT_CONVERSION' => 'YES',
      'CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS' => 'YES',
      'CLANG_WARN_DIRECT_OBJC_ISA_USAGE' => 'YES_ERROR',
      'CLANG_WARN_EMPTY_BODY' => 'YES',
      'CLANG_WARN_ENUM_CONVERSION' => 'YES',
      'CLANG_WARN_IMPLICIT_SIGN_CONVERSION' => 'YES',
      'CLANG_WARN_INT_CONVERSION' => 'YES',
      'CLANG_WARN_NULLABLE_TO_NONNULL_CONVERSION' => 'YES',
      'CLANG_WARN_OBJC_IMPLICIT_ATOMIC_PROPERTIES' => 'YES',
      'CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF' => 'YES',
      'CLANG_WARN_OBJC_REPEATED_USE_OF_WEAK' => 'YES',
      'CLANG_WARN_OBJC_ROOT_CLASS' => 'YES_ERROR',
      'CLANG_WARN_SUSPICIOUS_IMPLICIT_CONVERSION' => 'YES',
      'CLANG_WARN_UNREACHABLE_CODE' => 'YES',
      'CLANG_WARN__DUPLICATE_METHOD_MATCH' => 'YES',
      'GCC_TREAT_INCOMPATIBLE_POINTER_TYPE_WARNINGS_AS_ERRORS' => 'YES',
      'GCC_WARN_64_TO_32_BIT_CONVERSION' => 'YES',
      'GCC_WARN_ABOUT_MISSING_NEWLINE' => 'YES',
      'GCC_WARN_ABOUT_MISSING_PROTOTYPES' => 'YES',
      'GCC_WARN_ABOUT_RETURN_TYPE' => 'YES_ERROR',
      'GCC_WARN_FOUR_CHARACTER_CONSTANTS' => 'YES',
      'GCC_WARN_INITIALIZER_NOT_FULLY_BRACKETED' => 'YES',
      'GCC_WARN_SHADOW' => 'YES',
      'GCC_WARN_SIGN_COMPARE' => 'YES',
      'GCC_WARN_UNDECLARED_SELECTOR' => 'YES',
      'GCC_WARN_UNINITIALIZED_AUTOS' => 'YES_AGGRESSIVE',
      'GCC_WARN_UNKNOWN_PRAGMAS' => 'YES',
      'GCC_WARN_UNUSED_FUNCTION' => 'YES',
      'GCC_WARN_UNUSED_LABEL' => 'YES',
      'GCC_WARN_UNUSED_PARAMETER' => 'YES',
      'GCC_WARN_UNUSED_VARIABLE' => 'YES'})
  end
end
# vim:syntax=ruby:et:sts=2:sw=2:ts=2:ff=unix:
