import 'package:flutter/material.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/activity.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/context_manager.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/home.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/smart_insight.dart';
import 'package:smartsilence_contextual_quiet_mode/pages/settings.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartSilence',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartSilence',
      debugShowCheckedModeBanner: false,
      initialRoute: '/home',
      routes: {
        '/home': (context) => const Home(),
        '/context_manager': (context) => const ContextManager(),
        '/smart_insight': (context) => const SmartInsight(),
        '/activity': (context) => const Activity(),
        '/settings': (context) => const Settings(),
      }
    );

  }
}
