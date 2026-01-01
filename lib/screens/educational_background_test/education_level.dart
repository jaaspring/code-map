import 'package:code_map/screens/educational_background_test/thesis_topic.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:code_map/services/assessment_state_service.dart';
import '../../models/user_responses.dart';
import 'cgpa.dart';

class EducationLevel extends StatefulWidget {
  final UserResponses userResponse;

  const EducationLevel({super.key, required this.userResponse});

  @override
  State<EducationLevel> createState() => _EducationLevelState();
}

class _EducationLevelState extends State<EducationLevel> {
  String? selectedLevel; // currently selected education level

  final List<String> levels = [
    "SPM (Sijil Pelajaran Malaysia)",
    "STPM (Sijil Tinggi Persekolahan Malaysia)",
    "Diploma",
    "Undergraduate (Bachelor's Degree)",
    "Postgraduate (Master's Degree)",
    "Doctorate (PhD)",
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
              // header with back button and logo
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
                  IconButton(
                    icon: const Icon(Icons.exit_to_app_rounded,
                        color: Color(0xFFFFFFFF)),
                    onPressed: () {
                      final user = FirebaseAuth.instance.currentUser;
                      AssessmentStateService.abandonAssessment(
                        context: context,
                        uid: user?.uid,
                        userTestId: widget.userResponse.userTestId,
                        draftData: widget.userResponse,
                        currentStep: 'EducationLevel',
                      );
                    },
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              const Text(
                'What was your highest level of education?',
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

              Expanded(
                child: ListView.builder(
                  itemCount: levels.length,
                  itemBuilder: (context, index) {
                    final level = levels[index];
                    final isSelected = selectedLevel == level;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              selectedLevel = level; // update selection
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
                              level,
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

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedLevel != null) {
                      // save selected education level to response object
                      widget.userResponse.educationLevel = selectedLevel!;

                      // route to different screens based on selection
                      // if Doctorate, go to ThesisTopicScreen
                      if (selectedLevel == "Doctorate (PhD)") {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ThesisTopic(userResponse: widget.userResponse),
                          ),
                        );
                      } else {
                        // else, go to CgpaScreen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                Cgpa(userResponse: widget.userResponse),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFFD32F2F),
                          content: Text(
                            "What was your highest level of education?",
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
