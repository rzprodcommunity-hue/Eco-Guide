# Eco-Guide Backend API Documentation

## Overview

This is a NestJS backend API for an eco-tourism/hiking application called "Eco-Guide". The API provides endpoints for managing trails, points of interest (POIs), quizzes, local services, user activities, and emergency SOS features.

## Technical Stack

- **Framework**: NestJS (Node.js)
- **Database**: PostgreSQL with PostGIS extension (for geospatial queries)
- **ORM**: TypeORM
- **Authentication**: JWT (JSON Web Tokens)
- **File Storage**: Cloudinary (for media uploads)
- **API Documentation**: Swagger (available at `/api/docs`)

## Base Configuration

- **Base URL**: `http://localhost:3000/api`
- **Swagger Docs**: `http://localhost:3000/api/docs`
- **Port**: 3000 (configurable via `PORT` env variable)

## Authentication

All protected endpoints require a JWT token in the Authorization header:
```
Authorization: Bearer <jwt_token>
```

Token expiration: 7 days

### Roles
- `user` - Default role for registered users
- `admin` - Administrative access for managing content

---

## API Endpoints

### 1. Authentication (`/api/auth`)

#### POST `/api/auth/register`
Register a new user account.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "Password123!",
  "firstName": "John",      // optional
  "lastName": "Doe"         // optional
}
```

**Response (201):**
```json
{
  "access_token": "jwt_token_here",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "firstName": "John",
    "lastName": "Doe",
    "role": "user"
  }
}
```

#### POST `/api/auth/login`
Login with email and password.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "Password123!"
}
```

**Response (200):**
```json
{
  "access_token": "jwt_token_here",
  "user": { ... }
}
```

#### GET `/api/auth/profile` 🔒
Get current authenticated user's profile.

**Response (200):**
```json
{
  "id": "uuid",
  "email": "user@example.com",
  "firstName": "John",
  "lastName": "Doe",
  "role": "user",
  "avatarUrl": "https://...",
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00.000Z"
}
```

---

### 2. Trails (`/api/trails`)

#### GET `/api/trails`
Get all trails with optional filters.

**Query Parameters:**
- `page` (number) - Page number for pagination
- `limit` (number) - Items per page
- `difficulty` (enum) - Filter by difficulty: `easy`, `moderate`, `difficult`
- `region` (string) - Filter by region name

**Response (200):**
```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Mountain Trail",
      "description": "A beautiful mountain trail...",
      "distance": 5.5,
      "difficulty": "moderate",
      "estimatedDuration": 120,
      "elevationGain": 350,
      "imageUrls": ["https://..."],
      "region": "Atlas Mountains",
      "startLatitude": 31.6295,
      "startLongitude": -7.9811,
      "geojson": { ... },
      "isActive": true,
      "createdAt": "2024-01-01T00:00:00.000Z"
    }
  ],
  "meta": {
    "total": 100,
    "page": 1,
    "limit": 10,
    "totalPages": 10
  }
}
```

#### GET `/api/trails/nearby`
Find trails near a location.

**Query Parameters:**
- `lat` (number, required) - Latitude
- `lng` (number, required) - Longitude
- `radius` (number) - Search radius in km (default: 50)

#### GET `/api/trails/:id`
Get trail details by ID.

#### POST `/api/trails` 🔒 Admin
Create a new trail.

**Request Body:**
```json
{
  "name": "Mountain Trail",
  "description": "A beautiful mountain trail with scenic views",
  "distance": 5.5,
  "difficulty": "moderate",
  "estimatedDuration": 120,
  "elevationGain": 350,
  "imageUrls": ["https://example.com/trail1.jpg"],
  "region": "Atlas Mountains",
  "startLatitude": 31.6295,
  "startLongitude": -7.9811,
  "geojson": {
    "type": "LineString",
    "coordinates": [[lng, lat], [lng, lat], ...]
  }
}
```

#### PATCH `/api/trails/:id` 🔒 Admin
Update a trail.

#### DELETE `/api/trails/:id` 🔒 Admin
Delete a trail.

---

### 3. Points of Interest (`/api/pois`)

