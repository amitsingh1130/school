import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;

  LanguageProvider() {
    _loadLanguage();
  }

  void _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    String? langCode = prefs.getString('language_code');
    if (langCode != null) {
      _currentLocale = Locale(langCode);
      notifyListeners();
    }
  }

  void changeLanguage(String langCode) async {
    _currentLocale = Locale(langCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', langCode);
    notifyListeners();
  }

  String translate(String key) {
    String lang = _currentLocale.languageCode;
    if (_translations[lang] != null && _translations[lang]![key] != null) {
      return _translations[lang]![key]!;
    }
    return _translations['en']?[key] ?? key;
  }

  static final Map<String, Map<String, String>> _translations = {
    'en': {
      'app_title': 'SWARAJ CONVENT SCHOOL',
      'login_title': 'LOGIN INTO YOUR ACCOUNT',
      'user_id': 'User ID',
      'password': 'Password',
      'forgot_password': 'Forgot Password',
      'admin_dashboard': 'Admin Dashboard',
      'teacher_dashboard': 'Teacher Dashboard',
      'student_dashboard': 'Student Dashboard',
      'home': 'Home',
      'profile': 'Profile',
      'fee': 'Fee',
      'alert': 'Alert',
      'attendance': 'Attendance',
      'homework': 'Homework',
      'settings': 'Settings',
      'language': 'Language',
      'logout': 'LOGOUT',
      'apply_leave': 'Apply for Leave',
      'mark_attendance': 'Mark Attendance',
      'upload_homework': 'Upload Homework',
      'enter_marks': 'Enter Marks',
      'my_timetable': 'My Timetable',
    },
    'hi': {
      'app_title': 'स्वराज कॉन्वेंट स्कूल',
      'login_title': 'अपने खाते में लॉगिन करें',
      'user_id': 'यूजर आईडी',
      'password': 'पासवर्ड',
      'forgot_password': 'पासवर्ड भूल गए?',
      'admin_dashboard': 'एडमिन डैशबोर्ड',
      'teacher_dashboard': 'शिक्षक डैशबोर्ड',
      'student_dashboard': 'छात्र डैशबोर्ड',
      'home': 'होम',
      'profile': 'प्रोफ़ाइल',
      'fee': 'फीस',
      'alert': 'अलर्ट',
      'attendance': 'उपस्थिति',
      'homework': 'होमवर्क',
      'settings': 'सेटिंग्स',
      'language': 'भाषा',
      'logout': 'लॉगआउट',
      'apply_leave': 'छुट्टी के लिए आवेदन करें',
      'mark_attendance': 'उपस्थिति दर्ज करें',
      'upload_homework': 'होमवर्क अपलोड करें',
      'enter_marks': 'अंक दर्ज करें',
      'my_timetable': 'मेरी समय सारिणी',
    },
    'sa': {
      'app_title': 'स्वराज कॉन्वेंट विद्यालयः',
      'login_title': 'स्वकीयं खातां प्रविशतु',
      'user_id': 'प्रयोक्तृ परिचयः',
      'password': 'कूटशब्दः',
      'forgot_password': 'कूटशब्दं विस्मृतवान्?',
      'admin_dashboard': 'प्रशासक फलकम्',
      'teacher_dashboard': 'शिक्षक फलकम्',
      'student_dashboard': 'छात्र फलकम्',
      'home': 'मुख्यपृष्ठम्',
      'profile': 'पार्श्वचित्रम्',
      'fee': 'शुल्कम्',
      'alert': 'सूचना',
      'attendance': 'उपस्थितिः',
      'homework': 'गृहकार्यम्',
      'settings': 'विन्यासाः',
      'language': 'भाषा',
      'logout': 'निर्गमनम्',
      'apply_leave': 'विश्रामार्थं आवेदनम्',
      'mark_attendance': 'उपस्थितिं अङ्कयतु',
      'upload_homework': 'गृहकार्यं प्रेषयतु',
      'enter_marks': 'अङ्कान् लिखतु',
      'my_timetable': 'मम समयसारिणी',
    },
    'ur': {
      'app_title': 'سوراج کونونٹ اسکول',
      'login_title': 'اپنے اکاؤنٹ میں لاگ ان کریں',
      'user_id': 'صارف کی شناخت',
      'password': 'پاس ورڈ',
      'forgot_password': 'پاس ورڈ بھول گئے؟',
      'admin_dashboard': 'ایڈمن ڈیش بورڈ',
      'teacher_dashboard': 'ٹیچر ڈیش بورڈ',
      'student_dashboard': 'طالب علم ڈیش بورڈ',
      'home': 'ہوم',
      'profile': 'پروفائل',
      'fee': 'فیس',
      'alert': 'الرٹ',
      'attendance': 'حاضری',
      'homework': 'ہوم ورک',
      'settings': 'ترتیبات',
      'language': 'زبان',
      'logout': 'لاگ آؤٹ',
      'apply_leave': 'چھٹی کے لیے درخواست دیں',
      'mark_attendance': 'حاضری لگائیں',
      'upload_homework': 'ہوم ورک اپ لوڈ کریں',
      'enter_marks': 'نمبر درج کریں',
      'my_timetable': 'میرا ٹائم ٹیبل',
    }
  };
}
