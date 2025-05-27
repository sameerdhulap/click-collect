//
//  OrderViewController.swift
//  Click&Collect
//
//  Created by Woosmap on 21/05/25.
//

import Foundation
import UIKit
import CoreLocation
import Woosmap

protocol OrderDelegate {
    func OrderDelegate(_ manager: OrderViewController, OrderPlace info: [String:String])
    
}

class OrderViewController: UIViewController {
    
    
    var currentLocation: CLLocation?
    var tableData: [WMStoresService.Store] = []
    var selectedStore:WMStoresService.Store?
    var selectedMode: String = "walking"
    var modeArray : [String] = ["walking","driving"]
    public var delegate:OrderDelegate?
    
    @IBOutlet weak var tblRestaurant: UITableView!
    @IBOutlet weak var vwWaitView: UIView!
    
    @IBOutlet weak var btnLocationCoordinate: UIButton!
    @IBOutlet weak var btnPlaceOrder: UIButton!
    @IBOutlet weak var vwOrderInfo: UIView!
    @IBOutlet weak var lblSelectedAddress: UILabel!
    
    @IBOutlet weak var lblMode: UILabel!
    @IBOutlet weak var btnPreviousMode: UIButton!
    @IBOutlet weak var btnNextMode: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let desiredColor: UIColor = UIColor.white
        self.tblRestaurant.backgroundColor = desiredColor;
        self.tblRestaurant.backgroundView?.backgroundColor = desiredColor;
        vwOrderInfo.isHidden = true
        lblMode.text = modeArray[0]
        vwWaitView.isHidden = false
        //Fetch current location
        let locationMgr = CLLocationManager()
        locationMgr.delegate = self
        locationMgr.requestLocation()
        
        
    }
    @IBAction func onTapLocateStore(_ sender: UIButton) {
        let storyboard = self.storyboard!
        if let modalVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
            modalVC.modalPresentationStyle = .formSheet // or .fullScreen, .pageSheet, etc.
            modalVC.modalTransitionStyle = .coverVertical // optional
            
            if let storeInfo = selectedStore{
                modalVC.restaureantsLocation = storeInfo.location
                
                var addressLine = ""
                if let address = storeInfo.address {
                    if(address.lines.count > 0){
                        addressLine = address.lines.joined(separator: ",")
                    }
                }
                modalVC.restaureantsInfo = ["id": storeInfo.store_id, "name": storeInfo.name,"address": addressLine, "location": "\(storeInfo.coordinate.latitude),\(storeInfo.coordinate.longitude)", "radius": String(AppConfig.liveTracking.isochroneDistance) ,"distanceMode": selectedMode]
            }
            self.navigationController?.pushViewController(modalVC, animated: true)
        }
    }
    func fetchStore(location: CLLocationCoordinate2D) async -> [WMStoresService.Store]{
       
        var filterStore: [WMStoresService.Store] = []
        let assetRequest = WMStoresService.SearchRequest()
        assetRequest.query = nil
        assetRequest.limit = 5
        assetRequest.location = WMLocation.init(coordinates:  location)
        var assetResult: [WMStoresService.Store]?
        do{
            assetResult = try await WMApi.stores.search(assetRequest)
        }
        catch let error as NSError{
            print("Error: \(error)")
        }
        
        if let result = assetResult{
            result.forEach({ match in
                filterStore.append(match)
            })
        }
        return filterStore
    }
    @IBAction func onTapPervMode(_ sender: UIButton) {
        if let index = modeArray.firstIndex(of: selectedMode){
            lblMode.text = index == 0 ? modeArray.last :modeArray[index-1]
            selectedMode = lblMode.text!
        }
    }
    @IBAction func onTapNextMode(_ sender: UIButton) {
        if let index = modeArray.firstIndex(of: selectedMode){
            lblMode.text = index == modeArray.count-1 ? modeArray.first :modeArray[index+1]
            selectedMode = lblMode.text!
        }
    }
    
    @IBAction func onTapPlaceOrder(_ sender: UIButton) {
        if let store = selectedStore{
            
            let alertController = UIAlertController(title: "Your order placed for \(store.name)", message: "Walk in to pick it up; we will start preparing it once you get near the restaurant so you can enjoy hot and fresh food.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                // Handle OK button tap
                
                self.navigationController?.popViewController(animated: true)
            }
            alertController.addAction(okAction)
            
            var addressLine = ""
            if let address = store.address {
                if(address.lines.count > 0){
                    addressLine = address.lines.joined(separator: ",")
                }
            }
            
            delegate?.OrderDelegate(self, OrderPlace: ["id": store.store_id, "name": store.name,"address": addressLine, "location": "\(store.coordinate.latitude),\(store.coordinate.longitude)", "radius": String(AppConfig.liveTracking.isochroneDistance) ,"distanceMode": selectedMode])
            present(alertController, animated: true, completion: nil)
            
        }
        else{
            let alertController = UIAlertController(title: "Error", message: "Please select a store", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                // Handle OK button tap
            }
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
            
        }
        
    }
    
}
extension OrderViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        //Load store around me
        Task {
            if let location = currentLocation{
                self.tableData = await fetchStore(location: location.coordinate)
                self.tblRestaurant.reloadData()
                vwWaitView.isHidden = true
            }
            
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        debugPrint(error)
    }
}

extension OrderViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedStore = tableData[indexPath.row]
        tableView.reloadData()
        vwOrderInfo.isHidden = false
        if let storeInfo = selectedStore{
            if let address = storeInfo.address {
                if(address.lines.count > 0){
                    lblSelectedAddress.text = "\(storeInfo.name) \n\(address.lines.joined(separator: ","))"
                }
                else{
                    lblSelectedAddress.text = "\(storeInfo.name)"
                }
            }
            else{
                lblSelectedAddress.text = "\(storeInfo.name)"
            }
            btnLocationCoordinate.setTitle("\(storeInfo.location.latitude),\(storeInfo.location.longitude)", for: .normal)
            btnLocationCoordinate.setTitle("\(storeInfo.location.latitude),\(storeInfo.location.longitude)", for: .selected)
            btnLocationCoordinate.setTitle("\(storeInfo.location.latitude),\(storeInfo.location.longitude)", for: .highlighted)
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
   
}
extension OrderViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StoreCell", for: indexPath) as! StoreCell
        cell.accessoryType = tableData[indexPath.row].store_id == selectedStore?.store_id ? .checkmark : .none
        cell.fillDetails(location: currentLocation!.coordinate , data: tableData[indexPath.row] , isSelected: false)
        return cell
    }
    
}

class StoreCell: UITableViewCell {
    
    @IBOutlet weak var lblRestaurantName: UILabel!
    
    @IBOutlet weak var lblDistance: UILabel!
    
    func fillDetails(location:CLLocationCoordinate2D, data:WMStoresService.Store, isSelected:Bool){
        let distance = CLLocation.init(latitude: location.latitude, longitude: location.longitude).distance(from: CLLocation.init(latitude: data.location.latitude, longitude: data.location.longitude))
        if let address = data.address {
            if(address.lines.count > 0){
                lblRestaurantName.text = "\(data.name) \n\(address.lines.joined(separator: ","))"
            }
            else{
                lblRestaurantName.text = "\(data.name)"
            }
        }
        else{
            lblRestaurantName.text = "\(data.name)"
        }
        if distance > 500 {
            lblDistance.text = String(format: "Approx. %.1f Km away", distance/1000)
        }
        else{
            lblDistance.text = String(format: "Approx. %.0f meters away", distance)
        }
        
    }
    
}
