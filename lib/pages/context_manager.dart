import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:smartsilence_contextual_quiet_mode/services/database_helper.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class ContextManager extends StatefulWidget {
  const ContextManager({super.key});

  @override
  State<ContextManager> createState() => _ContextManagerState();
}

class _ContextManagerState extends State<ContextManager> {

  //Default Location: Kuala Lumpur
  LatLng _selectedLocation = LatLng(3.1390, 101.6869);
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _savedContexts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadContexts();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      _mapController.move(_selectedLocation, 15.0);
    } catch (e) {
      print("Location Error: $e");
      setState(() => _isLoading = false,);
    }
  }

  Future<void> _loadContexts() async {
    final data = await DatabaseHelper().getAllContexts();
    setState(() {
      _savedContexts = data;
    });
  }

  Future<void> _addSelectedZone() async{
    TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Name this Silence Zone"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: "e.g., Library, Office"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async{
              if (nameController.text.isNotEmpty) {
                await DatabaseHelper().insertContext({
                  'name': nameController.text,
                  'type': 'GEOFENCE',
                  'value': '${_selectedLocation.latitude},${_selectedLocation.longitude}',
                  'radius': 100,
                  'is_active': 1
                });
                Navigator.pop(context);
                _loadContexts();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Zone Added!")));
              }
            },
            child: const Text("Save")
            )
        ],
      ),
    );
  }

  void _toggleContext(int id, bool currentStatus) async {
    await DatabaseHelper().toggleContext(id, currentStatus ? 0 : 1);
    _loadContexts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Quiet Zones")
      ),
      body: Stack(
        children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: 15.0,
                onTap: (tapPosition, point) {
                  setState(() {
                  _selectedLocation = point;
                  });
                }
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // Caching helps! It saves tiles you've already seen so they work offline later.
                  tileProvider: NetworkTileProvider(),
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation,
                      width: 80,
                      height: 80,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                  ],
                ),
              ],
             ),

          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.white.withOpacity(0.8),
              child: const Text(
                "Note: Map Images require internet. GPS works offline.",
                style: TextStyle(fontSize: 10, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            )
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey.shade200,
            child: Column(
              children: [
                Text("Tap map to adjust location", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 5),
                ElevatedButton.icon(
                  onPressed: _addSelectedZone,
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text("Set Silence Zone Here"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),

          Expanded(
            child: _savedContexts.isEmpty 
            ? const Center(child: Text("No Zones saved yet."))
            : ListView.builder(
              itemCount: _savedContexts.length,
              itemBuilder: (context, index){
                final zone = _savedContexts[index];
                return ListTile(
                  leading: const Icon(Icons.place, color: Colors.deepPurple),
                  title: Text(zone['name']),
                  subtitle: Text("Lat: ${zone['value'].toString().split(',')[0]}..."),
                  trailing: Switch(
                    value: zone['is_active'] == 1,
                    onChanged: (val) => _toggleContext(zone['id'], zone['is_active'] == 1),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}