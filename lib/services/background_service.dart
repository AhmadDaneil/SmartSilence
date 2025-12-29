import 'dart:async';
import 'dart:ui';
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

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('set_normal_mode').listen((event) async {
  await SoundMode.setSoundMode(RingerModeStatus.normal);
  print("Forcing Normal Mode...");
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Periodically check location (Every 10 seconds)
  Timer.periodic(const Duration(seconds: 10), (timer) async {
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
        if (insideZone) {
          try{
            await SoundMode.setSoundMode(RingerModeStatus.vibrate);

            await db.logEvent("GEOFENCE ($activeZoneName)", "SILENT");

            service.setForegroundNotificationInfo(
              title: "SmartSilence Active", 
              content: "Silenceed: Inside $activeZoneName"
            );

            service.invoke(
              'update',
              {
                "is_silent": true,
                "status_text": "Inside $activeZoneName",
              },
            );
          } catch(e) {
            print("Permission error: $e");
          }
        } else {
          try {
             // A. Restore Sound (Normal Mode) - THIS WAS MISSING
             await SoundMode.setSoundMode(RingerModeStatus.normal);

             // B. Update Notification
             service.setForegroundNotificationInfo(
                title: "SmartSilence Active",
                content: "Safe Zone. Ringer ON.",
             );

             // C. UPDATE THE UI (Dashboard Page)
             service.invoke(
              'update',
              {
                "is_silent": false,
                "status_text": "Safe Zone",
              },
            );

          } catch (e) {
            print("Error restoring sound: $e");
          }
        }
      }
    }
  });
}