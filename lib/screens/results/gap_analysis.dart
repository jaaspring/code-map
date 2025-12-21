import 'package:code_map/screens/results/report.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class SkillGapAnalysisScreen extends StatefulWidget {
  final String userTestId;
  final String jobIndex;

  const SkillGapAnalysisScreen({
    super.key,
    required this.userTestId,
    required this.jobIndex,
  });

  @override
  State<SkillGapAnalysisScreen> createState() => _SkillGapAnalysisScreenState();
}

class _SkillGapAnalysisScreenState extends State<SkillGapAnalysisScreen> {
  Map<String, dynamic>? _gapData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchGapAnalysis();
  }

  Future<void> _fetchGapAnalysis() async {
    setState(() => _isLoading = true);

    try {
      final allGaps =
          await ApiService.getGapAnalysis(userTestId: widget.userTestId);

      print("DEBUG: total gaps fetched = ${allGaps.length}");
      print("DEBUG: looking for job_index = ${widget.jobIndex}");

      Map<String, dynamic>? gapEntry;
      for (var g in allGaps) {
        final jobIndex = g["job_index"]?.toString().trim();
        print("DEBUG: found job_index = $jobIndex");
        if (jobIndex == widget.jobIndex.trim()) {
          gapEntry = g;
          break;
        }
      }

      if (gapEntry == null || gapEntry["gap_analysis"] == null) {
        setState(() {
          _errorMessage =
              "No gap analysis found for this job.\nCheck your backend data!";
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _gapData = Map<String, dynamic>.from(gapEntry?["gap_analysis"]);
        _gapData!['job_title'] = gapEntry?['job_title'] ?? "Selected Job";
        _isLoading = false;
      });
    } catch (e, st) {
      print("ERROR fetching gap analysis: $e\n$st");
      setState(() {
        _errorMessage = "Failed to fetch gap analysis: $e";
        _isLoading = false;
      });
    }
  }

  Widget _buildTable(Map<String, dynamic> data, String title) {
    if (data.isEmpty) return const SizedBox.shrink();
    final entries = data.entries.toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  final status = e.value['status'] ?? '-';
                  return TableRow(
                    children: [
                      Padding(
                          padding: const EdgeInsets.all(8), child: Text(e.key)),
                      Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(e.value['required_level'] ??
                              e.value['required'] ??
                              '-')),
                      Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(e.value['user_level'] ?? '-')),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          status,
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
    return Scaffold(
      appBar: AppBar(title: const Text("Skill Gap Analysis")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Suggested Career Path:",
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _gapData?['job_title'] ?? 'Selected Job',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTable(
                                Map<String, dynamic>.from(
                                    _gapData?['skills'] ?? {}),
                                "Skills"),
                            _buildTable(
                                Map<String, dynamic>.from(
                                    _gapData?['knowledge'] ?? {}),
                                "Knowledge"),
                          ],
                        ),
                      ),
                    ),

                    // buttons at the bottom
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
                                  builder: (context) => ReportScreen(
                                    userTestId: widget.userTestId,
                                    jobIndex: widget.jobIndex,
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                                "Generate Your IT Career Path Report"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
