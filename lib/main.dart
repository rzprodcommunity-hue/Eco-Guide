import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'services/api_client.dart';
import 'services/map_offline_service.dart';
import 'services/offline_cache_service.dart';
import 'providers/auth_provider.dart';
import 'providers/trail_provider.dart';
import 'providers/poi_provider.dart';
import 'providers/quiz_provider.dart';
import 'providers/local_service_provider.dart';
import 'providers/weather_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'core/services/offline_sos_service.dart';
import 'core/services/connectivity_service.dart';
import 'services/sos_service.dart';
import 'services/socket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize connectivity monitoring
  await ConnectivityService.instance.initialize();
  
  // Initialize offline map tile service so tiles can be resolved synchronously
  final mapOfflineService = MapOfflineService();
  await mapOfflineService.initialize();
  
  // Initialize seed data for Jebel Chitana if database is empty
  // This allows the app to work offline with realistic local data
  try {
    await OfflineCacheService.instance.initializeSeedData();
    debugPrint('✅ Seed data initialized for Jebel Chitana, Nefza, Jendouba');
  } catch (e) {
    debugPrint('❌ Failed to initialize seed data: $e');
  }
  
  runApp(EcoGuideApp(mapOfflineService: mapOfflineService));
}

class EcoGuideApp extends StatelessWidget {
  final MapOfflineService mapOfflineService;

  const EcoGuideApp({super.key, required this.mapOfflineService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Connectivity Service - monitors network status
        ChangeNotifierProvider<ConnectivityService>.value(
          value: ConnectivityService.instance,
        ),
        // API Client - base for all services
        Provider<ApiClient>(
          create: (_) => ApiClient(),
          dispose: (_, client) => client.dispose(),
        ),
        // Map offline service (pre-initialized)
        Provider<MapOfflineService>.value(value: mapOfflineService),
        // Theme Provider
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
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
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Eco-Guide',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AppWrapper(),
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
  bool? _lastKnownOfflineMode;

  @override
  void initState() {
    super.initState();
    _lastKnownOfflineMode = ConnectivityService.instance.isOfflineMode;
    ConnectivityService.instance.addListener(_onConnectivityModeChanged);

    // Start listening for network to sync offline SOS queue
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      if (!result.contains(ConnectivityResult.none) && result.isNotEmpty) {
        // Network is back, try syncing!
        if (mounted) {
          final apiClient = context.read<ApiClient>();
          OfflineSosService.syncOfflineAlerts(SosService(apiClient));
        }
      }
    });

    // Initialize real-time updates from Dashboard
    SocketService.init();

    SocketService.on('trail_updated', (data) {
      if (mounted) {
        print('📡 Real-time update: Trail ${data['action']}');
        context.read<TrailProvider>().loadTrails(refresh: true);
      }
    });

    SocketService.on('poi_updated', (data) {
      if (mounted) {
        print('📡 Real-time update: POI ${data['action']}');
        context.read<PoiProvider>().loadPois();
      }
    });

    SocketService.on('service_updated', (data) {
      if (mounted) {
        print('📡 Real-time update: Service ${data['action']}');
        context.read<LocalServiceProvider>().loadServices();
      }
    });

    SocketService.on('quiz_updated', (data) {
      if (mounted) {
        print('📡 Real-time update: Quiz ${data['action']}');
        context.read<QuizProvider>().loadCategoryStats();
        context.read<QuizProvider>().loadUserScores();
      }
    });
  }

  void _onConnectivityModeChanged() {
    if (!mounted) return;

    final currentOfflineMode = ConnectivityService.instance.isOfflineMode;
    if (_lastKnownOfflineMode == currentOfflineMode) {
      return;
    }

    _lastKnownOfflineMode = currentOfflineMode;
    debugPrint(
      'AppWrapper: connectivity mode changed -> ${currentOfflineMode ? 'OFFLINE' : 'ONLINE'}; refreshing providers',
    );

    context.read<TrailProvider>().loadTrails(refresh: true);
    context.read<PoiProvider>().loadPois();
    context.read<LocalServiceProvider>().loadServices();
  }

  @override
  void dispose() {
    ConnectivityService.instance.removeListener(_onConnectivityModeChanged);
    super.dispose();
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
              Icon(
                Icons.landscape,
                size: 80,
                color: AppTheme.primaryColor,
              ),
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
