//
//  AppConfig.swift
//  Click&Collect
//
//  Created by WGS on 26/05/25.
//
import Foundation

struct AppConfig {
    /// Woosmap private API key. Defined as `DEFAULT_PRIVATE_KEY` in `AppSecret.xcconfig`,
    /// substituted into the `WMKey` Info.plist entry at build time and read back here, so
    /// the key never lives in source. Empty when the xcconfig is missing — API calls then fail.
    static let privateKey: String = Bundle.main.object(forInfoDictionaryKey: "WMKey") as? String ?? ""
    struct liveTracking {
        static let isochroneDistance: Int = 10 //minutes
        static let distanceDisplacementFilter : Int = 30 //meters
    }
    
    struct passiveTracking {
        static let poiRadius: Int = 100 //meters
        /// Store user property the POI radius is read from, matching the key the
        /// geofencing SDK reads by default. `poiRadius` is used when a store omits it.
        static let poiRadiusProperty: String = "radius"
        static let ProtectedRegionSlot: Int = 0
    }
    
}

