-- ============================================================================
-- Eco-Guide Seed Data for Jebel Chitana, Nefza, Jendouba, Tunisia
-- ============================================================================
-- This file contains seed data for offline mode testing
-- Execute this file in SQLite to populate the database manually
-- ============================================================================

-- Clear existing data
DELETE FROM offline_trails;
DELETE FROM offline_pois;
DELETE FROM offline_local_services;

-- ============================================================================
-- TRAILS - Jebel Chitana Region
-- ============================================================================

-- Trail 1: Sommet du Jebel Chitana
INSERT INTO offline_trails (id, payload, downloadedAt, quality, sizeMb) VALUES (
  'seed_trail_1_jebel_chitana_summit',
  '{"id":"seed_trail_1_jebel_chitana_summit","name":"Sommet du Jebel Chitana","description":"Randonnée panoramique vers le sommet du Jebel Chitana avec vue imprenable sur la région de Nefza et les montagnes de Kroumirie. Traversée de forêts de chênes-lièges et découverte de la faune locale.","distance":8.5,"difficulty":"Modérée","estimatedDuration":240,"elevationGain":420,"imageUrls":["https://images.unsplash.com/photo-1551632811-561732d1e306?w=800","https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800"],"region":"Nefza, Jendouba","averageRating":4.7,"reviewCount":23,"startLatitude":36.7633,"startLongitude":8.7683,"geojson":{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"LineString","coordinates":[[8.7683,36.7633],[8.7713,36.7683],[8.7753,36.7733],[8.7803,36.7783],[8.7833,36.7833]]},"properties":{"name":"Sentier du Sommet"}}]},"isActive":true,"createdAt":"2025-12-16T00:00:00.000Z"}',
  datetime('now'),
  'Moyenne',
  4.2
);

-- Trail 2: Circuit de la Forêt de Kroumirie
INSERT INTO offline_trails (id, payload, downloadedAt, quality, sizeMb) VALUES (
  'seed_trail_2_foret_kroumirie',
  '{"id":"seed_trail_2_foret_kroumirie","name":"Circuit de la Forêt de Kroumirie","description":"Promenade familiale à travers la dense forêt de chênes-lièges de Kroumirie. Idéale pour observer la flore méditerranéenne et les oiseaux migrateurs. Sentier ombragé et accessible toute l''année.","distance":5.2,"difficulty":"Facile","estimatedDuration":150,"elevationGain":180,"imageUrls":["https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800","https://images.unsplash.com/photo-1511497584788-876760111969?w=800"],"region":"Nefza, Jendouba","averageRating":4.5,"reviewCount":18,"startLatitude":36.7483,"startLongitude":8.7933,"geojson":{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"LineString","coordinates":[[8.7933,36.7483],[8.7983,36.7533],[8.8033,36.7583],[8.8013,36.7633],[8.7933,36.7483]]},"properties":{"name":"Circuit Forestier"}}]},"isActive":true,"createdAt":"2026-01-15T00:00:00.000Z"}',
  datetime('now'),
  'Moyenne',
  4.1
);

-- Trail 3: Les Sources d'Aïn Draham
INSERT INTO offline_trails (id, payload, downloadedAt, quality, sizeMb) VALUES (
  'seed_trail_3_sources_ain_draham',
  '{"id":"seed_trail_3_sources_ain_draham","name":"Les Sources d''Aïn Draham","description":"Randonnée aquatique reliant plusieurs sources naturelles de la région. Parcours rafraîchissant passant par des cascades et des bassins naturels. Parfait en été.","distance":12.3,"difficulty":"Difficile","estimatedDuration":360,"elevationGain":650,"imageUrls":["https://images.unsplash.com/photo-1439066615861-d1af74d74000?w=800"],"region":"Nefza, Jendouba","averageRating":4.8,"reviewCount":31,"startLatitude":36.8033,"startLongitude":8.7583,"geojson":{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"LineString","coordinates":[[8.7583,36.8033],[8.7633,36.8083],[8.7683,36.8133],[8.7733,36.8113],[8.7783,36.8083]]},"properties":{"name":"Sentier des Sources"}}]},"isActive":true,"createdAt":"2026-02-14T00:00:00.000Z"}',
  datetime('now'),
  'Moyenne',
  4.2
);

-- ============================================================================
-- POIS - Points of Interest
-- ============================================================================

