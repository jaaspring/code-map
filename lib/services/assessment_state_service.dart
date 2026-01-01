import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../screens/user/home_screen.dart';


import 'package:code_map/models/user_responses.dart';


class AssessmentStateService {
  /// Abandons the current assessment for the given [uid] and [userTestId].
  /// Shows a confirmation dialog before proceeding.
  static Future<void> abandonAssessment({
    required BuildContext context,
    String? uid,
    String? userTestId,
    UserResponses? draftData,
    String? currentStep,
  }) async {
    final shouldAbandon = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.5),
        elevation: 8,
        title: Container(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4B4B).withOpacity(0.1), // Red accent
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.exit_to_app_rounded,
                  color: Color(0xFFFF4B4B),
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Abandon Assessment?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Are you sure you want to abandon the assessment? You can resume it later from the home screen.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Colors.blue[400],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Don\'t worry, your progress will be saved! :D',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[400],
                      side: BorderSide(color: Colors.grey[600]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4B4B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Abandon',
                      style: TextStyle(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (shouldAbandon == true) {
      String? targetTestId = userTestId;
      
      if (uid != null) {
        if (targetTestId != null) {
          await _updateStatusToAbandoned(uid, targetTestId);
        } else {
          // Early abandonment: create a new record and get its ID
          targetTestId = await _createAbandonedRecord(uid);
        }
        
        // Save draft if we have data and an ID
        if (targetTestId != null && draftData != null && currentStep != null) {
          // CRITICAL: Ensure the draft data has the correct ID so it resumes correctly
          draftData.userTestId = targetTestId;
          await _saveDraft(targetTestId, draftData, currentStep);
        }
      }
      
      if (context.mounted) {
         _navigateToHome(context);
      }
    }
  }

  static Future<void> _saveDraft(String userTestId, UserResponses data, String step) async {
    try {
      await FirebaseFirestore.instance
          .collection('assessment_drafts')
          .doc(userTestId)
          .set({
        'currentStep': step,
        'responses': data.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Draft saved for $userTestId at step $step');
    } catch (e) {
      print('Error saving draft: $e');
    }
  }

  static Future<Map<String, dynamic>?> fetchDraft(String userTestId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('assessment_drafts')
          .doc(userTestId)
          .get();
      return doc.data();
    } catch (e) {
      print('Error fetching draft: $e');
      return null;
    }
  }

  static Future<void> _updateStatusToAbandoned(String uid, String userTestId) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userDoc = await userRef.get();

      if (!userDoc.exists) return;

      final attempts =
          userDoc.data()?['assessmentAttempts'] as List<dynamic>? ?? [];

      bool updated = false;
      // find and update the specific attempt
      for (int i = 0; i < attempts.length; i++) {
        if (attempts[i]['testId'] == userTestId) {
          // update this attempt
          final updatedAttempt = Map<String, dynamic>.from(attempts[i]);
          updatedAttempt['status'] = 'Abandoned';
          updatedAttempt['completedAt'] = DateTime.now().toIso8601String(); // Update timestamp
          
          // Update the array
          attempts[i] = updatedAttempt;
          updated = true;
          break;
        }
      }

      if (updated) {
        await userRef.update({
          'assessmentAttempts': attempts,
        });
        print('Assessment $userTestId marked as Abandoned.');
      }
    } catch (e) {
      print('Error abandoning assessment: $e');
    }
  }

  static Future<String?> _createAbandonedRecord(String uid) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
       final userDoc = await userRef.get();

       int attemptNumber = 1;
       if (userDoc.exists) {
         final attempts = userDoc.data()?['assessmentAttempts'] as List? ?? [];
         attemptNumber = attempts.length + 1;
       }

       // Generate a real UUID for early abandonment to mimic backend ID
       final abandonedId = const Uuid().v4();

      await userRef.update({
        'userTestId': abandonedId, // Update current test ID
        'assessmentAttempts': FieldValue.arrayUnion([
          {
            'attemptNumber': attemptNumber,
            'testId': abandonedId,
            'completedAt': DateTime.now().toIso8601String(),
            'status': 'Abandoned'
          }
        ]),
        'testIds': FieldValue.arrayUnion([abandonedId])
      });
      print('Created early abandoned record $abandonedId');
      return abandonedId;
    } catch (e) {
      print('Error creating abandoned record: $e');
      return null;
    }
  }

  static void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }
}
