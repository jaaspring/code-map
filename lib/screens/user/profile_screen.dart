import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_information_screen.dart';
import 'package:code_map/screens/user/account_settings_screen.dart';

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

  static const Color geekGreen = Color(0xFF4BC945);

  Future<void> _fetchProfileData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _profileImageUrl = data?['photoUrl'] ?? '';
          _name = data?['name'] ?? '';
          _email = user.email ?? '';
          _birthdate = data?['birthdate'] ?? '';
          _gender = data?['gender'] ?? '';
          _username = data?['username'] ?? '';
          _education = data?['education'] ?? '';
          _skills = data?['skills'] ?? '';
          _careerGoals = data?['careerGoals'] ?? '';
          _badges = List<String>.from(data?['badges'] ?? []);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
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
                    ).then((updated) {
                      if (updated != null && updated) {
                        _fetchProfileData();
                      }
                    });
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
                      ).then((updated) {
                        if (updated != null && updated) {
                          _fetchProfileData();
                        }
                      });
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
                  _badges.isEmpty
                      ? const Text(
                          'No badges yet',
                          style: TextStyle(color: Colors.grey),
                        )
                      : Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: _badges.map((badgeId) {
                            return _buildBadge();
                          }).toList(),
                        ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
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

  Widget _buildBadge() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[800],
        border: Border.all(
          color: geekGreen,
          width: 2,
        ),
      ),
      child: const Icon(
        Icons.emoji_events,
        color: geekGreen,
        size: 40,
      ),
    );
  }
}