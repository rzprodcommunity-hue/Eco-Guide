# 🗺️ Eco-Guide — Étapes Détaillées de Réalisation

> Guide complet pour construire le projet Eco-Guide étape par étape.

---

## Phase 1 : Mise en Place de l'Environnement

### 1.1 — Installer les prérequis

- [ ] Installer **Node.js** (v18+ recommandé) et **npm**
- [ ] Installer **Flutter SDK** (version stable)
- [ ] Installer **PostgreSQL** (v14+) avec l'extension **PostGIS**
- [ ] Installer **Git** pour le versioning
- [ ] Créer un compte **Cloudinary** (stockage médias)
- [ ] Installer un IDE (VS Code recommandé + extensions Flutter, NestJS, PostgreSQL)

### 1.2 — Initialiser la structure du projet

```
app_rz/
├── app_backend/      ← NestJS REST API
├── app_front/        ← Flutter mobile (Android/iOS)
├── app_backoffice/   ← Flutter Web (admin)
└── project_details.md
```

- [ ] Vérifier que les 3 dossiers (`app_backend`, `app_front`, `app_backoffice`) existent
- [ ] Initialiser un dépôt Git si ce n'est pas déjà fait

---

## Phase 2 : Backend — `app_backend` (NestJS)

### 2.1 — Initialiser le projet NestJS

- [ ] Créer le projet NestJS : `npx -y @nestjs/cli new app_backend`
- [ ] Installer les dépendances principales :
  ```bash
  npm install @nestjs/typeorm typeorm pg @nestjs/jwt @nestjs/passport passport passport-jwt
  npm install @nestjs/swagger swagger-ui-express
  npm install cloudinary multer @nestjs/platform-express
  npm install class-validator class-transformer
  npm install bcrypt
  npm install -D @types/multer @types/bcrypt @types/passport-jwt
  ```

### 2.2 — Configurer la base de données PostgreSQL + PostGIS

- [ ] Créer la base de données `ecoguide` dans PostgreSQL
- [ ] Activer l'extension PostGIS : `CREATE EXTENSION postgis;`
- [ ] Créer le fichier `.env` avec les variables d'environnement :
  ```env
  NODE_ENV=development
  PORT=3000
  DATABASE_HOST=localhost
  DATABASE_PORT=5432
  DATABASE_USER=postgres
  DATABASE_PASSWORD=your_password
  DATABASE_NAME=ecoguide
  JWT_SECRET=your_secret_key
  JWT_EXPIRES_IN=7d
  CLOUDINARY_CLOUD_NAME=xxx
  CLOUDINARY_API_KEY=xxx
  CLOUDINARY_API_SECRET=xxx
  CORS_ORIGINS=http://localhost:3000,http://localhost:8080
  ```
- [ ] Configurer TypeORM dans `app.module.ts` avec la connexion PostgreSQL

### 2.3 — Créer les entités (Modèles de données)

Créer chaque entité TypeORM dans `src/entities/` :

- [ ] **User** — `id`, `email`, `password`, `role` (admin/user), `firstName`, `lastName`, `avatarUrl`, `isActive`, `createdAt`, `updatedAt`
- [ ] **Trail** — `id`, `name`, `description`, `distance`, `difficulty` (easy/moderate/difficult), `geojson`, `estimatedDuration`, `elevationGain`, `imageUrls`, `region`, `startLatitude`, `startLongitude`, `isActive`
- [ ] **POI** — `id`, `name`, `type` (viewpoint/flora/fauna/historical/water/camping/danger/rest_area/information), `description`, `latitude`, `longitude`, `mediaUrl`, `additionalMediaUrls`, `audioGuideUrl`, `trailId`, `isActive`
- [ ] **Quiz** — `id`, `question`, `answers[]`, `correctAnswerIndex`, `explanation`, `category` (flora/fauna/ecology/history/geography/safety), `imageUrl`, `trailId`, `poiId`, `points`, `isActive`
- [ ] **Activity** — `id`, `userId`, `type` (trail_started/trail_completed/poi_visited/quiz_answered/download), `trailId`, `poiId`, `metadata` (JSON), `createdAt`
- [ ] **LocalService** — `id`, `name`, `category` (guide/artisan/accommodation/restaurant/transport/equipment), `description`, `contact`, `email`, `website`, `address`, `latitude`, `longitude`, `imageUrl`, `additionalImages`, `languages`, `rating`, `reviewCount`, `isVerified`, `isActive`
- [ ] **SosAlert** — `id`, `userId`, `latitude`, `longitude`, `message`, `emergencyContact`, `status` (active/resolved), `createdAt`
- [ ] **OfflineDownload** — `id`, `userId`, `resourceType`, `resourceId`, `createdAt`

