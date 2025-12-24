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
      final userDoc = await userRef.get();

      if (!userDoc.exists) return;

      final attempts =
          userDoc.data()?['assessmentAttempts'] as List<dynamic>? ?? [];

      // find and update the specific attempt
      for (int i = 0; i < attempts.length; i++) {
        if (attempts[i]['testId'] == testId) {
          // update this attempt
          final updatedAttempt = Map<String, dynamic>.from(attempts[i]);
          updatedAttempt['status'] = status;
          updatedAttempt['completedAt'] =
              DateTime.now().toIso8601String(); // update completion time

          if (score != null) updatedAttempt['score'] = score;
          if (jobTitle != null) updatedAttempt['jobTitle'] = jobTitle;

          // Update the array
          attempts[i] = updatedAttempt;

          await userRef.update({
            'assessmentAttempts': attempts,
          });

          print(
              'Updated attempt ${updatedAttempt['attemptNumber']} status to $status');
          break;
        }
      }
    } catch (e) {
      print('Error updating attempt status: $e');
    }
  }
}
