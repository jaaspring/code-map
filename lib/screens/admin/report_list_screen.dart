import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:code_map/screens/user/assessment_screen.dart';
import 'package:flutter/material.dart';
import 'package:code_map/services/api_service.dart';
import '../results/report.dart';

class ReportListScreen extends StatefulWidget {
  const ReportListScreen({super.key});

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  // Design constants matching ReportHistoryScreen/HomeScreen
  static const Color geekGreen = Color(0xFF4BC945);
  static const Color backgroundColor = Color(0xFF000000);
  static const Color cardBackground = Color(0xFF121212);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF666666);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // List of all assessment attempts across all users
  // Each item will contain the attempt data + user info
  List<Map<String, dynamic>> _allAttempts = [];
  bool _isLoading = true;

  // Track expanded state and loaded jobs for each assessment (keyed by testId)
  final Map<String, bool> _expandedStates = {};
  final Map<String, List<Map<String, dynamic>>> _loadedJobs = {};
  final Map<String, bool> _loadingJobs = {};

  @override
  void initState() {
    super.initState();
    _loadAllUserAssessments();
  }

  Future<void> _loadAllUserAssessments() async {
    try {
      // Get all users
      final usersSnapshot = await _firestore.collection('users').get();
      final loadedAttempts = <Map<String, dynamic>>[];

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userInfo = {
          'uid': userDoc.id,
          'name': userData['name'] ?? 'Unknown User',
          'email': userData['email'] ?? 'No Email',
          'photoUrl': userData['photoUrl'],
        };

        if (userData.containsKey('assessmentAttempts')) {
          final attemptsData = userData['assessmentAttempts'];
          if (attemptsData is List) {
            for (final attempt in attemptsData) {
              if (attempt is Map<String, dynamic>) {
                loadedAttempts.add({
                  ...attempt,
                  'userInfo': userInfo, // Attach user info to the attempt
                });
              }
            }
          }
        }
      }

      // Sort by completedAt date (newest first)
      loadedAttempts.sort((a, b) {
        final dateA = DateTime.tryParse(a['completedAt'] ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['completedAt'] ?? '') ?? DateTime(1970);
        return dateB.compareTo(dateA);
      });

      // Initialize expanded states
      for (final attempt in loadedAttempts) {
        final testId = attempt['testId'] ?? '';
        if (testId.isNotEmpty) {
          _expandedStates[testId] = false;
        }
      }

      if (mounted) {
        setState(() {
          _allAttempts = loadedAttempts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading all assessments: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Load jobs for a specific test
  Future<void> _loadJobsForTest(String testId) async {
    // Don't reload if already loaded
    if (_loadedJobs.containsKey(testId) && _loadedJobs[testId]!.isNotEmpty) {
      return;
    }

    setState(() {
      _loadingJobs[testId] = true;
    });

    try {
      final response = await ApiService.getAllRecommendedJobs(testId);
      final jobs = <Map<String, dynamic>>[];

      if (response['data'] is List) {
        final jobsList = response['data'] as List;
        for (var job in jobsList) {
          jobs.add({
            'job_index': job['job_index'].toString(),
            'job_title': job['job_title'] ?? 'Unknown Job',
            'job_description': job['job_description'] ?? '',
            'similarity_percentage':
                job['similarity_percentage']?.toString() ?? '0',
            'report_data': null,
          });
        }
      }

      // Sort jobs by similarity percentage (highest first)
      jobs.sort((a, b) {
        final aPercent =
            double.tryParse(a['similarity_percentage']?.toString() ?? '0') ?? 0;
        final bPercent =
            double.tryParse(b['similarity_percentage']?.toString() ?? '0') ?? 0;
        return bPercent.compareTo(aPercent);
      });

      if (mounted) {
        setState(() {
          _loadedJobs[testId] = jobs;
          _loadingJobs[testId] = false;
        });
      }
    } catch (e) {
      print('Error fetching jobs for test $testId: $e');
      if (mounted) {
        setState(() {
          _loadingJobs[testId] = false;
        });
      }
    }
  }

  // Toggle expansion
  void _toggleExpansion(String testId) {
    final isExpanding = !(_expandedStates[testId] ?? false);

    setState(() {
      _expandedStates[testId] = isExpanding;
    });

    // Load jobs when expanding
    if (isExpanding) {
      _loadJobsForTest(testId);
    }
  }

  // Navigate to AssessmentReportScreen
  // Note: CareerAnalysisReport might need updates if it strictly relies on current user auth,
  // but usually passing userTestId is enough for fetching report data if the API allows it.
  void _navigateToAssessmentReport(
    BuildContext context,
    String userTestId,
    String jobIndex,
    int attemptNumber,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CareerAnalysisReport(
          userTestId: userTestId,
          jobIndex: jobIndex,
          attemptNumber: attemptNumber,
          fromGapAnalysis: false,
        ),
      ),
    );
  }

  // Helper methods for UI
  Color _getSimilarityColor(double percentage) {
    if (percentage >= 80) return const Color(0xFF4CAF50); // Green
    if (percentage >= 70) return const Color(0xFF81C784); // Light Green
    if (percentage >= 60) return const Color(0xFFFFB74D); // Orange
    return const Color(0xFFE57373); // Red
  }

  String _getRankingIcon(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$rank';
    }
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${_getMonth(dateTime.month)} ${dateTime.day}, ${dateTime.year}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  String _getMonth(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      // Minimal AppBar for Admin Navigation
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: geekGreen),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'All User Reports',
          style: TextStyle(color: geekGreen),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistics / Header info
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Row(
                  children: [
                    const Text(
                      'Total Assessments:',
                      style: TextStyle(
                        fontSize: 14,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_allAttempts.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: geekGreen,
                          strokeWidth: 2,
                        ),
                      )
                    : _allAttempts.isNotEmpty
                        ? ListView.separated(
                            itemCount: _allAttempts.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final attempt = _allAttempts[index];
                              final attemptNumber = attempt['attemptNumber'] ?? 0;
                              final testId = attempt['testId'] ?? '';
                              final completedAt = attempt['completedAt'] ?? '';
                              final status = attempt['status'] ?? '';
                              final userInfo = attempt['userInfo'] as Map<String, dynamic>? ?? {};
                              final userName = userInfo['name'] ?? 'Unknown';
                              final userEmail = userInfo['email'] ?? 'No Email';
                              
                              final isExpanded = _expandedStates[testId] ?? false;
                              final jobs = _loadedJobs[testId] ?? [];
                              final isLoadingJobs = _loadingJobs[testId] ?? false;

                              return Material(
                                color: Colors.transparent,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cardBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.05),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Assessment header (User info + Basic info)
                                      InkWell(
                                        onTap: () => _toggleExpansion(testId),
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(12),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            children: [
                                              // User Info Row
                                              Row(
                                                children: [
                                                   CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor: geekGreen.withOpacity(0.2),
                                                    child: Text(
                                                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                                      style: const TextStyle(
                                                        color: geekGreen, 
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          userName,
                                                          style: const TextStyle(
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.bold,
                                                            color: textPrimary,
                                                          ),
                                                        ),
                                                        Text(
                                                          userEmail,
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color: textSecondary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      '#$attemptNumber',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              const Divider(height: 1, color: Colors.white10),
                                              const SizedBox(height: 12),
                                              
                                              // Assessment Info Row
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          _formatDateTime(completedAt),
                                                          style: const TextStyle(
                                                            fontSize: 13,
                                                            color: textSecondary,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Row(
                                                          children: [
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: status == 'Completed'
                                                                    ? geekGreen.withOpacity(0.1)
                                                                    : Colors.orange.withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Text(
                                                                status,
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: status == 'Completed'
                                                                      ? geekGreen
                                                                      : Colors.orange,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Icon(
                                                    isExpanded
                                                        ? Icons.expand_less
                                                        : Icons.expand_more,
                                                    color: geekGreen,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Expanded job recommendations section
                                      if (isExpanded) ...[
                                        Divider(
                                          height: 1,
                                          color: Colors.white.withOpacity(0.1),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.work_outline,
                                                    size: 20,
                                                    color: geekGreen,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Text(
                                                    'Career Recommendations',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  if (jobs.isNotEmpty)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: geekGreen.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        '${jobs.length} jobs',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: geekGreen,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),

                                              // Jobs list
                                              if (isLoadingJobs)
                                                const Center(
                                                  child: Padding(
                                                    padding: EdgeInsets.all(16.0),
                                                    child: CircularProgressIndicator(
                                                      color: geekGreen,
                                                      strokeWidth: 2,
                                                    ),
                                                  ),
                                                )
                                              else if (jobs.isEmpty)
                                                const Padding(
                                                  padding: EdgeInsets.all(16.0),
                                                  child: Column(
                                                    children: [
                                                      Icon(
                                                        Icons.work_off_outlined,
                                                        size: 48,
                                                        color: textSecondary,
                                                      ),
                                                      SizedBox(height: 8),
                                                      Text(
                                                        'No job recommendations found',
                                                        style: TextStyle(
                                                          color: textSecondary,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else
                                                Column(
                                                  children: jobs
                                                      .asMap()
                                                      .entries
                                                      .map(
                                                    (entry) {
                                                      final rank = entry.key + 1;
                                                      final job = entry.value;
                                                      final similarity =
                                                          double.tryParse(job['similarity_percentage']?.toString() ?? '0') ?? 0;

                                                      return Card(
                                                        color: cardBackground,
                                                        margin: const EdgeInsets.only(bottom: 12),
                                                        elevation: 0,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(10),
                                                          side: BorderSide(
                                                            color: Colors.white.withOpacity(0.05),
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: Padding(
                                                          padding: const EdgeInsets.all(12),
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Row(
                                                                children: [
                                                                  // Ranking badge
                                                                  Container(
                                                                    width: 36,
                                                                    height: 36,
                                                                    decoration: BoxDecoration(
                                                                      color: _getSimilarityColor(similarity).withOpacity(0.1),
                                                                      borderRadius: BorderRadius.circular(8),
                                                                      border: Border.all(
                                                                        color: _getSimilarityColor(similarity),
                                                                        width: 2,
                                                                      ),
                                                                    ),
                                                                    child: Center(
                                                                      child: Text(
                                                                        _getRankingIcon(rank),
                                                                        style: const TextStyle(fontSize: 16),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 12),
                                                                  Expanded(
                                                                    child: Column(
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        Text(
                                                                          job['job_title'],
                                                                          style: const TextStyle(
                                                                            fontSize: 15,
                                                                            fontWeight: FontWeight.w600,
                                                                            color: textPrimary,
                                                                          ),
                                                                          maxLines: 2,
                                                                          overflow: TextOverflow.ellipsis,
                                                                        ),
                                                                        const SizedBox(height: 4),
                                                                        Row(
                                                                          children: [
                                                                            Expanded(
                                                                              child: LinearProgressIndicator(
                                                                                value: similarity / 100,
                                                                                backgroundColor: Colors.white.withOpacity(0.1),
                                                                                valueColor: AlwaysStoppedAnimation<Color>(_getSimilarityColor(similarity)),
                                                                                borderRadius: BorderRadius.circular(4),
                                                                                minHeight: 8,
                                                                              ),
                                                                            ),
                                                                            const SizedBox(width: 8),
                                                                            Text(
                                                                              '${similarity.toStringAsFixed(1)}% match',
                                                                              style: TextStyle(
                                                                                fontSize: 12,
                                                                                fontWeight: FontWeight.bold,
                                                                                color: _getSimilarityColor(similarity),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                              const SizedBox(height: 8),
                                                              Text(
                                                                job['job_description'] ?? '',
                                                                style: const TextStyle(
                                                                  fontSize: 13,
                                                                   color: textSecondary,
                                                                  height: 1.4,
                                                                ),
                                                                maxLines: 2,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                              const SizedBox(height: 12),
                                                              SizedBox(
                                                                width: double.infinity,
                                                                child: ElevatedButton(
                                                                  onPressed: () {
                                                                    _navigateToAssessmentReport(
                                                                      context,
                                                                      testId,
                                                                      job['job_index'],
                                                                      attemptNumber,
                                                                    );
                                                                  },
                                                                  style: ElevatedButton.styleFrom(
                                                                    backgroundColor: geekGreen,
                                                                    foregroundColor: Colors.white,
                                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                                    shape: RoundedRectangleBorder(
                                                                      borderRadius: BorderRadius.circular(8),
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    'View Full Report ${rank == 1 ? '(Best Match)' : ''}',
                                                                    style: const TextStyle(
                                                                      fontSize: 14,
                                                                      fontWeight: FontWeight.w600,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ).toList(),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.assessment_outlined,
                                  size: 64,
                                  color: textSecondary,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No user reports found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
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
