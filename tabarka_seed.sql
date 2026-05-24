-- ============================================================
-- Eco-Guide — Tabarka, Tunisia  (36.953691, 8.759213)
-- 3 trails + 18 POIs
-- Run against your Supabase / PostgreSQL database
-- ============================================================

-- ── TRAILS ───────────────────────────────────────────────────

INSERT INTO trails (
  id, name, description,
  distance, difficulty, "estimatedDuration", "elevationGain",
  "imageUrls", region,
  "startLatitude", "startLongitude",
  geojson, "isActive", "createdAt"
) VALUES

-- Trail 1 · Sentier Côtier de Tabarka (~5.2 km, facile)
(
  'aaaaaaaa-0001-0001-0001-000000000001',
  'Sentier Côtier de Tabarka',
  'Randonnée le long de la côte méditerranéenne entre plages de sable doré et falaises ocre. Vue panoramique sur les Aiguilles de Tabarka et le large. Idéal au lever du soleil.',
  5200, 'easy', 90, 45,
  ARRAY[]::text[],
  'Tabarka, Tunisie',
  36.9548, 8.7412,
  '{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"LineString","coordinates":[[8.7412,36.9548],[8.7435,36.9553],[8.7460,36.9561],[8.7483,36.9559],[8.7507,36.9553],[8.7530,36.9547],[8.7554,36.9543],[8.7578,36.9549],[8.7602,36.9560],[8.7628,36.9558],[8.7652,36.9551],[8.7678,36.9545],[8.7704,36.9541],[8.7730,36.9538]]},"properties":{}}]}',
  true, NOW()
),

-- Trail 2 · Boucle Forêt des Chênes-Liège (~8.7 km, modéré)
(
  'aaaaaaaa-0002-0002-0002-000000000002',
  'Boucle de la Forêt des Chênes-Liège',
  'Grande boucle au cœur de la forêt de la Kroumirie, l''une des dernières forêts de chênes-liège d''Afrique du Nord. Faune sauvage, sources naturelles et panoramas sur la mer.',
  8700, 'moderate', 180, 320,
  ARRAY[]::text[],
  'Kroumirie, Tabarka',
  36.9480, 8.7590,
  '{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"LineString","coordinates":[[8.7590,36.9480],[8.7612,36.9460],[8.7640,36.9440],[8.7665,36.9420],[8.7692,36.9405],[8.7722,36.9394],[8.7750,36.9385],[8.7782,36.9378],[8.7812,36.9373],[8.7840,36.9380],[8.7862,36.9400],[8.7872,36.9428],[8.7865,36.9455],[8.7848,36.9478],[8.7828,36.9498],[8.7803,36.9514],[8.7778,36.9525],[8.7748,36.9532],[8.7718,36.9528],[8.7688,36.9518],[8.7658,36.9507],[8.7628,36.9495],[8.7600,36.9487],[8.7590,36.9480]]},"properties":{}}]}',
  true, NOW()
),

-- Trail 3 · Sentier des Aiguilles (~3.1 km, facile)
(
  'aaaaaaaa-0003-0003-0003-000000000003',
  'Sentier des Aiguilles de Tabarka',
  'Court sentier menant aux célèbres formations rocheuses calcaires des Aiguilles. Point de vue exceptionnel sur la Méditerranée et le port de Tabarka. Magnifique au coucher du soleil.',
  3100, 'easy', 60, 80,
  ARRAY[]::text[],
  'Tabarka, Tunisie',
  36.9652, 8.7450,
  '{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"LineString","coordinates":[[8.7450,36.9652],[8.7464,36.9640],[8.7478,36.9627],[8.7491,36.9616],[8.7504,36.9606],[8.7518,36.9598],[8.7531,36.9590],[8.7544,36.9581],[8.7557,36.9573],[8.7570,36.9566],[8.7582,36.9560],[8.7592,36.9556]]},"properties":{}}]}',
  true, NOW()
);


-- ── POINTS OF INTEREST ────────────────────────────────────────

