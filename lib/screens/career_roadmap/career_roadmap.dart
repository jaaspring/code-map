import 'package:flutter/material.dart';
import '../../services/api_service.dart';

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
  Map<String, dynamic>? roadmapData;
  List<dynamic> recommendedJobs = [];
  String? currentJobIndex;
  String? currentJobTitle;
  bool isLoading = true;
  bool isLoadingJobs = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    currentJobIndex = widget.jobIndex;
    _loadData();
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
      });

      final results = await ApiService.getCareerRoadmap(
          widget.userTestId, currentJobIndex!);

      setState(() {
        roadmapData = results;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  void _setCurrentJobTitle() {
    final job = recommendedJobs.firstWhere(
      (job) => job['job_index'] == currentJobIndex,
      orElse: () => {'job_title': 'Unknown Title'},
    );
    setState(() {
      currentJobTitle = job['job_title'];
    });
  }

  void _onJobSelected(String jobIndex, String jobTitle) {
    setState(() {
      currentJobIndex = jobIndex;
      currentJobTitle = jobTitle;
    });
    _loadCareerRoadmap();
  }

  Widget _buildJobSelector() {
    if (isLoadingJobs) {
      return const CircularProgressIndicator();
    }

    if (recommendedJobs.isEmpty) {
      return const Text('No recommended jobs found');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: recommendedJobs.asMap().entries.map((entry) {
          final index = entry.key;
          final job = entry.value;
          final jobIndex = job['job_index'];
          final jobTitle = job['job_title'];
          final isSelected = currentJobIndex == jobIndex;

          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              onPressed: () => _onJobSelected(jobIndex, jobTitle),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surface,
                foregroundColor: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Career #${index + 1}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    jobTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'ID: $jobIndex',
                    style: const TextStyle(
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRoadmapContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Text(
          'Error: $errorMessage',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (roadmapData == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Nothing to see here D:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Complete your assessments to unlock your personalized career roadmap!',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (currentJobTitle != null) ...[
              Text(
                'Career Roadmap for: $currentJobTitle',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Roadmap Data:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: Text(
                roadmapData.toString(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Career Roadmap'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // job Selector Section
            Text(
              'Your Recommended Careers',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildJobSelector(),
            const SizedBox(height: 24),

            // Roadmap Content Section
            _buildRoadmapContent(),
          ],
        ),
      ),
    );
  }
}
