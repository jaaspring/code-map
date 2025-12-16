import 'package:code_map/screens/user/assessment_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/retake_service.dart';
import '../user/home_screen.dart';

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

  // retake tracking
  bool _canRetake = true;
  int _daysUntilRetake = 0;
  List<dynamic> _userAttempts = [];

  @override
  void initState() {
    super.initState();
    currentJobIndex = widget.jobIndex;
    _loadData();
    _checkRetakeEligibility();
  }

  Future<void> _checkRetakeEligibility() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userAttempts = await RetakeService.getUserAttempts(user.uid);
    final canRetake = RetakeService.canRetakeTest(_userAttempts);
    final daysUntil = RetakeService.daysUntilRetake(_userAttempts);

    setState(() {
      _canRetake = canRetake;
      _daysUntilRetake = daysUntil;
    });
  }

  Future<void> _handleRetake() async {
    if (!_canRetake) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _userAttempts.length >= 10
                ? 'Maximum 10 attempts reached'
                : 'You can retake in $_daysUntilRetake days',
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.1),
        elevation: 8,
        title: Container(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.amber,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Start New Assessment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
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
                color: Theme.of(context).primaryColor,
                backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.1),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'re about to start a new assessment. Are you sure you want to proceed?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Colors.blue[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Don\t worry, your previous results will be saved! :D',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
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
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Not Now',
                      style: TextStyle(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center, // Add this
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
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
                      textAlign: TextAlign.center, // Add this
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

      // extract the data
      final responseData = results['data'];
      if (responseData == null) {
        throw Exception('No data in response');
      }

      // the actual roadmap data is in responseData['data']
      final roadmapData = responseData['data'];
      if (roadmapData == null) {
        throw Exception('No roadmap data found');
      }

      // transform the data into the structure needed for the UI
      final Map<String, Map<String, List<String>>> levels = {};

      // process topics and sub_topics
      if (roadmapData['topics'] != null && roadmapData['sub_topics'] != null) {
        final topics = Map<String, dynamic>.from(roadmapData['topics']);
        final subTopics = Map<String, dynamic>.from(roadmapData['sub_topics']);

        topics.forEach((topicName, level) {
          final levelName = _formatLevelName(level.toString());
          final topicSubTopics = List<String>.from(subTopics[topicName] ?? []);

          if (!levels.containsKey(levelName)) {
            levels[levelName] = {};
          }
          levels[levelName]![topicName] = topicSubTopics;
        });
      }

      setState(() {
        roadmap = {
          'user_test_id': roadmapData['user_test_id'] ?? widget.userTestId,
          'job_index': roadmapData['job_index'] ?? currentJobIndex,
          'job_title': currentJobTitle,
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
      case 'beginner':
        return 'Beginner';
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(width: 12),
            Text(
              'Loading careers...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(
              Icons.work_off_outlined,
              size: 20,
              color: Colors.grey[400],
            ),
            const SizedBox(width: 12),
            Text(
              'No recommended jobs found',
              style: TextStyle(
                color: Colors.grey[600],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: DropdownButton<String>(
          value: currentJobIndex,
          isExpanded: true,
          underline: const SizedBox(), // Remove default underline
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: Colors.grey[600],
            size: 24,
          ),
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          onChanged: _onJobSelected,
          items: [
            // Default hint item
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
            // Career items
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
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Career #${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[700],
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
                            color: Colors.black87,
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
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 3),
            SizedBox(height: 20),
            Text(
              'Loading your career roadmap...',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey[300]!, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.school_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Nothing to see here D:',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Complete your assessments to unlock your\npersonalized career roadmap! :D',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey[50]!,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.route_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Personalized Career Roadmap',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
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
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your step-by-step learning journey to become a ${currentJobTitle ?? 'professional'}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
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
      final order = {
        'Beginner': 0,
        'Intermediate': 1,
        'Advanced': 2,
        'Expert': 3
      };
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
            height: 50, // Longer arrow
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.arrow_downward_rounded,
                    color: Colors.grey[500],
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 2,
                    width: 3,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 2,
                    width: 3,
                    color: Colors.grey[400],
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
        case 'beginner':
        case 'basic': // handle both 'Beginner' and 'Basic'
          return const Color(0xFF4CAF50); // Green
        case 'intermediate':
          return const Color(0xFF2196F3); // Blue
        case 'advanced':
          return const Color(0xFFFF9800); // Orange/Yellow
        case 'expert':
          return const Color(0xFFF44336); // Red
        default:
          // Fallback color based on position
          return const Color(0xFF4CAF50);
      }
    }

    final backgroundColor = _getLevelColor(levelName);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: backgroundColor.withOpacity(0.3),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
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
                // level header with improved design
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
                      // Level indicator with number
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
                                fontWeight: FontWeight.w800,
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

                // Topics list with improved visual hierarchy
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Topic name with improved design
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
                          color: Colors.black87,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (subTopics.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        // Subtopic list with arrow indicators
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
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700],
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
      backgroundColor: const Color(0xFFF8F9FC),
      appBar: AppBar(
        title: const Text(
          'Career Roadmap',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey[200],
            height: 1,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Career Journey',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select a career path and follow the learning roadmap',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            _buildJobSelector(),
            const SizedBox(height: 24),
            _buildRoadmapContent(),
          ],
        ),
      ),
      persistentFooterButtons: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
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
                  backgroundColor: Theme.of(context).primaryColor,
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
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _canRetake ? _handleRetake : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).primaryColor,
                  side: BorderSide(
                    color: _canRetake
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300]!,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _canRetake
                      ? "Retake Test (Attempt ${_userAttempts.length + 1})"
                      : _userAttempts.length >= 10
                          ? "Max Attempts Reached"
                          : "Retake Available in $_daysUntilRetake days",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
