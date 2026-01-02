import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_information_screen.dart';
import 'package:code_map/screens/user/account_settings_screen.dart';
import '../../models/badge_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _profileImageUrl = '';
  String _name = '';
  String _email = '';
  String _birthdate = '';
  String _gender = '';
  String _username = '';
  String _education = '';
  String _skills = '';
  String _careerGoals = '';
  List<String> _badges = [];
  List<BadgeModel> _recentBadges = [];

  static const Color geekGreen = Color(0xFF4BC945);

  Map<String, BadgeModel> _badgeCache = {};

  Stream<DocumentSnapshot> _getUserStream() {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestore.collection('users').doc(user.uid).snapshots();
    }
    return const Stream.empty();
  }

  Future<void> _updateBadgeCache(List<String> badgeIds) async {
    final missingIds = badgeIds.where((id) => !_badgeCache.containsKey(id)).toList();
    if (missingIds.isEmpty) return;

    // Fetch missing badge definitions
    final docs = await Future.wait(
      missingIds.map((id) => _firestore.collection('badge_definitions').doc(id).get())
    );

    if (mounted) {
      setState(() {
        for (var doc in docs) {
          if (doc.exists) {
            _badgeCache[doc.id] = BadgeModel.fromFirestore(doc);
          }
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Initial fetch for non-stream data if any (though most is in stream now)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _getUserStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _name.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: geekGreen));
          }

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            _profileImageUrl = data['photoUrl'] ?? '';
            _name = data['name'] ?? '';
            _username = data['username'] ?? '';
            _education = data['education'] ?? '';
            _skills = data['skills'] ?? '';
            _careerGoals = data['careerGoals'] ?? '';
            _badges = List<String>.from(data['badges'] ?? []);
            
            // Trigger cache update for badges
            if (_badges.isNotEmpty) {
              final recentIds = _badges.length > 3 
                  ? _badges.sublist(_badges.length - 3) 
                  : _badges;
              _updateBadgeCache(recentIds);

              _recentBadges = recentIds
                  .where((id) => _badgeCache.containsKey(id))
                  .map((id) => _badgeCache[id]!)
                  .toList()
                  .reversed.toList();
            } else {
              _recentBadges = [];
            }
          }

          return Column(
            children: [
              // Green Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [geekGreen, Color(0xFF3AA036)],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.home, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AccountSettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Profile Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Profile Avatar
                      Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[800],
                              border: Border.all(
                                color: geekGreen,
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: _profileImageUrl.isEmpty
                                  ? const Icon(Icons.person,
                                      size: 60, color: Colors.grey)
                                  : Image.memory(
                                      base64Decode(_profileImageUrl),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: geekGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.circle,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Name
                      Text(
                        _name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: geekGreen,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Username
                      Text(
                        _username,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Edit Profile Button
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditInformationScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: geekGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Edit profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Education Section
                      if (_education.isNotEmpty)
                        _buildInfoSection(
                          'Education:',
                          _education,
                        ),

                      // Skills Section
                      if (_skills.isNotEmpty)
                        _buildInfoSection(
                          'Skills:',
                          _skills,
                        ),

                      // Career Goals Section
                      if (_careerGoals.isNotEmpty)
                        _buildInfoSection(
                          'Career Goals:',
                          _careerGoals,
                        ),

                      const SizedBox(height: 30),

                      // Achievements Section
                      const Text(
                        'Achievements',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: geekGreen,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Badges Display
                      _recentBadges.isEmpty
                          ? Text(
                              _badges.isEmpty ? 'No badges yet' : 'Loading badges...',
                              style: const TextStyle(color: Colors.grey),
                            )
                          : Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: _recentBadges.map((badge) {
                                return _buildBadge(badge);
                              }).toList(),
                            ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.5,
            ),
            children: [
              TextSpan(
                text: '$title ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextSpan(
                text: content,
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(BadgeModel badge) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[900],
        border: Border.all(
          color: badge.color.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: badge.color.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: badge.imageUrl != null && badge.imageUrl!.isNotEmpty
            ? Image.memory(
                base64Decode(badge.imageUrl!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Icon(
                  badge.icon,
                  color: badge.color,
                  size: 40,
                ),
              )
            : Icon(
                badge.icon,
                color: badge.color,
                size: 40,
              ),
      ),
    );
  }
}