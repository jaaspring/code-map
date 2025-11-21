import 'package:flutter/material.dart';
import '../../models/user_responses.dart';
import '../../services/api_service.dart';
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
  bool _isSubmitting = false; // add loading state

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
    if (_isSubmitting) return; // prevent multiple submissions

    final text = _controller.text.trim(); // remove leading/trailing spaces
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Career goals cannot be empty."),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_charCount < 100) {
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
      _isSubmitting = true; // set loading state
    });

    try {
      // save career goals to user response
      widget.userResponse.careerGoals = _controller.text;

      // submit test -> backend creates userTestId
      final userTestId = await ApiService.submitTest(widget.userResponse);

      // navigate to FollowUpScreen with the userTestId
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FollowUpScreen(
            userResponse: widget.userResponse,
            userTestId: userTestId, // Pass the userTestId
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
      appBar: AppBar(title: const Text("Career Goals")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "What is your career goals?",
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText:
                      "In your own words, describe your career goals. Share the roles, industries, or specializations you aspire to. Mention long-term ambitions, short-term objectives, or the kind of impact you hope to create in your career.",
                  hintMaxLines: 10,
                ),
                minLines: 20,
                maxLines: 20,
              ),
            ),
            const SizedBox(height: 10),

            // Character counter + progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _charCount < 200
                      ? '$_charCount characters entered (${200 - _charCount} more needed)'
                      : '$_charCount characters entered (minimum met)',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _charCount < 200 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: (_charCount / 200).clamp(0, 1),
                  backgroundColor: Colors.grey[300],
                  color: _charCount < 200 ? Colors.red : Colors.green,
                  minHeight: 6,
                ),
              ],
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _onCompletePressed,
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
                  : const Text("Complete"),
            ),
          ],
        ),
      ),
    );
  }
}
