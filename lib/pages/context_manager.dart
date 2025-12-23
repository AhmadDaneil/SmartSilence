import 'package:flutter/material.dart';
import 'package:smartsilence_contextual_quiet_mode/services/database_helper.dart';

class ContextManager extends StatefulWidget {
  const ContextManager({super.key});

  @override
  State<ContextManager> createState() => _ContextManagerState();
}

class _ContextManagerState extends State<ContextManager> {

  // LOGIC: Add a dummy place to DB (Simulating a Map pick)
  void _addMockPlace() async {
    await DatabaseHelper().insertContext({
      'name': 'New Location ${DateTime.now().second}',
      'type': 'GEOFENCE',
      'value': '3.0123, 101.500',
      'radius': 50,
      'is_active': 1
    });
    setState(() {}); // Refresh list
  }

  // LOGIC: Toggle active state in DB
  void _toggleContext(int id, bool currentValue) async {
    await DatabaseHelper().toggleContext(id, currentValue ? 0 : 1);
    setState(() {}); // Refresh list
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Context Manager")
      ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addMockPlace, 
          icon : const Icon(Icons.add_location_alt),
          label: const Text("Add Place"), 
          ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper().getAllContexts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final contexts = snapshot.data!;
          if (contexts.isEmpty) return const Center(child: Text("No contexts added yet."));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: contexts.length,
            itemBuilder: (context, index) {
              final item = contexts[index];
              return Card(
              child: ListTile(
              leading: CircleAvatar(child: Icon(item['type'] == 'GEOFENCE' ? Icons.place : Icons.wifi),
              ),
              title: Text(item['name']),
              subtitle: Text(item['value']),
              trailing: Switch(value: item['is_active'] == 1, onChanged: (val) => _toggleContext(item['id'], item['is_active'] == 1),
              ),
              ),
            );
            }
          );
        }
      ),
    );
  }
}