# Eco-Guide — Présentation du projet

> Plateforme complète d'écotourisme et de randonnée pour la région de Tabarka /
> Jbel Chitana (Nefza), Tunisie. L'application accompagne le randonneur avant,
> pendant et après sa sortie — y compris **entièrement hors-ligne**.

---

## 1. En une phrase

Eco-Guide est une suite full-stack (API + appli mobile + back-office web) qui
permet de **découvrir des sentiers, points d'intérêt, services locaux et
quiz pédagogiques**, de **naviguer en pleine nature même sans connexion**, et
d'**alerter les secours (SOS)** en cas de problème.

---

## 2. Les trois sous-projets

| Dossier | Rôle | Stack principale |
|---|---|---|
| [`app_backend/`](app_backend/) | API REST + WebSocket | NestJS · TypeScript · PostgreSQL + PostGIS · TypeORM · Socket.io · Cloudinary · Supabase |
| [`app_front/`](app_front/) | Application mobile (iOS / Android) | Flutter · Provider · `flutter_map` · `sqflite` · `connectivity_plus` · Supabase |
| [`app_backoffice/`](app_backoffice/) | Panneau d'administration web | Flutter Web · Provider · Go Router · `fl_chart` · `data_table_2` |

Communication : **REST/HTTP** pour les opérations CRUD, **Socket.io** pour les
mises à jour temps réel poussées vers les clients, **Cloudinary** pour les
médias.

---

## 3. Fonctionnalités principales

### Côté randonneur (`app_front`)

- **Tableau de bord** avec carte d'aperçu, météo en temps réel, sentiers
  proches, POIs à découvrir.
- **Carte interactive** multi-styles (Standard, Relief, Sombre, Satellite) avec
  marqueurs sentiers / POIs / services.
- **Navigation guidée hybride**
  - en ligne : itinéraire OSRM (API publique) calculé proprement,
  - hors-ligne : itinéraire interne (ligne directe + étapes synthétiques) —
    aucune connexion requise.
- **Alerte hors-sentier (5 m)** avec hystérésis (réactivation à 3 m), vibration
  rythmée, voix TTS, bouton **désactivation/réactivation** (badge bottom bar +
  bouton ✕ dans la bannière).
- **Mode hors-ligne complet**
  - tuiles de carte (Tabarka **+** Jbel Chitana téléchargeables ensemble),
  - sentiers / POIs / services en SQLite via `OfflineCacheService`,
  - bouton **« Tout télécharger / mettre à jour »** pour tout récupérer en
    un clic,
  - bouton **« Forcer hors-ligne »** sur la carte pour tester sans réseau.
- **Bundle d'usine** : la première ouverture peut décompacter des tuiles et
  données embarquées (`assets/offline/`, `assets/seed/`) — un client sans
  connexion peut utiliser l'app dès l'installation (`OfflineSeedService`).
- **SOS** : alerte géolocalisée envoyée au backend, **file d'attente
  hors-ligne** synchronisée automatiquement quand le réseau revient
  (`OfflineSosService`).
- **Quiz écologiques** par catégorie, scores utilisateur, statistiques.
- **Annuaire** des services locaux (guides, artisans, hébergements).
- **Chatbot EcoBot** flottant pour l'aide en contexte.
- **Multilingue** : français · anglais · arabe.
- **Onboarding** rejouable depuis le centre d'aide.

### Côté admin (`app_backoffice`)

- Tableau de bord (graphes via `fl_chart`).
- Gestion des sentiers avec **calcul automatique de la distance et du
  dénivelé** à chaque nouveau point (système interne + bouton de recalcul).
- Gestion des POIs (PostGIS), des services locaux, des quiz.
- Modération SOS, gestion des utilisateurs, médias.
- **Dark mode** (shell sobre, sidebar / topbar).
- **Splash écran** au démarrage, **logo + favicon** intégrés.

### Côté backend (`app_backend`)

14 modules métier orchestrés depuis [`src/app.module.ts`](app_backend/src/app.module.ts) :

`auth` · `users` · `trails` · `pois` · `quizzes` · `local-economy` · `media` ·
`sos` · `activities` · `offline` · `notifications` · `weather` · `admin` ·
`events`

- API montée sur `/api`, doc Swagger sur `/api/docs`.
- Auth JWT + Passport, sessions Supabase.
- PostGIS pour les requêtes géospatiales (POIs proches, etc.).
- Gateway Socket.io diffusant `trail_updated`, `poi_updated`,
  `service_updated`, `quiz_updated` à tous les clients connectés.
- Upload média direct vers Cloudinary, l'URL est persistée côté backend.

---

## 4. Schéma de flux

