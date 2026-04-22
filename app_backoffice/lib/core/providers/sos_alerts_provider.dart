import 'package:flutter/material.dart';
import '../models/sos_alert_model.dart';
import '../services/sos_service.dart';
import '../services/socket_service.dart';
import 'package:audioplayers/audioplayers.dart';

class SosAlertsProvider extends ChangeNotifier {
  List<SosAlertModel> _alerts = [];
  bool _isLoading = false;
  String? _error;
  AudioPlayer? _audioPlayer;
  bool _isAlarmPlaying = false;

  List<SosAlertModel> get alerts => _alerts;
  List<SosAlertModel> get activeAlerts => _alerts.where((a) => !a.isResolved).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAlarmPlaying => _isAlarmPlaying;

  SosAlertsProvider() {
    _initSocketListeners();
  }

  void _initSocketListeners() {
    SocketService.on('sos_alert_created', (data) async {
      // Auto-refresh using standard function when new alert comes
      loadAlerts();
      
      // Play alert sound (louder alarm loop)
      try {
        if (_audioPlayer == null) {
          _audioPlayer = AudioPlayer();
          _audioPlayer!.onPlayerStateChanged.listen((state) {
            _isAlarmPlaying = state == PlayerState.playing;
            notifyListeners();
          });
        }
        await _audioPlayer!.setVolume(1.0);
        await _audioPlayer!.setReleaseMode(ReleaseMode.loop); // Keep ringing until stopped
        await _audioPlayer!.play(UrlSource('https://actions.google.com/sounds/v1/alarms/alarm_clock.ogg'));
      } catch (e) {
        print('Error playing sound: $e');
      }
    });

    SocketService.on('sos_alert_resolved', (data) {
      loadAlerts();
    });
  }

  void stopAlarm() {
    if (_audioPlayer != null) {
      _audioPlayer!.stop();
    }
  }

  Future<void> loadAlerts({bool activeOnly = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (activeOnly) {
        _alerts = await SosService.getActiveAlerts();
      } else {
        _alerts = await SosService.getAllAlerts();
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> resolveAlert(String id) async {
    try {
      await SosService.resolveAlert(id);
      await loadAlerts();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
