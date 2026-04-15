import '../models/poi.dart';
import '../models/trail.dart';
import '../models/local_service.dart';

/// Service providing seed data for Jebel Chitana, Nefza, Jendouba, Tunisia
/// This allows the app to work offline with realistic local data
class SeedDataService {
  // Jebel Chitana coordinates: ~36.7833°N, 8.7833°E (Nefza, Jendouba region)
  static const double jebelChitanaLat = 36.7833;
  static const double jebelChitanaLng = 8.7833;

  /// Get seed trails for Jebel Chitana region
  static List<Trail> getSeedTrails() {
    final now = DateTime.now();

    return [
      Trail(
        id: 'seed_trail_1_jebel_chitana_summit',
        name: 'Sommet du Jebel Chitana',
        description:
            'Randonnée panoramique vers le sommet du Jebel Chitana avec vue imprenable sur la région de Nefza et les montagnes de Kroumirie. Traversée de forêts de chênes-lièges et découverte de la faune locale.',
        distance: 8.5,
        difficulty: 'Modérée',
        estimatedDuration: 240, // 4 hours
        elevationGain: 420,
        imageUrls: [
          'https://images.unsplash.com/photo-1551632811-561732d1e306?w=800',
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
        ],
        region: 'Nefza, Jendouba',
        averageRating: 4.7,
        reviewCount: 23,
        startLatitude: jebelChitanaLat - 0.02,
        startLongitude: jebelChitanaLng - 0.015,
        geojson: {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [jebelChitanaLng - 0.015, jebelChitanaLat - 0.02],
                  [jebelChitanaLng - 0.012, jebelChitanaLat - 0.015],
                  [jebelChitanaLng - 0.008, jebelChitanaLat - 0.01],
                  [jebelChitanaLng - 0.003, jebelChitanaLat - 0.005],
                  [jebelChitanaLng, jebelChitanaLat], // Summit
                ]
              },
              'properties': {'name': 'Sentier du Sommet'}
            }
          ]
        },
        isActive: true,
        createdAt: now.subtract(const Duration(days: 120)),
      ),
      Trail(
        id: 'seed_trail_2_foret_kroumirie',
        name: 'Circuit de la Forêt de Kroumirie',
        description:
            'Promenade familiale à travers la dense forêt de chênes-lièges de Kroumirie. Idéale pour observer la flore méditerranéenne et les oiseaux migrateurs. Sentier ombragé et accessible toute l\'année.',
        distance: 5.2,
        difficulty: 'Facile',
        estimatedDuration: 150, // 2.5 hours
        elevationGain: 180,
        imageUrls: [
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800',
          'https://images.unsplash.com/photo-1511497584788-876760111969?w=800',
        ],
        region: 'Nefza, Jendouba',
        averageRating: 4.5,
        reviewCount: 18,
        startLatitude: jebelChitanaLat - 0.035,
        startLongitude: jebelChitanaLng + 0.01,
        geojson: {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [jebelChitanaLng + 0.01, jebelChitanaLat - 0.035],
                  [jebelChitanaLng + 0.015, jebelChitanaLat - 0.03],
                  [jebelChitanaLng + 0.02, jebelChitanaLat - 0.025],
                  [jebelChitanaLng + 0.018, jebelChitanaLat - 0.02],
                  [jebelChitanaLng + 0.01, jebelChitanaLat - 0.035],
                ]
              },
              'properties': {'name': 'Circuit Forestier'}
            }
          ]
        },
        isActive: true,
        createdAt: now.subtract(const Duration(days: 90)),
      ),
      Trail(
        id: 'seed_trail_3_sources_ain_draham',
        name: 'Les Sources d\'Aïn Draham',
        description:
            'Randonnée aquatique reliant plusieurs sources naturelles de la région. Parcours rafraîchissant passant par des cascades et des bassins naturels. Parfait en été.',
        distance: 12.3,
        difficulty: 'Difficile',
        estimatedDuration: 360, // 6 hours
        elevationGain: 650,
        imageUrls: [
          'https://images.unsplash.com/photo-1439066615861-d1af74d74000?w=800',
        ],
        region: 'Nefza, Jendouba',
        averageRating: 4.8,
        reviewCount: 31,
        startLatitude: jebelChitanaLat + 0.02,
        startLongitude: jebelChitanaLng - 0.025,
        geojson: {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [jebelChitanaLng - 0.025, jebelChitanaLat + 0.02],
                  [jebelChitanaLng - 0.02, jebelChitanaLat + 0.025],
                  [jebelChitanaLng - 0.015, jebelChitanaLat + 0.03],
                  [jebelChitanaLng - 0.01, jebelChitanaLat + 0.028],
                  [jebelChitanaLng - 0.005, jebelChitanaLat + 0.025],
                ]
              },
              'properties': {'name': 'Sentier des Sources'}
            }
          ]
        },
        isActive: true,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
    ];
  }

  /// Get seed POIs for Jebel Chitana region
  static List<Poi> getSeedPois() {
    final now = DateTime.now();
    final trails = getSeedTrails();

    return [
      // POIs for Trail 1 - Summit trail
      Poi(
        id: 'seed_poi_1_belvedere_sommet',
        name: 'Belvédère du Sommet',
        type: 'viewpoint',
        description:
            'Point de vue panoramique à 360° sur la région de Kroumirie, la vallée de Nefza et par temps clair, la Méditerranée au nord.',
        badge: 'Vue Exceptionnelle',
        latitude: jebelChitanaLat,
        longitude: jebelChitanaLng,
        mediaUrl:
            'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800',
        trailId: trails[0].id,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 120)),
      ),
      Poi(
        id: 'seed_poi_2_chene_centenaire',
        name: 'Chêne-liège Centenaire',
        type: 'flora',
        description:
            'Magnifique spécimen de chêne-liège (Quercus suber) âgé de plus de 200 ans. Arbre emblématique de la région, exploité traditionnellement pour son écorce.',
        badge: 'Patrimoine Naturel',
        latitude: jebelChitanaLat - 0.008,
        longitude: jebelChitanaLng - 0.01,
        mediaUrl:
            'https://images.unsplash.com/photo-1542273917363-3b1817f69a2d?w=800',
        trailId: trails[0].id,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 118)),
      ),
      Poi(
        id: 'seed_poi_3_source_montagne',
        name: 'Source de la Montagne',
        type: 'water',
        description:
            'Source d\'eau potable naturelle. Point de ravitaillement important pour les randonneurs. Eau fraîche et pure toute l\'année.',
        latitude: jebelChitanaLat - 0.012,
        longitude: jebelChitanaLng - 0.012,
        trailId: trails[0].id,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 115)),
      ),
      Poi(
        id: 'seed_poi_4_ruines_romaines',
        name: 'Vestiges Romains',
        type: 'historical',
        description:
            'Ruines d\'un ancien poste de surveillance romain. Témoignage de l\'occupation romaine dans la région de Jendouba (ancienne Simitthu).',
        badge: 'Site Archéologique',
        learnMoreUrl: 'https://fr.wikipedia.org/wiki/Simitthu',
        latitude: jebelChitanaLat - 0.005,
        longitude: jebelChitanaLng - 0.007,
        mediaUrl:
            'https://images.unsplash.com/photo-1590073242678-70ee3fc28e8e?w=800',
        trailId: trails[0].id,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 110)),
      ),

      // POIs for Trail 2 - Forest circuit
      Poi(
        id: 'seed_poi_5_aire_pique_nique',
        name: 'Aire de Pique-nique Forestière',
        type: 'rest_area',
        description:
            'Espace aménagé avec tables et bancs à l\'ombre des chênes-lièges. Idéal pour une pause déjeuner en pleine nature.',
        latitude: jebelChitanaLat - 0.03,
        longitude: jebelChitanaLng + 0.015,
        trailId: trails[1].id,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 90)),
      ),
      Poi(
        id: 'seed_poi_6_observation_oiseaux',
        name: 'Point d\'Observation Ornithologique',
        type: 'fauna',
        description:
            'Site privilégié pour observer les oiseaux migrateurs : Milan royal, Circaète Jean-le-Blanc, et nombreuses espèces de passereaux.',
        badge: 'Biodiversité',
        latitude: jebelChitanaLat - 0.025,
        longitude: jebelChitanaLng + 0.018,
        mediaUrl:
            'https://images.unsplash.com/photo-1535083783855-76ae62b2914e?w=800',
        trailId: trails[1].id,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 88)),
      ),
      Poi(
        id: 'seed_poi_7_champignons',
        name: 'Zone de Cueillette (Champignons)',
        type: 'information',
        description:
            'Zone riche en champignons comestibles en automne (cèpes, lactaires). Attention : cueillette réglementée, renseignez-vous auprès des gardes forestiers.',
        latitude: jebelChitanaLat - 0.028,
        longitude: jebelChitanaLng + 0.012,
        trailId: trails[1].id,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 85)),
      ),

      // POIs for Trail 3 - Water sources trail
      Poi(
        id: 'seed_poi_8_cascade_principale',
        name: 'Grande Cascade d\'Aïn Draham',
        type: 'water',
        description:
            'Cascade de 15 mètres formant un bassin naturel. Baignade possible en été (eau fraîche 16-18°C). Site prisé des locaux.',
        badge: 'Baignade Naturelle',
        latitude: jebelChitanaLat + 0.025,
        longitude: jebelChitanaLng - 0.02,
        mediaUrl:
            'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=800',
        trailId: trails[2].id,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      Poi(
        id: 'seed_poi_9_grotte_bergers',
        name: 'Grotte des Bergers',
        type: 'historical',
        description:
            'Grotte naturelle utilisée traditionnellement par les bergers pour s\'abriter. Abri possible en cas d\'orage.',
        latitude: jebelChitanaLat + 0.028,
        longitude: jebelChitanaLng - 0.015,
        trailId: trails[2].id,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 58)),
      ),
      Poi(
        id: 'seed_poi_10_zone_danger_sangliers',
        name: 'Zone de Passage de Sangliers',
        type: 'danger',
        description:
            'Zone fréquentée par des sangliers, surtout au crépuscule. Restez sur le sentier et ne nourrissez pas les animaux. Faire du bruit pour signaler votre présence.',
        latitude: jebelChitanaLat + 0.022,
        longitude: jebelChitanaLng - 0.018,
        trailId: trails[2].id,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 55)),
      ),

      // General region POIs (not trail-specific)
      Poi(
        id: 'seed_poi_11_maison_garde_forestier',
        name: 'Maison du Garde Forestier',
        type: 'information',
        description:
            'Poste de garde forestier. Informations sur les sentiers, conditions météo, et réglementation. Présence irrégulière.',
        latitude: jebelChitanaLat - 0.04,
        longitude: jebelChitanaLng + 0.005,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 100)),
      ),
      Poi(
        id: 'seed_poi_12_parking_trailhead',
        name: 'Parking Départ des Sentiers',
        type: 'information',
        description:
            'Parking principal pour accéder aux sentiers de Jebel Chitana. Capacité : 20 véhicules. Gratuit. Présence d\'un panneau d\'information.',
        latitude: jebelChitanaLat - 0.045,
        longitude: jebelChitanaLng,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 150)),
      ),
    ];
  }

  /// Get seed local services for Jebel Chitana region
  static List<LocalService> getSeedLocalServices() {
    final now = DateTime.now();

    return [
      LocalService(
        id: 'seed_service_1_guide_mohamed',
        name: 'Mohamed Trabelsi - Guide de Montagne',
        category: 'guide',
        description:
            'Guide professionnel certifié avec 15 ans d\'expérience dans la région de Kroumirie. Spécialiste de la faune et la flore locale. Parle français, arabe et anglais.',
        contact: '+216 98 123 456',
        email: 'mohamed.trabelsi.guide@gmail.com',
        address: 'Centre-ville de Nefza, Jendouba',
        latitude: jebelChitanaLat - 0.05,
        longitude: jebelChitanaLng + 0.01,
        languages: ['Français', 'Arabe', 'Anglais'],
        rating: 4.9,
        reviewCount: 47,
        isVerified: true,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 200)),
      ),
      LocalService(
        id: 'seed_service_2_auberge_montagne',
        name: 'Auberge de la Montagne',
        category: 'accommodation',
        description:
            'Gîte rural authentique au pied du Jebel Chitana. Chambres simples et confortables. Cuisine traditionnelle tunisienne. Wifi disponible.',
        contact: '+216 78 654 321',
        email: 'auberge.montagne@gmail.com',
        website: 'https://auberge-montagne-nefza.com',
        address: 'Route de Jebel Chitana, Nefza',
        latitude: jebelChitanaLat - 0.048,
        longitude: jebelChitanaLng - 0.005,
        imageUrl:
            'https://images.unsplash.com/photo-1587381420270-3e1a5b9e6904?w=800',
        languages: ['Français', 'Arabe'],
        rating: 4.6,
        reviewCount: 28,
        isVerified: true,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 180)),
      ),
      LocalService(
        id: 'seed_service_3_restaurant_terroir',
        name: 'Restaurant du Terroir',
        category: 'restaurant',
        description:
            'Restaurant familial proposant une cuisine locale : couscous, tajines, grillades. Produits frais de la région. Vue panoramique sur les montagnes.',
        contact: '+216 78 555 444',
        address: 'Avenue Habib Bourguiba, Nefza',
        latitude: jebelChitanaLat - 0.052,
        longitude: jebelChitanaLng + 0.008,
        imageUrl:
            'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800',
        languages: ['Français', 'Arabe'],
        rating: 4.4,
        reviewCount: 35,
        isVerified: true,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 160)),
      ),
      LocalService(
        id: 'seed_service_4_artisan_liege',
        name: 'Artisanat du Liège - Famille Ben Salem',
        category: 'artisan',
        description:
            'Atelier artisanal familial spécialisé dans la transformation du liège. Objets décoratifs, sous-verres, sacs écologiques. Visite de l\'atelier possible.',
        contact: '+216 22 789 012',
        address: 'Souk Nefza, quartier des artisans',
        latitude: jebelChitanaLat - 0.055,
        longitude: jebelChitanaLng + 0.012,
        imageUrl:
            'https://images.unsplash.com/photo-1452860606245-08befc0ff44b?w=800',
        languages: ['Français', 'Arabe'],
        rating: 4.7,
        reviewCount: 19,
        isVerified: true,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 140)),
      ),
      LocalService(
        id: 'seed_service_5_transport_taxi',
        name: 'Taxi Montagne - Karim',
        category: 'transport',
        description:
            'Service de taxi 4x4 pour accès aux points de départ des randonnées. Disponible 7j/7. Possibilité de navette retour en fin de journée.',
        contact: '+216 97 333 222',
        address: 'Station taxi, centre Nefza',
        latitude: jebelChitanaLat - 0.051,
        longitude: jebelChitanaLng + 0.009,
        rating: 4.3,
        reviewCount: 22,
        isVerified: false,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 120)),
      ),
      LocalService(
        id: 'seed_service_6_epicerie_montagne',
        name: 'Épicerie de la Montagne',
        category: 'equipment',
        description:
            'Épicerie générale proposant provisions pour randonnées, eau, snacks, et équipement basique (lampes, piles, couvertures). Ouvert tous les jours 7h-20h.',
        contact: '+216 78 666 777',
        address: 'Route principale, entrée Nefza',
        latitude: jebelChitanaLat - 0.049,
        longitude: jebelChitanaLng + 0.007,
        rating: 4.1,
        reviewCount: 15,
        isVerified: false,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 100)),
      ),
      LocalService(
        id: 'seed_service_7_pharmacie_nefza',
        name: 'Pharmacie Centrale de Nefza',
        category: 'equipment',
        description:
            'Pharmacie complète. Fournitures médicales de base, trousses de secours, protection solaire. Ouvert du lundi au samedi 8h-18h.',
        contact: '+216 78 888 999',
        address: 'Avenue principale, Nefza',
        latitude: jebelChitanaLat - 0.053,
        longitude: jebelChitanaLng + 0.011,
        rating: 4.5,
        reviewCount: 12,
        isVerified: true,
        isActive: true,
        createdAt: now.subtract(const Duration(days: 180)),
      ),
    ];
  }

  /// Initialize database with seed data if empty
  static Future<void> initializeSeedDataIfNeeded(
    Future<void> Function(List<Trail> trails, String quality, double sizeMb)
        saveTrails,
    Future<void> Function(List<Poi> pois) savePois,
    Future<void> Function(List<LocalService> services) saveServices,
    Future<List<Trail>> Function() getTrails,
  ) async {
    // Check if database already has data
    final existingTrails = await getTrails();

    if (existingTrails.isEmpty) {
      // Database is empty, populate with seed data
      final seedTrails = getSeedTrails();
      final seedPois = getSeedPois();
      final seedServices = getSeedLocalServices();

      await saveTrails(seedTrails, 'Moyenne', 12.5);
      await savePois(seedPois);
      await saveServices(seedServices);
    }
  }
}