#### GET `/api/pois`
Get all POIs with optional filters.

**Query Parameters:**
- `page`, `limit` - Pagination
- `type` (enum) - Filter by type: `viewpoint`, `flora`, `fauna`, `historical`, `water`, `camping`, `danger`, `rest_area`, `information`
- `trailId` (uuid) - Filter by associated trail

#### GET `/api/pois/nearby`
Find POIs near a location.

**Query Parameters:**
- `lat` (number, required)
- `lng` (number, required)
- `radius` (number) - In km (default: 10)
- `type` (enum) - Optional filter

#### GET `/api/pois/trail/:trailId`
Get all POIs for a specific trail.

#### GET `/api/pois/:id`
Get POI details by ID.

**Response (200):**
```json
{
  "id": "uuid",
  "name": "Scenic Viewpoint",
  "type": "viewpoint",
  "description": "A beautiful viewpoint...",
  "latitude": 31.6295,
  "longitude": -7.9811,
  "mediaUrl": "https://...",
  "additionalMediaUrls": ["https://..."],
  "audioGuideUrl": "https://...",
  "trailId": "uuid",
  "isActive": true
}
```

#### POST `/api/pois` 🔒 Admin
Create a new POI.

**Request Body:**
```json
{
  "name": "Scenic Viewpoint",
  "type": "viewpoint",
  "description": "A beautiful viewpoint overlooking the valley",
  "latitude": 31.6295,
  "longitude": -7.9811,
  "mediaUrl": "https://example.com/poi.jpg",
  "additionalMediaUrls": ["https://..."],
  "audioGuideUrl": "https://example.com/audio.mp3",
  "trailId": "uuid"
}
```

#### PATCH `/api/pois/:id` 🔒 Admin
#### DELETE `/api/pois/:id` 🔒 Admin

---

### 4. Quizzes (`/api/quizzes`)

#### GET `/api/quizzes`
Get all quizzes with pagination.

#### GET `/api/quizzes/random`
Get random quizzes.

**Query Parameters:**
- `count` (number) - Number of random quizzes (default: 5)

#### GET `/api/quizzes/trail/:trailId`
Get quizzes for a specific trail.

#### GET `/api/quizzes/poi/:poiId`
Get quizzes for a specific POI.

#### GET `/api/quizzes/:id`
Get quiz details by ID.

**Response (200):**
```json
{
  "id": "uuid",
  "question": "What type of tree is this?",
  "answers": ["Oak", "Pine", "Cedar", "Maple"],
  "correctAnswerIndex": 1,
  "explanation": "This is a Pine tree, identifiable by...",
  "category": "flora",
  "imageUrl": "https://...",
  "trailId": "uuid",
  "poiId": "uuid",
  "points": 10,
  "isActive": true
}
```

**Quiz Categories:** `flora`, `fauna`, `ecology`, `history`, `geography`, `safety`

#### POST `/api/quizzes` 🔒 Admin
#### PATCH `/api/quizzes/:id` 🔒 Admin
#### DELETE `/api/quizzes/:id` 🔒 Admin

---

### 5. Activities (`/api/activities`) 🔒

Track user activities and get statistics.

#### POST `/api/activities`
Log a new activity.

**Request Body:**
```json
{
  "type": "trail_started",
  "trailId": "uuid",
  "poiId": "uuid",
  "metadata": {
    "duration": 3600,
    "distance": 5.5,
    "quizScore": 8
  }
}
```

**Activity Types:**
- `trail_started` - User started a trail
- `trail_completed` - User completed a trail
- `poi_visited` - User visited a POI
- `quiz_answered` - User answered a quiz
- `download` - User downloaded offline content

#### GET `/api/activities/me`
Get current user's activity history with pagination.

#### GET `/api/activities/me/stats`
Get current user's statistics.

**Response (200):**
```json
{
  "totalTrailsStarted": 15,
  "totalTrailsCompleted": 12,
  "totalPoisVisited": 45,
  "totalQuizzesAnswered": 30,
  "totalDistance": 67.5,
  "totalDuration": 28800
}
```

#### GET `/api/activities/me/recent`
Get recent activities.

