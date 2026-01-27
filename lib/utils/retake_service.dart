import 'package:cloud_firestore/cloud_firestore.dart';

class RetakeService {
  // check if user can retake based on rules
  static bool canRetakeTest(List<dynamic> attempts) {
    if (attempts.isEmpty) {
      return true; // no attempts yet, can take the test
    }

    if (attempts.length >= 10) {
      return false; // max attempts reached
    }

    // get last attempt
    final lastAttempt = attempts.last;
    final completedAt = lastAttempt['completedAt'];

    // parse date safely
    DateTime lastDate;
    if (completedAt is String) {
      lastDate = DateTime.parse(completedAt);
    } else if (completedAt is Timestamp) {
      lastDate = completedAt.toDate();
    } else {
      return false; // unknown format, deny retake
    }

    final now = DateTime.now();
    final difference = now.difference(lastDate).inDays;

    if (attempts.length < 3) {
      return true; // less than 3 attempts, can retake anytime
    } else if (attempts.length < 6) {
      return difference >= 7; // 3-5 attempts, need 7 days gap
    } else {
      return difference >= 30; // 6-9 attempts, need 30 days gap
    }
  }

  // calculate days until next retake is available
  static int daysUntilRetake(List<dynamic> attempts) {
    if (attempts.isEmpty) return 0;

    final lastAttempt = attempts.last;
    final completedAt = lastAttempt['completedAt'];

    DateTime lastDate;
    if (completedAt is String) {
      lastDate = DateTime.parse(completedAt);
    } else if (completedAt is Timestamp) {
      lastDate = completedAt.toDate();
    } else {
      return 0;
    }

    final now = DateTime.now();
    final difference = now.difference(lastDate).inDays;

    if (attempts.length < 3) return 0; // can retake anytime

    if (attempts.length < 6) {
      // needs 7 days gap
      const daysNeeded = 7;
      return daysNeeded - difference;
    } else {
      // needs 30 days gap
      const daysNeeded = 30;
      return daysNeeded - difference;
    }
  }

  // get user attempts from Firebase
  static Future<List<dynamic>> getUserAttempts(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) return [];

      final attempts = userDoc.data()?['assessmentAttempts'] as List<dynamic>?;
      return attempts ?? [];
    } catch (e) {
      print('Error getting user attempts: $e');
      return [];
    }
  }

  // Update attempt status when test is completed
  static Future<void> updateAttemptStatus({
    required String userId,
    required String testId,
    required String status, // 'Completed', 'In progress'
    double? score,
    String? jobTitle,
  }) async {
    try {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      
      // Use transaction to ensure atomic updates for counters
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);

        if (!userDoc.exists) return;

        final userData = userDoc.data()!;
        final attempts = List<dynamic>.from(userData['assessmentAttempts'] ?? []);

        bool updated = false;
        bool wasAlreadyCompleted = false;

        // find and update the specific attempt
        for (int i = 0; i < attempts.length; i++) {
          final attempt = Map<String, dynamic>.from(attempts[i]); // Create copy
          if (attempt['testId'] == testId) {
            
            // IDEMPOTENCY CHECK: If already completed, don't increment counters again
            if (attempt['status'] == 'Completed') {
              wasAlreadyCompleted = true;
            }

            // update this attempt
            attempt['status'] = status;
            
            // Only update timestamp if it wasn't already completed or if we are just marking it completed now
            if (!wasAlreadyCompleted && status == 'Completed') {
               attempt['completedAt'] = DateTime.now().toIso8601String();
            } else if (status != 'Completed') {
               attempt['completedAt'] = DateTime.now().toIso8601String();
            }

            if (score != null) attempt['score'] = score;
            if (jobTitle != null) attempt['jobTitle'] = jobTitle;

            // Update the array
            attempts[i] = attempt;
            updated = true;
            break;
          }
        }

        if (updated) {
          Map<String, dynamic> updateData = {
            'assessmentAttempts': attempts,
          };

          // If status is completed and it wasn't completed before, update counters
          if (status == 'Completed' && !wasAlreadyCompleted) {
            updateData['assessmentsCompleted'] = FieldValue.increment(1);
            
            // --- WEEKLY ASSESSMENTS LOGIC ---
            final now = DateTime.now();
            final lastAssessmentDateStr = userData['lastAssessmentDate'];
            
            DateTime? lastAssessmentDate;
            if (lastAssessmentDateStr != null) {
              if (lastAssessmentDateStr is String) {
                lastAssessmentDate = DateTime.tryParse(lastAssessmentDateStr);
              } else if (lastAssessmentDateStr is Timestamp) {
                lastAssessmentDate = lastAssessmentDateStr.toDate();
              }
            }

            // Check if current completion is in the same week as the last one
            if (lastAssessmentDate != null && _isSameWeek(lastAssessmentDate, now)) {
              updateData['weeklyAssessments'] = FieldValue.increment(1);
            } else {
              // New week, reset to 1 (this attempt)
              updateData['weeklyAssessments'] = 1;
            }
            
            updateData['lastAssessmentDate'] = now.toIso8601String();
          }

          transaction.update(userRef, updateData);
          
          if (status == 'Completed' && !wasAlreadyCompleted) {
             print('Assessment $testId completed. Counters updated.');
          } else {
             print('Updated attempt $testId status to $status (Idempotent update).');
          }
        }
      });

    } catch (e) {
      print('Error updating attempt status: $e');
    }
  }

  static bool _isSameWeek(DateTime date1, DateTime date2) {
    // Calculate the start of the week (Monday) for both dates
    // This is a simple approximation. exact week number libraries can also be used.
    // Monday is 1, Sunday is 7.
    final d1 = date1.subtract(Duration(days: date1.weekday - 1));
    final d2 = date2.subtract(Duration(days: date2.weekday - 1));
    
    // Normalize to midnight
    final startOfWeek1 = DateTime(d1.year, d1.month, d1.day);
    final startOfWeek2 = DateTime(d2.year, d2.month, d2.day);
    
    return startOfWeek1 == startOfWeek2;
  }
}
