import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/services/offline_sos_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/map_offline_service.dart';
import '../../core/widgets/eco_page_header.dart';
import '../../core/widgets/eco_shortcut_badge.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/sos_service.dart';
import '../home/home_screen.dart';

class SosButton extends StatelessWidget {
  const SosButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'sosButton',
      backgroundColor: AppTheme.sosColor,
      onPressed: () => _showSosScreen(context),
      child: const Icon(Icons.sos, color: Colors.white, size: 28),
    );
  }

  void _showSosScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SosScreen(),
        fullscreenDialog: true,
      ),
    );
  }
}

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isSending = false;
  LatLng _currentPosition = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );
  double _altitude = 0.0;
  double _accuracy = 0.0;
  bool _hasGoodSignal = false;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _detectUserPosition();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _detectUserPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Services de localisation désactivés. Activez-les pour obtenir votre position exacte.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission de localisation refusée. Autorisez l\'accès à la localisation.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Get high accuracy position with timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _altitude = position.altitude;
        _accuracy = position.accuracy;
        _hasGoodSignal = position.accuracy < 20;
        _isLoadingLocation = false;
      });

      // Listen to position updates for continuous tracking
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5, // Update every 5 meters
        ),
      ).listen((Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
            _altitude = position.altitude;
            _accuracy = position.accuracy;
            _hasGoodSignal = position.accuracy < 20;
          });
        }
      });
    } catch (e) {
      debugPrint('Error getting position: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de localisation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmAndTriggerSos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.sosColor, size: 28),
            SizedBox(width: 12),
            Text('Confirmer l\'alerte SOS'),
          ],
        ),
        content: const Text(
          'Voulez-vous vraiment envoyer une alerte SOS d\'urgence ?\n\n'
          'Les secours seront notifiés de votre position actuelle.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.sosColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(context);
              _triggerSos();
            },
            child: const Text('Envoyer SOS', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerSos() async {
    if (_isLoadingLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attente de la localisation précise...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    // L'envoi d'Alerte SOS est maintenant public, pas besoin d'être authentifié.

    try {
      final apiClient = context.read<ApiClient>();
      final sosService = SosService(apiClient);

      // Check Network Connectivity First
      final connectivityResult = await (Connectivity().checkConnectivity());
      final isOffline = connectivityResult.contains(ConnectivityResult.none) || connectivityResult.isEmpty;

      if (isOffline) {
        // Save to offline queue
        await OfflineSosService.saveOfflineAlert(
          _currentPosition.latitude,
          _currentPosition.longitude,
          'Alerte SOS declenchee depuis l\'application',
        );

        if (mounted) {
          setState(() => _isSending = false);
          _showOfflineEmergencyDialog();
        }
        return;
      }

      await sosService.sendAlert(
        latitude: _currentPosition.latitude,
        longitude: _currentPosition.longitude,
        message: 'Alerte SOS declenchee depuis l\'application',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Alerte SOS envoyee avec succes!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted && _isSending) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showOfflineEmergencyDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.signal_cellular_connected_no_internet_4_bar, color: AppTheme.errorColor),
            SizedBox(width: 8),
            Text('Aucun Réseau Détecté', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'L\'alerte a été sauvegardée. Elle sera transmise au Dashboard automatiquement dès qu\'un signal sera retrouvé.\n\n'
          'En attendant, vous pouvez :\n'
          '1. Envoyer vos coordonnées par SMS (GSM).\n'
          '2. Utiliser le mode Satellite natif d\'iOS (si disponible).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.sms, size: 18),
            label: const Text('SMS d\'Urgence'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final link = 'sms:112?body=${Uri.encodeComponent("URGENCE ECO-GUIDE - Je suis à la position GPS : ${_currentPosition.latitude}, ${_currentPosition.longitude}. Envoyez des secours.")}';
              final uri = Uri.parse(link);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _callNumber(String number) async {
    final sanitizedNumber = number.replaceAll(RegExp(r'\s+'), '');
    final dialUris = <Uri>[
      Uri(scheme: 'tel', path: sanitizedNumber),
      Uri.parse('tel://$sanitizedNumber'),
    ];

    var opened = false;

    for (final uri in dialUris) {
      try {
        opened = await launchUrl(uri);
        if (opened) {
          break;
        }
      } catch (_) {
        // Try next URI format.
      }
    }

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'ouvrir le clavier avec le $number'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const EcoPageHeader(title: 'Urgence SOS'),
      bottomNavigationBar: EcoShortcutBadge(
        currentTab: EcoShortcutTab.home,
        onTabSelected: (tab) {
          final index = switch (tab) {
            EcoShortcutTab.home => 0,
            EcoShortcutTab.map => 1,
            EcoShortcutTab.trails => 2,
            EcoShortcutTab.quiz => 4,
            EcoShortcutTab.services => 6,
            EcoShortcutTab.settings => 7,
          };
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => HomeScreen(initialIndex: index)),
            (route) => false,
          );
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSosButton(),
            const SizedBox(height: 24),
            _buildGpsCard(),
            const SizedBox(height: 24),
            _buildEmergencyContacts(),
            const SizedBox(height: 24),
            _buildSafetyTips(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSosButton() {
    return Container(
      padding: const EdgeInsets.all(50),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pulsing SOS Button
          GestureDetector(
            onTap: _isSending ? null : _confirmAndTriggerSos,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulse rings
                    if (!_isSending) ...[
                      Transform.scale(
                        scale: _pulseAnimation.value * 1.3,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.sosColor.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: _pulseAnimation.value * 1.15,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.sosColor.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                    ],
                    // Main button
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isSending ? Colors.grey : AppTheme.sosColor,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.sosColor.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _isSending
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sos,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 30),
          Text(
            _isSending
                ? 'Envoi de l\'alerte en cours...'
                : (_isLoadingLocation
                    ? 'Détection de votre position exacte...'
                    : 'Appuyez pour envoyer une alerte SOS'),
            style: TextStyle(
              color: _isSending ? Colors.orange : Colors.grey[600],
              fontSize: 14,
              fontWeight: _isSending ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsCard() {
    final latDegrees = _currentPosition.latitude.abs();
    final latDirection = _currentPosition.latitude >= 0 ? 'N' : 'S';
    final lngDegrees = _currentPosition.longitude.abs();
    final lngDirection = _currentPosition.longitude >= 0 ? 'E' : 'W';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Votre Position GPS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _hasGoodSignal
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.signal_cellular_alt,
                        size: 14,
                        color: _hasGoodSignal ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _hasGoodSignal ? 'Signal Fort' : 'Signal Faible',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _hasGoodSignal ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Mini Map
          Container(
            height: 120,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: _currentPosition,
                      initialZoom: 14,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.ecoguide.app',
                        tileProvider: LocalFirstTileProvider(),
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentPosition,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.sosColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.sosColor
                                        .withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Coordinates overlay
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${latDegrees.toStringAsFixed(4)}° $latDirection, ${lngDegrees.toStringAsFixed(4)}° $lngDirection',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Map data from OpenStreetMap',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[400],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Altitude and Precision
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    Icons.height,
                    'Altitude',
                    '${_altitude.toStringAsFixed(0)} m',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoChip(
                    Icons.gps_fixed,
                    'Precision',
                    '+/- ${_accuracy.toStringAsFixed(0)} m',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContacts() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Contacts d\'urgence',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          _buildContactItem(
            icon: Icons.local_hospital,
            iconColor: Colors.red,
            title: 'Secours en Montagne',
            subtitle: 'PGHM - Intervention rapide',
            number: '112',
          ),
          Divider(height: 1, color: Colors.grey[100]),
          _buildContactItem(
            icon: Icons.shield,
            iconColor: Colors.green,
            title: 'Poste des Gardes',
            subtitle: 'Parc National Eco-Guide',
            number: '112',
          ),
          Divider(height: 1, color: Colors.grey[100]),
          _buildContactItem(
            icon: Icons.person,
            iconColor: Colors.blue,
            title: 'Guide Referent',
            subtitle: 'Votre expedition',
            number: '112',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String number,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, isLast ? 16 : 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _callNumber(number),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.phone,
                color: Colors.green,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.sosColor.withValues(alpha: 0.9),
            AppTheme.sosColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'En attendant les secours',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Restez visible, couvrez-vous pour eviter l\'hypothermie et ne quittez pas votre position actuelle.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
