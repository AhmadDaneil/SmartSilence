import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/activity.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/context_manager.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/home.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/smart_insight.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smartsilence_contextual_quiet_mode/services/background_service.dart';
import 'package:smartsilence_contextual_quiet_mode/services/insight_provider.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await Permission.notification.request();
  await Permission.locationAlways.request();
  await Permission.accessNotificationPolicy.request();

  await initializeService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InsightProvider()),
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainNavigationWrapper(),
    );
  }
}

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
          padding: const EdgeInsets.symmetric(horizontal:15.0, vertical: 20),
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
            padding: EdgeInsets.all(16),
            tabs: [
              GButton(
                icon: Icons.dashboard_outlined,
                text: 'Dashboard',
                ),
              GButton(
                icon: Icons.map_outlined,
                text: 'Map',
                ),
              GButton(
                icon: Icons.insights_outlined,
                text: 'Insights',
                ),
              GButton(
                icon: Icons.history_outlined,
                text: 'History',
                ),
            ]
            ),
        ),
      ),
    );

  }
}