INSERT INTO pois (
  id, name, type, description, badge,
  "learnMoreUrl", latitude, longitude,
  "mediaUrl", "additionalMediaUrls", "videoUrls", "audioGuideUrl",
  "trailId", "isActive", "createdAt"
) VALUES

-- ── Trail 1 — Côtier ──────────────────────────────────────────

(
  gen_random_uuid(),
  'Plage de la Grande Crique',
  'viewpoint',
  'Crique de sable blanc encadrée de rochers dorés, typique du littoral tabarkois. Eaux cristallines propices à la baignade et à l''observation des fonds marins.',
  NULL, NULL,
  36.9552, 8.7435,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0001-0001-0001-000000000001', true, NOW()
),

(
  gen_random_uuid(),
  'Grotte Marine de l''Écume',
  'viewpoint',
  'Grotte naturelle creusée par l''érosion marine. À marée basse, accessible à pied ; les parois calcaires abritent des concrétions colorées et des nids d''oiseaux marins.',
  NULL, NULL,
  36.9558, 8.7508,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0001-0001-0001-000000000001', true, NOW()
),

(
  gen_random_uuid(),
  'Falaises des Cormorans',
  'fauna',
  'Secteur de falaises de 15 à 20 m fréquenté par des colonies de cormorans huppés et de goélands leucophées. Observer au crépuscule pour les voir regagner leurs nids.',
  NULL, NULL,
  36.9560, 8.7602,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0001-0001-0001-000000000001', true, NOW()
),

(
  gen_random_uuid(),
  'Table de Pique-Nique du Cap',
  'rest_area',
  'Aire de repos ombragée sous un pin parasol avec tables et bancs en bois. Vue directe sur la mer. Point d''eau non potable disponible à 50 m.',
  NULL, NULL,
  36.9547, 8.7652,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0001-0001-0001-000000000001', true, NOW()
),

(
  gen_random_uuid(),
  'Épave du Cargo Tabarkois',
  'viewpoint',
  'À marée basse, on aperçoit depuis le sentier la silhouette d''un cargo échoué dans les années 1970. Site de plongée sous-marine réputé accessible depuis le rivage.',
  NULL, NULL,
  36.9540, 8.7705,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0001-0001-0001-000000000001', true, NOW()
),

-- ── Trail 2 — Forêt ──────────────────────────────────────────

(
  gen_random_uuid(),
  'Chêne-Liège Tricentenaire',
  'flora',
  'Spécimen remarquable de chêne-liège (Quercus suber) estimé à plus de 300 ans, avec une circonférence de 4,2 m. Son écorce a été prélevée pour la dernière fois en 2019.',
  NULL, NULL,
  36.9438, 8.7668,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0002-0002-0002-000000000002', true, NOW()
),

(
  gen_random_uuid(),
  'Source Ain el-Kharoub',
  'water',
  'Source naturelle pérenne dont l''eau douce et froide (14 °C) est potable. Elle alimente un petit ruisseau qui traverse la forêt. Idéale pour remplir les gourdes.',
  NULL, NULL,
  36.9395, 8.7722,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0002-0002-0002-000000000002', true, NOW()
),

(
  gen_random_uuid(),
  'Observatoire Naturaliste',
  'fauna',
  'Affût en bois permettant d''observer sangliers, lièvres de Barbarie et rapaces (bondrée apivore, épervier d''Europe) sans les déranger. Jumelles conseillées tôt le matin.',
  NULL, NULL,
  36.9380, 8.7782,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0002-0002-0002-000000000002', true, NOW()
),

(
  gen_random_uuid(),
  'Vestiges Numides du Col',
  'historical',
  'Restes d''un poste de guet numide (IIe s. av. J.-C.) : pierres taillées et fragments de céramique. Le col offrait un passage stratégique entre la côte et l''arrière-pays.',
  NULL, NULL,
  36.9375, 8.7812,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0002-0002-0002-000000000002', true, NOW()
),

(
  gen_random_uuid(),
  'Crête Panoramique Jbel Diss',
  'viewpoint',
  'Sommet à 412 m d''altitude offrant une vue à 360° : mer Méditerranée au nord, forêts de la Kroumirie au sud, frontière algérienne à l''ouest. Point GPS précis du sommet.',
  NULL, NULL,
  36.9373, 8.7840,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0002-0002-0002-000000000002', true, NOW()
),

