//
//  PushManger.swift
//  CT_iOS
//
//  Created by Aditya Sinha on 21/04/25.
//
import Foundation
import UserNotifications
import UIKit
import CleverTapSDK

class PushManager: NSObject, UNUserNotificationCenterDelegate {
    
    static let shared = PushManager()
    
    private override init() {
            super.init()
        }
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().delegate = self
        updatePushCategory()
    }

//    // MARK: - Request Provisional Push Permission (iOS 12+)
    func requestProvisionalPushAuthorization() {
        
        UNUserNotificationCenter.current().delegate = self //Check this why its used?? does it need to be used in register for push
        var options: UNAuthorizationOptions = [.alert, .sound, .badge]
        
        if #available(iOS 12.0, *) {
            options.insert(.provisional)
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            if granted {
                print("✅ Push permission granted (may be provisional)")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                self.updatePushCategory()
            } else {
                print("❌ Push permission denied: \(error?.localizedDescription ?? "No error")")
                
            }
        }
    }
    // MARK: - Request Standard Push Permission (iOS 10+)
        func requestStandardPushAuthorization() {
            UNUserNotificationCenter.current().delegate = self
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    print("✅ Standard push permission granted")
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    self.updatePushCategory()
                } else {
                    print("❌ Standard push denied: \(error?.localizedDescription ?? "Unknown error")")
                    
//                    // Try Provisional Authorization as fallback
//                    if #available(iOS 12.0, *) {
//                        print("➡️ Trying Provisional Push Authorization fallback...")
//                        self.requestProvisionalPushAuthorization()
//                    }
                }
            }
        }


    // MARK: - Update 'push category' Multi-Value in CleverTap
    func updatePushCategory() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            var pushTypes = [String]()

            // Authorization Status
            switch settings.authorizationStatus {
            case .notDetermined:
                pushTypes.append("not_determined")
            case .denied:
                pushTypes.append("denied")
                
                let profile: Dictionary<String, AnyObject> = [
                    "MSG-push": false as AnyObject,
                ]
                CleverTap.sharedInstance()?.profilePush(profile)
            case .authorized:
                pushTypes.append("authorized")
                
                let profile: Dictionary<String, AnyObject> = [
                    "MSG-push": true as AnyObject,
                ]
                CleverTap.sharedInstance()?.profilePush(profile)
            case .provisional:
                pushTypes.append("provisional")
            case .ephemeral:
                pushTypes.append("ephemeral")
            @unknown default:
                pushTypes.append("unknown")
            }
            print("Auth: \(settings.authorizationStatus.rawValue)")

            // Specific Permissions
            if settings.badgeSetting == .enabled {
                pushTypes.append("Badge")
                print("Badge: \(settings.badgeSetting.rawValue)")
            }
            if settings.soundSetting == .enabled {
                pushTypes.append("Sound")
                print("Sound: \(settings.soundSetting.rawValue)")
            }
            
            // MARK: - Notification Display Preferences (Simplified)
            var displayPreferences = [String]()

            if settings.notificationCenterSetting == .enabled {
                displayPreferences.append("Non-Alert Notification")
                print("✅ Notification Centre: \(settings.notificationCenterSetting.rawValue)")
            }

            if settings.lockScreenSetting == .enabled {
                displayPreferences.append("Lock-Screen Notification")
                print("✅ Lock Screen Notification: \(settings.lockScreenSetting.rawValue)")
            }

            if settings.alertSetting == .enabled {
                displayPreferences.append("Banner Notification")
                print("✅ Alert (Banner): \(settings.alertSetting.rawValue)")
            }

            // If all 3 display options are ON, simplify to "Alert"
            let allDisplayEnabled = settings.notificationCenterSetting == .enabled &&
                                    settings.lockScreenSetting == .enabled &&
                                    settings.alertSetting == .enabled

            if allDisplayEnabled {
                displayPreferences.removeAll()
                displayPreferences.append("Alert")
                print("📣 All display preferences enabled — collapsing to 'Alert'")
            }

            // Merge display prefs into overall pushTypes
            pushTypes.append(contentsOf: displayPreferences)
            
            // New: Track alert style
//                    switch settings.alertStyle {
//                    case .none:
//                        pushTypes.append("alertStyle_none")
//                    case .banner:
//                        pushTypes.append("alertStyle_banner")
//                    case .alert:
//                        pushTypes.append("alertStyle_alert")
//                    @unknown default:
//                        pushTypes.append("alertStyle_unknown")
//                    }
            

            // Update CleverTap Profile
            DispatchQueue.main.async {
                CleverTap.sharedInstance()?.profileSetMultiValues(pushTypes, forKey: "push category")
                print("📬 CleverTap Push Category Updated: \(pushTypes)")
            }
        }
    }
    
    // Called when the app fails to register for remote (push) notifications
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("Failed to register for remote notifications: %@", error.localizedDescription)
    }
    // Called when the app successfully registers for remote notifications and receives a device token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NSLog("Registered for remote notifications: %@", deviceToken.description)
    }

    // Called when the user taps on a push notification while the app is in the background or terminated
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // Logs the notification payload
        NSLog("Push notification tapped: %@", response.notification.request.content.userInfo)
        
        // Informs CleverTap that the notification was tapped (for engagement tracking)
        CleverTap.sharedInstance()?.handleNotification(withData: response.notification.request.content.userInfo)
        
        // Must call the completion handler
        completionHandler()
    }

    // Called when a push notification is received while the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Logs the notification payload received in foreground
        NSLog("Push received while app is in foreground: %@", notification.request.content.userInfo)
        
        // Informs CleverTap that the notification was viewed (only works when app is in foreground)
        CleverTap.sharedInstance()?.recordNotificationViewedEvent(withData: notification.request.content.userInfo)
        
        // Tells iOS to present the notification with alert, sound, and badge even in foreground
        completionHandler([.badge, .sound, .alert])
    }
    // Called when a remote push notification is received in the background (silent push or content-available)
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NSLog("Received background push notification: %@", userInfo)
        CleverTap.sharedInstance()?.recordNotificationViewedEvent(withData: userInfo)
        completionHandler(.newData)
    }
    
//    func application(_ application: UIApplication,
//                         didReceiveRemoteNotification userInfo: [AnyHashable: Any],
//                         fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
//            NSLog("Received background push notification: %@", userInfo)
//            PushManager.shared.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
//        }
}