### 2.4 — Créer les modules NestJS

Pour chaque module, créer : `module`, `controller`, `service`, `dto` (Create/Update).

- [ ] **Auth Module** — Register, Login, JWT strategy, Guard, Profile
  - `POST /api/auth/register`
  - `POST /api/auth/login`
  - `GET /api/auth/profile` 🔒
- [ ] **User Module** — Gestion des utilisateurs
- [ ] **Trail Module** — CRUD sentiers + recherche à proximité
  - `GET /api/trails` (pagination, filtres)
  - `GET /api/trails/nearby` (géolocalisation)
  - `GET /api/trails/:id`
  - `POST /api/trails` 🔒 Admin
  - `PATCH /api/trails/:id` 🔒 Admin
  - `DELETE /api/trails/:id` 🔒 Admin
- [ ] **POI Module** — CRUD points d'intérêt + recherche à proximité
  - `GET /api/pois` (filtres par type, trailId)
  - `GET /api/pois/nearby`
  - `GET /api/pois/trail/:trailId`
  - `POST /api/pois` 🔒 Admin
  - `PATCH /api/pois/:id` 🔒 Admin
  - `DELETE /api/pois/:id` 🔒 Admin
- [ ] **Quiz Module** — CRUD quiz + quiz aléatoires + par sentier/POI
  - `GET /api/quizzes` / `GET /api/quizzes/random`
  - `GET /api/quizzes/trail/:trailId` / `GET /api/quizzes/poi/:poiId`
  - `POST /api/quizzes` 🔒 Admin
- [ ] **Activity Module** — Historique + statistiques utilisateur
  - `POST /api/activities` 🔒
  - `GET /api/activities/me` / `GET /api/activities/me/stats` / `GET /api/activities/me/recent` 🔒
- [ ] **Local Service Module** — CRUD services locaux + recherche à proximité
  - `GET /api/local-services` (filtres par catégorie)
  - `GET /api/local-services/nearby`
  - `POST /api/local-services` 🔒 Admin
- [ ] **SOS Module** — Alertes d'urgence
  - `POST /api/sos/alert` 🔒
  - `GET /api/sos/alerts` 🔒 Admin
  - `PATCH /api/sos/alerts/:id/resolve` 🔒 Admin
- [ ] **Media Module** — Upload images/vidéos/audio via Cloudinary
  - `POST /api/media/upload/image` 🔒
  - `POST /api/media/upload/video` 🔒
  - `POST /api/media/upload/audio` 🔒
  - `DELETE /api/media/:publicId` 🔒
- [ ] **Offline Module** — Gestion de paquets hors ligne
  - `GET /api/offline/packages` / `GET /api/offline/downloads`
  - `POST /api/offline/download` 🔒
- [ ] **Notification Module** — Push notifications
  - `POST /api/notifications/send` 🔒 Admin
  - `GET /api/notifications/history` 🔒 Admin

### 2.5 — Sécurité & Middleware

- [ ] Implémenter le **JWT Auth Guard** (protection des routes)
- [ ] Implémenter le **Roles Guard** (admin vs user)
- [ ] Ajouter la validation des DTOs avec `class-validator`
- [ ] Configurer **CORS** pour les origines autorisées
- [ ] Configurer **Swagger** à `/api/docs`

