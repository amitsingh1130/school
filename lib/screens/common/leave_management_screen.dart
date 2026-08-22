import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'apply_leave_screen.dart';
import 'leave_history_screen.dart';

class LeaveManagementScreen extends StatelessWidget {
  final UserModel user;
  const LeaveManagementScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Leave Management"),
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: "Apply New"),
              Tab(text: "My History"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ApplyLeaveScreen(user: user, isTab: true),
            LeaveHistoryScreen(user: user, isTab: true),
          ],
        ),
      ),
    );
  }
}
