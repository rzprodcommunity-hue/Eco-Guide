-- ============================================================
-- EcoGuide — Supabase media seed script
-- Column names are camelCase (TypeORM default)
-- "imageUrls" is text[] (PostgreSQL array), NOT jsonb
-- "additionalMediaUrls" / "videoUrls" in pois are also text[]
-- Run each section in Supabase SQL Editor
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 0. CHECK column types first (run this alone to confirm)
-- ────────────────────────────────────────────────────────────
SELECT column_name, data_type, udt_name
FROM information_schema.columns
WHERE table_name = 'trails'
  AND column_name IN ('imageUrls', 'name', 'id');

SELECT column_name, data_type, udt_name
FROM information_schema.columns
WHERE table_name = 'pois'
  AND column_name IN ('mediaUrl', 'additionalMediaUrls', 'videoUrls', 'audioGuideUrl');


-- ────────────────────────────────────────────────────────────
-- 1. PREVIEW existing data
-- ────────────────────────────────────────────────────────────
SELECT id, name, "imageUrls" FROM trails ORDER BY "createdAt";

SELECT id, name, type, "mediaUrl", "additionalMediaUrls", "videoUrls", "audioGuideUrl"
FROM pois ORDER BY "createdAt";


-- ────────────────────────────────────────────────────────────
-- 2. TRAILS — multiple images  ("imageUrls" is text[])
-- ────────────────────────────────────────────────────────────

-- Djurdjura / Chréa / mountain trails
UPDATE trails
SET "imageUrls" = ARRAY[
  'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=1200&q=80',
  'https://images.unsplash.com/photo-1551632811-561732d1e306?w=1200&q=80',
  'https://images.unsplash.com/photo-1476611338391-6f395a0dd82e?w=1200&q=80',
  'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1200&q=80'
]
WHERE name ILIKE '%djurdjura%' OR name ILIKE '%chréa%' OR name ILIKE '%chrea%';

-- Tassili / Hoggar / Sahara
UPDATE trails
SET "imageUrls" = ARRAY[
  'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=1200&q=80',
  'https://images.unsplash.com/photo-1527030280862-64139fef82b8?w=1200&q=80',
  'https://images.unsplash.com/photo-1502786129293-79981df4e689?w=1200&q=80',
  'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=1200&q=80'
]
WHERE name ILIKE '%tassili%' OR name ILIKE '%hoggar%' OR name ILIKE '%sahara%';

-- Atlas / Forest / Cedar trails
UPDATE trails
SET "imageUrls" = ARRAY[
  'https://images.unsplash.com/photo-1486870591958-9b9d0d1dda99?w=1200&q=80',
  'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=1200&q=80',
  'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=1200&q=80',
  'https://images.unsplash.com/photo-1518173946687-a4c8892bbd9f?w=1200&q=80'
]
WHERE name ILIKE '%atlas%' OR name ILIKE '%forêt%' OR name ILIKE '%foret%' OR name ILIKE '%cedre%';

-- Cascades / Gorges / Kherrata
UPDATE trails
SET "imageUrls" = ARRAY[
  'https://images.unsplash.com/photo-1542224566-6e85f2e6772f?w=1200&q=80',
  'https://images.unsplash.com/photo-1433086966358-54859d0ed716?w=1200&q=80',
  'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=1200&q=80',
  'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=1200&q=80'
]
WHERE name ILIKE '%cascade%' OR name ILIKE '%gorge%' OR name ILIKE '%kherrata%';

-- Fallback: all remaining trails with 0 or 1 image get 3 hiking images
UPDATE trails
SET "imageUrls" = ARRAY[
  'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=1200&q=80',
  'https://images.unsplash.com/photo-1476611338391-6f395a0dd82e?w=1200&q=80',
  'https://images.unsplash.com/photo-1486870591958-9b9d0d1dda99?w=1200&q=80'
]
WHERE "imageUrls" IS NULL
   OR array_length("imageUrls", 1) IS NULL
   OR array_length("imageUrls", 1) < 2;


-- ────────────────────────────────────────────────────────────
-- 3. POIS — images + videos by type  (text[] columns)
-- ────────────────────────────────────────────────────────────

-- VIEWPOINTS
UPDATE pois
SET
  "mediaUrl"            = 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=1200&q=80',
  "additionalMediaUrls" = ARRAY[
    'https://images.unsplash.com/photo-1476611338391-6f395a0dd82e?w=1200&q=80',
    'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=1200&q=80'
  ],
  "videoUrls"           = ARRAY['https://www.youtube.com/watch?v=s_wUW6oBYtA'],
  "audioGuideUrl"       = NULL
WHERE type = 'viewpoint';

-- FLORA
UPDATE pois
SET
  "mediaUrl"            = 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=1200&q=80',
  "additionalMediaUrls" = ARRAY[
    'https://images.unsplash.com/photo-1518173946687-a4c8892bbd9f?w=1200&q=80',
    'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=1200&q=80'
  ],
  "videoUrls"           = ARRAY['https://www.youtube.com/watch?v=VkTMILcmYKM'],
  "audioGuideUrl"       = NULL
WHERE type = 'flora';

