import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_responses.dart';
import 'package:code_map/services/assessment_state_service.dart';
import 'programming_languages.dart';

class EducationMajor extends StatefulWidget {
  final UserResponses userResponse;

  const EducationMajor({super.key, required this.userResponse});

  @override
  State<EducationMajor> createState() => _EducationMajorState();
}

class _EducationMajorState extends State<EducationMajor> {
  String? selectedMajor;

  final List<String> majors = [
    "Software Engineering",
    "Computer Science",
    "Data Science",
    "Cybersecurity",
    "Artificial Intelligence (AI)",
    "Web Development",
    "Mobile Computing",
    "Cloud Computing",
    "Network Engineering",
    "None"
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
                        currentStep: 'EducationMajor',
                      );
                    },
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              const Text(
                'What was your major or area of focus during your studies?',
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

              // Major options
              Expanded(
                child: ListView.builder(
                  itemCount: majors.length,
                  itemBuilder: (context, index) {
                    final major = majors[index];
                    final isSelected = selectedMajor == major;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              selectedMajor = major; // update selection
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
                              major,
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

              // Next button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedMajor != null) {
                      // save selected education major to response object
                      widget.userResponse.major = selectedMajor!;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProgrammingLanguages(
                              userResponse: widget.userResponse),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFFD32F2F),
                          content: Text(
                            "Please select your major or area of focus",
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
