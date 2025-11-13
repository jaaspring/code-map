import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
                    : "Initializing assessment system",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              if (!_isBackendReady) const SizedBox(height: 10),
              if (!_isBackendReady)
                const Text(
                  "Subsequent loads will be faster!",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );

    try {
      // generate follow-up questions
      final questions = await ApiService.generateQuestions(
        skillReflection: widget.userResponse.skillReflection,
        thesisFindings: widget.userResponse.thesisFindings,
        careerGoals: widget.userResponse.careerGoals,
        userTestId: widget.userTestId, // use the passed userTestId
      );

      print("Questions received: $questions");

      if (questions.isNotEmpty) {
        setState(() => _isBackendReady = true);

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
