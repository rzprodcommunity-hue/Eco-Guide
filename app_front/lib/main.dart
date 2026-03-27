import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'services/api_client.dart';
import 'providers/auth_provider.dart';
import 'providers/trail_provider.dart';
import 'providers/poi_provider.dart';
import 'providers/quiz_provider.dart';
import 'providers/local_service_provider.dart';
import 'providers/weather_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

void main() {
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
      ],
      child: MaterialApp(
        title: 'Eco-Guide',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AppWrapper(),
      ),
    );
  }
}

class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

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
