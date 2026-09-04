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
// A
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
      // 1. Firestore Settings (Safe Initialization)
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (e) {
        debugPrint("Firestore Settings already set");
      }

      // 2. Auth with Timeout
      try {
        if (FirebaseAuth.instance.currentUser == null) {
          await FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 5));
        }
      } catch (authError) {
        debugPrint("Auth/Network Timeout: $authError");
      }

      // 3. Load Local User
      UserModel? user = await PrefService().getUser();

      if (user != null) {
        // 4. Background Sync (Does NOT block the app)
        // We trim the ID just in case there's a stray space in local storage
        final String currentUid = user.userId.trim();
        
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUid)
            .get()
            .then((userDoc) async {
          if (userDoc.exists && userDoc.data() != null) {
            try {
              var latestUser = UserModel.fromMap(userDoc.data()!, userDoc.id);
              await PrefService().saveUser(latestUser);
              debugPrint("Sync Complete: Latest data saved locally.");
            } catch (parseError) {
              debugPrint("Parsing Error: $parseError");
            }
          } else {
            // Document not found with exact ID, try searching by userId field
            var query = await FirebaseFirestore.instance
                .collection('users')
                .where('userId', isEqualTo: currentUid)
                .limit(1)
                .get();

            if (query.docs.isNotEmpty) {
              var latestUser = UserModel.fromMap(query.docs.first.data(), query.docs.first.id);
              await PrefService().saveUser(latestUser);
              debugPrint("Sync Complete (via Query): Latest data saved locally.");
            } else {
              // IMPORTANT: Don't force logout here to prevent accidental logouts 
              // on poor network or minor sync issues.
              debugPrint("User not found in Firestore sync, keeping local session.");
            }
          }
        }).catchError((e) {
          debugPrint("Background Sync Failed: $e");
        });

        // Setup Notifications
        NotificationService nService = NotificationService();
        nService.initialize().catchError((e) => debugPrint("Notification Init Error: $e"));
        nService.saveTokenToFirestore(currentUid).catchError((e) => debugPrint("Token Save Error: $e"));
      }

      return user;
    } catch (e) {
      debugPrint("Global Init Error: $e");
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
