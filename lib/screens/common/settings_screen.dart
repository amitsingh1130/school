import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
import '../../services/session_provider.dart';
import '../../models/user_model.dart';
import '../../services/pref_service.dart';
import '../admin/reports_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    final sessionProvider = Provider.of<SessionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(langProvider.translate('settings')),
      ),
      body: ListView(
        children: [
          // LANGUAGE OPTION
          ListTile(
            leading: const Icon(Icons.language, color: Color(0xFFFFD700)),
            title: Text(langProvider.translate('language')),
            subtitle: Text(_getLanguageName(langProvider.currentLocale.languageCode)),
            onTap: () => _showLanguageDialog(context, langProvider),
          ),
          
          // SESSION & REPORTS OPTIONS FOR ADMIN
          FutureBuilder<UserModel?>(
            future: PrefService().getUser(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.role == 'admin') {
                return Column(
                  children: [
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.history_edu, color: Color(0xFFFFD700)),
                      title: const Text("Academic Session"),
                      subtitle: Text("Active: ${sessionProvider.currentSession}"),
                      onTap: () => _showSessionDialog(context, sessionProvider),
                    ),
                    ListTile(
                      leading: const Icon(Icons.bar_chart, color: Color(0xFFFFD700)),
                      title: const Text("School Analytics & Reports"),
                      subtitle: const Text("View total fees, strength & activities"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
                      },
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'hi': return 'हिन्दी (Hindi)';
      case 'sa': return 'संस्कृतम् (Sanskrit)';
      case 'ur': return 'اردو (Urdu)';
      default: return 'English';
    }
  }

  void _showLanguageDialog(BuildContext context, LanguageProvider langProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(langProvider.translate('language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _langOption(context, langProvider, 'en', 'English'),
            _langOption(context, langProvider, 'hi', 'हिन्दी (Hindi)'),
            _langOption(context, langProvider, 'sa', 'संस्कृतम् (Sanskrit)'),
            _langOption(context, langProvider, 'ur', 'اردو (Urdu)'),
          ],
        ),
      ),
    );
  }

  void _showSessionDialog(BuildContext context, SessionProvider sessionProvider) {
    List<String> sessions = ["2023-24", "2024-25", "2025-26", "2026-27"];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Academic Session"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: sessions.map((s) => ListTile(
            title: Text(s),
            trailing: sessionProvider.currentSession == s ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () {
              sessionProvider.changeSession(s);
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  Widget _langOption(BuildContext context, LanguageProvider langProvider, String code, String name) {
    return ListTile(
      title: Text(name),
      trailing: langProvider.currentLocale.languageCode == code ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () {
        langProvider.changeLanguage(code);
        Navigator.pop(context);
      },
    );
  }
}
