//
//  PassiveTrackingPOIViewController.swift
//  Click&Collect
//
//  Created by WGS on 04/08/25.
//

import UIKit
import WoosmapGeofencing

class PassiveTrackingPOIViewController: UIViewController {
    var tableData: [POI] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        tableData = POIs.getAll()
        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension PassiveTrackingPOIViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
   
}
extension PassiveTrackingPOIViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "poiCell", for: indexPath) as! poiCell
        let data = tableData[indexPath.row]
        cell.fillDetails(cellData: data)
//        cell.accessoryType = tableData[indexPath.row].store_id == selectedStore?.store_id ? .checkmark : .none
        return cell
    }
}

class poiCell: UITableViewCell {
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblStatus: UILabel!
    func fillDetails(cellData:POI){
        lblTitle.text = "\(cellData.idstore ?? "N/A") : \(cellData.name ?? "-")"
        if(cellData.openNow){
            lblStatus.text = "OPEN"
            lblStatus.textColor = UIColor(named: "palette3")
        }
        else {
            lblStatus.text = "CLOSED"
            lblStatus.textColor = UIColor(named: "palette4")
        }
    }
}
