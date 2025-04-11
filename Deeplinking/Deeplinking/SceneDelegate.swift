//
//  SceneDelegate.swift
//  Deeplinking
//
//  Created by Aditya Sinha on 11/03/25.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let navigationController = storyboard.instantiateViewController(identifier: "MainNavigationController") as? UINavigationController
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
    //     Handle deep link if app is launched with a URL
//        used when apop is in killed state
        if let url = connectionOptions.urlContexts.first?.url {
          print("one")
          handleDeepLink(url)
        }
      }
    
    private func handleDeepLink(_ url: URL) {
        guard let path = url.host else { return }
        print("Deep link path: \(path)")
        switch path {
        case "second":
          navigateToSecondVC()
        default:
          break
        }
      }
      func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
          handleDeepLink(url)
        }
      }
      private func navigateToSecondVC() {
        print("[Navigation] Navigating to Second Page")
        guard let rootViewController = window?.rootViewController else { return }
        // Dismiss any existing modals before navigating
        rootViewController.dismiss(animated: true) { [weak self] in
          let storyboard = UIStoryboard(name: "Main", bundle: nil)
          guard let secondVC = storyboard.instantiateViewController(withIdentifier: "SecondViewController") as? SecondViewController else {
            return
          }
          if let navVC = self?.window?.rootViewController as? UINavigationController {
            navVC.pushViewController(secondVC, animated: true)
          } else {
            rootViewController.present(secondVC, animated: true)
          }
        }
      }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

