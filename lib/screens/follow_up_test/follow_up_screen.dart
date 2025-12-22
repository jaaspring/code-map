import 'package:flutter/material.dart';
import '../../../../models/user_responses.dart';
import '../../../../services/api_service.dart';
import 'follow_up_test.dart';

class FollowUpScreen extends StatefulWidget {
  final UserResponses userResponse;
  final String userTestId;
  final int attemptNumber;

  const FollowUpScreen({
    super.key,
    required this.userResponse,
    required this.userTestId,
    required this.attemptNumber,
  });

  @override
  State<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends State<FollowUpScreen> {
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

    String loadingMessage =
        "Generating questions for attempt ${widget.attemptNumber}...";

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
                loadingMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                "Attempt ${widget.attemptNumber}",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      loadingMessage =
          "Generating new questions for attempt ${widget.attemptNumber}...";
      print("Generating new questions for attempt ${widget.attemptNumber}...");

      List<Map<String, dynamic>> questions = await ApiService.generateQuestions(
        skillReflection: widget.userResponse.skillReflection,
        thesisFindings: widget.userResponse.thesisFindings,
        careerGoals: widget.userResponse.careerGoals,
        userTestId: widget.userTestId,
        attemptNumber: widget.attemptNumber,
      );

      print(
          "Generated ${questions.length} new questions for attempt ${widget.attemptNumber}");

      if (questions.isNotEmpty) {
        if (Navigator.canPop(context)) Navigator.pop(context);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FollowUpTest(
              userTestId: widget.userTestId,
              userResponse: widget.userResponse,
              questions: questions,
              attemptNumber: widget.attemptNumber,
            ),
          ),
        );
      } else {
        throw Exception(
            "No questions were generated for attempt ${widget.attemptNumber}");
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Error for attempt ${widget.attemptNumber}: ${e.toString()}"),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Follow-up Test: Validate Your Skills',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Coding & Technical Assessment',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          // show attempt info
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Text(
              'Assessment Attempt ${widget.attemptNumber}',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (_showWarning)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Text(
                "Please check your connection and try again\nAttempt ${widget.attemptNumber}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.orange, fontSize: 14),
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
                      child: const Text('Start Attempt'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
