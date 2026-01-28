# Ride Tracker

A native iOS app for tracking Disneyland Resort ride wait times and personal visit history.

## Features

### Live Wait Times
- Real-time wait times from the ThemeParks.wiki API
- Support for Disneyland Park and Disney California Adventure
- Filter by Attractions, Shows, or Restaurants
- Sort by wait time, name, or distance from your location
- Favorite your most-visited attractions
- Add personal notes to any attraction

### Queue Timer
- Swipe left on any ride to start tracking your wait
- Choose between Standby or Lightning Lane queue types
- Live timer shows how long you've been waiting
- Automatically logs your actual wait time when done
- Compares posted wait time vs. actual wait time

### Ride History
- Complete log of all rides with timestamps
- Grouped by day with collapsible sections
- Statistics: total rides, unique rides, total wait time, average wait
- Swipe to delete individual entries
- Lightning Lane rides marked with LL badge

### Sharing
- Export history as JSON text
- Generate QR codes for easy sharing between devices
- Scan QR codes to import history/notes
- Generate trip reports with customizable date selection
- Share trip reports via iOS share sheet

### Location Services
- See your distance from each attraction
- Sort attractions by proximity
- Uses device GPS (optional)

### Push Notifications
- Receive real-time push notifications for ride status updates
- Get notified when your favorite rides are down or reopen
- Powered by the [ride-watch](https://github.com/chsnow/ride-watch) backend service

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.0+

## Project Structure

```
RideTracker/
├── RideTrackerApp.swift        # App entry point
├── Info.plist                  # App configuration
├── Assets.xcassets/            # App icons and colors
├── Models/
│   ├── Park.swift              # Park/Destination models
│   ├── Entity.swift            # Attraction/Show/Restaurant models
│   ├── LiveData.swift          # Real-time wait time data
│   ├── RideHistory.swift       # Logged ride history
│   └── ActiveQueue.swift       # Active queue timer
├── Services/
│   ├── ThemeParksAPI.swift     # API client for themeparks.wiki
│   ├── StorageService.swift    # Local data persistence
│   └── LocationService.swift   # GPS and distance calculations
├── ViewModels/
│   └── AppState.swift          # Main app state management
└── Views/
    ├── ContentView.swift       # Tab bar container
    ├── RidesView.swift         # Main rides list
    ├── RideCardView.swift      # Individual ride card with swipe
    ├── HistoryView.swift       # Ride history and stats
    └── QRCodeView.swift        # QR generation and scanning
```

## API

This app uses the [ThemeParks.wiki API](https://api.themeparks.wiki/docs) for live wait time data.

## Privacy

- Location data is used only for distance calculations and never leaves your device
- Ride history is stored locally using UserDefaults
- No account or sign-in required

## Building

1. Open `RideTracker.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run on a simulator or device

## License

MIT License
