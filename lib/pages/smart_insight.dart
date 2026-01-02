import 'package:flutter/material.dart';
import 'package:smartsilence_contextual_quiet_mode/services/database_helper.dart';

class SmartInsight extends StatefulWidget {
  const SmartInsight({super.key});

  @override
  State<SmartInsight> createState() => _SmartInsightState();
}

class _SmartInsightState extends State<SmartInsight> {
  // Control visibility of the recommendation card
  bool _isRecommendationVisible = true;

  void _refreshData() {
    setState(() {
      _isRecommendationVisible = true; // Show card again on refresh if valid
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Intelligent Insights"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: "Refresh Data",
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: DatabaseHelper().getSilenceCountByDay(),
          builder: (context, snapshot) {
            // --- LOADING STATE ---
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                  height: 200, child: Center(child: CircularProgressIndicator()));
            }

            // --- EMPTY STATE ---
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 50.0),
                  child: Text("No data available yet.\nKeep using the app!", 
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                ),
              );
            }

            // --- PROCESS DATA ---
            final processedData = _processData(snapshot.data!);
            
            // Find Peak Day
            Map<String, dynamic> peakDayData = processedData[0];
            for (var d in processedData) {
              if (d['count'] > peakDayData['count']) {
                peakDayData = d;
              }
            }
            
            String topDay = peakDayData['day']; // e.g., "Mon"
            int topCount = peakDayData['count'];

            // Grammar Map
            Map<String, String> fullDayNames = {
              "Mon": "Monday", "Tue": "Tuesday", "Wed": "Wednesday",
              "Thu": "Thursday", "Fri": "Friday", "Sat": "Saturday", "Sun": "Sunday"
            };
            String fullDayName = fullDayNames[topDay] ?? topDay;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Weekly Silence Pattern",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // --- CHART ---
                SizedBox(
                  height: 200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: processedData.map((dayData) {
                      int maxVal = (topCount == 0) ? 1 : topCount; 
                      double relativeHeight = (dayData['count'] / maxVal) * 150;
                      bool isPeak = dayData['day'] == topDay && topCount > 0;
                      
                      return _buildBar(
                        dayData['day'],
                        relativeHeight,
                        isPeak ? Colors.redAccent : Colors.blue,
                        dayData['count'].toString()
                      );
                    }).toList(),
                  ),
                ),
                
                const SizedBox(height: 30),

                // --- RECOMMENDATION CARD ---
                // Only show if: 
                // 1. User hasn't clicked Ignore/Automate (_isRecommendationVisible)
                // 2. We actually have data (topCount > 0)
                if (_isRecommendationVisible && topCount > 0) ...[
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
                              "You manually silence your phone frequently on $fullDayName ($topCount times). Shall I automate this for you?"),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // --- IGNORE BUTTON ---
                              TextButton(
                                onPressed: () {
                                  // Hides the card
                                  setState(() {
                                    _isRecommendationVisible = false;
                                  });
                                }, 
                                child: const Text("Ignore")
                              ),
                              const SizedBox(width: 8),

                              // --- AUTOMATE BUTTON ---
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white
                                ),
                                onPressed: () async {
                                  // 1. Save to Database
                                  // Defaulting to "2:00 PM" as per your example, 
                                  // or you can make this more dynamic later.
                                  await DatabaseHelper().insertSchedule(fullDayName, "14:00");

                                  if(!context.mounted) return;

                                  // 2. Show Success Message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Success! Auto-silence enabled for $fullDayName."),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 2),
                                    )
                                  );

                                  // 3. Hide the card (Mark as done)
                                  setState(() {
                                    _isRecommendationVisible = false;
                                  });
                                }, 
                                child: const Text("Automate")
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ]
              ],
            );
          },
        ),
      ),
    );
  }

  // --- HELPERS ---

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
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}