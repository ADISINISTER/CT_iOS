//////
//////  AppDelegate.swift
//////  CT_iOS
//////
//////  Created by Aditya Sinha on 10/02/25.
//////

import UIKit
import CleverTapSDK
import CleverTapLocation
import CoreLocation
import UserNotifications
import CleverTapGeofence
import mParticle_Apple_SDK
import WebKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, CleverTapURLDelegate {
    
    var window: UIWindow?
    private let hasSeenPushPermissionDialogKey = "hasSeenPushPermissionDialog"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // CleverTap Initialization
        CleverTap.autoIntegrate()
        CleverTap.setDebugLevel(CleverTapLogLevel.debug.rawValue)
        CleverTap.sharedInstance()?.setUrlDelegate(self)

        // Push Notification Setup
        UNUserNotificationCenter.current().delegate = self  //?? understand this why its here???
        updatePushCategory()

        // Only show the dialog once
        if !UserDefaults.standard.bool(forKey: hasSeenPushPermissionDialogKey) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.showPushPermissionDialog(from: application)
            }
        }

        // Geofence SDK Init
        CleverTapGeofence.monitor.start(didFinishLaunchingWithOptions: launchOptions)

        // Location Permissions
        let locationManager = CLLocationManager()
        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()

        return true
    }
    // Update push category info when app comes to foreground
    func applicationWillEnterForeground(_ application: UIApplication) {
        updatePushCategory()
    }

    // MARK: - Push Notification Registration
    // Request for provisional push permissions (iOS 12+)
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
    // Request standard (regular) push notification permissions
    func requestStandardPushAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Standard push permission granted")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                self.updatePushCategory()
            } else {
                print("❌ Standard push permission denied: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    // MARK: - Push Notification Handling
    
    // Called when successfully registered for APNs
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NSLog("Registered for remote notifications: %@", deviceToken.description)
    }
    // Called when registration for push fails
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("Failed to register for remote notifications: %@", error.localizedDescription)
    }
    // Called when a push notification is received in background or terminated state
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        NSLog("Received background push notification: %@", userInfo)
//        CleverTap.sharedInstance()?.recordNotificationViewedEvent(withData: userInfo) //!!here it does not record or handle the background thing for that you have to trigger nse class
        completionHandler(.newData)
    }
    
    // Called when a notification is received while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        NSLog("Push received while app is in foreground: %@", notification.request.content.userInfo)
        CleverTap.sharedInstance()?.recordNotificationViewedEvent(withData: notification.request.content.userInfo) //if mutable is off
        completionHandler([.badge, .sound, .alert])// Display notification as usual
    }

    // Called when user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        NSLog("Push notification tapped: %@", response.notification.request.content.userInfo)
        CleverTap.sharedInstance()?.handleNotification(withData: response.notification.request.content.userInfo)
//        CleverTap.sharedInstance()?.recordNotificationViewedEvent(withData: response.notification.request.content.userInfo)//!!It does not work (similar to background thing)
        completionHandler()
    }

    // MARK: - CleverTapURLDelegate
    // Handle deep links or CleverTap campaign URLs
    func shouldHandleCleverTap(_ url: URL?, for channel: CleverTapChannel) -> Bool {
        print("Handling CleverTap URL: \(url?.absoluteString ?? "") for channel: \(channel)")
        return true
    }

    // MARK: - Push Category Update
    // Track push notification settings and update CleverTap user profile
    func updatePushCategory() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            var pushTypes = [String]()

            switch settings.authorizationStatus {
            case .notDetermined: pushTypes.append("not_determined")
            case .denied:
                pushTypes.append("denied")
                let profile: [String: AnyObject] = ["MSG-push": false as AnyObject]
                CleverTap.sharedInstance()?.profilePush(profile)
            case .authorized:
                pushTypes.append("authorized")
                let profile: [String: AnyObject] = ["MSG-push": true as AnyObject]
                CleverTap.sharedInstance()?.profilePush(profile)
            case .provisional: pushTypes.append("provisional")
            case .ephemeral: pushTypes.append("ephemeral")
            @unknown default: pushTypes.append("unknown")
            }

            // Append detailed push settings (sound, badge, display)
            if settings.badgeSetting == .enabled { pushTypes.append("Badge") }
            if settings.soundSetting == .enabled { pushTypes.append("Sound") }

            var displayPreferences = [String]()
            if settings.notificationCenterSetting == .enabled { displayPreferences.append("Non-Alert Notification") }
            if settings.lockScreenSetting == .enabled { displayPreferences.append("Lock-Screen Notification") }
            if settings.alertSetting == .enabled { displayPreferences.append("Banner Notification") }

            if settings.notificationCenterSetting == .enabled && settings.lockScreenSetting == .enabled && settings.alertSetting == .enabled {
                displayPreferences = ["Alert"]// If all are enabled, simplify
            }

            pushTypes.append(contentsOf: displayPreferences)

            // Update CleverTap profile with categorized push settings
            DispatchQueue.main.async {
                CleverTap.sharedInstance()?.profileSetMultiValues(pushTypes, forKey: "push category")
                print("📬 CleverTap Push Category Updated: \(pushTypes)")
            }
        }
    }

    // MARK: - Show Custom Push Permission Dialog
    // Show a custom dialog asking user to choose between standard or provisional notification
    func showPushPermissionDialog(from application: UIApplication) {
        guard let window = application.windows.first,
              let rootViewController = window.rootViewController else { return }

        let alertController = UIAlertController(title: "Enable Notifications",
                                                message: "Choose how you want to receive notifications.",
                                                preferredStyle: .alert)

        let allowAction = UIAlertAction(title: "Standard Allow", style: .default) { _ in
            self.requestStandardPushAuthorization()
        }

        let provisionalAllowAction = UIAlertAction(title: "Provisional Allow", style: .default) { _ in
            self.requestProvisionalPushAuthorization()
        }

        alertController.addAction(allowAction)
        alertController.addAction(provisionalAllowAction)

        rootViewController.present(alertController, animated: true, completion: nil)

        // Save a flag so the dialog doesn't appear again
        UserDefaults.standard.set(true, forKey: hasSeenPushPermissionDialogKey)
    }
}

