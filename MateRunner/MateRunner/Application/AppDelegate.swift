//
//  AppDelegate.swift
//  MateRunner
//
//  Created by 이정원 on 2021/10/29.
//

import CoreData
import UIKit
import UserNotifications

import Firebase
import FirebaseMessaging

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:[UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter
            .current()
            .requestAuthorization(options: authOptions, completionHandler: { (_, _) in })
        
        application.registerForRemoteNotifications()
        
        if let nickName = UserDefaults.standard.string(forKey: UserDefaultKey.nickname.rawValue) {
            Database.database().reference().child("state").child("\(nickName)/isRunning").setValue(false)
        }
        
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        if let nickName = UserDefaults.standard.string(forKey: UserDefaultKey.nickname.rawValue) {
            Database.database().reference().child("state").child("\(nickName)/isRunning").setValue(false)
        }
    }

    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "MateRunner")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}

extension AppDelegate : MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let nickname = UserDefaults.standard.string(forKey: UserDefaultKey.nickname.rawValue) {
            Database.database().reference().child("fcmToken/\(nickname)").setValue(fcmToken)
        } else {
            UserDefaults.standard.set(fcmToken, forKey: UserDefaultKey.fcmToken.rawValue)
        }
    }
}

extension AppDelegate : UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        userInfo[NotificationCenterKey.sender] != nil
        ? self.configureMateRequestNotification(with: userInfo)
        : self.configureInvitation(with: userInfo)
        
        completionHandler()
    }
    
    
    private func configureMateRequestNotification(with userInfo: [AnyHashable: Any]) {
        guard let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate,
              let appCoordinator = sceneDelegate.appCoordinator,
              let tabBarCoordinator = appCoordinator.findCoordinator(type: .tab) as? TabBarCoordinator,
              let myPageCoordinator = appCoordinator.findCoordinator(type: .mypage) as? MyPageCoordinator else { return }
        tabBarCoordinator.selectPage(.mypage)
        // TODO: push NotificationViewController after integrates mypage subcoordinators
        myPageCoordinator.showNotificationFlow()
    }
    
    private func configureInvitation(with userInfo: [AnyHashable: Any]) {
        guard let invitation = Invitation(from: userInfo) else { return }
        
        NotificationCenter.default.post(
            name: NotificationCenterKey.invitationDidReceive,
            object: nil,
            userInfo: [NotificationCenterKey.invitation: invitation]
        )
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }
}
