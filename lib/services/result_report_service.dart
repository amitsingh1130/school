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

  static pw.Widget _cell(String text, {bool bold = false, bool alignLeft = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
        style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: 12),
      ),
    );
  }
}
