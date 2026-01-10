import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'database_helper.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel stickyChannel = AndroidNotificationChannel(
    'sticky_service_v1', 
    'SmartSilence Service',
    description: 'Background Monitor',
    importance: Importance.low, 
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(stickyChannel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true, 
      isForegroundMode: true,
      notificationChannelId: 'sticky_service_v1', 
      initialNotificationTitle: 'SmartSilence',
      initialNotificationContent: 'Monitoring...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );

  await service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  await localNotifications.initialize(
    const InitializationSettings(android: initializationSettingsAndroid),
  );

  // Helper: Show Pop-up Notification
  Future<void> showPopUp(String title, String body) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_priority_alerts', 'Zone Alerts',
        importance: Importance.max, priority: Priority.high,
        playSound: true, enableVibration: true,
      );
      await localNotifications.show(777, title, body, NotificationDetails(android: androidDetails));
    } catch (e) { print(e); }
  }

  // --- STATE VARIABLES ---
  bool? wasSilent;
  String? lastZoneName;
  Timer? timer; 
  int outsideCount = 0; // Buffer counter

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) => service.setAsForegroundService());
    service.on('setAsBackground').listen((event) => service.setAsBackgroundService());
  }

  // ==========================================================
  // 1. FIXED STOP LISTENER (This fixes the "Off Button")
  // ==========================================================
  service.on('stopService').listen((event) async {
    print("🛑 Stop Command Received");
    
    // A. Force Phone back to Normal Mode
    try {
      await SoundMode.setSoundMode(RingerModeStatus.normal);
    } catch (e) { print(e); }

    // B. Log the Stop Event
    await DatabaseHelper().logEvent("Manual Switch", "NORMAL");

    // C. Kill the service
    timer?.cancel(); 
    service.stopSelf(); 
  });

  print("🚀 Service Started");

  // --- LOOP EVERY 5 SECONDS ---
  timer = Timer.periodic(const Duration(seconds: 5), (t) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        
        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        } catch (e) { return; }

        final db = DatabaseHelper();
        final contexts = await db.getAllContexts();
        
        bool currentlyInside = false;
        String activeZoneName = "Unknown";

        // Check Zones
        for (var place in contexts) {
          if (place['is_active'] == 1 && place['type'] == 'GEOFENCE') {
            final coords = place['value'].split(',');
            double savedLat = double.parse(coords[0]);
            double savedLong = double.parse(coords[1]);
            double radius = (place['radius'] as int).toDouble();

            double distance = Geolocator.distanceBetween(
              position.latitude, position.longitude, savedLat, savedLong
            );

            // 10m buffer to prevent flickering at the edge
            if (distance <= (radius + 10)) {
              currentlyInside = true;
              activeZoneName = place['name'];
              break; 
            }
          }
        }

        // ==========================================================
        // 2. LOGIC WITH DATABASE LOGGING (Fixes "Missing Logs")
        // ==========================================================
        if (currentlyInside) {
          outsideCount = 0; // Reset buffer
          
          if (wasSilent != true || activeZoneName != lastZoneName) {
             try {
              // CHANGE SETTINGS
              await SoundMode.setSoundMode(RingerModeStatus.vibrate);
              
              // NOTIFICATIONS
              service.setForegroundNotificationInfo(
                title: "SmartSilence Active", content: "Inside $activeZoneName"
              );
              if (wasSilent != true) await showPopUp("Entering $activeZoneName", "Phone Silenced");
              service.invoke('update', {"is_silent": true, "status_text": "Inside $activeZoneName"});
              
              // LOGGING TO DATABASE
              await DatabaseHelper().logEvent("Entered $activeZoneName", "SILENT");

              wasSilent = true;
              lastZoneName = activeZoneName;
            } catch (e) { print(e); }
          }
        } else {
          outsideCount++; // Increment buffer
          
          // Wait for 3 checks (15 seconds) before switching off
          if (outsideCount >= 3) { 
            if (wasSilent == true) {
               try {
                // CHANGE SETTINGS
                await SoundMode.setSoundMode(RingerModeStatus.normal);

                // NOTIFICATIONS
                service.setForegroundNotificationInfo(
                  title: "SmartSilence Running", content: "Safe Zone"
                );
                await showPopUp("Left Quiet Zone", "Ringer Restored");
                service.invoke('update', {"is_silent": false, "status_text": "Safe Zone"});
                
                // LOGGING TO DATABASE
                await DatabaseHelper().logEvent("Exited Zone", "NORMAL");

                wasSilent = false;
                lastZoneName = null;
              } catch (e) { print(e); }
            }
            outsideCount = 3; // Cap the counter
          }
        }
      }
    }
  });
}