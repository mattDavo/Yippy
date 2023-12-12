# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'


project 'Yippy', {
  'Debug' => :debug,
  'Release' => :release,
  'Beta Debug' => :debug,
  'Beta Release' => :release,
  'XCTest' => :debug
}

target 'Yippy' do
    # Comment the next line if you don't want to use dynamic frameworks
    use_frameworks!

    # Pods for Yippy
    pod 'Default'
    pod 'LoginServiceKit', :git => 'https://github.com/Clipy/LoginServiceKit.git'
    pod 'RxSwift', '~> 6'
    pod 'RxCocoa', '~> 6'

    target 'YippyTests' do
        inherit! :search_paths
        # Pods for testing
        pod 'RxBlocking', '~> 6'
        pod 'RxTest', '~> 6'
        pod 'Default'
        pod 'LoginServiceKit', :git => 'https://github.com/Clipy/LoginServiceKit.git'
        pod 'RxSwift', '~> 6'
        pod 'RxCocoa', '~> 6'
    end

    target 'YippyUITests' do
        inherit! :search_paths
        # Pods for testing
        pod 'RxBlocking', '~> 6'
        pod 'RxTest', '~> 6'
        pod 'Default'
        pod 'LoginServiceKit', :git => 'https://github.com/Clipy/LoginServiceKit.git'
        pod 'RxSwift', '~> 6'
        pod 'RxCocoa', '~> 6'
    end
end
