import 'package:code_map/screens/results/career_recommendations.dart';
import 'package:flutter/material.dart';
import 'package:code_map/models/follow_up_responses.dart';
import '../../models/user_responses.dart';
import '../../services/api_service.dart';

class FollowUpTest extends StatefulWidget {
  final String userTestId; // passed from FollowUpScreen
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
      // update only if _selectedOption is not null
      if (_selectedOption != null) {
        followUpResponses.responses[existingIndex].selectedOption =
            _selectedOption;
      }
    } else {
      followUpResponses.responses.add(FollowUpResponse(
        questionId: questionId,
        selectedOption: _selectedOption, // can be null safely
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
          const SnackBar(content: Text("Please select an option.")));
      return;
    }

    _saveCurrentAnswer();

    if (_currentIndex < widget.questions.length - 1) {
      _goToQuestion(_currentIndex + 1);
    } else {
      // last question -> submit all answers
      await _submitAllAnswers();
    }
  }

  // separate method to submit all answers
  Future<void> _submitAllAnswers() async {
    setState(() {
      _isSubmitting = true; // start loading
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
          const SnackBar(
            content: Text("Failed to submit answers. Please try again."),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false; // stop loading regardless of success/failure
        });
      }
    }
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case "easy":
        return Colors.green;
      case "medium":
        return Colors.orange;
      case "hard":
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildQuestionContent(String questionText) {
    final currentQuestion = widget.questions[_currentIndex];
    final String? code = currentQuestion['code'];
    final String? language = currentQuestion['language'];

    // if it's a coding question with separate code field
    if (code != null && code.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // question text
          Text(
            questionText,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),

          // language badge
          if (language != null && language.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                language.toUpperCase(),
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // code block
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 13,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      );
    }

    //fallback to old markdown parsing for backward compatibility
    final codeRegex = RegExp(r'```(.*?)```', dotAll: true);
    final matches = codeRegex.allMatches(questionText);

    if (matches.isEmpty) {
      return Text(
        questionText,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      );
    }

    List<Widget> parts = [];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        parts.add(Text(
          questionText.substring(lastIndex, match.start).trim(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ));
      }

      String codeContent = match.group(1)!.trim();
      parts.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              codeContent,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < questionText.length) {
      parts.add(Text(
        questionText.substring(lastIndex).trim(),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No questions available.")),
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

    return WillPopScope(
      onWillPop: () async {
        // prevent going back while submitting
        if (_isSubmitting) {
          return false;
        }

        if (_currentIndex > 0) {
          _goToQuestion(_currentIndex - 1);
          return false;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You cannot go back from the first question."),
            ),
          );
          return false;
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              "Question ${_currentIndex + 1} of ${widget.questions.length}"),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              _getDifficultyColor(difficulty).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          difficulty,
                          style: TextStyle(
                            color: _getDifficultyColor(difficulty),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Category: $category",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildQuestionContent(questionText),
                      const SizedBox(height: 20),
                      Column(
                        children: options.map((option) {
                          return RadioListTile<String>(
                            title: Text(option),
                            value: option,
                            groupValue: _selectedOption,
                            onChanged: _isSubmitting
                                ? null
                                : (value) {
                                    // disable while submitting
                                    setState(() {
                                      _selectedOption = value;
                                    });
                                  },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _currentIndex == widget.questions.length - 1
                              ? "Complete"
                              : "Next Question",
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
