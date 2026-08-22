import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/pref_service.dart';
import '../models/user_model.dart';
import 'main_navigation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  bool _isObscure = true;
  bool _isLoading = false;

  void _handleLogin() async {
    String userId = _userIdController.text.trim();
    String password = _passwordController.text.trim();

    if (userId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter User ID and Password")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserModel? user = await _dbService.verifyLogin(userId, password);

      if (user != null) {
        // --- BACKGROUND SECURITY HANDSHAKE (Required for Security Rules) ---
        await FirebaseAuth.instance.signInAnonymously();
        
        await PrefService().saveUser(user);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => MainNavigationScreen(user: user)),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid User ID or Password")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Official School Logo
              Image.asset('assets/icon/app_icon.png', width: 120, height: 120),
              const SizedBox(height: 20),
              const Text(
                "SWARAJ CONVENT SCHOOL",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              TextField(
                controller: _userIdController,
                decoration: const InputDecoration(
                  labelText: "User ID / Roll No",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: _passwordController,
                obscureText: _isObscure,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _isObscure = !_isObscure),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 40),
              
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("LOGIN TO DASHBOARD", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
              
              const SizedBox(height: 20),
              const Text(
                "In case of lost ID/Password, please contact School Admin.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
