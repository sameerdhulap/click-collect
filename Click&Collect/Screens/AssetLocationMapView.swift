//
//  AssetLocationMapView.swift
//  Click&Collect
//
//  Created by Woosmap.
//

import UIKit
import MapKit

/// Apple map that follows the device location and draws its horizontal accuracy.
/// Used by the Asset Monitoring mode of `ViewController`.
final class AssetLocationMapView: UIView {

    private enum Constants {
        static let initialSpan: CLLocationDistance = 500
        static let cornerRadius: CGFloat = 8
        static let labelInset: CGFloat = 8
    }

    private let mapView = MKMapView()
    private let accuracyLabel = UILabel()
    private let locationManager = CLLocationManager()
    private var accuracyCircle: MKCircle?
    private var hasCenteredOnUser = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSubviews()
    }

    /// Shows the blue dot and follows it. Safe to call repeatedly.
    func startTracking() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        mapView.showsUserLocation = true
        mapView.setUserTrackingMode(.follow, animated: true)
    }

    /// Stops following so the map does not keep the location hardware awake while hidden.
    func stopTracking() {
        mapView.setUserTrackingMode(.none, animated: false)
        mapView.showsUserLocation = false
    }

    private func setupSubviews() {
        layer.cornerRadius = Constants.cornerRadius
        clipsToBounds = true
        setupMapView()
        setupAccuracyLabel()
    }

    private func setupMapView() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.showsCompass = true
        addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: topAnchor),
            mapView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func setupAccuracyLabel() {
        accuracyLabel.translatesAutoresizingMaskIntoConstraints = false
        accuracyLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        accuracyLabel.textColor = .label
        accuracyLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        accuracyLabel.textAlignment = .center
        accuracyLabel.numberOfLines = 1
        accuracyLabel.layer.cornerRadius = 4
        accuracyLabel.clipsToBounds = true
        accuracyLabel.text = "Waiting for a location fix…"
        addSubview(accuracyLabel)
        NSLayoutConstraint.activate([
            accuracyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.labelInset),
            accuracyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.labelInset),
            accuracyLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Constants.labelInset),
            accuracyLabel.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    /// Refreshes the accuracy circle and the readout for the latest fix.
    private func render(_ location: CLLocation) {
        updateAccuracyCircle(for: location)
        updateAccuracyLabel(for: location)
        centerOnFirstFix(location)
    }

    private func updateAccuracyCircle(for location: CLLocation) {
        if let circle = accuracyCircle {
            mapView.removeOverlay(circle)
            accuracyCircle = nil
        }
        guard location.horizontalAccuracy > 0 else { return }
        let circle = MKCircle(center: location.coordinate, radius: location.horizontalAccuracy)
        mapView.addOverlay(circle)
        accuracyCircle = circle
    }

    private func updateAccuracyLabel(for location: CLLocation) {
        let coordinates = String(format: "%.5f, %.5f",
                                 location.coordinate.latitude,
                                 location.coordinate.longitude)
        guard location.horizontalAccuracy > 0 else {
            accuracyLabel.text = "\(coordinates)  ·  accuracy unavailable"
            return
        }
        accuracyLabel.text = String(format: "%@  ·  ± %.0f m", coordinates, location.horizontalAccuracy)
    }

    private func centerOnFirstFix(_ location: CLLocation) {
        guard !hasCenteredOnUser else { return }
        hasCenteredOnUser = true
        mapView.setRegion(MKCoordinateRegion(center: location.coordinate,
                                             latitudinalMeters: Constants.initialSpan,
                                             longitudinalMeters: Constants.initialSpan),
                          animated: true)
    }
}

extension AssetLocationMapView: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        guard let location = userLocation.location else { return }
        render(location)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let circle = overlay as? MKCircle else {
            return MKOverlayRenderer(overlay: overlay)
        }
        let renderer = MKCircleRenderer(circle: circle)
        renderer.fillColor = UIColor.systemBlue.withAlphaComponent(0.15)
        renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.6)
        renderer.lineWidth = 1
        return renderer
    }
}