**Query Parameters:**
- `limit` (number) - Number of activities (default: 10)

---

### 6. Local Services (`/api/local-services`)

#### GET `/api/local-services`
Get all local services.

**Query Parameters:**
- `page`, `limit` - Pagination
- `category` (enum) - Filter by category: `guide`, `artisan`, `accommodation`, `restaurant`, `transport`, `equipment`

#### GET `/api/local-services/nearby`
Find local services near a location.

**Query Parameters:**
- `lat`, `lng` (required) - Location
- `radius` (number) - In km (default: 50)
- `category` (enum) - Optional filter

#### GET `/api/local-services/:id`
Get service details.

**Response (200):**
```json
{
  "id": "uuid",
  "name": "Mountain Guide Ahmed",
  "category": "guide",
  "description": "Experienced mountain guide...",
  "contact": "+212 600 123456",
  "email": "ahmed@guide.ma",
  "website": "https://...",
  "address": "123 Main St, City",
  "latitude": 31.6295,
  "longitude": -7.9811,
  "imageUrl": "https://...",
  "additionalImages": ["https://..."],
  "languages": ["Arabic", "French", "English"],
  "rating": 4.8,
  "reviewCount": 25,
  "isVerified": true
}
```

#### POST `/api/local-services` 🔒 Admin
#### PATCH `/api/local-services/:id` 🔒 Admin
#### DELETE `/api/local-services/:id` 🔒 Admin

---

### 7. SOS Emergency (`/api/sos`)

#### POST `/api/sos/alert` 🔒
Send an emergency SOS alert.

**Request Body:**
```json
{
  "latitude": 31.6295,
  "longitude": -7.9811,
  "message": "I am injured and need help",
  "emergencyContact": "+212 600 123456"
}
```

#### GET `/api/sos/alerts` 🔒 Admin
Get all SOS alerts.

#### GET `/api/sos/alerts/active` 🔒 Admin
Get active (unresolved) SOS alerts.

#### PATCH `/api/sos/alerts/:id/resolve` 🔒 Admin
Mark an alert as resolved.

---

### 8. Media Upload (`/api/media`) 🔒

#### POST `/api/media/upload/image`
Upload an image file.

**Request:** `multipart/form-data` with `file` field

**Response (201):**
```json
{
  "url": "https://res.cloudinary.com/...",
  "publicId": "folder/filename"
}
```

#### POST `/api/media/upload/video`
Upload a video file.

#### POST `/api/media/upload/audio`
Upload an audio file.

#### DELETE `/api/media/:publicId`
Delete a media file by public ID.

---

### 9. Offline Support (`/api/offline`) 🔒

#### GET `/api/offline/packages`
Get available offline packages for download.

#### GET `/api/offline/downloads`
Get current user's downloaded resources.

#### GET `/api/offline/sync`
Get sync status for offline data.

#### POST `/api/offline/download`
Mark a resource as downloaded.

**Request Body:**
```json
{
  "resourceType": "trail",
  "resourceId": "uuid"
}
```

#### DELETE `/api/offline/download/:id`
Remove a downloaded resource.

#### DELETE `/api/offline/downloads`
Clear all downloaded resources.

---

### 10. Notifications (`/api/notifications`) 🔒 Admin

#### POST `/api/notifications/send`
Send a push notification.

**Request Body:**
```json
{
  "title": "New Trail Available!",
  "body": "Check out our new mountain trail",
  "data": { "trailId": "uuid" }
}
```

#### GET `/api/notifications/history`
Get notification history.

**Query Parameters:**
- `limit` (number) - Default: 50

---

## Data Models

### User
```typescript
{
  id: string;           // UUID
  email: string;        // Unique
  role: 'admin' | 'user';
  firstName?: string;
  lastName?: string;
  avatarUrl?: string;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}
```

### Trail
```typescript
{
  id: string;
  name: string;
  description: string;
  distance: number;                    // kilometers
  difficulty: 'easy' | 'moderate' | 'difficult';
  geojson?: object;                    // GeoJSON LineString
  estimatedDuration?: number;          // minutes
  elevationGain?: number;              // meters
  imageUrls?: string[];
  region?: string;
  startLatitude?: number;
  startLongitude?: number;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}
```

