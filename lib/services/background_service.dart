import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'database_helper.dart'; // Ensure this import points to your DB file

// Entry point
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // Create the notification channel (Required for Android)
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
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'SmartSilence Active',
      initialNotificationContent: 'Initializing...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(),
  );
}

// BACKGROUND LOGIC
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // --- STATE MEMORY ---
  // We keep track of the LAST known state to avoid spamming updates
  bool? wasSilent; 
  String? lastZoneName; 
  // --------------------

  // Listeners for stopping/backgrounding
  service.on('stopService').listen((event) => service.stopSelf());
  service.on('setAsForeground').listen((event) {
     if (service is AndroidServiceInstance) service.setAsForegroundService();
  });
  service.on('setAsBackground').listen((event) {
     if (service is AndroidServiceInstance) service.setAsBackgroundService();
  });

  // Listener to force Normal Mode manually
  service.on('set_normal_mode').listen((event) async {
    await SoundMode.setSoundMode(RingerModeStatus.normal);
    wasSilent = false; 
  });

  // --- THE LOCATION LOOP (Every 10 Seconds) ---
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        
        // 1. Get Current Location
        Position? position;
        try {
          position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        } catch (e) {
          print("GPS Error: $e");
          return; 
        }

        // 2. Check Database for Matches
        final db = DatabaseHelper();
        final contexts = await db.getAllContexts();
        
        bool insideZone = false;
        String activeZoneName = "Unknown"; // Placeholder

        for (var place in contexts) {
          if (place['is_active'] == 1 && place['type'] == 'GEOFENCE') {
            final coords = place['value'].split(',');
            double savedLat = double.parse(coords[0]);
            double savedLong = double.parse(coords[1]);
            double radius = (place['radius'] as int).toDouble();

            double distance = Geolocator.distanceBetween(
              position.latitude, position.longitude, savedLat, savedLong
            );

            if (distance <= radius) {
              insideZone = true;
              activeZoneName = place['name']; // <--- CAPTURE THE NAME HERE
              break; 
            }
          }
        }

        // 3. DECISION LOGIC
        // We update IF: 
        // A. We entered/exited a zone (insideZone changed)
        // OR
        // B. We are still inside a zone, but the name changed (Moved from Library -> Class)
        
        bool stateChanged = (insideZone != wasSilent) || (insideZone && activeZoneName != lastZoneName);

        if (stateChanged) {
          if (insideZone) {
            // --- SCENARIO: ENTERING A ZONE ---
            try {
              // 1. Silence Phone
              await SoundMode.setSoundMode(RingerModeStatus.vibrate);

              // 2. Update System Notification (The Status Bar)
              service.setForegroundNotificationInfo(
                title: "SmartSilence Active", 
                content: "Silenced: Inside $activeZoneName" // <--- SHOW NAME HERE
              );

              // 3. Log to DB
              await db.logEvent("ENTERED $activeZoneName", "SILENCED");

              // 4. Update App UI
              service.invoke('update', {
                "is_silent": true,
                "status_text": "Inside $activeZoneName"
              });

            } catch(e) { print("Error silencing: $e"); }

          } else {
            // --- SCENARIO: LEAVING ZONE (SAFE) ---
            try {
              // 1. Un-Silence Phone
              await SoundMode.setSoundMode(RingerModeStatus.normal);

              // 2. Update System Notification
              service.setForegroundNotificationInfo(
                title: "SmartSilence Active",
                content: "Safe Zone. Ringer ON.", // <--- SHOW SAFE STATUS
              );

              // 3. Log to DB
              if (wasSilent == true) { // Only log if we were previously silent
                 await db.logEvent("EXITED ZONE", "NORMAL_MODE");
              }

              // 4. Update App UI
              service.invoke('update', {
                "is_silent": false,
                "status_text": "Safe Zone"
              });

            } catch (e) { print("Error restoring sound: $e"); }
          }

          // Update Memory
          wasSilent = insideZone;
          lastZoneName = activeZoneName;
        }
      }
    }
  });
}