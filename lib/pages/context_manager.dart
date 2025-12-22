import 'package:flutter/material.dart';

class ContextManager extends StatelessWidget {
  const ContextManager({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Context Manager")
      ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: (){}, 
          icon : const Icon(Icons.add_location_alt),
          label: const Text("Add Context"), 
          ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Saved Locations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildContextCard("University Library", "Radius: 50m", Icons.local_library, true),
          _buildContextCard("Lecture Hall", "Radius: 30m", Icons.class_, false),

          const Divider(height: 40,),

          const Text("Saved Wi-Fi Networks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildContextCard("UiTM Wifi", "SSID Match", Icons.wifi, true),
          _buildContextCard("MyHome Wifi", "SSID Match", Icons.home, false),
        ],
      ),
    );
  }

  Widget _buildContextCard(String title, String subtitle, IconData icon, bool isActive) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Switch(value: isActive, onChanged: (val) {}),
      ),
    );
  }
}