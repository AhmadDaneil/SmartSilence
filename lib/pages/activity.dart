import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:smartsilence_contextual_quiet_mode/services/database_helper.dart';
import 'package:sqflite/sqlite_api.dart';

class Activity extends StatefulWidget {
  const Activity({super.key});

  @override
  State<Activity> createState() => _ActivityState();
}

class _ActivityState extends State<Activity> {
  bool locGranted = false;
  bool notifGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  void _checkPermission() async{
    var loc = await Permission.location.status;
    var notif = await Permission.notification.status;
    setState(() {
      locGranted = loc.isGranted;
      notifGranted = notif.isGranted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Activity Log")),
      body: Column(
        children: [
          // Permissions Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPermissionStatus("Location", locGranted),
                _buildPermissionStatus("Notification", notifGranted),
              ]
            ),
          ),
          const Divider(height: 1),
          
          // Log List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper().getRecentLogs(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final logs = snapshot.data!;

                if (logs.isEmpty) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () async{
                        await DatabaseHelper().logEvent("GEOFENCE", "SILENT");
                        setState(() {});
                      },
                      child: const Text("Simulate Event (Generate Log)"),
                      ),
                  );
                }

                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(log['timestamp']);
                    return ListTile(
                      leading: const Icon(Icons.history, size: 18),
                      title: Text("Trigger: ${log['trigger_source']}"),
                      subtitle: Text("Time: ${DateFormat('hh:mm a').format(date)}"),
                      trailing: Text(log['action_taken'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionStatus(String name, bool isGranted) {
    return Column(
      children: [
        Icon(
          isGranted ? Icons.check_circle : Icons.error,
          color: isGranted ? Colors.green : Colors.red,
        ),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}