platform :ios, '13.0'
inhibit_all_warnings!
use_frameworks!

target 'Pan3' do
  pod 'IQKeyboardManagerSwift'
  pod 'SwifterSwift'
  pod 'Kingfisher'
  pod 'GRDB.swift'
  pod 'SwiftyJSON'
  pod 'Alamofire'
  pod 'MJRefresh'
  pod 'SnapKit'
  pod 'QMUIKit'
  #debug
  pod 'LookinServer', :configurations => ['Debug']
end

target 'Pan3PushService' do
  pod 'SwiftyJSON'
end

post_install do |installer|
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      end
    end
  end
end
