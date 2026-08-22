import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/pref_service.dart';
import 'models/user_model.dart';
import 'services/notification_service.dart';
import 'services/language_provider.dart';
import 'services/session_provider.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 

  LanguageProvider langProvider = LanguageProvider();
  SessionProvider sessionProvider = SessionProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: langProvider),
        ChangeNotifierProvider.value(value: sessionProvider),
      ],
      child: const SchoolApp(),
    ),
  );
}

class SchoolApp extends StatefulWidget {
  const SchoolApp({super.key});

  @override
  State<SchoolApp> createState() => _SchoolAppState();
}

class _SchoolAppState extends State<SchoolApp> {
  Future<UserModel?>? _initTask;

  @override
  void initState() {
    super.initState();
    _initTask = _initializeApp();
  }

  Future<UserModel?> _initializeApp() async {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      try {
        if (FirebaseAuth.instance.currentUser == null) {
          await FirebaseAuth.instance.signInAnonymously();
        }
      } catch (authError) {
        debugPrint("Auth Error: $authError");
      }

      UserModel? user = await PrefService().getUser();

      if (user != null) {
        try {
          NotificationService nService = NotificationService();
          await nService.initialize();
          FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
          await nService.saveTokenToFirestore(user.userId);
        } catch (serviceError) {
          debugPrint("Background Services Error: $serviceError");
        }
      }
      return user;
    } catch (e) {
      debugPrint("Init Error: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    const Color schoolYellow = Color(0xFFFFD700);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SWARAJ CONVENT SCHOOL',
      locale: langProvider.currentLocale,
      supportedLocales: const [Locale('en'), Locale('hi')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: schoolYellow,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: schoolYellow,
          primary: schoolYellow,
          onPrimary: Colors.black,
          primaryContainer: schoolYellow,
          onPrimaryContainer: Colors.black,
          secondary: Colors.black,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
          tertiary: schoolYellow,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: schoolYellow,
          foregroundColor: Colors.black,
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: schoolYellow,
            foregroundColor: Colors.black,
            disabledBackgroundColor: schoolYellow.withOpacity(0.5),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            elevation: 3,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            side: const BorderSide(color: schoolYellow, width: 2),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: FutureBuilder<UserModel?>(
        future: _initTask,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/icon/app_icon.png', width: 120, height: 120),
                    const SizedBox(height: 20),
                    const Text(
                      "SWARAJ CONVENT SCHOOL",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return snapshot.data != null ? MainNavigationScreen(user: snapshot.data!) : const LoginScreen();
        },
      ),
    );
  }
}
