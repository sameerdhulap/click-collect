//
//  MapViewController.swift
//  Click&Collect
//
//  Created by WGS on 27/05/25.
//

import UIKit
import Woosmap

class RestaurantAnnotation: NSObject, MGLAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String) {
        self.coordinate = coordinate
        self.title = title
    }
}


class MapViewController: UIViewController {
    
    @IBOutlet weak var mapView: UIView!
    var woosmapView: WMMapView!
    var restaureantsLocation: CLLocationCoordinate2D?
    var restaureantsInfo:[String:String] = [:]
    override func viewDidLoad() {
        super.viewDidLoad()
        woosmapView = WMMapView(frame: self.mapView.bounds)
        woosmapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        woosmapView.delegate = self
        self.mapView.addSubview(woosmapView)
    }

}

extension MapViewController: WMMapViewDelegate {
    
    func mapView(_ mapView: WMMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? {
            let av = WMMarkerAnnotationView(annotation: annotation, reuseIdentifier: "Woozie")
            av.markerTintColor = UIColor.magenta
            av.glyphTintColor = UIColor.white
            av.glyphImage = UIImage(systemName: "circle.hexagongrid")
            return av
        }
        
        func mapViewDidFinishLoadingMap(_ mapView: WMMapView) {
            if let location = restaureantsLocation {
                woosmapView.add(RestaurantAnnotation(coordinate: location, title: ""))
                woosmapView.setCenter( location, animated: true )
                woosmapView.setCenter(location, zoomLevel: 15, animated: true)
            }
        }
    
}
