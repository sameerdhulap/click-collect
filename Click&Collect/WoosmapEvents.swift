//
//  WoosmapEvents.swift
//  Click&Collect
//
//  Created by Woosmap on 21/05/25.
//

import WoosmapGeofencing
import UIKit
import CoreLocation

internal class WoosmapEvent: LocationServiceDelegate, SearchAPIDelegate, RegionsServiceDelegate, VisitServiceDelegate, DistanceAPIDelegate{
    private var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
    private var backgroundTaskLoop: Int = 30
    /// Latest fix reported by the SDK, used to measure the gap to a POI on region entry.
    private var lastKnownLocation: CLLocation?

    internal init() {}
    
    func killBackgroundTask(){
        if (backgroundTask != UIBackgroundTaskIdentifier.invalid) {
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = UIBackgroundTaskIdentifier.invalid
        }
    }
    func extendBackgroundRunningTime() {
        if (backgroundTask != UIBackgroundTaskIdentifier.invalid) {
            // already started
            return
        }
        else{
            backgroundTaskLoop = 30
        }
        
        self.backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "WoosmapApp", expirationHandler: {
            UIApplication.shared.endBackgroundTask(self.backgroundTask)
            self.backgroundTask = UIBackgroundTaskIdentifier.invalid
        })
        
