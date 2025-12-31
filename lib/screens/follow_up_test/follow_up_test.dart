import 'package:code_map/screens/results/career_recommendations.dart';
import 'package:flutter/material.dart';
import 'package:code_map/models/follow_up_responses.dart';
import '../../models/user_responses.dart';
import '../../services/api_service.dart';

class FollowUpTest extends StatefulWidget {
  final String userTestId;
  final UserResponses userResponse;
  final List<dynamic> questions;
  final int attemptNumber;

  const FollowUpTest({
    super.key,
    required this.userTestId,
    required this.userResponse,
    required this.questions,
    required this.attemptNumber,
  });

  @override
  State<FollowUpTest> createState() => _FollowUpTestState();
}

class _FollowUpTestState extends State<FollowUpTest> {
  int _currentIndex = 0;
  String? _selectedOption;
  final FollowUpResponses followUpResponses = FollowUpResponses(responses: []);
  bool _isSubmitting = false;

  // save or update the current question's answer
  void _saveCurrentAnswer() {
    final questionId = widget.questions[_currentIndex]['id'];
    if (questionId == null) return;

    final existingIndex = followUpResponses.responses
        .indexWhere((r) => r.questionId == questionId);

    if (existingIndex >= 0) {
      if (_selectedOption != null) {
        followUpResponses.responses[existingIndex].selectedOption =
            _selectedOption;
      }
    } else {
      followUpResponses.responses.add(FollowUpResponse(
        questionId: questionId,
        selectedOption: _selectedOption,
        userTestId: widget.userTestId,
        attemptNumber: widget.attemptNumber,
      ));
    }
  }

  // navigate to a specific question index
  void _goToQuestion(int index) {
    _saveCurrentAnswer();
    setState(() {
      _currentIndex = index;
      final existing = followUpResponses.responses.indexWhere(
          (r) => r.questionId == widget.questions[_currentIndex]['id']);
      _selectedOption = existing >= 0
          ? followUpResponses.responses[existing].selectedOption
          : null;
    });
  }

