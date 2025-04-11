//
//  ViewController.swift
//  CT_iOS
//
//  Created by Aditya Sinha on 10/02/25.
//

import UIKit
import CleverTapSDK
import UserNotifications

class ViewController: UIViewController, CleverTapInboxViewControllerDelegate,  CleverTapDisplayUnitDelegate{
    @IBOutlet weak var nativeDisplayImageView: UIImageView!
    var imageUrls: [String] = []
        var currentIndex = 0
        var timer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupButtons()
        // Set delegate to receive display unit updates
                CleverTap.sharedInstance()?.setDisplayUnitDelegate(self)
    }
    
    // MARK: - Button Setup
    func setupButtons() {
        addButton(title: "Reset CleverTap", yPosition: 100, color: .systemRed, action: #selector(resetCleverTapInstance))
        addButton(title: "Push Notification Event", yPosition: 170, action: #selector(recordPushEvent))
        addButton(title: "In-App Event", yPosition: 240, action: #selector(recordInAppEvent))
        addButton(title: "Charged Event", yPosition: 310, action: #selector(recordChargedEvent))
        addButton(title: "OnUserLogin", yPosition: 380, action: #selector(onUserLoginWithProfile))
        addButton(title: "Show UserDefaults", yPosition: 450, action: #selector(showUserDefaults))
        addButton(title: "App Inbox", yPosition: 520, color: .systemIndigo, action: #selector(showAppInbox))
        addButton(title: "Go to Login Page", yPosition: 590, color: .systemGreen, action: #selector(navigateToLoginPage))

        
    }
    
    func addButton(title: String, yPosition: CGFloat, color: UIColor = .systemBlue, action: Selector) {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = color
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.frame = CGRect(x: 50, y: yPosition, width: 300, height: 50)
        button.addTarget(self, action: action, for: .touchUpInside)
        view.addSubview(button)
    }
    
    
    
    // MARK: - Button Actions
    
    @objc func resetCleverTapInstance() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.unregisterForRemoteNotifications()
                }
            }
        }
        
        if let accId = CleverTap.sharedInstance()?.config.accountId {
            let fileName = "clevertap-\(accId)-userprofile.plist"
            let appDir = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).last
            let filePath = "\(appDir!)/\(fileName)"
            if FileManager.default.fileExists(atPath: filePath) {
                try? FileManager.default.removeItem(atPath: filePath)
            }
            
            let defaults = UserDefaults.standard
            for (key, _) in defaults.dictionaryRepresentation() where key.contains("WizRocket") {
                if key != "WizRocketdevice_token" && key != "WizRocketfirstTime" {
                    defaults.removeObject(forKey: key)
                }
            }
            defaults.synchronize()
        }
        
        (UIApplication.shared.delegate as? AppDelegate)?.registerForPush()
    }
    
    @objc func recordPushEvent() {
        CleverTap.sharedInstance()?.recordEvent("Push Notification")
    }
    
    @objc func recordInAppEvent() {
        CleverTap.sharedInstance()?.recordEvent("Raise InApp")
    }
    
    @objc func recordChargedEvent() {
        let chargeDetails: [String: Any] = [
            "Amount": 300,
            "Payment mode": "Credit Card",
            "Charged ID": 24052013
        ]
        let items: [[String: Any]] = [
            ["Category": "books", "Book name": "The Millionaire next door", "Quantity": 1],
            ["Category": "books", "Book name": "Achieving inner zen", "Quantity": 1],
            ["Category": "books", "Book name": "Chuck it, let's do it", "Quantity": 5]
        ]
        CleverTap.sharedInstance()?.recordChargedEvent(withDetails: chargeDetails, andItems: items)
    }
    
    @objc func onUserLoginWithProfile() {
        let dob = DateComponents(calendar: .current, year: 1992, month: 5, day: 24).date!
        let profile: [String: AnyObject] = [
            "Name": "Aditya Raj Sinha" as AnyObject,
            "Identity": 8275 as AnyObject,
            "Email": "addy3503@gmail.com" as AnyObject,
            "Phone": "+9135878442" as AnyObject,
            "Gender": "M" as AnyObject,
            "DOB": dob as AnyObject,
            "Age": 28 as AnyObject,
            "Photo": "https://avatar.iran.liara.run/public/boy?username=Ash" as AnyObject,
            "MSG-email": false as AnyObject,
            "MSG-push": true as AnyObject,
            "MSG-sms": false as AnyObject,
            "MSG-dndPhone": true as AnyObject,
            "MSG-dndEmail": true as AnyObject
        ]
        CleverTap.sharedInstance()?.onUserLogin(profile)
    }
    
    @objc func showUserDefaults() {
        let defaults = UserDefaults.standard.dictionaryRepresentation()
        let message = defaults.map { "\($0): \($1)" }.joined(separator: "\n")
        let alert = UIAlertController(title: "UserDefaults", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc func showAppInbox() {
        //Initialize the CleverTap App Inbox
        CleverTap.sharedInstance()?.initializeInbox(callback: ({ (success) in
                let messageCount = CleverTap.sharedInstance()?.getInboxMessageCount()
                let unreadCount = CleverTap.sharedInstance()?.getInboxMessageUnreadCount()
                print("Inbox Message:\(String(describing: messageCount))/\(String(describing: unreadCount)) unread")
         }))
//        // config the style of App Inbox Controller (CT APPINBOX)
//            let style = CleverTapInboxStyleConfig.init()
//            style.title = "App Inbox"
//            style.backgroundColor = UIColor.blue
//            style.messageTags = ["tag1", "tag2"]
//            style.navigationBarTintColor = UIColor.blue
//            style.navigationTintColor = UIColor.blue
//            style.tabUnSelectedTextColor = UIColor.blue
//            style.tabSelectedTextColor = UIColor.blue
//            style.tabSelectedBgColor = UIColor.blue
//            style.firstTabTitle = "My First Tab"
//            
//            if let inboxController = CleverTap.sharedInstance()?.newInboxViewController(with: style, andDelegate: self) {
//                let navigationController = UINavigationController.init(rootViewController: inboxController)
//                self.present(navigationController, animated: true, completion: nil)
//          }
        //Custom App Inbox
        let style = CleverTapInboxStyleConfig()
        style.title = "App Inbox"
        style.backgroundColor = UIColor.systemIndigo
        style.navigationBarTintColor = UIColor.white
        style.navigationTintColor = UIColor.systemIndigo
        style.firstTabTitle = "All"
        style.tabUnSelectedTextColor = UIColor.systemGray
        style.tabSelectedTextColor = UIColor.white
        style.tabSelectedBgColor = UIColor.systemPurple
        style.messageTags = ["Promotions", "Offers"]
        
        if let inboxVC = CleverTap.sharedInstance()?.newInboxViewController(with: style, andDelegate: self) {
            let navController = UINavigationController(rootViewController: inboxVC)
            navController.modalPresentationStyle = .pageSheet
            self.present(navController, animated: true, completion: nil)
        }
    }
    @objc func navigateToLoginPage() {
        let loginVC = LoginViewController()
        self.present(loginVC, animated: true, completion: nil)
    }
    // MARK: - CleverTapDisplayUnitDelegate
        func displayUnitsUpdated(_ displayUnits: [CleverTapDisplayUnit]) {
            imageUrls.removeAll()
            
            for unit in displayUnits {
                if let contents = unit.contents {
                    for content in contents {
                        if let imageUrl = content.mediaUrl {
                            imageUrls.append(imageUrl)
                        }
                    }
                }
            }

            if !imageUrls.isEmpty {
                startImageCarousel()
            }
        }

        // MARK: - Image Carousel
        func startImageCarousel() {
            updateImageView()  // Show the first image
            
            timer?.invalidate()  // Clear old timer
            timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                self.updateImageView()
            }
        }

        func updateImageView() {
            guard !imageUrls.isEmpty else { return }

            DispatchQueue.main.async {
                let urlString = self.imageUrls[self.currentIndex]
                if let url = URL(string: urlString), let data = try? Data(contentsOf: url) {
                    self.nativeDisplayImageView.image = UIImage(data: data)
                }
                self.currentIndex = (self.currentIndex + 1) % self.imageUrls.count
            }
        }

        deinit {
            timer?.invalidate()
        }
    }
    // MARK: - CleverTapInboxViewControllerDelegate Methods
    
//        func messageDidSelect(_ message: CleverTapInboxMessage, at index: Int32, withButtonIndex buttonIndex: Int32) {
//            print("Inbox message tapped at index: \(index), button index: \(buttonIndex)")
//    
//            if let messageId = message.messageId {
//                CleverTap.sharedInstance()?.recordInboxNotificationClickedEvent(forID: messageId)
//            }
//    
//            if let content = message.content?[safe: Int(index)] {
//                var ctaURL: URL?
//    
//                if buttonIndex < 0 {
//                    if content.actionHasUrl, let urlString = content.actionUrl {
//                        ctaURL = URL(string: urlString)
//                    }
//                } else {
//                    if content.actionHasLinks {
//                        let customExtras = content.customData(forLinkAt: Int(buttonIndex))
//                        print("Custom Extras: \(customExtras ?? [:])")
//    
//                        if let urlString = content.url(forLinkAt: Int(buttonIndex)) {
//                            ctaURL = URL(string: urlString)
//                        }
//                    }
//                }
//    
//                if let url = ctaURL {
//                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
//                }
//            }
//        }
//    
//        func messageButtonTapped(withCustomExtras customExtras: [AnyHashable: Any]?) {
//            print("App Inbox CTA Button tapped with custom extras: \(customExtras ?? [:])")
//        }
//    
//    }
//    extension Collection {
//        subscript(safe index: Index) -> Element? {
//            return indices.contains(index) ? self[index] : nil
//        }
//    }



//------------(old Code)-----------------------------------
//import UIKit
//import CoreLocation // Import CoreLocation for location tracking
//import CleverTapSDK
//import UserNotifications
//class ViewController: UIViewController {
//    
//    @IBOutlet weak var inApp: UIButton!
//    
//    @IBOutlet weak var Window: UIButton!
//    @IBOutlet weak var push: UIButton!
//    @IBAction func push(_ sender: Any) {
//        CleverTap.sharedInstance()?.recordEvent("Push Notification")
//    }
//    
//    @IBAction func inApp(_ sender: Any) {
//        print("[LOG] InApp Event Raised...")
//        // Raise CleverTap event
//        CleverTap.sharedInstance()?.recordEvent("Raise InApp")
//        //showToast(message: "Event Raised InApp")
//    }
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        // Create a button programmatically
//        let resetButton = UIButton(type: .system)
//        resetButton.setTitle("Reset CleverTap", for: .normal)
//        resetButton.backgroundColor = .systemRed
//        resetButton.setTitleColor(.white, for: .normal)
//        resetButton.layer.cornerRadius = 10
//        resetButton.frame = CGRect(x: 50, y: 200, width: 250, height: 50)
//        // Add action for the button
//        resetButton.addTarget(self, action: #selector(resetCleverTapInstance), for: .touchUpInside)
//        // Add the button to the view
//        view.addSubview(resetButton)
//        // Do any additional setup after loading the view.
//    }
//    @objc func resetCleverTapInstance() {
//        // Unregister the APNS token
//        UNUserNotificationCenter.current().requestAuthorization(options: [.sound, .alert, .badge]) {
//            (granted, error) in
//            if (granted) {
//                DispatchQueue.main.async {
//                    UIApplication.shared.unregisterForRemoteNotifications()
//                }
//            }
//        }
//        //        CleverTap.sharedInstance()?.setPushToken("pushTokenData", forType: .none)
//        
//        // Clear CleverTap-related data from UserDefaults
//        guard let accId = CleverTap.sharedInstance()?.config.accountId else {
//            return
//        }
//        //       CleverTap.sharedInstance()?._asyncSwitchUser([:],"","","")
//        let fileName = "clevertap-\(accId)-userprofile.plist"
//        let appDir = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).last
//        let filePath = "\(appDir!)/\(fileName)"
//        if FileManager.default.fileExists(atPath: filePath) {
//            try! FileManager.default.removeItem(atPath: filePath)
//        }
//        let defaults = UserDefaults.standard
//        let dictionary = defaults.dictionaryRepresentation()
//        dictionary.keys.forEach { key in
//            if key.contains("WizRocket"){
//                print("key \(key)")
//                if(key != "WizRocketdevice_token" || key != "WizRocketfirstTime"){
//                    defaults.removeObject(forKey: key)
//                }
//            }
//        }
//        defaults.synchronize()
//        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
//            appDelegate.registerForPush()
//        }
//    }
//    
//    @IBAction func Sharedpref(_ sender: Any) {
//    }
//    @IBAction func showuserdefaults(_ sender: Any) {
//        let defaults = UserDefaults.standard.dictionaryRepresentation()
//        var message = ""
//        for (key, value) in defaults {
//            message += "\(key): \(value)\n"
//        }
//        print(message)
//        let alert = UIAlertController(title: "UserDefaults", message: message, preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: "OK", style: .default))
//        present(alert, animated: true, completion: nil)
//    }
//-------------------------------------------------------------------------
//    @IBAction func Window(_ sender: Any) {
//        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
//            appDelegate.handleDeepLink("CT_iOS://Window")
//            //        }
//        }
//    }
//}



//    @objc func resetCleverTapInstance() {
//        //            // Clear CleverTap-related data from UserDefaults
//        //            let defaults = UserDefaults.standard
//        //            for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("WizRocket") {
//        //                defaults.removeObject(forKey: key)
//        //            }
//        //            defaults.synchronize()
//        //            // Reset CleverTap credentials (equivalent to Android’s changeCredentials)
//        //        CleverTap.setCredentialsWithAccountID("", andToken: "")            // Reinitialize the CleverTap instance
//        //            let _ = CleverTap.sharedInstance()
//        //            print("CleverTap instance reset successfully!")
//        guard let accId = CleverTap.sharedInstance()?.config.accountId else {
//            return
//        }
//    
////        CleverTap.sharedInstance()?._asyncSwitchUser()
//        let fileName = "clevertap-\(accId)-userprofile.plist"
//        let appDir = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).last
//        let filePath = "\(appDir!)/\(fileName)"
//        if FileManager.default.fileExists(atPath: filePath) {
//            try! FileManager.default.removeItem(atPath: filePath)
//        }
//        let defaults = UserDefaults.standard
//        let dictionary = defaults.dictionaryRepresentation()
//        dictionary.keys.forEach { key in
//            if key.contains("WizRocket"){
//                //                print(“key \(key)“)
//                if(key != "WizRocketdevice_token" || key != "WizRocketfirstTime"){
//                    defaults.removeObject(forKey: key)
//                }
//            }
//        }
//        defaults.synchronize()
//        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
//            appDelegate.registerForPush()
//        }
//    }
//}



