import 'package:code_map/services/assessment_state_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

    final loadingMessageNotifier = ValueNotifier<String>("Initializing...");

    setState(() {
      _isLoading = true;
      _showWarning = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color.fromARGB(255, 30, 30, 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color.fromARGB(30, 255, 255, 255),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4BC945)),
                ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder<String>(
                valueListenable: loadingMessageNotifier,
                builder: (context, message, child) {
                  return Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              Text(
                "Attempt ${widget.attemptNumber}",
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4BC945),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // 1. Check for existing questions
      loadingMessageNotifier.value = "Checking for existing questions...";
      await Future.delayed(const Duration(milliseconds: 800)); // smooth UX

      List<Map<String, dynamic>> questions =
          await ApiService.getGeneratedQuestions(
        userTestId: widget.userTestId,
        attemptNumber: widget.attemptNumber,
      );

      if (questions.isNotEmpty) {
        loadingMessageNotifier.value = "Retrieving existing questions...";
        print("Found ${questions.length} existing questions.");
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        // 2. Generate new if none exist
        loadingMessageNotifier.value =
            "Generating new questions for attempt ${widget.attemptNumber}...";
        print("No existing questions. Generating new...");
        
        questions = await ApiService.generateQuestions(
          userTestId: widget.userTestId,
          attemptNumber: widget.attemptNumber,
        );
      }

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
          backgroundColor: const Color.fromARGB(255, 30, 30, 30),
          content: Text(
            "Error: ${e.toString()}",
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      setState(() => _showWarning = true);
    } finally {
      loadingMessageNotifier.dispose();
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header with back button and logo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Color.fromARGB(255, 255, 255, 255)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                  Image.asset(
                    'assets/icons/logo_only_white.png',
                    height: 18,
                    fit: BoxFit.contain,
                  ),
                  IconButton(
                    icon: const Icon(Icons.exit_to_app_rounded,
                        color: Color.fromARGB(255, 255, 255, 255)),
                    onPressed: () {
                      final user = FirebaseAuth.instance.currentUser;
                        AssessmentStateService.abandonAssessment(
                          context: context,
                          uid: user?.uid,
                          userTestId: widget.userTestId,
                          draftData: widget.userResponse,
                          currentStep: 'FollowUpScreen',
                        );
                    },
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),

              // Main content
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Follow-up Test\nValidate Your Skills',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: const Color.fromARGB(255, 255, 255, 255),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Subtitle
                    Text(
                      '3 out of 3 assessments to help\npersonalize your journey.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: const Color.fromARGB(136, 255, 255, 255),
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Attempt info badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 20),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(30, 75, 201, 69),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF4BC945),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Assessment Attempt ${widget.attemptNumber}',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF4BC945),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Warning message
                    if (_showWarning)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Text(
                          "Please check your connection and try again\nAttempt ${widget.attemptNumber}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFA500),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Start button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _startFollowUp(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLoading
                        ? const Color.fromARGB(255, 40, 40, 40)
                        : const Color(0xFF4BC945),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Starting...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Start Test',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
