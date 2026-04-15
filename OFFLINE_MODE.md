# Mode Hors Ligne - Eco-Guide

## 🌐 Fonctionnement Automatique

L'application **Eco-Guide** fonctionne maintenant automatiquement en mode hors ligne quand :
- ❌ Aucune connexion Internet n'est détectée
- ❌ Le serveur backend n'est pas accessible
- ❌ Une erreur réseau se produit

### Détection Automatique

L'application vérifie automatiquement :
1. **État de la connexion Internet** (WiFi, données mobiles)
2. **Accessibilité du backend** (serveur API)
3. **Échec des requêtes API** (timeout, erreurs réseau)

Quand l'un de ces problèmes est détecté, l'application bascule **automatiquement** sur les données SQLite locales.

---

## 📦 Données Disponibles Hors Ligne

### Seed Data - Jebel Chitana, Nefza, Jendouba, Tunisia

L'application contient des **données préchargées** pour la région de **Jebel Chitana** :

#### 🥾 **3 Sentiers de Randonnée**
1. **Sommet du Jebel Chitana** (8.5 km, Modérée, 4h)
2. **Circuit de la Forêt de Kroumirie** (5.2 km, Facile, 2.5h)
3. **Les Sources d'Aïn Draham** (12.3 km, Difficile, 6h)

#### 📍 **12 Points d'Intérêt (POIs)**
- Belvédères panoramiques
- Sources d'eau naturelles
- Sites historiques (ruines romaines)
- Zones d'observation de la faune
- Aires de repos et pique-nique
- Points d'information et sécurité

#### 🏪 **7 Services Locaux**
- Guide de montagne professionnel
- Hébergement (auberge)
- Restaurant local
- Artisan du liège
- Transport (taxi 4x4)
- Épicerie de montagne
- Pharmacie

---

## 🔄 Initialisation des Données

### Automatique au Démarrage

Les données seed sont **chargées automatiquement** au premier lancement si la base SQLite est vide.

```dart
// main.dart
await OfflineCacheService.instance.initializeSeedData();
```

### Manuel via DB Browser for SQLite

Pour charger manuellement les données :

1. **Ouvrir DB Browser for SQLite**
2. **Ouvrir la base de données** :
   - Android : `/data/data/com.ecoguide.app/databases/ecoguide_offline.db`
   - iOS : `~/Library/Developer/CoreSimulator/.../ecoguide_offline.db`
3. **Onglet "Execute SQL"**
4. **Copier-coller le contenu** du fichier [`seed_data.sql`](seed_data.sql)
5. **Cliquer sur "Execute"** (▶️)
6. **Sauvegarder** (Ctrl+S)

---

## 🎯 Utilisation dans l'Interface

### Indicateurs Visuels

L'application affiche automatiquement :

#### 📊 **Banner Hors Ligne** (en haut de l'écran)
```dart
OfflineBanner() // Affiche "Mode hors ligne"
```

#### 🔴 **Indicateur Badge** (dans l'app bar)
```dart
OfflineIndicator() // Badge "Hors ligne"
```

### Exemple d'Intégration

```dart
Scaffold(
  appBar: AppBar(
    title: Text('Sentiers'),
    actions: [
      OfflineIndicator(), // Badge automatique
    ],
  ),
  body: Column(
    children: [
      OfflineBanner(), // Banner automatique
      // Votre contenu...
    ],
  ),
)
```

---

## 🛠️ Architecture Technique

### Services Modifiés

#### 1. **ConnectivityService** (nouveau)
- Monitore la connexion Internet en temps réel
- Vérifie l'accessibilité du backend
- Notifie les providers des changements d'état

#### 2. **TrailProvider**
```dart
// Vérifie automatiquement la connectivité
if (ConnectivityService.instance.isOfflineMode) {
  // Utilise SQLite directement
  final trails = await OfflineCacheService.instance.getOfflineTrails();
  return;
}

try {
  // Essaye le backend
  final trails = await _service.getTrails();
} catch (e) {
  // Fallback automatique sur SQLite
  final trails = await OfflineCacheService.instance.getOfflineTrails();
}
```

