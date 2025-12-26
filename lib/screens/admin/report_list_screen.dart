import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:convert';

class ReportListScreen extends StatefulWidget {
  const ReportListScreen({super.key});

  @override
  State<ReportListScreen> createState() => _ReportListScreenState();
}

class _ReportListScreenState extends State<ReportListScreen> {
  static const Color geekGreen = Color(0xFF2F8D46);
  static const Color geekDarkGreen = Color(0xFF1B5E20);
  static const Color geekLightGreen = Color(0xFF4CAF50);
  static const Color geekBackground = Color(0xFFE8F5E9);
  static const Color geekCardBg = Color(0xFFFFFFFF);

  List<Map<String, dynamic>> _recommendations = [];
  Map<String, Map<String, dynamic>> _userData = {};
  bool _isLoading = true;
  Map<String, bool> _expandedStates = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();

      final Map<String, Map<String, dynamic>> testIdToUserMap = {};

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final testIds = (userData['testIds'] as List<dynamic>? ?? [])
            .map((id) => id.toString())
            .toList();

        final userInfo = {
          'name': userData['name'] ?? 'Unknown',
          'username': userData['username'] ?? 'N/A',
          'email': userData['email'] ?? 'No Email',
          'uid': userDoc.id,
        };

        for (final testId in testIds) {
          testIdToUserMap[testId] = userInfo;
        }
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('career_recommendations')
          .get();

      List<Map<String, dynamic>> data = [];

      for (var doc in snapshot.docs) {
        final recData = doc.data();
        final userTestId = recData['user_test_id']?.toString() ?? 'N/A';

        final userInfo = testIdToUserMap[userTestId] ??
            {
              'name': 'Unknown User',
              'username': 'N/A',
              'email': 'No Email',
              'uid': 'N/A',
            };

        final jobsSnapshot =
            await doc.reference.collection('job_matches').get();

        final jobs = jobsSnapshot.docs.map((jobDoc) {
          final jobData = jobDoc.data();
          return {
            ...jobData,
            'id': jobDoc.id,
          };
        }).toList();

        data.add({
          'user_test_id': userTestId,
          'profile': recData['profile_text'],
          'jobs': jobs,
          'doc_id': doc.id,
          'user_info': userInfo,
        });
        _expandedStates[userTestId] = false;
      }

      data.sort((a, b) => a['user_test_id'].compareTo(b['user_test_id']));

      setState(() {
        _recommendations = data;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading data: $e");
      setState(() => _isLoading = false);
    }
  }

