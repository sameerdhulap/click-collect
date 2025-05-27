//
//  ViewController.swift
//  Click&Collect
//
//  Created by Woosmap on 21/05/25.
//

import UIKit
import CoreLocation
import WoosmapGeofencing

extension UIViewController {
    open override func awakeAfter(using coder: NSCoder) -> Any? {
        navigationItem.backButtonDisplayMode = .minimal // This will help us to remove text
        return super.awakeAfter(using: coder)
    }
}

class ViewController: UIViewController {
    
    @IBOutlet weak var vwModeClickCollect: UIView!
    @IBOutlet weak var vwModeAsset: UIView!
    
    @IBOutlet weak var btnEta: UIButton!
    @IBOutlet weak var btnRestaurantLocation: UIButton!
    @IBOutlet weak var lblRestaureantName: UILabel!
    let AssetMonitoringAtributes = ["ProtectedRegionSlot":String(AppConfig.liveTracking.ProtectedRegionSlot),
                                    "radius":String(AppConfig.liveTracking.poiRadius),
                                    "action":String(AppConfig.liveTracking.poiRadius),
                                    "optimizeDistanceRequest":"false"]
    
    let ClickAndCollectAtributes = ["optimizeDistanceRequest":"false"]
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        vwModeClickCollect.layer.cornerRadius = 8
        vwModeClickCollect.clipsToBounds = true
        vwModeAsset.layer.cornerRadius = 8
        vwModeAsset.clipsToBounds = true
        if let currentProfile = ApplicationData().getProfile() {
            if(currentProfile.profile == "Asset Monitoring"){
                vwModeAsset.isHidden = false
                vwModeClickCollect.isHidden = !vwModeAsset.isHidden
            }else if(currentProfile.profile == "Click&Collect"){
                vwModeAsset.isHidden = true
                vwModeClickCollect.isHidden = !vwModeAsset.isHidden
                if let attributes = currentProfile.profileProperties {
                    if let name = attributes["name"]{
                        if let address = attributes["address"]{
                            lblRestaureantName.text = "\(name) \n\(address)"
                            
                        }
                        else{
                            lblRestaureantName.text = "\(name)"
                        }
                    }
                    if let location = attributes["location"]{
                        btnRestaurantLocation.setTitle("\(location)", for: .normal)
                        btnRestaurantLocation.setTitle("\(location)", for: .selected)
                        btnRestaurantLocation.setTitle("\(location)", for: .highlighted)
                    }
                }

            }
            else{
                debugPrint( "Something went wrong, Unknown Profile \(currentProfile.profile!)")
            }
        }
        else{
            // default to Asset monitoring
            let newProfileAdded = ApplicationData().addProfile( profile: "Asset Monitoring", attribute:AssetMonitoringAtributes)
            if(newProfileAdded){
                (UIApplication.shared.delegate as! AppDelegate).startMonitoringWithWoosmap()
            }
            vwModeAsset.isHidden = false
            vwModeClickCollect.isHidden = !vwModeAsset.isHidden
        }
    }
    
    @IBAction func onTapOrderForMe(_ sender: UIButton) {
        //Show Order form
        let storyboard = self.storyboard!
        if let modalVC = storyboard.instantiateViewController(withIdentifier: "OrderViewController") as? OrderViewController {
            modalVC.modalPresentationStyle = .formSheet // or .fullScreen, .pageSheet, etc.
            modalVC.modalTransitionStyle = .coverVertical // optional
            modalVC.delegate = self
            //            present(modalVC, animated: true, completion: nil)
            
            self.navigationController?.pushViewController(modalVC, animated: true)
        }
    }
    
    @IBAction func onTapOrderReceived(_ sender: UIButton) {
        
        let newProfileAdded = ApplicationData().addProfile( profile: "Asset Monitoring", attribute:AssetMonitoringAtributes)
        //Update UI
        if(newProfileAdded){
            if let currentProfile = ApplicationData().getProfile() {
                if(currentProfile.profile == "Asset Monitoring"){
                    vwModeAsset.isHidden = false
                    vwModeClickCollect.isHidden = !vwModeAsset.isHidden
                }
                else{
                    debugPrint( "Something went wrong, Unknown Profile \(currentProfile.profile!)")
                }
                //Change SDK Profile
                (UIApplication.shared.delegate as! AppDelegate).stopGeofencing()
                RegionIsochrones.deleteAll()
                (UIApplication.shared.delegate as! AppDelegate).startMonitoringWithWoosmap()
                WoosmapGeofenceManager.shared.refreshPOIs()
            }
        }
    }
    
    @IBAction func onTapCancelORder(_ sender: UIButton) {
        
        let newProfileAdded = ApplicationData().addProfile( profile: "Asset Monitoring", attribute:AssetMonitoringAtributes)
        //Update UI
        if(newProfileAdded){
            if let currentProfile = ApplicationData().getProfile() {
                if(currentProfile.profile == "Asset Monitoring"){
                    vwModeAsset.isHidden = false
                    vwModeClickCollect.isHidden = !vwModeAsset.isHidden
                }else{
                    debugPrint( "Something went wrong, Unknown Profile \(currentProfile.profile!)")
                }
                //Change SDK Profile
                (UIApplication.shared.delegate as! AppDelegate).stopGeofencing()
                RegionIsochrones.deleteAll()
                (UIApplication.shared.delegate as! AppDelegate).startMonitoringWithWoosmap()
                WoosmapGeofenceManager.shared.refreshPOIs()
            }
        }
    }
    
    @IBAction func onTapLog(_ sender: UIBarButtonItem) {
        let storyboard = self.storyboard!
        if let modalVC = storyboard.instantiateViewController(withIdentifier: "NotificationViewController") as? NotificationViewController {
            modalVC.modalPresentationStyle = .formSheet // or .fullScreen, .pageSheet, etc.
            modalVC.modalTransitionStyle = .coverVertical // optional
            
            self.navigationController?.pushViewController(modalVC, animated: true)
        }
    }
    @IBAction func onTapEta(_ sender: UIButton) {
        if let zone = ISOChroneData().getActiveZone(){
            if let attributes = zone.attribute{
                guard let id: String = attributes["id"] else { return }
                if let data = RegionIsochrones.getRegionFromId(id: id){
                    
                    let alertController = UIAlertController(title: "Eta", message: "Approximiatly \(data.durationText)", preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                        // Handle OK button tap
                    }
                    alertController.addAction(okAction)
                    present(alertController, animated: true, completion: nil)
                }
            }
        }
        else{
            sender.isHidden = true
        }
    }
    
    @IBAction func onTapShowLocation(_ sender: UIButton) {
        let storyboard = self.storyboard!
        if let modalVC = storyboard.instantiateViewController(withIdentifier: "MapViewController") as? MapViewController {
            modalVC.modalPresentationStyle = .formSheet // or .fullScreen, .pageSheet, etc.
            modalVC.modalTransitionStyle = .coverVertical // optional
            if let currentProfile = ApplicationData().getProfile() {
                if(currentProfile.profile == "Click&Collect"){
                    
                    if let attributes = currentProfile.profileProperties {
                        
                        if let location = attributes["location"]{
                            let coordinateArray = location.split(separator: ",").compactMap(Double.init)
                            let coordinate = CLLocationCoordinate2D(latitude: coordinateArray[0], longitude: coordinateArray[1])
                            modalVC.restaureantsLocation = coordinate
                            modalVC.restaureantsInfo = attributes
                            self.navigationController?.pushViewController(modalVC, animated: true)
                        }
                    }
                }
                else{
                    debugPrint( "Something went wrong, Unknown Profile \(currentProfile.profile!)")
                }
            }
        }
    }
}