  // handle Next button
  Future<void> _nextQuestion() async {
    if (_selectedOption == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E1E1E),
          content: const Text(
            "Please select an option.",
            style: TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    _saveCurrentAnswer();

    if (_currentIndex < widget.questions.length - 1) {
      _goToQuestion(_currentIndex + 1);
    } else {
      await _submitAllAnswers();
    }
  }

  // separate method to submit all answers
  Future<void> _submitAllAnswers() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await ApiService.submitFollowUpResponses(responses: followUpResponses);
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => CareerRecommendationsScreen(
            userTestId: widget.userTestId,
            attemptNumber: widget.attemptNumber,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      print("Error submitting: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E1E1E),
            content: const Text(
              "Failed to submit answers. Please try again.",
              style: TextStyle(color: Colors.white),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case "easy":
        return const Color(0xFF4BC945);
      case "medium":
        return const Color(0xFFFFA500);
      case "hard":
        return const Color(0xFFFF4444);
      default:
        return const Color.fromARGB(136, 255, 255, 255);
    }
  }

  Widget _buildQuestionContent(String questionText) {
    final currentQuestion = widget.questions[_currentIndex];
    final String? code = currentQuestion['code'];
    final String? language = currentQuestion['language'];

    // if it's a coding question with separate code field
    if (code != null && code.isNotEmpty) {
      final lines = code.split('\n');
      final lineCount = lines.length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // question text
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Text(
              questionText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ),

          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E), // Dark gray background
              borderRadius:
                  BorderRadius.circular(0), // Square corners like image
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Tab bar background
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF252526), // Dark tab bar background
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Active Tab
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E1E1E), // Matches code background
                            border: Border(
                              top: BorderSide(
                                color: Color(0xFF4BC945), // Accent color top border
                                width: 2,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Optional: File icon
                              const Icon(
                                Icons.code,
                                size: 16,
                                color: Color(0xFF4BC945),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                language ?? 'Code',
                                style: const TextStyle(
                                  fontFamily: 'GoogleSansCode',
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Close icon for tab look
                              const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white54,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                Container(
                  padding: const EdgeInsets.only(top: 0, bottom: 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Line numbers column - Light gray background
                      Container(
                        width: 50,
                        padding:
                            const EdgeInsets.only(top: 8, bottom: 8, right: 12),
                        decoration: const BoxDecoration(
                          color: Color(
                              0xFF2D2D2D), // Light gray background for line numbers
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(
                            lineCount,
                            (index) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 3.5),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontFamily: 'GoogleSansCode',
                                  fontSize: 14,
                                  color:
                                      Color(0xFF858585), // Medium gray numbers
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Code content
                      Expanded(
                        child: Container(
                          color: const Color(
                              0xFF1E1E1E), // Dark background for code
                          child: SingleChildScrollView(
                            child: Container(
                              padding: const EdgeInsets.only(
                                  top: 8, bottom: 8, left: 16, right: 16),
                              child: SelectableText(
                                code,
                                style: const TextStyle(
                                  fontFamily: 'GoogleSansCode',
                                  fontSize: 14,
                                  color:
                                      Color(0xFFD4D4D4), // Light gray code text
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // fallback to old markdown parsing
    final codeRegex = RegExp(r'```(.*?)```', dotAll: true);
    final matches = codeRegex.allMatches(questionText);

    if (matches.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: Text(
          questionText,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 1.5,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildQuestionParts(questionText, matches),
    );
  }

  List<Widget> _buildQuestionParts(
      String questionText, Iterable<Match> matches) {
    List<Widget> parts = [];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        parts.add(
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Text(
              questionText.substring(lastIndex, match.start).trim(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        );
      }

      String codeContent = match.group(1)!.trim();
      final lines = codeContent.split('\n');
      final lineCount = lines.length;

      parts.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tab bar background
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF252526), // Dark tab bar background
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Active Tab
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E1E1E), // Matches code background
                        border: Border(
                          top: BorderSide(
                            color: Color(0xFF4BC945), // Accent color top border
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.code,
                            size: 16,
                            color: Color(0xFF4BC945),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Code',
                            style: TextStyle(
                              fontFamily: 'GoogleSansCode',
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white54,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.only(top: 0, bottom: 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      padding:
                          const EdgeInsets.only(top: 8, bottom: 8, right: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2D2D2D),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(
                          lineCount,
                          (index) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.5),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontFamily: 'GoogleSansCode',
                                fontSize: 14,
                                color: Color(0xFF858585),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: const Color(0xFF1E1E1E),
                        child: SingleChildScrollView(
                          child: Container(
                            padding: const EdgeInsets.only(
                                top: 8, bottom: 8, left: 16, right: 16),
                            child: SelectableText(
                              codeContent,
                              style: const TextStyle(
                                fontFamily: 'GoogleSansCode',
                                fontSize: 14,
                                color: Color(0xFFD4D4D4),
                                height: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < questionText.length) {
      parts.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Text(
            questionText.substring(lastIndex).trim(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return parts;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const Scaffold(
        backgroundColor: Color.fromARGB(255, 0, 0, 0),
        body: Center(
          child: Text(
            "No questions available.",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final currentQuestion = widget.questions[_currentIndex];
    final questionText = currentQuestion['question'] ?? '';
    final options = currentQuestion['options'] is List
        ? List<String>.from(currentQuestion['options'])
        : currentQuestion['options'] is String
            ? (currentQuestion['options'] as String)
                .split(',')
                .map((e) => e.trim())
                .toList()
            : ["Option A", "Option B", "Option C", "Option D"];

    final difficulty = currentQuestion['difficulty'] ?? '';
    final category = currentQuestion['category'] ?? '';
    final language = currentQuestion['language'] ?? '';

    return WillPopScope(
      onWillPop: () async {
        if (_isSubmitting) {
          return false;
        }

        if (_currentIndex > 0) {
          _goToQuestion(_currentIndex - 1);
          return false;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF1E1E1E),
              content: const Text(
                "You cannot go back from the first question.",
                style: TextStyle(color: Colors.white),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return false;
        }
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Header with back button and centered logo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Color.fromARGB(255, 255, 255, 255)),
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              if (_currentIndex > 0) {
                                _goToQuestion(_currentIndex - 1);
                              } else {
                                Navigator.pop(context);
                              }
                            },
                      padding: EdgeInsets.zero,
                    ),
                    Expanded(
                      child: Center(
                        child: Image.asset(
                          'assets/logo_white.png',
                          height: 20,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          "${_currentIndex + 1}/${widget.questions.length}",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color.fromARGB(136, 255, 255, 255),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Badges
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                      if (difficulty.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(difficulty),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            difficulty,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (language != null && language.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            language,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 16),

                // Main content area
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Question content
                        _buildQuestionContent(questionText),
                        const SizedBox(height: 16),

                        // Options section
                        Column(
                          children: options.asMap().entries.map((entry) {
                            final index = entry.key;
                            final option = entry.value;
                            final isSelected = _selectedOption == option;
                            final optionLetter =
                                String.fromCharCode(65 + index);

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _isSubmitting
                                  ? null
                                  : () {
                                      setState(() {
                                        _selectedOption = option;
                                      });
                                    },
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color.fromARGB(30, 75, 201, 69)
                                      : const Color.fromARGB(255, 18, 18, 18),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF4BC945)
                                        : const Color.fromARGB(
                                            30, 255, 255, 255),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? const Color(0xFF4BC945)
                                            : const Color.fromARGB(
                                                255, 40, 40, 40),
                                      ),
                                      child: Center(
                                        child: Text(
                                          optionLetter,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color.fromARGB(
                                                    180, 255, 255, 255),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        option,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Fixed button at bottom
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _nextQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSubmitting
                          ? const Color.fromARGB(255, 40, 40, 40)
                          : const Color(0xFF4BC945),
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
                        : Text(
                            _currentIndex == widget.questions.length - 1
                                ? "Complete Assessment"
                                : "Next Question",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
