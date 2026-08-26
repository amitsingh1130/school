import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class FeeReportService {
  static Future<void> generateReceipt({
    required String studentName,
    required String classId,
    required String amount,
    required String receiptNo,
    required String feeTitle,
    required String academicSession,
    String? regNo,
    String? fatherName,
    String? motherName,
  }) async {
    final pdf = pw.Document();
    
    pw.MemoryImage? logoImage = await _loadLogo();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5, 
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildPdfHeader(logoImage, "Fee Payment Receipt"),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Receipt No: $receiptNo", style: const pw.TextStyle(fontSize: 9)),
                  pw.Text("Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 15),
              _infoRow("Student Name:", studentName),
              _infoRow("Reg. No.:", regNo ?? "N/A"),
              _infoRow("Father's Name:", fatherName ?? "N/A"),
              _infoRow("Mother's Name:", motherName ?? "N/A"),
              _infoRow("Class:", classId),
              _infoRow("Session:", academicSession),
              _infoRow("Payment For:", feeTitle),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(color: PdfColors.grey200, borderRadius: pw.BorderRadius.all(pw.Radius.circular(5))),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("TOTAL AMOUNT RECEIVED:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text("Rs. $amount", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text("Mode of Payment: Cash/Offline", style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 80, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5)))),
                      pw.Text("Receiver's Signature", style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text("This is a computer generated receipt.", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Receipt_${studentName}.pdf');
  }

  static Future<void> generateFeeCard({
    required String studentName,
    required String classId,
    required String academicSession,
    required List<Map<String, dynamic>> installments,
    required Map<String, Map<String, dynamic>> payments,
    String? regNo,
    String? fatherName,
    String? motherName,
  }) async {
    final pdf = pw.Document();
    pw.MemoryImage? logoImage = await _loadLogo();

    double totalRequired = 0;
    double totalPaid = 0;
    for (var inst in installments) {
      totalRequired += (inst['amount'] as num).toDouble();
      totalPaid += (payments[inst['feeTitle']]?['amount'] as num?)?.toDouble() ?? 0;
    }
    double totalPending = totalRequired - totalPaid;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (context) => [
          _buildPdfHeader(logoImage, "Annual Fee Card"),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Name: $studentName", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text("Father's Name: ${fatherName ?? 'N/A'}", style: const pw.TextStyle(fontSize: 10)),
                  pw.Text("Mother's Name: ${motherName ?? 'N/A'}", style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("Reg No: ${regNo ?? 'N/A'}", style: const pw.TextStyle(fontSize: 10)),
                  pw.Text("Class: $classId", style: const pw.TextStyle(fontSize: 10)),
                  pw.Text("Session: $academicSession", style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _tableCell("S.No", bold: true),
                  _tableCell("Fee Description", bold: true, alignLeft: true),
                  _tableCell("Required (Rs)", bold: true),
                  _tableCell("Paid (Rs)", bold: true),
                  _tableCell("Status", bold: true),
                  _tableCell("Pay Date", bold: true),
                ],
              ),
              for (int i = 0; i < installments.length; i++)
                pw.TableRow(
                  children: [
                    _tableCell("${i + 1}"),
                    _tableCell(installments[i]['feeTitle'], alignLeft: true),
                    _tableCell(installments[i]['amount'].toString()),
                    _tableCell(payments[installments[i]['feeTitle']]?['amount']?.toString() ?? "0"),
                    _tableCell(
                      (payments[installments[i]['feeTitle']]?['isPaid'] ?? false) ? "PAID" : "PENDING",
                      color: (payments[installments[i]['feeTitle']]?['isPaid'] ?? false) ? PdfColors.green : PdfColors.red,
                      bold: true,
                    ),
                    _tableCell(payments[installments[i]['feeTitle']]?['date'] ?? "-"),
                  ],
                ),
              // TOTAL ROW
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _tableCell(""),
                  _tableCell("TOTAL", bold: true, alignLeft: true),
                  _tableCell(totalRequired.toInt().toString(), bold: true),
                  _tableCell(totalPaid.toInt().toString(), bold: true),
                  _tableCell("Pending: ${totalPending.toInt()}", bold: true, color: PdfColors.red),
                  _tableCell(""),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text("Generated on: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.Column(
                children: [
                  pw.Container(width: 100, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1)))),
                  pw.Text("Principal Seal & Sign", style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'FeeCard_${studentName}.pdf');
  }

  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load('assets/icon/app_icon.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      return null;
    }
  }

  static pw.Widget _buildPdfHeader(pw.MemoryImage? logo, String subTitle) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          children: [
            if (logo != null) pw.Image(logo, width: 50, height: 50),
            pw.SizedBox(width: 10),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("SWARAJ CONVENT SCHOOL", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(subTitle, style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _tableCell(String text, {bool bold = false, bool alignLeft = false, PdfColor color = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: alignLeft ? pw.TextAlign.left : pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color),
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 80, child: pw.Text(label, style: const pw.TextStyle(fontSize: 10))),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }
}
