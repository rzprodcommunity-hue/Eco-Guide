import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/services/offline_sos_service.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/locale_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/map_tile_url.dart';
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
  bool _isDetectingPosition = false;
  StreamSubscription<Position>? _positionSubscription;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _detectUserPosition();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _detectUserPosition() async {
    if (_isDetectingPosition) return;
    setState(() => _isDetectingPosition = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services disabled');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied');
        return;
      }

      // Try to get a quick last-known fix first for instant feedback
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          final pos = LatLng(lastKnown.latitude, lastKnown.longitude);
          setState(() {
            _currentPosition = pos;
            _altitude = lastKnown.altitude;
            _accuracy = lastKnown.accuracy;
          });
          _mapController.move(pos, 17);
        }
      } catch (_) {}

      // Then get a fresh high-accuracy fix
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;
      final newPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = newPos;
        _altitude = position.altitude;
        _accuracy = position.accuracy;
        _hasGoodSignal = position.accuracy < 20;
      });
      _mapController.move(newPos, 17);

      // Start continuous live tracking
      _startPositionStream();
    } catch (e) {
      debugPrint('Error getting position: $e');
    } finally {
      if (mounted) setState(() => _isDetectingPosition = false);
    }
  }

  void _startPositionStream() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2, // update every 2 meters of movement
      ),
    ).listen((position) {
      if (!mounted) return;
      final newPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = newPos;
        _altitude = position.altitude;
        _accuracy = position.accuracy;
        _hasGoodSignal = position.accuracy < 20;
      });
    }, onError: (e) => debugPrint('Position stream error: $e'));
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
            label: Text(context.watch<LocaleProvider>().t('sos.smsEmergency')),
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
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $uri: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir le téléphone: $e')),
        );
      }
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
              const SizedBox(height: 60),
              Text(
                context.watch<LocaleProvider>().t('sos.holdInstruction'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.watch<LocaleProvider>().t('sos.locationInfo'),
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
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
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
          ),
        ),
        Text(
          context.watch<LocaleProvider>().t('sos.title'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const Expanded(child: SizedBox()),
      ],
    );
  }

  Widget _buildSosButton() {
    return GestureDetector(
      onTapDown: (_) => _startHolding(),
      onTapUp: (_) => _stopHolding(),
      onTapCancel: _stopHolding,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final t = _pulseController.value; // 0 → 1 → 0

          return SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Halo 1 — outer ──────────────────────────────────────────
                if (!_isHolding)
                  Transform.scale(
                    scale: 1.0 + t * 0.18,
                    child: Opacity(
                      opacity: (0.85 - t * 0.50).clamp(0.0, 1.0),
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE53935).withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                  ),
                // ── Halo 2 — inner ──────────────────────────────────────────
                if (!_isHolding)
                  Transform.scale(
                    scale: 1.0 + t * 0.10,
                    child: Opacity(
                      opacity: (0.80 - t * 0.35).clamp(0.0, 1.0),
                      child: Container(
                        width: 152,
                        height: 152,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE53935).withValues(alpha: 0.16),
                        ),
                      ),
                    ),
                  ),
                // ── Progress ring when holding ───────────────────────────────
                if (_isHolding)
                  SizedBox(
                    width: 158,
                    height: 158,
                    child: CircularProgressIndicator(
                      value: _holdProgress,
                      strokeWidth: 6,
                      backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE53935)),
                    ),
                  ),
                // ── Outer shell — animated shadow ────────────────────────────
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(0, -0.36),
                      radius: 0.75,
                      colors: [Color(0xFFFF7065), Color(0xFFE53935), Color(0xFFBD2723)],
                      stops: [0.0, 0.55, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53935).withValues(alpha: 0.30 + t * 0.25),
                        blurRadius: 18 + t * 18,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    // ── Middle shell ────────────────────────────────────────
                    child: Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(0, -0.30),
                          radius: 0.65,
                          colors: [Color(0xFFC42924), Color(0xFFC62828), Color(0xFFBC2724)],
                          stops: [0.0, 0.70, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: Center(
                        // ── Inner face ────────────────────────────────────
                        child: Container(
                          width: 118,
                          height: 118,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              center: Alignment(0, -0.40),
                              radius: 0.65,
                              colors: [Color(0xFFFF8C81), Color(0xFFEF4945), Color(0xFFC62828)],
                              stops: [0.0, 0.40, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.16),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isSending
                                ? const SizedBox(
                                    width: 32, height: 32,
                                    child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 3,
                                    ),
                                  )
                                : const Text(
                                    'SOS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.0,
                                      height: 1,
                                      shadows: [
                                        Shadow(color: Colors.black38, blurRadius: 0, offset: Offset(0, 1)),
                                        Shadow(color: Colors.black26, blurRadius: 14),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildZoomButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF333333)),
      ),
    );
  }

  Widget _buildGpsCard() {
    final latDirection = _currentPosition.latitude >= 0 ? 'N' : 'S';
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
                  context.watch<LocaleProvider>().t('sos.position'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _detectUserPosition,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _isDetectingPosition
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF2E7D32),
                                ),
                              )
                            : const Icon(
                                Icons.refresh,
                                size: 18,
                                color: Color(0xFF2E7D32),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                        _hasGoodSignal
                            ? context.watch<LocaleProvider>().t('sos.signal.strong')
                            : context.watch<LocaleProvider>().t('sos.signal.weak'),
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
              ],
            ),
          ),
          // Mini Map
          Container(
            height: 200,
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
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentPosition,
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.pinchZoom |
                            InteractiveFlag.doubleTapZoom |
                            InteractiveFlag.drag,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: mapTileUrlForTheme(context),
                        userAgentPackageName: 'com.ecoguide.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentPosition,
                            width: 32,
                            height: 32,
                            child: const Icon(
                              Icons.location_pin,
                              color: Color(0xFFD84B3C),
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Coordinates overlay
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lat: ${_currentPosition.latitude.toStringAsFixed(6)}° $latDirection',
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Lng: ${_currentPosition.longitude.toStringAsFixed(6)}° $lngDirection',
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Zoom buttons
                  Positioned(
                    right: 8,
                    bottom: 24,
                    child: Column(
                      children: [
                        _buildZoomButton(
                          icon: Icons.add,
                          onTap: () => _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom + 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildZoomButton(
                          icon: Icons.remove,
                          onTap: () => _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom - 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 8,
                    child: Text(
                      '© OpenStreetMap',
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
                  context.watch<LocaleProvider>().t('sos.altitude'),
                  '${_altitude.toStringAsFixed(0)} m',
                ),
                _buildInfoColumn(
                  context.watch<LocaleProvider>().t('sos.precision'),
                  '+/- ${_accuracy.toStringAsFixed(0)} m',
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
          context.watch<LocaleProvider>().t('sos.contacts'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        _buildContactItem(
          icon: Icons.local_hospital,
          title: context.watch<LocaleProvider>().t('sos.contact.mountain'),
          subtitle: context.watch<LocaleProvider>().t('sos.contact.mountain.desc'),
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
    return GestureDetector(
      onTap: () => _callNumber(number),
      child: Container(
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
                  const SizedBox(height: 2),
                  Text(
                    number,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
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
