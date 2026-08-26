import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';
import '../models/user_model.dart';
import 'admin/admin_home.dart';
import 'admin/fee_management_screen.dart';
import 'teacher/teacher_home.dart';
import 'teacher/mark_attendance_screen.dart';
import 'teacher/upload_homework_screen.dart';
import 'student/student_home.dart';
import 'student/homework_list_screen.dart';
import 'common/profile_screen.dart';
import 'common/notifications_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final UserModel user;
  const MainNavigationScreen({super.key, required this.user});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  void _onSwitchTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> _getScreens() {
    final String role = widget.user.role;
    if (role == 'admin' || role == 'principal' || role == 'vice_principal') {
      return [
        AdminHomeScreen(user: widget.user),
        const FeeManagementScreen(),
        NotificationsScreen(user: widget.user, onSwitchTab: _onSwitchTab),
        ProfileScreen(user: widget.user),
      ];
    } else if (role == 'teacher') {
      return [
        TeacherHomeScreen(user: widget.user),
        // Unified Attendance Tab
        widget.user.classId != null 
            ? MarkAttendanceScreen(classId: widget.user.classId!, isTab: true)
            : const Center(child: Text("No Class Assigned")),
        // Unified Homework Tab
        UploadHomeworkScreen(teacher: widget.user, isTab: true),
        NotificationsScreen(user: widget.user, onSwitchTab: _onSwitchTab),
        ProfileScreen(user: widget.user),
      ];
    } else {
      return [
        StudentHomeScreen(user: widget.user),
        HomeworkListScreen(classId: widget.user.classId ?? ''),
        NotificationsScreen(user: widget.user, onSwitchTab: _onSwitchTab),
        ProfileScreen(user: widget.user),
      ];
    }
  }

  List<BottomNavigationBarItem> _getNavItems() {
    final lang = Provider.of<LanguageProvider>(context);
    final String role = widget.user.role;
    if (role == 'admin' || role == 'principal' || role == 'vice_principal') {
      return [
        BottomNavigationBarItem(icon: const Icon(Icons.home), label: lang.translate('home')),
        BottomNavigationBarItem(icon: const Icon(Icons.money), label: lang.translate('fee')),
        BottomNavigationBarItem(icon: const Icon(Icons.notifications), label: lang.translate('alert')),
        BottomNavigationBarItem(icon: const Icon(Icons.person), label: lang.translate('profile')),
      ];
    } else if (role == 'teacher') {
      return [
        BottomNavigationBarItem(icon: const Icon(Icons.home), label: lang.translate('home')),
        BottomNavigationBarItem(icon: const Icon(Icons.how_to_reg), label: lang.translate('attendance')),
        BottomNavigationBarItem(icon: const Icon(Icons.assignment), label: lang.translate('homework')),
        BottomNavigationBarItem(icon: const Icon(Icons.notifications), label: lang.translate('alert')),
        BottomNavigationBarItem(icon: const Icon(Icons.person), label: lang.translate('profile')),
      ];
    } else {
      return [
        BottomNavigationBarItem(icon: const Icon(Icons.home), label: lang.translate('home')),
        BottomNavigationBarItem(icon: const Icon(Icons.book), label: lang.translate('homework')),
        BottomNavigationBarItem(icon: const Icon(Icons.notifications), label: lang.translate('alert')),
        BottomNavigationBarItem(icon: const Icon(Icons.person), label: lang.translate('profile')),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    Color selectedColor = const Color(0xFFFFD700); // Default Yellow
    if (widget.user.role == 'principal') selectedColor = Colors.deepPurple;
    if (widget.user.role == 'vice_principal') selectedColor = Colors.indigo;

    return Scaffold(
      body: _getScreens()[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: selectedColor,
        backgroundColor: Colors.white,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: _getNavItems(),
      ),
    );
  }
}
