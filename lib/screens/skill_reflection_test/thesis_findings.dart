import 'package:flutter/material.dart';
import '../../models/user_responses.dart';
import '../skill_reflection_test/career_goals.dart';

class ThesisFindings extends StatefulWidget {
  final UserResponses userResponse;

  const ThesisFindings({super.key, required this.userResponse});

  @override
  State<ThesisFindings> createState() => _ThesisFindingsState();
}

class _ThesisFindingsState extends State<ThesisFindings> {
  late TextEditingController _controller;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();

    // Skip this screen if not PhD
    if (widget.userResponse.educationLevel != "Doctorate (PhD)") {
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CareerGoals(userResponse: widget.userResponse),
          ),
        );
      });
    }

    _controller =
        TextEditingController(text: widget.userResponse.thesisFindings);
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
          content: Text("Thesis findings cannot be empty."),
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
    widget.userResponse.thesisFindings = _controller.text;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CareerGoals(userResponse: widget.userResponse),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Thesis Findings")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Describe the key findings from your thesis research.",
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "In your own words, describe your thesis findings.",
                  hintMaxLines: 10,
                ),
                minLines: 20,
                maxLines: 20,
              ),
            ),
            const SizedBox(height: 10),

            // character counter + progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _charCount < 500
                      ? '$_charCount characters entered (${500 - _charCount} more needed)'
                      : '$_charCount characters entered (minimum met)',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _charCount < 500 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(
                  value: (_charCount / 500).clamp(0, 1),
                  backgroundColor: Colors.grey[300],
                  color: _charCount < 500 ? Colors.red : Colors.green,
                  minHeight: 6,
                ),
              ],
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _onCompletePressed,
              child: const Text("Next"),
            ),
          ],
        ),
      ),
    );
  }
}
