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
    
    // MARK: - Core Data stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "Bookmarks")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
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
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
}