### POI (Point of Interest)
```typescript
{
  id: string;
  name: string;
  type: 'viewpoint' | 'flora' | 'fauna' | 'historical' | 'water' | 'camping' | 'danger' | 'rest_area' | 'information';
  description: string;
  latitude: number;
  longitude: number;
  mediaUrl?: string;
  additionalMediaUrls?: string[];
  audioGuideUrl?: string;
  trailId?: string;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}
```

### Quiz
```typescript
{
  id: string;
  question: string;
  answers: string[];           // Array of answer options
  correctAnswerIndex: number;  // Index of correct answer in answers array
  explanation?: string;
  category?: 'flora' | 'fauna' | 'ecology' | 'history' | 'geography' | 'safety';
  imageUrl?: string;
  trailId?: string;
  poiId?: string;
  points: number;              // Default: 10
  isActive: boolean;
  createdAt: Date;
}
```

### Activity
```typescript
{
  id: string;
  userId: string;
  type: 'trail_started' | 'trail_completed' | 'poi_visited' | 'quiz_answered' | 'download';
  trailId?: string;
  poiId?: string;
  metadata?: {
    duration?: number;     // seconds
    distance?: number;     // km
    quizScore?: number;
    // ... other custom data
  };
  createdAt: Date;
}
```

### LocalService
```typescript
{
  id: string;
  name: string;
  category: 'guide' | 'artisan' | 'accommodation' | 'restaurant' | 'transport' | 'equipment';
  description: string;
  contact?: string;
  email?: string;
  website?: string;
  address?: string;
  latitude?: number;
  longitude?: number;
  imageUrl?: string;
  additionalImages?: string[];
  languages?: string[];
  rating?: number;            // 0-5
  reviewCount: number;
  isVerified: boolean;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}
```

---

## Error Responses

All errors follow this format:
```json
{
  "statusCode": 400,
  "message": "Error description",
  "error": "Bad Request"
}
```

### Common HTTP Status Codes:
- `200` - Success
- `201` - Created
- `400` - Bad Request (validation error)
- `401` - Unauthorized (missing/invalid token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found
- `409` - Conflict (e.g., email already exists)
- `500` - Internal Server Error

---

## Pagination

Paginated endpoints accept:
- `page` (number) - Page number (default: 1)
- `limit` (number) - Items per page (default: 10)

Response format:
```json
{
  "data": [...],
  "meta": {
    "total": 100,
    "page": 1,
    "limit": 10,
    "totalPages": 10
  }
}
```

---

## Frontend Integration Notes

### Authentication Flow
1. Register/Login to get JWT token
2. Store token securely (localStorage/AsyncStorage)
3. Include token in all protected requests via `Authorization: Bearer <token>` header
4. Handle 401 responses by redirecting to login

### Geolocation Features
- Use GPS coordinates for `/nearby` endpoints
- Store trail GeoJSON for offline map display
- Track user position during trail navigation

### Offline Support
1. Fetch trail/POI data and cache locally
2. Use `/api/offline/download` to track downloads
3. Sync activities when back online
4. Check `/api/offline/sync` for pending syncs

### Media Handling
- Upload images/audio before creating POIs (get URL from upload response)
- Use Cloudinary URLs directly for display
- Support offline caching of media files

### Quiz Implementation
- Show answers array as options
- Use `correctAnswerIndex` to validate user selection
- Display `explanation` after answering
- Log quiz results via activities endpoint

### SOS Feature
- Implement prominent SOS button
- Get GPS coordinates before sending alert
- Allow optional emergency message
- Confirm alert was sent successfully

---

## Environment Variables Required

```env
# Application
NODE_ENV=development
PORT=3000

# Database
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USER=postgres
DATABASE_PASSWORD=your_password
DATABASE_NAME=ecoguide

# JWT
JWT_SECRET=your_secret_key
JWT_EXPIRES_IN=7d

# Cloudinary (for media storage)
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=

# CORS
CORS_ORIGINS=http://localhost:3000,http://localhost:8080
```
