# Eco-Guide Mobile App

Application mobile Flutter pour les randonneurs.

## Configuration API

Avant de lancer l'application, configurez l'URL de l'API backend dans le fichier :
`lib/core/constants/api_constants.dart`

### Environnements de test

1. **Emulateur Android** : Utilisez `10.0.2.2`
   ```dart
   static const String _host = '10.0.2.2';
   ```

2. **Simulateur iOS** : Utilisez `localhost`
   ```dart
   static const String _host = 'localhost';
   ```

3. **Appareil physique** : Utilisez l'adresse IP de votre ordinateur
   ```dart
   static const String _host = '192.168.71.79'; // Remplacez par votre IP
   ```

## Installation

```bash
# Installer les dépendances
flutter pub get

# Lancer l'application
flutter run
```

## Backend

Le backend NestJS doit être lancé avant l'application mobile :

```bash
cd ../app_backend
npm run start:dev
```

Le backend sera accessible sur `http://localhost:3000/api`

## Fonctionnalités implémentées

- ✅ Authentification (Login/Register)
- ✅ Carte interactive avec marqueurs
- ✅ Liste et détail des sentiers
- ✅ Points d'intérêt (POI)
- ✅ Quiz éducatif
- ✅ Annuaire des services locaux
- ✅ Profil utilisateur avec statistiques
- ✅ SOS d'urgence
