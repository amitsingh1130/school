import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';

class PrefService {
  static const String userKey = "logged_user";

  // Save User Data to Phone
  Future<void> saveUser(UserModel user) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String userJson = jsonEncode(user.toMap());
    await prefs.setString(userKey, userJson);
  }

  // Get User Data from Phone
  Future<UserModel?> getUser() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userJson = prefs.getString(userKey);
    if (userJson != null) {
      return UserModel.fromMap(jsonDecode(userJson));
    }
    return null;
  }

  // Remove User (Logout)
  Future<void> removeUser() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(userKey);
  }
}
