import 'package:flutter/material.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/activity.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/context_manager.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/home.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/smart_insight.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smartsilence_contextual_quiet_mode/services/background_service.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await Permission.notification.request();
  await Permission.locationAlways.request();
  await Permission.accessNotificationPolicy.request();

  await initializeService();

  runApp(const MyApp());
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

      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Contexts',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Activity Logs',
          ),
        ],
        ),
    );

  }
}
