import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_responses.dart';
import 'package:code_map/services/assessment_state_service.dart';
import 'coursework_experience.dart';

class ProgrammingLanguages extends StatefulWidget {
  final UserResponses userResponse;

  const ProgrammingLanguages({super.key, required this.userResponse});

  @override
  State<ProgrammingLanguages> createState() => _ProgrammingLanguagesState();
}

class _ProgrammingLanguagesState extends State<ProgrammingLanguages> {
  final List<String> languages = [
    "Python",
    "Java",
    "JavaScript",
    "TypeScript",
    "C",
    "C++",
    "C#",
    "PHP",
    "Ruby",
    "Go (Golang)",
    "Rust",
    "Swift",
    "Kotlin",
    "Scala",
    "R",
    "SQL",
    "Pascal",
    "Perl",
    "Dart",
    "Lua",
    "Objective-C",
    "Visual Basic",
    "None"
  ];

  // tracks user's selected languages
  final List<String> selectedLanguages = [];

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
                    'assets/icons/logo_white.png',
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
                        currentStep: 'ProgrammingLanguages',
                      );
                    },
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              const Text(
                'What programming languages have you learned?',
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

              // Subtitle for multi-select hint
              Text(
                'Select all that apply',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFFFFFFF).withOpacity(0.6),
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(height: 40),

              // Programming language options
              Expanded(
                child: ListView.builder(
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    final isSelected = selectedLanguages.contains(lang);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              // toggle selection: add if not selected, remove if already selected
                              isSelected
                                  ? selectedLanguages.remove(lang)
                                  : selectedLanguages.add(lang);
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  lang,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFFFFFFFF),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Next button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedLanguages.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFFD32F2F),
                          content: Text(
                            "Please select at least one programming language",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                      return;
                    }

                    // save selected languages to user response object
                    widget.userResponse.programmingLanguages =
                        List.from(selectedLanguages);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CourseworkExperience(
                            userResponse: widget.userResponse),
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
