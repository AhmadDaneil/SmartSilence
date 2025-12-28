import 'package:flutter/material.dart';
import 'package:smartsilence_contextual_quiet_mode/services/database_helper.dart';

class SmartInsight extends StatefulWidget {
  const SmartInsight({super.key});

  @override
  State<SmartInsight> createState() => _SmartInsightState();
}

class _SmartInsightState extends State<SmartInsight> {
  // State to handle the "Ignore" button (hides the card)
  bool _isRecommendationVisible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Intelligent Insights")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: DatabaseHelper().getSilenceCountByDay(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                  height: 200, child: Center(child: CircularProgressIndicator()));
            }

            // 1. Process Data & Find the Peak Day
            final processedData = _processData(snapshot.data!);
            
            // Find the day with the highest count
            Map<String, dynamic> peakDayData = processedData[0];
            for (var d in processedData) {
              if (d['count'] > peakDayData['count']) {
                peakDayData = d;
              }
            }
            
            String topDay = peakDayData['day']; // e.g., "Tue"
            int topCount = peakDayData['count'];

            // Map "Tue" -> "Tuesday" for better grammar
            Map<String, String> fullDayNames = {
              "Mon": "Mondays", "Tue": "Tuesdays", "Wed": "Wednesdays",
              "Thu": "Thursdays", "Fri": "Fridays", "Sat": "Saturdays", "Sun": "Sundays"
            };
            String fullDayName = fullDayNames[topDay] ?? topDay;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Weekly Silence Pattern",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // --- CHART SECTION ---
                SizedBox(
                  height: 200,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: processedData.map((dayData) {
                      // Scale height (max 150)
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
                // ---------------------

                const SizedBox(height: 30),

                // Only show recommendation if we actually have data (count > 0)
                if (_isRecommendationVisible && topCount > 0) ...[
                  const Text("Smart Recommendations",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  // --- RECOMMENDATION CARD ---
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
                                  child: Text("Pattern Detected: $fullDayName", // Dynamic Day
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
                              // IGNORE BUTTON
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isRecommendationVisible = false;
                                  });
                                }, 
                                child: const Text("Ignore")
                              ),
                              
                              const SizedBox(width: 8),

                              // AUTOMATE BUTTON
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurple,
                                  foregroundColor: Colors.white
                                ),
                                onPressed: () {
                                  // 1. Show Feedback
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Auto-silence scheduled for every $fullDayName!"),
                                      backgroundColor: Colors.green,
                                    )
                                  );

                                  // 2. Hide the card (Action Complete)
                                  setState(() {
                                    _isRecommendationVisible = false;
                                  });

                                  // TODO: Insert into your Database here
                                  // DatabaseHelper().insertSchedule(fullDayName, "14:00"); 
                                }, 
                                child: const Text("Automate")
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ] else if (topCount == 0) ...[
                   // Fallback when no data exists yet
                   const Text("Smart Recommendations",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 10),
                   const Card(
                     child: Padding(
                       padding: EdgeInsets.all(16.0),
                       child: Text("Use the app for a few days to see smart insights here!"),
                     ),
                   )
                ]
              ],
            );
          },
        ),
      ),
    );
  }

  // --- HELPER METHODS ---

  List<Map<String, dynamic>> _processData(List<Map<String, dynamic>> dbData) {
    Map<String, int> weekMap = {
      'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0
    };

    for (var row in dbData) {
      String dayKey = row['day_name'].toString().substring(0, 3);
      int count = row['silence_count'] ?? 0;
      if (weekMap.containsKey(dayKey)) {
        weekMap[dayKey] = count;
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