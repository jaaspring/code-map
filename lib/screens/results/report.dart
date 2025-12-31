import 'dart:convert';

import 'package:code_map/services/api_service.dart';
import 'package:flutter/material.dart';
import '../career_roadmap/career_roadmap.dart';

class CareerAnalysisReport extends StatefulWidget {
  final String userTestId;
  final String jobIndex;
  final Map<String, dynamic>? gapAnalysisData;
  final int? attemptNumber; // needed for fetching gap analysis separately
  final bool?
      fromGapAnalysis; // flag to track if navigated from Gap Analysis Screen

  const CareerAnalysisReport({
    super.key,
    required this.userTestId,
    required this.jobIndex,
    this.gapAnalysisData,
    this.attemptNumber,
    this.fromGapAnalysis = false, // default to false
  });

  @override
  State<CareerAnalysisReport> createState() => _CareerAnalysisReportState();
}

class _CareerAnalysisReportState extends State<CareerAnalysisReport> {
  Map<String, dynamic>? report;
  Map<String, dynamic>? gapAnalysisData; // store gap analysis data
  bool isLoading = true;
  bool isLoadingGapAnalysis = false;

  @override
  void initState() {
    super.initState();

    // store gap analysis data from previous screen
    gapAnalysisData = widget.gapAnalysisData;

    // if no gap analysis data passed, fetch it
    if (gapAnalysisData == null) {
      _fetchGapAnalysis();
    }

    _computeChartsAndFetchReport();
  }

// New combined function
  Future<void> _computeChartsAndFetchReport() async {
    setState(() => isLoading = true);

    try {
      print('STARTED: Triggering chart computation...');
      await ApiService.generateCharts(
          userTestId: widget.userTestId,
          attemptNumber: widget.attemptNumber ?? 1);
      print('SUCCESS: Chart computation completed!');

      // Now fetch the report, charts should be ready
      final response =
          await ApiService.generateReport(widget.userTestId, widget.jobIndex);
      print("Report data fetched: $response");

      setState(() {
        report = response['data'];
        isLoading = false;
      });
    } catch (e, s) {
      print("Error during charts + report fetch: $e");
      print("Stack trace: $s");
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchGapAnalysis() async {
    try {
      setState(() => isLoadingGapAnalysis = true);

      final attemptNumber = widget.attemptNumber ?? 1;

      print("DEBUG: Fetching gap analysis with:");
      print("DEBUG: - userTestId: ${widget.userTestId}");
      print("DEBUG: - jobIndex: ${widget.jobIndex}");
      print("DEBUG: - attemptNumber: $attemptNumber");

      final response = await ApiService.getSingleGapAnalysis(
        userTestId: widget.userTestId,
        jobIndex: widget.jobIndex,
        attemptNumber: attemptNumber,
      );

      print("DEBUG: API Response: $response");

      if (response['data'] != null &&
          response['data']['gap_analysis'] != null) {
        setState(() {
          gapAnalysisData =
              Map<String, dynamic>.from(response['data']['gap_analysis']);
        });
        print("DEBUG: Successfully set gapAnalysisData");
      } else {
        print("DEBUG: No gap_analysis in response data");
        print("DEBUG: Response data structure: ${response['data']}");
      }
    } catch (e, s) {
      print("Failed to fetch gap analysis: $e");
      print("Stack trace: $s");
    } finally {
      setState(() => isLoadingGapAnalysis = false);
    }
  }

  // method to display gap analysis table (similar to Gap Analysis Screen)
  Widget _buildGapAnalysisTable(Map<String, dynamic> data, String title) {
    if (data.isEmpty) {
      print("DEBUG Table: $title data is empty!");
      return const SizedBox.shrink();
    }

    final entries = data.entries.toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(1),
              },
              border: TableBorder.all(color: Colors.grey.shade300),
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: Colors.grey),
                  children: [
                    Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Name',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white))),
                    Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Required',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white))),
                    Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('User Level',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white))),
                    Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Status',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white))),
                  ],
                ),
                ...entries.map((e) {
                  final value = e.value;
                  // handle different possible data structures
                  final requiredLevel = value is Map
                      ? (value['required_level'] ?? value['required'] ?? '-')
                      : (value.toString());

                  final userLevel =
                      value is Map ? (value['user_level'] ?? '-') : '-';

                  final status = value is Map ? (value['status'] ?? '-') : '-';

                  return TableRow(
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(8), child: Text(e.key)),
                      Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(requiredLevel.toString())),
                      Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(userLevel.toString())),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          status.toString(),
                          style: TextStyle(
                            color: status == 'Achieved'
                                ? Colors.green
                                : status == 'Weak'
                                    ? Colors.amber
                                    : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportData = report;

    // DEBUG: Check gap analysis data
    print("DEBUG Build: gapAnalysisData = $gapAnalysisData");
    if (gapAnalysisData != null) {
      print(
          "DEBUG Build: gapAnalysisData keys = ${gapAnalysisData!.keys.toList()}");
      print("DEBUG Build: skills = ${gapAnalysisData!['skills']}");
      print("DEBUG Build: knowledge = ${gapAnalysisData!['knowledge']}");
    }

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
                              ] else ...[
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (gapAnalysisData != null) ...[
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
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.analytics,
                                          color: Colors.red.shade700, size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      "Detailed Gap Analysis",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildGapAnalysisTable(
                                  Map<String, dynamic>.from(
                                      gapAnalysisData?['skills'] ?? {}),
                                  "Skills Comparison",
                                ),
                                _buildGapAnalysisTable(
                                  Map<String, dynamic>.from(
                                      gapAnalysisData?['knowledge'] ?? {}),
                                  "Knowledge Comparison",
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ] else if (isLoadingGapAnalysis) ...[
                        // Show loading while fetching gap analysis
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    "Loading Gap Analysis...",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

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

                                // Test Result Performance Chart
                                if (reportData['charts']['result_chart'] !=
                                    null) ...[
                                  const Text(
                                    "Test Result Performance",
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
                                            ['result_chart']),
                                        fit: BoxFit.contain,
                                        height: 250,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      // button to Career Roadmap Screen
                      if (widget.fromGapAnalysis == true) ...[
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CareerRoadmap(
                                        userTestId: widget.userTestId,
                                        jobIndex: widget.jobIndex,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                    "View your Personalized Career Roadmap"),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
