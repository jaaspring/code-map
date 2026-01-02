import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:code_map/screens/user/assessment_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../career_roadmap/career_roadmap.dart';
import '../../services/badge_service.dart';

class CareerRoadmapScreen extends StatefulWidget {
  const CareerRoadmapScreen({super.key});

  @override
  State<CareerRoadmapScreen> createState() => _CareerRoadmapScreenState();
}

class _CareerRoadmapScreenState extends State<CareerRoadmapScreen> {
  // Design constants matching HomeScreen
  static const Color geekGreen = Color(0xFF4BC945);
  static const Color backgroundColor = Color(0xFF000000);
  static const Color cardBackground = Color(0xFF121212);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF666666);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> assessmentAttempts = [];
  bool isLoading = true;

  // Track expanded state and loaded job matches for each assessment
  Map<String, bool> _expandedStates = {};
  Map<String, List<Map<String, dynamic>>> _loadedJobMatches = {};
  Map<String, bool> _loadingJobMatches = {};

  @override
  void initState() {
    super.initState();
    _loadUserAssessments();
  }

  Future<void> _loadUserAssessments() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final loadedAttempts = <Map<String, dynamic>>[];

      if (!userDoc.exists) {
        if (mounted) {
          setState(() {
            assessmentAttempts = [];
            isLoading = false;
          });
        }
        return;
      }

      final data = userDoc.data();
      if (data == null) {
        if (mounted) {
          setState(() {
            assessmentAttempts = [];
            isLoading = false;
          });
        }
        return;
      }

      final attempts = data['assessmentAttempts'] as List<dynamic>?;

      // handle null or empty attempts
      if (attempts == null || attempts.isEmpty) {
        if (mounted) {
          setState(() {
            assessmentAttempts = [];
            isLoading = false;
          });
        }
        return;
      }

      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final attempts = data['assessmentAttempts'] as List<dynamic>?;

        if (attempts != null) {
          for (final attempt in attempts) {
            if (attempt is Map<String, dynamic>) {
              loadedAttempts.add(Map<String, dynamic>.from(attempt));
            }
          }

          // sort by completedAt date (newest first)
          loadedAttempts.sort((a, b) {
            DateTime getDate(dynamic value) {
              if (value is Timestamp) return value.toDate();
              if (value is String && value.isNotEmpty) {
                return DateTime.tryParse(value) ?? DateTime(1970);
              }
              return DateTime(1970);
            }

            return getDate(b['completedAt'])
                .compareTo(getDate(a['completedAt']));
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
        }
      }
    } catch (e, stack) {
      debugPrint('Error loading assessments: $e');
      debugPrintStack(stackTrace: stack);
      if (mounted) setState(() => isLoading = false);
    }
  }

  // load job matches for a specific test from career_recommendations
  Future<void> _loadJobMatchesForTest(String testId, int attemptNumber) async {
    // don't reload if already loaded
    if (_loadedJobMatches.containsKey(testId) &&
        _loadedJobMatches[testId]!.isNotEmpty) {
      return;
    }

    setState(() {
      _loadingJobMatches[testId] = true;
    });

    try {
      // First get career_recommendations document
      final querySnapshot = await _firestore
          .collection('career_recommendations')
          .where('user_test_id', isEqualTo: testId)
          .limit(1)
          .get();

      final jobMatches = <Map<String, dynamic>>[];

      if (querySnapshot.docs.isNotEmpty) {
        final recDoc = querySnapshot.docs.first;
        recDoc.data();

        // Get the job_matches subcollection
        final jobMatchesSnapshot =
            await recDoc.reference.collection('job_matches').get();

        for (final jobDoc in jobMatchesSnapshot.docs) {
          final jobData = jobDoc.data();
          jobMatches.add({
            'job_index': jobDoc.id, // "0", "1", "2" etc.
            'job_title': jobData['job_title'] ?? 'Job ${jobDoc.id}',
            'job_description': jobData['job_description'] ?? '',
            'similarity_percentage':
                jobData['similarity_percentage']?.toString() ?? '0',
            'similarity_score': jobData['similarity_score']?.toDouble() ?? 0.0,
          });
        }

        // sort jobs by similarity score (highest first)
        jobMatches.sort((a, b) {
          final aScore = a['similarity_score'] ?? 0.0;
          final bScore = b['similarity_score'] ?? 0.0;
          return bScore.compareTo(aScore);
        });
      }

      setState(() {
        _loadedJobMatches[testId] = jobMatches;
        _loadingJobMatches[testId] = false;
      });
    } catch (e) {
      debugPrint('Error loading job matches for test $testId: $e');
      setState(() {
        _loadingJobMatches[testId] = false;
      });
    }
  }

  // toggle expansion
  void _toggleExpansion(String testId, int attemptNumber) {
    final isExpanding = !(_expandedStates[testId] ?? false);

    setState(() {
      _expandedStates[testId] = isExpanding;
    });

    // load job matches when expanding
    if (isExpanding) {
      _loadJobMatchesForTest(testId, attemptNumber);
    }
  }

  // navigate to CareerRoadmap screen for a specific job index
  void _navigateToCareerRoadmap(
    BuildContext context,
    String userTestId,
    String jobIndex,
    int attemptNumber,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CareerRoadmap(
          userTestId: userTestId,
          jobIndex: jobIndex,
        ),
      ),
    );
    
    // Trigger roadmap_create badge check
    BadgeService.checkAndAwardBadge(trigger: 'roadmap_create').then((newBadges) {
      if (newBadges.isNotEmpty && mounted) {
        BadgeService.showBadgeDialog(context, newBadges);
      }
    });

    // Increment roadmapsCreated counter
    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection('users').doc(user.uid).update({
        'roadmapsCreated': FieldValue.increment(1),
      });
    }
  }

  // helper method to format test ID display
  String _formatTestId(String testId) {
    if (testId.length <= 8) return testId;
    return '${testId.substring(0, 8)}...';
  }

  // helper methods for UI
  String _formatDateTime(dynamic dateValue) {
    try {
      DateTime dateTime;
      if (dateValue is Timestamp) {
        dateTime = dateValue.toDate();
      } else if (dateValue is String) {
        dateTime = DateTime.parse(dateValue);
      } else {
        return 'N/A';
      }

      final month = _getMonth(dateTime.month);
      return '$month ${dateTime.day}, ${dateTime.year}';
    } catch (e) {
      return dateValue?.toString() ?? 'N/A';
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

  // get similarity color based on percentage
  Color _getSimilarityColor(double percentage) {
    if (percentage >= 80) return const Color(0xFF4CAF50); // Green
    if (percentage >= 70) return const Color(0xFF81C784); // Light Green
    if (percentage >= 60) return const Color(0xFFFFB74D); // Orange
    return const Color(0xFFE57373); // Red
  }

  // get ranking icon based on position
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

  // get icon container for job index
  Widget _getJobIndexIcon(int rank, double similarityPercentage) {
    if (rank == 1) {
      return Image.asset(
        'assets/medal_first.png',
        width: 56,
        height: 56,
        fit: BoxFit.contain,
      );
    }
    final color = _getSimilarityColor(similarityPercentage);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          _getRankingIcon(rank),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Text(
                'Career\nRoadmaps',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: geekGreen,
                  height: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Text(
                'Explore your professional growth path based on job matches',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ),
            
            const SizedBox(height: 20),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                              const Text(
                                'Available Roadmaps',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: geekGreen,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // list of assessments with expandable job matches
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
                                    final completedAt = attempt['completedAt'];
                                    final status = attempt['status'] ?? '';
                                    final isExpanded =
                                        _expandedStates[testId] ?? false;
                                    final jobMatches =
                                        _loadedJobMatches[testId] ?? [];
                                    final isLoadingMatches =
                                        _loadingJobMatches[testId] ?? false;

                                    return Material(
                                      color: Colors.transparent,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: cardBackground,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.05),
                                            width: 1,
                                          ),
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
                                                        Icons.map_rounded,
                                                        color: geekGreen,
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
                                                                  textPrimary,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            _formatDateTime(
                                                                completedAt),
                                                            style:
                                                                const TextStyle(
                                                              fontSize: 13,
                                                              color:
                                                                  textSecondary,
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
                                                                      ? geekGreen
                                                                          .withOpacity(
                                                                              0.1)
                                                                      : Colors
                                                                          .orange
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
                                                                        ? geekGreen
                                                                        : Colors
                                                                            .orange,
                                                                  ),
                                                                ),
                                                              ),
                                                              const Spacer(),
                                                              Text(
                                                                'ID: ${_formatTestId(testId)}',
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 11,
                                                                  fontFamily:
                                                                      'Monospace',
                                                                  color:
                                                                      textSecondary,
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

                                            // expanded job matches section
                                            if (isExpanded) ...[
                                              Divider(
                                                height: 1,
                                                color: Colors.white
                                                    .withOpacity(0.1),
                                              ),
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
                                                          'Job Matches',
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: textPrimary,
                                                          ),
                                                        ),
                                                        const Spacer(),
                                                        if (jobMatches
                                                            .isNotEmpty)
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
                                                              '${jobMatches.length} matches',
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

                                                    // job matches list
                                                    if (isLoadingMatches)
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
                                                    else if (jobMatches.isEmpty)
                                                      const Padding(
                                                        padding: EdgeInsets.all(
                                                            16.0),
                                                        child: Column(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .work_off_outlined,
                                                              size: 48,
                                                              color:
                                                                  textSecondary,
                                                            ),
                                                            SizedBox(height: 8),
                                                            Text(
                                                              'No job matches found for this assessment',
                                                              style: TextStyle(
                                                                color:
                                                                    textSecondary,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      )
                                                    else
                                                      Column(
                                                        children: jobMatches
                                                            .asMap()
                                                            .entries
                                                            .map(
                                                          (entry) {
                                                            final rank =
                                                                entry.key + 1;
                                                            final jobMatch =
                                                                entry.value;
                                                            final similarityPercentage =
                                                                double.tryParse(
                                                                        jobMatch['similarity_percentage']?.toString() ??
                                                                            '0') ??
                                                                    0;
                                                            final jobTitle =
                                                                jobMatch[
                                                                        'job_title'] ??
                                                                    'Job Match';
                                                            final jobDescription =
                                                                jobMatch[
                                                                        'job_description'] ??
                                                                    '';
                                                            final jobIndex =
                                                                jobMatch[
                                                                        'job_index'] ??
                                                                    '0';

                                                            return Card(
                                                              color:
                                                                  cardBackground,
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
                                                                      .white
                                                                      .withOpacity(
                                                                          0.05),
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
                                                                        // Ranking badge with similarity color
                                                                        _getJobIndexIcon(
                                                                            rank,
                                                                            similarityPercentage),
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
                                                                                jobTitle,
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
                                                                                      value: similarityPercentage / 100,
                                                                                      backgroundColor: Colors.white.withOpacity(0.1),
                                                                                      valueColor: AlwaysStoppedAnimation<Color>(_getSimilarityColor(similarityPercentage)),
                                                                                      borderRadius: BorderRadius.circular(4),
                                                                                      minHeight: 8,
                                                                                    ),
                                                                                  ),
                                                                                  const SizedBox(width: 8),
                                                                                  Text(
                                                                                    '${similarityPercentage.toStringAsFixed(1)}% match',
                                                                                    style: TextStyle(
                                                                                      fontSize: 12,
                                                                                      fontWeight: FontWeight.bold,
                                                                                      color: _getSimilarityColor(similarityPercentage),
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
                                                                      jobDescription,
                                                                      style:
                                                                          const TextStyle(
                                                                        fontSize:
                                                                            13,
                                                                        color:
                                                                            textSecondary,
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
                                                                          _navigateToCareerRoadmap(
                                                                            context,
                                                                            testId,
                                                                            jobIndex,
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
                                                                          'View Career Roadmap ${rank == 1 ? '(Best Match)' : ''}',
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
                                    Icons.map_outlined,
                                    size: 60,
                                    color: geekGreen,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'No Roadmaps Yet',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 40.0),
                                  child: Text(
                                    'Complete an assessment to generate personalized career roadmaps based on your job matches! :D',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AssessmentScreen(),
                                      ),
                                    );
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
          ),
        ],
      ),
      ),
    );
  }
}
