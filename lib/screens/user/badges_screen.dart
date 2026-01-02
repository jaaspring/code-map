import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({Key? key}) : super(key: key);

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Black & Neon Green Theme
  static const Color geekGreen = Color(0xFF4BC945);
  static const Color geekDarkGreen = Color(0xFF3AA036);
  static const Color geekLightGreen = Color(0xFF5DD954);
  static const Color geekAccent = Color(0xFF6BE062);

  late TabController _tabController;
  List<String> _unlockedBadgeIds = [];
  List<BadgeModel> _allBadges = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _loadBadgeDefinitions(),
        _loadUserBadges(),
      ]);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
      });
    }
  }

  Future<void> _loadBadgeDefinitions() async {
    try {
      print('🔍 Loading badge definitions from Firebase...');

      final snapshot = await _firestore
          .collection('badge_definitions')
          .orderBy('order')
          .get();

      print('📦 Found ${snapshot.docs.length} badges in Firebase');

      if (snapshot.docs.isEmpty) {
        print('⚠️ No badges found in badge_definitions collection!');
        setState(() {
          _errorMessage = 'No badges found. Please add badges in admin panel.';
        });
      }

      final badges = snapshot.docs.map((doc) {
        print('Loading badge: ${doc.data()['name']}');
        return BadgeModel.fromFirestore(doc);
      }).toList();

      setState(() {
        _allBadges = badges;
      });

      print('✅ Loaded ${_allBadges.length} badges successfully');
    } catch (e) {
      print('❌ Error loading badge definitions: $e');
      setState(() {
        _errorMessage = 'Error loading badges: $e';
      });
    }
  }

  Future<void> _loadUserBadges() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        print('👤 Loading badges for user: ${user.uid}');

        final doc = await _firestore.collection('users').doc(user.uid).get();

        if (doc.exists) {
          final data = doc.data();
          final badges = List<String>.from(data?['badges'] ?? []);

          print('🎖️ User has ${badges.length} unlocked badges: $badges');

          setState(() {
            _unlockedBadgeIds = badges;
            _isLoading = false;
          });
        } else {
          print('⚠️ User document not found, creating...');
          await _firestore.collection('users').doc(user.uid).set({
            'badges': [],
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          setState(() {
            _unlockedBadgeIds = [];
            _isLoading = false;
          });
        }
      } else {
        print('❌ No user logged in');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading user badges: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading your badges: $e';
      });
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

  List<BadgeWithStatus> get filteredUnlockedBadges {
    return badgesWithStatus.where((b) {
      final matchesSearch =
          b.badge.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              b.badge.description
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase());
      return b.isUnlocked && matchesSearch;
    }).toList();
  }

  List<BadgeWithStatus> get filteredLockedBadges {
    return badgesWithStatus.where((b) {
      final matchesSearch =
          b.badge.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              b.badge.description
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase());
      return !b.isUnlocked && matchesSearch;
    }).toList();
  }

  List<BadgeWithStatus> get unlockedBadges =>
      badgesWithStatus.where((b) => b.isUnlocked).toList();

  List<BadgeWithStatus> get lockedBadges =>
      badgesWithStatus.where((b) => !b.isUnlocked).toList();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: geekGreen),
              const SizedBox(height: 16),
              const Text(
                'Loading badges...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Badges'),
          backgroundColor: geekGreen,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
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
        ),
      );
    }

    if (_allBadges.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Badges'),
          backgroundColor: geekGreen,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, size: 80, color: Colors.grey[700]),
                const SizedBox(height: 16),
                Text(
                  'No badges available yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[400]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Badges will appear here once admin adds them',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: geekGreen,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Header with gradient
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [geekGreen, geekDarkGreen],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Badges & Achievements',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      onPressed: _loadData,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(
                      icon: Icons.emoji_events,
                      label: 'Unlocked',
                      value: '${unlockedBadges.length}',
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    _buildStatItem(
                      icon: Icons.lock_outline,
                      label: 'Locked',
                      value: '${lockedBadges.length}',
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    _buildStatItem(
                      icon: Icons.workspace_premium,
                      label: 'Total',
                      value: '${_allBadges.length}',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search badges...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.search, color: geekGreen),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: geekGreen.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: geekGreen.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: geekGreen, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border(
                bottom: BorderSide(color: geekGreen.withOpacity(0.3)),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: geekGreen,
              unselectedLabelColor: Colors.grey,
              indicatorColor: geekGreen,
              indicatorWeight: 3,
              tabs: [
                Tab(text: 'Unlocked (${filteredUnlockedBadges.length})'),
                Tab(text: 'Locked (${filteredLockedBadges.length})'),
              ],
            ),
          ),

          // Tab view
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBadgesGrid(filteredUnlockedBadges, true),
                _buildBadgesGrid(filteredLockedBadges, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgesGrid(List<BadgeWithStatus> badges, bool isUnlocked) {
    if (badges.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off
                  : (isUnlocked ? Icons.lock_open : Icons.lock),
              size: 80,
              color: Colors.grey.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No badges found'
                  : (isUnlocked
                      ? 'No badges unlocked yet'
                      : 'All badges unlocked!'),
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade500,
              ),
            ),
            if (!isUnlocked && lockedBadges.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  '🎉 Congratulations! You\'ve unlocked all badges!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: geekGreen),
                ),
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) {
        final badgeWithStatus = badges[index];
        return _buildBadgeCard(badgeWithStatus);
      },
    );
  }

  Widget _buildBadgeCard(BadgeWithStatus badgeWithStatus) {
    final badge = badgeWithStatus.badge;
    final isUnlocked = badgeWithStatus.isUnlocked;

    return GestureDetector(
      onTap: () => _showBadgeDetails(badgeWithStatus),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked ? geekGreen.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: [
            if (isUnlocked)
              BoxShadow(
                color: geekGreen.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Badge icon or image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isUnlocked
                    ? geekGreen.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: badge.imageUrl != null
                  ? ClipOval(
                      child: Image.network(
                        badge.imageUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: geekGreen,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Icon(
                          badge.icon,
                          size: 40,
                          color: isUnlocked ? geekGreen : Colors.grey,
                        ),
                      ),
                    )
                  : Icon(
                      badge.icon,
                      size: 40,
                      color: isUnlocked ? geekGreen : Colors.grey,
                    ),
            ),
            const SizedBox(height: 12),
            // Badge name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                badge.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isUnlocked ? Colors.white : Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            // Badge description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                badge.description,
                style: TextStyle(
                  fontSize: 11,
                  color: isUnlocked ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            // Lock/Unlock indicator
            if (!isUnlocked)
              Icon(
                Icons.lock,
                size: 16,
                color: Colors.grey.shade600,
              ),
          ],
        ),
      ),
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
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 32),
              // Badge icon or image
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? geekGreen.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isUnlocked ? geekGreen : Colors.grey,
                    width: 3,
                  ),
                ),
                child: badge.imageUrl != null
                    ? ClipOval(
                        child: Image.network(
                          badge.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            badge.icon,
                            size: 60,
                            color: isUnlocked ? geekGreen : Colors.grey,
                          ),
                        ),
                      )
                    : Icon(
                        badge.icon,
                        size: 60,
                        color: isUnlocked ? geekGreen : Colors.grey,
                      ),
              ),
              const SizedBox(height: 24),
              // Badge name
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
              // Badge description
              Text(
                badge.description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Status
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? geekGreen.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.1),
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
              // Close button
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: geekGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
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
            ],
          ),
        );
      },
    );
  }
}

