import 'package:flutter/material.dart';
import '../../../../models/user_responses.dart';
import '../../../../services/api_service.dart';
import 'follow_up_test.dart';

class FollowUpScreen extends StatefulWidget {
  final UserResponses userResponse;
  final String userTestId;

  const FollowUpScreen(
      {super.key, required this.userResponse, required this.userTestId});

  @override
  State<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends State<FollowUpScreen> {
  bool _isBackendReady = false;
  bool _isLoading = false;
  bool _showWarning = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startFollowUp(BuildContext context) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _showWarning = false;
    });

    // show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _isBackendReady
                    ? "Generating your questions..."
                    : "Checking for existing questions...",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (!_isBackendReady) const SizedBox(height: 10),
              if (!_isBackendReady)
                const Text(
                  "This will take a few minutes!",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );

    try {
      // check for existing generated questions first
      List<Map<String, dynamic>> questions;

      try {
        questions = await ApiService.getGeneratedQuestions(
          userTestId: widget.userTestId,
        );

        if (questions.isNotEmpty) {
          print(
              "Found ${questions.length} existing questions for user ${widget.userTestId}");
          // use existing questions - no need to generate new ones
          setState(() => _isBackendReady = true);

          if (Navigator.canPop(context)) Navigator.pop(context);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => FollowUpTest(
                userTestId: widget.userTestId,
                userResponse: widget.userResponse,
                questions: questions,
              ),
            ),
          );
          return; // exit early since we have existing questions
        }
      } catch (e) {
        print("No existing questions found or error retrieving: $e");
        // continue to generate new questions
      }

      // if no existing questions found, generate new ones
      print("No existing questions found, generating new ones...");
      questions = await ApiService.generateQuestions(
        skillReflection: widget.userResponse.skillReflection,
        thesisFindings: widget.userResponse.thesisFindings,
        careerGoals: widget.userResponse.careerGoals,
        userTestId: widget.userTestId,
      );

      print("New questions generated: ${questions.length}");

      if (questions.isNotEmpty) {
        setState(() => _isBackendReady = true);

        if (Navigator.canPop(context)) Navigator.pop(context);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FollowUpTest(
              userTestId: widget.userTestId,
              userResponse: widget.userResponse,
              questions: questions,
            ),
          ),
        );
      } else {
        throw Exception("No questions were generated");
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          duration: const Duration(seconds: 4),
        ),
      );

      setState(() => _showWarning = true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Expanded(
            child: Center(
              child: Text(
                'Follow-up Test: Validate Your Skills',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (_showWarning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Text(
                "Please check your connection and try again",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orange, fontSize: 14),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _startFollowUp(context),
                      child: const Text('Start'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
