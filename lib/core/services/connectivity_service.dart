import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to check and monitor network connectivity
class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isOnline = true;
  bool _hasBackendConnection = true;
  bool _isManualOfflineMode = true;
  DateTime? _lastBackendCheck;

  bool get isOnline => _isOnline;
  bool get hasBackendConnection => _hasBackendConnection;
  bool get isManualOfflineMode => _isManualOfflineMode;
  bool get isOfflineMode =>
      _isManualOfflineMode || !_isOnline || !_hasBackendConnection;
  bool get isFullyConnected => _isOnline && _hasBackendConnection;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    await checkConnectivity();

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateConnectivity(results);
    });
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectivity(results);
      return _isOnline;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      _isOnline = false;
      notifyListeners();
      return false;
    }
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && 
                !results.contains(ConnectivityResult.none);
    
    if (wasOnline != _isOnline) {
      debugPrint('Connectivity changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
      notifyListeners();
    }
  }

  /// Check if backend is reachable (with caching)
  Future<bool> checkBackendConnection(String baseUrl, {
    Duration cacheDuration = const Duration(minutes: 2),
  }) async {
    // Return cached result if recent
    if (_lastBackendCheck != null) {
      final elapsed = DateTime.now().difference(_lastBackendCheck!);
      if (elapsed < cacheDuration) {
        return _hasBackendConnection;
      }
    }

    if (!_isOnline) {
      _hasBackendConnection = false;
      _lastBackendCheck = DateTime.now();
      notifyListeners();
      return false;
    }

    try {
      // Try to reach backend with short timeout
      final uri = Uri.parse(baseUrl.replaceAll('/api', '/health').replaceAll('/health/health', '/health'));
      final socket = await Socket.connect(
        uri.host,
        uri.port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      
      _hasBackendConnection = true;
      _lastBackendCheck = DateTime.now();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Backend not reachable: $e');
      _hasBackendConnection = false;
      _lastBackendCheck = DateTime.now();
      notifyListeners();
      return false;
    }
  }

  /// Force check backend connection (ignore cache)
  Future<bool> forceCheckBackend(String baseUrl) async {
    _lastBackendCheck = null;
    return await checkBackendConnection(baseUrl);
  }

  /// Enable or disable manual offline mode.
  /// When enabled, the app uses offline data even if network/backend are reachable.
  void setManualOfflineMode(bool enabled) {
    if (_isManualOfflineMode == enabled) return;
    _isManualOfflineMode = enabled;
    debugPrint(
      'Manual offline mode: ${_isManualOfflineMode ? "ENABLED" : "DISABLED"}',
    );
    notifyListeners();
  }

  void toggleManualOfflineMode() {
    setManualOfflineMode(!_isManualOfflineMode);
  }

  /// Mark backend as unreachable (called after failed API request)
  void markBackendUnreachable() {
    if (_hasBackendConnection) {
      _hasBackendConnection = false;
      _lastBackendCheck = DateTime.now();
      notifyListeners();
    }
  }

  /// Mark backend as reachable (called after successful API request)
  void markBackendReachable() {
    if (!_hasBackendConnection) {
      _hasBackendConnection = true;
      _lastBackendCheck = DateTime.now();
      notifyListeners();
    }
  }

  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
