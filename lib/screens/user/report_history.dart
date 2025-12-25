import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:code_map/screens/user/assessment_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:code_map/services/api_service.dart';
import '../results/report.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen>
    with SingleTickerProviderStateMixin {
  static const Color geekGreen = Color(0xFF2F8D46);
  static const Color geekDarkGreen = Color(0xFF1B5E20);
  static const Color geekLightGreen = Color(0xFF4CAF50);
  static const Color geekBackground = Color(0xFFE8F5E9);
  static const Color geekCardBg = Color(0xFFFFFFFF);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> assessmentAttempts = [];
  bool isLoading = true;

  // Track expanded state and loaded jobs for each assessment
  Map<String, bool> _expandedStates = {};
  Map<String, List<Map<String, dynamic>>> _loadedJobs = {};
  Map<String, bool> _loadingJobs = {};

  @override
  void initState() {
    super.initState();
    _loadUserAssessments();
  }

  Future<void> _loadUserAssessments() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data()!;

          if (data.containsKey('assessmentAttempts')) {
            final attempts = data['assessmentAttempts'] as List<dynamic>;
            final loadedAttempts = <Map<String, dynamic>>[];

            for (final attempt in attempts) {
              if (attempt is Map<String, dynamic>) {
                loadedAttempts.add(Map<String, dynamic>.from(attempt));
              }
            }

            // sort by completedAt date (newest first)
            loadedAttempts.sort((a, b) {
              final dateA = DateTime.parse(a['completedAt'] ?? '');
              final dateB = DateTime.parse(b['completedAt'] ?? '');
              return dateB.compareTo(dateA);
            });

            // initialize expanded states
            for (final attempt in loadedAttempts) {
              final testId = attempt['testId'] ?? '';
              _expandedStates[testId] = false;
            }

            if (mounted) {
              setState(() {
                assessmentAttempts = loadedAttempts;
                isLoading = false;
              });
            }
          } else {
            if (mounted) {
              setState(() {
                isLoading = false;
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading assessments: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // load jobs for a specific test
  Future<void> _loadJobsForTest(String testId, int attemptNumber) async {
    // don't reload if already loaded
    if (_loadedJobs.containsKey(testId) && _loadedJobs[testId]!.isNotEmpty) {
      return;
    }

    setState(() {
      _loadingJobs[testId] = true;
    });

    try {
      final jobs = <Map<String, dynamic>>[];

      // try to load all 3 job recommendations (0, 1, 2)
      for (int jobIndex = 0; jobIndex < 3; jobIndex++) {
        try {
          final response = await ApiService.generateReport(
            testId,
            jobIndex.toString(),
          );

          if (response['data'] != null && response['data']['job'] != null) {
            final jobData = response['data']['job'];
            final similarity =
                jobData['similarity_percentage']?.toString() ?? '0';

            jobs.add({
              'job_index': jobIndex.toString(),
              'job_title': jobData['job_title'] ?? 'Job ${jobIndex + 1}',
              'job_description': jobData['job_description'] ?? '',
              'similarity_percentage': similarity,
              'report_data': response['data'],
            });
          }
        } catch (e) {
          print('Error loading job $jobIndex for test $testId: $e');
          // continue with other jobs
        }
      }

      // sort jobs by similarity percentage (highest first)
      jobs.sort((a, b) {
        final aPercent =
            double.tryParse(a['similarity_percentage']?.toString() ?? '0') ?? 0;
        final bPercent =
            double.tryParse(b['similarity_percentage']?.toString() ?? '0') ?? 0;
        return bPercent.compareTo(aPercent);
      });

      setState(() {
        _loadedJobs[testId] = jobs;
        _loadingJobs[testId] = false;
      });
    } catch (e) {
      print('Error fetching jobs for test $testId: $e');
      setState(() {
        _loadingJobs[testId] = false;
      });
    }
  }

  // toggle expansion
  void _toggleExpansion(String testId, int attemptNumber) {
    final isExpanding = !(_expandedStates[testId] ?? false);

    setState(() {
      _expandedStates[testId] = isExpanding;
    });

    // load jobs when expanding
    if (isExpanding) {
      _loadJobsForTest(testId, attemptNumber);
    }
  }

  // navigate to AssessmentReportScreen
  void _navigateToAssessmentReport(
    BuildContext context,
    String userTestId,
    String jobIndex,
    int attemptNumber,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportResultScreen(
          userTestId: userTestId,
          jobIndex: jobIndex,
          atemptNumber: attemptNumber,
          fromGapAnalysis: false,
        ),
      ),
    );
  }

  // helper methods for UI
  Color _getSimilarityColor(double percentage) {
    if (percentage >= 80) return const Color(0xFF2F8D46);
    if (percentage >= 70) return const Color(0xFF4CAF50);
    if (percentage >= 60) return const Color(0xFFF57C00);
    return const Color(0xFFD32F2F);
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = dateTime.hour < 12 ? 'AM' : 'PM';
    return '${hour == 0 ? 12 : hour}:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: geekBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Report History',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: geekDarkGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'View your completed assessments',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // content
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: geekGreen,
                          strokeWidth: 2,
                        ),
                      )
                    : assessmentAttempts.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Completed Assessments (${assessmentAttempts.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: geekDarkGreen,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // list of assessments with expandable jobs
                              Expanded(
                                child: ListView.separated(
                                  itemCount: assessmentAttempts.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final attempt = assessmentAttempts[index];
                                    final attemptNumber =
                                        attempt['attemptNumber'] ?? 0;
                                    final testId = attempt['testId'] ?? '';
                                    final completedAt =
                                        attempt['completedAt'] ?? '';
                                    final status = attempt['status'] ?? '';
                                    final isExpanded =
                                        _expandedStates[testId] ?? false;
                                    final jobs = _loadedJobs[testId] ?? [];
                                    final isLoadingJobs =
                                        _loadingJobs[testId] ?? false;

                                    return Material(
                                      color: Colors.transparent,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: geekCardBg,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: geekGreen.withOpacity(0.1),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            // Assessment header (always visible)
                                            InkWell(
                                              onTap: () => _toggleExpansion(
                                                  testId, attemptNumber),
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: Row(
                                                  children: [
                                                    // Icon Container
                                                    Container(
                                                      width: 50,
                                                      height: 50,
                                                      decoration: BoxDecoration(
                                                        color: geekGreen
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .assessment_rounded,
                                                        color: geekDarkGreen,
                                                        size: 24,
                                                      ),
                                                    ),

                                                    const SizedBox(width: 16),

                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Assessment #$attemptNumber',
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  geekDarkGreen,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            _formatDateTime(
                                                                completedAt),
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 6),
                                                          Row(
                                                            children: [
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: status ==
                                                                          'Completed'
                                                                      ? Colors
                                                                          .green
                                                                          .withOpacity(
                                                                              0.1)
                                                                      : Colors
                                                                          .amber
                                                                          .withOpacity(
                                                                              0.1),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              6),
                                                                ),
                                                                child: Text(
                                                                  status,
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color: status ==
                                                                            'Completed'
                                                                        ? Colors
                                                                            .green
                                                                            .shade700
                                                                        : Colors
                                                                            .amber
                                                                            .shade700,
                                                                  ),
                                                                ),
                                                              ),
                                                              const Spacer(),
                                                              Text(
                                                                'Test ID: ${testId.substring(0, 8)}...',
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 11,
                                                                  fontFamily:
                                                                      'Monospace',
                                                                  color: Colors
                                                                      .grey,
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
                                              ),
                                            ),

                                            // expanded job recommendations section
                                            if (isExpanded) ...[
                                              const Divider(height: 1),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(16),
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
                                                        const SizedBox(
                                                            width: 8),
                                                        const Text(
                                                          'Career Recommendations',
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                geekDarkGreen,
                                                          ),
                                                        ),
                                                        const Spacer(),
                                                        if (jobs.isNotEmpty)
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 10,
                                                              vertical: 4,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: geekGreen
                                                                  .withOpacity(
                                                                      0.1),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                            ),
                                                            child: Text(
                                                              '${jobs.length} jobs',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    geekGreen,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),

                                                    // jobs list
                                                    if (isLoadingJobs)
                                                      const Center(
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsets.all(
                                                                  16.0),
                                                          child:
                                                              CircularProgressIndicator(
                                                            color: geekGreen,
                                                            strokeWidth: 2,
                                                          ),
                                                        ),
                                                      )
                                                    else if (jobs.isEmpty)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(16.0),
                                                        child: Column(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .work_off_outlined,
                                                              size: 48,
                                                              color: Colors
                                                                  .grey[400],
                                                            ),
                                                            const SizedBox(
                                                                height: 8),
                                                            Text(
                                                              'No job recommendations found',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .grey[600],
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
                                                            final rank =
                                                                entry.key + 1;
                                                            final job =
                                                                entry.value;
                                                            final similarity =
                                                                double.tryParse(
                                                                        job['similarity_percentage']?.toString() ??
                                                                            '0') ??
                                                                    0;

                                                            return Card(
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      bottom:
                                                                          12),
                                                              elevation: 0,
                                                              shape:
                                                                  RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            10),
                                                                side:
                                                                    BorderSide(
                                                                  color: Colors
                                                                          .grey[
                                                                      300]!,
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(
                                                                        12),
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Row(
                                                                      children: [
                                                                        // Ranking badge
                                                                        Container(
                                                                          width:
                                                                              36,
                                                                          height:
                                                                              36,
                                                                          decoration:
                                                                              BoxDecoration(
                                                                            color:
                                                                                _getSimilarityColor(similarity).withOpacity(0.1),
                                                                            borderRadius:
                                                                                BorderRadius.circular(8),
                                                                            border:
                                                                                Border.all(
                                                                              color: _getSimilarityColor(similarity),
                                                                              width: 2,
                                                                            ),
                                                                          ),
                                                                          child:
                                                                              Center(
                                                                            child:
                                                                                Text(
                                                                              _getRankingIcon(rank),
                                                                              style: const TextStyle(fontSize: 16),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                            width:
                                                                                12),
                                                                        Expanded(
                                                                          child:
                                                                              Column(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children: [
                                                                              Text(
                                                                                job['job_title'],
                                                                                style: const TextStyle(
                                                                                  fontSize: 15,
                                                                                  fontWeight: FontWeight.w600,
                                                                                  color: Colors.black87,
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
                                                                                      backgroundColor: Colors.grey[200],
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
                                                                    const SizedBox(
                                                                        height:
                                                                            8),
                                                                    Text(
                                                                      job['job_description'] ??
                                                                          '',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            13,
                                                                        color: Colors
                                                                            .grey[700],
                                                                        height:
                                                                            1.4,
                                                                      ),
                                                                      maxLines:
                                                                          2,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            12),
                                                                    SizedBox(
                                                                      width: double
                                                                          .infinity,
                                                                      child:
                                                                          ElevatedButton(
                                                                        onPressed:
                                                                            () {
                                                                          _navigateToAssessmentReport(
                                                                            context,
                                                                            testId,
                                                                            job['job_index'],
                                                                            attemptNumber,
                                                                          );
                                                                        },
                                                                        style: ElevatedButton
                                                                            .styleFrom(
                                                                          backgroundColor:
                                                                              geekGreen,
                                                                          foregroundColor:
                                                                              Colors.white,
                                                                          padding: const EdgeInsets
                                                                              .symmetric(
                                                                              vertical: 10),
                                                                          shape:
                                                                              RoundedRectangleBorder(
                                                                            borderRadius:
                                                                                BorderRadius.circular(8),
                                                                          ),
                                                                        ),
                                                                        child:
                                                                            Text(
                                                                          'View Full Report ${rank == 1 ? '(Best Match)' : ''}',
                                                                          style:
                                                                              const TextStyle(
                                                                            fontSize:
                                                                                14,
                                                                            fontWeight:
                                                                                FontWeight.w600,
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
                                ),
                              ),
                            ],
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: geekGreen.withOpacity(0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.assessment_outlined,
                                    size: 60,
                                    color: geekGreen.withOpacity(0.3),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'No Report Yet',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: geekDarkGreen,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40.0),
                                  child: Text(
                                    'Complete your first assessment to view your detailed report and unlock personalized insights! :D',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () {
                                    const AssessmentScreen();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: geekGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text('Start Assessment'),
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