-- POIs for Trail 1
INSERT INTO offline_pois (id, trailId, payload) VALUES (
  'seed_poi_1_belvedere_sommet',
  'seed_trail_1_jebel_chitana_summit',
  '{"id":"seed_poi_1_belvedere_sommet","name":"Belvédère du Sommet","type":"viewpoint","description":"Point de vue panoramique à 360° sur la région de Kroumirie, la vallée de Nefza et par temps clair, la Méditerranée au nord.","badge":"Vue Exceptionnelle","latitude":36.7833,"longitude":8.7833,"mediaUrl":"https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=800","trailId":"seed_trail_1_jebel_chitana_summit","isActive":true,"createdAt":"2025-12-16T00:00:00.000Z"}'
);

INSERT INTO offline_pois (id, trailId, payload) VALUES (
  'seed_poi_2_chene_centenaire',
  'seed_trail_1_jebel_chitana_summit',
  '{"id":"seed_poi_2_chene_centenaire","name":"Chêne-liège Centenaire","type":"flora","description":"Magnifique spécimen de chêne-liège (Quercus suber) âgé de plus de 200 ans. Arbre emblématique de la région, exploité traditionnellement pour son écorce.","badge":"Patrimoine Naturel","latitude":36.7753,"longitude":8.7733,"mediaUrl":"https://images.unsplash.com/photo-1542273917363-3b1817f69a2d?w=800","trailId":"seed_trail_1_jebel_chitana_summit","isActive":true,"createdAt":"2025-12-18T00:00:00.000Z"}'
);

INSERT INTO offline_pois (id, trailId, payload) VALUES (
  'seed_poi_3_source_montagne',
  'seed_trail_1_jebel_chitana_summit',
  '{"id":"seed_poi_3_source_montagne","name":"Source de la Montagne","type":"water","description":"Source d''eau potable naturelle. Point de ravitaillement important pour les randonneurs. Eau fraîche et pure toute l''année.","latitude":36.7713,"longitude":8.7713,"trailId":"seed_trail_1_jebel_chitana_summit","isActive":true,"createdAt":"2025-12-21T00:00:00.000Z"}'
);

INSERT INTO offline_pois (id, trailId, payload) VALUES (
  'seed_poi_4_ruines_romaines',
  'seed_trail_1_jebel_chitana_summit',
  '{"id":"seed_poi_4_ruines_romaines","name":"Vestiges Romains","type":"historical","description":"Ruines d''un ancien poste de surveillance romain. Témoignage de l''occupation romaine dans la région de Jendouba (ancienne Simitthu).","badge":"Site Archéologique","learnMoreUrl":"https://fr.wikipedia.org/wiki/Simitthu","latitude":36.7783,"longitude":8.7763,"mediaUrl":"https://images.unsplash.com/photo-1590073242678-70ee3fc28e8e?w=800","trailId":"seed_trail_1_jebel_chitana_summit","isActive":true,"createdAt":"2025-12-26T00:00:00.000Z"}'
);

-- POIs for Trail 2
INSERT INTO offline_pois (id, trailId, payload) VALUES (
  'seed_poi_5_aire_pique_nique',
  'seed_trail_2_foret_kroumirie',
  '{"id":"seed_poi_5_aire_pique_nique","name":"Aire de Pique-nique Forestière","type":"rest_area","description":"Espace aménagé avec tables et bancs à l''ombre des chênes-lièges. Idéal pour une pause déjeuner en pleine nature.","latitude":36.7533,"longitude":8.7983,"trailId":"seed_trail_2_foret_kroumirie","isActive":true,"createdAt":"2026-01-15T00:00:00.000Z"}'
);

INSERT INTO offline_pois (id, trailId, payload) VALUES (
  'seed_poi_6_observation_oiseaux',
  'seed_trail_2_foret_kroumirie',
  '{"id":"seed_poi_6_observation_oiseaux","name":"Point d''Observation Ornithologique","type":"fauna","description":"Site privilégié pour observer les oiseaux migrateurs : Milan royal, Circaète Jean-le-Blanc, et nombreuses espèces de passereaux.","badge":"Biodiversité","latitude":36.7583,"longitude":8.8013,"mediaUrl":"https://images.unsplash.com/photo-1535083783855-76ae62b2914e?w=800","trailId":"seed_trail_2_foret_kroumirie","isActive":true,"createdAt":"2026-01-17T00:00:00.000Z"}'
);

INSERT INTO offline_pois (id, trailId, payload) VALUES (
  'seed_poi_7_champignons',
  'seed_trail_2_foret_kroumirie',
  '{"id":"seed_poi_7_champignons","name":"Zone de Cueillette (Champignons)","type":"information","description":"Zone riche en champignons comestibles en automne (cèpes, lactaires). Attention : cueillette réglementée, renseignez-vous auprès des gardes forestiers.","latitude":36.7553,"longitude":8.7953,"trailId":"seed_trail_2_foret_kroumirie","isActive":true,"createdAt":"2026-01-20T00:00:00.000Z"}'
);

