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

class PushManager {
    
    static let shared = PushManager()
    
    private init() {}
    
    // MARK: - Request Provisional Push Permission (iOS 12+)
    func requestProvisionalPushAuthorization() {
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
//                       let allDisabled = settings.alertSetting == .disabled &&
//                                         settings.badgeSetting == .disabled &&
//                                         settings.soundSetting == .disabled
//                       if allDisabled {
//                           pushTypes.append("effectively_disabled")  // Optional tag
//                       } else {
                           pushTypes.append("authorized")
//                       }
            case .provisional:
                pushTypes.append("provisional")
            case .ephemeral:
                pushTypes.append("ephemeral")
            @unknown default:
                pushTypes.append("unknown")
            }
            print("Auth: \(settings.authorizationStatus.rawValue)")

            // Specific Permissions
            if settings.alertSetting == .enabled {
                pushTypes.append("alert")
                print("Alert: \(settings.alertSetting.rawValue)")
            }
            if settings.badgeSetting == .enabled {
                pushTypes.append("badge")
                print("Sound: \(settings.soundSetting.rawValue)")
            }
            if settings.soundSetting == .enabled {
                pushTypes.append("sound")
                print("Badge: \(settings.badgeSetting.rawValue)")
            }

            // Update CleverTap Profile
            DispatchQueue.main.async {
                CleverTap.sharedInstance()?.profileSetMultiValues(pushTypes, forKey: "push category")
                print("📬 CleverTap Push Category Updated: \(pushTypes)")
            }
        }
    }
}

