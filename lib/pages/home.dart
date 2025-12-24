import 'package:flutter/material.dart';
import 'package:smartsilence_contextual_quiet_mode/services/database_helper.dart';
import 'package:flutter_background_service/flutter_background_service.dart';


class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool isMasterSwitchOn = true;
  bool isSilentModeActive = false;
  String predictionText = "Analyzing patterns...";

  @override
  void initState(){
    super.initState();
    _loadPrediction();
  }

  void _loadPrediction() async{
    final logs = await DatabaseHelper().getRecentLogs();
    if (logs.isNotEmpty) {
      setState(() {
        predictionText = "Prediction: Based on your recent activity, you might need silent around ${DateTime.fromMillisecondsSinceEpoch(logs.first['timestamp']).hour}:00.";
      });
    } else {
      setState(() {
        predictionText = "No data yet. Use the app for a few days to see predictions.";
      });
    }
  }


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
                    onChanged: (val) async{
                      final service = FlutterBackgroundService();
                      if (val) {
                        await service.startService();
                      } else {
                        service.invoke("stopService");
                      }
                      setState(() {
                        isMasterSwitchOn = val;
                        print("Background Service Enabled: $val");
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
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.purple),
                      SizedBox(width: 10),
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