//
//  LogData.swift
//  Click&Collect
//
//  Created by Woosmap on 26/05/25.


import UIKit
import CoreData
import CoreLocation

class LogData {

    /// Stored when the distance to the POI could not be measured.
    static let unknownDistance: CLLocationDistance = -1

    func getLogs()-> [NotificationData]?{
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<NotificationData> = NotificationData.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "onDate", ascending: false)]
        do {
            let results = try context.fetch(fetchRequest)
            return results
        } catch {
            return nil
        }
    }
    
    /// - Parameter distance: metres between the user and the POI when the region was entered.
    ///   `LogData.unknownDistance` when no recent fix was available, or on an exit event.
    func addNotification(title:String, isInside:Bool, profile: String, distance: CLLocationDistance = LogData.unknownDistance) -> Bool{
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext

        let newNotification = NotificationData(context: context)
        newNotification.id = UUID()
        newNotification.isInside = isInside
        newNotification.title = title
        newNotification.onDate = Date()
        newNotification.mode = profile
        newNotification.distance = distance
        do {
            try context.save()
        } catch {
            print("Failed saving: \(error)")
            return false
        }
        
        return true
        
    }
    
    func deleteAllEntities(named entityName: String, context: NSManagedObjectContext) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to batch delete: \(error)")
        }
    }
}

class ApiLogData {
    
    func getAPILogs()-> [APILog]?{
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<APILog> = APILog.fetchRequest()
        do {
            let results = try context.fetch(fetchRequest)
            return results
        } catch {
            return nil
        }
    }
    
    func addAPILog(type:String, profile: String) -> Bool{
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
        let newNotification = APILog(context: context)
        
        newNotification.id = UUID()
        newNotification.onDate = Date()
        newNotification.mode = profile
        newNotification.type = type
        do {
            try context.save()
        } catch {
            print("Failed saving: \(error)")
            return false
        }
        
        return true
        
    }
    
    func deleteAllEntities(named entityName: String, context: NSManagedObjectContext) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to batch delete: \(error)")
        }
    }
}
