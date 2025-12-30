import 'package:flutter/material.dart';
import '../../models/user_responses.dart';
import 'education_major.dart';

class ThesisTopic extends StatefulWidget {
  final UserResponses userResponse;

  const ThesisTopic({super.key, required this.userResponse});

  @override
  State<ThesisTopic> createState() => _ThesisTopicState();
}

class _ThesisTopicState extends State<ThesisTopic> {
  final TextEditingController thesisTopicController = TextEditingController();

  @override
  void dispose() {
    thesisTopicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
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
                    icon:
                        const Icon(Icons.arrow_back, color: Color(0xFFFFFFFF)),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                  Image.asset(
                    'assets/logo_white.png',
                    height: 18,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 48), // Balance for symmetric layout
                ],
              ),

              const SizedBox(height: 40),

              // Title
              const Text(
                'What is your thesis topic?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFFFFFF),
                  height: 1.3,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 40),

              // Thesis Topic Input Field
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: thesisTopicController,
                  keyboardType: TextInputType.text,
                  maxLines: 3,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFFFFFF),
                    letterSpacing: 0.2,
                  ),
                  decoration: const InputDecoration(
                    hintText: "Enter your thesis topic",
                    hintStyle: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),

              const Spacer(),

              // Next button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    String thesisTopic = thesisTopicController.text.trim();
                    if (thesisTopic.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFFD32F2F),
                          content: Text(
                            "Please enter your thesis topic",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                      return;
                    }

                    // save thesis topic to response object
                    widget.userResponse.thesisTopic = thesisTopic;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EducationMajor(userResponse: widget.userResponse),
                      ),
                    );
                  },
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
                    'Continue',
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
