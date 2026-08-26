//
//  AssetLocationMapView.swift
//  Click&Collect
//
//  Created by Woosmap.
//

import UIKit
import MapKit
import Woosmap

/// Pin for a Woosmap store, carrying the geofence radius read from its user properties.
/// Selecting it opens a callout with the store id — the same id the geofence events and
/// the notification log use, so a pin can be matched to an event.
private final class POIAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let identifier: String
    let radius: CLLocationDistance

    init(store: WMStoresService.Store, radius: CLLocationDistance) {
        self.coordinate = store.location
        self.title = store.name
        self.identifier = store.store_id
        self.subtitle = String(format: "ID %@  ·  radius %.0f m", store.store_id, radius)
        self.radius = radius
    }
}

/// Apple map that follows the device location and draws its horizontal accuracy.
/// The "POIs" switch overlays the nearest Woosmap stores with their geofence radius.
/// Used by the Asset Monitoring mode of `ViewController`.
final class AssetLocationMapView: UIView {

    private enum Constants {
        static let initialSpan: CLLocationDistance = 500
        static let cornerRadius: CGFloat = 8
        static let labelInset: CGFloat = 8
        /// Nearest stores requested when the POI switch is on.
        static let poiLimit: UInt = 20
        static let poiReuseIdentifier = "POIAnnotation"
    }

    private let mapView = MKMapView()
    private let accuracyLabel = UILabel()
    private let poiSwitch = UISwitch()
    private let poiToggleBar = UIStackView()
    private let locationManager = CLLocationManager()
    private var accuracyCircle: MKCircle?
    private var poiAnnotations: [POIAnnotation] = []
    private var poiCircles: [MKCircle] = []
    /// Set when the switch is turned on before any fix exists; the first fix then fetches once.
    private var poiFetchPending = false
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
        setupPOIToggle()
    }

    private func setupMapView() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.showsCompass = true
        mapView.register(MKMarkerAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: Constants.poiReuseIdentifier)
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

    private func setupPOIToggle() {
        let caption = UILabel()
        caption.text = "POIs"
        caption.font = .systemFont(ofSize: 13, weight: .semibold)
        caption.textColor = .label

        poiSwitch.isOn = false
        poiSwitch.addTarget(self, action: #selector(poiVisibilityChanged), for: .valueChanged)

        poiToggleBar.translatesAutoresizingMaskIntoConstraints = false
        poiToggleBar.axis = .horizontal
        poiToggleBar.alignment = .center
        poiToggleBar.spacing = 6
        poiToggleBar.isLayoutMarginsRelativeArrangement = true
        poiToggleBar.layoutMargins = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 6)
        poiToggleBar.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.85)
        poiToggleBar.layer.cornerRadius = 18
        poiToggleBar.clipsToBounds = true
        poiToggleBar.addArrangedSubview(caption)
        poiToggleBar.addArrangedSubview(poiSwitch)
        addSubview(poiToggleBar)
        NSLayoutConstraint.activate([
            poiToggleBar.topAnchor.constraint(equalTo: topAnchor, constant: Constants.labelInset),
            poiToggleBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.labelInset)
        ])
    }

    /// Refreshes the accuracy circle and the readout for the latest fix.
    private func render(_ location: CLLocation) {
        updateAccuracyCircle(for: location)
        updateAccuracyLabel(for: location)
        centerOnFirstFix(location)
        fetchPendingPOIs(from: location)
    }

    private func updateAccuracyCircle(for location: CLLocation) {
        if let circle = accuracyCircle {
            mapView.removeOverlay(circle)
            accuracyCircle = nil
        }
        guard location.horizontalAccuracy > 0 else { return }
        let circle = MKCircle(center: location.coordinate, radius: location.horizontalAccuracy)
        accuracyCircle = circle
        mapView.addOverlay(circle)
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

    // MARK: - POIs

    /// The only place POIs are fetched: the switch going on. Location updates never refetch,
    /// so the pins stay put until the user toggles the layer off and on again.
    @objc private func poiVisibilityChanged() {
        guard poiSwitch.isOn else {
            poiFetchPending = false
            clearPOIs()
            return
        }
        guard let location = mapView.userLocation.location else {
            poiFetchPending = true
            return
        }
        loadPOIs(around: location)
    }

    /// Covers the switch being turned on before the first fix arrived.
    private func fetchPendingPOIs(from location: CLLocation) {
        guard poiFetchPending, poiSwitch.isOn else { return }
        poiFetchPending = false
        loadPOIs(around: location)
    }

    private func loadPOIs(around location: CLLocation) {
        Task { @MainActor in
            let stores = await nearestStores(to: location.coordinate)
            guard poiSwitch.isOn else { return }
            showPOIs(stores)
        }
    }

    private func nearestStores(to coordinate: CLLocationCoordinate2D) async -> [WMStoresService.Store] {
        let request = WMStoresService.SearchRequest()
        request.query = nil
        request.limit = Constants.poiLimit
        request.location = WMLocation.init(coordinates: coordinate)
        var result: [WMStoresService.Store]?
        do {
            result = try await WMApi.stores.search(request)
        }
        catch let error as NSError {
            debugPrint("sampleapp: POI search failed \(error)")
        }
        return result ?? []
    }

    /// Draws the pins. The camera is left alone: zooming out to fit every POI would fight
    /// both follow mode and any zoom the user set to inspect a specific geofence.
    private func showPOIs(_ stores: [WMStoresService.Store]) {
        clearPOIs()
        guard !stores.isEmpty else { return }
        stores.forEach { store in
            let radius = geofenceRadius(for: store)
            poiAnnotations.append(POIAnnotation(store: store, radius: radius))
            poiCircles.append(MKCircle(center: store.location, radius: radius))
        }
        mapView.addAnnotations(poiAnnotations)
        mapView.addOverlays(poiCircles)
    }

    private func clearPOIs() {
        mapView.removeAnnotations(poiAnnotations)
        mapView.removeOverlays(poiCircles)
        poiAnnotations.removeAll()
        poiCircles.removeAll()
    }

    /// Geofence radius for a store: its `radius` user property — the key the geofencing SDK
    /// reads by default — falling back to the radius configured in `AppConfig`.
    private func geofenceRadius(for store: WMStoresService.Store) -> CLLocationDistance {
        let fallback = CLLocationDistance(AppConfig.passiveTracking.poiRadius)
        guard let value = store.user_properties?[AppConfig.passiveTracking.poiRadiusProperty] else { return fallback }
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let text = value as? String, let parsed = Double(text) {
            return parsed
        }
        return fallback
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
        // Anything that is not a POI is the user's accuracy circle, which stays blue.
        let isPOI = poiCircles.contains { $0 === circle }
        let tint: UIColor = isPOI ? .systemOrange : .systemBlue
        renderer.fillColor = tint.withAlphaComponent(0.15)
        renderer.strokeColor = tint.withAlphaComponent(isPOI ? 0.8 : 0.9)
        renderer.lineWidth = 1
        return renderer
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // Leave the blue dot to the system.
        guard annotation is POIAnnotation else { return nil }
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: Constants.poiReuseIdentifier,
                                                         for: annotation) as? MKMarkerAnnotationView
        view?.markerTintColor = .systemOrange
        view?.glyphImage = UIImage(systemName: "mappin.and.ellipse")
        view?.layer.opacity = 0.7
        view?.canShowCallout = true
        return view
    }
}
