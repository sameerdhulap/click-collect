//
//  AppDelegate.swift
//  Click&Collect
//
//  Created by Woosmap on 21/05/25.
//

import UIKit
import CoreData
import CoreLocation
import WoosmapGeofencing
import Woosmap

@objc(DictionaryStringTransformer)
class DictionaryStringTransformer: ValueTransformer {
    
    override class func allowsReverseTransformation() -> Bool { true }

    override class func transformedValueClass() -> AnyClass { NSData.self }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let dict = value as? [String: String] else { return nil }
        return try? NSKeyedArchiver.archivedData(withRootObject: dict, requiringSecureCoding: true)
    }

    override func reverseTransformedValue(_ data: Any?) -> Any? {
        guard let data = data as? Data else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSDictionary.self, from: data) as? [String: String]
    }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "CollectionBox")
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    let dataEvent = WoosmapEvent()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
#if targetEnvironment(simulator)
    if let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path {
        debugPrint("sampleapp: Documents Directory: \(documentsPath)")
    }
#endif
        
        ValueTransformer.setValueTransformer(DictionaryStringTransformer(), forName: NSValueTransformerName("DictionaryStringTransformer"))
        
        if #available(iOS 10, *) {
            UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
            UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { _, _ in }
        } else {
            UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: [.badge, .sound, .alert], categories: nil))
        }
        UIApplication.shared.registerForRemoteNotifications()
        
        startMonitoringWithWoosmap()
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        if CLLocationManager().authorizationStatus != .notDetermined {
            WoosmapGeofenceManager.shared.startMonitoringInBackground()
        }

        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        WoosmapGeofenceManager.shared.setModeHighfrequencyLocation(enable: false)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        WoosmapGeofenceManager.shared.didBecomeActive()
    }


}

extension AppDelegate{
    public func startMonitoringWithWoosmap(){
        if let currentProfile = ApplicationData().getProfile() {
            WMSettings.shared().key = AppConfig.privateKey
            WoosmapGeofenceManager.shared.getLocationService().locationServiceDelegate = dataEvent
            WoosmapGeofenceManager.shared.getLocationService().searchAPIDataDelegate = dataEvent
            WoosmapGeofenceManager.shared.getLocationService().regionDelegate = dataEvent
            WoosmapGeofenceManager.shared.setWoosmapAPIKey(key: WMSettings.shared().key)
            
            if(currentProfile.profile == "Asset Monitoring") {
                WoosmapGeofenceManager.shared.startTracking(configurationProfile: .passiveTracking)
                
                if let attributes:[String:String] = currentProfile.profileProperties{
                    if let r = attributes["radius"]{
                        WoosmapGeofenceManager.shared.setPoiRadius(radius: r)
                    }
                    if let slots = attributes["ProtectedRegionSlot"]{
                        try? WoosmapGeofenceManager.shared.setProtectedRegionSlot(Int(slots) ?? 0)
                    }
                    if let optimize = attributes["optimizeDistanceRequest"]{
                        WoosmapGeofenceManager.shared.OptimizeDistanceRequest = optimize == "true" ? true : false
                    }
                }
                
            }
            else if(currentProfile.profile == "Click&Collect"){
                WoosmapGeofenceManager.shared.getLocationService().distanceAPIDataDelegate = dataEvent
                WoosmapGeofenceManager.shared.startTracking(configurationProfile: .liveTracking)
                WoosmapGeofenceManager.shared.distanceDisplacementFilter = Double(AppConfig.passiveTracking.distanceDisplacementFilter)
                if let attributes:[String:String] = currentProfile.profileProperties{
                    if let mode = attributes["distanceMode"] {
                        if mode == "driving" {
                            WoosmapGeofenceManager.shared.setDistanceAPIMode(mode:DistanceMode.driving)
                        }
                        else if mode  == "walking" {
                            WoosmapGeofenceManager.shared.setDistanceAPIMode(mode:DistanceMode.walking)
                        }
                    }
                    if let optimize = attributes["optimizeDistanceRequest"]{
                        WoosmapGeofenceManager.shared.OptimizeDistanceRequest = optimize == "true" ? true : false
                    }
                }
                
                
            }
            
            let locationManager = CLLocationManager()
            let status = locationManager.authorizationStatus
            if (status != .notDetermined) {
                WoosmapGeofenceManager.shared.startMonitoringInBackground()
            }
            
        }
    }
    public func stopGeofencing(){
        WoosmapGeofenceManager.shared.setTrackingEnable(enable: false)
        WoosmapGeofenceManager.shared.stopTracking()
        POIs.deleteAll()
        RegionIsochrones.deleteAll()
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
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
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
         completionHandler([.alert,.badge])
    }
}

