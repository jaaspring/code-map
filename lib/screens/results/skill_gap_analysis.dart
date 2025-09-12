import 'package:flutter/material.dart';
import '../../models/user_profile_match.dart';

class SkillGapAnalysis extends StatelessWidget {
  final JobMatch jobMatch;

  const SkillGapAnalysis({super.key, required this.jobMatch});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Skill Gap Analysis")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Career Path: ${jobMatch.jobTitle}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text("Description: ${jobMatch.jobDescription}"),
            const SizedBox(height: 16),
            Text("Required Skills: ${jobMatch.requiredSkills.join(', ')}"),
            const SizedBox(height: 16),
            Text(
                "Required Knowledge: ${jobMatch.requiredKnowledge.join(', ')}"),
          ],
        ),
      ),
    );
  }
}
