import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:smartsilence_contextual_quiet_mode/services/database_helper.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class ContextManager extends StatefulWidget {
  const ContextManager({super.key});

  @override
  State<ContextManager> createState() => _ContextManagerState();
}

class _ContextManagerState extends State<ContextManager> {
  LatLng _selectedLocation = const LatLng(3.1390, 101.6869); // Default KL
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _savedContexts = [];
  // ignore: unused_field
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadContexts() async {
    final data = await DatabaseHelper().getAllContexts();
    setState(() {
      _savedContexts = data;
    });
  }

  // --- ADD NEW ZONE ---
  Future<void> _addSelectedZone() async {
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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  await DatabaseHelper().insertContext({
                    'name': nameController.text,
                    'type': 'GEOFENCE',
                    'value':
                        '${_selectedLocation.latitude},${_selectedLocation.longitude}',
                    'radius': 100,
                    'is_active': 1
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    _loadContexts();
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Zone Added!")));
                  }
                }
              },
              child: const Text("Save"))
        ],
      ),
    );
  }

  // --- EDIT EXISTING ZONE ---
  Future<void> _editZone(Map<String, dynamic> zone) async {
    TextEditingController nameController =
        TextEditingController(text: zone['name']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Zone"),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: "Zone Name"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  // Update logic (Assuming generic update or using raw SQL via helper)
                  // If your helper doesn't have update, you might need to add it.
                  // Here is a generic SQL way if your helper exposes 'update':
                  await DatabaseHelper().updateContextName(zone['id'], nameController.text); 
                  
                  if (mounted) {
                    Navigator.pop(context);
                    _loadContexts();
                  }
                }
              },
              child: const Text("Update"))
        ],
      ),
    );
  }

  // --- DELETE ZONE ---
  Future<void> _deleteZone(int id) async {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Zone?"),
        content: const Text("Are you sure you want to remove this location?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () async {
                await DatabaseHelper().deleteContext(id);
                if (mounted) {
                  Navigator.pop(context);
                  _loadContexts();
                }
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red))),
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
      appBar: AppBar(title: const Text("Manage Quiet Zones")),
      // CHANGED: Use Column instead of Stack for the main layout
      body: Column(
        children: [
          // 1. THE MAP (Top Half - Fixed Height)
          SizedBox(
            height: 300, 
            child: Stack(
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
                      }),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      tileProvider: NetworkTileProvider(),
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation,
                          width: 80,
                          height: 80,
                          child: const Icon(Icons.location_on,
                              color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                  ],
                ),
                // Offline Notice
                Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.white.withOpacity(0.8),
                      child: const Text(
                        "Tap map to move pin. GPS works offline.",
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    )),
              ],
            ),
          ),

          // 2. THE ADD BUTTON (Middle)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            color: Colors.grey.shade100,
            child: ElevatedButton.icon(
              onPressed: _addSelectedZone,
              icon: const Icon(Icons.add_location_alt),
              label: const Text("Set Silence Zone Here"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white),
            ),
          ),

          // 3. THE LIST (Bottom Half - Fills remaining space)
          Expanded(
            child: _savedContexts.isEmpty
                ? const Center(child: Text("No Zones saved yet."))
                : ListView.builder(
                    itemCount: _savedContexts.length,
                    itemBuilder: (context, index) {
                      final zone = _savedContexts[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: ListTile(
                          leading:
                              const Icon(Icons.place, color: Colors.deepPurple),
                          title: Text(zone['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              "Lat: ${zone['value'].toString().split(',')[0].substring(0, 7)}..."),
                          
                          // Toggle Switch
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: zone['is_active'] == 1,
                                activeColor: Colors.deepPurple,
                                onChanged: (val) => _toggleContext(
                                    zone['id'], zone['is_active'] == 1),
                              ),
                              // Popup Menu for Edit/Delete
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _editZone(zone);
                                  if (value == 'delete') _deleteZone(zone['id']);
                                },
                                itemBuilder: (BuildContext context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Rename")]),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))]),
                                  ),
                                ],
                              ),
                            ],
                          ),
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