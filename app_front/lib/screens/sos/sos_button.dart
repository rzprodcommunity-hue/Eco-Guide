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
import '../../services/api_client.dart';
import '../../services/sos_service.dart';

class SosButton extends StatelessWidget {
  const SosButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'sosButton',
      backgroundColor: const Color(0xFFC83226),
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
  bool _isHolding = false;
  bool _isSending = false;
  double _holdProgress = 0.0;
  LatLng _currentPosition = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );
  double _altitude = 0.0;
  double _accuracy = 0.0;
  bool _hasGoodSignal = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
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
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _altitude = position.altitude;
        _accuracy = position.accuracy;
        _hasGoodSignal = position.accuracy < 20;
      });
    } catch (e) {
      debugPrint('Error getting position: $e');
    }
  }

  void _startHolding() {
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });
    _incrementHoldProgress();
  }

  void _incrementHoldProgress() async {
    while (_isHolding && _holdProgress < 1.0 && mounted) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (!_isHolding || !mounted) break;
      setState(() {
        _holdProgress += 0.01;
      });
      if (_holdProgress >= 1.0) {
        _triggerSos();
        break;
      }
    }
  }

  void _stopHolding() {
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  Future<void> _triggerSos() async {
    setState(() {
      _isHolding = false;
      _isSending = true;
    });

    try {
      final apiClient = context.read<ApiClient>();
      final sosService = SosService(apiClient);

      // Check Network Connectivity First
      final connectivityResult = await (Connectivity().checkConnectivity());
      final isOffline =
          connectivityResult.contains(ConnectivityResult.none) ||
          connectivityResult.isEmpty;

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
            Icon(
              Icons.signal_cellular_connected_no_internet_4_bar,
              color: AppTheme.errorColor,
            ),
            SizedBox(width: 8),
            Text(
              'Aucun Réseau Détecté',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
              final link =
                  'sms:112?body=${Uri.encodeComponent("URGENCE ECO-GUIDE - Je suis à la position GPS : ${_currentPosition.latitude}, ${_currentPosition.longitude}. Envoyez des secours.")}';
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
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _confirmEndTrail() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminer le trail ?'),
        content: const Text(
          'Votre trail actif sera termine et vous reviendrez a l\'accueil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD84B3C),
            ),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildSosButton(),
              const SizedBox(height: 16),
              Text(
                'Maintenez 3 secondes pour alerter',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Les secours recevront votre position exacte',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 32),
              _buildGpsCard(),
              const SizedBox(height: 32),
              _buildEmergencyContacts(),
              const SizedBox(height: 32),
              _buildSafetyTips(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: IconButton(
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onSurface,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Text(
          'Urgence SOS',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        TextButton(
          onPressed: _confirmEndTrail,
          child: const Text(
            'End',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildSosButton() {
    return GestureDetector(
      onTapDown: (_) => _startHolding(),
      onTapUp: (_) => _stopHolding(),
      onTapCancel: _stopHolding,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse rings
              if (!_isHolding) ...[
                Transform.scale(
                  scale: _pulseAnimation.value * 1.3,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFC83226).withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: _pulseAnimation.value * 1.15,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFC83226).withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ],
              // Progress ring when holding
              if (_isHolding)
                SizedBox(
                  width: 160,
                  height: 160,
                  child: CircularProgressIndicator(
                    value: _holdProgress,
                    strokeWidth: 8,
                    backgroundColor: const Color(
                      0xFFC83226,
                    ).withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFC83226),
                    ),
                  ),
                ),
              // Main button
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSending
                      ? Colors.grey
                      : (_isHolding
                            ? const Color(0xFFC83226).withValues(alpha: 0.9)
                            : const Color(0xFFC83226)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC83226).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _isSending
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Votre Position GPS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(
                      color: _hasGoodSignal
                          ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.my_location,
                        size: 14,
                        color: _hasGoodSignal
                            ? const Color(0xFF2E7D32)
                            : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _hasGoodSignal ? 'Signal Fort' : 'Signal Faible',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _hasGoodSignal
                              ? const Color(0xFF2E7D32)
                              : Colors.orange,
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
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
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
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentPosition,
                            width: 24,
                            height: 24,
                            child: const Icon(
                              Icons
                                  .change_history, // Triangle icon used in screenshot instead of person
                              color: Color(0xFFD84B3C),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Coordinates overlay
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${latDegrees.toStringAsFixed(4)}° $latDirection, ${lngDegrees.toStringAsFixed(4)}° $lngDirection',
                        style: TextStyle(
                          color: const Color(0xFF111111),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 8,
                    child: Text(
                      'Map data from OpenStreetMap',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Altitude and Precision
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn(
                  'Altitude',
                  '${_altitude.toStringAsFixed(0)} m',
                ),
                _buildInfoColumn(
                  'Précision',
                  '+/- ${_accuracy.toStringAsFixed(0)} mètres',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyContacts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contacts d\'urgence',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildContactItem(
          icon: Icons.local_hospital,
          title: 'Secours en Montagne',
          subtitle: 'PGHM - Intervention rapide',
          number: '112',
        ),
        const SizedBox(height: 12),
        _buildContactItem(
          icon: Icons.park,
          title: 'Poste des Gardes',
          subtitle: 'Parc National Éco-Guide',
          number: '112',
        ),
        const SizedBox(height: 12),
        _buildContactItem(
          icon: Icons.person,
          title: 'Guide Référent',
          subtitle: 'Jean Dupont (Votre expédition)',
          number: '112',
        ),
      ],
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String number,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.8),
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
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone,
                color: Color(0xFF2E7D32),
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
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.red.withValues(alpha: 0.1)
            : const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.red.withValues(alpha: 0.3)
              : const Color(0xFFFFD4D4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.redAccent
                : const Color(0xFFD32F2F),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'En attendant les secours',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.redAccent
                        : const Color(0xFFD32F2F),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Restez visible, couvrez-vous pour éviter l\'hypothermie et ne quittez pas votre position actuelle.',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.redAccent.withValues(alpha: 0.9)
                        : const Color(0xFFD32F2F),
                    fontSize: 12,
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
