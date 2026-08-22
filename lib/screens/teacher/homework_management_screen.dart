import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import 'upload_homework_screen.dart';
import 'homework_history_screen.dart';

class HomeworkManagementScreen extends StatelessWidget {
  final UserModel user;
  const HomeworkManagementScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Homework Management"),
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: "Upload New"),
              Tab(text: "My History"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            UploadHomeworkScreen(teacher: user, isTab: true),
            // Updated to show history based on teacherId
            HomeworkHistoryScreen(teacherId: user.userId, isTab: true),
          ],
        ),
      ),
    );
  }
}