### 2.6 — Tester le backend

- [ ] Tester chaque endpoint avec **Postman** ou **Swagger UI**
- [ ] Vérifier les réponses paginées (`data` + `meta`)
- [ ] Vérifier les requêtes géospatiales (`/nearby`)
- [ ] Vérifier l'upload média Cloudinary

---

## Phase 3 : Application Mobile — `app_front` (Flutter)

### 3.1 — Initialiser le projet Flutter

- [ ] Créer le projet : `flutter create app_front`
- [ ] Installer les dépendances principales :
  ```yaml
  dependencies:
    http: ^1.1.0              # Requêtes HTTP
    flutter_map: ^6.0.0       # Carte OpenStreetMap
    latlong2: ^0.9.0          # Coordonnées GPS
    geolocator: ^10.0.0       # GPS temps réel
    sqflite: ^2.3.0           # SQLite (mode offline)
    shared_preferences: ^2.2.0 # Stockage sessions
    provider: ^6.1.0          # State management
    flutter_secure_storage: ^9.0.0 # Stockage JWT
    cached_network_image: ^3.3.0   # Cache images
  ```

### 3.2 — Mettre en place l'architecture

- [ ] Organiser le code en **clean architecture** :
  ```
  lib/
  ├── core/          ← constantes, thèmes, utils
  ├── data/          ← API services, modèles, datasources
  ├── domain/        ← entités, repositories abstraits
  ├── presentation/  ← pages, widgets, state management
  └── main.dart
  ```
- [ ] Créer un **service API** centralisé (base URL, headers JWT, interceptors)

### 3.3 — Implémenter les écrans

#### Authentification
- [ ] Écran **Login** (email + mot de passe → `POST /api/auth/login`)
- [ ] Écran **Register** (email + mot de passe → `POST /api/auth/register`)
- [ ] Gestion session JWT (stockage sécurisé + refresh)

#### Accueil
- [ ] Écran **Accueil** avec carte interactive (Mapbox / OpenStreetMap)
- [ ] Bouton d'accès rapide aux sentiers
- [ ] Bouton **SOS** visible et accessible

#### Carte Interactive
- [ ] Affichage des **tracés GeoJSON** des sentiers sur la carte
- [ ] Affichage des **marqueurs POI** sur la carte
- [ ] **Position utilisateur** en temps réel (GPS)

#### Sentiers
- [ ] Écran **Liste des sentiers** (`GET /api/trails`)
  - Filtres par difficulté (facile, modéré, difficile)
  - Affichage distance + durée estimée
- [ ] Écran **Détail sentier** (`GET /api/trails/:id`)
  - Description, carte preview, bouton démarrer

#### Navigation GPS
- [ ] Écran **Navigation** avec suivi GPS temps réel
- [ ] **Alertes hors sentier** (calcul de distance par rapport au tracé)
- [ ] Statistiques en direct : distance parcourue, vitesse

#### Points d'intérêt (POI)
- [ ] Écran **Détail POI** (`GET /api/pois/:id`)
  - Contenu multimédia (images, vidéos, audio)
- [ ] **Notifications de proximité** (quand l'utilisateur est près d'un POI)

#### SOS
- [ ] Écran **SOS** avec envoi coordonnées GPS (`POST /api/sos/alert`)
- [ ] Bouton d'appel secours direct

#### Profil
- [ ] Écran **Profil** avec historique d'activités (`GET /api/activities/me`)
- [ ] Statistiques utilisateur (`GET /api/activities/me/stats`)

#### Annuaire Local
- [ ] Écran **Annuaire** (`GET /api/local-services`)
  - Guides, artisans, hébergements, restaurants
  - Filtres par catégorie

#### Quiz
- [ ] Écran **Quiz** (`GET /api/quizzes/random`)
  - Affichage questions + réponses multiples
  - Validation avec `correctAnswerIndex`
  - Affichage score utilisateur

