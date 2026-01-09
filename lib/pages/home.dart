import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartsilence_contextual_quiet_mode/services/home_provider.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the provider
    final homeProvider = context.watch<HomeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- STATUS DISPLAY ---
            const Icon(Icons.radar, size: 80, color: Colors.deepPurple),
            const SizedBox(height: 20),
            
            Text(
              homeProvider.statusMessage, 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              homeProvider.currentLocationInfo,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            
            const SizedBox(height: 50),

            // --- THE TOGGLE BUTTON ---
            GestureDetector(
              onTap: () {
                context.read<HomeProvider>().toggleService();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  color: homeProvider.isServiceActive ? Colors.green : Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: homeProvider.isServiceActive 
                          ? Colors.green.withOpacity(0.4) 
                          : Colors.red.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ]
                ),
                child: Center(
                  child: Text(
                    homeProvider.isServiceActive ? "ON" : "OFF",
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 32, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            const Text("Tap to Automate Silence")
          ],
        ),
      ),
    );
  }
}