import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/network_service.dart';
import 'core/theme/app_theme.dart';
import 'services/api_client.dart';
import 'services/map_offline_service.dart';
import 'providers/auth_provider.dart';
import 'providers/trail_provider.dart';
import 'providers/poi_provider.dart';
import 'providers/quiz_provider.dart';
import 'providers/local_service_provider.dart';
import 'providers/weather_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/favorites_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'core/services/offline_sos_service.dart';
import 'services/sos_service.dart';
import 'services/socket_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
  runApp(const EcoGuideApp());
}

class EcoGuideApp extends StatelessWidget {
  const EcoGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // API Client - base for all services
        Provider<ApiClient>(
          create: (_) => ApiClient(),
          dispose: (_, client) => client.dispose(),
        ),
        // Auth Provider
        ChangeNotifierProxyProvider<ApiClient, AuthProvider>(
          create: (context) => AuthProvider(context.read<ApiClient>()),
          update: (_, apiClient, previous) =>
              previous ?? AuthProvider(apiClient),
        ),
        // Trail Provider
        ChangeNotifierProxyProvider<ApiClient, TrailProvider>(
          create: (context) => TrailProvider(context.read<ApiClient>()),
          update: (_, apiClient, previous) =>
              previous ?? TrailProvider(apiClient),
        ),
        // POI Provider
        ChangeNotifierProxyProvider<ApiClient, PoiProvider>(
          create: (context) => PoiProvider(context.read<ApiClient>()),
          update: (_, apiClient, previous) =>
              previous ?? PoiProvider(apiClient),
        ),
        // Quiz Provider
        ChangeNotifierProxyProvider<ApiClient, QuizProvider>(
          create: (context) => QuizProvider(context.read<ApiClient>()),
          update: (_, apiClient, previous) =>
              previous ?? QuizProvider(apiClient),
        ),
        // Local Service Provider
        ChangeNotifierProxyProvider<ApiClient, LocalServiceProvider>(
          create: (context) => LocalServiceProvider(context.read<ApiClient>()),
          update: (_, apiClient, previous) =>
              previous ?? LocalServiceProvider(apiClient),
        ),
        // Weather Provider
        ChangeNotifierProxyProvider<ApiClient, WeatherProvider>(
          create: (context) => WeatherProvider(context.read<ApiClient>()),
          update: (_, apiClient, previous) =>
              previous ?? WeatherProvider(apiClient),
        ),
        // Theme Provider
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        // Locale Provider
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        // Favorites Provider
        ChangeNotifierProvider<FavoritesProvider>(
          create: (_) => FavoritesProvider(),
        ),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, child) {
          return MaterialApp(
            title: 'EcoGuide',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: localeProvider.locale,
            supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  Future<void> _refreshRealtimeData() async {
    final isOnline = await NetworkService.hasInternetConnection();
    if (!mounted) return;

    await Future.wait([
      context.read<TrailProvider>().loadTrails(
        refresh: true,
        forceOffline: !isOnline,
      ),
      context.read<PoiProvider>().loadPois(forceOffline: !isOnline),
      context.read<LocalServiceProvider>().loadServices(
        forceOffline: !isOnline,
      ),
    ]);
  }

  @override
  void initState() {
    super.initState();
    MapOfflineService().initialize();
    // Start listening for network to sync offline SOS queue
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      if (!result.contains(ConnectivityResult.none) && result.isNotEmpty) {
        // Network is back, try syncing!
        if (mounted) {
          final apiClient = context.read<ApiClient>();
          OfflineSosService.syncOfflineAlerts(SosService(apiClient));
        }
      }
    });

    // Initialize real-time updates from Dashboard
    try {
      SocketService.init();

      SocketService.on('trail_updated', (data) {
        if (mounted) {
          print('📡 Real-time update: Trail ${data['action']}');
          _refreshRealtimeData();
        }
      });

      SocketService.on('poi_updated', (data) {
        if (mounted) {
          print('📡 Real-time update: POI ${data['action']}');
          _refreshRealtimeData();
        }
      });

      SocketService.on('service_updated', (data) {
        if (mounted) {
          print('📡 Real-time update: Service ${data['action']}');
          _refreshRealtimeData();
        }
      });

      SocketService.on('quiz_updated', (data) {
        if (mounted) {
          print('📡 Real-time update: Quiz ${data['action']}');
          context.read<QuizProvider>().loadCategoryStats();
          context.read<QuizProvider>().loadUserScores();
        }
      });
    } catch (_) {
      // Widget tests can boot the app without initializing Supabase first.
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Show loading while checking stored auth
    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.landscape, size: 80, color: AppTheme.primaryColor),
              SizedBox(height: 24),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Chargement...'),
            ],
          ),
        ),
      );
    }

    // Navigate based on auth state
    return authProvider.isAuthenticated
        ? const HomeScreen()
        : const LoginScreen();
  }
}
