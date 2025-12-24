import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'database_helper.dart';

// Entry point for the background service
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // Android Notification Setup (Required for foreground service)
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', 
    'SmartSilence Service', 
    description: 'Scanning for Quiet Zones...',
    importance: Importance.low, 
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // We control this with the Master Switch
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'SmartSilence Active',
      initialNotificationContent: 'Monitoring location...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(), // iOS requires different setup, skipping for simple demo
  );
}

// THIS IS THE CODE THAT RUNS IN THE BACKGROUND
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Periodically check location (Every 15 seconds)
  Timer.periodic(const Duration(seconds: 15), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        
        // 1. GET REAL LOCATION
        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        } catch (e) {
          print("Error getting location: $e");
          return;
        }

        // 2. CHECK DATABASE FOR NEARBY ZONES
        final db = DatabaseHelper();
        final contexts = await db.getAllContexts(); // Get your saved places
        
        bool insideZone = false;
        String activeZoneName = "";

        for (var place in contexts) {
          if (place['is_active'] == 1 && place['type'] == 'GEOFENCE') {
            // Parse saved "lat,long"
            final coords = place['value'].split(',');
            double savedLat = double.parse(coords[0]);
            double savedLong = double.parse(coords[1]);
            double radius = (place['radius'] as int).toDouble();

            // Calculate Distance (Real Math!)
            double distanceInMeters = Geolocator.distanceBetween(
              position.latitude, position.longitude, savedLat, savedLong
            );

            if (distanceInMeters <= radius) {
              insideZone = true;
              activeZoneName = place['name'];
              break; // Found one, stop looking
            }
          }
        }

        // 3. ACTUAL SYSTEM CONTROL (CHANGE RINGER)
        RingerModeStatus status = await SoundMode.ringerModeStatus;
        
        if (insideZone) {
          // If we are inside a zone but phone is NOT silent, silence it!
          if (status != RingerModeStatus.silent && status != RingerModeStatus.vibrate) {
            
            // ACTUALLY CHANGE PHONE SETTINGS
            try {
              await SoundMode.setSoundMode(RingerModeStatus.vibrate);
              
              // LOG IT
              await db.logEvent("GEOFENCE ($activeZoneName)", "SILENT");
              
              // Update Notification
              service.setForegroundNotificationInfo(
                title: "SmartSilence Active",
                content: "Silenced: Inside $activeZoneName",
              );
            } catch (e) {
              print("Permission error: $e");
            }
          }
        } else {
          // If we left the zone, restore sound? (Optional logic)
           service.setForegroundNotificationInfo(
                title: "SmartSilence Active",
                content: "Safe Zone. Scanning...",
           );
        }
      }
    }
  });
}