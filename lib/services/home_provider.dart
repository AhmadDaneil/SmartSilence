import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class HomeProvider with ChangeNotifier {
  bool _isServiceActive = false;
  String _statusMessage = "Service is Stopped";
  String _currentLocationInfo = "Normal Mode";

  // Getters
  bool get isServiceActive => _isServiceActive;
  String get statusMessage => _statusMessage;
  String get currentLocationInfo => _currentLocationInfo;

  HomeProvider() {
    _init();
  }

  void _init() async {
    final service = FlutterBackgroundService();
    
    // 1. Check if the service is already running when app opens
    _isServiceActive = await service.isRunning();
    if (_isServiceActive) {
      _statusMessage = "Service Running";
    }

    // 2. Listen for updates FROM the background service
    // This ensures the UI matches exactly what the background is doing
    service.on('update').listen((event) {
      if (event != null) {
        // Update the UI text based on the Background Service's reality
        _statusMessage = event['status_text'] ?? _statusMessage;
        
        // Optional: You can update current location info if your service sends it
        if (event['is_silent'] == true) {
          _currentLocationInfo = "Silent Mode Active";
        } else {
          _currentLocationInfo = "Safe Zone (Normal Mode)";
        }
        notifyListeners();
      }
    });
  }

  // --- TOGGLE BUTTON ACTION ---
  void toggleService() async {
    final service = FlutterBackgroundService();
    
    if (_isServiceActive) {
      // --- TURN OFF ---
      service.invoke("stopService"); // Tell Background Service to die
      _isServiceActive = false;
      _statusMessage = "Service Stopped";
      _currentLocationInfo = "Normal Mode Restored";
      print("🔕 Stopped Service");
    } else {
      // --- TURN ON ---
      await service.startService(); // Tell Background Service to start
      _isServiceActive = true;
      _statusMessage = "Starting...";
      _currentLocationInfo = "Initializing...";
      print("🔔 Started Service");
    }

    notifyListeners();
  }
}