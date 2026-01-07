import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartsilence_contextual_quiet_mode/services/insight_provider.dart';

class SmartInsight extends StatefulWidget {
  const SmartInsight({super.key});

  @override
  State<SmartInsight> createState() => _SmartInsightState();
}

class _SmartInsightState extends State<SmartInsight> {
  
  @override
  void initState() {
    super.initState();
    // Fetch data once when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InsightProvider>(context, listen: false).loadInsights();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider for changes
    final insightProvider = context.watch<InsightProvider>();
    final processedData = _processData(insightProvider.dailyData);
    final topData = _getPeakDay(processedData);

    return Scaffold(
      appBar: AppBar(title: const Text("Intelligent Insights")),
      body: insightProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Weekly Silence Pattern",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),

                  // --- CHART ---
                  if (processedData.isEmpty)
                     const SizedBox(height: 150, child: Center(child: Text("No data yet")))
                  else
                    SizedBox(
                      height: 200,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: processedData.map((dayData) {
                          int maxVal = (topData['count'] == 0) ? 1 : topData['count'];
                          double relativeHeight = (dayData['count'] / maxVal) * 150;
                          bool isPeak = dayData['day'] == topData['day'] && topData['count'] > 0;

                          return _buildBar(
                              dayData['day'],
                              relativeHeight,
                              isPeak ? Colors.redAccent : Colors.blue,
                              dayData['count'].toString());
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 30),

                  // --- RECOMMENDATION CARD ---
                  if (insightProvider.isRecommendationVisible && topData['count'] > 0)
                    _buildRecommendationCard(context, topData['day'], topData['count']),
                ],
              ),
            ),
    );
  }

  // --- WIDGETS EXTRACTED FOR CLEANLINESS ---

  Widget _buildRecommendationCard(BuildContext context, String dayCode, int count) {
    Map<String, String> fullNames = {
      "Mon": "Monday", "Tue": "Tuesday", "Wed": "Wednesday",
      "Thu": "Thursday", "Fri": "Friday", "Sat": "Saturday", "Sun": "Sunday"
    };
    String fullDayName = fullNames[dayCode] ?? dayCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Smart Recommendations",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Card(
          color: Colors.indigo.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text("Pattern Detected: $fullDayName",
                            style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                    "You silence your phone frequently on $fullDayName ($count times). Shall I automate this?"),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      // Call Provider Method
                      onPressed: () => context.read<InsightProvider>().ignoreRecommendation(),
                      child: const Text("Ignore"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                      onPressed: () {
                        // Call Provider Method
                        context.read<InsightProvider>().automateSchedule(fullDayName, "14:00");
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Automated for $fullDayName!")));
                      },
                      child: const Text("Automate"),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBar(String label, double height, Color color, String countText) {
    double displayHeight = height < 4 ? 4 : height;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(countText, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 5),
        Container(
          width: 20,
          height: displayHeight,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  // --- DATA HELPERS ---
  
  List<Map<String, dynamic>> _processData(List<Map<String, dynamic>> dbData) {
    Map<String, int> weekMap = {
      'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0
    };
    for (var row in dbData) {
      if (row['day_name'] != null) {
        String dayKey = row['day_name'].toString().substring(0, 3);
        int count = row['silence_count'] ?? 0;
        if (weekMap.containsKey(dayKey)) weekMap[dayKey] = count;
      }
    }
    return weekMap.entries.map((e) => {'day': e.key, 'count': e.value}).toList();
  }

  Map<String, dynamic> _getPeakDay(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return {'day': 'Mon', 'count': 0};
    var peak = data[0];
    for (var d in data) {
      if (d['count'] > peak['count']) peak = d;
    }
    return peak;
  }
}