#### 3. **PoiProvider** et **LocalServiceProvider**
- Même logique de fallback automatique
- Filtres appliqués localement sur les données SQLite

---

## 📱 Test du Mode Hors Ligne

### Option 1 : Désactiver la Connexion
1. Activer le mode avion sur votre appareil
2. Ouvrir l'application
3. ✅ Les données de Jebel Chitana s'affichent automatiquement

### Option 2 : Arrêter le Backend
1. Arrêter le serveur backend (`npm stop`)
2. Ouvrir l'application
3. ✅ Fallback automatique sur SQLite

### Option 3 : Simulateur (Flutter)
```bash
# Android Emulator
adb shell svc wifi disable
adb shell svc data disable

# Réactiver
adb shell svc wifi enable
adb shell svc data enable
```

---

## 📊 Vérification des Données

### Requêtes SQL Utiles

```sql
-- Compter les données chargées
SELECT COUNT(*) as trail_count FROM offline_trails;
SELECT COUNT(*) as poi_count FROM offline_pois;
SELECT COUNT(*) as service_count FROM offline_local_services;

-- Voir les sentiers
SELECT name, difficulty, distance FROM offline_trails;

-- Voir les POIs par type
SELECT name, type FROM offline_pois;

-- Voir les services par catégorie
SELECT name, category FROM offline_local_services;
```

---

## 🔧 Troubleshooting

### Problème : Les données ne s'affichent pas hors ligne

**Solutions :**
1. Vérifier que les seed data sont chargées :
   ```dart
   final trails = await OfflineCacheService.instance.getOfflineTrails();
   print('Trails offline: ${trails.length}'); // Devrait afficher 3
   ```

2. Réinitialiser la base de données :
   ```dart
   await OfflineCacheService.instance.clearOfflineTrails();
   await OfflineCacheService.instance.clearOfflinePois();
   await OfflineCacheService.instance.clearOfflineLocalServices();
   await OfflineCacheService.instance.initializeSeedData();
   ```

3. Vérifier la connectivité :
   ```dart
   print(ConnectivityService.instance.isOfflineMode);
   print(ConnectivityService.instance.isOnline);
   print(ConnectivityService.instance.hasBackendConnection);
   ```

### Problème : "Cannot find seed_data.sql"

Le fichier SQL est généré dans le dossier racine `app_front/seed_data.sql`. Vous pouvez l'exécuter manuellement dans DB Browser.

---

## ✅ Checklist de Validation

- [x] Connectivity service initialisé au démarrage
- [x] Seed data chargées automatiquement si DB vide
- [x] TrailProvider utilise SQLite en mode hors ligne
- [x] PoiProvider utilise SQLite en mode hors ligne
- [x] LocalServiceProvider utilise SQLite en mode hors ligne
- [x] Banner hors ligne s'affiche automatiquement
- [x] Filtres de recherche fonctionnent hors ligne
- [x] Détection automatique de la connectivité
- [x] Fallback automatique en cas d'erreur réseau
- [x] 3 sentiers disponibles (Jebel Chitana)
- [x] 12 POIs disponibles
- [x] 7 services locaux disponibles

---

## 📝 Notes Importantes

1. **Les données seed ne sont chargées qu'une seule fois** au premier lancement
2. **Les modifications ne sont pas synchronisées** avec le backend en mode hors ligne
3. **Les utilisateurs peuvent télécharger plus de données** via l'écran "Cartes Hors Ligne"
4. **Le mode hors ligne est automatique**, aucune action utilisateur requise

---

## 🚀 Prochaines Étapes

- [ ] Synchronisation automatique quand la connexion revient
- [ ] File d'attente pour les actions hors ligne (reviews, favoris)
- [ ] Indicateur de taille des données téléchargées
- [ ] Gestion du cache (suppression automatique des vieilles données)
- [ ] Compression des données pour économiser l'espace
