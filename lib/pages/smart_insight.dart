import 'package:flutter/material.dart';
import 'package:smartsilence_contextual_quiet_mode/services/database_helper.dart';

class SmartInsight extends StatelessWidget {
  const SmartInsight({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Intelligent Insights")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Weekly Silence Pattern", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // Simple Custom Bar Chart Visual
            FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper().getSilenceCountByDay(),
              builder: (context, snapshot) {
                if(!snapshot.hasData) return const LinearProgressIndicator();
                return SizedBox(
                  height: 200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildBar("Mon", 40, Colors.blue),
                      _buildBar("Tue", 80, Colors.redAccent), // High usage
                      _buildBar("Wed", 30, Colors.blue),
                      _buildBar("Thu", 90, Colors.redAccent), // High usage
                      _buildBar("Fri", 50, Colors.blue),
                      _buildBar("Sat", 20, Colors.grey),
                      _buildBar("Sun", 10, Colors.grey),
                    ],
                  ),
                );
              }
            ),
            const SizedBox(height: 30),
            
            const Text("Smart Recommendations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // Recommendation Card
            Card(
              color: Colors.indigo.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.orange),
                        SizedBox(width: 10),
                        Expanded(child: Text("Pattern Detected: Tuesdays at 2 PM", style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text("You manually silence your phone 80% of the time on Tuesdays afternoon. Shall I automate this?"),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () {}, child: const Text("Ignore")),
                        ElevatedButton(onPressed: () {}, child: const Text("Automate")),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(String label, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: height * 1.5,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}