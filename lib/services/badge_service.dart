import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/badge_model.dart';
import 'dart:convert';

class BadgeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Checks and awards badges based on a trigger.
  /// Returns a list of newly awarded badges.
  static Future<List<BadgeModel>> checkAndAwardBadge({
    required String trigger,
    Map<String, dynamic>? contextData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // 1. Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data() as Map<String, dynamic>;
      final List<String> currentBadges = List<String>.from(userData['badges'] ?? []);

      // 2. Query potential badges for this trigger
      final badgeQuery = await _firestore
          .collection('badge_definitions')
          .where('trigger', isEqualTo: trigger)
          .where('isActive', isEqualTo: true)
          .get();

      List<BadgeModel> newBadges = [];

      for (var doc in badgeQuery.docs) {
        final badgeId = doc.id;
        
        // Skip if user already has this badge
        if (currentBadges.contains(badgeId)) continue;

        final data = doc.data();
        final String? conditionType = data['conditionType'];
        final String? conditionField = data['conditionField'];
        final dynamic conditionValue = data['conditionValue'];

        bool isMet = false;

        // Determine if condition is met
        if (conditionType == null || conditionType == 'none' || conditionField == null) {
          isMet = true; 
        } else {
          // Check the field value
          dynamic userValue;
          
          // Check contextData first (e.g. current assessment score)
          if (contextData != null && contextData.containsKey(conditionField)) {
            userValue = contextData[conditionField];
          } else {
            // Otherwise check Firestore user doc
            // Profile Pro uses 'profileImageUrl' in definition but 'photoUrl' in doc
            String fieldToQuery = conditionField;
            if (fieldToQuery == 'profileImageUrl') fieldToQuery = 'photoUrl';
            userValue = userData[fieldToQuery];
          }

          if (userValue != null) {
            switch (conditionType) {
              case 'equals':
                isMet = userValue.toString() == conditionValue.toString();
                break;
              case 'count':
              case 'at_least':
                if (userValue is num && conditionValue is num) {
                  isMet = userValue >= conditionValue;
                }
                break;
              case 'array_length':
                if (userValue is List && conditionValue is num) {
                  isMet = userValue.length >= conditionValue;
                }
                break;
              case 'not_empty':
                if (userValue is String) {
                  isMet = userValue.isNotEmpty;
                } else if (userValue is List) {
                  isMet = userValue.isNotEmpty;
                }
                break;
              case 'exists':
              case 'not_null':
                isMet = true; // Already verified not null above
                break;
            }
          }
        }

        if (isMet) {
          newBadges.add(BadgeModel.fromFirestore(doc));
          currentBadges.add(badgeId);
        }
      }

      // 3. Update user doc if new badges were earned
      if (newBadges.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update({
          'badges': currentBadges,
        });
      }

      return newBadges;
    } catch (e) {
      print("Error checking badges: $e");
      return [];
    }
  }

  /// Shows a congratulations dialog for earned badges.
  static void showBadgeDialog(BuildContext context, List<BadgeModel> badges) {
    if (badges.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return BadgeCelebrationDialog(badges: badges);
      },
    );
  }
}

class BadgeCelebrationDialog extends StatefulWidget {
  final List<BadgeModel> badges;

  const BadgeCelebrationDialog({Key? key, required this.badges}) : super(key: key);

  @override
  State<BadgeCelebrationDialog> createState() => _BadgeCelebrationDialogState();
}

class _BadgeCelebrationDialogState extends State<BadgeCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF4BC945).withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4BC945).withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.stars_rounded,
                  color: Color(0xFF4BC945),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.badges.length == 1
                      ? 'You earned a new badge!'
                      : 'You earned ${widget.badges.length} new badges!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Badge list
                ...widget.badges.map((badge) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      _buildBadgeIcon(badge),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              badge.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              badge.description,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )).toList(),

                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4BC945),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'AWESOME!',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildBadgeIcon(BadgeModel badge) {
    final Color badgeColor = badge.color;
    
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: badgeColor.withOpacity(0.5), width: 2),
      ),
      child: Center(
        child: badge.imageUrl != null && badge.imageUrl!.isNotEmpty
            ? ClipOval(
                child: Image.memory(
                  base64Decode(badge.imageUrl!),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              )
            : Icon(
                badge.icon,
                color: badgeColor,
                size: 30,
              ),
      ),
    );
  }
}
