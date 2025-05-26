//
//  ApplicationData.swift
//  Click&Collect
//
//  Created by Woosmap on 21/05/25.
//

import UIKit
import CoreData
class ApplicationData {
    
    func getProfile()-> AppData? {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<AppData> = AppData.fetchRequest()
        fetchRequest.fetchLimit = 1
        do {
            let results = try context.fetch(fetchRequest)
            return results.first
        } catch {
            return nil
        }
    }
    
    func addProfile(profile:String, attribute:[String:String]) -> Bool{
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        self.deleteAllEntities(named: "AppData", context: context)
        
        let newRow = AppData(context: context)
        newRow.profile = profile
        newRow.profileProperties = attribute
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

class ISOChroneData {
    func addRestaurant(latitude:Double, longitude:Double, attribute:[String:String]) -> Bool{
        guard  let _ = ApplicationData().getProfile() else {
            return false
        }
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let newRow = ISOChrone(context: context)
        newRow.id = UUID()
        newRow.addedOn = Date()
        newRow.updatedOn = Date()
        newRow.distanceRequest = 0
        newRow.latitude = latitude
        newRow.longitude = longitude
        newRow.attribute = attribute
        
        do {
            try context.save()
        } catch {
            print("Failed saving: \(error)")
            return false
        }
        return true
    }
    
    
    func fetchLastObject<T: NSManagedObject>(ofType type: T.Type, context: NSManagedObjectContext) throws -> T? {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        
        // Sort by a property (e.g., creationDate or a timestamp, or objectID if you don’t have one)
        // Replace "creationDate" with the appropriate property
        request.sortDescriptors = [NSSortDescriptor(key: "addedOn", ascending: false)]
        
        // Only fetch one object
        request.fetchLimit = 1

        let result = try context.fetch(request)
        return result.first
    }
    
    func updateCount(isReached:Bool){
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        
        let last =  try! fetchLastObject(ofType: ISOChrone.self, context: context)
        if let update = last {
            if(isReached){
                update.fullfillOn = Date()
            }
            else{
                update.distanceRequest += 1
            }
            update.updatedOn = Date()
            do {
                try context.save()
            } catch {
                print("Failed saving: \(error)")
            }
        }
           
    }
}
