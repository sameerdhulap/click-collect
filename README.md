# Click & Collect — Woosmap Geofencing iOS sample

A small UIKit demo app showing how to drive the [Woosmap Geofencing iOS SDK](https://github.com/Woosmap/geofencing-ios-sdk-spm-release)
through the two tracking profiles a click-and-collect use case needs:

| Mode | SDK profile | What it does |
| --- | --- | --- |
| **Asset Monitoring** (idle) | `.passiveTracking` | Low-power background tracking. The SDK searches nearby stores with the Woosmap Search API, creates circular geofences around them (300 m) and notifies the user when they walk into one. |
| **Click & Collect** (order placed) | `.liveTracking` | Higher-frequency tracking with an isochrone geofence around the chosen restaurant. The Distance API estimates the ETA, and the app notifies "your burger is ready" once the user is ~10 minutes away. |

The app switches profiles at runtime: placing an order moves it to live tracking,
receiving or cancelling the order moves it back to passive asset monitoring.

## Requirements

- Xcode 16 or later (the project uses file-system-synchronized groups, `objectVersion = 77`)
- iOS 16.6+ device or simulator
- Swift 5

Dependencies are resolved with Swift Package Manager, no CocoaPods step:

- `Woosmap/geofencing-ios-sdk-spm-release` 4.6.1 — geofencing, Search API, Distance API
- `Woosmap/sdk-ios-distribution` 1.1.0 — Woosmap map & Stores API (`WMMapView`, `WMApi.stores`)

## Getting started

1. Open `Click&Collect.xcodeproj` and let SPM resolve the two packages.
2. Put your own Woosmap private API key in [AppConfig.swift](Click&Collect/AppConfig.swift):

   ```swift
   static let privateKey: String = "<your-woosmap-private-key>"
   ```

   The key currently in the file is a demo key committed to the repo — replace it before
   using the app against your own Woosmap project, and never ship a production key this way.
3. Build & run. On first launch the app asks for location and notification permission,
   defaults to the **Asset Monitoring** profile, and starts tracking.

Geofencing needs real movement to be interesting. On the simulator, use
*Features ▸ Location ▸ Freeway Drive*, or push a fix from the command line:

```bash
xcrun simctl location booted set 48.8566,2.3522
```

## Configuration

All tunables live in [AppConfig.swift](Click&Collect/AppConfig.swift):

| Setting | Default | Meaning |
| --- | --- | --- |
| `liveTracking.isochroneDistance` | 10 min | Isochrone radius requested around the restaurant (stored in seconds as `minutes × 60`) |
| `liveTracking.distanceDisplacementFilter` | 30 m | Minimum displacement before a new Distance API call |
| `passiveTracking.poiRadius` | 300 m | Radius of the circular geofences built around nearby stores |
| `passiveTracking.ProtectedRegionSlot` | 0 | Number of the 20 iOS region slots reserved for the app's own regions |

## Screens

| Screen | File | Purpose |
| --- | --- | --- |
| Home | [ViewController.swift](Click&Collect/Screens/ViewController.swift) | Shows the active mode. In Asset Monitoring it displays an Apple map with the user location; in Click & Collect it shows the restaurant, the ETA and the Distance API call counter. |
| Order | [OrderViewController.swift](Click&Collect/Screens/OrderViewController.swift) | Lists the 30 nearest stores (Woosmap Stores API) sorted by straight-line distance, lets the user pick walking/driving and place the order. |
| Store map | [MapViewController.swift](Click&Collect/Screens/MapViewController.swift) | Woosmap `WMMapView` centred on the selected restaurant. |
| Location map | [AssetLocationMapView.swift](Click&Collect/Screens/AssetLocationMapView.swift) | MapKit view embedded in the home screen: blue dot, an accuracy circle and a `lat, lon · ± n m` readout. |
| Event log | [NotificationViewController.swift](Click&Collect/Screens/NotificationViewController.swift) | History of geofence notifications — enter events also show how far the user was from the POI — plus a toolbar action that exports the databases for debugging. |
| Monitored POIs | [PassiveTrackingPOIViewController.swift](Click&Collect/Screens/PassiveTrackingPOIViewController.swift) | The POIs the SDK is currently geofencing, with their open/closed status. Reached from the "POIs arround you" button on the event log. |

## How it fits together

```
AppDelegate
  ├── startMonitoringWithWoosmap()  →  WoosmapGeofenceActor.start()
  │        reads the stored profile, sets the API key, wires the delegates
  │        and calls startTracking(configurationProfile: .passiveTracking | .liveTracking)
  ├── stopGeofencing()              →  stops tracking, clears POIs, isochrones and notifications
  └── persistentContainer           →  Core Data stack ("CollectionBox")

WoosmapEvent  (LocationService / SearchAPI / Regions / Visit / DistanceAPI delegates)
  ├── builds the local notifications on region enter/exit
  ├── writes the log rows (NotificationData, APILog)
  └── re-posts every SDK callback as an NSNotification (.newLocationSaved,
      .newPOISaved, .updateRegions, .didEventPOIRegion, .distanceRequested)
```

- [AppDelegate.swift](Click&Collect/AppDelegate.swift) — app lifecycle, notification permission,
  Core Data stack, and `WoosmapGeofenceActor`, the actor that configures and starts the SDK.
  Its work is hopped to `@MainActor` because the SDK is main-thread bound.
- [WoosmapEvents.swift](Click&Collect/WoosmapEvents.swift) — the single delegate object for all SDK
  callbacks; also where notification copy is composed.
- [PersistanceData/](Click&Collect/PersistanceData) — thin Core Data wrappers over four entities:
  `AppData` (the active profile and its attributes), `ISOChrone` (the ordered-from restaurant and
  its Distance API counter), `NotificationData` and `APILog` (debug logs).

The active profile is stored as a single `AppData` row whose `profileProperties` dictionary carries
the mode-specific settings (`radius`, `ProtectedRegionSlot`, `distanceMode`, `optimizeDistanceRequest`,
and the chosen store's id/name/address/location). `ApplicationData().addProfile(...)` replaces it,
which is what makes a profile switch a single write followed by a `stopGeofencing()` /
`startMonitoringWithWoosmap()` cycle.

## Debugging

- The **event log** (bookmark icon, top right) lists every geofence notification with its mode and timestamp.
- Its download button zips the app's `Application Support` folder — the app's `CollectionBox`
  store and the SDK's `Woosmap.sqlite` — to `Documents/AppDump.zip` and opens a share sheet,
  so you can pull the databases off a device and inspect them.
- On the simulator the app prints its Documents directory at launch.
