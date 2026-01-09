import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sound_mode/sound_mode.dart'; // <--- NEW IMPORT
import 'package:sound_mode/utils/ringer_mode_statuses.dart'; // <--- NEW IMPORT
import '../services/database_helper.dart';

class HomeProvider with ChangeNotifier {
  bool _isServiceActive = false;
  String _statusMessage = "Service is Stopped";
  String _currentLocationInfo = "Unknown Location";

  // Getters
  bool get isServiceActive => _isServiceActive;
  String get statusMessage => _statusMessage;
  String get currentLocationInfo => _currentLocationInfo;

  // --- MAIN FUNCTION: TOGGLE BUTTON ---
  void toggleService() {
    _isServiceActive = !_isServiceActive;

    if (_isServiceActive) {
      _statusMessage = "Service Started...";
      notifyListeners();

      // 1. Scan Instantly
      _scanAndCheckLocation();

      // 2. Scan again in 10 seconds
      Future.delayed(const Duration(seconds: 10), () {
        // Only scan if user hasn't turned it off in the meantime
        if (_isServiceActive) {
          print("10 seconds passed. Re-scanning...");
          _scanAndCheckLocation();
        }
      });

    } else {
      // User turned OFF the service -> Revert to Normal Mode
      _stopService();
    }
  }
  
  void _stopService() async {
     _statusMessage = "Service Stopped";
     _currentLocationInfo = "Normal Mode Restored";
     
     // Set phone back to NORMAL when stopping
     try {
       await SoundMode.setSoundMode(RingerModeStatus.normal);
     } catch (e) {
       print("Error restoring sound: $e");
     }
     
     notifyListeners();
  }

  // --- HELPER: THE SCANNING LOGIC ---
  Future<void> _scanAndCheckLocation() async {
    try {
      _statusMessage = "Scanning Location...";
      notifyListeners();

      // A. Get Current Position
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // B. Fetch Saved Places from DB
      final contexts = await DatabaseHelper().getAllContexts();
      
      bool matchFound = false;
      String matchedPlaceName = "";

      // C. Loop through saved places to find a match
      for (var place in contexts) {
        if (place['type'] == 'GEOFENCE' && place['is_active'] == 1) {
          
          List<String> coords = place['value'].split(',');
          double savedLat = double.parse(coords[0]);
          double savedLng = double.parse(coords[1]);
          double radius = (place['radius'] ?? 100).toDouble();

          double distanceInMeters = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            savedLat,
            savedLng,
          );

          if (distanceInMeters <= radius) {
            matchFound = true;
            matchedPlaceName = place['name'];
            break; // Stop looking, we found one
          }
        }
      }

      // --- LOGIC TO CHANGE PHONE SETTINGS ---
      if (matchFound) {
        _statusMessage = "Active: Inside $matchedPlaceName";
        _currentLocationInfo = "Silent Mode ON";
        
        // 1. SILENCE THE PHONE
        await SoundMode.setSoundMode(RingerModeStatus.silent); // Or .vibrate
        
        // 2. Log it
        await DatabaseHelper().logEvent("GEOFENCE", "SILENCED_AT_$matchedPlaceName");

      } else {
        _statusMessage = "Active: Monitoring...";
        _currentLocationInfo = "Outside known areas (Normal Mode)";

        // 3. UNSILENCE THE PHONE (Back to Normal)
        await SoundMode.setSoundMode(RingerModeStatus.normal);
      }

    } catch (e) {
      _statusMessage = "Error: ${e.toString()}";
      // Fallback
      await SoundMode.setSoundMode(RingerModeStatus.normal);
    }
    
    notifyListeners();
  }
}