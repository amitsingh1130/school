import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageLeavesScreen extends StatefulWidget {
  final String viewRole; // 'teacher' or 'student'
  final String? classId; // Optional: filter by class if provided (for teachers)

  const ManageLeavesScreen({super.key, required this.viewRole, this.classId});

  @override
  State<ManageLeavesScreen> createState() => _ManageLeavesScreenState();
}

class _ManageLeavesScreenState extends State<ManageLeavesScreen> {
  void _showActionDialog(String docId, String status) {
    final TextEditingController remarkController = TextEditingController();
    final bool isReject = status == 'rejected';
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("${status[0].toUpperCase()}${status.substring(1)} Leave"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Enter a remark/reason for this ${status}${isReject ? ' (Compulsory)' : ''}:"),
                const SizedBox(height: 10),
                TextField(
                  controller: remarkController,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: isReject ? "Reason for rejection is required" : "e.g. Approved for family function",
                  ),
                  maxLines: 2,
                  onChanged: (v) => setDialogState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: (isReject && remarkController.text.trim().isEmpty) 
                  ? null 
                  : () async {
                      await _updateStatus(docId, status, remarkController.text.trim());
                      if (context.mounted) Navigator.pop(ctx);
                    },
                style: ElevatedButton.styleFrom(
                  backgroundColor: status == 'approved' ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Confirm"),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _updateStatus(String docId, String status, String remark) async {
    await FirebaseFirestore.instance.collection('leaves').doc(docId).update({
      'status': status,
      'adminRemark': remark,
      'respondedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Leave Request $status")));
    }
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('leaves')
        .where('role', isEqualTo: widget.viewRole);
    
    // Apply class filter if provided
    if (widget.classId != null) {
      query = query.where('classId', isEqualTo: widget.classId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        int pendingCount = 0;
        int historyCount = 0;

        if (snapshot.hasData) {
          var docs = snapshot.data!.docs;
          pendingCount = docs.where((doc) => (doc['status'] ?? 'pending') == 'pending').length;
          historyCount = docs.length - pendingCount;
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.classId != null 
                  ? "Class ${widget.classId} Leaves" 
                  : "Manage ${widget.viewRole[0].toUpperCase()}${widget.viewRole.substring(1)} Leaves"),
              bottom: TabBar(
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.black,
                tabs: [
                  Tab(text: "Pending ($pendingCount)"),
                  Tab(text: "History ($historyCount)"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildListView(snapshot, 'pending'),
                _buildListView(snapshot, 'history'),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildListView(AsyncSnapshot<QuerySnapshot> snapshot, String type) {
    if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
    
    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return Center(child: Text("No records found for ${widget.viewRole}s."));
    }

    var allDocs = snapshot.data!.docs;
    List<DocumentSnapshot> filteredLeaves = [];

    if (type == 'pending') {
      filteredLeaves = allDocs.where((doc) {
        String s = (doc['status'] ?? 'pending').toString().toLowerCase();
        return s == 'pending';
      }).toList();
    } else {
      filteredLeaves = allDocs.where((doc) {
        String s = (doc['status'] ?? 'pending').toString().toLowerCase();
        return s != 'pending';
      }).toList();
    }

    // Robust Sort - latest first
    filteredLeaves.sort((a, b) {
      Timestamp? ta = _getTimestamp(a);
      Timestamp? tb = _getTimestamp(b);
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });

    if (filteredLeaves.isEmpty) {
      return Center(child: Text(type == 'pending' ? "No pending requests." : "No history found."));
    }

    return ListView.builder(
      itemCount: filteredLeaves.length,
      itemBuilder: (context, index) {
        var doc = filteredLeaves[index];
        var data = doc.data() as Map<String, dynamic>;
        String status = (data['status'] ?? 'pending').toString().toLowerCase();
        String leaveType = data['leaveType'] ?? 'Full Day';
        String sessionInfo = (leaveType == 'Half Day') ? " (${data['halfDaySession']})" : "";

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            title: Text(data['name'] ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Type: $leaveType$sessionInfo", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                Text("Date: ${data['startDate']} ${leaveType == 'Full Day' ? 'to ' + data['endDate'] : ''}"),
              ],
            ),
            trailing: _getStatusChip(status),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Role: ${data['role']}"),
                    Text("Class ID: ${data['classId'] ?? 'N/A'}"),
                    const SizedBox(height: 5),
                    Text("Reason: ${data['reason'] ?? 'No reason provided'}"),
                    if (data['adminRemark'] != null && data['adminRemark'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text("Remark: ${data['adminRemark']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      ),
                    const SizedBox(height: 15),
                    if (status == 'pending')
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _showActionDialog(doc.id, 'rejected'),
                            child: const Text("Reject", style: TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () => _showActionDialog(doc.id, 'approved'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text("Approve", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Timestamp? _getTimestamp(DocumentSnapshot doc) {
    try {
      return doc.get('appliedAt') as Timestamp?;
    } catch (e) {
      try {
        return doc.get('createdAt') as Timestamp?;
      } catch (e2) {
        return null;
      }
    }
  }

  Widget _getStatusChip(String status) {
    Color color = Colors.orange;
    if (status == 'approved') color = Colors.green;
    if (status == 'rejected') color = Colors.red;
    return Chip(
      label: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
      backgroundColor: color,
    );
  }
}
