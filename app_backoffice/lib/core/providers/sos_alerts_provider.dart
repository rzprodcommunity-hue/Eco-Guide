import 'package:flutter/material.dart';
import '../models/sos_alert_model.dart';
import '../services/sos_service.dart';

class SosAlertsProvider extends ChangeNotifier {
  List<SosAlertModel> _alerts = [];
  bool _isLoading = false;
  String? _error;

  List<SosAlertModel> get alerts => _alerts;
  List<SosAlertModel> get activeAlerts => _alerts.where((a) => !a.isResolved).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

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
