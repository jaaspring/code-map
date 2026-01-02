import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:code_map/services/api_service.dart';
import '../../services/pdf_service.dart';
import '../career_roadmap/career_roadmap.dart';


class CareerAnalysisReport extends StatefulWidget {
  final String userTestId;
  final String jobIndex;
  final Map<String, dynamic>? gapAnalysisData;
  final int? attemptNumber;
  final bool? fromGapAnalysis;

  const CareerAnalysisReport({
    super.key,
    required this.userTestId,
    required this.jobIndex,
    this.gapAnalysisData,
    this.attemptNumber,
    this.fromGapAnalysis = false,
  });

  @override
  State<CareerAnalysisReport> createState() => _CareerAnalysisReportState();
}

class _CareerAnalysisReportState extends State<CareerAnalysisReport> {
  Map<String, dynamic>? report;
  Map<String, dynamic>? gapAnalysisData;
  bool isLoading = true;
  bool isLoadingGapAnalysis = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    gapAnalysisData = widget.gapAnalysisData;

    if (gapAnalysisData == null) {
      _fetchGapAnalysis();
    }

    _computeChartsAndFetchReport();
  }

  Future<void> _computeChartsAndFetchReport() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Step 1: Generate charts and capture them directly (to avoid race conditions)
      // This ensures we have the charts even if the report retrieval misses them initially
      List<Map<String, dynamic>> chartsList = [];
      try {
        chartsList = await ApiService.generateCharts(
          userTestId: widget.userTestId,
          attemptNumber: widget.attemptNumber ?? 1,
        );
      } catch (e) {
        print("Error generating charts: $e");
        // Continue to fetch report even if charts fail
      }

      // Step 2: Fetch report
      final reportResponse = await ApiService.generateReport(
        widget.userTestId,
        widget.jobIndex,
      );

      // Handle report response structure
      Map<String, dynamic>? reportData;
      if (reportResponse is List && reportResponse.isNotEmpty) {
        if (reportResponse[0] is Map<String, dynamic>) {
          reportData = reportResponse[0] as Map<String, dynamic>;
        }
      } else if (reportResponse is Map<String, dynamic>) {
        reportData = reportResponse;
      }

      if (reportData != null) {
        // Ensure data structure exists
        if (reportData['data'] == null) {
          reportData['data'] = <String, dynamic>{};
        }
        
        final data = reportData['data'];
        if (data is Map<String, dynamic>) {
          // Initialize charts map if missing
          if (data['charts'] == null) {
            data['charts'] = <String, dynamic>{};
          }

          // Merge charts from Step 1 into report data
          // This fixes the issue where charts might not be saved to DB fast enough
          if (chartsList.isNotEmpty && data['charts'] is Map) {
             final currentCharts = data['charts'] as Map;
             // chartsList is typically [{ "radar_chart": "...", "result_chart": "..." }] 
             // or [{ "chartName": "radar", ... }] depending on API impl.
             // Based on previous analysis, generateCharts returns a list containing the map of charts.
             
             for (var chartItem in chartsList) {
               chartItem.forEach((key, value) {
                 if (key != "chartName" && !currentCharts.containsKey(key)) {
                    currentCharts[key] = value;
                 }
               });
             }
          }

          setState(() {
            report = data;
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load report data';
          isLoading = false;
        });
      }

    } catch (e) {
      print("Error fetching report: $e");
      setState(() {
        errorMessage = 'Error loading report. Please try again.';
        isLoading = false;
      });
    }
  }

  Widget _buildChartImage(String? base64Data, String chartName, {BoxFit? fit}) {
    if (base64Data == null || base64Data.isEmpty) {
      return Container(
        height: 250,
        color: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, color: Colors.grey[600], size: 48),
              SizedBox(height: 8),
              Text(
                "Chart not available",
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }
    
    try {
      String cleanBase64 = base64Data;
      if (base64Data.contains(',')) {
        cleanBase64 = base64Data.split(',').last;
      }
      
      final chartBytes = base64Decode(cleanBase64);
      
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        child: Image.memory(
          chartBytes,
          fit: fit ?? BoxFit.contain, // Use correct fit
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(
                "Failed to render chart",
                style: TextStyle(color: Colors.grey),
              ),
            );
          },
        ),
      );
    } catch (e) {
      return Container(
        height: 250,
        color: Colors.grey[900],
        child: Center(
          child: Text(
            "Error decoding chart",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ),
      );
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

  Widget _buildGapAnalysisTable(Map<String, dynamic> data, String title) {
    if (data.isEmpty) return const SizedBox.shrink();

    final entries = data.entries.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.8),
                1: FlexColumnWidth(1.1),
                2: FlexColumnWidth(1.1),
                3: FlexColumnWidth(1.4), // increased for Status badge
              },
              border: TableBorder.all(color: Colors.white.withOpacity(0.1)),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                  ),
                  children: const [
                    Padding(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Text('Name',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey))),
                    Padding(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Text('Required',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey))),
                    Padding(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Text('Your Level',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey))),
                    Padding(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        child: Center( // Centered header for Status
                            child: Text('Status',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey)))),
                  ],
                ),
                ...entries.map((e) {
                  final value = e.value;
                  final requiredLevel = value is Map
                      ? (value['required_level'] ?? value['required'] ?? '-')
                      : (value.toString());

                  final userLevel =
                      value is Map ? (value['user_level'] ?? '-') : '-';

                  final status = value is Map ? (value['status'] ?? '-') : '-';

                  return TableRow(
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(e.key,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w500))),
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(requiredLevel.toString(),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13))),
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(userLevel.toString(),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13))),
                      Padding(
                        padding: const EdgeInsets.all(8.0), // reduced padding
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 60), // ensure min width
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4), // compacted padding
                            decoration: BoxDecoration(
                              color: status == 'Achieved'
                                  ? const Color(0xFF4BC945).withOpacity(0.15)
                                  : status == 'Weak'
                                      ? Colors.orange.withOpacity(0.15)
                                      : Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: status == 'Achieved'
                                    ? const Color(0xFF4BC945).withOpacity(0.4)
                                    : status == 'Weak'
                                        ? Colors.orange.withOpacity(0.4)
                                        : Colors.red.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              status.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: status == 'Achieved'
                                    ? const Color(0xFF4BC945)
                                    : status == 'Weak'
                                        ? Colors.orange
                                        : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportData = report;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Header with back button and centered logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Color.fromARGB(255, 255, 255, 255)),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                    Expanded(
                      child: Center(
                        child: Image.asset(
                          'assets/icons/logo_only_white.png',
                          height: 22, 
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance for back button
                  ],
                ),
              const SizedBox(height: 20),
              
              const Text(
                "Career Analysis Report",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Detailed comprehensive report of your skills",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              
              // Debug Info Panel
              if (errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[300], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: TextStyle(color: Colors.red[300], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              Expanded(
                child: isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF4BC945)),
                          SizedBox(height: 16),
                          Text(
                            "Generating charts and report...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "This may take a few seconds",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : reportData == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.description_outlined,
                                  size: 64, color: Colors.grey[700]),
                              const SizedBox(height: 16),
                              Text(
                                "No data found",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _computeChartsAndFetchReport,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF4BC945),
                                ),
                                child: Text("Retry"),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Profile Summary Card
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4BC945).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.account_circle,
                                              color: Color(0xFF4BC945), size: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          "Profile Summary",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
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
                                        color: Colors.grey[300],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Job Details Card
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4BC945).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.work,
                                              color: Color(0xFF4BC945), size: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          "Job Details",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    if (reportData['job'] != null) ...[
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.1),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.badge,
                                                color: Color(0xFF4BC945),
                                                size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                reportData['job']['job_title'] ??
                                                    'N/A',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
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
                                          color: Colors.grey[400],
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
                                          color: Colors.grey[300],
                                        ),
                                      ),
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
                              const SizedBox(height: 20),
                              
                              if (gapAnalysisData != null) ...[
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color:Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.analytics,
                                                color: Colors.redAccent, size: 24),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            "Detailed Gap Analysis",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            color: Colors.white,
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
                                const SizedBox(height: 20),
                              ] else if (isLoadingGapAnalysis) ...[
                                const Center(
                                  child: CircularProgressIndicator(color: Color(0xFF4BC945)),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Charts Card
                              if (reportData['charts'] != null && 
                                  (reportData['charts']['radar_chart'] != null || 
                                   reportData['charts']['result_chart'] != null)) ...[
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4BC945).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.radar,
                                                color: Color(0xFF4BC945),
                                                size: 24),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            "Career Analysis at a Glance",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),

                                      // Radar Chart
                                      if (reportData['charts']['radar_chart'] != null) ...[
                                        const Text(
                                          "Skill Gap Radar Chart",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          "Visual representation of your skills compared to job requirements",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          height: 280,
                                          child: _buildChartImage(
                                            reportData['charts']['radar_chart'],
                                            "Radar",
                                          ),
                                        ),
                                        const SizedBox(height: 30),
                                      ],

                                      // Test Result Performance Chart
                                      if (reportData['charts']['result_chart'] != null) ...[
                                        const Text(
                                          "Test Result Performance",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          "Overview of your test performance and accuracy",
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          height: 280,
                                          width: double.infinity,
                                          child: _buildChartImage(
                                            reportData['charts']['result_chart'],
                                            "Result",
                                            fit: BoxFit.fill,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Charts missing warning
                              if (reportData['charts'] == null || 
                                  (reportData['charts']['radar_chart'] == null && 
                                   reportData['charts']['result_chart'] == null)) ...[
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.orange),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Charts Not Available",
                                              style: TextStyle(
                                                color: Colors.orange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              "Chart data could not be generated. This may be due to insufficient data or a processing error.",
                                              style: TextStyle(
                                                color: Colors.orange[300],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 20),
                              ],

                              // Career Roadmap Button
                              if (widget.fromGapAnalysis == true) ...[
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: ElevatedButton(
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
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4BC945),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      elevation: 4,
                                      shadowColor: const Color(0xFF4BC945).withOpacity(0.4),
                                    ),
                                    child: const Text(
                                      "View your Personalized Career Roadmap",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ],
                          ),
                        ),
              ),
              const SizedBox(height: 16),
              if (!isLoading && reportData != null)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Generating PDF..."),
                            duration: Duration(seconds: 1),
                          ),
                        );
                        await PdfService.generateCareerReport(
                          reportData!,
                          gapAnalysisData,
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Failed to export PDF: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.download_rounded, color: Colors.white),
                    label: const Text(
                      "Download / Export as PDF",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4BC945),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFF4BC945).withOpacity(0.4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}