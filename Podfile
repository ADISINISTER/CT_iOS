# Uncomment the next line to define a global platform for your project
 platform :ios, '16.0'

target 'CT_iOS' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for CT_iOS
  pod 'CleverTap-iOS-SDK'
  pod 'CleverTapLocation'
  pod 'CleverTap-Geofence-SDK'
  pod 'mParticle-CleverTap'
  post_install do |installer_representation|
      installer_representation.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'CLEVERTAP_HOST_WATCHOS=1']
        end
      end
    end

  target 'Notification_Service' do
    pod 'CTNotificationService'
    pod 'CleverTap-iOS-SDK'
  end
  
  target 'Notification_Content' do
    pod 'CTNotificationContent'
#    pod 'CleverTap-iOS-SDK'
  end

  target 'CT_iOSTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'CT_iOSUITests' do
    # Pods for testing
  end

end
