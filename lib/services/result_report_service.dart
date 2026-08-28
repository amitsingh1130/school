import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ResultReportService {
  static Future<void> generateReportCard(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    
    // Load Logo
    pw.MemoryImage? logoImage;
    try {
      final bytes = await rootBundle.load('assets/icon/app_icon.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint("Logo Error: $e");
    }

    List subjects = data['subjects'] ?? [];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null) pw.Image(logoImage, width: 50, height: 50),
                      pw.SizedBox(width: 10),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("SWARAJ CONVENT SCHOOL", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                          pw.Text("Academic Report Card", style: const pw.TextStyle(fontSize: 11)),
                          pw.Text("Session: ${data['academicSession'] ?? 'N/A'}", style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(data['examName'] ?? 'Exam', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5),
              pw.SizedBox(height: 15),

              // --- STUDENT INFO ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.RichText(text: pw.TextSpan(children: [
                        const pw.TextSpan(text: "Name: ", style: pw.TextStyle(fontSize: 11)),
                        pw.TextSpan(text: "${data['studentName']}", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ])),
                      pw.Text("Class: ${data['classId']}", style: const pw.TextStyle(fontSize: 11)),
                      pw.Text("Roll No: ${data['rollNumber']}", style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // --- MARKS TABLE ---
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      _cell("S.No", bold: true),
                      _cell("Subject", bold: true, alignLeft: true),
                      _cell("Max Marks", bold: true),
                      _cell("Obtained", bold: true),
                      _cell("Grade", bold: true),
                    ],
                  ),
                  for (int i = 0; i < subjects.length; i++)
                    pw.TableRow(
                      children: [
                        _cell("${i + 1}"),
                        _cell(subjects[i]['name'] ?? '', alignLeft: true),
                        _cell(subjects[i]['max']?.toString() ?? '100'),
                        _cell(subjects[i]['obtained']?.toString() ?? '0'),
                        _cell(subjects[i]['grade'] ?? '-', bold: true),
                      ],
                    ),
                ],
              ),
              
              pw.SizedBox(height: 20),

              // --- SUMMARY ---
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Total Marks: ${data['totalObtained']} / ${data['totalMax']}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Percentage: ${data['percentage']}%", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                    pw.Text("Overall Grade: ${data['grade']}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                  ],
                ),
              ),

              pw.Spacer(),

              // --- FOOTER ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(children: [
                    pw.Container(width: 100, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide()))),
                    pw.Text("Class Teacher", style: const pw.TextStyle(fontSize: 10)),
                  ]),
                  pw.Column(children: [
                    pw.Container(width: 120, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide()))),
                    pw.Text("Principal Seal & Sign", style: const pw.TextStyle(fontSize: 10)),
                  ]),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(), 
      name: 'ReportCard_${data['studentName']}_${data['examName']}.pdf'
    );
  }

  static Future<void> generateConsolidatedReport({
    required String studentName,
    required String classId,
    required String rollNumber,
    required String academicSession,
    required List<Map<String, dynamic>> examResults,
  }) async {
    final pdf = pw.Document();
    
    pw.MemoryImage? logoImage;
    try {
      final bytes = await rootBundle.load('assets/icon/app_icon.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {}

    // 1. Identify all unique subjects across all exams
    Set<String> allSubjects = {};
    for (var res in examResults) {
      List subs = res['subjects'] ?? [];
      for (var s in subs) {
        if (s['name'] != null) allSubjects.add(s['name']);
      }
    }
    List<String> sortedSubjects = allSubjects.toList()..sort();

    // 2. Prepare headers (Dynamic Exam Columns)
    List<String> examNames = examResults.map((e) => e['examName']?.toString() ?? 'Exam').toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(30),
        build: (context) => [
          // HEADER
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(children: [
                if (logoImage != null) pw.Image(logoImage, width: 40, height: 40),
                pw.SizedBox(width: 10),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("SWARAJ CONVENT SCHOOL", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Consolidated Academic Statement", style: const pw.TextStyle(fontSize: 10)),
                ]),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text("Session: $academicSession", style: const pw.TextStyle(fontSize: 10)),
                pw.Text("Generated on: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 8)),
              ]),
            ],
          ),
          pw.Divider(),
          pw.SizedBox(height: 10),
          
          // STUDENT INFO
          pw.Row(children: [
            pw.Text("Name: ", style: const pw.TextStyle(fontSize: 10)),
            pw.Text(studentName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 30),
            pw.Text("Class: ", style: const pw.TextStyle(fontSize: 10)),
            pw.Text(classId, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(width: 30),
            pw.Text("Roll No: ", style: const pw.TextStyle(fontSize: 10)),
            pw.Text(rollNumber, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.SizedBox(height: 20),

          // CONSOLIDATED TABLE
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
            children: [
              // Header Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _cell("S.No", bold: true, size: 8),
                  _cell("Subject Name", bold: true, alignLeft: true, size: 8),
                  for (var name in examNames) _cell(name, bold: true, size: 8),
                  _cell("Total", bold: true, size: 8),
                  _cell("Grade", bold: true, size: 8),
                ],
              ),
              // Subject Rows
              for (int i = 0; i < sortedSubjects.length; i++)
                _buildSubjectRow(sortedSubjects[i], examResults, i + 1),
              
              // Total Row
              _buildTotalRow(examResults),
              // Percentage Row
              _buildPercentageRow(examResults),
            ],
          ),

          pw.SizedBox(height: 40),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(children: [
                pw.Container(width: 100, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5)))),
                pw.Text("Class Teacher", style: const pw.TextStyle(fontSize: 8)),
              ]),
              pw.Column(children: [
                pw.Container(width: 100, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5)))),
                pw.Text("Principal Seal & Sign", style: const pw.TextStyle(fontSize: 8)),
              ]),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Final_Result_$studentName.pdf');
  }

  static pw.TableRow _buildSubjectRow(String subName, List<Map<String, dynamic>> results, int index) {
    double rowTotalObtained = 0;
    double rowTotalMax = 0;

    List<pw.Widget> examMarks = [];
    for (var res in results) {
      List subs = res['subjects'] ?? [];
      var match = subs.firstWhere((s) => s['name'] == subName, orElse: () => null);
      if (match != null) {
        double ob = double.tryParse(match['obtained'].toString()) ?? 0;
        double mx = double.tryParse(match['max'].toString()) ?? 100;
        examMarks.add(_cell("$ob / $mx", size: 7));
        rowTotalObtained += ob;
        rowTotalMax += mx;
      } else {
        examMarks.add(_cell("-", size: 7));
      }
    }

    String grade = _calculateGrade((rowTotalObtained / (rowTotalMax > 0 ? rowTotalMax : 1)) * 100);

    return pw.TableRow(
      children: [
        _cell(index.toString(), size: 7),
        _cell(subName, alignLeft: true, size: 7),
        ...examMarks,
        _cell("$rowTotalObtained / $rowTotalMax", bold: true, size: 7),
        _cell(grade, bold: true, size: 7),
      ],
    );
  }

  static pw.TableRow _buildTotalRow(List<Map<String, dynamic>> results) {
    double grandObtained = 0;
    double grandMax = 0;

    List<pw.Widget> examTotals = [];
    for (var res in results) {
      double ob = double.tryParse(res['totalObtained'].toString()) ?? 0;
      double mx = double.tryParse(res['totalMax'].toString()) ?? 0;
      examTotals.add(_cell("$ob / $mx", bold: true, size: 7));
      grandObtained += ob;
      grandMax += mx;
    }

    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      children: [
        _cell(""),
        _cell("GRAND TOTAL", bold: true, alignLeft: true, size: 7),
        ...examTotals,
        _cell("$grandObtained / $grandMax", bold: true, size: 7),
        _cell("", size: 7),
      ],
    );
  }

  static pw.TableRow _buildPercentageRow(List<Map<String, dynamic>> results) {
    double grandObtained = 0;
    double grandMax = 0;

    List<pw.Widget> examPercs = [];
    for (var res in results) {
      double p = double.tryParse(res['percentage'].toString()) ?? 0;
      examPercs.add(_cell("$p%", bold: true, size: 7, color: PdfColors.blue));
      grandObtained += double.tryParse(res['totalObtained'].toString()) ?? 0;
      grandMax += double.tryParse(res['totalMax'].toString()) ?? 0;
    }

    double finalPerc = grandMax > 0 ? (grandObtained / grandMax) * 100 : 0;

    return pw.TableRow(
      children: [
        _cell(""),
        _cell("PERCENTAGE (%)", bold: true, alignLeft: true, size: 7),
        ...examPercs,
        _cell("${finalPerc.toStringAsFixed(1)}%", bold: true, size: 7, color: PdfColors.blue),
        _cell(_calculateGrade(finalPerc), bold: true, size: 7, color: PdfColors.green),
      ],
    );
  }

  static String _calculateGrade(double percentage) {
    if (percentage >= 91) return "A1";
    if (percentage >= 81) return "A2";
    if (percentage >= 71) return "B1";
    if (percentage >= 61) return "B2";
    if (percentage >= 51) return "C1";
    if (percentage >= 41) return "C2";
    if (percentage >= 33) return "D";
    return "E";
  }

  static pw.Widget _cell(String text, {bool bold = false, bool alignLeft = false, double size = 12, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
        style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: size, color: color),
      ),
    );
  }
}
