import 'package:flutter/material.dart';
import '../../models/user_responses.dart';
import '../skill_reflection_test/skill_reflection_screen.dart';

class CourseworkExperience extends StatefulWidget {
  final UserResponses userResponse;

  const CourseworkExperience({super.key, required this.userResponse});

  @override
  State<CourseworkExperience> createState() => _CourseworkExperienceState();
}

class _CourseworkExperienceState extends State<CourseworkExperience> {
  String? selectedExperience;

  final List<String> experiences = [
    "Not Familiar",
    "Somewhat Familiar",
    "Very Familiar"
  ];

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

              const Text(
                'Is your coursework familiar with any hands-on projects?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFFFFFF),
                  height: 1.3,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 12),

              // Subtitle with examples
              Text(
                'e.g., Final year project, Internship',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFFFFFFF).withOpacity(0.6),
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(height: 40),

              // Experience level options
              Expanded(
                child: ListView.builder(
                  itemCount: experiences.length,
                  itemBuilder: (context, index) {
                    final exp = experiences[index];
                    final isSelected = selectedExperience == exp;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              selectedExperience = exp; // update selection
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 24,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color.fromARGB(255, 59, 62, 59)
                                  : const Color(0xFF121212),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              exp,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFFFFFFF),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Complete button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedExperience != null) {
                      // save selected coursework experience to response object
                      widget.userResponse.courseworkExperience =
                          selectedExperience!;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SkillReflectionScreen(
                              userResponse: widget.userResponse),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFFD32F2F),
                          content: Text(
                            "Please select your coursework experience level",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    }
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
