import 'package:code_map/screens/skill_reflection_test/career_goals.dart';
import 'package:code_map/screens/skill_reflection_test/thesis_findings.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:code_map/services/assessment_state_service.dart';
import '../../models/user_responses.dart';

class SkillReflectionTest extends StatefulWidget {
  final UserResponses userResponse;

  const SkillReflectionTest({super.key, required this.userResponse});

  @override
  State<SkillReflectionTest> createState() => _SkillReflectionTestState();
}

class _SkillReflectionTestState extends State<SkillReflectionTest> {
  late TextEditingController _controller;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: widget.userResponse.skillReflection);
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

  void _onCompletePressed() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Skill reflection cannot be empty."),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_charCount < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Please write at least 500 characters. Current count: $_charCount'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    widget.userResponse.skillReflection = _controller.text;

    if (widget.userResponse.educationLevel == "Doctorate (PhD)") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ThesisFindings(userResponse: widget.userResponse),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CareerGoals(userResponse: widget.userResponse),
        ),
      );
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
              // header with back button and logo
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
                    'assets/logo_white.png',
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
                        userTestId: widget.userResponse.userTestId,
                        draftData: widget.userResponse,
                        currentStep: 'SkillReflectionTest',
                      );
                    },
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Question text
              const Text(
                "What IT skills and strengths are you most proud of, and why?",
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
                          "In your own words, describe the skills you are most confident in. Mention any tools, programming languages you haven't mentioned previously, or technical concepts you are familiar with. You may also include soft skills, previous projects, or anything you believe showcases your strengths.",
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

              // Character count
              Text(
                'Character count: $_charCount/500',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  color: _charCount < 500
                      ? const Color.fromARGB(136, 255, 255, 255)
                      : const Color(0xFF4BC945),
                ),
              ),
              const SizedBox(height: 24),

              // Next button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onCompletePressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4BC945),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Next',
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
