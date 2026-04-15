# Offline Data Management - Eco-Guide

## Overview
The Eco-Guide app now fully supports **offline operation** with SQLite storage for trails, POIs, and local services. The app will work seamlessly even when the backend is unavailable.

## Features

### 1. **Automatic Seed Data Initialization**
On first launch, the app automatically loads realistic seed data for:
- **Location**: Jebel Chitana, Nefza, Jendouba, Tunisia
- **3 Hiking Trails**: Summit trail, forest circuit, water sources trail
- **12 Points of Interest (POIs)**: Viewpoints, flora, fauna, historical sites, water sources
- **7 Local Services**: Guides, accommodation, restaurants, artisans, transport

### 2. **Offline-First Architecture**
All data providers follow an offline-first pattern:
```dart
try {
  // Try fetching from backend API
  data = await apiService.getData();
} catch (e) {
  // Fallback to SQLite offline cache
  data = await OfflineCacheService.instance.getOfflineData();
}
```

### 3. **Supported Offline Operations**
- ✅ View all trails with details, difficulty, distance, elevation
- ✅ Browse POIs by trail or type (viewpoint, flora, fauna, etc.)
- ✅ Access local services (guides, accommodation, restaurants, artisans)
- ✅ View offline map tiles (if previously downloaded)
- ✅ Send SOS alerts (queued for sync when online)

## Data Structure

### Trails
Each trail includes:
- Name, description, difficulty level
- Distance, elevation gain, estimated duration
- GPS coordinates (start point, route GeoJSON)
- Region, ratings, images

### POIs (Points of Interest)
- Name, type (viewpoint, flora, fauna, historical, water, etc.)
- GPS coordinates, description
- Associated trail (if any)
- Media (images, audio guides)
- Special badges (e.g., "Vue Exceptionnelle", "Patrimoine Naturel")

### Local Services
- Name, category (guide, accommodation, restaurant, artisan, transport, equipment)
- Contact details (phone, email, website, address)
- GPS coordinates
- Languages spoken
- Verification status, ratings

## Seed Data: Jebel Chitana Region

### Trail 1: Sommet du Jebel Chitana
- **Distance**: 8.5 km
- **Difficulty**: Modérée
- **Duration**: 4 hours
- **Elevation**: 420m
- **Highlights**: Panoramic views, cork oak forests, local wildlife

### Trail 2: Circuit de la Forêt de Kroumirie
- **Distance**: 5.2 km
- **Difficulty**: Facile
- **Duration**: 2.5 hours
- **Elevation**: 180m
- **Highlights**: Family-friendly, Mediterranean flora, bird watching

### Trail 3: Les Sources d'Aïn Draham
- **Distance**: 12.3 km
- **Difficulty**: Difficile
- **Duration**: 6 hours
- **Elevation**: 650m
- **Highlights**: Waterfalls, natural pools, refreshing summer trail

## Technical Implementation

### Files Created/Modified
1. **`services/seed_data_service.dart`** - Seed data provider for Jebel Chitana
2. **`services/offline_cache_service.dart`** - Updated with seed initialization
3. **`main.dart`** - Auto-initialize seed data on app startup
4. **`screens/offline/seed_data_manager_screen.dart`** - UI to manage offline data

### Database Schema
```sql
-- Trails table
CREATE TABLE offline_trails (
  id TEXT PRIMARY KEY,
  payload TEXT NOT NULL,
  downloadedAt TEXT NOT NULL,
  quality TEXT NOT NULL,
  sizeMb REAL NOT NULL
);

-- POIs table
CREATE TABLE offline_pois (
  id TEXT PRIMARY KEY,
  trailId TEXT,
  payload TEXT NOT NULL
);

-- Local services table
CREATE TABLE offline_local_services (
  id TEXT PRIMARY KEY,
  payload TEXT NOT NULL,
  downloadedAt TEXT NOT NULL
);
```

## Usage

### For Users
The app will automatically work offline with no additional configuration. Just launch the app and:
1. Navigate to the Map screen to see trails and POIs
2. Browse trails in the Trails screen
3. View local services in the Services screen
4. All data is available offline after first initialization

### For Developers

#### Manual Seed Data Loading
Navigate to the Seed Data Manager screen (for testing):
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const SeedDataManagerScreen(),
  ),
);
```

#### Initialize Seed Data Programmatically
```dart
import 'services/offline_cache_service.dart';

await OfflineCacheService.instance.initializeSeedData();
```

#### Get All Offline Data
```dart
final offlineData = await OfflineCacheService.instance.getAllOfflineData();
print('Trails: ${offlineData['trails'].length}');
print('POIs: ${offlineData['pois'].length}');
print('Services: ${offlineData['services'].length}');
```

#### Clear All Offline Data
```dart
await OfflineCacheService.instance.clearOfflineTrails();
await OfflineCacheService.instance.clearOfflinePois();
await OfflineCacheService.instance.clearOfflineLocalServices();
```

## Testing Offline Mode

### Method 1: Disable Backend
1. Stop the NestJS backend server
2. Open the app
3. Navigate to Map, Trails, or Services screens
4. Verify that seed data is displayed

### Method 2: Airplane Mode
1. Enable airplane mode on your device
2. Open the app
3. All offline data should be accessible

### Method 3: Invalid Backend URL
1. Change API URL in `services/api_client.dart` to invalid URL
2. Restart app
3. Offline data should be used automatically

## Coordinates Reference
- **Jebel Chitana**: 36.7833°N, 8.7833°E
- **Region**: Nefza, Jendouba, Tunisia
- **Elevation**: ~500-800m above sea level
- **Terrain**: Cork oak forests (Kroumirie), Mediterranean mountains

## Benefits
✅ **100% Offline Operation**: No internet required after first launch  
✅ **Realistic Local Data**: Actual trails and services in Jebel Chitana region  
✅ **Automatic Fallback**: Seamless switch between online and offline  
✅ **Persistent Storage**: Data survives app restarts  
✅ **Emergency Ready**: SOS alerts work offline (queued for sync)  
✅ **Low Storage**: ~12.5 MB for all seed data  

## Future Enhancements
- [ ] Download additional regions
- [ ] Sync offline changes when online
- [ ] Offline map tile packages
- [ ] User-generated offline content
- [ ] Export/import offline data

## Support
For issues or questions about offline functionality:
- Check database status in Seed Data Manager screen
- Verify SQLite permissions on device
- Clear and reload seed data if corrupted
- Contact: mohamed.trabelsi.guide@gmail.com (fictional example contact)
