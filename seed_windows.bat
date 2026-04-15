@echo off
REM ============================================================================
REM Seed Windows Desktop Database Script
REM This script seeds the Eco-Guide SQLite database on Windows
REM ============================================================================

echo.
echo ==========================================
echo Eco-Guide Database Seeding for Windows
echo ==========================================
echo.

REM Check if SQLite3 is available
where sqlite3 >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] sqlite3 not found! Please install SQLite.
    echo Install with: choco install sqlite
    echo Or download from: https://www.sqlite.org/download.html
    pause
    exit /b 1
)

REM Define database path
set DB_PATH=%APPDATA%\com.ecoguide\app_front\databases\ecoguide_offline.db

REM Check if database exists
if not exist "%DB_PATH%" (
    echo [ERROR] Database not found at: %DB_PATH%
    echo Please run the Eco-Guide app at least once to create the database.
    pause
    exit /b 1
)

echo [1/3] Database found: %DB_PATH%
echo.

REM Execute SQL
echo [2/3] Seeding database with Jebel Chitana data...
sqlite3 "%DB_PATH%" < seed_data.sql
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to execute SQL.
    pause
    exit /b 1
)
echo [OK] Database seeded.
echo.

REM Verify data
echo [3/3] Verifying seeded data...
sqlite3 "%DB_PATH%" "SELECT COUNT(*) FROM offline_trails;" > temp_count.txt
set /p TRAIL_COUNT=<temp_count.txt
sqlite3 "%DB_PATH%" "SELECT COUNT(*) FROM offline_pois;" > temp_count.txt
set /p POI_COUNT=<temp_count.txt
sqlite3 "%DB_PATH%" "SELECT COUNT(*) FROM offline_local_services;" > temp_count.txt
set /p SERVICE_COUNT=<temp_count.txt
del temp_count.txt

echo [OK] Data verified:
echo     - Trails: %TRAIL_COUNT%
echo     - POIs: %POI_COUNT%
echo     - Services: %SERVICE_COUNT%
echo.

echo ==========================================
echo SUCCESS! Database seeded successfully.
echo ==========================================
echo.
echo Please restart the Eco-Guide app to see the data.
echo Data includes 3 trails, 12 POIs, and 7 services for Jebel Chitana, Tunisia.
echo.
pause
