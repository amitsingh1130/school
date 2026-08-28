import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AttendanceReportService {
  static Future<void> showMonthPicker(BuildContext context, String classId) async {
    int selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Download Monthly Report"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Month:", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<int>(
                value: selectedMonth,
                isExpanded: true,
                items: List.generate(12, (index) => DropdownMenuItem(
                  value: index + 1, 
                  child: Text(DateFormat('MMMM').format(DateTime(2024, index + 1)))
                )),
                onChanged: (v) => setDialogState(() => selectedMonth = v!),
              ),
              const SizedBox(height: 15),
              const Text("Select Year:", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<int>(
                value: selectedYear,
                isExpanded: true,
                items: [2024, 2025, 2026].map((y) => DropdownMenuItem(
                  value: y, 
                  child: Text(y.toString())
                )).toList(),
                onChanged: (v) => setDialogState(() => selectedYear = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                generateMonthlyReport(classId: classId, month: selectedMonth, year: selectedYear);
              },
              child: const Text("GENERATE PDF"),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> showTeacherMonthPicker(BuildContext context) async {
    int selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Teacher Monthly Report"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Month:", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<int>(
                value: selectedMonth,
                isExpanded: true,
                items: List.generate(12, (index) => DropdownMenuItem(
                  value: index + 1, 
                  child: Text(DateFormat('MMMM').format(DateTime(2024, index + 1)))
                )),
                onChanged: (v) => setDialogState(() => selectedMonth = v!),
              ),
              const SizedBox(height: 15),
              const Text("Select Year:", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<int>(
                value: selectedYear,
                isExpanded: true,
                items: [2024, 2025, 2026].map((y) => DropdownMenuItem(
                  value: y, 
                  child: Text(y.toString())
                )).toList(),
                onChanged: (v) => setDialogState(() => selectedYear = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                generateTeacherMonthlyReport(month: selectedMonth, year: selectedYear);
              },
              child: const Text("GENERATE PDF"),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> generateMonthlyReport({required String classId, required int month, required int year}) async {
    final pdf = pw.Document();
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final daysInMonth = lastDay.day;

    // Load Logo
    pw.MemoryImage? logoImage = await _loadLogo();

    var studentSnap = await FirebaseFirestore.instance
        .collection('students')
        .where('classId', isEqualTo: classId)
        .get();
    
    var students = studentSnap.docs.map((d) => {
      'roll': d['rollNumber'].toString(),
      'name': d['name'].toString(),
    }).toList();
    
    students.sort((a, b) => (int.tryParse(a['roll']!) ?? 0).compareTo(int.tryParse(b['roll']!) ?? 0));

    Map<String, String> holidays = await _fetchHolidays(month, year, isTeacherReport: false, classId: classId);
    Map<String, Map<String, dynamic>> monthlyData = {};
    int totalClassWorkingDays = 0;

    for (int i = 1; i <= daysInMonth; i++) {
      DateTime current = DateTime(year, month, i);
      String dateStr = DateFormat('yyyy-MM-dd').format(current);
      bool isSunday = current.weekday == DateTime.sunday;
      bool isHoliday = holidays.containsKey(i.toString());

      var attDoc = await FirebaseFirestore.instance.collection('attendance').doc("${classId}_$dateStr").get();
      if (attDoc.exists) {
        monthlyData[i.toString()] = Map<String, dynamic>.from(attDoc['records']);
      }
      if (!isSunday && !isHoliday) totalClassWorkingDays++;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(15),
        build: (context) => [
          _buildHeader(logoImage, "Class: $classId", DateFormat('MMMM yyyy').format(firstDay)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey),
            children: [
              _buildTableHeader(daysInMonth, year, month, holidays, isTeacher: false),
              for (int j = 0; j < students.length; j++)
                _buildRow(students[j], monthlyData, daysInMonth, year, month, holidays, isTeacher: false, serial: (j + 1).toString()),
            ],
          ),
          pw.SizedBox(height: 15),
          _buildSummary(students, monthlyData, daysInMonth, year, month, holidays, totalClassWorkingDays),
        ],
      ),
    );

    await _printPdf(pdf, 'Attendance_${classId}_${DateFormat('MMM_yyyy').format(firstDay)}.pdf');
  }

  static Future<void> generateTeacherMonthlyReport({required int month, required int year}) async {
    final pdf = pw.Document();
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final daysInMonth = lastDay.day;

    pw.MemoryImage? logoImage = await _loadLogo();

    var staffSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: ['teacher', 'principal', 'vice_principal'])
        .get();
    var staff = staffSnap.docs.map((d) => {
      'id': d['userId'].toString(),
      'name': d['name'].toString(),
    }).toList();
    staff.sort((a, b) => a['name']!.compareTo(b['name']!));

    Map<String, String> holidays = await _fetchHolidays(month, year, isTeacherReport: true);
    Map<String, Map<String, dynamic>> monthlyData = {};
    int totalWorkingDays = 0;

    for (int i = 1; i <= daysInMonth; i++) {
      DateTime current = DateTime(year, month, i);
      String dateStr = DateFormat('yyyy-MM-dd').format(current);
      bool isSunday = current.weekday == DateTime.sunday;
      bool isHoliday = holidays.containsKey(i.toString());

      var attQuery = await FirebaseFirestore.instance.collection('teacher_attendance').where('date', isEqualTo: dateStr).get();
      Map<String, String> dayRecords = {};
      for (var doc in attQuery.docs) {
        String status = (doc['status'] ?? 'P').toString().toUpperCase();
        if (status == 'PRESENT') status = 'P';
        else if (status == 'ABSENT') status = 'A';
        else if (status.contains('HALF')) status = 'H';
        else if (status.contains('LEAVE')) status = 'L';
        else status = 'P'; // Default
        
        dayRecords[doc['teacherId']] = status;
      }
      monthlyData[i.toString()] = dayRecords;
      
      if (!isSunday && !isHoliday) totalWorkingDays++;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(15),
        build: (context) => [
          _buildHeader(logoImage, "STAFF ATTENDANCE", DateFormat('MMMM yyyy').format(firstDay)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey),
            children: [
              _buildTableHeader(daysInMonth, year, month, holidays, isTeacher: true),
              for (int j = 0; j < staff.length; j++)
                _buildRow(staff[j], monthlyData, daysInMonth, year, month, holidays, isTeacher: true, serial: (j + 1).toString()),
            ],
          ),
          pw.SizedBox(height: 15),
          _buildSummary(staff, monthlyData, daysInMonth, year, month, holidays, totalWorkingDays),
        ],
      ),
    );

    await _printPdf(pdf, 'Teacher_Attendance_${DateFormat('MMM_yyyy').format(firstDay)}.pdf');
  }

  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load('assets/icon/app_icon.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint("Attendance Logo Error: $e");
      return null;
    }
  }

  static Future<Map<String, String>> _fetchHolidays(int month, int year, {bool isTeacherReport = false, String? classId}) async {
    Map<String, String> holidays = {};
    var holidaySnap = await FirebaseFirestore.instance.collection('holidays').get();
    for (var doc in holidaySnap.docs) {
      DateTime dt = DateFormat('yyyy-MM-dd').parse(doc.id);
      if (dt.month == month && dt.year == year) {
        var data = doc.data() as Map<String, dynamic>;
        String target = data['target'] ?? "All School";
        String? targetClass = data['targetClass'];
        
        bool applies = false;
        if (isTeacherReport) {
          // Staff report: only "All School" applies
          if (target == "All School") applies = true;
        } else {
          // Student report: "All School", "Students Only", or "Specific Class"
          if (target == "All School" || target == "Students Only") {
            applies = true;
          } else if (target == "Specific Class" && targetClass == classId) {
            applies = true;
          }
        }

        if (applies) {
          holidays[dt.day.toString()] = data['reason'] ?? 'Holiday';
        }
      }
    }
    return holidays;
  }

  static pw.Widget _buildHeader(pw.MemoryImage? logo, String title, String date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(children: [
          if (logo != null) pw.Image(logo, width: 40, height: 40),
          pw.SizedBox(width: 10),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text("SWARAJ CONVENT SCHOOL", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text("Monthly Attendance Register", style: const pw.TextStyle(fontSize: 10)),
          ]),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text("Month: $date", style: const pw.TextStyle(fontSize: 10)),
        ]),
      ],
    );
  }

  static pw.TableRow _buildTableHeader(int days, int year, int month, Map<String, String> holidays, {required bool isTeacher}) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _cell(isTeacher ? "S.No" : "Roll", bold: true, width: 22),
        _cell(isTeacher ? "Teacher Name" : "Student Name", bold: true, width: 85, alignLeft: true),
        for (int i = 1; i <= days; i++) 
          _cell("$i", bold: true, width: 14, color: (DateTime(year, month, i).weekday == DateTime.sunday || holidays.containsKey(i.toString())) ? PdfColors.red : PdfColors.black),
        _cell("P", bold: true, width: 14),
        _cell("A", bold: true, width: 14),
        _cell("H", bold: true, width: 14),
        _cell("L", bold: true, width: 14),
        _cell("Cnt", bold: true, width: 18),
        _cell("%", bold: true, width: 28),
      ],
    );
  }

  static pw.TableRow _buildRow(Map<String, String> item, Map<String, Map<String, dynamic>> monthlyData, int daysInMonth, int year, int month, Map<String, String> holidays, {required bool isTeacher, required String serial}) {
    int p = 0, a = 0, h = 0, l = 0, totalWorking = 0;
    String idKey = isTeacher ? item['id']! : item['roll']!;
    
    List<pw.Widget> dayCells = [];
    for (int i = 1; i <= daysInMonth; i++) {
      bool isSunday = DateTime(year, month, i).weekday == DateTime.sunday;
      bool isHoliday = holidays.containsKey(i.toString());
      var status = _normalizeStatus(monthlyData[i.toString()]?[idKey]);
      
      if (!isSunday && !isHoliday) {
        if (status != "-") totalWorking++;
        if (status == "P") p++;
        if (status == "A") a++;
        if (status == "H") h++;
        if (status == "L") l++;
      }

      String cellText = status;
      PdfColor cellColor = status == "A" ? PdfColors.red : PdfColors.black;
      PdfColor? bgColor;

      if (isSunday) { cellText = "S"; cellColor = PdfColors.red300; bgColor = PdfColors.grey100; }
      else if (isHoliday) { cellText = "H"; cellColor = PdfColors.red; bgColor = PdfColors.grey200; }

      dayCells.add(pw.Container(width: 14, height: 12, alignment: pw.Alignment.center, decoration: bgColor != null ? pw.BoxDecoration(color: bgColor) : null, child: pw.Text(cellText, style: pw.TextStyle(fontSize: 6, color: cellColor, fontWeight: (isSunday || isHoliday) ? pw.FontWeight.bold : pw.FontWeight.normal))));
    }

    double percentage = totalWorking > 0 ? ((p + (h * 0.5)) / totalWorking) * 100 : 0.0;

    return pw.TableRow(children: [
      _cell(isTeacher ? serial : idKey),
      _cell(item['name']!, alignLeft: true),
      ...dayCells,
      _cell(p.toString(), bold: true),
      _cell(a.toString(), color: a > 0 ? PdfColors.red : PdfColors.black),
      _cell(h.toString()),
      _cell(l.toString()),
      _cell(totalWorking.toString()),
      _cell("${percentage.toStringAsFixed(1)}%"),
    ]);
  }

  static pw.Widget _buildSummary(List<Map<String, String>> items, Map<String, Map<String, dynamic>> monthlyData, int daysInMonth, int year, int month, Map<String, String> holidays, int workingDays) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(border: pw.TableBorder.all(width: 0.5)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text("SUMMARY", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text("Total Staff/Students: ${items.length}", style: const pw.TextStyle(fontSize: 7)),
            pw.Text("Total Working Days: $workingDays", style: const pw.TextStyle(fontSize: 7)),
            pw.Text("Average Attendance: ${_calculateClassAvg(items, monthlyData, daysInMonth, year, month, holidays)}%", style: const pw.TextStyle(fontSize: 7)),
            if (holidays.isNotEmpty) ...[
              pw.SizedBox(height: 5),
              pw.Text("Holidays:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              for (var entry in holidays.entries) pw.Text("${entry.key}: ${entry.value}", style: const pw.TextStyle(fontSize: 6)),
            ]
          ]),
        ),
        pw.Column(children: [
          pw.SizedBox(height: 20),
          pw.Row(children: [
            pw.Column(children: [
              pw.Container(width: 100, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5)))),
              pw.Text("Signature", style: const pw.TextStyle(fontSize: 8)),
            ]),
            pw.SizedBox(width: 40),
            pw.Column(children: [
              pw.Container(width: 100, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5)))),
              pw.Text("Principal Stamp & Sign", style: const pw.TextStyle(fontSize: 8)),
            ]),
          ]),
          pw.SizedBox(height: 5),
          pw.Text("Generated: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
        ]),
      ],
    );
  }

  static Future<void> _printPdf(pw.Document pdf, String filename) async {
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: filename);
  }

  static pw.Widget _cell(String text, {bool bold = false, bool alignLeft = false, double? width, PdfColor color = PdfColors.black}) {
    return pw.Container(width: width, padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 1), child: pw.Text(text, textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center, style: pw.TextStyle(fontSize: 6.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)));
  }

  static String _normalizeStatus(dynamic s) {
    if (s == null) return "-";
    String status = s.toString().toUpperCase();
    if (status == 'PRESENT' || status == 'P' || status == 'TRUE') return "P";
    if (status == 'ABSENT' || status == 'A' || status == 'FALSE') return "A";
    if (status == 'HALF DAY' || status == 'HD') return "H";
    if (status == 'ON LEAVE' || status == 'L') return "L";
    return "-";
  }

  static String _calculateClassAvg(List<Map<String, String>> items, Map<String, Map<String, dynamic>> monthlyData, int daysInMonth, int year, int month, Map<String, String> holidays) {
    if (items.isEmpty) return "0";
    double totalPercent = 0;
    for (var item in items) {
      int p = 0, h = 0, working = 0;
      String idKey = item.containsKey('roll') ? item['roll']! : item['id']!;
      for (int i = 1; i <= daysInMonth; i++) {
        if (DateTime(year, month, i).weekday == DateTime.sunday) continue;
        if (holidays.containsKey(i.toString())) continue;
        var status = _normalizeStatus(monthlyData[i.toString()]?[idKey]);
        if (status != "-") working++;
        if (status == "P") p++;
        if (status == "H") h++;
      }
      if (working > 0) totalPercent += ((p + (h * 0.5)) / working) * 100;
    }
    return (totalPercent / items.length).toStringAsFixed(1);
  }
}
