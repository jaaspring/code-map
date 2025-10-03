// screens/career_recommendations_screen.dart
import 'package:flutter/material.dart';
import '../../models/user_profile_match.dart';
import '../../services/api_service.dart';
import 'package:code_map/screens/results/skill_gap_analysis.dart';

class CareerRecommendationsScreen extends StatefulWidget {
  final String userTestId;

  const CareerRecommendationsScreen({super.key, required this.userTestId});

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

  @override
  void initState() {
    super.initState();
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

      if (result == null) {
        print('FAILED: API returned NULL result');
        setState(() {
          _errorMessage = "Failed to fetch profile match.";
          _isLoading = false;
        });
        return;
      }

      print(
          'SUCCESS: API call completed! Total jobs: ${result.topMatches.length}');
      setState(() {
        _profileMatch = result;
      });

      await _precomputeSkillGaps();

      if (_profileMatch!.topMatches.isNotEmpty) {
        _selectedJobIndex = _profileMatch!.topMatches[0].jobIndex;
        _expandedCards[_selectedJobIndex!] = true;
        print('Selected first job by default: Index $_selectedJobIndex');
      }
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

  Future<void> _precomputeSkillGaps() async {
    if (_profileMatch == null) return;

    try {
      final allGaps =
          await ApiService.getGapAnalysis(userTestId: widget.userTestId);

      setState(() {
        for (var job in _profileMatch!.topMatches) {
          print('Mapping skill gaps for job "${job.jobTitle}"');

          final gap = allGaps.firstWhere(
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

            print(
                'Mapped job "${job.jobTitle}" -> dbJobIndex: ${job.dbJobIndex}');
          } else {
            print(
                'No gap found for job "${job.jobTitle}" (job_index=${job.jobIndex})');
          }
        }
      });

      print('Skill gaps computed for all jobs!');
    } catch (e) {
      print('Error computing skill gaps: $e');
    }
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

  Widget _buildJobCard(JobMatch job) {
    final bool isExpanded = _expandedCards[job.jobIndex] ?? false;
    final bool isSelected = _selectedJobIndex == job.jobIndex;

    return Card(
      elevation: isSelected ? 4 : 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      color: isSelected ? Colors.blue[50] : null,
      child: InkWell(
        onTap: () => _selectCareer(job.jobIndex),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      job.jobTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            isSelected ? Theme.of(context).primaryColor : null,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      "${job.similarityPercentage.toStringAsFixed(2)}% Match",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: _getMatchColor(job.similarityPercentage),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!isExpanded) _buildShortJobPreview(job.jobDescription),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                ..._buildFullJobDescription(job.jobDescription),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      isSelected ? "Selected" : "Tap to select",
                      style: TextStyle(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillsCard(JobMatch job) {
    if (job.requiredSkills == null || job.requiredSkills!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Required Skills:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: job.requiredSkills!.keys.map((skill) {
                return Chip(
                  label: Text(skill),
                  backgroundColor: Colors.blue[50],
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKnowledgeCard(JobMatch job) {
    if (job.requiredKnowledge == null || job.requiredKnowledge!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Required Knowledge:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: job.requiredKnowledge!.keys.map((knowledge) {
                return Chip(
                  label: Text(knowledge),
                  backgroundColor: Colors.green[50],
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ),
      ),
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
      style: const TextStyle(fontSize: 14, color: Colors.grey),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<Widget> _buildFullJobDescription(String description) {
    final List<Widget> widgets = [];
    widgets.add(
      const Text(
        "Career Description:",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
    widgets.add(const SizedBox(height: 8));
    widgets.addAll(_formatJobDescription(description));
    return widgets;
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
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: Text(line.substring(2).trim())),
              ],
            ),
          ),
        );
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(line),
        ));
      }
    }

    return widgets;
  }

  Color _getMatchColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.blue;
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Career Recommendations")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "Recommended Career Paths",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._profileMatch!.topMatches
                          .map((job) => _buildJobCard(job)),
                      if (_selectedJobIndex != null) ...[
                        for (final job in _profileMatch!.topMatches)
                          if (job.jobIndex == _selectedJobIndex) ...[
                            _buildSkillsCard(job),
                            _buildKnowledgeCard(job),
                          ],
                      ],
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_selectedJobIndex != null &&
                                  _profileMatch != null) {
                                final selectedJob = _profileMatch!.topMatches
                                    .firstWhere((job) =>
                                        job.jobIndex == _selectedJobIndex);
                                if (selectedJob.dbJobIndex != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          SkillGapAnalysisScreen(
                                        userTestId: widget.userTestId,
                                        jobIndex: selectedJob.dbJobIndex!,
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
                                    content: Text(
                                        'Please select a career path first'),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Proceed to Skill Gap Analysis",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
