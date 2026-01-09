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
// THIS IS THE CODE THAT RUNS IN THE BACKGROUND
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // --- STATE TRACKING VARIABLES ---
  // We use these to remember the previous state.
  // We only update the phone if the state CHANGES.
  bool? isCurrentlySilent; 
  String? lastZoneName; 
  // --------------------------------

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
    // Reset state so it can trigger again if needed
    isCurrentlySilent = false; 
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
        final contexts = await db.getAllContexts();
        
        bool insideZone = false;
        String activeZoneName = "";

        for (var place in contexts) {
          if (place['is_active'] == 1 && place['type'] == 'GEOFENCE') {
            final coords = place['value'].split(',');
            double savedLat = double.parse(coords[0]);
            double savedLong = double.parse(coords[1]);
            double radius = (place['radius'] as int).toDouble();

            double distanceInMeters = Geolocator.distanceBetween(
              position.latitude, position.longitude, savedLat, savedLong
            );

            if (distanceInMeters <= radius) {
              insideZone = true;
              activeZoneName = place['name'];
              break; 
            }
          }
        }

        // --- CRITICAL FIX: ONLY UPDATE IF STATE CHANGED ---
        bool stateChanged = (insideZone != isCurrentlySilent) || (insideZone && activeZoneName != lastZoneName);

        if (stateChanged) {
          print("State Changed! Updating System...");

          // 3. ACTUAL SYSTEM CONTROL
          if (insideZone) {
            // ENTERING A QUIET ZONE
            try {
              await SoundMode.setSoundMode(RingerModeStatus.vibrate); // or .silent

              // Log only ONCE when entering
              await db.logEvent("GEOFENCE ($activeZoneName)", "SILENCED");

              service.setForegroundNotificationInfo(
                title: "SmartSilence Active", 
                content: "Silenced: Inside $activeZoneName"
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
            // LEAVING A ZONE (RETURNING TO NORMAL)
            try {
              await SoundMode.setSoundMode(RingerModeStatus.normal);
              
              // Log only ONCE when exiting
              await db.logEvent("GEOFENCE_EXIT", "NORMAL_MODE");

              service.setForegroundNotificationInfo(
                title: "SmartSilence Active",
                content: "Safe Zone. Ringer ON.",
              );

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

          // Update State Trackers
          isCurrentlySilent = insideZone;
          lastZoneName = activeZoneName;
        }
      }
    }
  });
}