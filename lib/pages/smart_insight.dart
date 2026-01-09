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
    // Use addPostFrameCallback to safely call Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InsightProvider>().loadInsights();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the updated provider
    final provider = context.watch<InsightProvider>();
    final chartData = provider.chartData;
    final topData = provider.peakData;

    return Scaffold(
      appBar: AppBar(title: const Text("Intelligent Insights")),
      body: provider.isLoading
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
                  if (chartData.isEmpty || topData['count'] == 0)
                     Container(
                       height: 150, 
                       alignment: Alignment.center,
                       child: const Text("No silence patterns detected yet.\nUse the app for a few days!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                     )
                  else
                    SizedBox(
                      height: 200,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: chartData.map((dayData) {
                          // Calculate relative height safely
                          int maxVal = (topData['count'] == 0) ? 1 : topData['count'];
                          double relativeHeight = (dayData['count'] / maxVal) * 150;
                          
                          bool isPeak = dayData['day'] == topData['day'] && topData['count'] > 0;

                          return _buildBar(
                              dayData['day'],
                              relativeHeight,
                              isPeak ? Colors.deepPurple : Colors.deepPurple.shade200,
                              dayData['count'].toString());
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 30),

                  // --- RECOMMENDATION CARD ---
                  if (provider.isRecommendationVisible && topData['count'] > 0)
                    _buildRecommendationCard(context, topData['day'], topData['count']),
                ],
              ),
            ),
    );
  }

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
          elevation: 2,
          color: Colors.indigo.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.deepPurple),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text("Pattern Detected: $fullDayName",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                    "You silence your phone frequently on $fullDayName ($count times). Shall I automate this schedule?"),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => context.read<InsightProvider>().ignoreRecommendation(),
                      child: const Text("Ignore", style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                      onPressed: () {
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
    // Ensure minimum height so bar is visible even if value is small
    double displayHeight = height < 10 ? 10 : height; 
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(countText, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: 24,
          height: displayHeight,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
      ],
    );
  }
}