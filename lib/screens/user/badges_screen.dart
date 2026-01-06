import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../../models/badge_model.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({Key? key}) : super(key: key);

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color geekGreen = Color(0xFF4BC945);

  List<String> _unlockedBadgeIds = [];
  List<BadgeModel> _allBadges = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _assessmentsCompleted = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _loadBadgeDefinitions(),
        _loadUserProgress(),
      ]);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBadgeDefinitions() async {
    try {
      final snapshot = await _firestore
          .collection('badge_definitions')
          .orderBy('order')
          .get();

      final badges = snapshot.docs.map((doc) {
        return BadgeModel.fromFirestore(doc);
      }).toList();

      setState(() {
        _allBadges = badges;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading badges: $e';
      });
    }
  }

  Future<void> _loadUserProgress() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();

        if (doc.exists) {
          final data = doc.data();
          setState(() {
            _unlockedBadgeIds = List<String>.from(data?['badges'] ?? []);
            _assessmentsCompleted = data?['assessmentsCompleted'] ?? 0;
          });
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  List<BadgeWithStatus> get badgesWithStatus {
    return _allBadges.map((badge) {
      final isUnlocked = _unlockedBadgeIds.contains(badge.id);
      return BadgeWithStatus(
        badge: badge,
        isUnlocked: isUnlocked,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: geekGreen),
        ),
      );
    }

    if (_errorMessage != null || _allBadges.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Badges'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.grey[700]),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'No badges available',
                style: TextStyle(fontSize: 16, color: Colors.grey[500]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: geekGreen,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Simple Header with Back Button and Logo
            Padding(
              padding: const EdgeInsets.all(24),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Logo centered
                  Image.asset(
                    'assets/icons/logo_only_white.png',
                    height: 30,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.emoji_events, color: Colors.white, size: 30),
                  ),
                  // Refresh button on the right
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _loadData,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.refresh,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Text(
                'Achievement\nBadges',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: geekGreen,
                  height: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const Text(
                'Track your progress and unlock achievements',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.85,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
              ),
              itemCount: badgesWithStatus.length,
              itemBuilder: (context, index) {
                return _buildBadgeCard(badgesWithStatus[index]);
              },
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildBadgeCard(BadgeWithStatus badgeWithStatus) {
    final badge = badgeWithStatus.badge;
    final isUnlocked = badgeWithStatus.isUnlocked;

    return GestureDetector(
      onTap: () => _showBadgeDetails(badgeWithStatus),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Badge Icon with grayscale - BIGGER, NO BORDER
          Expanded(
            child: _buildBadgeIcon(badge, isUnlocked),
          ),
          const SizedBox(height: 8),
          // Badge Name - BIGGER TEXT
          Text(
            badge.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isUnlocked ? Colors.white : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeIcon(BadgeModel badge, bool isUnlocked) {
    if (badge.imageUrl != null && badge.imageUrl!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(badge.imageUrl!);
        return ColorFiltered(
          colorFilter: isUnlocked
              ? const ColorFilter.mode(
                  Colors.transparent,
                  BlendMode.multiply,
                )
              : const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0, 0, 0, 1, 0,
                ]),
          child: Image.memory(
            imageBytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                badge.icon,
                size: 40,
                color: isUnlocked ? geekGreen : Colors.grey,
              );
            },
          ),
        );
      } catch (e) {
        return Icon(
          badge.icon,
          size: 40,
          color: isUnlocked ? geekGreen : Colors.grey,
        );
      }
    }

    return Icon(
      badge.icon,
      size: 40,
      color: isUnlocked ? geekGreen : Colors.grey,
    );
  }

  void _showBadgeDetails(BadgeWithStatus badgeWithStatus) {
    final badge = badgeWithStatus.badge;
    final isUnlocked = badgeWithStatus.isUnlocked;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(
              color: geekGreen.withOpacity(0.3),
              width: 2,
            ),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 120,
                height: 120,
                child: _buildBadgeIcon(badge, isUnlocked),
              ),
              const SizedBox(height: 24),
              Text(
                badge.name,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Description Section
              Column(
                children: [
                   const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: geekGreen, // or Colors.white with bold
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    badge.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              
              const SizedBox(height: 24),

              // Criteria / How to Earn Section
              Column(
                children: [
                   const Text(
                    'How to Earn',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: geekGreen,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    badge.criteriaDescription,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[400],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? geekGreen.withOpacity(0.2)
                      : Colors.grey[800],
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isUnlocked ? geekGreen : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUnlocked ? Icons.check_circle : Icons.lock,
                      color: isUnlocked ? geekGreen : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isUnlocked ? 'Unlocked' : 'Locked',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isUnlocked ? geekGreen : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: geekGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

