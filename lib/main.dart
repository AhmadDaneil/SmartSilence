import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

// Import your files
import 'package:smartsilence_contextual_quiet_mode/pages/activity.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/context_manager.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/home.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/smart_insight.dart';
import 'package:smartsilence_contextual_quiet_mode/services/background_service.dart';
import 'package:smartsilence_contextual_quiet_mode/services/insight_provider.dart';
import 'package:smartsilence_contextual_quiet_mode/services/home_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize background service
  await initializeService(); 

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InsightProvider()),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartSilence',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PermissionCheckScreen(),
    );
  }
}

// --- PERMISSION SCREEN (FIXED) ---
class PermissionCheckScreen extends StatefulWidget {
  const PermissionCheckScreen({super.key});

  @override
  State<PermissionCheckScreen> createState() => _PermissionCheckScreenState();
}

class _PermissionCheckScreenState extends State<PermissionCheckScreen> {
  // We use this to show a message if they deny permissions
  bool _showError = false; 

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // 1. Check Statuses
    var statusNotif = await Permission.notification.status;
    var statusDND = await Permission.accessNotificationPolicy.status;
    // Note: We check 'locationAlways' specifically for background tasks
    var statusLoc = await Permission.locationAlways.status;

    if (statusNotif.isGranted && statusLoc.isGranted && statusDND.isGranted) {
      _navigateToMain();
    }
  }

  Future<void> _requestPermissions() async {
    // 1. Notifications
    if (!await Permission.notification.isGranted) {
      await Permission.notification.request();
    }

    // 2. Location Logic (Crucial Fix for Android 11+)
    if (!await Permission.locationAlways.isGranted) {
      // First, request basic location
      LocationPermission p = await Geolocator.requestPermission();
      
      // If they gave us "While in use", we must explicitly ask for "Always"
      // or guide them to settings, because 'requestPermission' alone 
      // often doesn't grant 'Always' immediately on newer Androids.
      if (p == LocationPermission.whileInUse || p == LocationPermission.always) {
         // Try to upgrade to Always
         var status = await Permission.locationAlways.request();
         
         // If still denied (user selected "Keep only while using"), 
         // we might need to open settings manually:
         if (status.isDenied || status.isPermanentlyDenied) {
            openAppSettings();
            return; // Stop here, wait for them to come back
         }
      }
    }

    // 3. Do Not Disturb
    if (!await Permission.accessNotificationPolicy.isGranted) {
      await Permission.accessNotificationPolicy.request();
    }

    // --- FINAL VERIFICATION ---
    if (await Permission.notification.isGranted &&
        await Permission.locationAlways.isGranted &&
        await Permission.accessNotificationPolicy.isGranted) {
      _navigateToMain();
    } else {
      // Show error message in UI
      setState(() {
        _showError = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Background Location is required. Please select 'Allow all the time' in Settings."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          )
        );
      }
    }
  }

  void _navigateToMain() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainNavigationWrapper()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 20),
              const Text(
                "Permissions Required",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "To automate Silent Mode, this app needs access to:\n\n• Notifications\n• Location (Select 'Allow all the time')\n• Do Not Disturb Settings",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                onPressed: _requestPermissions,
                child: const Text("Grant Permissions"),
              ),

              // Show a small retry hint if they failed once
              if (_showError)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: TextButton(
                    onPressed: openAppSettings,
                    child: const Text("Open Settings Manually", style: TextStyle(color: Colors.red)),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}

// --- MAIN NAVIGATION ---
class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const Home(),
    const ContextManager(),
    const SmartInsight(),
    const Activity(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 20),
          child: GNav(
            selectedIndex: _currentIndex,
            onTabChange: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: Colors.white,
            color: Colors.black,
            activeColor: Colors.black,
            tabBackgroundColor: Colors.grey.shade200,
            gap: 8,
            padding: const EdgeInsets.all(16),
            tabs: const [
              GButton(icon: Icons.dashboard_outlined, text: 'Dashboard'),
              GButton(icon: Icons.map_outlined, text: 'Places'),
              GButton(icon: Icons.insights_outlined, text: 'Insights'),
              GButton(icon: Icons.history_outlined, text: 'History'),
            ],
          ),
        ),
      ),
    );
  }
}