        DispatchQueue.global(qos: .utility).async {
            while (true) {
                //let backgroundTimeRemaining = UIApplication.shared.backgroundTimeRemaining
                // This will be a very large number if you have proper permissions
                // If not, it will generally count down from 10 seconds once you are in the
                // background until iOS suspends your app.
                Thread.sleep(forTimeInterval: 1.0)
                self.backgroundTaskLoop = self.backgroundTaskLoop-1
                if( self.backgroundTaskLoop == 0){
                    self.killBackgroundTask()
                }
            }
        }
    }
    
    
    ///Updated when new location capture by device
    internal func tracingLocation(location: Location) {
        lastKnownLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        //Save it in history
        NotificationCenter.default.post(name: .newLocationSaved, object: self, userInfo: ["Location": location])
        debugPrint("Location Updated")
    }
    ///
    ///Location error
    internal func tracingLocationDidFailWithError(error: Error) {
        debugPrint("sampleapp: \(error)")
    }
    ///
    ///Search response fetch from woos server
    internal func searchAPIResponse(poi: POI) {
        NotificationCenter.default.post(name: .newPOISaved, object: self, userInfo: ["POI": poi])
    }
    
    ///
    ///Search error
    internal func searchAPIError(error: String) {
        
    }
    ///CAlled ehen geofance region created
    internal func updateRegions(regions: Set<CLRegion>) {
        NotificationCenter.default.post(name: .updateRegions, object: self, userInfo: ["Regions": regions])
    }
    
    /// Called  when user is inside Geofence zone
    internal func didEnterPOIRegion(POIregion: Region) {
        NotificationCenter.default.post(name: .didEventPOIRegion, object: self, userInfo: ["Region": POIregion])
        if POIregion.type == "circle" {
            formatNotification(POIregion: POIregion, isIsoChrone: false)
        }
        else if POIregion.type == "isochrone" {
            formatNotification(POIregion: POIregion, isIsoChrone: true)
        }
    }
    
    /// Called  when user is exited Geofence zone
    internal func didExitPOIRegion(POIregion: Region) {
        NotificationCenter.default.post(name: .didEventPOIRegion, object: self, userInfo: ["Region": POIregion])
        // The SDK reports exits only here, so this is the only path that can raise the
        // "leaving a geofence" notification. Exit rows are logged with type "circle" even
        // for an isochrone, so the enter type is what decides the wording.
        formatNotification(POIregion: POIregion, isIsoChrone: POIregion.type == "isochrone")
    }
    
    /// Called  when user is inside Work Geofence zone
    internal func workZOIEnter(classifiedRegion: Region) {
        NotificationCenter.default.post(name: .didEventPOIRegion, object: self, userInfo: ["Region": classifiedRegion])
    }
    
    /// Called  when user is inside home Geofence zone
    internal func homeZOIEnter(classifiedRegion: Region) {
        NotificationCenter.default.post(name: .didEventPOIRegion, object: self, userInfo: ["Region": classifiedRegion])
    }
    /// Called when visit capture
    internal func processVisit(visit: WoosmapGeofencing.Visit) {
        
    }
    /// Called when distance api response capture
    internal func distanceAPIResponse(distance: [WoosmapGeofencing.Distance]) {
        guard let config =  ApplicationData().getProfile() else { return }
        let _ = ApiLogData().addAPILog(type: "Distance", profile: config.profile!)
        ISOChroneData().updateCount(isReached: false)
        
        NotificationCenter.default.post(name: .distanceRequested, object: self, userInfo: [:])
    }
    
    /// Called when distance api error capture
    internal func distanceAPIError(error: String) {
        
    }
    
    private func secondsToHoursMinutesSeconds(_ seconds: Int) -> (Int, Int, Int) {
        return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }

    /// Time spent in a region, as "1 hours 2 minutes 3 seconds".
    private func spentTimeText(_ spentTime: Double) -> String {
        let (hours, minutes, seconds) = secondsToHoursMinutesSeconds(Int(spentTime))
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hours") }
        if minutes > 0 { parts.append("\(minutes) minutes") }
        if seconds > 0 { parts.append("\(seconds) seconds") }
        return parts.isEmpty ? "less than a second" : parts.joined(separator: " ")
    }

    /// How far the user is from the centre of `POIregion` when the region is entered.
    /// Returns `LogData.unknownDistance` when no fix is available.
    private func distanceFromUser(to POIregion: Region) -> CLLocationDistance {
        guard let user = lastKnownLocation ?? mostRecentStoredLocation() else {
            return LogData.unknownDistance
        }
        let poi = CLLocation(latitude: POIregion.latitude, longitude: POIregion.longitude)
        return user.distance(from: poi)
    }

    /// Fallback for the case where the app was woken by the region event itself and has
    /// not received a live fix yet: the freshest location the SDK has stored.
    private func mostRecentStoredLocation() -> CLLocation? {
        let latest = Locations.getAll()
            .compactMap { location -> (Date, CLLocation)? in
                guard let date = location.date else { return nil }
                return (date, CLLocation(latitude: location.latitude, longitude: location.longitude))
            }
            .max(by: { $0.0 < $1.0 })
        return latest?.1
    }
    
    
    
    //******************/
    private func formatNotification (POIregion: Region, isIsoChrone: Bool)  {
        let id: String = POIregion.identifier
        guard let config =  ApplicationData().getProfile() else { return }
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removeDeliveredNotifications(withIdentifiers: ["woosmap_\(id)"])
        var content = UNMutableNotificationContent()
        
        if POIregion.didEnter == true {
            let distanceToPOI = distanceFromUser(to: POIregion)
            if(isIsoChrone){
                content.title = "Your burger is ready!"
                content.body = "Your order will be ready in next \(Int(POIregion.radius / 60)) minute(s)"
                
                
                // Create the request
                let request = UNNotificationRequest(identifier: "woosmap_\(POIregion.identifier)",
                                                    content: content, trigger: nil)
                
                
                // Schedule the request with the system.
                let notificationCenter = UNUserNotificationCenter.current()
                notificationCenter.add(request)
                ISOChroneData().updateCount(isReached: true)
                
                let _ = LogData().addNotification(title: "ISOChrone Zone \(POIregion.identifier)", isInside: true, profile: config.profile!, distance: distanceToPOI)
            }
            else{
                if let moreInfo = POIs.getPOIbyIdStore(idstore: POIregion.identifier){
                    content.title = "You're near to an asset!"
                    content.body = "Have a break, have a burger at \(moreInfo.name ?? "-") is \(moreInfo.openNow ? "open now" : "closed")"
                    // Create the request
                    let request = UNNotificationRequest(identifier: "woosmap_\(moreInfo.idstore ?? "-")",
                                                        content: content, trigger: nil)
                    
                    
                    // Schedule the request with the system.
                    let notificationCenter = UNUserNotificationCenter.current()
                    notificationCenter.add(request)
                    
                    let _ = LogData().addNotification(title: "Inside circle zone of \(moreInfo.name ?? "-") status:\(moreInfo.openNow ? "open now" : "closed")", isInside: true, profile: config.profile!, distance: distanceToPOI)
                }
                
            }
        }
        else{
            //Show exit notification. The POI is only used for its name: an exit from a region
            //with no matching POI (an isochrone around a store that was never searched) still
            //has to be notified and logged.
            let name = POIs.getPOIbyIdStore(idstore: POIregion.identifier)?.name ?? POIregion.identifier
            content.title = "You`re leaving a geofence!"
            content.body = String(format: "You spent %@ at %@", spentTimeText(POIregion.spentTime), name)
            content.categoryIdentifier = "woosmap"
            // Create the request
            let request = UNNotificationRequest(identifier: "woosmap_\(POIregion.identifier)",
                                                content: content, trigger: nil)
            // Schedule the request with the system.
            notificationCenter.add(request)

            let _ = LogData().addNotification(title: "Outside zone of \(name)", isInside: false, profile: config.profile!)
        }
    }
}

/// Notification raised by SDK
extension Notification.Name {
    static let newLocationSaved = Notification.Name("newLocationSaved")
    static let newPOISaved = Notification.Name("newPOISaved")
    static let updateRegions = Notification.Name("updateRegions")
    static let didEventPOIRegion = Notification.Name("didEventPOIRegion")
    static let distanceRequested = Notification.Name("distanceRequested")
}