-- POIs for Trail 3
INSERT INTO offline_pois (id, trailId, payload) VALUES (
  'seed_poi_8_cascade_principale',
  'seed_trail_3_sources_ain_draham',
  '{"id":"seed_poi_8_cascade_principale","name":"Grande Cascade d''Aïn Draham","type":"water","description":"Cascade de 15 mètres formant un bassin naturel. Baignade possible en été (eau fraîche 16-18°C). Site prisé des locaux.","badge":"Baignade Naturelle","latitude":36.8083,"longitude":8.7633,"mediaUrl":"https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=800","trailId":"seed_trail_3_sources_ain_draham","isActive":true,"createdAt":"2026-02-14T00:00:00.000Z"}'
);

INSERT INTO offline_pois (id, trailId, payload) VALUES (
  'seed_poi_9_grotte_bergers',
  'seed_trail_3_sources_ain_draham',
  '{"id":"seed_poi_9_grotte_bergers","name":"Grotte des Bergers","type":"historical","description":"Grotte naturelle utilisée traditionnellement par les bergers pour s''abriter. Abri possible en cas d''orage.","latitude":36.8113,"longitude":8.7683,"trailId":"seed_trail_3_sources_ain_draham","isActive":true,"createdAt":"2026-02-16T00:00:00.000Z"}'
);

INSERT INTO offline_pois (id, trailId, payload) VALUES (
  'seed_poi_10_zone_danger_sangliers',
  'seed_trail_3_sources_ain_draham',
  '{"id":"seed_poi_10_zone_danger_sangliers","name":"Zone de Passage de Sangliers","type":"danger","description":"Zone fréquentée par des sangliers, surtout au crépuscule. Restez sur le sentier et ne nourrissez pas les animaux. Faire du bruit pour signaler votre présence.","latitude":36.8053,"longitude":8.7613,"trailId":"seed_trail_3_sources_ain_draham","isActive":true,"createdAt":"2026-02-19T00:00:00.000Z"}'
);

-- General POIs (not trail-specific)
INSERT INTO offline_pois (id, trailId, payload) VALUES (
  'seed_poi_11_maison_garde_forestier',
  NULL,
  '{"id":"seed_poi_11_maison_garde_forestier","name":"Maison du Garde Forestier","type":"information","description":"Poste de garde forestier. Informations sur les sentiers, conditions météo, et réglementation. Présence irrégulière.","latitude":36.7433,"longitude":8.7883,"isActive":true,"createdAt":"2026-01-05T00:00:00.000Z"}'
);

INSERT INTO offline_pois (id, trailId, payload) VALUES (
  'seed_poi_12_parking_trailhead',
  NULL,
  '{"id":"seed_poi_12_parking_trailhead","name":"Parking Départ des Sentiers","type":"information","description":"Parking principal pour accéder aux sentiers de Jebel Chitana. Capacité : 20 véhicules. Gratuit. Présence d''un panneau d''information.","latitude":36.7383,"longitude":8.7833,"isActive":true,"createdAt":"2025-11-16T00:00:00.000Z"}'
);

-- ============================================================================
-- LOCAL SERVICES - Accommodation, Guides, Restaurants, etc.
-- ============================================================================

INSERT INTO offline_local_services (id, payload, downloadedAt) VALUES (
  'seed_service_1_guide_mohamed',
  '{"id":"seed_service_1_guide_mohamed","name":"Mohamed Trabelsi - Guide de Montagne","category":"guide","description":"Guide professionnel certifié avec 15 ans d''expérience dans la région de Kroumirie. Spécialiste de la faune et la flore locale. Parle français, arabe et anglais.","contact":"+216 98 123 456","email":"mohamed.trabelsi.guide@gmail.com","address":"Centre-ville de Nefza, Jendouba","latitude":36.7333,"longitude":8.7933,"languages":["Français","Arabe","Anglais"],"rating":4.9,"reviewCount":47,"isVerified":true,"isActive":true,"createdAt":"2025-09-28T00:00:00.000Z"}',
  datetime('now')
);

INSERT INTO offline_local_services (id, payload, downloadedAt) VALUES (
  'seed_service_2_auberge_montagne',
  '{"id":"seed_service_2_auberge_montagne","name":"Auberge de la Montagne","category":"accommodation","description":"Gîte rural authentique au pied du Jebel Chitana. Chambres simples et confortables. Cuisine traditionnelle tunisienne. Wifi disponible.","contact":"+216 78 654 321","email":"auberge.montagne@gmail.com","website":"https://auberge-montagne-nefza.com","address":"Route de Jebel Chitana, Nefza","latitude":36.7353,"longitude":8.7783,"imageUrl":"https://images.unsplash.com/photo-1587381420270-3e1a5b9e6904?w=800","languages":["Français","Arabe"],"rating":4.6,"reviewCount":28,"isVerified":true,"isActive":true,"createdAt":"2025-10-18T00:00:00.000Z"}',
  datetime('now')
);