extension ViewController:OrderDelegate{
    func OrderDelegate(_ manager: OrderViewController, OrderPlace info: [String : String]) {
        
        let attributes = info.merging(ClickAndCollectAtributes) { (_, new) in new }
        
        let newProfileAdded = ApplicationData().addProfile( profile: "Click&Collect", attribute:attributes)
        (UIApplication.shared.delegate as! AppDelegate).stopGeofencing()
        (UIApplication.shared.delegate as! AppDelegate).startMonitoringWithWoosmap()
        //Add Isochorne zone
        guard let coordinateString: String = attributes["location"] else { return }
        guard let id: String = attributes["id"] else { return }
        guard let durationRadius = attributes["radius"] else { return }
        let coordinateArray = coordinateString.split(separator: ",").compactMap(Double.init)
        let coordinate = CLLocationCoordinate2D(latitude: coordinateArray[0], longitude: coordinateArray[1])
        
        let (regionIsCreated, state) = WoosmapGeofenceManager.shared.getLocationService().addRegion(identifier: id, center: coordinate, radius: Int(durationRadius)!*60, type: "isochrone")
        //Add Isochorne zone
        //Update UI
        if(newProfileAdded && regionIsCreated){
            let _ = ISOChroneData().addRestaurant(latitude:coordinate.latitude,longitude: coordinate.longitude, attribute: attributes)
            if let currentProfile = ApplicationData().getProfile() {
               if(currentProfile.profile == "Click&Collect"){
                    vwModeAsset.isHidden = true
                    vwModeClickCollect.isHidden = !vwModeAsset.isHidden
                   if let name = attributes["name"]{
                       if let address = attributes["address"]{
                           lblRestaureantName.text = "\(name) \n\(address)"
                           
                       }
                       else{
                           lblRestaureantName.text = "\(name)"
                       }
                   }
                   if let location = attributes["location"]{
                       btnRestaurantLocation.setTitle("\(location)", for: .normal)
                       btnRestaurantLocation.setTitle("\(location)", for: .selected)
                       btnRestaurantLocation.setTitle("\(location)", for: .highlighted)
                   }
                   
                }
                else{
                    debugPrint( "Something went wrong, Unknown Profile \(currentProfile.profile!)")
                }
                //Change SDK Profile
            }
        }
        else{
            //TODO: raise error
            if(!regionIsCreated){
                debugPrint("Unable to create IsochroneZone : \(state)")
            }
        }
    }
}
