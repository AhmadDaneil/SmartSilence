import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool isMasterSwitchOn = false;
  bool isSilentModeActive = false;
  String predictionText = "System Idle";

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();

    // Listen for updates from the background service
    FlutterBackgroundService().on('update').listen((event) {
      if (event != null) {
        if (mounted) {
          setState(() {
            isSilentModeActive = event["is_silent"];
            predictionText = event['status_text'];
          });
        }
      }
    });
  }

  void _checkServiceStatus() async {
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();

    if (mounted) {
      setState(() {
        isMasterSwitchOn = isRunning;
        predictionText = isRunning ? "Monitoring Location..." : "System Paused";
      });
    }
  }

  // --- TOGGLE LOGIC ---
  void _toggleService(bool value) async {
    final service = FlutterBackgroundService();

    if (value) {
      // --- TURNING ON ---

      // 1. ASK FOR FOREGROUND LOCATION
      var locStatus = await Permission.location.status;
      if (!locStatus.isGranted) {
        locStatus = await Permission.location.request();
        if (!locStatus.isGranted) {
          _showError("Location permission is required to detect zones.");
          setState(() => isMasterSwitchOn = false);
          return;
        }
      }

      // 2. ASK FOR BACKGROUND LOCATION
      var bgStatus = await Permission.locationAlways.status;
      if (!bgStatus.isGranted) {
        if (mounted) {
          bool? allowBg = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Background Location Needed"),
              content: const Text(
                  "To silence your phone automatically while it's in your pocket, "
                  "SmartSilence needs 'Allow all the time' location access.\n\n"
                  "Please select 'Allow all the time' on the next screen."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Cancel")),
                ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text("Open Settings")),
              ],
            ),
          );

          if (allowBg == true) {
            await Permission.locationAlways.request();
            setState(() => isMasterSwitchOn = false);
            return;
          } else {
            setState(() => isMasterSwitchOn = false);
            return;
          }
        }
      }

      // 3. ASK FOR DO NOT DISTURB ACCESS
      var dndStatus = await Permission.accessNotificationPolicy.status;
      if (!dndStatus.isGranted) {
        await Permission.accessNotificationPolicy.request();
        dndStatus = await Permission.accessNotificationPolicy.status;
        if (!dndStatus.isGranted) {
          _showError("Cannot run without 'Do Not Disturb' access.");
          setState(() => isMasterSwitchOn = false);
          return;
        }
      }

      // 4. START SERVICE
      var isRunning = await service.startService();
      if (isRunning) {
        setState(() {
          isMasterSwitchOn = true;
          predictionText = "Monitoring Location...";
        });
      }
    } else {
      // --- TURNING OFF (UPDATED) ---
      
      // 1. Send signal to Background Service to UN-SILENCE the phone first
      service.invoke("set_normal_mode"); 

      // 2. Stop the service
      service.invoke("stopService");

      // 3. Update UI
      setState(() {
        isMasterSwitchOn = false;
        predictionText = "System Paused";
        isSilentModeActive = false;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SmartSilence Dashboard"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsetsGeometry.all(20.0),
                child: Column(
                  children: [
                    const Text("Current Status",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        color: isSilentModeActive
                            ? Colors.orange.shade100
                            : Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSilentModeActive
                                ? Icons.notifications_off
                                : Icons.notifications_active,
                            size: 50,
                            color: isSilentModeActive
                                ? Colors.deepOrange
                                : Colors.green,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isSilentModeActive ? "SILENT" : "ACTIVE",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSilentModeActive
                                  ? Colors.deepOrange
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            SwitchListTile(
              title: const Text("SmartSilence Service",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              subtitle: Text(isMasterSwitchOn
                  ? "Running in background"
                  : "Service is stopped"),
              value: isMasterSwitchOn,
              activeColor: Colors.deepPurple,
              onChanged: _toggleService, 
            ),
            const Divider(height: 40),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(predictionText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}