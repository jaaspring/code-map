import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/user_profile_match.dart';
import '../../services/api_service.dart';
import 'package:code_map/screens/results/gap_analysis.dart';
import '../../utils/retake_service.dart';

class CareerRecommendationsScreen extends StatefulWidget {
  final String userTestId;
  final int attemptNumber;

  const CareerRecommendationsScreen({
    super.key,
    required this.userTestId,
    required this.attemptNumber,
  });

  @override
  State<CareerRecommendationsScreen> createState() =>
      _CareerRecommendationsScreenState();
}

class _CareerRecommendationsScreenState
    extends State<CareerRecommendationsScreen> {
  UserProfileMatchResponse? _profileMatch;
  bool _isLoading = true;
  String? _errorMessage;
  final Map<String, bool> _expandedCards = {};
  String? _selectedJobIndex;
  List<Map<String, dynamic>>? _allGaps;

  @override
  void initState() {
    super.initState();
    _expandedCards.clear();
    _selectedJobIndex = null;
    _fetchProfileMatch();
  }

  Future<void> _fetchProfileMatch() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('STARTED: Fetching profile match...');
      final result =
          await ApiService.getUserProfileMatch(userTestId: widget.userTestId);
      print('getUserProfileMatch completed');

      if (result == null) {
        print('FAILED: API returned NULL result');
        setState(() {
          _errorMessage = "Failed to fetch profile match.";
          _isLoading = false;
        });
        return;
      }

      print('Result received, jobMatches: ${result.jobMatches.length}');
      print(
          'SUCCESS: API call completed! Total jobs: ${result.jobMatches.length}');
      setState(() {
        _profileMatch = result;
      });

      await _precomputeGaps();

      if (_profileMatch!.jobMatches.isNotEmpty) {
        _selectedJobIndex = _profileMatch!.jobMatches[0].jobIndex;
        _expandedCards[_selectedJobIndex!] = true;
        print('Selected first job by default: Index $_selectedJobIndex');
      }

      await _markTestAsCompleted();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _precomputeGaps() async {
    if (_profileMatch == null) return;

    try {
      print(
          'DEBUG: Fetching gap analysis for userTestId: ${widget.userTestId}');

      _allGaps = await ApiService.getGapAnalysis(userTestId: widget.userTestId);
      print('DEBUG: Received ${_allGaps!.length} total gap analysis entries');

      setState(() {
        for (var job in _profileMatch!.jobMatches) {
          final gap = _allGaps!.firstWhere(
            (g) => g["job_index"]?.toString() == job.jobIndex,
            orElse: () => {},
          );

          if (gap.isNotEmpty) {
            job.dbJobIndex = gap["job_index"]?.toString();
            job.requiredSkills = gap["gap_analysis"]?["skills"] is Map
                ? Map<String, dynamic>.from(gap["gap_analysis"]!["skills"])
                : {};
            job.requiredKnowledge = gap["gap_analysis"]?["knowledge"] is Map
                ? Map<String, dynamic>.from(gap["gap_analysis"]!["knowledge"])
                : {};
          }
        }
      });
    } catch (e) {
      print('Error computing skill gaps: $e');
    }
  }

  Future<void> _markTestAsCompleted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await RetakeService.updateAttemptStatus(
      userId: user.uid,
      testId: widget.userTestId,
      status: 'Completed',
    );
  }

  void _selectCareer(String jobIndex) {
    setState(() {
      if (_selectedJobIndex == jobIndex) {
        _expandedCards[jobIndex] = !(_expandedCards[jobIndex] ?? false);
      } else {
        _selectedJobIndex = jobIndex;
        _expandedCards[jobIndex] = true;
      }
    });
  }

  Widget _buildMatchBadge(double percentage) {
    final color = _getMatchColor(percentage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${percentage.toStringAsFixed(1)}% Match',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(JobMatch job) {
    final bool isExpanded = _expandedCards[job.jobIndex] ?? false;
    final bool isSelected = _selectedJobIndex == job.jobIndex;
    final matchColor = _getMatchColor(job.similarityPercentage);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        elevation: isSelected ? 8 : 2,
        borderRadius: BorderRadius.circular(16),
        color: Colors.black,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(
                    color: matchColor,
                    width: 2,
                  )
                : Border.all(
                    color: const Color.fromARGB(30, 255, 255, 255),
                    width: 1,
                  ),
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      matchColor.withOpacity(0.05),
                      matchColor.withOpacity(0.02),
                      Colors.transparent,
                    ],
                  )
                : null,
          ),
          child: InkWell(
            onTap: () => _selectCareer(job.jobIndex),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          job.jobTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? matchColor : Colors.white,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildMatchBadge(job.similarityPercentage),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!isExpanded) _buildShortJobPreview(job.jobDescription),
                  if (isExpanded) ...[
                    const SizedBox(height: 16),
                    _buildFullJobDescription(job.jobDescription),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? matchColor.withOpacity(0.1)
                              : const Color.fromARGB(30, 255, 255, 255),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.circle,
                              size: 12,
                              color: isSelected ? matchColor : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isSelected ? "Selected" : "Tap to select",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSelected ? matchColor : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: isSelected ? matchColor : Colors.grey,
                        size: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkillsSection(JobMatch job) {
    if (job.requiredSkills == null || job.requiredSkills!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "Key Skills",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: job.requiredSkills!.keys.map((skill) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF333333),
                  width: 1,
                ),
              ),
              child: Text(
                skill,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4BC945),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildKnowledgeSection(JobMatch job) {
    if (job.requiredKnowledge == null || job.requiredKnowledge!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            "Required Knowledge",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: job.requiredKnowledge!.keys.map((knowledge) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF333333),
                  width: 1,
                ),
              ),
              child: Text(
                knowledge,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF4BC945),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildShortJobPreview(String description) {
    String previewText = description;
    final firstPeriod = description.indexOf('.');
    if (firstPeriod != -1 && firstPeriod < 120) {
      previewText = description.substring(0, firstPeriod + 1);
    } else {
      previewText = description.length > 120
          ? '${description.substring(0, 120)}...'
          : description;
    }

    return Text(
      previewText,
      style: TextStyle(
        fontSize: 14,
        color: Colors.white.withOpacity(0.7),
        height: 1.5,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFullJobDescription(String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            "Career Overview",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        ..._formatJobDescription(description),
      ],
    );
  }

  List<Widget> _formatJobDescription(String description) {
    final List<Widget> widgets = [];
    final lines = description.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('- ') || line.startsWith('• ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.circle,
                  size: 6,
                  color: Colors.white.withOpacity(0.5),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    line.substring(2).trim(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.8),
                height: 1.5,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  Color _getMatchColor(double percentage) {
    if (percentage >= 80) return const Color(0xFF4BC945);
    if (percentage >= 60) return const Color(0xFF4BC945);
    if (percentage >= 40) return const Color(0xFFFFB74D);
    return const Color(0xFFFF6B6B);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Career Recommendations",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Based on your assessment results",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),

              // Content
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF4BC945)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Analyzing your results...",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.red,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Your Top Career Paths",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Select one to view detailed analysis",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Job Cards
                                ..._profileMatch!.jobMatches
                                    .map((job) => _buildJobCard(job)),

                                // Selected Job Details
                                if (_selectedJobIndex != null) ...[
                                  for (final job in _profileMatch!.jobMatches)
                                    if (job.jobIndex == _selectedJobIndex) ...[
                                      const SizedBox(height: 24),
                                      _buildSkillsSection(job),
                                      const SizedBox(height: 24),
                                      _buildKnowledgeSection(job),
                                    ],
                                ],

                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
              ),

              // Proceed Button
              if (!_isLoading && _errorMessage == null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_selectedJobIndex != null && _profileMatch != null) {
                        final selectedJob = _profileMatch!.jobMatches
                            .firstWhere(
                                (job) => job.jobIndex == _selectedJobIndex);

                        if (_allGaps != null && _allGaps!.isNotEmpty) {
                          final gapEntry = _allGaps!.firstWhere(
                            (g) =>
                                g["job_index"]?.toString() ==
                                selectedJob.jobIndex,
                            orElse: () => {},
                          );

                          if (gapEntry.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GapAnalysisScreen(
                                  userTestId: widget.userTestId,
                                  jobIndex: selectedJob.dbJobIndex!,
                                  attemptNumber: widget.attemptNumber,
                                  preloadedGapData: gapEntry,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Skill gap data is not available for "${selectedJob.jobTitle}"'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Gap analysis data not loaded yet'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a career path first'),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4BC945),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "View Skill Gap Analysis",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
