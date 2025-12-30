import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:code_map/services/api_service.dart';
import '../results/report.dart';

class RecentReportWidget extends StatefulWidget {
  const RecentReportWidget({super.key});

  @override
  _RecentReportWidgetState createState() => _RecentReportWidgetState();
}

class _RecentReportWidgetState extends State<RecentReportWidget> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _availableJobs = [];
  Map<String, dynamic>? _selectedJob;
  Map<String, dynamic>? _reportData;
  String? _userTestId;
  int? _attemptNumber;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showJobDropdown = false;
  String? _highestSimilarityJobIndex;

  @override
  void initState() {
    super.initState();
    _loadRecentReport();
  }

  Future<void> _loadRecentReport() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;

        _userTestId = data['userTestId'];

        if (_userTestId != null && _userTestId!.isNotEmpty) {
          await _loadAllJobs();
        } else {
          setState(() {
            _errorMessage = 'No assessment taken yet';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'User document not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading recent report: $e');
      setState(() {
        _errorMessage = 'Error loading report: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllJobs() async {
    if (_userTestId == null) return;

    try {
      print("=== LOADING JOBS DEBUG ===");
      print("UserTestId: $_userTestId");
      print("Attempt: $_attemptNumber");

      for (int jobIndex = 0; jobIndex < 3; jobIndex++) {
        try {
          final response = await ApiService.generateReport(
              _userTestId!, jobIndex.toString());

          print("\nJob $jobIndex Response:");
          print("Job Title: ${response['data']?['job']?['job_title']}");
          print(
              "Job Desc: ${response['data']?['job']?['job_description']?.substring(0, 50)}...");

          if (response['data'] != null && response['data']['job'] != null) {
            _availableJobs.add({
              'job_index': jobIndex.toString(),
              'job_title':
                  response['data']['job']['job_title'] ?? 'Job ${jobIndex + 1}',
              'job_description':
                  response['data']['job']['job_description'] ?? '',
              'similarity_percentage':
                  response['data']['job']['similarity_percentage'] ?? '',
              'report_data': response['data'],
            });
          }
        } catch (e) {
          print('Error loading job $jobIndex: $e');
        }
      }

      // Sort jobs by similarity percentage (highest first)
      _availableJobs.sort((a, b) {
        final aPercent =
            double.tryParse(a['similarity_percentage']?.toString() ?? '0') ?? 0;
        final bPercent =
            double.tryParse(b['similarity_percentage']?.toString() ?? '0') ?? 0;
        return bPercent.compareTo(aPercent);
      });

      if (_availableJobs.isNotEmpty) {
        _highestSimilarityJobIndex = _availableJobs.first['job_index'];
        print("Highest similarity job index: $_highestSimilarityJobIndex");
      }

      print("\n=== LOADED ${_availableJobs.length} JOBS ===");
      for (var i = 0; i < _availableJobs.length; i++) {
        print(
            "Job $i: ${_availableJobs[i]['job_title']} - ${_availableJobs[i]['similarity_percentage']}%");
      }

      if (_availableJobs.isNotEmpty) {
        _selectedJob = _availableJobs.first;
        _reportData = _selectedJob!['report_data'];

        print("\nSELECTED JOB: ${_selectedJob!['job_title']}");

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'No job recommendations found';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading jobs: $e');
      setState(() {
        _errorMessage = 'Error loading job recommendations: $e';
        _isLoading = false;
      });
    }
  }

  void _onJobSelected(Map<String, dynamic> job) {
    setState(() {
      _selectedJob = job;
      _reportData = job['report_data'];
      _showJobDropdown = false;
    });
  }

  String _truncateText(String text, {int maxLength = 80}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  Color _getSimilarityColor(double percentage) {
    if (percentage >= 80) return const Color(0xFF4BC945);
    if (percentage >= 70) return const Color(0xFF5FD954);
    if (percentage >= 60) return const Color(0xFF73E963);
    return const Color(0xFF87F972);
  }

  @override
  Widget build(BuildContext context) {
    final bool showBestMatchLabel = _selectedJob != null &&
        _highestSimilarityJobIndex != null &&
        _selectedJob!['job_index'] == _highestSimilarityJobIndex;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // FLEXIBLE HEADER SECTION
          _buildHeaderSection(showBestMatchLabel),

          // CONDITIONAL DROPDOWN SECTION
          if (_showJobDropdown && _availableJobs.length > 1)
            _buildDropdownSection(),

          // MAIN CONTENT SECTION
          const SizedBox(height: 20),

          if (_isLoading)
            _buildLoadingState()
          else if (_errorMessage != null)
            _buildErrorState()
          else if (_reportData != null)
            _buildReportContent()
          else
            _buildNoReportState(),
        ],
      ),
    );
  }

  // HEADER SECTION - Flexible with adaptive layout
  Widget _buildHeaderSection(bool showBestMatchLabel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 400;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT SECTION - Match badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedJob != null)
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        if (showBestMatchLabel) ...[
                          _buildBestMatchBadge(),
                          const SizedBox(width: 8),
                        ],
                        Flexible(child: _buildSimilarityBadge(_selectedJob!)),
                      ],
                    ),
                  // Additional header content can be added here
                ],
              ),
            ),

            // RIGHT SECTION - Dropdown button
            if (_availableJobs.length > 1)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    // allow it to shrink on narrow screens
                    maxWidth: isCompact ? 120 : constraints.maxWidth * 0.45,
                  ),
                  child: _buildDropdownButton(isCompact),
                ),
              ),
          ],
        );
      },
    );
  }

  // BEST MATCH BADGE
  Widget _buildBestMatchBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF4BC945),
            Color(0xFF3BA535),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF4BC945).withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/star_icon.png',
            width: 14,
            height: 14,
            color: Colors.white,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 6),
          Text(
            'Best Match',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // SIMILARITY BADGE
  Widget _buildSimilarityBadge(Map<String, dynamic> job) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4BC945).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        '${job['similarity_percentage']}% match',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4BC945),
          letterSpacing: 0.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // DROPDOWN BUTTON
  Widget _buildDropdownButton(bool isCompact) {
    final currentIndex = _selectedJob != null
        ? _availableJobs.indexWhere(
                (job) => job['job_index'] == _selectedJob!['job_index']) +
            1
        : 1;

    return GestureDetector(
      onTap: () => setState(() => _showJobDropdown = !_showJobDropdown),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        constraints: const BoxConstraints(maxWidth: 180),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4BC945),
              Color(0xFF3BA535),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF4BC945).withOpacity(0.2),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                isCompact
                    ? '$currentIndex/${_availableJobs.length}'
                    : '$currentIndex of ${_availableJobs.length} Jobs',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _showJobDropdown
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              size: 18,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  // DROPDOWN SECTION - Clean design without medals or check marks
  Widget _buildDropdownSection() {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1A1A1A)),
          ),
          child: Column(
            children: _availableJobs.asMap().entries.map((entry) {
              final index = entry.key;
              final job = entry.value;
              final isSelected = _selectedJob?['job_index'] == job['job_index'];
              final similarity = double.tryParse(
                      job['similarity_percentage']?.toString() ?? '0') ??
                  0;
              final isBestMatch =
                  job['job_index'] == _highestSimilarityJobIndex;

              return GestureDetector(
                onTap: () => _onJobSelected(job),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFF0D0D0D),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF4BC945)
                          : const Color(0xFF1A1A1A),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // SIMILARITY INDICATOR
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getSimilarityColor(similarity),
                              _getSimilarityColor(similarity).withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${similarity.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: similarity >= 60
                                  ? Color(0xFF000000)
                                  : Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // JOB INFO
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    job['job_title'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: Colors.white,
                                      fontFamily: 'Poppins',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rank #${index + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7F6B), // Muted sage green
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // LOADING STATE
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF4BC945),
          ),
          const SizedBox(height: 8),
          Text(
            'Loading your career recommendations...',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  // ERROR STATE
  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          color: Color(0xFF666666),
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF666666),
            fontSize: 12,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  // NO REPORT STATE
  Widget _buildNoReportState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF121212),
              border: Border.all(
                color: const Color(0xFF1A1A1A),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.work_outline,
                size: 40,
                color: Color(0xFF666666),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No career\nrecommendations yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete an assessment to see your matches! :D',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 12,
              fontFamily: 'Poppins',
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // REPORT CONTENT - Flexible structure
  Widget _buildReportContent() {
    final jobTitle =
        _reportData!['job']?['job_title'] ?? 'Job Title Not Available';
    final jobDescription = _reportData!['job']?['job_description'] ??
        'Job description not available';
    final similarity = double.tryParse(
            _selectedJob?['similarity_percentage']?.toString() ??
                _reportData!['job']?['similarity_percentage']?.toString() ??
                '0') ??
        0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // JOB TITLE
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Text(
            jobTitle,
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ),

        // JOB DESCRIPTION
        const SizedBox(height: 4),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Text(
            jobDescription,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFCCCCCC),
              height: 1.6,
              fontFamily: 'Poppins',
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // SKILLS MATCH
        if (_reportData!['job']?['required_skills'] != null)
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF4BC945),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 6),
                      Text(
                        '${(_reportData!['job']['required_skills'] as Map).length} skills match',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // ACTION BUTTONS
        _buildActionButtons(),
      ],
    );
  }

  // ACTION BUTTONS - Responsive layout
  Widget _buildActionButtons() {
    final hasMultipleJobs = _availableJobs.length > 1;

    return Container(
      height: 48,
      child: Row(
        children: [
          // PREVIOUS BUTTON
          if (hasMultipleJobs) ...[
            _buildNavButton(
              iconWidget: Image.asset(
                'assets/left_arrow.png',
                width: 20,
                height: 20,
                color: Colors.white,
                fit: BoxFit.contain,
              ),
              onPressed: () {
                final currentIndex = _availableJobs.indexWhere(
                    (job) => job['job_index'] == _selectedJob!['job_index']);
                final prevIndex = (currentIndex - 1 + _availableJobs.length) %
                    _availableJobs.length;
                _onJobSelected(_availableJobs[prevIndex]);
              },
            ),
            const SizedBox(width: 12),
          ],

          // VIEW REPORT BUTTON
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF4BC945),
                    Color(0xFF3BA535),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF4BC945).withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  if (_userTestId != null && _selectedJob != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CareerAnalysisReport(
                          userTestId: _userTestId!,
                          jobIndex: _selectedJob!['job_index'],
                          attemptNumber: _attemptNumber,
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Center(
                  child: Text(
                    'View Report',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // NEXT BUTTON
          if (hasMultipleJobs) ...[
            const SizedBox(width: 12),
            _buildNavButton(
              iconWidget: Image.asset(
                'assets/right_arrow.png',
                width: 20,
                height: 20,
                color: Colors.white,
                fit: BoxFit.contain,
              ),
              onPressed: () {
                final currentIndex = _availableJobs.indexWhere(
                    (job) => job['job_index'] == _selectedJob!['job_index']);
                final nextIndex = (currentIndex + 1) % _availableJobs.length;
                _onJobSelected(_availableJobs[nextIndex]);
              },
            ),
          ],
        ],
      ),
    );
  }

  // NAVIGATION BUTTON
  Widget _buildNavButton({
    required Widget iconWidget,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF4BC945),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: iconWidget,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
