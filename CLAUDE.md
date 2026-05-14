# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Eco-Guide is a full-stack hiking/trekking application with three sub-projects:

- `app_backend/` — NestJS REST API (TypeScript, PostgreSQL + PostGIS)
- `app_front/` — Flutter mobile app (iOS/Android)
- `app_backoffice/` — Flutter web admin dashboard

## Backend (`app_backend/`)

### Commands

```bash
npm run start:dev       # Development with hot-reload
npm run build           # Compile TypeScript to dist/
npm run start:prod      # Run compiled production build
npm run test            # Unit tests (Jest)
npm run test:e2e        # End-to-end tests
npm run seed            # Seed the database
```

Swagger API docs available at `http://localhost:<PORT>/api/docs` when running.

### Environment Setup

Copy `.env.example` to `.env` and fill in:
- `DATABASE_*` — PostgreSQL connection details (requires PostGIS extension)
- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`
- `JWT_SECRET`
- `CLOUDINARY_*` — Media upload credentials

### Architecture

Entry point: `src/main.ts` — enables global validation pipe, CORS, and mounts Swagger at `/api/docs`. All routes are prefixed with `/api`.

`src/app.module.ts` imports 14 domain modules:

| Module | Responsibility |
|---|---|
| `auth` | JWT/Passport strategies, login/register guards |
| `users` | User CRUD and profile management |
| `trails` | Hiking trails with GeoJSON geometries |
| `pois` | Points of Interest with PostGIS geolocation |
| `quizzes` | Educational quiz content with scoring |
| `local-economy` | Guides, artisans, accommodations |
| `media` | Cloudinary image/video upload |
| `sos` | Emergency alerts with geolocation |
| `activities` | User activity history/logging |
| `offline` | Offline data cache endpoints |
| `notifications` | Push notification delivery |
| `weather` | External weather data integration |
| `admin` | Admin-only management endpoints |
| `events` | Socket.io real-time WebSocket gateway |

Each module follows the NestJS pattern: `*.module.ts` → `*.controller.ts` → `*.service.ts` → `*.entity.ts` + `dto/`.

Config files live in `src/config/` (database, JWT, Cloudinary). TypeORM is used as the ORM; entities use PostGIS column types for geospatial queries.

## Mobile App (`app_front/`)

### Commands

```bash
flutter pub get         # Install dependencies
flutter run             # Run on connected device/emulator
flutter build apk       # Build Android APK
flutter build ios       # Build iOS (macOS only)
flutter test            # Run widget/unit tests
```

### Environment Setup

Copy `.env.example` to `.env`. Set `API_HOST` in `lib/core/constants/` or similar to point to the backend:
- Android emulator: `http://10.0.2.2:<PORT>`
- iOS simulator: `http://localhost:<PORT>`
- Physical device: use machine's local IP

### Architecture

Entry point: `lib/main.dart` — bootstraps Supabase, sets up 10+ `Provider` instances, then launches the app.

State management uses the **Provider** package. Key providers mirror backend modules (AuthProvider, TrailProvider, POIProvider, QuizProvider, etc.).

```
lib/
  core/           # Theme, constants, API client, services
  models/         # Data models (mirroring backend entities)
  providers/      # Provider state classes
  screens/        # UI screens grouped by feature
  services/       # ApiService, SocketService, SOS, offline map cache
```

- **Maps**: `flutter_map` with OpenStreetMap tiles + `latlong2`
- **Offline**: SQLite via `sqflite` + `connectivity_plus` for network detection; offline SOS queue
- **Auth**: Supabase for session management + JWT for API calls
- **Real-time**: `SocketService` connects to backend Socket.io for live updates
- **Localization**: French/Arabic support

## Admin Panel (`app_backoffice/`)

### Commands

```bash
flutter pub get
flutter run -d chrome   # Run as web app
flutter build web       # Build for web deployment
flutter test
```

### Architecture

Entry point: `lib/main.dart` — Provider-based setup mirroring `app_front`, with Go Router for navigation.

```
lib/
  core/           # Providers, constants, services
  router/         # Go Router configuration and route definitions
  screens/        # Admin UI screens (dashboard, content management)
```

Uses `fl_chart` for analytics charts, `data_table_2` for data tables, `file_picker` for uploads, and `audioplayers` for media preview.

## Data Flow

```
Flutter App / Admin Panel
        ↕ REST (HTTP)
  NestJS API (/api/*)
        ↕
  PostgreSQL + PostGIS
        ↕ WebSocket (Socket.io)
  Flutter (real-time updates)
```

Media uploads go directly to Cloudinary; the backend stores the resulting URLs. Authentication tokens are JWTs issued by the backend after Supabase verifies credentials.