-- FAUNA
UPDATE pois
SET
  "mediaUrl"            = 'https://images.unsplash.com/photo-1474511320723-9a56873867b5?w=1200&q=80',
  "additionalMediaUrls" = ARRAY[
    'https://images.unsplash.com/photo-1437622368342-7a3d73a34c8f?w=1200&q=80',
    'https://images.unsplash.com/photo-1425082661705-1834bfd09dca?w=1200&q=80'
  ],
  "videoUrls"           = ARRAY['https://www.youtube.com/watch?v=CplADxwJSm0'],
  "audioGuideUrl"       = NULL
WHERE type = 'fauna';

-- HISTORICAL
UPDATE pois
SET
  "mediaUrl"            = 'https://images.unsplash.com/photo-1548013146-72479768bada?w=1200&q=80',
  "additionalMediaUrls" = ARRAY[
    'https://images.unsplash.com/photo-1539650116574-75c0c6d73c0e?w=1200&q=80',
    'https://images.unsplash.com/photo-1578895101408-1a36b834405b?w=1200&q=80'
  ],
  "videoUrls"           = ARRAY['https://www.youtube.com/watch?v=VQsrEepKYdM'],
  "audioGuideUrl"       = NULL
WHERE type = 'historical';

-- WATER / CASCADES
UPDATE pois
SET
  "mediaUrl"            = 'https://images.unsplash.com/photo-1542224566-6e85f2e6772f?w=1200&q=80',
  "additionalMediaUrls" = ARRAY[
    'https://images.unsplash.com/photo-1433086966358-54859d0ed716?w=1200&q=80',
    'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=1200&q=80'
  ],
  "videoUrls"           = ARRAY['https://www.youtube.com/watch?v=gKPMZ3GQi9c'],
  "audioGuideUrl"       = NULL
WHERE type = 'water';

-- CAMPING
UPDATE pois
SET
  "mediaUrl"            = 'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=1200&q=80',
  "additionalMediaUrls" = ARRAY[
    'https://images.unsplash.com/photo-1487730116645-74489c95b41b?w=1200&q=80',
    'https://images.unsplash.com/photo-1508193638397-1c4234db14d8?w=1200&q=80'
  ],
  "videoUrls"           = NULL,
  "audioGuideUrl"       = NULL
WHERE type = 'camping';

-- REST AREA
UPDATE pois
SET
  "mediaUrl"            = 'https://images.unsplash.com/photo-1531366936337-7c912a4589a7?w=1200&q=80',
  "additionalMediaUrls" = ARRAY[
    'https://images.unsplash.com/photo-1551632811-561732d1e306?w=1200&q=80'
  ],
  "videoUrls"           = NULL,
  "audioGuideUrl"       = NULL
WHERE type = 'rest_area';

-- DANGER
UPDATE pois
SET
  "mediaUrl"            = 'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=1200&q=80',
  "additionalMediaUrls" = ARRAY[
    'https://images.unsplash.com/photo-1478719059408-592965723cbc?w=1200&q=80'
  ],
  "videoUrls"           = NULL,
  "audioGuideUrl"       = NULL
WHERE type = 'danger';

-- INFORMATION
UPDATE pois
SET
  "mediaUrl"            = 'https://images.unsplash.com/photo-1476611338391-6f395a0dd82e?w=1200&q=80',
  "additionalMediaUrls" = ARRAY[
    'https://images.unsplash.com/photo-1501854140801-50d01698950b?w=1200&q=80'
  ],
  "videoUrls"           = NULL,
  "audioGuideUrl"       = NULL
WHERE type = 'information';

-- Fallback: any POI still missing a main image
UPDATE pois
SET "mediaUrl" = 'https://images.unsplash.com/photo-1486870591958-9b9d0d1dda99?w=1200&q=80'
WHERE "mediaUrl" IS NULL OR "mediaUrl" = '';


-- ────────────────────────────────────────────────────────────
-- 4. VOICE-OVER — add MP3 audio guides to specific POIs
-- Upload your MP3 files to Supabase Storage bucket "audio"
-- then replace the URL pattern below
-- ────────────────────────────────────────────────────────────

-- Example (uncomment and edit):
-- UPDATE pois
-- SET "audioGuideUrl" = 'https://YOUR_PROJECT.supabase.co/storage/v1/object/public/audio/viewpoint-fr.mp3'
-- WHERE type = 'viewpoint';

-- UPDATE pois
-- SET "audioGuideUrl" = 'https://YOUR_PROJECT.supabase.co/storage/v1/object/public/audio/cedres-fr.mp3'
-- WHERE name ILIKE '%cèdres%' OR name ILIKE '%cedres%';


-- ────────────────────────────────────────────────────────────
-- 5. VERIFY results
-- ────────────────────────────────────────────────────────────
SELECT
  name,
  array_length("imageUrls", 1) AS num_images
FROM trails
ORDER BY name;

SELECT
  name,
  type,
  CASE WHEN "mediaUrl" IS NOT NULL THEN '✓' ELSE '✗' END          AS has_image,
  COALESCE(array_length("additionalMediaUrls", 1), 0)              AS extra_images,
  COALESCE(array_length("videoUrls", 1), 0)                        AS videos,
  CASE WHEN "audioGuideUrl" IS NOT NULL THEN '✓' ELSE '✗' END      AS has_audio
FROM pois
ORDER BY type, name;
