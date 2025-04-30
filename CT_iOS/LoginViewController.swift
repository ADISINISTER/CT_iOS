//
// LoginViewController.swift
//  CT_iOS
//
//  Created by Aditya Sinha on 10/04/25.
//

import UIKit
import CleverTapSDK

class LoginViewController: UIViewController {

    let nameField = UITextField()
    let emailField = UITextField()
    let identityField = UITextField()
    let phoneField = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupFields()
        setupButtons()
    }

    func setupFields() {
        let fields = [nameField, emailField, identityField, phoneField]
        let placeholders = ["Name", "Email", "Identity", "Phone Number"]

        for (index, field) in fields.enumerated() {
            field.frame = CGRect(x: 40, y: 100 + CGFloat(index * 70), width: 300, height: 40)
            field.borderStyle = .roundedRect
            field.placeholder = placeholders[index]
            view.addSubview(field)
        }
        phoneField.keyboardType = .phonePad
        identityField.keyboardType = .numberPad
    }

    func setupButtons() {
        let submitBtn = UIButton(type: .system)
        submitBtn.frame = CGRect(x: 40, y: 400, width: 300, height: 50)
        submitBtn.setTitle("Submit", for: .normal)
        submitBtn.backgroundColor = .systemBlue
        submitBtn.setTitleColor(.white, for: .normal)
        submitBtn.layer.cornerRadius = 10
        submitBtn.addTarget(self, action: #selector(submitLogin), for: .touchUpInside)
        view.addSubview(submitBtn)

        let backBtn = UIButton(type: .system)
        backBtn.frame = CGRect(x: 40, y: 470, width: 300, height: 50)
        backBtn.setTitle("Back", for: .normal)
        backBtn.backgroundColor = .systemGray
        backBtn.setTitleColor(.white, for: .normal)
        backBtn.layer.cornerRadius = 10
        backBtn.addTarget(self, action: #selector(backToHome), for: .touchUpInside)
        view.addSubview(backBtn)
    }

    @objc func submitLogin() {
        guard let name = nameField.text, !name.isEmpty,
              let email = emailField.text, !email.isEmpty,
              let identity = identityField.text, !identity.isEmpty,
              let phone = phoneField.text, !phone.isEmpty else {
            showAlert("Please fill all fields")
            return
        }

        let profile: [String: AnyObject] = [
            "Name": name as AnyObject,
            "Identity": identity as AnyObject,
            "Email": email as AnyObject,
            "Phone": phone as AnyObject
        ]
        CleverTap.sharedInstance()?.onUserLogin(profile)
        showAlert("onUserLogin triggered")
        
        // Step 3: Save important user info in App Group UserDefaults
                let defaults = UserDefaults(suiteName: "group.provisional.nse") // Replace with your App Group name
                defaults?.set(email, forKey: "userEmailID")
                defaults?.set(identity, forKey: "userIdentity")
                defaults?.set(phone, forKey: "userMobileNumber")
                
                // Optional: Sync immediately
                defaults?.synchronize()

                print("✅ User info saved to App Group successfully.")
    }

    @objc func backToHome() {
        self.dismiss(animated: true, completion: nil)
    }

    func showAlert(_ message: String) {
        let alert = UIAlertController(title: "Login", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
