//
//  AppDelegate.swift
//  lingeo
//
//  Created by LD on 4/13/18.
//  Copyright © 2018 LD. All rights reserved.
//

import UIKit
import CoreData
import GRDB
import Toaster

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    var dbPool: DatabasePool!
    var syncWithCloud:Debouncer!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        syncWithCloud = Debouncer(delay: 5) {
            self.syncWithCloudRaw()
        }
        
        self.copyDatabaseIfNeeded()

        do {
            dbPool = try self.getDB()
            Network.reachability = try Reachability(hostname: "www.apple.com")
            if(Network.reachability?.isReachableViaWiFi)! {
                self.syncWithCloud.call()
            }
            do {
                try Network.reachability?.start()
            } catch let error as Network.Error {
                print(error)
            } catch {
                print(error)
            }
        } catch {
            print(error)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(statusManager), name: .flagsChanged, object: Network.reachability)
        
        return true
    }
    
    public func getDB() throws -> DatabasePool  {
        let fileManager = FileManager.default
        
        let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        
        guard documentsUrl.count != 0 else {
            throw NSError(domain: "bad_document", code: -19, userInfo: nil)
        }
        
        let finalDatabaseURL = documentsUrl.first!.appendingPathComponent("ilingoka.sqlite")
        if(dbPool == nil ) {
            dbPool = try DatabasePool(path: finalDatabaseURL.path)
        }
        return dbPool
    }
    
    private func copyDatabaseIfNeeded() {
        // Move database file from bundle to documents folder
        
        let fileManager = FileManager.default
        
        let documentsUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        
        guard documentsUrl.count != 0 else {
            return // Could not find documents URL
        }
        
        let finalDatabaseURL = documentsUrl.first!.appendingPathComponent("ilingoka.sqlite")
        
        if !( (try? finalDatabaseURL.checkResourceIsReachable()) ?? false) {
            print("DB does not exist in documents folder")
            
            let documentsURL = Bundle.main.resourceURL?.appendingPathComponent("ilingoka.sqlite")
            
            do {
                try fileManager.copyItem(atPath: (documentsURL?.path)!, toPath: finalDatabaseURL.path)
            } catch let error as NSError {
                print("Couldn't copy file to final location! Error:\(error.description)")
            }
            
        } else {
            print("Database file found at path: \(finalDatabaseURL.path)")
        }
        
    }
    
    private func syncWithCloudRaw() {
        let migrationKey = UserDefaults.standard.object(forKey: "migration_key") as? String
        var url:URL!
        if(migrationKey != nil) {
            url = URL(string: "https://lingeo.picktek.org/api/migration/" + migrationKey!)
        } else {
            url = URL(string: "https://lingeo.picktek.org/api/migration")
        }
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        
        let session = URLSession.init(configuration: config)
        let task = session.dataTask(with: url) {(data, response, error) in
            if(data != nil) {                
                do {
                    let syncData = try JSON(data: data!)
                    if(syncData["total"] > 0) {
                        var executionCount = 0
                        for (_ , subJson):(String, JSON) in syncData["data"] {
                            self.executeMigration(query: subJson["query"].string!, uuid: subJson["uuid"].string!)
                            executionCount = executionCount + 1
                        }
                        if(executionCount > 0) {
                            self.syncWithCloud.call()
                            DispatchQueue.main.async {
                                Toast(text: "Database Updated!").show()
                            }
                        }
                    }
                } catch {
                    print(error)
                }
            } else {
                print(response ?? "suppose-response", error ?? "suppose-error")
            }
        }
        
        task.resume()
    }
    
    private func executeMigration(query:String, uuid:String) {
        print(query, uuid)
        do {
            try dbPool.write { db in
                try db.execute(query)
            }
            UserDefaults.standard.set(uuid, forKey: "migration_key")
        } catch {
            print(error)
        }
    }
    
    @objc func statusManager(_ notification: Notification) {
        if(Network.reachability?.isReachableViaWiFi)! {
            self.syncWithCloud.call()
        }
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        
        if(Network.reachability?.isReachableViaWiFi)! {
            self.syncWithCloud.call()
        }
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        if(Network.reachability?.isReachableViaWiFi)! {
            self.syncWithCloud.call()
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        CoreDataStack.saveContext()
    }
    
}

