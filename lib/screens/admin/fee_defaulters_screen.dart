import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/session_provider.dart';
import '../../services/pref_service.dart';
import '../../models/user_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class FeeDefaultersScreen extends StatefulWidget {
  const FeeDefaultersScreen({super.key});

  @override
  State<FeeDefaultersScreen> createState() => _FeeDefaultersScreenState();
}

class _FeeDefaultersScreenState extends State<FeeDefaultersScreen> {
  String? _selectedClass;
  String? _selectedMonth;
  UserModel? _currentUser;
  bool _isLoadingUser = true;
  final List<String> _months = ["April", "May", "June", "July", "August", "September", "October", "November", "December", "January", "February", "March"];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await PrefService().getUser();
    setState(() {
      _currentUser = user;
      _isLoadingUser = false;
      // If teacher, pre-set the class and lock it
      if (user?.role == 'teacher') {
        _selectedClass = user?.classId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    final session = Provider.of<SessionProvider>(context).currentSession;
    bool isTeacher = _currentUser?.role == 'teacher';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Fee Status Tracking"),
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: "Defaulters", icon: Icon(Icons.warning_amber_rounded)),
              Tab(text: "Paid List", icon: Icon(Icons.check_circle_outline)),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  if (!isTeacher) // Only show class selector for Admins
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('students').snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const LinearProgressIndicator();
                          Set<String> classes = {};
                          for (var d in snapshot.data!.docs) { 
                            if (d['classId'] != null) classes.add(d['classId'].toString()); 
                          }
                          var sortedClasses = classes.toList()..sort();
                          return DropdownButtonFormField<String>(
                            value: _selectedClass,
                            decoration: const InputDecoration(labelText: "Class", border: OutlineInputBorder()),
                            items: sortedClasses.map((c) => DropdownMenuItem(value: c, child: Text("Class $c"))).toList(),
                            onChanged: (v) => setState(() => _selectedClass = v),
                          );
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                        child: Text("Class: ${_selectedClass ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedMonth,
                      decoration: const InputDecoration(labelText: "Month", border: OutlineInputBorder()),
                      items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (v) => setState(() => _selectedMonth = v),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildStatusList(session, showPaid: false),
                  _buildStatusList(session, showPaid: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusList(String session, {required bool showPaid}) {
    if (_selectedClass == null || _selectedMonth == null) {
      return const Center(child: Text("Please select a month to track fees"));
    }

    String feeTitle = "Monthly Fee - $_selectedMonth";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
          .where('role', isEqualTo: 'student')
          .where('classId', isEqualTo: _selectedClass)
          .snapshots(),
      builder: (context, studentSnap) {
        if (!studentSnap.hasData) return const Center(child: CircularProgressIndicator());
        var students = studentSnap.data!.docs;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('fees')
              .where('feeTitle', isEqualTo: feeTitle)
              .where('academicSession', isEqualTo: session)
              .snapshots(),
          builder: (context, paymentSnap) {
            if (!paymentSnap.hasData) return const Center(child: CircularProgressIndicator());
            
            Set<String> paidStudentIds = paymentSnap.data!.docs
                .map((d) => (d.data() as Map<String, dynamic>)['studentId'].toString())
                .toSet();

            var filteredList = students.where((s) {
              bool isPaid = paidStudentIds.contains(s['userId']);
              return showPaid ? isPaid : !isPaid;
            }).toList();

            // SORT BY ROLL NUMBER
            filteredList.sort((a, b) {
              int r1 = int.tryParse(a['rollNumber']?.toString() ?? '999') ?? 999;
              int r2 = int.tryParse(b['rollNumber']?.toString() ?? '999') ?? 999;
              return r1.compareTo(r2);
            });

            if (filteredList.isEmpty) {
              return Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(showPaid ? Icons.pending : Icons.check_circle, color: Colors.grey, size: 60),
                  const SizedBox(height: 10),
                  Text(showPaid ? "No one has paid yet." : "Everyone has paid!", 
                       style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ],
              ));
            }

            return ListView.builder(
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                var s = filteredList[index].data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: showPaid ? Colors.green.shade50 : Colors.red.shade50,
                      child: Text(s['name'][0], style: TextStyle(color: showPaid ? Colors.green : Colors.red)),
                    ),
                    title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Roll: ${s['rollNumber']} | Parent Mobile: ${s['mobile'] ?? 'N/A'}"),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!showPaid && s['mobile'] != null)
                          IconButton(
                            icon: const Icon(Icons.call, color: Colors.blue),
                            onPressed: () => _makePhoneCall(s['mobile']),
                          ),
                        Text(showPaid ? "PAID" : "UNPAID", 
                             style: TextStyle(color: showPaid ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw 'Could not launch $launchUri';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Parent Mobile: $phoneNumber"),
            action: SnackBarAction(
              label: "COPY NUMBER",
              onPressed: () {
                Clipboard.setData(ClipboardData(text: phoneNumber));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Number copied to clipboard!")));
              },
            ),
          ),
        );
      }
    }
  }
}
