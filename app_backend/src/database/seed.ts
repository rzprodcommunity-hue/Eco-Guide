import { DataSource } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { config } from 'dotenv';

config();

const AppDataSource = new DataSource({
  type: 'postgres',
  host: process.env.DATABASE_HOST || 'localhost',
  port: parseInt(process.env.DATABASE_PORT || '5432'),
  username: process.env.DATABASE_USER || 'postgres',
  password: process.env.DATABASE_PASSWORD || 'postgres',
  database: process.env.DATABASE_NAME || 'ecoguide',
  synchronize: true,
  entities: ['src/**/*.entity.ts'],
});

async function seed() {
  console.log('🌱 Starting database seed...');

  await AppDataSource.initialize();
  console.log('✅ Database connected');

  // Create tables if not exist
  await AppDataSource.synchronize();

  // Seed Users
  console.log('👤 Seeding users...');
  const hashedPassword = await bcrypt.hash('password123', 10);

  await AppDataSource.query(`
    INSERT INTO users (id, email, password, role, "firstName", "lastName", "isActive", "createdAt", "updatedAt")
    VALUES
      ('11111111-1111-1111-1111-111111111111', 'admin@ecoguide.ma', '${hashedPassword}', 'admin', 'Admin', 'User', true, NOW(), NOW()),
      ('22222222-2222-2222-2222-222222222222', 'user@ecoguide.ma', '${hashedPassword}', 'user', 'Test', 'User', true, NOW(), NOW()),
      ('33333333-3333-3333-3333-333333333333', 'hiker@ecoguide.ma', '${hashedPassword}', 'user', 'Hiker', 'Explorer', true, NOW(), NOW())
    ON CONFLICT (email) DO NOTHING;
  `);

  // Seed Trails
  console.log('🥾 Seeding trails...');
  await AppDataSource.query(`
    INSERT INTO trails (id, name, description, distance, difficulty, "estimatedDuration", "elevationGain", "imageUrls", region, "startLatitude", "startLongitude", "isActive", "createdAt", "updatedAt")
    VALUES
      ('aaaa1111-1111-1111-1111-111111111111',
       'Toubkal Summit Trail',
       'The iconic trek to North Africa''s highest peak at 4,167m. This challenging trail offers breathtaking views of the Atlas Mountains and tests your endurance with its steep ascents. Best attempted between April and October.',
       22.5, 'difficult', 720, 1900,
       '{"https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800","https://images.unsplash.com/photo-1486870591958-9b9d0d1dda99?w=800"}',
       'High Atlas', 31.0599, -7.9154, true, NOW(), NOW()),

      ('aaaa2222-2222-2222-2222-222222222222',
       'Ouzoud Waterfalls Trail',
       'A scenic walk through olive groves leading to Morocco''s most spectacular waterfalls. The 110m cascades are surrounded by lush vegetation and playful Barbary macaques. Perfect for families and photography enthusiasts.',
       8.0, 'easy', 180, 250,
       '{"https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=800","https://images.unsplash.com/photo-1546182990-dffeafbe841d?w=800"}',
       'Middle Atlas', 32.0154, -6.7172, true, NOW(), NOW()),

      ('aaaa3333-3333-3333-3333-333333333333',
       'Paradise Valley Hike',
       'Discover hidden pools and palm oases in this stunning canyon near Agadir. The trail winds through rocky terrain and natural swimming spots, offering a refreshing escape from the coastal heat.',
       12.0, 'moderate', 300, 450,
       '{"https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=800"}',
       'Souss-Massa', 30.5234, -9.2345, true, NOW(), NOW()),

      ('aaaa4444-4444-4444-4444-444444444444',
       'Akchour Waterfalls & God''s Bridge',
       'Explore the pristine Talassemtane National Park with its dramatic waterfalls and natural rock bridge. This trail in the Rif Mountains showcases some of Morocco''s most untouched wilderness.',
       15.0, 'moderate', 360, 600,
       '{"https://images.unsplash.com/photo-1433086966358-54859d0ed716?w=800","https://images.unsplash.com/photo-1475070929565-c985b496cb9f?w=800"}',
       'Rif Mountains', 35.2456, -5.1234, true, NOW(), NOW()),

      ('aaaa5555-5555-5555-5555-555555555555',
       'Imlil Valley Circuit',
       'A beautiful day hike through traditional Berber villages in the foothills of Toubkal. Experience authentic mountain culture, terraced fields, and stunning views without the extreme altitude.',
       10.0, 'easy', 240, 350,
       '{"https://images.unsplash.com/photo-1464278533981-50106e6176b1?w=800"}',
       'High Atlas', 31.1378, -7.9195, true, NOW(), NOW()),

      ('aaaa6666-6666-6666-6666-666666666666',
       'Sfax Hay Ons Urban Eco Walk',
       'Urban eco walk in Sfax Hay Ons combining neighborhood streets, small green pockets, and local points of interest. Designed for short daily walks and lightweight orientation training.',
       4.2, 'easy', 70, 25,
       '{"https://images.unsplash.com/photo-1469474968028-56623f02e42e?w=800"}',
       'Sfax - Hay Ons', 34.7487, 10.7698, true, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;
  `);

  // Seed POIs
  console.log('📍 Seeding POIs...');
  await AppDataSource.query(`
    INSERT INTO pois (id, name, type, description, latitude, longitude, "mediaUrl", "trailId", "isActive", "createdAt", "updatedAt")
    VALUES
      ('bbbb1111-1111-1111-1111-111111111111',
       'Toubkal Refuge',
       'rest_area',
       'Mountain refuge at 3,207m offering basic accommodation and meals. Essential stop for summit attempts. Book in advance during peak season.',
       31.0612, -7.9089,
       'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800',
       'aaaa1111-1111-1111-1111-111111111111', true, NOW(), NOW()),

      ('bbbb2222-2222-2222-2222-222222222222',
       'Atlas Cedar Forest',
       'flora',
       'Ancient cedar forest home to some of Morocco''s oldest trees, some over 800 years old. These majestic trees can reach heights of 40m.',
       31.0534, -7.9234,
       'https://images.unsplash.com/photo-1542273917363-3b1817f69a2d?w=800',
       'aaaa1111-1111-1111-1111-111111111111', true, NOW(), NOW()),

      ('bbbb3333-3333-3333-3333-333333333333',
       'Barbary Macaque Habitat',
       'fauna',
       'Home to endangered Barbary macaques. Observe these playful primates in their natural habitat. Please do not feed them.',
       32.0167, -6.7189,
       'https://images.unsplash.com/photo-1540573133985-87b6da6d54a9?w=800',
       'aaaa2222-2222-2222-2222-222222222222', true, NOW(), NOW()),

      ('bbbb4444-4444-4444-4444-444444444444',
       'Ouzoud Main Viewpoint',
       'viewpoint',
       'The best vantage point to photograph the full height of the 110m waterfalls. Rainbow visible on sunny mornings.',
       32.0145, -6.7156,
       'https://images.unsplash.com/photo-1432405972618-c60b0225b8f9?w=800',
       'aaaa2222-2222-2222-2222-222222222222', true, NOW(), NOW()),

      ('bbbb5555-5555-5555-5555-555555555555',
       'Natural Swimming Pool',
       'water',
       'Crystal clear natural pool perfect for swimming. Water temperature varies seasonally. Bring water shoes for rocky bottom.',
       30.5256, -9.2367,
       'https://images.unsplash.com/photo-1501785888041-af3ef285b470?w=800',
       'aaaa3333-3333-3333-3333-333333333333', true, NOW(), NOW()),

      ('bbbb6666-6666-6666-6666-666666666666',
       'God''s Bridge (Pont de Dieu)',
       'historical',
       'Spectacular natural rock arch spanning 25m across the river gorge. A geological wonder formed over millions of years.',
       35.2478, -5.1256,
       'https://images.unsplash.com/photo-1475070929565-c985b496cb9f?w=800',
       'aaaa4444-4444-4444-4444-444444444444', true, NOW(), NOW()),

      ('bbbb7777-7777-7777-7777-777777777777',
       'Armed Village',
       'information',
       'Traditional Berber village with distinctive architecture. Local guides available. Respectful photography only with permission.',
       31.1389, -7.9201,
       'https://images.unsplash.com/photo-1464278533981-50106e6176b1?w=800',
       'aaaa5555-5555-5555-5555-555555555555', true, NOW(), NOW()),

      ('bbbb8888-8888-8888-8888-888888888888',
       'Steep Descent Warning',
       'danger',
       'Caution: Very steep section ahead with loose rocks. Use trekking poles recommended. Not suitable after rain.',
       31.0578, -7.9123,
       NULL,
       'aaaa1111-1111-1111-1111-111111111111', true, NOW(), NOW()),

      ('bbbb9991-9991-9991-9991-999999999991',
       'Hay Ons Neighborhood Plaza',
       'viewpoint',
       'Central plaza in Hay Ons used as a local orientation point and meetup area for short walking routes.',
       34.7489, 10.7701,
       NULL,
       'aaaa6666-6666-6666-6666-666666666666', true, NOW(), NOW()),

      ('bbbb9992-9992-9992-9992-999999999992',
       'Eco Information Board',
       'information',
       'Community information point sharing environmental awareness tips and walking guidance in the district.',
       34.7497, 10.7689,
       NULL,
       'aaaa6666-6666-6666-6666-666666666666', true, NOW(), NOW()),

      ('bbbb9993-9993-9993-9993-999999999993',
       'Hay Ons Pocket Garden',
       'flora',
       'Small urban garden with drought-resistant Mediterranean plants and shade trees.',
       34.7478, 10.7712,
       NULL,
       'aaaa6666-6666-6666-6666-666666666666', true, NOW(), NOW()),

      ('bbbb9994-9994-9994-9994-999999999994',
       'Street Crossing Alert - Hay Ons',
       'danger',
       'Busy road crossing section. Slow down, look both ways, and use marked pedestrian crossing when available.',
       34.7482, 10.7681,
       NULL,
       'aaaa6666-6666-6666-6666-666666666666', true, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;
  `);

  // Seed Quizzes
  console.log('❓ Seeding quizzes...');
  await AppDataSource.query(`
    INSERT INTO quizzes (id, question, answers, "correctAnswerIndex", explanation, category, "trailId", "poiId", points, "isActive", "createdAt")
    VALUES
      ('cccc1111-1111-1111-1111-111111111111',
       'What is the height of Mount Toubkal?',
       '["3,167m", "4,167m", "5,167m", "2,167m"]',
       1,
       'Mount Toubkal stands at 4,167 meters, making it the highest peak in North Africa and the Arab world.',
       'geography',
       'aaaa1111-1111-1111-1111-111111111111',
       NULL, 10, true, NOW()),

      ('cccc2222-2222-2222-2222-222222222222',
       'What species of monkey lives in the Atlas Mountains?',
       '["Chimpanzee", "Barbary Macaque", "Mandrill", "Spider Monkey"]',
       1,
       'The Barbary Macaque is the only wild monkey species in Africa north of the Sahara and the only primate besides humans native to Europe.',
       'fauna',
       'aaaa2222-2222-2222-2222-222222222222',
       'bbbb3333-3333-3333-3333-333333333333', 10, true, NOW()),

      ('cccc3333-3333-3333-3333-333333333333',
       'How old can Atlas Cedar trees grow to be?',
       '["100 years", "300 years", "800+ years", "50 years"]',
       2,
       'Some Atlas Cedar trees in Morocco are estimated to be over 800 years old, making them among the oldest living organisms in the region.',
       'flora',
       'aaaa1111-1111-1111-1111-111111111111',
       'bbbb2222-2222-2222-2222-222222222222', 15, true, NOW()),

      ('cccc4444-4444-4444-4444-444444444444',
       'What is the approximate height of Ouzoud Waterfalls?',
       '["50 meters", "80 meters", "110 meters", "150 meters"]',
       2,
       'Ouzoud Waterfalls cascade approximately 110 meters, making them the highest waterfalls in Morocco.',
       'geography',
       'aaaa2222-2222-2222-2222-222222222222',
       'bbbb4444-4444-4444-4444-444444444444', 10, true, NOW()),

      ('cccc5555-5555-5555-5555-555555555555',
       'What should you do if you encounter a Barbary Macaque on the trail?',
       '["Feed it fruit", "Run away quickly", "Maintain distance and avoid direct eye contact", "Try to pet it"]',
       2,
       'Barbary Macaques should be observed from a safe distance. Feeding them disrupts their natural behavior and can make them aggressive.',
       'safety',
       NULL,
       'bbbb3333-3333-3333-3333-333333333333', 20, true, NOW()),

      ('cccc6666-6666-6666-6666-666666666666',
       'What is the traditional name for Berber mountain villages?',
       '["Medina", "Kasbah", "Douar", "Riad"]',
       2,
       'A Douar is a traditional Berber village, typically consisting of a cluster of houses built into the mountainside.',
       'history',
       'aaaa5555-5555-5555-5555-555555555555',
       'bbbb7777-7777-7777-7777-777777777777', 10, true, NOW()),

      ('cccc7777-7777-7777-7777-777777777777',
       'What is the best time of year to attempt the Toubkal summit?',
       '["December-February", "April-October", "Year-round", "Only August"]',
       1,
       'The best months are April to October when snow levels are lower and weather is more stable. Winter attempts require technical mountaineering skills.',
       'safety',
       'aaaa1111-1111-1111-1111-111111111111',
       NULL, 15, true, NOW()),

      ('cccc8888-8888-8888-8888-888888888888',
       'What ecosystem type is found in the Talassemtane National Park?',
       '["Desert", "Mediterranean Forest", "Tropical Rainforest", "Savanna"]',
       1,
       'Talassemtane features a Mediterranean forest ecosystem with fir and cedar trees, unique to the Rif Mountains region.',
       'ecology',
       'aaaa4444-4444-4444-4444-444444444444',
       NULL, 10, true, NOW())
    ON CONFLICT (id) DO NOTHING;
  `);

  // Seed Local Services
  console.log('🏪 Seeding local services...');
  await AppDataSource.query(`
    INSERT INTO local_services (id, name, category, description, contact, email, website, address, latitude, longitude, "imageUrl", languages, rating, "reviewCount", "isActive", "isVerified", "createdAt", "updatedAt")
    VALUES
      ('dddd1111-1111-1111-1111-111111111111',
       'Ahmed Mountain Guide',
       'guide',
       'Certified mountain guide with 15 years of experience in the High Atlas. Specializes in Toubkal treks and multi-day expeditions. First aid certified.',
       '+212 661 234567',
       'ahmed.guide@gmail.com',
       NULL,
       'Imlil Village, High Atlas',
       31.1378, -7.9195,
       'https://images.unsplash.com/photo-1551632811-561732d1e306?w=800',
       '{Arabic,French,English,Spanish}',
       4.9, 127, true, true, NOW(), NOW()),

      ('dddd2222-2222-2222-2222-222222222222',
       'Riad Atlas Toubkal',
       'accommodation',
       'Traditional mountain lodge at the base of Toubkal. Comfortable rooms, home-cooked meals, and stunning terrace views. Perfect base for trekking.',
       '+212 524 485611',
       'info@riadatlastoubkal.com',
       'https://riadatlastoubkal.com',
       'Imlil, High Atlas Mountains',
       31.1356, -7.9178,
       'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800',
       '{Arabic,French,English}',
       4.7, 89, true, true, NOW(), NOW()),

      ('dddd3333-3333-3333-3333-333333333333',
       'Berber Treasures Artisan Shop',
       'artisan',
       'Family-run shop selling authentic Berber handicrafts: carpets, jewelry, pottery, and traditional clothing. Fair trade certified.',
       '+212 662 345678',
       NULL,
       NULL,
       'Main Square, Imlil',
       31.1367, -7.9189,
       'https://images.unsplash.com/photo-1590736969955-71cc94901144?w=800',
       '{Arabic,French,English}',
       4.6, 45, true, true, NOW(), NOW()),

      ('dddd4444-4444-4444-4444-444444444444',
       'Café Panorama Ouzoud',
       'restaurant',
       'Terrace restaurant with spectacular waterfall views. Serves traditional tagines, fresh salads, and mint tea. Vegetarian options available.',
       '+212 523 456789',
       NULL,
       NULL,
       'Ouzoud Waterfalls Viewpoint',
       32.0148, -6.7162,
       'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800',
       '{Arabic,French}',
       4.4, 156, true, true, NOW(), NOW()),

      ('dddd5555-5555-5555-5555-555555555555',
       'Atlas Trekking Equipment',
       'equipment',
       'Rental and sales of hiking gear: boots, poles, backpacks, sleeping bags, and cold weather clothing. Daily and weekly rentals available.',
       '+212 664 567890',
       'atlastrek.equip@gmail.com',
       NULL,
       'Marrakech Road, Asni',
       31.2489, -7.9856,
       'https://images.unsplash.com/photo-1551632811-561732d1e306?w=800',
       '{Arabic,French,English}',
       4.5, 67, true, true, NOW(), NOW()),

      ('dddd6666-6666-6666-6666-666666666666',
       'Hassan 4x4 Transport',
       'transport',
       'Reliable 4x4 transfers from Marrakech to all Atlas trailheads. Airport pickups available. Comfortable vehicles with experienced drivers.',
       '+212 665 678901',
       'hassan.transport@gmail.com',
       NULL,
       'Marrakech',
       31.6295, -7.9811,
       'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?w=800',
       '{Arabic,French,English}',
       4.8, 203, true, true, NOW(), NOW()),

      ('dddd7777-7777-7777-7777-777777777777',
       'Hay Ons Community First Aid Point',
        'guide',
       'Local first-aid support point for minor incidents during urban walks and neighborhood activities.',
       '+216 74 200 100',
       NULL,
       NULL,
       'Hay Ons, Sfax',
       34.7492, 10.7690,
       NULL,
       '{Arabic,French}',
       4.5, 22, true, true, NOW(), NOW()),

      ('dddd8888-8888-8888-8888-888888888888',
       'Hay Ons Local Bike & Repair',
       'equipment',
       'Neighborhood bike rental and quick repair service useful for soft mobility exploration in Sfax.',
       '+216 74 200 220',
       NULL,
       NULL,
       'Avenue principale, Hay Ons, Sfax',
       34.7476, 10.7708,
       NULL,
       '{Arabic,French}',
       4.4, 17, true, true, NOW(), NOW())
    ON CONFLICT (id) DO NOTHING;
  `);

  // Seed some activities for the test user
  console.log('📊 Seeding activities...');
  await AppDataSource.query(`
    INSERT INTO activities (id, "userId", type, "trailId", "poiId", metadata, "createdAt")
    VALUES
      ('eeee1111-1111-1111-1111-111111111111',
       '22222222-2222-2222-2222-222222222222',
       'trail_started',
       'aaaa2222-2222-2222-2222-222222222222',
       NULL,
       '{"startTime": "2024-01-15T09:00:00Z"}',
       '2024-01-15T09:00:00Z'),

      ('eeee2222-2222-2222-2222-222222222222',
       '22222222-2222-2222-2222-222222222222',
       'poi_visited',
       'aaaa2222-2222-2222-2222-222222222222',
       'bbbb3333-3333-3333-3333-333333333333',
       NULL,
       '2024-01-15T10:30:00Z'),

      ('eeee3333-3333-3333-3333-333333333333',
       '22222222-2222-2222-2222-222222222222',
       'quiz_answered',
       'aaaa2222-2222-2222-2222-222222222222',
       'bbbb3333-3333-3333-3333-333333333333',
       '{"quizId": "cccc2222-2222-2222-2222-222222222222", "correct": true, "score": 10}',
       '2024-01-15T10:35:00Z'),

      ('eeee4444-4444-4444-4444-444444444444',
       '22222222-2222-2222-2222-222222222222',
       'trail_completed',
       'aaaa2222-2222-2222-2222-222222222222',
       NULL,
       '{"duration": 10800, "distance": 8.0}',
       '2024-01-15T12:00:00Z')
    ON CONFLICT (id) DO NOTHING;
  `);

  console.log('✅ Database seeded successfully!');
  console.log('');
  console.log('📋 Test Accounts:');
  console.log('   Admin: admin@ecoguide.ma / password123');
  console.log('   User:  user@ecoguide.ma / password123');
  console.log('   User:  hiker@ecoguide.ma / password123');
  console.log('');
  console.log('📊 Seeded Data:');
  console.log('   - 3 Users (1 admin, 2 regular users)');
  console.log('   - 6 Trails');
  console.log('   - 12 Points of Interest');
  console.log('   - 8 Quizzes');
  console.log('   - 8 Local Services');
  console.log('   - 4 Sample Activities');

  await AppDataSource.destroy();
}

seed().catch((error) => {
  console.error('❌ Seed failed:', error);
  process.exit(1);
});
