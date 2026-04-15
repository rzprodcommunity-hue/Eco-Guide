# Manual SQLite Database Seeding Instructions

This guide explains how to manually seed the Eco-Guide offline database with data for Jebel Chitana, Nefza, Jendouba, Tunisia.

## Prerequisites

- SQLite3 command-line tool installed
- Flutter app installed on device/emulator
- ADB (Android Debug Bridge) for Android devices

## Database Location

The database file is located at:
- **Android**: `/data/data/com.ecoguide.app/databases/ecoguide_offline.db`
- **iOS**: `Library/Application Support/ecoguide_offline.db`
- **Windows Desktop**: `%APPDATA%\com.ecoguide\app_front\databases\ecoguide_offline.db`

---

## Method 1: Using ADB (Android - Recommended)

### Step 1: Connect your Android device or emulator
```bash
# Check if device is connected
adb devices
```

### Step 2: Launch the app at least once
This creates the database file. Open the Eco-Guide app and navigate to any screen.

### Step 3: Pull the database to your computer
```bash
# Pull database from device
adb pull /data/data/com.ecoguide.app/databases/ecoguide_offline.db ./ecoguide_offline.db
```

### Step 4: Execute the SQL seed file
```bash
# Open SQLite and execute the seed file
sqlite3 ecoguide_offline.db < seed_data.sql
```

Or interactively:
```bash
# Open database
sqlite3 ecoguide_offline.db

# Execute the seed file
.read seed_data.sql

# Verify data
SELECT COUNT(*) FROM offline_trails;
SELECT COUNT(*) FROM offline_pois;
SELECT COUNT(*) FROM offline_local_services;

# Exit
.quit
```

### Step 5: Push the database back to device
```bash
# Push modified database back
adb push ./ecoguide_offline.db /data/data/com.ecoguide.app/databases/ecoguide_offline.db

# Fix permissions (important!)
adb shell run-as com.ecoguide.app chmod 660 /data/data/com.ecoguide.app/databases/ecoguide_offline.db
```

### Step 6: Restart the app
Force close and reopen the Eco-Guide app to see the seeded data.

---

## Method 2: Using ADB Shell (Android - Direct Method)

### Step 1: Copy SQL file to device
```bash
adb push seed_data.sql /sdcard/seed_data.sql
```

### Step 2: Execute SQL directly on device
```bash
# Open ADB shell
adb shell

# Navigate to app directory
cd /data/data/com.ecoguide.app/databases/

# Execute SQL file
sqlite3 ecoguide_offline.db < /sdcard/seed_data.sql

# Exit shell
exit
```

---

## Method 3: Windows Desktop (Flutter Desktop)

### Step 1: Locate the database
Run the app at least once, then find the database at:
```
%APPDATA%\com.ecoguide\app_front\databases\ecoguide_offline.db
```

Full path example:
```
C:\Users\mouha\AppData\Roaming\com.ecoguide\app_front\databases\ecoguide_offline.db
```

### Step 2: Execute SQL
```cmd
# Navigate to app_front folder
cd "C:\Users\mouha\Downloads\Eco-Guide-feature-offline-maps-realtime\Eco-Guide-feature-offline-maps-realtime\app_front"

# Execute SQL (replace path with actual AppData path)
sqlite3 "%APPDATA%\com.ecoguide\app_front\databases\ecoguide_offline.db" < seed_data.sql
```

Or use PowerShell:
```powershell
# Navigate to app_front folder
cd "C:\Users\mouha\Downloads\Eco-Guide-feature-offline-maps-realtime\Eco-Guide-feature-offline-maps-realtime\app_front"

# Execute SQL
Get-Content .\seed_data.sql | sqlite3 "$env:APPDATA\com.ecoguide\app_front\databases\ecoguide_offline.db"
```

---

## Method 4: Install SQLite Tools if not available

### Windows
Download from: https://www.sqlite.org/download.html
- Download "sqlite-tools-win32-x86-*.zip"
- Extract and add to PATH

Or use Chocolatey:
```powershell
choco install sqlite
```

### Linux/Mac
```bash
# Ubuntu/Debian
sudo apt-get install sqlite3

# macOS
brew install sqlite3
```

---

## Verification

After seeding, verify the data was inserted correctly:

```bash
sqlite3 ecoguide_offline.db
```

Then run these queries:
```sql
-- Count records
SELECT COUNT(*) as trail_count FROM offline_trails;
SELECT COUNT(*) as poi_count FROM offline_pois;
SELECT COUNT(*) as service_count FROM offline_local_services;

-- View trail names
SELECT name, difficulty, distance FROM offline_trails;

-- View POI types
SELECT name, type FROM offline_pois LIMIT 10;

-- View services
SELECT name, category FROM offline_local_services;
```

Expected results:
- **3 trails** (Sommet du Jebel Chitana, Circuit de la Forêt, Les Sources d'Aïn Draham)
- **12 POIs** (viewpoints, historical sites, water sources, etc.)
- **7 local services** (guides, accommodation, restaurants, etc.)

---

## Troubleshooting

### Issue: Permission Denied (Android)
```bash
# Fix permissions
adb shell run-as com.ecoguide.app chmod 660 /data/data/com.ecoguide.app/databases/ecoguide_offline.db
```

### Issue: Database file not found
- Make sure you've opened the app at least once to create the database
- Check the app's package name is correct: `com.ecoguide.app`

### Issue: Data not showing in app
1. Force close the app completely
2. Clear app cache (Settings > Apps > Eco-Guide > Storage > Clear Cache)
3. Reopen the app

### Issue: SQLite command not found
Install SQLite tools (see Method 4 above)

---

## Quick Commands Reference

```bash
# Android - Full workflow
adb pull /data/data/com.ecoguide.app/databases/ecoguide_offline.db ./
sqlite3 ecoguide_offline.db < seed_data.sql
adb push ./ecoguide_offline.db /data/data/com.ecoguide.app/databases/ecoguide_offline.db
adb shell run-as com.ecoguide.app chmod 660 /data/data/com.ecoguide.app/databases/ecoguide_offline.db

# Windows Desktop - Quick seed
cd app_front
sqlite3 "%APPDATA%\com.ecoguide\app_front\databases\ecoguide_offline.db" < seed_data.sql

# Verify data
sqlite3 ecoguide_offline.db "SELECT COUNT(*) FROM offline_trails; SELECT COUNT(*) FROM offline_pois; SELECT COUNT(*) FROM offline_local_services;"
```

---

## Notes

- The seed data includes **realistic locations** around Jebel Chitana (36.7833°N, 8.7833°E)
- All data is in **French** to match the Tunisia/Nefza region
- The data works **offline** - no internet connection required after seeding
- Database size: ~15KB (very lightweight)

## Need Help?

If you encounter issues, check:
1. App package name in AndroidManifest.xml
2. Database file permissions
3. SQLite installation
4. Device/emulator connection (adb devices)
