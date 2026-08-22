import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/pref_service.dart';
import '../login_screen.dart';
import 'settings_screen.dart';
import 'full_details_screen.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel user;
  const ProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(lang.translate('profile'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, backgroundColor: Color(0xFFFFF9C4), child: Icon(Icons.person, size: 50, color: Color(0xFFFFD700))),
            const SizedBox(height: 15),
            Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            
            // --- DETAILS OPTION (Hidden for Admin) ---
            if (user.role != 'admin')
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline, color: Color(0xFFFFD700)),
                  title: Text(user.role == 'student' ? "Student Details" : "Teacher Details"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => FullDetailsScreen(user: user)));
                  },
                ),
              ),
            if (user.role != 'admin') const SizedBox(height: 10),

            // --- SETTINGS OPTION ---
            Card(
              child: ListTile(
                leading: const Icon(Icons.settings, color: Color(0xFFFFD700)),
                title: Text(lang.translate('settings')),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
            ),
            
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700), 
                  foregroundColor: Colors.black, 
                  padding: const EdgeInsets.all(15)
                ),
                onPressed: () async {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Logout"),
                      content: const Text("Are you sure you want to sign out?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                        ElevatedButton(
                          onPressed: () async {
                            await PrefService().removeUser();
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          },
                          child: const Text("Logout"),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.logout),
                label: Text(lang.translate('logout')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