// Badge model from Firebase
class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String? iconName;
  final String? imageUrl;
  final String colorHex;
  final String category;

  BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    this.iconName,
    this.imageUrl,
    required this.colorHex,
    required this.category,
  });

  factory BadgeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BadgeModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      iconName: data['iconName'],
      imageUrl: data['imageUrl'],
      colorHex: data['colorHex'] ?? '#4BC945',
      category: data['category'] ?? 'General',
    );
  }

  IconData get icon {
    if (iconName == null) return Icons.emoji_events;

    final iconMap = {
      'emoji_events': Icons.emoji_events,
      'waving_hand': Icons.waving_hand,
      'person_outline': Icons.person_outline,
      'photo_camera': Icons.photo_camera,
      'badge': Icons.badge,
      'explore': Icons.explore,
      'psychology': Icons.psychology,
      'flag': Icons.flag,
      'lightbulb_outline': Icons.lightbulb_outline,
      'checklist': Icons.checklist,
      'route': Icons.route,
      'search': Icons.search,
      'people_outline': Icons.people_outline,
      'thumb_up': Icons.thumb_up,
    };
    return iconMap[iconName] ?? Icons.emoji_events;
  }

  Color get color {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      print('Error parsing color: $colorHex, using default');
      return const Color(0xFF4BC945);
    }
  }
}

// Badge with status model
class BadgeWithStatus {
  final BadgeModel badge;
  final bool isUnlocked;

  BadgeWithStatus({
    required this.badge,
    required this.isUnlocked,
  });
}