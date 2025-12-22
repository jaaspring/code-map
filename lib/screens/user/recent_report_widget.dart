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

      // get userTestId from users collection (as saved in CareerGoals)
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        _userTestId = userDoc.data()?['userTestId'];
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
      // load all 3 job recommendations
      for (int jobIndex = 0; jobIndex < 3; jobIndex++) {
        try {
          final response = await ApiService.generateReport(
              _userTestId!, jobIndex.toString());

          if (response['data'] != null && response['data']['job'] != null) {
            _availableJobs.add({
              'job_index': jobIndex.toString(),
              'job_title':
                  response['data']['job']['job_title'] ?? 'Job ${jobIndex + 1}',
              'job_description':
                  response['data']['job']['job_description'] ?? '',
              'report_data': response['data'],
            });
          }
        } catch (e) {
          print('Error loading job $jobIndex: $e');
          // continue with other jobs
        }
      }

      if (_availableJobs.isNotEmpty) {
        // select first job by default
        _selectedJob = _availableJobs.first;
        _reportData = _selectedJob!['report_data'];

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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header with job dropdown toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // left side - icon and title
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.assessment,
                        color: Color(0xFF2F8D46),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Recent Career Recommendations',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // right side - dropdown button (only show if we have multiple jobs)
              if (_availableJobs.length > 1) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () =>
                      setState(() => _showJobDropdown = !_showJobDropdown),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F8D46).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_availableJobs.length} jobs',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2F8D46),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _showJobDropdown
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                          color: const Color(0xFF2F8D46),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),

          // job dropdown
          if (_showJobDropdown && _availableJobs.length > 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: _availableJobs.map((job) {
                  final isSelected =
                      _selectedJob?['job_index'] == job['job_index'];
                  return GestureDetector(
                    onTap: () => _onJobSelected(job),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? const Color(0xFFE8F5E9) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2F8D46).withOpacity(0.3)
                              : Colors.grey[300]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2F8D46)
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                '#${int.parse(job['job_index']) + 1}',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              job['job_title'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF1B5E20)
                                    : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
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

          // main content
          const SizedBox(height: 16),

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

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 8),
          Text(
            'Loading your career recommendations...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        Icon(
          Icons.work_outline,
          color: Colors.grey[400],
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _loadRecentReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2F8D46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Try Again',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoReportState() {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.work_outline,
            color: Colors.grey[400],
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'No career recommendations yet',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Complete an assessment to see your matches',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
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

    return Column(
      children: [
        // Current job indicator
        if (_availableJobs.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2F8D46).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Recommendation ${int.parse(_selectedJob!['job_index']) + 1} of ${_availableJobs.length}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2F8D46),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Report content
        GestureDetector(
          onTap: () {
            if (_userTestId != null && _selectedJob != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReportScreen(
                    userTestId: _userTestId!,
                    jobIndex: _selectedJob!['job_index'],
                  ),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FDF9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2F8D46).withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  jobTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _truncateText(jobDescription, maxLength: 120),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Quick stats if available
                if (_reportData!['job']?['required_skills'] != null)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 12, color: Colors.blue[700]),
                            const SizedBox(width: 4),
                            Text(
                              '${(_reportData!['job']['required_skills'] as Map).length} skills',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Action buttons - IMPROVED
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (_userTestId != null && _selectedJob != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReportScreen(
                          userTestId: _userTestId!,
                          jobIndex: _selectedJob!['job_index'],
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F8D46),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'View Full Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            if (_availableJobs.length > 1) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final currentIndex = int.parse(_selectedJob!['job_index']);
                    final nextIndex =
                        (currentIndex + 1) % _availableJobs.length;
                    _onJobSelected(_availableJobs[nextIndex]);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8F5E9),
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Icon(
                    Icons.navigate_next,
                    color: Color(0xFF2F8D46),
                    size: 20,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
