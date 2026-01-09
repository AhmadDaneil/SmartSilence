import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class InsightProvider with ChangeNotifier {
  List<Map<String, dynamic>> _chartData = [];
  Map<String, dynamic> _peakData = {'day': 'Mon', 'count': 0};
  bool _isRecommendationVisible = true;
  bool _isLoading = false;

  // Getters
  List<Map<String, dynamic>> get chartData => _chartData;
  Map<String, dynamic> get peakData => _peakData;
  bool get isRecommendationVisible => _isRecommendationVisible;
  bool get isLoading => _isLoading;

  Future<void> loadInsights() async {
    _isLoading = true;
    notifyListeners();

    try {
      final rawData = await DatabaseHelper().getSilenceCountByDay();
      
      // Process data internally here
      _processData(rawData);
      
    } catch (e) {
      print("Error loading insights: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  void _processData(List<Map<String, dynamic>> dbData) {
    // 1. Initialize empty week
    Map<String, int> weekMap = {
      'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0
    };

    // 2. Fill with DB data
    for (var row in dbData) {
      if (row['day_name'] != null) {
        // Take first 3 letters (e.g., "Monday" -> "Mon")
        String dayKey = row['day_name'].toString().substring(0, 3);
        int count = row['silence_count'] ?? 0;
        
        if (weekMap.containsKey(dayKey)) {
          weekMap[dayKey] = count;
        }
      }
    }

    // 3. Convert to List for Chart
    _chartData = weekMap.entries.map((e) => {'day': e.key, 'count': e.value}).toList();

    // 4. Find Peak Day
    var peak = _chartData[0];
    for (var d in _chartData) {
      if (d['count'] > peak['count']) peak = d;
    }
    _peakData = peak;
  }

  void ignoreRecommendation() {
    _isRecommendationVisible = false;
    notifyListeners();
  }

  Future<void> automateSchedule(String day, String time) async {
    await DatabaseHelper().insertSchedule(day, time);
    _isRecommendationVisible = false;
    notifyListeners();
  }
}