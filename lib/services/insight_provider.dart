import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class InsightProvider with ChangeNotifier {
  List<Map<String, dynamic>> _dailyData = [];
  bool _isRecommendationVisible = true;
  bool _isLoading = false;

  // Getters
  List<Map<String, dynamic>> get dailyData => _dailyData;
  bool get isRecommendationVisible => _isRecommendationVisible;
  bool get isLoading => _isLoading;

  // 1. Fetch Data from DB
  Future<void> loadInsights() async {
    _isLoading = true;
    notifyListeners(); // Tell UI to show loading spinner

    final data = await DatabaseHelper().getSilenceCountByDay();
    _dailyData = data;
    
    _isLoading = false;
    notifyListeners(); // Tell UI to show chart
  }

  // 2. Hide Recommendation (Ignore)
  void ignoreRecommendation() {
    _isRecommendationVisible = false;
    notifyListeners(); // Update UI instantly
  }

  // 3. Automate Schedule
  Future<void> automateSchedule(String day, String time) async {
    await DatabaseHelper().insertSchedule(day, time);
    
    _isRecommendationVisible = false; // Hide card after automating
    notifyListeners();
  }
}