(
  gen_random_uuid(),
  'Zone de Bivouac Forestière',
  'camping',
  'Clairière aménagée pour le camping (autorisation requise auprès de la Direction des forêts). Emplacement pour 6 tentes, foyer en pierre, poubelles. Eau à 300 m (source Ain el-Kharoub).',
  NULL, NULL,
  36.9455, 8.7865,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0002-0002-0002-000000000002', true, NOW()
),

(
  gen_random_uuid(),
  'Pépinière Forestière Nationale',
  'information',
  'Station de la pépinière nationale qui produit chaque année des milliers de plants de chênes-liège pour la reforestation de la Kroumirie. Des panneaux expliquent le cycle de récolte du liège.',
  NULL, NULL,
  36.9500, 8.7830,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0002-0002-0002-000000000002', true, NOW()
),

-- ── Trail 3 — Aiguilles ──────────────────────────────────────

(
  gen_random_uuid(),
  'Les Aiguilles de Tabarka',
  'viewpoint',
  'Formations calcaires spectaculaires surgissant de la mer, classées monument naturel. Ces pitons rocheux de 20 à 40 m abritent une riche faune marine et des nids de faucons pèlerins.',
  NULL, NULL,
  36.9556, 8.7592,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0003-0003-0003-000000000003', true, NOW()
),

(
  gen_random_uuid(),
  'Ancien Phare Ottoman',
  'historical',
  'Phare construit à l''époque ottomane (XIXe s.) pour guider les navires dans le détroit. Restauré en 1954, il fonctionne encore aujourd''hui. Accès à la base uniquement.',
  NULL, NULL,
  36.9640, 8.7464,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0003-0003-0003-000000000003', true, NOW()
),

(
  gen_random_uuid(),
  'Belvédère du Coucher de Soleil',
  'viewpoint',
  'Esplanade rocheuse dégagée, idéale pour admirer le coucher de soleil sur la Méditerranée. La lumière dorée illumine les Aiguilles de façon spectaculaire entre 18 h et 20 h en été.',
  NULL, NULL,
  36.9598, 8.7518,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0003-0003-0003-000000000003', true, NOW()
),

(
  gen_random_uuid(),
  'Panneau d''Accueil et Sécurité',
  'information',
  'Panneau officiel de la Direction des parcs nationaux : carte du sentier, règles de sécurité, numéros d''urgence (Protection civile : 198, SAMU : 190). Prévenez toujours quelqu''un avant de partir.',
  NULL, NULL,
  36.9650, 8.7452,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0003-0003-0003-000000000003', true, NOW()
),

(
  gen_random_uuid(),
  'Passage Dangereux — Falaise',
  'danger',
  'Attention : passage étroit de 80 cm au bord d''une falaise de 35 m de hauteur. Garde-corps absent. Déconseillé par vent fort ou temps humide. Enfants à tenir par la main.',
  NULL, NULL,
  36.9573, 8.7557,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  'aaaaaaaa-0003-0003-0003-000000000003', true, NOW()
),

-- ── POIs sans sentier (zone Tabarka générale) ────────────────

(
  gen_random_uuid(),
  'Port de Plaisance de Tabarka',
  'information',
  'Point de départ recommandé pour tous les sentiers côtiers. Le port dispose de parkings gratuits, de toilettes publiques et de deux cafés ouverts dès 6 h. Bus régional depuis Aïn Draham.',
  NULL, NULL,
  36.9537, 8.7592,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  NULL, true, NOW()
),

(
  gen_random_uuid(),
  'Zone Naturelle Protégée — Kroumirie',
  'information',
  'La forêt de la Kroumirie est classée réserve naturelle nationale. Cueillette, feux de camp hors zones aménagées et circulation en véhicule motorisé sont interdits sous peine d''amende.',
  NULL, NULL,
  36.9420, 8.7690,
  NULL, ARRAY[]::text[], ARRAY[]::text[], NULL,
  NULL, true, NOW()
);
