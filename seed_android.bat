@echo off
REM ============================================================================
REM Seed Android Database Script
REM This script seeds the Eco-Guide SQLite database on an Android device
REM ============================================================================

echo.
echo ========================================
echo Eco-Guide Database Seeding for Android
echo ========================================
echo.

REM Check if ADB is available
where adb >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] ADB not found! Please install Android SDK Platform Tools.
    echo Download from: https://developer.android.com/studio/releases/platform-tools
    pause
    exit /b 1
)

REM Check if device is connected
echo [1/6] Checking device connection...
adb devices | findstr "device$" >nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] No Android device connected! Please connect a device or start an emulator.
    pause
    exit /b 1
)
echo [OK] Device connected.
echo.

REM Pull database
echo [2/6] Pulling database from device...
adb pull /data/data/com.ecoguide.app/databases/ecoguide_offline.db .\ecoguide_offline.db
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to pull database. Make sure the app has been opened at least once.
    pause
    exit /b 1
)
echo [OK] Database pulled.
echo.

REM Execute SQL
echo [3/6] Seeding database with Jebel Chitana data...
sqlite3 ecoguide_offline.db < seed_data.sql
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to execute SQL. Make sure sqlite3 is installed.
    echo Install with: choco install sqlite
    pause
    exit /b 1
)
echo [OK] Database seeded.
echo.

REM Verify data
echo [4/6] Verifying seeded data...
sqlite3 ecoguide_offline.db "SELECT COUNT(*) FROM offline_trails;" > temp_count.txt
set /p TRAIL_COUNT=<temp_count.txt
sqlite3 ecoguide_offline.db "SELECT COUNT(*) FROM offline_pois;" > temp_count.txt
set /p POI_COUNT=<temp_count.txt
sqlite3 ecoguide_offline.db "SELECT COUNT(*) FROM offline_local_services;" > temp_count.txt
set /p SERVICE_COUNT=<temp_count.txt
del temp_count.txt

echo [OK] Data verified:
echo     - Trails: %TRAIL_COUNT%
echo     - POIs: %POI_COUNT%
echo     - Services: %SERVICE_COUNT%
echo.

REM Push database back
echo [5/6] Pushing database back to device...
adb push ecoguide_offline.db /data/data/com.ecoguide.app/databases/ecoguide_offline.db
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to push database back to device.
    pause
    exit /b 1
)
echo [OK] Database pushed.
echo.

REM Fix permissions
echo [6/6] Fixing database permissions...
adb shell run-as com.ecoguide.app chmod 660 /data/data/com.ecoguide.app/databases/ecoguide_offline.db
echo [OK] Permissions fixed.
echo.

REM Cleanup
echo Cleaning up temporary files...
del ecoguide_offline.db
echo [OK] Cleanup complete.
echo.

echo ========================================
echo SUCCESS! Database seeded successfully.
echo ========================================
echo.
echo Please restart the Eco-Guide app to see the data.
echo Data includes 3 trails, 12 POIs, and 7 services for Jebel Chitana, Tunisia.
echo.
pause
