#!/bin/bash
# ============================================================================
# Seed Android Database Script (Linux/Mac)
# This script seeds the Eco-Guide SQLite database on an Android device
# ============================================================================

echo ""
echo "========================================"
echo "Eco-Guide Database Seeding for Android"
echo "========================================"
echo ""

# Check if ADB is available
if ! command -v adb &> /dev/null; then
    echo "[ERROR] ADB not found! Please install Android SDK Platform Tools."
    echo "Download from: https://developer.android.com/studio/releases/platform-tools"
    exit 1
fi

# Check if device is connected
echo "[1/6] Checking device connection..."
if ! adb devices | grep -q "device$"; then
    echo "[ERROR] No Android device connected! Please connect a device or start an emulator."
    exit 1
fi
echo "[OK] Device connected."
echo ""

# Pull database
echo "[2/6] Pulling database from device..."
if ! adb pull /data/data/com.ecoguide.app/databases/ecoguide_offline.db ./ecoguide_offline.db; then
    echo "[ERROR] Failed to pull database. Make sure the app has been opened at least once."
    exit 1
fi
echo "[OK] Database pulled."
echo ""

# Execute SQL
echo "[3/6] Seeding database with Jebel Chitana data..."
if ! sqlite3 ecoguide_offline.db < seed_data.sql; then
    echo "[ERROR] Failed to execute SQL. Make sure sqlite3 is installed."
    echo "Install with: sudo apt-get install sqlite3 (Ubuntu/Debian)"
    echo "Or: brew install sqlite3 (macOS)"
    exit 1
fi
echo "[OK] Database seeded."
echo ""

# Verify data
echo "[4/6] Verifying seeded data..."
TRAIL_COUNT=$(sqlite3 ecoguide_offline.db "SELECT COUNT(*) FROM offline_trails;")
POI_COUNT=$(sqlite3 ecoguide_offline.db "SELECT COUNT(*) FROM offline_pois;")
SERVICE_COUNT=$(sqlite3 ecoguide_offline.db "SELECT COUNT(*) FROM offline_local_services;")

echo "[OK] Data verified:"
echo "    - Trails: $TRAIL_COUNT"
echo "    - POIs: $POI_COUNT"
echo "    - Services: $SERVICE_COUNT"
echo ""

# Push database back
echo "[5/6] Pushing database back to device..."
if ! adb push ecoguide_offline.db /data/data/com.ecoguide.app/databases/ecoguide_offline.db; then
    echo "[ERROR] Failed to push database back to device."
    exit 1
fi
echo "[OK] Database pushed."
echo ""

# Fix permissions
echo "[6/6] Fixing database permissions..."
adb shell run-as com.ecoguide.app chmod 660 /data/data/com.ecoguide.app/databases/ecoguide_offline.db
echo "[OK] Permissions fixed."
echo ""

# Cleanup
echo "Cleaning up temporary files..."
rm ecoguide_offline.db
echo "[OK] Cleanup complete."
echo ""

echo "========================================"
echo "SUCCESS! Database seeded successfully."
echo "========================================"
echo ""
echo "Please restart the Eco-Guide app to see the data."
echo "Data includes 3 trails, 12 POIs, and 7 services for Jebel Chitana, Tunisia."
echo ""
