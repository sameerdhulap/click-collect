//
//  DistanceFormat.swift
//  Click&Collect
//
//  Created by Woosmap.
//

import CoreLocation

extension CLLocationDistance {

    /// Distance a user is expected to read: "Approx. 152 meters away" / "Approx. 1.2 Km away".
    /// Shared by the store list and the notification log so both read the same way.
    var approximateDistanceText: String {
        self > 500
            ? String(format: "Approx. %.1f Km away", self / 1000)
            : String(format: "Approx. %.0f meters away", self)
    }
}
