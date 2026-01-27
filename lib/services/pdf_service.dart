import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> generateCareerReport(
    Map<String, dynamic> reportData,
    Map<String, dynamic>? gapAnalysis,
  ) async {
    final pdf = pw.Document();

    // Load logo
    Uint8List? logoData;
    try {
      final byteData = await rootBundle.load('assets/icons/logo_black.png');
      logoData = byteData.buffer.asUint8List();
    } catch (e) {
      print("Error loading logo for PDF: $e");
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(logoData),
            pw.SizedBox(height: 20),
            _buildProfileSummary(reportData),
            pw.SizedBox(height: 20),
            _buildJobDetails(reportData),
            if (gapAnalysis != null) ...[
              pw.SizedBox(height: 20),
              _buildGapAnalysis(gapAnalysis),
            ],
            pw.SizedBox(height: 20),
            _buildCharts(reportData),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Career_Analysis_Report.pdf',
    );
  }

  static pw.Widget _buildHeader(Uint8List? logoData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (logoData != null) ...[
          pw.Center(
            child: pw.Image(
              pw.MemoryImage(logoData),
              height: 50,
              fit: pw.BoxFit.contain,
            ),
          ),
          pw.SizedBox(height: 20),
        ],
        pw.Text(
          "Career Analysis Report",
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          "Comprehensive analysis of your skills and career path.",
          style: pw.TextStyle(
            fontSize: 14,
            color: PdfColor.fromInt(0xFF616161), // Grey 700
          ),
        ),
        pw.Divider(thickness: 1, color: PdfColor.fromInt(0xFFE0E0E0)), // Grey 300
      ],
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 18,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFF37474F), // Blue Grey 800
        ),
      ),
    );
  }

  static pw.Widget _buildProfileSummary(Map<String, dynamic> data) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE0E0E0)), // Grey 300
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Profile Summary"),
          pw.Text(
            data['profile_text'] ?? "No profile text available.",
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
            textAlign: pw.TextAlign.justify,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildJobDetails(Map<String, dynamic> data) {
    final job = data['job'];
    if (job == null) return pw.SizedBox();

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE0E0E0)), // Grey 300
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Job Details"),
          pw.Text(
            job['job_title'] ?? "Unknown Job",
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            job['job_description'] ?? "No description available.",
            style: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
            textAlign: pw.TextAlign.justify,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildGapAnalysis(Map<String, dynamic> data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Gap Analysis"),
        if (data['skills'] != null) ...[
          pw.Text("Skills", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _buildTable(data['skills']),
          pw.SizedBox(height: 16),
        ],
        if (data['knowledge'] != null) ...[
          pw.Text("Knowledge", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _buildTable(data['knowledge']),
        ],
      ],
    );
  }

  static pw.Widget _buildTable(Map<String, dynamic> items) {
    final headers = ['Name', 'Required', 'Your Level', 'Status'];
    final rows = <List<String>>[];

    items.forEach((key, value) {
      if (value is Map) {
        rows.add([
          key,
          value['required_level']?.toString() ?? value['required']?.toString() ?? '-',
          value['user_level']?.toString() ?? '-',
          value['status']?.toString() ?? '-',
        ]);
      }
    });

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF37474F)), // Blue Grey 800
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
      },
      oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)), // Grey 100
      border: null,
      headerCellDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF37474F)), // Blue Grey 800
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromInt(0xFFEEEEEE)))), // Grey 200
      cellPadding: const pw.EdgeInsets.all(6),
    );
  }

  static pw.Widget _buildCharts(Map<String, dynamic> data) {
    final charts = data['charts'];
    if (charts == null) return pw.SizedBox();

    final List<pw.Widget> chartWidgets = [];

    if (charts['radar_chart'] != null && charts['radar_chart'].toString().isNotEmpty) {
      chartWidgets.add(
        pw.Column(
          children: [
            pw.Text("Skill Gap Radar Chart", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(
              "Visual representation of your skills compared to job requirements",
              style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF616161)),
            ),
            pw.SizedBox(height: 10),
            pw.Center(child: _buildImageFromBase64(charts['radar_chart'])),
            pw.SizedBox(height: 20),
          ],
        ),
      );
    }

    if (charts['knowledge_radar_chart'] != null && charts['knowledge_radar_chart'].toString().isNotEmpty) {
      chartWidgets.add(
        pw.Column(
          children: [
            pw.Text("Knowledge Gap Radar Chart", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(
              "Visual representation of your knowledge compared to job requirements",
              style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF616161)),
            ),
            pw.SizedBox(height: 10),
            pw.Center(child: _buildImageFromBase64(charts['knowledge_radar_chart'])),
            pw.SizedBox(height: 20),
          ],
        ),
      );
    }

    if (charts['result_chart'] != null && charts['result_chart'].toString().isNotEmpty) {
      chartWidgets.add(
        pw.Column(
          children: [
            pw.Text("Result Chart", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(
              "Overview of your test performance and accuracy",
              style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF616161)),
            ),
            pw.SizedBox(height: 10),
            pw.Center(child: _buildImageFromBase64(charts['result_chart'])),
          ],
        ),
      );
    }

    if (chartWidgets.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Charts"),
        ...chartWidgets,
      ],
    );
  }

  static pw.Widget _buildImageFromBase64(String base64String) {
    try {
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',').last;
      }
      
      final imageBytes = Uint8List.fromList(base64Decode(cleanBase64));
      return pw.Image(
        pw.MemoryImage(imageBytes),
        height: 200,
        fit: pw.BoxFit.contain,
      );
    } catch (e) {
      return pw.Container(
        height: 100,
        alignment: pw.Alignment.center,
        child: pw.Text("Error loading chart image", style: const pw.TextStyle(color: PdfColors.red)),
      );
    }
  }
}
