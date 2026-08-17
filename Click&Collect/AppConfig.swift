//
//  AppConfig.swift
//  Click&Collect
//
//  Created by WGS on 26/05/25.
//
struct AppConfig {
    static let privateKey: String = "3cd8ada3-e14f-47d1-90b4-5587c824ba8a"
    struct liveTracking {
        static let isochroneDistance: Int = 10 //minutes
        static let distanceDisplacementFilter : Int = 30 //meters
    }
    
    struct passiveTracking {
        static let poiRadius: Int = 100 //meters
        static let ProtectedRegionSlot: Int = 0
    }
    
}

