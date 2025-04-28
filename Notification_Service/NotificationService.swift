//import UserNotifications
//import CleverTapSDK
//import CTNotificationService
//
//class NotificationService: UNNotificationServiceExtension {
//
//    var contentHandler: ((UNNotificationContent) -> Void)?
//    var bestAttemptContent: UNMutableNotificationContent?
//
//    override func didReceive(_ request: UNNotificationRequest,
//                              withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
//        self.contentHandler = contentHandler
//        self.bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent
//
//        let userInfo = request.content.userInfo
//        let isProvisional = userInfo["is_provisional"] as? Bool ?? false
//
//        if isProvisional {
//            // ✅ Track impression manually for provisional
//            CleverTap.sharedInstance()?.recordNotificationViewedEvent(withData: userInfo)
//            print("📬 Provisional push impression recorded manually.")
//            
//            // ✅ Return unmodified content to preserve "Keep"/"Turn Off"
//            contentHandler(request.content)
//        } else {
//            // ✅ For standard push, use CleverTap extension
//            let cleverTapExtension = CTNotificationServiceExtension()
//            cleverTapExtension.didReceive(request, withContentHandler: contentHandler)
//        }
//    }
//}

//-----------2nd code (for keep and turn off thing without unchecking the mutable content)
//import UserNotifications
//import CTNotificationService
//import CleverTapSDK
//
//class NotificationService: CTNotificationServiceExtension {
//    
//    var contentHandler: ((UNNotificationContent) -> Void)?
//    var bestAttemptContent: UNMutableNotificationContent?
//
//    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
//        self.contentHandler = contentHandler
//        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
//
//        // Check for provisional indicator in payload
//        let userInfo = request.content.userInfo
//        let isProvisional = userInfo["is_provisional"] as? Bool ?? false
//
//        if isProvisional {
//            // ✅ Don't modify content, so "Keep/Turn Off" shows
//            print("🔕 Provisional push detected, skipping modification.")
//            contentHandler(request.content)
//        } else {
//            // ✅ Record impression manually
//            CleverTap.sharedInstance()?.recordNotificationViewedEvent(withData: userInfo)
//
//            // ✅ Call super to let CT SDK modify the notification (rich media, etc.)
//            super.didReceive(request, withContentHandler: contentHandler)
//        }
//    }
//}

//--------------
//
//  NotificationService.swift
//  Notification_Service
//
//  Created by Aditya Sinha on 13/02/25.
//

import UserNotifications
import CTNotificationService
import CleverTapSDK

class NotificationService: CTNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        //Push Impression record
        CleverTap.sharedInstance()?.recordNotificationViewedEvent(withData: request.content.userInfo)
        super.didReceive(request, withContentHandler: contentHandler)
        
//        if let bestAttemptContent = bestAttemptContent {
//            // Modify the notification content here...
//            bestAttemptContent.title = "\(bestAttemptContent.title) [modified]"
//            
//            contentHandler(bestAttemptContent)
//        }
    }
    
//    override func serviceExtensionTimeWillExpire() {
//        // Called just before the extension will be terminated by the system.
//        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
//        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
//            contentHandler(bestAttemptContent)
//        }
//    }

}
