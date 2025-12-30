import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:code_map/services/api_service.dart';
import '../results/report.dart';

class RecentReportWidget extends StatefulWidget {
  const RecentReportWidget({Key? key}) : super(key: key);

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

      // load all 3 job recommendations
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
          // continue with other jobs
        }
      }

      // sort jobs by similarity percentage (highest first)
      _availableJobs.sort((a, b) {
        final aPercent =
            double.tryParse(a['similarity_percentage']?.toString() ?? '0') ?? 0;
        final bPercent =
            double.tryParse(b['similarity_percentage']?.toString() ?? '0') ?? 0;
        return bPercent.compareTo(aPercent);
      });

      print("\n=== LOADED ${_availableJobs.length} JOBS ===");
      for (var i = 0; i < _availableJobs.length; i++) {
        print(
            "Job $i: ${_availableJobs[i]['job_title']} - ${_availableJobs[i]['similarity_percentage']}%");
      }

      if (_availableJobs.isNotEmpty) {
        // select first job by default (now the highest percentage)
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
    if (percentage >= 80) return const Color(0xFF2F8D46); // Green for excellent
    if (percentage >= 70)
      return const Color(0xFF4CAF50); // Light green for good
    if (percentage >= 60) return const Color(0xFFF57C00); // Orange for average
    return const Color(0xFFD32F2F); // Red for low
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2F8D46),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F8D46).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FIXED: Header Row with proper constraints
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side - Best Match badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2F8D46),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Best Match',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'RobotoMono',
                      ),
                    ),
                  ],
                ),
              ),

              // Middle - similarity percentage with proper spacing
              if (_selectedJob != null)
                Expanded(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252525),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_selectedJob!['similarity_percentage']}% match',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'RobotoMono',
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),

              // Right side - dropdown button (only show if we have multiple jobs)
              if (_availableJobs.length > 1)
                Container(
                  constraints: BoxConstraints(maxWidth: 120),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _showJobDropdown = !_showJobDropdown),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '1 of ${_availableJobs.length} Jobs',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black,
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
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Job dropdown
          if (_showJobDropdown && _availableJobs.length > 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF3A3A3A)),
              ),
              child: Column(
                children: _availableJobs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final job = entry.value;
                  final isSelected =
                      _selectedJob?['job_index'] == job['job_index'];
                  final similarity = double.tryParse(
                          job['similarity_percentage']?.toString() ?? '0') ??
                      0;
                  final rank = index + 1;

                  return GestureDetector(
                    onTap: () => _onJobSelected(job),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2F8D46).withOpacity(0.2)
                            : const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2F8D46)
                              : const Color(0xFF3A3A3A),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Ranking badge
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _getSimilarityColor(similarity),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                _getRankingIcon(rank),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: rank == 1 ? 14 : 12,
                                  fontWeight: FontWeight.bold,
                                ),
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
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${similarity.toStringAsFixed(1)}% match',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _getSimilarityColor(similarity),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF2F8D46),
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Main content
          const SizedBox(height: 20),

          if (_isLoading)
            Center(child: _buildLoadingState())
          else if (_errorMessage != null)
            Center(child: _buildErrorState())
          else if (_reportData != null)
            _buildReportContent()
          else
            Center(child: _buildNoReportState()),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF2F8D46),
          ),
          SizedBox(height: 8),
          Text(
            'Loading your career recommendations...',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.work_outline,
          color: Colors.grey[600],
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }

  Widget _buildNoReportState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.work_outline,
            color: Colors.grey[600],
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'No career recommendations yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete an assessment to see your matches',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

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
        // Job title - Modern design
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Text(
            jobTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Poppins',
              height: 1.2,
            ),
          ),
        ),

        const SizedBox(height: 4),

        // Job description with modern styling
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Text(
            jobDescription,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[300],
              height: 1.6,
              fontFamily: 'Poppins',
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        const SizedBox(height: 16),

        // Skills badge - Modern design
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
                    color: const Color(0xFF2F8D46).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF2F8D46),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt,
                        size: 14,
                        color: Color(0xFF2F8D46),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(_reportData!['job']['required_skills'] as Map).length} skills match',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Modern buttons row
        Container(
          height: 48,
          child: Row(
            children: [
              // Previous button (only if multiple jobs)
              if (_availableJobs.length > 1)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2F8D46),
                      width: 2,
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      final currentIndex = _availableJobs.indexWhere((job) =>
                          job['job_index'] == _selectedJob!['job_index']);
                      final prevIndex =
                          (currentIndex - 1 + _availableJobs.length) %
                              _availableJobs.length;
                      _onJobSelected(_availableJobs[prevIndex]);
                    },
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Color(0xFF2F8D46),
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),

              if (_availableJobs.length > 1) const SizedBox(width: 12),

              // View report button
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF2F8D46),
                        Color(0xFF4CAF50),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2F8D46).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              if (_availableJobs.length > 1) const SizedBox(width: 12),

              // Next button (only if multiple jobs)
              if (_availableJobs.length > 1)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2F8D46),
                      width: 2,
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      final currentIndex = _availableJobs.indexWhere((job) =>
                          job['job_index'] == _selectedJob!['job_index']);
                      final nextIndex =
                          (currentIndex + 1) % _availableJobs.length;
                      _onJobSelected(_availableJobs[nextIndex]);
                    },
                    icon: Icon(
                      Icons.chevron_right,
                      color: const Color(0xFF2F8D46),
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