  void _toggleExpansion(String userTestId) {
    setState(() {
      _expandedStates[userTestId] = !(_expandedStates[userTestId] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: geekBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: geekDarkGreen),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Career Recommendations',
          style: TextStyle(color: geekDarkGreen),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'User Report List',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: geekDarkGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_recommendations.length} tests • ${_getUniqueUserCount()} users',
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
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: geekGreen,
                          strokeWidth: 2,
                        ),
                      )
                    : _recommendations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.work_outline,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No recommendations found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User Reports (${_recommendations.length})',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: geekDarkGreen,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _recommendations.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final rec = _recommendations[index];
                                    final userTestId =
                                        rec['user_test_id']?.toString() ??
                                            'N/A';
                                    final isExpanded =
                                        _expandedStates[userTestId] ?? false;
                                    final jobs = rec['jobs']
                                        as List<Map<String, dynamic>>;
                                    final userInfo = rec['user_info']
                                        as Map<String, dynamic>;

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
                                            InkWell(
                                              onTap: () =>
                                                  _toggleExpansion(userTestId),
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                top: Radius.circular(12),
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 50,
                                                      height: 50,
                                                      decoration: BoxDecoration(
                                                        color: geekGreen
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(25),
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          userInfo['name']
                                                                  ?.toString()
                                                                  .substring(
                                                                      0, 1)
                                                                  .toUpperCase() ??
                                                              'U',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color:
                                                                geekDarkGreen,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  userInfo[
                                                                          'name'] ??
                                                                      'Unknown User',
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    color:
                                                                        geekDarkGreen,
                                                                  ),
                                                                ),
                                                              ),
                                                              Container(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical:
                                                                        2),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade100,
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4),
                                                                ),
                                                                child: Text(
                                                                  '${userTestId.substring(0, 6)}...',
                                                                  style:
                                                                      const TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    fontFamily:
                                                                        'Monospace',
                                                                    color: Colors
                                                                        .grey,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                            userInfo['email'] ??
                                                                'No Email',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 6),
                                                          Wrap(
                                                            spacing: 8,
                                                            runSpacing: 4,
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
                                                                  color: geekGreen
                                                                      .withOpacity(
                                                                          0.1),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              6),
                                                                ),
                                                                child: Text(
                                                                  '@${userInfo['username'] ?? 'N/A'}',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color:
                                                                        geekGreen,
                                                                  ),
                                                                ),
                                                              ),
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .blue
                                                                      .withOpacity(
                                                                          0.1),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              6),
                                                                ),
                                                                child: Text(
                                                                  '${userInfo['uid']?.substring(0, 6)}...',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        10,
                                                                    fontFamily:
                                                                        'Monospace',
                                                                    color: Colors
                                                                        .blue
                                                                        .shade700,
                                                                  ),
                                                                ),
                                                              ),
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: Colors
                                                                      .orange
                                                                      .withOpacity(
                                                                          0.1),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              6),
                                                                ),
                                                                child: Text(
                                                                  '${jobs.length} jobs',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color: Colors
                                                                        .orange
                                                                        .shade700,
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
                                              ),
                                            ),
                                            if (isExpanded) ...[
                                              const Divider(height: 1),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if (rec['profile'] !=
                                                            null &&
                                                        rec['profile']
                                                            .toString()
                                                            .isNotEmpty)
                                                      Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              const Icon(
                                                                Icons
                                                                    .description_outlined,
                                                                size: 20,
                                                                color:
                                                                    geekGreen,
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
                                                              const Text(
                                                                'Profile Summary',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color:
                                                                      geekDarkGreen,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(12),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors
                                                                  .grey.shade50,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                            ),
                                                            child: Text(
                                                              rec['profile']
                                                                  .toString(),
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 14,
                                                                height: 1.4,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 16),
                                                        ],
                                                      ),
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
                                                          'Career Matches',
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                geekDarkGreen,
                                                          ),
                                                        ),
                                                        const Spacer(),
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
                                                              color: geekGreen,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    if (jobs.isEmpty)
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(16),
                                                        child: const Center(
                                                          child: Text(
                                                            'No job matches found',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.grey,
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                    else
                                                      Column(
                                                        children: jobs
                                                            .asMap()
                                                            .entries
                                                            .map((entry) {
                                                          final jobIndex =
                                                              entry.key;
                                                          final job =
                                                              entry.value;
                                                          final similarity =
                                                              double.tryParse(
                                                                      job['similarity_percentage']
                                                                              ?.toString() ??
                                                                          '0') ??
                                                                  0;

                                                          return Container(
                                                            margin: EdgeInsets.only(
                                                                bottom: jobIndex ==
                                                                        jobs.length -
                                                                            1
                                                                    ? 0
                                                                    : 12),
                                                            decoration:
                                                                BoxDecoration(
                                                              border: Border.all(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade300),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8),
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Container(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          12),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .grey
                                                                        .shade50,
                                                                    borderRadius:
                                                                        const BorderRadius
                                                                            .only(
                                                                      topLeft: Radius
                                                                          .circular(
                                                                              8),
                                                                      topRight:
                                                                          Radius.circular(
                                                                              8),
                                                                    ),
                                                                  ),
                                                                  child: Row(
                                                                    children: [
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
                                                                            color:
                                                                                _getSimilarityColor(similarity),
                                                                            width:
                                                                                2,
                                                                          ),
                                                                        ),
                                                                        child:
                                                                            Center(
                                                                          child:
                                                                              Text(
                                                                            '#${jobIndex + 1}',
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 14,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: _getSimilarityColor(similarity),
                                                                            ),
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
                                                                              job['job_title'] ?? 'No Title',
                                                                              style: const TextStyle(
                                                                                fontSize: 15,
                                                                                fontWeight: FontWeight.w600,
                                                                                color: Colors.black87,
                                                                              ),
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
                                                                                    minHeight: 6,
                                                                                  ),
                                                                                ),
                                                                                const SizedBox(width: 8),
                                                                                Text(
                                                                                  '${similarity.toStringAsFixed(1)}%',
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
                                                                ),
                                                                Padding(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          12),
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      if (job['job_description'] !=
                                                                              null &&
                                                                          job['job_description']
                                                                              .toString()
                                                                              .isNotEmpty)
                                                                        Column(
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children: [
                                                                            const Text(
                                                                              'Description:',
                                                                              style: TextStyle(
                                                                                fontWeight: FontWeight.w600,
                                                                                color: geekDarkGreen,
                                                                              ),
                                                                            ),
                                                                            const SizedBox(height: 4),
                                                                            Text(
                                                                              job['job_description'].toString(),
                                                                              style: const TextStyle(
                                                                                fontSize: 14,
                                                                                height: 1.4,
                                                                              ),
                                                                            ),
                                                                            const SizedBox(height: 12),
                                                                          ],
                                                                        ),
                                                                      if (job['required_skills'] !=
                                                                              null &&
                                                                          job['required_skills']
                                                                              .toString()
                                                                              .isNotEmpty)
                                                                        Column(
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children: [
                                                                            const Text(
                                                                              'Skills:',
                                                                              style: TextStyle(
                                                                                fontWeight: FontWeight.w600,
                                                                                color: geekDarkGreen,
                                                                              ),
                                                                            ),
                                                                            const SizedBox(height: 4),
                                                                            _buildSkillsSection(job['required_skills']),
                                                                            const SizedBox(height: 12),
                                                                          ],
                                                                        ),
                                                                      if (job['required_knowledge'] !=
                                                                              null &&
                                                                          job['required_knowledge']
                                                                              .toString()
                                                                              .isNotEmpty)
                                                                        Column(
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children: [
                                                                            const Text(
                                                                              'Knowledge:',
                                                                              style: TextStyle(
                                                                                fontWeight: FontWeight.w600,
                                                                                color: geekDarkGreen,
                                                                              ),
                                                                            ),
                                                                            const SizedBox(height: 4),
                                                                            _buildSkillsSection(job['required_knowledge']),
                                                                            const SizedBox(height: 12),
                                                                          ],
                                                                        ),
                                                                      if (job['charts'] !=
                                                                          null)
                                                                        _buildChartsSection(
                                                                            job['charts']),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        }).toList(),
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
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getUniqueUserCount() {
    final uniqueUids = <String>{};
    for (final rec in _recommendations) {
      final userInfo = rec['user_info'] as Map<String, dynamic>;
      final uid = userInfo['uid']?.toString();
      if (uid != null && uid != 'N/A') {
        uniqueUids.add(uid);
      }
    }
    return uniqueUids.length;
  }

  Widget _buildSkillsSection(dynamic data) {
    final items = _parseSkills(data);
    if (items.isEmpty) return const SizedBox();

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: items.map((item) {
        if (item.contains(':')) {
          final parts = item.split(':');
          final skill = parts[0].trim();
          final level = parts.length > 1 ? parts[1].trim() : '';

          return Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.5,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    skill,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (level.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    constraints: const BoxConstraints(minWidth: 60),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _getLevelColor(level),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      level,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          );
        } else {
          return Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.4,
            ),
            child: Chip(
              label: Text(
                item.trim(),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              visualDensity: VisualDensity.compact,
              backgroundColor: Colors.grey.shade100,
              labelStyle: const TextStyle(fontSize: 12),
            ),
          );
        }
      }).toList(),
    );
  }

  Widget _buildChartsSection(Map<String, dynamic> charts) {
    if (charts.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visualization:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: geekDarkGreen,
          ),
        ),
        const SizedBox(height: 8),
        ...charts.entries.map((entry) {
          final chartName = entry.key;
          final base64Data = entry.value.toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatChartName(chartName),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                _buildChartImage(base64Data),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildChartImage(String base64Data) {
    try {
      final bytes = base64.decode(base64Data);
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Image.memory(
          bytes,
          height: 150,
          width: double.infinity,
          fit: BoxFit.contain,
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(8),
        color: Colors.red.shade50,
        child: Text('Chart: ${e.toString()}',
            style: const TextStyle(fontSize: 12)),
      );
    }
  }

  List<String> _parseSkills(dynamic data) {
    if (data == null) return [];

    String text = data.toString();
    text = text.replaceAll('{', '').replaceAll('}', '');

    List<String> items = [];

    if (text.contains('\n')) {
      items = text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (text.contains(',')) {
      items = text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (text.trim().isNotEmpty) {
      items = [text.trim()];
    }

    return items
        .map((item) {
          String cleaned = item.trim();
          if (cleaned.endsWith(')') && !cleaned.startsWith('(')) {
            cleaned = cleaned.substring(0, cleaned.length - 1);
          }
          return cleaned.trim();
        })
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Color _getSimilarityColor(double percentage) {
    if (percentage >= 80) return const Color(0xFF2F8D46);
    if (percentage >= 70) return const Color(0xFF4CAF50);
    if (percentage >= 60) return const Color(0xFFF57C00);
    return const Color(0xFFD32F2F);
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      case 'expert':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  String _formatChartName(String name) {
    return name.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
