# 🚀 Quick Start - Mode Hors Ligne

## Test Rapide (2 minutes)

### 1️⃣ Lancer l'Application

```bash
cd app_front
flutter run
```

### 2️⃣ Vérifier les Données Chargées

Au premier lancement, vous devriez voir dans les logs :

```
✅ Seed data initialized for Jebel Chitana, Nefza, Jendouba
```

### 3️⃣ Activer le Mode Avion

Sur votre appareil :
- 📱 **Android/iOS** : Activer le mode avion
- 💻 **Émulateur** : Désactiver WiFi/Data

### 4️⃣ Tester les Fonctionnalités

#### 🥾 Sentiers
1. Ouvrir l'écran "Sentiers"
2. ✅ Vous devriez voir **3 sentiers** :
   - Sommet du Jebel Chitana
   - Circuit de la Forêt de Kroumirie
   - Les Sources d'Aïn Draham

#### 📍 Points d'Intérêt
1. Ouvrir un sentier
2. ✅ Vous devriez voir des POIs associés
3. ✅ 12 POIs au total disponibles

#### 🏪 Services Locaux
1. Ouvrir l'écran "Services Locaux"
2. ✅ Vous devriez voir **7 services** :
   - Guide de montagne
   - Auberge
   - Restaurant
   - Artisan
   - Taxi
   - Épicerie
   - Pharmacie

---

## 🔍 Indicateurs Visuels

Quand vous êtes hors ligne, vous verrez :

### Banner en Haut de l'Écran
```
🌥️ Mode hors ligne - Aucune connexion Internet
```

### Badge dans l'App Bar
```
🔴 Hors ligne
```

---

## 📊 Vérification Manuelle (SQLite)

### Windows

1. **Télécharger DB Browser** : https://sqlitebrowser.org/
2. **Trouver la base de données** :
   ```
   %LOCALAPPDATA%\app_front\ecoguide_offline.db
   ```
3. **Ouvrir avec DB Browser**
4. **Onglet "Browse Data"**
5. **Vérifier les tables** :
   - `offline_trails` → 3 lignes
   - `offline_pois` → 12 lignes
   - `offline_local_services` → 7 lignes

---

## 🛠️ Réinitialiser les Données

Si vous voulez recharger les seed data :

### Option 1 : Via l'App
```dart
// Dans votre code
await OfflineCacheService.instance.clearOfflineTrails();
await OfflineCacheService.instance.clearOfflinePois();
await OfflineCacheService.instance.clearOfflineLocalServices();
await OfflineCacheService.instance.initializeSeedData();
```

### Option 2 : Via DB Browser
1. Ouvrir la base de données
2. Onglet "Execute SQL"
3. Copier-coller le contenu de [`seed_data.sql`](seed_data.sql)
4. Cliquer sur ▶️ "Execute"
5. Ctrl+S pour sauvegarder

---

## ✅ Checklist de Test

- [ ] Application lance sans erreur
- [ ] Message "Seed data initialized" dans les logs
- [ ] Mode avion activé
- [ ] Banner "Mode hors ligne" s'affiche
- [ ] 3 sentiers visibles dans l'écran Sentiers
- [ ] POIs visibles dans les détails d'un sentier
- [ ] 7 services locaux visibles
- [ ] Recherche fonctionne hors ligne
- [ ] Filtres fonctionnent hors ligne
- [ ] Détails d'un sentier s'affichent

---

## 🐛 Problèmes Courants

### "No trails found"

**Solution** : Les seed data ne sont pas chargées

```bash
# Supprimer l'app et réinstaller
flutter clean
flutter run
```

### "Connection timeout"

**C'est normal** ! L'app devrait automatiquement basculer sur les données locales.

### "Cannot open database"

**Solution** : Permissions manquantes (Android)

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

---

## 📞 Support

Si vous rencontrez des problèmes :

1. Vérifier les logs (`flutter logs`)
2. Consulter [OFFLINE_MODE.md](OFFLINE_MODE.md) pour plus de détails
3. Vérifier que la base SQLite contient bien les données

---

## 🎉 C'est Tout !

Votre application fonctionne maintenant **automatiquement en mode hors ligne** avec les données de **Jebel Chitana, Nefza, Jendouba, Tunisia** ! 🇹🇳
