import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_responses.dart';
import '../../services/api_service.dart';
import '../../services/assessment_state_service.dart';
import '../follow_up_test/follow_up_screen.dart';

class CareerGoals extends StatefulWidget {
  final UserResponses userResponse;

  const CareerGoals({super.key, required this.userResponse});

  @override
  State<CareerGoals> createState() => _CareerGoalsState();
}

class _CareerGoalsState extends State<CareerGoals> {
  late TextEditingController _controller;
  int _charCount = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.userResponse.careerGoals);
    _charCount = _controller.text.length;

    _controller.addListener(() {
      setState(() {
        _charCount = _controller.text.length;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onCompletePressed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    // check existing attempts
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    int attemptNumber = 1;
    List<dynamic> attempts = [];
    if (userDoc.exists) {
      attempts = List.from(userDoc.data()?['assessmentAttempts'] as List? ?? []);
      attemptNumber = attempts.length + 1;
    }

    if (_isSubmitting) return;

    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Career goals cannot be empty."),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_charCount < 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please write at least 200 characters. Current count: $_charCount'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      widget.userResponse.careerGoals = _controller.text;
      
      final existingId = widget.userResponse.userTestId;
      
      String userTestId = await ApiService.submitTest(widget.userResponse);
      
      if (userTestId == "null" || userTestId == "N/A" || userTestId.isEmpty) {
        if (widget.userResponse.userTestId != null && widget.userResponse.userTestId!.isNotEmpty) {
          userTestId = widget.userResponse.userTestId!;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error: Could not generate test ID. (Response: $userTestId)"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
          setState(() => _isSubmitting = false);
          return;
        }
      }

      // update the model immediately
      widget.userResponse.userTestId = userTestId;

      int existingIndex = -1;
      
      if (existingId != null) {
        for (int i = 0; i < attempts.length; i++) {
          if (attempts[i]['testId'] == existingId) {
            existingIndex = i;
            break;
          }
        }
      }

      if (existingIndex != -1) {
        final attempt = Map<String, dynamic>.from(attempts[existingIndex]);
        attempt['status'] = 'In progress';
        attempt['completedAt'] = DateTime.now().toIso8601String();
        // Don't overwrite attemptNumber if it exists
        
        attempts[existingIndex] = attempt;
        
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'assessmentAttempts': attempts,
          'userTestId': userTestId,
        });
      } else {
        // CREATE new attempt
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'userTestId': userTestId,
          'assessmentAttempts': FieldValue.arrayUnion([
            {
              'attemptNumber': attemptNumber,
              'testId': userTestId,
              'completedAt': DateTime.now().toIso8601String(),
              'status': 'In progress'
            }
          ]),
          'testIds': FieldValue.arrayUnion([userTestId])
        });
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FollowUpScreen(
            userResponse: widget.userResponse,
            userTestId: userTestId,
            attemptNumber: attemptNumber,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error submitting test: ${e.toString()}"),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      widget.userResponse.careerGoals = _controller.text; // Update model with text
                      AssessmentStateService.abandonAssessment(
                        context: context,
                        uid: user?.uid,
                        userTestId: widget.userResponse.userTestId,
                        draftData: widget.userResponse,
                        currentStep: 'CareerGoals',
                      );
                    },
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Question text
              const Text(
                "What is your career goals?",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color.fromARGB(255, 255, 255, 255),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Text field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 18, 18, 18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color.fromARGB(30, 255, 255, 255),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 255, 255, 255),
                      fontSize: 15,
                      height: 1.5,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                      hintText:
                          "In your own words, describe your career goals. Share the roles, industries, or specializations you aspire to. Mention long-term ambitions, short-term objectives, interest, or the kind of impact you hope to create in your career.",
                      hintStyle: TextStyle(
                        color: Color.fromARGB(100, 255, 255, 255),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                'Character count: $_charCount/200',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  color: _charCount < 200
                      ? const Color.fromARGB(136, 255, 255, 255)
                      : const Color(0xFF4BC945),
                ),
              ),
              const SizedBox(height: 24),

              // Next button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _onCompletePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4BC945),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Complete',
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
