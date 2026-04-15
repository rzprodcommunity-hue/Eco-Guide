# 🌲 Eco-Guide Offline Database Seeding

Quick guide to manually seed the SQLite database with data for **Jebel Chitana, Nefza, Jendouba, Tunisia**.

## 📦 What's Included

- **3 Trails**: Summit hike, forest circuit, waterfall trail
- **12 POIs**: Viewpoints, historical sites, water sources, wildlife areas
- **7 Local Services**: Guides, accommodation, restaurants, artisans

All data is in **French** and specific to the Jebel Chitana region (36.7833°N, 8.7833°E).

## 🚀 Quick Start

### For Android Device/Emulator

**Option 1: Automated Script (Recommended)**
```bash
# Windows
seed_android.bat

# Linux/Mac
chmod +x seed_android.sh
./seed_android.sh
```

**Option 2: Manual Commands**
```bash
adb pull /data/data/com.ecoguide.app/databases/ecoguide_offline.db ./
sqlite3 ecoguide_offline.db < seed_data.sql
adb push ecoguide_offline.db /data/data/com.ecoguide.app/databases/ecoguide_offline.db
adb shell run-as com.ecoguide.app chmod 660 /data/data/com.ecoguide.app/databases/ecoguide_offline.db
```

### For Windows Desktop

**Option 1: Automated Script (Recommended)**
```bash
seed_windows.bat
```

**Option 2: Manual Command**
```bash
sqlite3 "%APPDATA%\com.ecoguide\app_front\databases\ecoguide_offline.db" < seed_data.sql
```

## 📋 Prerequisites

- ✅ **SQLite3** installed ([Download](https://www.sqlite.org/download.html) or `choco install sqlite`)
- ✅ **ADB** installed for Android ([Download Platform Tools](https://developer.android.com/studio/releases/platform-tools))
- ✅ **App opened once** to create the database

## 📁 Files

- `seed_data.sql` - SQL script with all seed data
- `seed_android.bat` - Automated seeding for Android (Windows)
- `seed_android.sh` - Automated seeding for Android (Linux/Mac)
- `seed_windows.bat` - Automated seeding for Windows Desktop
- `SEED_DATABASE_INSTRUCTIONS.md` - Detailed manual instructions

## ✅ Verification

After seeding, verify in SQLite:
```sql
SELECT COUNT(*) FROM offline_trails;     -- Should return 3
SELECT COUNT(*) FROM offline_pois;       -- Should return 12
SELECT COUNT(*) FROM offline_local_services; -- Should return 7
```

Or in the app:
1. Open Eco-Guide
2. Navigate to "Offline Maps" or "Trails"
3. You should see 3 trails for Jebel Chitana region

## 🔧 Troubleshooting

| Issue | Solution |
|-------|----------|
| `adb: command not found` | Install Android Platform Tools |
| `sqlite3: command not found` | Install SQLite (`choco install sqlite`) |
| Permission denied | Run `adb shell run-as com.ecoguide.app chmod 660 ...` |
| Database not found | Open app at least once first |
| Data not showing | Force close app and reopen |

## 📍 Jebel Chitana Location

- **Coordinates**: 36.7833°N, 8.7833°E
- **Region**: Nefza, Jendouba Governorate, Tunisia
- **Features**: Kroumirie forest, cork oak trees, mountain trails
- **Difficulty**: Easy to Difficult (5km - 12km trails)

## 🗺️ Seed Data Details

### Trails
1. **Sommet du Jebel Chitana** - 8.5km, Moderate, 4h (Summit panoramic hike)
2. **Circuit de la Forêt de Kroumirie** - 5.2km, Easy, 2.5h (Family forest loop)
3. **Les Sources d'Aïn Draham** - 12.3km, Difficult, 6h (Waterfall trail)

### POIs Include
- 🏔️ Panoramic viewpoints
- 🌳 Centennial cork oak trees
- 💧 Natural water sources & waterfalls
- 🏛️ Roman ruins
- 🦅 Bird watching spots
- ⚠️ Wildlife alert zones
- 🅿️ Parking & facilities

### Services Include
- 👨‍🏫 Professional mountain guide (Mohamed Trabelsi)
- 🏠 Mountain guesthouse (Auberge de la Montagne)
- 🍽️ Traditional restaurant
- 🎨 Cork oak artisan workshop
- 🚕 4x4 taxi service
- 🏪 Mountain supplies store
- 💊 Pharmacy

## 📞 Support

For detailed instructions, see: `SEED_DATABASE_INSTRUCTIONS.md`

---

**Note**: This seed data allows the app to work **100% offline** for the Jebel Chitana region, even without backend connectivity.
