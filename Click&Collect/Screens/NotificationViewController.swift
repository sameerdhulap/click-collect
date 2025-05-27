//
//  NotificationViewController.swift
//  Click&Collect
//
//  Created by WGS on 26/05/25.
//
import UIKit

internal extension URL {
    
    /// Creates a zip archive of the file or folder represented by this URL and returns a references to the zipped file
    ///
    /// - parameter dest: the destination URL; if nil, the destination will be this URL with ".zip" appended
    func zip(toFileAt dest: URL? = nil) throws -> URL
    {
        let destURL = dest ?? self.appendingPathExtension("zip")
        
        let fm = FileManager.default
        var isDir: ObjCBool = false
        
        let srcDir: URL
        let srcDirIsTemporary: Bool
        if self.isFileURL && fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue == true {
            // this URL is a directory: just zip it in-place
            srcDir = self
            srcDirIsTemporary = false
        }
        else {
            // otherwise we need to copy the simple file to a temporary directory in order for
            // NSFileCoordinatorReadingOptions.ForUploading to actually zip it up
            srcDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
            try fm.createDirectory(at: srcDir, withIntermediateDirectories: true, attributes: nil)
            let tmpURL = srcDir.appendingPathComponent(self.lastPathComponent)
            try fm.copyItem(at: self, to: tmpURL)
            srcDirIsTemporary = true
        }
        
        let coord = NSFileCoordinator()
        var readError: NSError?
        var copyError: NSError?
        var errorToThrow: NSError?
        
        var readSucceeded:Bool = false
        // coordinateReadingItemAtURL is invoked synchronously, but the passed in zippedURL is only valid
        // for the duration of the block, so it needs to be copied out
        coord.coordinate(readingItemAt: srcDir,
                         options: NSFileCoordinator.ReadingOptions.forUploading,
                         error: &readError)
        {
            (zippedURL: URL) -> Void in
            readSucceeded = true
            // assert: read succeeded
            do {
                try fm.copyItem(at: zippedURL, to: destURL)
            } catch let caughtCopyError {
                copyError = caughtCopyError as NSError
            }
        }
        
        if let theReadError = readError, !readSucceeded {
            // assert: read failed, readError describes our reading error
            debugPrint("sampleapp: zipping failed")
            errorToThrow =  theReadError
        }
        else if readError == nil && !readSucceeded  {
            debugPrint("sampleapp: NSFileCoordinator has violated its API contract. It has errored without throwing an error object")
            errorToThrow = NSError.init(domain: Bundle.main.bundleIdentifier!, code: 0, userInfo: nil)
        }
        else if let theCopyError = copyError {
            // assert: read succeeded, copy failed
            debugPrint("sampleapp: zipping succeeded but copying the zip file failed")
            errorToThrow = theCopyError
        }
        
        if srcDirIsTemporary {
            do {
                try fm.removeItem(at: srcDir)
            }
            catch {
                // Not going to throw, because we do have a valid output to return. We're going to rely on
                // the operating system to eventually cleanup the temporary directory.
                debugPrint("sampleapp: Warning. Zipping succeeded but could not remove temporary directory afterwards")
            }
        }
        if let error = errorToThrow { throw error }
        return destURL
    }
}

private extension Data {
    
    /// Creates a zip archive of this data via a temporary file and returns the zipped contents
    func zip() throws -> NSData {
        let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try self.write(to: tmpURL, options: NSData.WritingOptions.atomic)
        let zipURL = try tmpURL.zip()
        let fm = FileManager.default
        let zippedData = try NSData(contentsOf: zipURL, options: NSData.ReadingOptions())
        try fm.removeItem(at: tmpURL) // clean up
        try fm.removeItem(at: zipURL)
        return zippedData
    }
    
    func getDocumentsDirectory() -> NSString {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        return documentsDirectory as NSString
    }
    
    /// Data into file
    ///
    /// - Parameters:
    ///   - fileName: the Name of the file you want to write
    /// - Returns: Returns the URL where the new file is located in NSURL
    func dataToFile(fileName: String) -> NSURL? {
        
        // Make a constant from the data
        let data = self
        
        // Make the file path (with the filename) where the file will be loacated after it is created
        let filePath = getDocumentsDirectory().appendingPathComponent(fileName)
        
        do {
            // Write the file from data into the filepath (if there will be an error, the code jumps to the catch block below)
            try data.write(to: URL(fileURLWithPath: filePath))
            
            // Returns the URL where the new file is located in NSURL
            return NSURL(fileURLWithPath: filePath)
            
        } catch {
            // debugPrint the localized description of the error from the do block
            debugPrint("sampleapp: Error writing the file: \(error.localizedDescription)")
        }
        
        // Returns nil if there was an error in the do-catch -block
        return nil
        
    }
    
}