///-------------------------------------------------IMPORTANT
//
///
//////  AppDelegate.swift
//////  CT_iOS
//////
//////  Created by Aditya Sinha on 10/02/25.
//////
//import UIKit
//import CleverTapSDK
//import CleverTapLocation
//import CoreLocation
//import UserNotifications
//import CleverTapGeofence
//import mParticle_Apple_SDK
//
//
//@main
//
//class AppDelegate: UIResponder, UIApplicationDelegate, /*UNUserNotificationCenterDelegate, */ CleverTapURLDelegate {
//    
//    var webView: WKWebView?
//    
//    // Flag to check if the dialog has been shown
//        private let hasSeenPushPermissionDialogKey = "hasSeenPushPermissionDialog"
//
//    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//
//        // Push Notification Registration
///*    -------*/    /*registerForPush()*/
//        
//        
//        
//        // CleverTap Initialization
//        CleverTap.autoIntegrate()
//        CleverTap.setDebugLevel(CleverTapLogLevel.debug.rawValue)
//        CleverTap.sharedInstance()?.setUrlDelegate(self)
//    
//////Push Primer
////
////        let localInAppBuilder = CTLocalInApp(inAppType: .ALERT,
////                                             titleText: "Get Notified",
////                                             messageText: "Enable Notification permission",
////                                             followDeviceOrientation: true,
////                                             positiveBtnText: "Allow",
////                                             negativeBtnText: "Cancel")
////
////        // Optional fields.
////        localInAppBuilder.setFallbackToSettings(true)
////
////        // Prompt Push Primer with above settings.
////        CleverTap.sharedInstance()?.promptPushPrimer(localInAppBuilder.getSettings())
//        
//    // Geofence SDK Init ---------UNCOMMENT THIS
//        CleverTapGeofence.monitor.start(didFinishLaunchingWithOptions: launchOptions)
//        
//    // Location Permissions ---------UNCOMMENT THIS
//        let locationManager = CLLocationManager()
//        locationManager.requestAlwaysAuthorization()
//        locationManager.requestWhenInUseAuthorization()
//        
//        // Setup CleverTap JS Interface
//        let ctInterface = CleverTapJSInterface(config: nil)!
//        self.webView?.configuration.userContentController.add(ctInterface, name: "clevertap")
//
//        // Register Push Notification Actions
//        let action1 = UNNotificationAction(identifier: "action_1", title: "Back", options: [])
//        let category = UNNotificationCategory(identifier: "CTNotification", actions: [action1], intentIdentifiers: [], options: [])
//        UNUserNotificationCenter.current().setNotificationCategories([category])
//        
//        UNUserNotificationCenter.current().delegate = PushManager.shared  //?? understand this why its here???
//        PushManager.shared.registerForPushNotifications() //changed here check
//        
//        // Only show the dialog once
//               if !UserDefaults.standard.bool(forKey: hasSeenPushPermissionDialogKey) {
//                   DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                       self.showPushPermissionDialog(from: application)
//                   }
//               }
//        
////        PushManager.shared.requestStandardPushAuthorization()
////        PushManager.shared.requestProvisionalPushAuthorization()
//
//
//        
//        return true
//    }
//    
//    //-------
//    // MARK: - Show Custom Push Permission Dialog
//       func showPushPermissionDialog(from application: UIApplication) {
//           guard let window = application.windows.first else { return }
//           
//           // Ensure we get the root view controller
//           guard let rootViewController = window.rootViewController else { return }
//           
//           // Create and present the alert
//           let alertController = UIAlertController(title: "Enable Notifications",
//                                                   message: "Choose how you want to receive notifications.",
//                                                   preferredStyle: .alert)
//           
//           let allowAction = UIAlertAction(title: "Standard Allow", style: .default) { _ in
//               PushManager.shared.requestStandardPushAuthorization()
//           }
//           
//           let provisionalAllowAction = UIAlertAction(title: "Provisional Allow", style: .default) { _ in
//               PushManager.shared.requestProvisionalPushAuthorization()
//           }
//           
////           let dontAllowAction = UIAlertAction(title: "Don't Allow", style: .destructive) { _ in
////               print("User chose to deny push notifications.")
////           }
//           
//           alertController.addAction(allowAction)
//           alertController.addAction(provisionalAllowAction)
////           alertController.addAction(dontAllowAction)
//
//           // Present the alert on the root view controller
//           rootViewController.present(alertController, animated: true, completion: nil)
//
//           // Mark the dialog as shown so it doesn't show again
//           UserDefaults.standard.set(true, forKey: hasSeenPushPermissionDialogKey)
//       }
//
//
//    // MARK: - CleverTapURLDelegate
//    public func shouldHandleCleverTap(_ url: URL?, for channel: CleverTapChannel) -> Bool {
//        print("Handling CleverTap URL: \(url?.absoluteString ?? "") for channel: \(channel)")
//        return true
//    }
//    
//    func applicationWillEnterForeground(_ application: UIApplication) {
//        PushManager.shared.updatePushCategory()
//        
//    }
//--------------------------------------------------------------------------
//      //--------change here
//    // MARK: - Push Notification Setup
////    func registerForPush() {
////        UNUserNotificationCenter.current().delegate = self
////        UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .badge, .alert]) { granted, _ in
////            if granted {
////                DispatchQueue.main.async {
////                    UIApplication.shared.registerForRemoteNotifications()
////                }
////            }
////        }
////    }
//    //--------------------- Below handling code is transfered to pushmanager
////    // Called when the app fails to register for remote (push) notifications
////    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
////        NSLog("Failed to register for remote notifications: %@", error.localizedDescription)
////    }
////    // Called when the app successfully registers for remote notifications and receives a device token
////    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
////        NSLog("Registered for remote notifications: %@", deviceToken.description)
////    }
////
////    // Called when the user taps on a push notification while the app is in the background or terminated
////    func userNotificationCenter(_ center: UNUserNotificationCenter,
////                                didReceive response: UNNotificationResponse,
////                                withCompletionHandler completionHandler: @escaping () -> Void) {
////        // Logs the notification payload
////        NSLog("Push notification tapped: %@", response.notification.request.content.userInfo)
////        
////        // Informs CleverTap that the notification was tapped (for engagement tracking)
////        CleverTap.sharedInstance()?.handleNotification(withData: response.notification.request.content.userInfo)
////        
////        // Must call the completion handler
////        completionHandler()
////    }
////
////    // Called when a push notification is received while the app is in the foreground
////    func userNotificationCenter(_ center: UNUserNotificationCenter,
////                                willPresent notification: UNNotification,
////                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
////        // Logs the notification payload received in foreground
////        NSLog("Push received while app is in foreground: %@", notification.request.content.userInfo)
////        
////        // Informs CleverTap that the notification was viewed (only works when app is in foreground)
////        CleverTap.sharedInstance()?.recordNotificationViewedEvent(withData: notification.request.content.userInfo)
////        
////        // Tells iOS to present the notification with alert, sound, and badge even in foreground
////        completionHandler([.badge, .sound, .alert])
////    }
////    // Called when a remote push notification is received in the background (silent push or content-available)
////    func application(_ application: UIApplication,
////                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
////                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
////        NSLog("Received background push notification: %@", userInfo)
////        completionHandler(.noData)
////    }
//    // MARK: - CleverTap Push Notification Delegate
//
////    func pushNotificationTapped(withCustomExtras customExtras: [AnyHashable : Any]!) {
////            print("Push Notification Tapped with Custom Extras: \(customExtras ?? [:])")
////            
////            // Example: Handle navigation based on custom extras
////            if let screen = customExtras["navigateTo"] as? String {
////                print("Navigate to screen: \(screen)")
////                // You can post a NotificationCenter event or call a coordinator to handle navigation
////        }
////    }
//    //----------------------------
//
//}
//
//
////-----------OLD CODE (10/04/25)-----------------
////import UIKit
//////import WebKit
////import CleverTapSDK
////import CleverTapLocation
////import CoreLocation
////import UserNotifications
////import CleverTapGeofence
////import mParticle_Apple_SDK
////import Foundation
////
//////import CleverTapJSInterface
////
////@main
////class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, CleverTapURLDelegate {
////
////    var webView: WKWebView?
////    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
////        // Override point for customization after application launch.
////        // register for push notifications
////                registerForPush()
////        CleverTap.autoIntegrate()
////        CleverTap.setDebugLevel(CleverTapLogLevel.debug.rawValue)
////        CleverTap.sharedInstance()?.setUrlDelegate(self)
////        CleverTapGeofence.monitor.start(didFinishLaunchingWithOptions: launchOptions) // Initialize Geofence SDK
////        let locationManager = CLLocationManager()
////        locationManager.requestAlwaysAuthorization()
////        locationManager.requestWhenInUseAuthorization()
//////        let profile: Dictionary<String, AnyObject> = [
//////            //Update pre-defined profile properties
//////            "Name": "Aditya Raj Sinha" as AnyObject,
//////            "Email": "rohan@gmail.com" as AnyObject,
//////              "Identity": 98221 as AnyObject,
//////            //Update custom profile properties
//////            "Plan type": "Silver" as AnyObject,
//////            "Favorite Food": "Pizza" as AnyObject,
//////        ]
////        
////        recordUserChargedEvent()
////        
//////        Inititialize the Webview and add the CleverTapJSInterface as a script message handler
////        
////        let ctInterface: CleverTapJSInterface = CleverTapJSInterface(config: nil)
////        
////        self.webView?.configuration.userContentController.add(ctInterface, name: "clevertap");
////        // register category with actions
////            let action1 = UNNotificationAction(identifier: "action_1", title: "Back", options: [])
////            let action2 = UNNotificationAction(identifier: "action_2", title: "Next", options: [])
////            let action3 = UNNotificationAction(identifier: "action_3", title: "View In App", options: [])
////            let category = UNNotificationCategory(identifier: "CTNotification", actions: [action1], intentIdentifiers: [], options: [])
////            UNUserNotificationCenter.current().setNotificationCategories([category])
////        
////       
//////         each of the below mentioned fields are optional
//////         if set, these populate demographic information in the Dashboard
////        let dob = NSDateComponents()
////        dob.day = 24
////        dob.month = 5
////        dob.year = 1992
////        let calendar = Calendar.current
////        let d = calendar.date(from: dob as DateComponents)
////        let profile: Dictionary<String, AnyObject> = [
////            "Name": "Aditya Raj Sinha" as AnyObject,                 // String
////            "Identity": 8275 as AnyObject,                   // String or number
////            "Email": "addy3503@gmail.com" as AnyObject,              // Email address of the user
////            "Phone": "+9135878442" as AnyObject,                // Phone (with the country code, starting with +)
////            "Gender": "M" as AnyObject,                          // Can be either M or F
////            "DOB": d! as AnyObject,                              // Date of Birth. An NSDate object
////            "Age": 28 as AnyObject,                              // Not required if DOB is set
////            "Photo":"https://avatar.iran.liara.run/public/boy?username=Ash" as AnyObject,   // URL to the Image
////
//////         optional fields. controls whether the user will be sent email, push etc.
////            "MSG-email": false as AnyObject,                     // Disable email notifications
////            "MSG-push": true as AnyObject,                       // Enable push notifications
////            "MSG-sms": false as AnyObject,                       // Disable SMS notifications
////            "MSG-dndPhone": true as AnyObject,                   // Opt out phone number from SMS notifications
////            "MSG-dndEmail": true as AnyObject,                   // Opt out email from email notifications
////        ]
////
////        CleverTap.sharedInstance()?.profilePush(profile)
////
////        // Event with properties
////        let props: [String: Any] = [
////            "Product name": "Casio Chronograph Watch",
////            "Category": "Mens Accessories",
////            "Price": 59.99,
////            "Date": NSDate() // Current date and time
////        ]
////
////        // Record the event with properties
////        CleverTap.sharedInstance()?.recordEvent("Product viewed", withProps: props)
////        return true
////    }
////    
////        
////        
////    
////    // MARK: - CleverTapURLDelegate method to handle deep links
//////    public func shouldHandleCleverTap(_ url: URL?, for channel: CleverTapChannel) -> Bool {
//////            guard let urlString = url?.absoluteString else { return false }
//////            print("Handling CleverTap URL: \(urlString) from channel: \(channel)")
//////
//////            // Custom deep link handling
////////            handleDeepLink(urlString)
//////
//////            return true // Return true if handled, false if you want CleverTap to handle it.
//////        }
//////    func handleDeepLink(_ urlString: String) {
//////           if urlString.contains("CT_iOS://Window") {
//////               ButtonWindow()
//////           } else {
//////               // Open in Safari as fallback
//////               if let url = URL(string: urlString) {
//////                   UIApplication.shared.open(url, options: [:], completionHandler: nil)
//////               }
//////           }
//////       }
//////    func ButtonWindow() {
//////        print("Navigating to Button Window")
//////        
//////        // Get the main storyboard
//////        let storyboard = UIStoryboard(name: "Main", bundle: nil)
//////        
//////        // Instantiate the ButtonWindowViewController (replace with your actual ViewController identifier)
//////        if let buttonVC = storyboard.instantiateViewController(withIdentifier: "ViewController") as? ViewController{
//////            
//////            // Get the root navigation controller
//////            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
//////                rootVC.present(buttonVC, animated: true, completion: nil)
//////            }
//////        }
//////    }
//////    func Window() {
//////            print("Navigating to Profile Screen")
//////            // Add navigation logic
//////        }
////
////
////
////    // CleverTapURLDelegate method
////    public func shouldHandleCleverTap(_ url: URL?, for channel: CleverTapChannel) -> Bool {
////        print("Handling URL: \(url!) for channel: \(channel)")
////        return true
////    }
////    //-----------------------------------------
////    func recordUserChargedEvent() {
////           // Transaction details
////           let chargeDetails: [String: Any] = [
////               "Amount": 300,
////               "Payment mode": "Credit Card",
////               "Charged ID": 24052013
////           ]
////           
////           // Items sold
////           let item1: [String: Any] = [
////               "Category": "books",
////               "Book name": "The Millionaire next door",
////               "Quantity": 1
////           ]
////           
////           let item2: [String: Any] = [
////               "Category": "books",
////               "Book name": "Achieving inner zen",
////               "Quantity": 1
////           ]
////           
////           let item3: [String: Any] = [
////               "Category": "books",
////               "Book name": "Chuck it, let's do it",
////               "Quantity": 5
////           ]
////           
////           // Record the Charged event with transaction details and items
////           CleverTap.sharedInstance()?.recordChargedEvent(withDetails: chargeDetails, andItems: [item1, item2, item3])
////       }
////
////    // MARK: UISceneSession Lifecycle
////    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
////        switch status {
////        case .authorizedAlways:
////            print("Always Authorized: Start geofencing.")
////        case .authorizedWhenInUse:
////            print("When In Use Authorized: Limited geofencing possible.")
////        case .denied, .restricted:
////            print("Location access denied.")
////        default:
////            break
////        }
////    }
////
////    func inAppNotificationButtonTapped(withCustomExtras customExtras: [AnyHashable: Any]!) {
////        print("In-App Notification Button Tapped with Custom Extras: \(customExtras ?? [:])")
////        // Handle the button click event here
////    }
////
////    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
////        // Called when a new scene session is being created.
////        // Use this method to select a configuration to create the new scene with.
////        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
////    }
////
////    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
////        // Called when the user discards a scene session.
////        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
////        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
////    }
////    func registerForPush() {
////            // Register for Push notifications
////            UNUserNotificationCenter.current().delegate = self
////            // request Permissions
////            UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .badge, .alert], completionHandler: {granted, error in
////                if granted {
////                    DispatchQueue.main.async {
////                        UIApplication.shared.registerForRemoteNotifications()
////                    }
////                }
////            })
////        }
////
////        // Handle push registration failure
////        func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
////            NSLog(" Failed to register for remote notifications: %@", error.localizedDescription)
////        }
////
////        // Handle successful push registration
////        func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
////            NSLog("Registered for remote notifications: %@", deviceToken.description)
////        }
////
////        // Handle push tap action (when user interacts with notification)
////        func userNotificationCenter(_ center: UNUserNotificationCenter,
////                                    didReceive response: UNNotificationResponse,
////                                    withCompletionHandler completionHandler: @escaping () -> Void) {
////            NSLog("Push notification tapped: %@", response.notification.request.content.userInfo)
////            CleverTap.sharedInstance()?.handleNotification(withData: response.notification.request.content.userInfo)
////            completionHandler()
////        }
////
////        // Handle foreground push notification (when app is open)
////        func userNotificationCenter(_ center: UNUserNotificationCenter,
////                                    willPresent notification: UNNotification,
////                                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
////            NSLog("Push received while app is in foreground: %@", notification.request.content.userInfo)
////            CleverTap.sharedInstance()?.recordNotificationViewedEvent(withData: notification.request.content.userInfo)
////            completionHandler([.badge, .sound, .alert])
////        }
////
////        // Handle background push notification
////        func application(_ application: UIApplication,
////                         didReceiveRemoteNotification userInfo: [AnyHashable : Any],
////                         fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
////            NSLog("Received background push notification: %@", userInfo)
////            completionHandler(.noData)
////        }
////
////        // Handle custom extra data in push notification
////        func pushNotificationTapped(withCustomExtras customExtras: [AnyHashable : Any]!) {
////            NSLog(" Push notification customExtras: %@", customExtras)
////        }
////
////        // Register push notification delegate
////        func registerForPushNotifications() {
////            let center = UNUserNotificationCenter.current()
////            center.delegate = self
////            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
////                if granted {
////                    DispatchQueue.main.async {
////                        UIApplication.shared.registerForRemoteNotifications()
////                    }
////                } else {
////                    NSLog(" Push notifications permission denied.")
////                }
////            }
////        }
////    }
//// -------------------------------------------------
//
//
//
//
//
//
//
////OlD CODE:...................................(2/04/)
//////
//////  AppDelegate.swift
//////  CT_iOS
//////
//////  Created by Aditya Sinha on 10/02/25.
//////
////
////import UIKit
//////import WebKit
////import CleverTapSDK
////import CleverTapLocation
////import CoreLocation
////import UserNotifications
////import CleverTapGeofence
////import mParticle_Apple_SDK
////import Foundation
////
//////import CleverTapJSInterface
////
////@main
////class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, CleverTapURLDelegate {
////
////    // For mparticle
//////    static var shouldShowCredsAlert: Bool = false
//////    static var eventsBeginSessions: Bool = true
////
////
////    var webView: WKWebView?
////    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
////        // Override point for customization after application launch.
////        // register for push notifications
////                registerForPush()
////        CleverTap.autoIntegrate()
////        CleverTap.setDebugLevel(CleverTapLogLevel.debug.rawValue)
////        CleverTap.sharedInstance()?.setUrlDelegate(self)
////        CleverTapGeofence.monitor.start(didFinishLaunchingWithOptions: launchOptions) // Initialize Geofence SDK
////        let locationManager = CLLocationManager()
////        locationManager.requestAlwaysAuthorization()
////        locationManager.requestWhenInUseAuthorization()
////        let profile: Dictionary<String, AnyObject> = [
////            //Update pre-defined profile properties
////            "Name": "Aditya Raj Sinha" as AnyObject,
////            "Email": "rohan@gmail.com" as AnyObject,
////              "Identity": 98221 as AnyObject,
////            //Update custom profile properties
////            "Plan type": "Silver" as AnyObject,
////            "Favorite Food": "Pizza" as AnyObject,
////        ]
////        CleverTap.sharedInstance()?.onUserLogin(profile)
////        if let key = ProcessInfo.processInfo.environment["MPARTICLE_KEY"],
////           let secret = ProcessInfo.processInfo.environment["MPARTICLE_SECRET"] {
////            
////            let options = MParticleOptions(key: key, secret: secret)
////            MParticle.sharedInstance().start(with: options)
////        } else {
////            print("Error: mParticle API key and secret are missing from environment variables.")
////        }
////        
//////        let options = MParticleOptions(key: "us1-276550cf7d56bd4788376b2044761ae3", secret: "lF1KDJ4Io4vk4qwNNLQraDuwT9eeYmskRKKcK3Ze-T2VxS9MlxRFJVhc2nzDQ7p_")
//////        MParticle.sharedInstance().start(with: options)
//////        let event = MPEvent(name: "Test Event", type: MPEventType.other)
//////        MParticle.sharedInstance().logEvent(event!)
////        if let event = MPEvent(name: "Video Watched", type: .navigation) {
////            event.customAttributes = ["category": "Destination Intro", "title": "Paris"]
////            MParticle.sharedInstance().logEvent(event)
////        }
////        
////        var identityRequest = MPIdentityApiRequest.withCurrentUser()
////        // The MPIdentityApiRequest provides convenience methods for common identifiers like email and customerIDs
////        identityRequest.email = "foo@example.com"
////        identityRequest.customerId = "123456"
////        
//////        recordUserChargedEvent()
////        
////        //Inititialize the Webview and add the CleverTapJSInterface as a script message handler
////        
////        let ctInterface: CleverTapJSInterface = CleverTapJSInterface(config: nil)
////        
////        self.webView?.configuration.userContentController.add(ctInterface, name: "clevertap");
////        // register category with actions
//////            let action1 = UNNotificationAction(identifier: "action_1", title: "Back", options: [])
//////            let action2 = UNNotificationAction(identifier: "action_2", title: "Next", options: [])
////            let action1 = UNNotificationAction(identifier: "action_1", title: "View In App", options: [])
////            let category = UNNotificationCategory(identifier: "CTNotification", actions: [action1], intentIdentifiers: [], options: [])
////            UNUserNotificationCenter.current().setNotificationCategories([category])
////        
////        return true
////    }
////        // each of the below mentioned fields are optional
////        // if set, these populate demographic information in the Dashboard
//////        let dob = NSDateComponents()
//////        dob.day = 24
//////        dob.month = 5
//////        dob.year = 1992
//////        let calendar = Calendar.current
//////        let d = calendar.date(from: dob as DateComponents)
//////        let profile: Dictionary<String, AnyObject> = [
//////            "Name": "Aditya Raj Sinha" as AnyObject,                 // String
//////            "Identity": 8275 as AnyObject,                   // String or number
//////            "Email": "addy3503@gmail.com" as AnyObject,              // Email address of the user
//////            "Phone": "+9135878442" as AnyObject,                // Phone (with the country code, starting with +)
//////            "Gender": "M" as AnyObject,                          // Can be either M or F
//////            "DOB": d! as AnyObject,                              // Date of Birth. An NSDate object
//////            "Age": 28 as AnyObject,                              // Not required if DOB is set
//////            "Photo": "https://cdn.pixabay.com/photo/2021/07/02/04/48/user-6380868_1280.png" as AnyObject,   // URL to the Image
//////
////////         optional fields. controls whether the user will be sent email, push etc.
//////            "MSG-email": false as AnyObject,                     // Disable email notifications
//////            "MSG-push": true as AnyObject,                       // Enable push notifications
//////            "MSG-sms": false as AnyObject,                       // Disable SMS notifications
//////            "MSG-dndPhone": true as AnyObject,                   // Opt out phone number from SMS notifications
//////            "MSG-dndEmail": true as AnyObject,                   // Opt out email from email notifications
//////        ]
//////
//////        CleverTap.sharedInstance()?.profilePush(profile)
//////
//////        // Event with properties
//////        let props: [String: Any] = [
//////            "Product name": "Casio Chronograph Watch",
//////            "Category": "Mens Accessories",
//////            "Price": 59.99,
//////            "Date": NSDate() // Current date and time
//////        ]
//////
//////        // Record the event with properties
//////        CleverTap.sharedInstance()?.recordEvent("Product viewed", withProps: props)
////
////       
//////You can create additional instances pointing to a different CleverTap account. These instances are initialized using a CleverTapInstanceConfig object, where you can set the identityKeys property to an array of identifiers.
////
//////        let ctConfig = CleverTapInstanceConfig.init(accountId: "ACCOUNT_ID", accountToken: "ACCOUNT_TOKEN")
//////        ctConfig.identityKeys = ["Phone", "Email"]
//////        let additionalInstance = CleverTap.instance(with: ctConfig)
//////   ----------------------------------------------------------
////        
////        
////    
////    // MARK: - CleverTapURLDelegate method to handle deep links
////    public func shouldHandleCleverTap(_ url: URL?, for channel: CleverTapChannel) -> Bool {
////            guard let urlString = url?.absoluteString else { return false }
////            print("Handling CleverTap URL: \(urlString) from channel: \(channel)")
////
////            // Custom deep link handling
//////            handleDeepLink(urlString)
////
////            return true // Return true if handled, false if you want CleverTap to handle it.
////        }
//////    func handleDeepLink(_ urlString: String) {
//////           if urlString.contains("CT_iOS://Window") {
//////               ButtonWindow()
//////           } else {
//////               // Open in Safari as fallback
//////               if let url = URL(string: urlString) {
//////                   UIApplication.shared.open(url, options: [:], completionHandler: nil)
//////               }
//////           }
//////       }
//////    func ButtonWindow() {
//////        print("Navigating to Button Window")
//////
//////        // Get the main storyboard
//////        let storyboard = UIStoryboard(name: "Main", bundle: nil)
//////
//////        // Instantiate the ButtonWindowViewController (replace with your actual ViewController identifier)
//////        if let buttonVC = storyboard.instantiateViewController(withIdentifier: "ViewController") as? ViewController{
//////
//////            // Get the root navigation controller
//////            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
//////                rootVC.present(buttonVC, animated: true, completion: nil)
//////            }
//////        }
//////    }
//////    func Window() {
//////            print("Navigating to Profile Screen")
//////            // Add navigation logic
//////        }
////
////
////
//////    // CleverTapURLDelegate method
//////    public func shouldHandleCleverTap(_ url: URL?, for channel: CleverTapChannel) -> Bool {
//////        print("Handling URL: \(url!) for channel: \(channel)")
//////        return true
//////    }
////    //-----------------------------------------
//////    func recordUserChargedEvent() {
//////           // Transaction details
//////           let chargeDetails: [String: Any] = [
//////               "Amount": 300,
//////               "Payment mode": "Credit Card",
//////               "Charged ID": 24052013
//////           ]
//////
//////           // Items sold
//////           let item1: [String: Any] = [
//////               "Category": "books",
//////               "Book name": "The Millionaire next door",
//////               "Quantity": 1
//////           ]
//////
//////           let item2: [String: Any] = [
//////               "Category": "books",
//////               "Book name": "Achieving inner zen",
//////               "Quantity": 1
//////           ]
//////
//////           let item3: [String: Any] = [
//////               "Category": "books",
//////               "Book name": "Chuck it, let's do it",
//////               "Quantity": 5
//////           ]
//////
//////           // Record the Charged event with transaction details and items
//////           CleverTap.sharedInstance()?.recordChargedEvent(withDetails: chargeDetails, andItems: [item1, item2, item3])
//////       }
////
////    // MARK: UISceneSession Lifecycle
////    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
////        switch status {
////        case .authorizedAlways:
////            print("Always Authorized: Start geofencing.")
////        case .authorizedWhenInUse:
////            print("When In Use Authorized: Limited geofencing possible.")
////        case .denied, .restricted:
////            print("Location access denied.")
////        default:
////            break
////        }
////    }
////
////    func inAppNotificationButtonTapped(withCustomExtras customExtras: [AnyHashable: Any]!) {
////        print("In-App Notification Button Tapped with Custom Extras: \(customExtras ?? [:])")
////        // Handle the button click event here
////    }
////
////    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
////        // Called when a new scene session is being created.
////        // Use this method to select a configuration to create the new scene with.
////        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
////    }
////
////    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
////        // Called when the user discards a scene session.
////        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
////        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
////    }
////    func registerForPush() {
////            // Register for Push notifications
////            UNUserNotificationCenter.current().delegate = self
////            // request Permissions
////            UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .badge, .alert], completionHandler: {granted, error in
////                if granted {
////                    DispatchQueue.main.async {
////                        UIApplication.shared.registerForRemoteNotifications()
////                    }
////                }
////            })
////        }
////
////        // Handle push registration failure
////        func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
////            NSLog(" Failed to register for remote notifications: %@", error.localizedDescription)
////        }
////
////        // Handle successful push registration
////        func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
////            NSLog("Registered for remote notifications: %@", deviceToken.description)
////        }
////
////        // Handle push tap action (when user interacts with notification)
////        func userNotificationCenter(_ center: UNUserNotificationCenter,
////                                    didReceive response: UNNotificationResponse,
////                                    withCompletionHandler completionHandler: @escaping () -> Void) {
////            NSLog("Push notification tapped: %@", response.notification.request.content.userInfo)
////            CleverTap.sharedInstance()?.handleNotification(withData: response.notification.request.content.userInfo)
////            completionHandler()
////        }
////
////        // Handle foreground push notification (when app is open)
////        func userNotificationCenter(_ center: UNUserNotificationCenter,
////                                    willPresent notification: UNNotification,
////                                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
////            NSLog("Push received while app is in foreground: %@", notification.request.content.userInfo)
////            CleverTap.sharedInstance()?.recordNotificationViewedEvent(withData: notification.request.content.userInfo)
////            completionHandler([.badge, .sound, .alert])
////        }
////
////        // Handle background push notification
////        func application(_ application: UIApplication,
////                         didReceiveRemoteNotification userInfo: [AnyHashable : Any],
////                         fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
////            NSLog("Received background push notification: %@", userInfo)
////            completionHandler(.noData)
////        }
////
////        // Handle custom extra data in push notification
////        func pushNotificationTapped(withCustomExtras customExtras: [AnyHashable : Any]!) {
////            NSLog(" Push notification customExtras: %@", customExtras)
////        }
////
////        // Register push notification delegate
////        func registerForPushNotifications() {
////            let center = UNUserNotificationCenter.current()
////            center.delegate = self
////            center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
////                if granted {
////                    DispatchQueue.main.async {
////                        UIApplication.shared.registerForRemoteNotifications()
////                    }
////                } else {
////                    NSLog(" Push notifications permission denied.")
////                }
////            }
////        }
//////    func makeOptions() -> MParticleOptions? {
//////        guard let key = getConfigInfo("MPARTICLE_KEY"),
//////                let secret = getConfigInfo("MPARTICLE_SECRET") else {
//////                    AppDelegate.shouldShowCredsAlert = true
//////                    log("Error: No mParticle key and secret were found")
//////                    return nil
//////                }
//////        if key == "REPLACEME" || secret == "REPLACEME" {
//////            AppDelegate.shouldShowCredsAlert = true
//////            if let value = getOverrideConfig("IS_UITEST") {
//////                if value == "YES" {
//////                    AppDelegate.shouldShowCredsAlert = false
//////                }
//////            }
//////        }
//////        let options = MParticleOptions(key: key, secret: secret)
//////        if let logLevel = parseLogLevel(getConfigInfo("MPARTICLE_LOGLEVEL")) {
//////            // Log level is set to .none by default--you should use a preprocessor directive to ensure it is only set for your non-App Store build configurations (e.g. Debug, Enterprise distribution, etc)
//////            #if DEBUG
//////            options.logLevel = logLevel
//////            #endif
//////        }
//////        options.customLogger = { (message: String) in
//////            self.log("Custom Higgs Logs - \(message)")
//////        }
//////        if let autoTracking = parseBool(getConfigInfo("MPARTICLE_AUTOTRACKING")) {
//////            if autoTracking == false {
//////                options.automaticSessionTracking = false
//////                options.shouldBeginSession = false
//////                Self.eventsBeginSessions = false
//////            }
//////        }
//////        if let sessionTimeout = parseDouble(getConfigInfo("MPARTICLE_SESSIONTIMEOUT")) {
//////            options.sessionTimeout = sessionTimeout
//////        }
//////        if let proxyDelegate = parseBool(getConfigInfo("MPARTICLE_PROXYDELEGATE")) {
//////            if proxyDelegate == false {
//////                // If you are disabling App Delegate proxying, you will need to manually forward certain App Delegate methods.
//////                // See our docs here: https://docs.mparticle.com/developers/client-sdks/ios/configuration/#uiapplication-delegate-proxy
//////                options.proxyAppDelegate = false
//////            }
//////        }
//////        return options
//////    }
////
//////        func makeOptions() -> MParticleOptions? {
//////            guard let key = getConfigInfo("MPARTICLE_KEY"),
//////                  let secret = getConfigInfo("MPARTICLE_SECRET") else {
//////                AppDelegate.shouldShowCredsAlert = true
//////                logMessage("❌ Error: No mParticle key and secret were found")
//////                return nil
//////            }
//////
//////            if key == "REPLACEME" || secret == "REPLACEME" {
//////                AppDelegate.shouldShowCredsAlert = true
//////                if let value = getOverrideConfig("IS_UITEST"), value == "YES" {
//////                    AppDelegate.shouldShowCredsAlert = false
//////                }
//////            }
//////
//////            let options = MParticleOptions(key: key, secret: secret)
//////
//////            if let logLevel = parseLogLevel(getConfigInfo("MPARTICLE_LOGLEVEL")) {
//////                #if DEBUG
//////                options.logLevel = logLevel
//////                #endif
//////            }
//////
//////            options.customLogger = { (message: String) in
//////                self.logMessage("Custom Higgs Logs - \(message)")
//////            }
//////
//////            if let autoTracking = parseBool(getConfigInfo("MPARTICLE_AUTOTRACKING")), autoTracking == false {
//////                options.automaticSessionTracking = false
//////                options.shouldBeginSession = false
//////                AppDelegate.eventsBeginSessions = false
//////            }
//////
//////            if let sessionTimeout = parseDouble(getConfigInfo("MPARTICLE_SESSIONTIMEOUT")) {
//////                options.sessionTimeout = sessionTimeout
//////            }
//////
//////            if let proxyDelegate = parseBool(getConfigInfo("MPARTICLE_PROXYDELEGATE")), proxyDelegate == false {
//////                options.proxyAppDelegate = false
//////            }
//////
//////            return options
//////        }
//////
//////        // ✅ Helper function to fetch config values from Info.plist
//////        func getConfigInfo(_ key: String) -> String? {
//////            return Bundle.main.object(forInfoDictionaryKey: key) as? String
//////        }
//////
//////        // ✅ Mocked function to override config values (if needed)
//////        func getOverrideConfig(_ key: String) -> String? {
//////            return nil // Replace with real logic if needed
//////        }
//////
//////        // ✅ Function to log messages properly
//////        func logMessage(_ message: String) {
//////            print(message) // You can replace this with a proper logging mechanism
//////        }
//////
//////        // ✅ Converts a string log level to an enum (mock implementation)
//////        func parseLogLevel(_ level: String?) -> MPILogLevel? {
//////            switch level?.lowercased() {
//////            case "none": return .none
//////            case "error": return .error
//////            case "warning": return .warning
//////            case "debug": return .debug
//////            case "verbose": return .verbose
//////            default: return nil
//////            }
//////        }
//////
//////        // ✅ Converts a string to a boolean (e.g., "YES" -> true, "NO" -> false)
//////        func parseBool(_ value: String?) -> Bool? {
//////            guard let val = value?.lowercased() else { return nil }
//////            return val == "yes" || val == "true" || val == "1"
//////        }
//////
//////        // ✅ Converts a string to a double (if present)
//////        func parseDouble(_ value: String?) -> Double? {
//////            guard let val = value else { return nil }
//////            return Double(val)
//////        }
////    }
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
