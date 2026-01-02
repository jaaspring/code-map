import 'package:code_map/screens/results/report.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/badge_service.dart';

class GapAnalysisScreen extends StatefulWidget {
  final String userTestId;
  final String jobIndex;
  final int attemptNumber;
  final Map<String, dynamic>? preloadedGapData;

  const GapAnalysisScreen({
    super.key,
    required this.userTestId,
    required this.jobIndex,
    required this.attemptNumber,
    this.preloadedGapData,
  });

  @override
  State<GapAnalysisScreen> createState() => _GapAnalysisScreenState();
}

class _GapAnalysisScreenState extends State<GapAnalysisScreen> {
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

    // check if we have preloaded data
    if (widget.preloadedGapData != null) {
      print("DEBUG: Using preloaded gap data");
      setState(() {
        _gapData = Map<String, dynamic>.from(
            widget.preloadedGapData!["gap_analysis"] ?? {});
        _gapData!['job_title'] =
            widget.preloadedGapData!['job_title'] ?? "Selected Job";
        _isLoading = false;
      });

      // Trigger career_explore badge check
      final newBadges = await BadgeService.checkAndAwardBadge(trigger: 'career_explore');
      if (newBadges.isNotEmpty && mounted) {
        BadgeService.showBadgeDialog(context, newBadges);
      }
      return;
    }

    // fallback: fetch from API if no preloaded data
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
      
      // Trigger career_explore badge check
      final newBadges = await BadgeService.checkAndAwardBadge(trigger: 'career_explore');
      if (newBadges.isNotEmpty && mounted) {
        BadgeService.showBadgeDialog(context, newBadges);
      }
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Premium Gradient Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF4BC945), const Color(0xFF3AA036)],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
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
                    const SizedBox(width: 48),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  "Skill Gap Analysis",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Compare your skills with requirements",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const SizedBox(height: 12),
              
              // Canvas for content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                        color: Color(0xFF4BC945),
                      ))
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline,
                                      size: 48, color: Colors.red[300]),
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                        color: Colors.red[200], fontSize: 15),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              // Job Title Header
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4BC945).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFF4BC945).withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "TARGET ROLE",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                        color: const Color(0xFF4BC945).withOpacity(0.8),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _gapData?['job_title'] ?? 'Selected Job',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Analysis Tables
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      _buildTable(
                                          Map<String, dynamic>.from(
                                              _gapData?['skills'] ?? {}),
                                          "Skills Analysis"),
                                      _buildTable(
                                          Map<String, dynamic>.from(
                                              _gapData?['knowledge'] ?? {}),
                                          "Knowledge Analysis"),
                                      const SizedBox(height: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),

              // Bottom Button
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CareerAnalysisReport(
                          userTestId: widget.userTestId,
                          jobIndex: widget.jobIndex,
                          attemptNumber: widget.attemptNumber,
                          gapAnalysisData: _gapData,
                          fromGapAnalysis: true,
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
                    "View Detailed Report",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
);
  }
}