class NotificationViewController: UIViewController {
    var tableData: [NotificationData] = []
    @IBOutlet weak var tableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        let desiredColor: UIColor = UIColor.white
        self.tableView.backgroundColor = desiredColor;
        self.tableView.backgroundView?.backgroundColor = desiredColor;

        tableData = LogData().getLogs() ?? []
    }
    @IBAction func onTapDownloadDB(_ sender: UIBarButtonItem) {
        let relPath = ("~/Library/Application Support/Woosmap.sqlite" as NSString).expandingTildeInPath
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: relPath) {
            
            do {
                let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
                try context.save()
                
                //Delete perviously saved file
                let lastSaved = ("~/Documents/AppDump.zip" as NSString).expandingTildeInPath
                if fileManager.fileExists(atPath: lastSaved) {
                    try fileManager.removeItem(atPath: lastSaved)
                }
                
                let sourceURL = URL(fileURLWithPath: ("~/Library/Application Support" as NSString).expandingTildeInPath)
                let destURL = URL(fileURLWithPath:  ("~/Documents/AppDump.zip" as NSString).expandingTildeInPath)
                let outcome = try sourceURL.zip(toFileAt: destURL)
                
                // Create the Array which includes the files you want to share
                var filesToShare = [Any]()
                
                // Add the path of the file to the Array
                filesToShare.append(outcome)
                
                // Make the activityViewContoller which shows the share-view
                let activityViewController = UIActivityViewController(activityItems: filesToShare, applicationActivities: nil)
                
                // Show the share-view
                self.present(activityViewController, animated: true, completion: nil)
                
                
            } catch {
                debugPrint("sampleapp: Failed to read database")
            }
        }
        else{
            debugPrint("sampleapp: No Database found")
        }
    }
}

extension NotificationViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        selectedStore = tableData[indexPath.row]
//        tableView.reloadData()
//        vwOrderInfo.isHidden = false
//        if let storeInfo = selectedStore{
//            if let address = storeInfo.address {
//                if(address.lines.count > 0){
//                    lblSelectedAddress.text = "\(storeInfo.name) \n\(address.lines.joined(separator: ","))"
//                }
//                else{
//                    lblSelectedAddress.text = "\(storeInfo.name)"
//                }
//            }
//            else{
//                lblSelectedAddress.text = "\(storeInfo.name)"
//            }
//            btnLocationCoordinate.setTitle("\(storeInfo.location.latitude),\(storeInfo.location.longitude)", for: .normal)
//            btnLocationCoordinate.setTitle("\(storeInfo.location.latitude),\(storeInfo.location.longitude)", for: .selected)
//            btnLocationCoordinate.setTitle("\(storeInfo.location.latitude),\(storeInfo.location.longitude)", for: .highlighted)
//        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
   
}
extension NotificationViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath) as! NotificationCell
        let data = tableData[indexPath.row]
        cell.fillDetails(title: data.title!, date: data.onDate!, mode: data.mode!)
//        cell.accessoryType = tableData[indexPath.row].store_id == selectedStore?.store_id ? .checkmark : .none
        return cell
    }
    
}

class NotificationCell: UITableViewCell {
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblDate: UILabel!
    @IBOutlet weak var lblMode: UILabel!
    func fillDetails(title:String, date:Date, mode:String){
        lblTitle.text = title
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd hh:mm a"
        lblDate.text = formatter.string(from: date)
        if(mode == "Asset Monitoring"){
            guard let bgColor = UIColor(named: "palette2") else {
                fatalError("Color not found in assets!")
            }
            
            self.backgroundColor = bgColor
        }
        else if(mode == "Click&Collect"){
            guard let bgColor = UIColor(named: "palette3") else {
                fatalError("Color not found in assets!")
            }
            self.backgroundColor = bgColor
        }
        else{
            self.backgroundColor = UIColor.white
        }
    }
}
