import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionProvider with ChangeNotifier {
  String _currentSession = "${DateTime.now().year}-${(DateTime.now().year + 1).toString().substring(2)}"; // Default e.g. 2024-25

  String get currentSession => _currentSession;

  SessionProvider() {
    _loadSession();
  }

  void _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedSession = prefs.getString('academic_session');
    if (savedSession != null) {
      _currentSession = savedSession;
      notifyListeners();
    }
  }

  void changeSession(String newSession) async {
    _currentSession = newSession;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('academic_session', newSession);
    notifyListeners();
  }
}
