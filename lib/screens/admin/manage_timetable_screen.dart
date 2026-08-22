import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_timetable_screen.dart';

class ManageTimetableScreen extends StatefulWidget {
  const ManageTimetableScreen({super.key});

  @override
  State<ManageTimetableScreen> createState() => _ManageTimetableScreenState();
}

class _ManageTimetableScreenState extends State<ManageTimetableScreen> {
  String selectedDay = "Monday";
  final List<String> days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  
  final List<String> periodHeaders = [
    "PRAYER",
    "1st Subject",
    "2nd Subject",
    "3rd Subject",
    "4th Subject",
    "LUNCH",
    "5th Subject",
    "6th Subject",
    "7th Subject",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Weekly Timetable")),
      body: Column(
        children: [
          _buildDaySelector(),
          const Divider(),
          Expanded(child: _buildGridTable()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTimetableScreen())),
        backgroundColor: const Color(0xFFFFD700),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ChoiceChip(
            label: Text(days[index]),
            selected: selectedDay == days[index],
            onSelected: (s) => setState(() => selectedDay = days[index]),
            selectedColor: const Color(0xFFFFD700),
          ),
        ),
      ),
    );
  }

  Widget _buildGridTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('timetable').where('day', isEqualTo: selectedDay).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        Map<String, Map<String, dynamic>> gridData = {};
        Map<String, String> docIds = {};
        Map<String, dynamic> globalSlots = {}; 

        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String cls = data['classId'] ?? 'N/A';
          String period = data['period'] ?? ""; 
          
          if (cls == "ALL") {
            globalSlots[period] = data;
            globalSlots["${period}_docId"] = doc.id;
          } else {
            gridData.putIfAbsent(cls, () => {});
            gridData[cls]![period] = data;
            docIds["${cls}_$period"] = doc.id;
          }
        }

        var sortedClasses = gridData.keys.toList()..sort();

        if (sortedClasses.isEmpty && globalSlots.isEmpty) {
          return const Center(child: Text("No records found for this day. Click + to add."));
        }

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 70,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFFFD700).withOpacity(0.3)),
              border: TableBorder.all(color: Colors.grey.shade300),
              columnSpacing: 25,
              columns: [
                const DataColumn(label: Text("Class", style: TextStyle(fontWeight: FontWeight.bold))),
                ...periodHeaders.map((p) {
                  bool isSpecial = p == "PRAYER" || p == "LUNCH";
                  var globalData = globalSlots[p];
                  String timeText = globalData != null ? globalData['time'] : "(Click to set)";

                  return DataColumn(
                    label: InkWell(
                      onTap: isSpecial ? () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AddTimetableScreen(
                          timetableDocId: globalSlots["${p}_docId"],
                          currentData: globalData,
                          initialClass: "ALL",
                          initialSlot: p,
                          initialDay: selectedDay,
                        )));
                      } : null,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(p, style: TextStyle(fontWeight: FontWeight.bold, color: isSpecial ? Colors.red : Colors.black)),
                          if (isSpecial)
                            Text(timeText, style: const TextStyle(fontSize: 9, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  );
                }),
              ],
              rows: sortedClasses.map((cls) {
                return DataRow(cells: [
                  DataCell(Text(cls, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                  ...periodHeaders.map((period) {
                    bool isSpecial = period == "PRAYER" || period == "LUNCH";
                    
                    if (isSpecial) {
                      return DataCell(
                        Center(child: Text(period, style: TextStyle(color: Colors.red.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 9)))
                      );
                    }

                    var data = gridData[cls]![period];
                    String docId = docIds["${cls}_$period"] ?? "";
                    return DataCell(
                      InkWell(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => AddTimetableScreen(
                            timetableDocId: data != null ? docId : null,
                            currentData: data,
                            initialClass: cls,
                            initialSlot: period,
                            initialDay: selectedDay,
                          )));
                        },
                        child: _buildCellContent(data),
                      ),
                    );
                  }).toList(),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCellContent(Map<String, dynamic>? data) {
    if (data == null) return const Center(child: Icon(Icons.add_circle_outline, size: 18, color: Colors.grey));
    
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data['subject'] ?? "", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          Text(data['time'] ?? "--:--", style: const TextStyle(fontSize: 8, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('userId', isEqualTo: data['teacherId']).limit(1).snapshots(),
            builder: (context, snap) {
              String name = "Teacher...";
              if (snap.hasData && snap.data!.docs.isNotEmpty) name = snap.data!.docs.first['name'];
              return Text(name, style: const TextStyle(fontSize: 8, color: Colors.black54), overflow: TextOverflow.ellipsis);
            }
          ),
        ],
      ),
    );
  }
}