#### Mode Offline
- [ ] Téléchargement cartes + sentiers en **SQLite** local
- [ ] Gestion du cache avec `sqflite`
- [ ] Synchronisation quand connexion retrouvée

#### Paramètres
- [ ] Écran **Paramètres**
  - Changement de langue (FR / AR)
  - Activation/désactivation notifications
  - Gestion GPS

---

## Phase 4 : Back-Office — `app_backoffice` (Flutter Web)

### 4.1 — Initialiser le projet Flutter Web

- [ ] Créer le projet : `flutter create app_backoffice`
- [ ] Activer le support web : `flutter config --enable-web`
- [ ] Installer les mêmes dépendances HTTP + un package de dashboard

### 4.2 — Implémenter les pages admin

- [ ] **Dashboard** principal avec statistiques globales
- [ ] **Gestion des sentiers** — CRUD complet + import GeoJSON + aperçu carte
- [ ] **Gestion des POI** — CRUD + upload images/vidéos via Cloudinary
- [ ] **Gestion des utilisateurs** — Liste, rôles (admin/user), activation/désactivation
- [ ] **Gestion des quiz** — Création/modification questions + réponses multiples
- [ ] **Gestion économie locale** — CRUD services (guides, artisans, hébergements)
- [ ] **Gestion des médias** — Upload via Cloudinary + organisation des fichiers
- [ ] **Gestion SOS** — Voir alertes actives + résoudre (`PATCH /api/sos/alerts/:id/resolve`)
- [ ] **Envoi de notifications** — Push aux utilisateurs (`POST /api/notifications/send`)

### 4.3 — Authentification admin

- [ ] Page de login admin (mêmes endpoints Auth)
- [ ] Restriction d'accès : seul le rôle `admin` peut accéder au back-office
- [ ] Gestion session JWT côté web

---

## Phase 5 : Tests & Qualité

### 5.1 — Tests Backend

- [ ] Tests unitaires des services NestJS
- [ ] Tests d'intégration des endpoints API
- [ ] Test des requêtes géospatiales PostGIS
- [ ] Test de l'upload Cloudinary

### 5.2 — Tests Frontend

- [ ] Tests unitaires des widgets Flutter
- [ ] Tests d'intégration des écrans
- [ ] Test du mode offline (déconnexion réseau)
- [ ] Test GPS et navigation

### 5.3 — Tests Back-Office

- [ ] Tests des formulaires CRUD
- [ ] Test de l'import GeoJSON
- [ ] Test de l'upload média

---

## Phase 6 : Déploiement

### 6.1 — Backend

- [ ] Configurer les variables d'environnement de production
- [ ] Déployer PostgreSQL + PostGIS sur un serveur (AWS RDS, DigitalOcean, OVH)
- [ ] Déployer l'API NestJS (Docker recommandé)
- [ ] Configurer HTTPS (certificat SSL)
- [ ] Configurer un reverse proxy (Nginx)

### 6.2 — Application Mobile

- [ ] Build Android : `flutter build apk --release`
- [ ] Build iOS : `flutter build ios --release`
- [ ] Publication sur Google Play Store / Apple App Store

### 6.3 — Back-Office Web

- [ ] Build web : `flutter build web --release`
- [ ] Déployer sur un hébergement web (Vercel, Netlify, ou serveur propre)

---

## 📋 Résumé de l'ordre de réalisation

| # | Étape | Durée estimée |
|---|-------|---------------|
| 1 | Environnement & prérequis | 1-2 jours |
| 2 | Backend NestJS (entités + modules + API) | 2-3 semaines |
| 3 | App Mobile Flutter (tous les écrans) | 3-4 semaines |
| 4 | Back-Office Flutter Web | 1-2 semaines |
| 5 | Tests & corrections | 1 semaine |
| 6 | Déploiement | 2-3 jours |

> **Total estimé : 8 à 10 semaines** pour un développeur expérimenté travaillant seul.