```
┌──────────────────┐        REST /api/*       ┌────────────────┐
│  Application     │ ───────────────────────▶ │                │
│  mobile          │ ◀─────────────────────── │  NestJS API    │
│  (Flutter)       │       JSON               │                │
└──────────────────┘                          │   + PostGIS    │
        ▲                                     │   + PostgreSQL │
        │   Socket.io (events temps réel)     │                │
        └─────────────────────────────────────│                │
                                              └────────────────┘
                                                      ▲
┌──────────────────┐        REST /api/*               │
│  Back-office     │ ─────────────────────────────────┘
│  (Flutter Web)   │
└──────────────────┘

Médias (images / vidéos) ──────► Cloudinary (uploads directs)
```

Côté mobile, un cache local **SQLite** + **tuiles disque** sert de
back-up à chaque appel réseau (lecture *local-first* via
`LocalFirstTileProvider`).

---

## 5. Pile technique détaillée

### Backend

- **NestJS** (TypeScript) — architecture modulaire (`*.module.ts` →
  `controller` → `service` → `entity` + `dto/`).
- **PostgreSQL + extension PostGIS** — entités avec colonnes géospatiales
  (`geometry`, `geography`).
- **TypeORM** comme ORM.
- **Supabase** pour l'authentification de session, **JWT** propre pour
  l'autorisation des routes API.
- **Cloudinary** pour le stockage média.
- **Socket.io** pour le push temps réel.

### Mobile / Web

- **Flutter** (Dart) — un seul codebase pour Android, iOS et Web.
- **State management : Provider** — `AuthProvider`, `TrailProvider`,
  `PoiProvider`, `QuizProvider`, `LocalServiceProvider`, `WeatherProvider`,
  `ThemeProvider`, `LocaleProvider`, `FavoritesProvider`.
- **Cartographie** : `flutter_map` + `latlong2`, tuiles OpenStreetMap /
  CARTO / Google / Esri.
- **Stockage hors-ligne** : `sqflite` (SQLite), tuiles décompactées sur
  disque (`assets/offline/tiles.zip`), `shared_preferences` pour les
  flags.
- **Réseau** : détection via `connectivity_plus`, file d'attente SOS
  hors-ligne.
- **Temps réel** : `socket_io_client` connecté au gateway NestJS.

---

## 6. Installation rapide

### Backend

```bash
cd app_backend
cp .env.example .env       # remplir DATABASE_*, SUPABASE_*, JWT_SECRET, CLOUDINARY_*
npm install
npm run start:dev          # API sur http://localhost:<PORT>, Swagger /api/docs
```

### Mobile

```bash
cd app_front
cp .env.example .env       # API_HOST = 10.0.2.2 (Android emu) / localhost (iOS) / IP locale (device)
flutter pub get
flutter run
```

### Back-office

```bash
cd app_backoffice
flutter pub get
flutter run -d chrome
```

---

## 7. Zones de couverture hors-ligne par défaut

| Région | Identifiant | Usage |
|---|---|---|
| Tabarka (côte) | `TileBounds.tabarka` | Téléchargement standard |
| Jbel Chitana (Nefza) | `TileBounds.jbelChitana` | Téléchargement standard |
| Autour d'un sentier | `TileBounds.aroundPoint(lat, lng, radiusKm: 3)` | Téléchargement par sentier |

Les deux régions principales sont **téléchargées ensemble** depuis l'écran
*Mode hors ligne* (un bouton, deux progress bars cumulées).

---

## 8. Sécurité et données

- Mots de passe **jamais** stockés en clair : auth Supabase + JWT.
- Validation globale Nest (`ValidationPipe`) sur tous les DTO.
- CORS activé pour l'admin web.
- Les médias circulent uniquement sous forme d'URL Cloudinary signées.
- Le mode hors-ligne **ne synchronise rien automatiquement** sans le
  consentement (toggle « Sync automatique »).

---

## 9. Limites connues / pistes futures

- L'itinéraire hors-ligne est une ligne directe entre points — il ne
  recalcule pas le chemin optimal sans réseau.
- L'estimation du dénivelé back-office utilise l'API publique Open-Meteo
  (requiert une connexion côté admin).
- Pas encore d'authentification multi-facteurs.
- Pas de notifications push natives encore branchées (le module backend
  existe).

---

## 10. Crédits

- Cartes : **OpenStreetMap**, **OpenTopoMap**, **CARTO**, **Esri World
  Imagery**.
- Routage en ligne : **OSRM** (`router.project-osrm.org`).
- Élévation : **Open-Meteo Elevation API**.
- Icônes / illustrations : Material Design + assets internes
  (`assets/images/logo.png`).

---

*Dernière mise à jour : 2026-05-31.*
