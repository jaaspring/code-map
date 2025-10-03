import 'dart:convert';

import 'package:code_map/services/api_service.dart';
import 'package:flutter/material.dart';

class ReportScreen extends StatefulWidget {
  final String userTestId;
  final String jobIndex;

  const ReportScreen({
    super.key,
    required this.userTestId,
    required this.jobIndex,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Map<String, dynamic>? report;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchReport();
  }

  void fetchReport() async {
    try {
      final response =
          await ApiService.generateReport(widget.userTestId, widget.jobIndex);
      print("Report data: $response");
      setState(() {
        report = response['data'];
        isLoading = false;
      });
    } catch (e, s) {
      print("Error: $e");
      print("Stack: $s");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportData = report;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Career Analysis Report",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : reportData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        "No data found",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Info Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple.shade400,
                                Colors.deepPurple.shade600
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person,
                                      color: Colors.white.withOpacity(0.9),
                                      size: 20),
                                  const SizedBox(width: 8),
                                  const Text(
                                    "User Test ID",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                reportData['user_test_id'] ?? '-',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Profile Summary Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.account_circle,
                                        color: Colors.blue.shade700, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    "Profile Summary",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                reportData['profile_text'] ?? "No profile text",
                                textAlign: TextAlign.justify,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Job Details Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.work,
                                        color: Colors.green.shade700, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    "Job Details",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (reportData['job'] != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.amber.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.badge,
                                          color: Colors.amber.shade700,
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          reportData['job']['job_title'] ??
                                              'N/A',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Description",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  reportData['job']['job_description'] ?? 'N/A',
                                  textAlign: TextAlign.justify,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.5,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (reportData['job']['required_skills'] !=
                                    null) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.star,
                                          color: Colors.orange.shade600,
                                          size: 18),
                                      const SizedBox(width: 6),
                                      const Text(
                                        "Required Skills",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (reportData['job']
                                                ['required_skills']
                                            as Map<String, dynamic>)
                                        .keys
                                        .map<Widget>(
                                          (skill) => Chip(
                                            label: Text(
                                              skill,
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                            backgroundColor:
                                                Colors.blue.shade50,
                                            side: BorderSide(
                                              color: Colors.blue.shade200,
                                              width: 1,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                if (reportData['job']['required_knowledge'] !=
                                    null) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.school,
                                          color: Colors.purple.shade600,
                                          size: 18),
                                      const SizedBox(width: 6),
                                      const Text(
                                        "Required Knowledge",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (reportData['job']
                                                ['required_knowledge']
                                            as Map<String, dynamic>)
                                        .keys
                                        .map<Widget>(
                                          (knowledge) => Chip(
                                            label: Text(
                                              knowledge,
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                            backgroundColor:
                                                Colors.purple.shade50,
                                            side: BorderSide(
                                              color: Colors.purple.shade200,
                                              width: 1,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ] else
                                Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      "No job found",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

// Charts Card
                      if (reportData['charts'] != null) ...[
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.radar,
                                          color: Colors.teal.shade700,
                                          size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      "Career Analysis at a Glance",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Radar Chart
                                if (reportData['charts']['radar_chart'] !=
                                    null) ...[
                                  const Text(
                                    "Skill Gap Radar Chart",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Image.memory(
                                        base64Decode(reportData['charts']
                                            ['radar_chart']),
                                        fit: BoxFit.contain,
                                        height: 250,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                ],

                                // Difficulty Chart
                                if (reportData['charts']['difficulty_chart'] !=
                                    null) ...[
                                  const Text(
                                    "Performance by Difficulty",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Image.memory(
                                        base64Decode(reportData['charts']
                                            ['difficulty_chart']),
                                        fit: BoxFit.contain,
                                        height: 250,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                ],

                                // Type Chart
                                if (reportData['charts']['type_chart'] !=
                                    null) ...[
                                  const Text(
                                    "Performance by Question Type",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                          width: 1,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: Image.memory(
                                        base64Decode(
                                            reportData['charts']['type_chart']),
                                        fit: BoxFit.contain,
                                        height: 250,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
    );
  }
}
