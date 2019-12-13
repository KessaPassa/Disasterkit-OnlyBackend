//
//  AppDelegate.swift
//  Disasterkit-Admin
//
//  Created by kiyolab01 on 2017/11/18.
//  Copyright © 2017年 kiyolab01. All rights reserved.
//

import UIKit
import Firebase

//internal let messageUpdateNotification = Notification.Name("New_Message")
//internal let databaseCallbackNotification = Notification.Name("Get_DataBase")
//internal let databaseCallbackDuplicateId = Notification.Name("DuplicteId")
internal let OFFLINE_MAP = "OfflineMapData"
internal let callbackMessageUpdate = Notification.Name("NewMessage")
internal let callbackGetDatabase = Notification.Name("GetDataBase")
internal let callbackDuplicateId = Notification.Name("DuplicteId")

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var backgroundTaskID : UIBackgroundTaskIdentifier = 0

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        FirebaseApp.configure()
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    //バックグラウンド遷移移行直前に呼ばれる
    func applicationWillResignActive(_ application: UIApplication) {
        
        self.backgroundTaskID = application.beginBackgroundTask(){
            [weak self] in
            application.endBackgroundTask((self?.backgroundTaskID)!)
            self?.backgroundTaskID = UIBackgroundTaskInvalid
        }
        
    }
    
    //アプリがアクティブになる度に呼ばれる
    func applicationDidBecomeActive(_ application: UIApplication) {
        
        application.endBackgroundTask(self.backgroundTaskID)
    }


}