INSERT INTO offline_local_services (id, payload, downloadedAt) VALUES (
  'seed_service_3_restaurant_terroir',
  '{"id":"seed_service_3_restaurant_terroir","name":"Restaurant du Terroir","category":"restaurant","description":"Restaurant familial proposant une cuisine locale : couscous, tajines, grillades. Produits frais de la région. Vue panoramique sur les montagnes.","contact":"+216 78 555 444","address":"Avenue Habib Bourguiba, Nefza","latitude":36.7313,"longitude":8.7913,"imageUrl":"https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800","languages":["Français","Arabe"],"rating":4.4,"reviewCount":35,"isVerified":true,"isActive":true,"createdAt":"2025-11-07T00:00:00.000Z"}',
  datetime('now')
);

INSERT INTO offline_local_services (id, payload, downloadedAt) VALUES (
  'seed_service_4_artisan_liege',
  '{"id":"seed_service_4_artisan_liege","name":"Artisanat du Liège - Famille Ben Salem","category":"artisan","description":"Atelier artisanal familial spécialisé dans la transformation du liège. Objets décoratifs, sous-verres, sacs écologiques. Visite de l''atelier possible.","contact":"+216 22 789 012","address":"Souk Nefza, quartier des artisans","latitude":36.7283,"longitude":8.7953,"imageUrl":"https://images.unsplash.com/photo-1452860606245-08befc0ff44b?w=800","languages":["Français","Arabe"],"rating":4.7,"reviewCount":19,"isVerified":true,"isActive":true,"createdAt":"2025-11-27T00:00:00.000Z"}',
  datetime('now')
);

INSERT INTO offline_local_services (id, payload, downloadedAt) VALUES (
  'seed_service_5_transport_taxi',
  '{"id":"seed_service_5_transport_taxi","name":"Taxi Montagne - Karim","category":"transport","description":"Service de taxi 4x4 pour accès aux points de départ des randonnées. Disponible 7j/7. Possibilité de navette retour en fin de journée.","contact":"+216 97 333 222","address":"Station taxi, centre Nefza","latitude":36.7323,"longitude":8.7923,"rating":4.3,"reviewCount":22,"isVerified":false,"isActive":true,"createdAt":"2025-12-16T00:00:00.000Z"}',
  datetime('now')
);

INSERT INTO offline_local_services (id, payload, downloadedAt) VALUES (
  'seed_service_6_epicerie_montagne',
  '{"id":"seed_service_6_epicerie_montagne","name":"Épicerie de la Montagne","category":"equipment","description":"Épicerie générale proposant provisions pour randonnées, eau, snacks, et équipement basique (lampes, piles, couvertures). Ouvert tous les jours 7h-20h.","contact":"+216 78 666 777","address":"Route principale, entrée Nefza","latitude":36.7343,"longitude":8.7903,"rating":4.1,"reviewCount":15,"isVerified":false,"isActive":true,"createdAt":"2026-01-05T00:00:00.000Z"}',
  datetime('now')
);

INSERT INTO offline_local_services (id, payload, downloadedAt) VALUES (
  'seed_service_7_pharmacie_nefza',
  '{"id":"seed_service_7_pharmacie_nefza","name":"Pharmacie Centrale de Nefza","category":"equipment","description":"Pharmacie complète. Fournitures médicales de base, trousses de secours, protection solaire. Ouvert du lundi au samedi 8h-18h.","contact":"+216 78 888 999","address":"Avenue principale, Nefza","latitude":36.7303,"longitude":8.7943,"rating":4.5,"reviewCount":12,"isVerified":true,"isActive":true,"createdAt":"2025-10-18T00:00:00.000Z"}',
  datetime('now')
);

-- ============================================================================
-- Verification Queries
-- ============================================================================
-- Run these to verify the data was inserted correctly:

-- SELECT COUNT(*) as trail_count FROM offline_trails;
-- SELECT COUNT(*) as poi_count FROM offline_pois;
-- SELECT COUNT(*) as service_count FROM offline_local_services;

-- SELECT name, difficulty, distance FROM offline_trails;
-- SELECT name, type FROM offline_pois LIMIT 10;
-- SELECT name, category FROM offline_local_services;
