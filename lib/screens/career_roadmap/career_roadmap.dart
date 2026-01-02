import 'package:code_map/screens/user/assessment_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/retake_service.dart';
import '../user/home_screen.dart';
import '../user/assessment_screen.dart';

class CareerRoadmap extends StatefulWidget {
  final String userTestId;
  final String jobIndex;

  const CareerRoadmap({
    super.key,
    required this.userTestId,
    required this.jobIndex,
  });

  @override
  State<CareerRoadmap> createState() => _CareerRoadmapState();
}

class _CareerRoadmapState extends State<CareerRoadmap> {
  Map<String, dynamic>? roadmap;
  List<dynamic> recommendedJobs = [];
  String? currentJobIndex;
  String? currentJobTitle;
  String? errorMessage;
  bool isLoading = true;
  bool isLoadingJobs = true;

  static const Color geekGreen = Color(0xFF4BC945);
  static const Color backgroundColor = Color(0xFF000000);
  static const Color cardBackground = Color(0xFF121212);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF666666);

  // retake tracking
  bool _canRetake = true;
  int _daysUntilRetake = 0;
  List<dynamic> _userAttempts = [];

  @override



  bool _isAssessmentIncomplete = false;

  @override
  void initState() {
    super.initState();
    currentJobIndex = widget.jobIndex;
    _checkStatusAndLoad();
  }

  Future<void> _checkStatusAndLoad() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // check retake eligibility (existing logic)
    _userAttempts = await RetakeService.getUserAttempts(user.uid);
    final daysUntil = RetakeService.daysUntilRetake(_userAttempts);

    // find the specific attempt for this view
    final currentAttempt = _userAttempts.firstWhere(
      (a) => a['testId'] == widget.userTestId,
      orElse: () => null,
    );

    if (currentAttempt != null && currentAttempt['status'] != 'Completed') {
      if (mounted) {
        setState(() {
          _isAssessmentIncomplete = true;
          isLoading = false;
          isLoadingJobs = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _daysUntilRetake = 0; // logic for retake simplified here as per previous
        _canRetake = true;
      });
      // only load data if completed
      _loadData();
    }
  }

  Future<void> _handleRetake() async {
    if (!_canRetake) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You can retake in $_daysUntilRetake days',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // show confirmation dialog for retake
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.5),
        elevation: 8,
        title: Container(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: geekGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: geekGreen,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Start New Assessment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Attempt ${_userAttempts.length + 1}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: geekGreen,
                backgroundColor: geekGreen.withOpacity(0.1),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'re about to start a new assessment. Are you sure you want to proceed?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Colors.blue[400],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Don\'t worry, your previous results will be saved! :D',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[400],
                      side: BorderSide(color: Colors.grey[600]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Not Now',
                      style: TextStyle(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: geekGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Proceed',
                      style: TextStyle(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    // navigate to the start of assessment
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const AssessmentScreen(),
      ),
      (route) => false, // clear all routes
    );
  }



  Future<void> _loadData() async {
    try {
      // load all recommended jobs first
      await _loadRecommendedJobs();

      // generate all career roadmaps for the user
      await ApiService.generateCareerRoadMaps(widget.userTestId);

      // load the initial career roadmap
      await _loadCareerRoadmap();
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
        isLoadingJobs = false;
      });
    }
  }

  Future<void> _loadRecommendedJobs() async {
    try {
      final response =
          await ApiService.getAllRecommendedJobs(widget.userTestId);

      if (response.containsKey('data')) {
        setState(() {
          recommendedJobs = response['data'];
          isLoadingJobs = false;
        });

        // set current job title if available
        if (currentJobIndex != null) {
          _setCurrentJobTitle();
        }
      }
    } catch (e) {
      setState(() {
        errorMessage = "Failed to load recommended jobs: $e";
        isLoadingJobs = false;
      });
    }
  }

  Future<void> _loadCareerRoadmap() async {
    if (currentJobIndex == null) return;

    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final results = await ApiService.getCareerRoadmap(
          widget.userTestId, currentJobIndex!);

      // check if there's an error message from backend
      if (results.containsKey('error')) {
        throw Exception(results['error']);
      }

      final roadmapData = results['data'];
      if (roadmapData == null) {
        throw Exception('No roadmap data found in response');
      }

      // extract topics and sub_topics
      Map<String, Map<String, List<String>>> levels = {};

      if (roadmapData.containsKey('topics') &&
          roadmapData.containsKey('sub_topics')) {
        final topics = Map<String, dynamic>.from(roadmapData['topics'] ?? {});
        final subTopics =
            Map<String, dynamic>.from(roadmapData['sub_topics'] ?? {});

        topics.forEach((topicName, level) {
          final levelName = _formatLevelName(level.toString());
          final topicSubTopics = List<String>.from(subTopics[topicName] ?? []);

          if (!levels.containsKey(levelName)) {
            levels[levelName] = {};
          }
          levels[levelName]![topicName] = topicSubTopics;
        });
      } else {
        if (roadmapData.containsKey('roadmap')) {
          final nestedData = roadmapData['roadmap'];
          if (nestedData.containsKey('topics') &&
              nestedData.containsKey('sub_topics')) {
            final topics =
                Map<String, dynamic>.from(nestedData['topics'] ?? {});
            final subTopics =
                Map<String, dynamic>.from(nestedData['sub_topics'] ?? {});

            topics.forEach((topicName, level) {
              final levelName = _formatLevelName(level.toString());
              final topicSubTopics =
                  List<String>.from(subTopics[topicName] ?? []);

              if (!levels.containsKey(levelName)) {
                levels[levelName] = {};
              }
              levels[levelName]![topicName] = topicSubTopics;
            });
          }
        }
      }

      setState(() {
        roadmap = {
          'user_test_id': roadmapData['user_test_id'] ?? widget.userTestId,
          'job_index': roadmapData['job_match_id'] ?? currentJobIndex,
          'job_title': currentJobTitle ?? roadmapData['job_title'] ?? 'Career',
          'levels': levels,
        };
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load roadmap: $e';
        isLoading = false;
      });
    }
  }

  String _formatLevelName(String level) {
    switch (level.toLowerCase()) {
      case 'basic':
        return 'Basic';
      case 'intermediate':
        return 'Intermediate';
      case 'advanced':
        return 'Advanced';
      case 'expert':
        return 'Expert';
      default:
        return level;
    }
  }

  void _setCurrentJobTitle() {
    try {
      final job = recommendedJobs.firstWhere(
        (job) => job['job_index'] == currentJobIndex,
        orElse: () => {'job_title': 'Unknown Title'},
      );
      setState(() {
        currentJobTitle = job['job_title'];
      });
    } catch (e) {
      setState(() {
        currentJobTitle = 'Unknown Title';
      });
    }
  }

  void _onJobSelected(String? jobIndex) {
    if (jobIndex == null) return;

    final job = recommendedJobs.firstWhere(
      (job) => job['job_index'] == jobIndex,
      orElse: () => {'job_title': 'Unknown Title'},
    );

    setState(() {
      currentJobIndex = jobIndex;
      currentJobTitle = job['job_title'];
    });
    _loadCareerRoadmap();
  }

  Widget _buildJobSelector() {
    if (isLoadingJobs) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(geekGreen),
            ),
            SizedBox(width: 12),
            Text(
              'Loading careers...',
              style: TextStyle(
                fontSize: 14,
                color: textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (recommendedJobs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.work_off_outlined,
              size: 20,
              color: textSecondary,
            ),
            SizedBox(width: 12),
            Text(
              'No recommended jobs found',
              style: TextStyle(
                color: textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DropdownButton<String>(
          value: currentJobIndex,
          isExpanded: true,
          underline: const SizedBox(), // remove default underline
          icon: const Icon(
            Icons.arrow_drop_down_rounded,
            color: textSecondary,
            size: 24,
          ),
          style: const TextStyle(
            fontSize: 16,
            color: textPrimary,
            fontWeight: FontWeight.w500,
          ),
          borderRadius: BorderRadius.circular(12),
          dropdownColor: cardBackground,
          onChanged: _onJobSelected,
          items: [
            // default hint item
            const DropdownMenuItem<String>(
              value: null,
              child: Text(
                'Select a career path',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
            // career items
            ...recommendedJobs.map<DropdownMenuItem<String>>((job) {
              final jobIndex = job['job_index'];
              final jobTitle = job['job_title'];
              final index = recommendedJobs.indexOf(job);

              return DropdownMenuItem<String>(
                value: jobIndex,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: geekGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Career #${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: geekGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          jobTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapContent() {
    if (_isAssessmentIncomplete) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pending_actions_rounded,
                  size: 64,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Assessment In Progress',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please complete your assessment to generate your personalized career roadmap.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                   Navigator.of(context).pop(); // go back to home
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: geekGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      );
    }

    if (isLoading) {
      return const Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(geekGreen),
              ),
              SizedBox(height: 20),
              Text(
                'Loading your career roadmap...',
                style: TextStyle(
                  fontSize: 15,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red[200]!, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.red[400],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Error loading roadmap',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[900],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red[800],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadCareerRoadmap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (roadmap == null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school_outlined,
                  size: 64,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Nothing to see here D:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Complete your assessments to unlock your\npersonalized career roadmap! :D',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final levels = roadmap?['levels'] as Map<String, dynamic>?;
    if (levels == null || levels.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_stories_outlined,
                size: 56,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No roadmap data available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // return the roadmap content wrapped in Expanded to take remaining space
    return Expanded(
      child: ListView(
        children: [
          _buildRoadmapHeader(),
          const SizedBox(height: 20),
          ..._buildLevels(),
        ],
      ),
    );
  }

  Widget _buildRoadmapHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: geekGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: geekGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Personalized Career Roadmap',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: geekGreen,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            currentJobTitle ?? 'Unknown Career',
            style: const TextStyle(
              fontSize: 22,
              fontFamily: 'JetBrainsMono',
              fontWeight: FontWeight.w900,
              color: textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your step-by-step learning journey to become a ${currentJobTitle ?? 'professional'}',
            style: const TextStyle(
              fontSize: 14,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLevels() {
    final levels = roadmap?['levels'] as Map<String, dynamic>?;
    if (levels == null || levels.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: const Center(
            child: Text('No roadmap levels available'),
          ),
        ),
      ];
    }

    final levelWidgets = <Widget>[];
    final levelNames = levels.keys.toList();

    // sort levels in logical order
    levelNames.sort((a, b) {
      final order = {'Basic': 0, 'Intermediate': 1, 'Advanced': 2, 'Expert': 3};
      return (order[a] ?? 4).compareTo(order[b] ?? 4);
    });

    for (int i = 0; i < levelNames.length; i++) {
      final levelName = levelNames[i];
      final topicsMap = Map<String, dynamic>.from(levels[levelName]!);

      levelWidgets.add(
        _buildLevelCard(levelName, topicsMap, i, levelNames.length),
      );

      if (i < levelNames.length - 1) {
        levelWidgets.add(
          Container(
            height: 50,
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.arrow_downward_rounded,
                    color: Colors.grey[500],
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  const SizedBox(height: 4),
                  Container(
                    height: 2,
                    width: 3,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 2,
                    width: 3,
                    color: Colors.white.withOpacity(0.2),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return levelWidgets;
  }

  Widget _buildLevelCard(String levelName, Map<String, dynamic> topicsMap,
      int levelIndex, int totalLevels) {
    Color _getLevelColor(String levelName) {
      switch (levelName.toLowerCase()) {
        case 'basic':
          return const Color(0xFF4CAF50); // Green
        case 'intermediate':
          return const Color(0xFF2196F3); // Blue
        case 'advanced':
          return const Color(0xFFFF9800); // Orange/Yellow
        case 'expert':
          return const Color(0xFFF44336); // Red
        default:
          // fallback color based on position
          return const Color(0xFF4CAF50);
      }
    }

    final backgroundColor = _getLevelColor(levelName);

    return Container(
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: backgroundColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    backgroundColor.withOpacity(0.8),
                    backgroundColor.withOpacity(0.4),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        backgroundColor.withOpacity(0.15),
                        backgroundColor.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: backgroundColor.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      // level indicator with number
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: backgroundColor.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${levelIndex + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              levelName,
                              style: TextStyle(
                                fontSize: 18,
                                fontFamily: 'JetBrainsMono',
                                fontWeight: FontWeight.w900,
                                color: backgroundColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Step ${levelIndex + 1} of $totalLevels',
                              style: TextStyle(
                                fontSize: 11,
                                color: backgroundColor.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: backgroundColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${topicsMap.length} ${topicsMap.length == 1 ? 'Area' : 'Areas'}',
                          style: TextStyle(
                            color: backgroundColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // topics list with improved visual hierarchy
                if (topicsMap.isNotEmpty)
                  ...topicsMap.entries.map((entry) {
                    final topicName = entry.key;
                    final subTopics = List<String>.from(entry.value ?? []);
                    return _buildTopicCard(
                        topicName, subTopics, backgroundColor);
                  }).toList()
                else
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Center(
                      child: Text(
                        'No learning areas for this level',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCard(
      String topicName, List<String> subTopics, Color levelColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // topic name with improved design
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 8, right: 12),
                  decoration: BoxDecoration(
                    color: levelColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topicName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (subTopics.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        // subtopic list with arrow indicators
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: subTopics
                              .map((subTopic) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 4.0, right: 10.0),
                                          child: Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 12,
                                            color: levelColor.withOpacity(0.7),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            subTopic,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: textSecondary,
                                              height: 1.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
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
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // Premium Gradient Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [geekGreen, const Color(0xFF3AA036)],
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
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
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
                  'Your Career Journey',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Explore your professional development roadmap',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const SizedBox(height: 10),
              _buildJobSelector(),
              const SizedBox(height: 24),
              _buildRoadmapContent(),
            ],
          ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: backgroundColor,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _canRetake ? _handleRetake : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: geekGreen,
                    side: BorderSide(
                      color: _canRetake
                          ? geekGreen
                          : Colors.grey[800]!,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _canRetake
                        ? "Retake Test"
                        : "Available in $_daysUntilRetake days",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomePage(),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: geekGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    "Complete",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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
