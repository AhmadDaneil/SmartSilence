import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:smartsilence_contextual_quiet_mode/services/database_helper.dart';

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

  void _refreshLogs() async {
    setState(() {});
  }

  void _resetLogs() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Logs"),
        content: const Text("Are you sure you want to clear all the activity history?"),
        actions: [
          TextButton(onPressed:() => Navigator.pop(context, false), child: const Text("Cancel"),),
          TextButton(onPressed:() => Navigator.pop(context, true), child: const Text("Clear", style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm == true) {
      await DatabaseHelper().clearAllLogs();
      setState(() {});

      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logs Cleared")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Activity Log"),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _refreshLogs,
          tooltip: "Refresh Logs",
        )
      ],
      ),
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

          // --- BUTTONS ROW (Refresh & Reset) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _refreshLogs,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text("Refresh List"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red
                    ),
                    onPressed: _resetLogs,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text("Clear History"),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),
          
          // Log List
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper().getRecentLogs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text("No activity logs found", style: TextStyle(color: Colors.grey)),
                      ],
                      ),
                  );
                }

                final logs = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(log['timestamp']);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      elevation: 1,
                      child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: const Icon(Icons.history, size:20, color: Colors.blue),
                      ),
                      title: Text(
                        "${log['trigger_source']}",
                        style: const TextStyle(fontWeight: FontWeight.bold)
                      ),
                      subtitle: Text(DateFormat('MMM d, h:mm a').format(date)),
                      trailing: Chip(
                      label: Text(log['action_taken'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: _getActionColor(log['action_taken']),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      ),
                    ),
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
  // Helper for Chip Color
  Color _getActionColor(String action) {
    if (action.toUpperCase() == "SILENT") return Colors.orange;
    if (action.toUpperCase() == "NORMAL") return Colors.green;
    return Colors.grey;
  }
}