import 'package:flutter/material.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool isMasterSwitchOn = true;
  bool isSilentModeActive = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SmartSilence Dashboard"),
      ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                color: isMasterSwitchOn ? Colors.indigo.shade50 : Colors.grey.shade100,
                child: SwitchListTile(
                  title: const Text(
                    "SmartSilence Service",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(isMasterSwitchOn ? "Running in background" : "Service paused"),
                    value: isMasterSwitchOn,
                    onChanged: (val){
                      setState(() {
                        isMasterSwitchOn = val;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),

                Center(
                  child: Container(
                    height: 200,
                    width: 200,
                    decoration: BoxDecoration(
                      color: isSilentModeActive ? Colors.orange.shade100 : Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSilentModeActive ? Icons.notifications_off : Icons.notifications_active,
                          size: 60,
                          color: isSilentModeActive ? Colors.orange : Colors.green,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          isSilentModeActive ? "SILENT MODE" : "RINGER ON",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                ),
                const SizedBox(height: 20),

                const Text("Active Context:", style: TextStyle(color: Colors.grey)),
                ListTile(
                  leading: const Icon(Icons.wifi, color: Colors.blue),
                  title: const Text("Connected to 'Wifi'"),
                  subtitle: const Text("Trigger: Safe Zone Detected"),
                  trailing: const Chip(label: Text("Safe")),
                ),

                const Spacer(),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.purple),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text("Prediction: You usually silence phone at 2:00 PM to today (Lecture Hall)."),
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