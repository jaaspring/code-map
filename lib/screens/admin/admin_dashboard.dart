import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:codemapv1/screens/login_screen.dart';
import 'user_list_screen.dart';
import 'admin_badge_creator_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final PageController _pageController = PageController();
  int _carouselIndex = 0;

  // Color scheme
  static const Color geekGreen = Color(0xFF4BC945);
  static const Color geekDarkGreen = Color(0xFF3AA036);

  bool _isUsersPressed = false;
  bool _isBadgesPressed = false;
  bool _isActivePressed = false;
  bool _isNewPressed = false;
  bool _isManageUsersPressed = false;
  bool _isManageBadgesPressed = false;
  bool _isStatsPressed = false;
  bool _isSettingsPressed = false;

  // Cache stats data
  Map<String, int>? _cachedStats;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardStats() async {
    try {
      final stats = await getDashboardStats();
      if (mounted) {
        setState(() {
          _cachedStats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false; // Show grid with 0s if error
        });
      }
    }
  }

  Future<Map<String, int>> getDashboardStats() async {
    final usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();
    final badgesSnapshot =
        await FirebaseFirestore.instance.collection('badge_definitions').get();

    final totalUsers = usersSnapshot.size > 0 ? usersSnapshot.size - 1 : 0;
    final activeUsers = usersSnapshot.size > 0 ? usersSnapshot.size - 1 : 0;

    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));

    int newUsers = 0;
    for (var doc in usersSnapshot.docs) {
      final data = doc.data();
      if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        if (createdAt.isAfter(oneWeekAgo)) {
          newUsers++;
        }
      }
    }

    return {
      'totalUsers': totalUsers,
      'activeUsers': activeUsers,
      'newUsers': newUsers,
      'totalBadges': badgesSnapshot.size,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '.CodeMap.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.logout,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),

                    // 4 Stats Cards (2x2 grid)
                    _isLoadingStats
                        ? Container(
                            height: 200,
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(
                              color: geekGreen,
                            ),
                          )
                        : Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSmallStatCard(
                                      'Total Users',
                                      _cachedStats?['totalUsers']?.toString() ??
                                          '0',
                                      Icons.people_outline,
                                      _isUsersPressed,
                                      () => setState(
                                          () => _isUsersPressed = true),
                                      () => setState(
                                          () => _isUsersPressed = false),
                                      () => setState(
                                          () => _isUsersPressed = false),
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const UserListScreen(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildSmallStatCard(
                                      'Total Badges',
                                      _cachedStats?['totalBadges']
                                              ?.toString() ??
                                          '0',
                                      Icons.emoji_events_outlined,
                                      _isBadgesPressed,
                                      () => setState(
                                          () => _isBadgesPressed = true),
                                      () => setState(
                                          () => _isBadgesPressed = false),
                                      () => setState(
                                          () => _isBadgesPressed = false),
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AdminBadgeCreatorScreen(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSmallStatCard(
                                      'Active Users',
                                      _cachedStats?['activeUsers']
                                              ?.toString() ??
                                          '0',
                                      Icons.person_outline,
                                      _isActivePressed,
                                      () => setState(
                                          () => _isActivePressed = true),
                                      () => setState(
                                          () => _isActivePressed = false),
                                      () => setState(
                                          () => _isActivePressed = false),
                                      null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildSmallStatCard(
                                      'New Users',
                                      _cachedStats?['newUsers']?.toString() ??
                                          '0',
                                      Icons.trending_up,
                                      _isNewPressed,
                                      () =>
                                          setState(() => _isNewPressed = true),
                                      () =>
                                          setState(() => _isNewPressed = false),
                                      () =>
                                          setState(() => _isNewPressed = false),
                                      null,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                    const SizedBox(height: 24),

                    // Section Title
                    const Text(
                      'What Admin Can Do',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: geekGreen,
                        letterSpacing: 0.3,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Admin Carousel
                    _buildCarousel(),

                    const SizedBox(height: 12),

                    // Carousel indicators
                    _buildCarouselIndicators(),

                    const SizedBox(height: 24),

                    // Section Title
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: geekGreen,
                        letterSpacing: 0.3,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Action Cards with Arrows
                    _buildActionCard(
                      'Manage Users',
                      'View and manage all users',
                      Icons.manage_accounts,
                      _isManageUsersPressed,
                      () => setState(() => _isManageUsersPressed = true),
                      () => setState(() => _isManageUsersPressed = false),
                      () => setState(() => _isManageUsersPressed = false),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserListScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildActionCard(
                      'Manage Badges',
                      'Create and edit badges',
                      Icons.emoji_events,
                      _isManageBadgesPressed,
                      () => setState(() => _isManageBadgesPressed = true),
                      () => setState(() => _isManageBadgesPressed = false),
                      () => setState(() => _isManageBadgesPressed = false),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminBadgeCreatorScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildActionCard(
                      'View Stats',
                      'Analytics and reports',
                      Icons.analytics,
                      _isStatsPressed,
                      () => setState(() => _isStatsPressed = true),
                      () => setState(() => _isStatsPressed = false),
                      () => setState(() => _isStatsPressed = false),
                      () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Coming soon!'),
                          backgroundColor: geekGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildActionCard(
                      'Settings',
                      'App configuration',
                      Icons.settings,
                      _isSettingsPressed,
                      () => setState(() => _isSettingsPressed = true),
                      () => setState(() => _isSettingsPressed = false),
                      () => setState(() => _isSettingsPressed = false),
                      () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Coming soon!'),
                          backgroundColor: geekGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Small Stat Cards - IMPROVED FOR ELDERLY READABILITY
  Widget _buildSmallStatCard(
    String title,
    String value,
    IconData icon,
    bool isPressed,
    VoidCallback onTapDown,
    VoidCallback onTapUp,
    VoidCallback onTapCancel,
    VoidCallback? onTap,
  ) {
    final bool clickable = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: clickable ? onTap : null,
        onTapDown: clickable ? (_) => onTapDown() : null,
        onTapUp: clickable ? (_) => onTapUp() : null,
        onTapCancel: clickable ? onTapCancel : null,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          // jangan paksa height besar sangat, bagi flexible sikit
          height: 140, // Fixed height to ensure grid consistency
          padding: const EdgeInsets.all(14), // reduce sikit (was 16)
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPressed ? Colors.white : geekGreen,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: geekGreen.withOpacity(isPressed ? 0.28 : 0.14),
                blurRadius: isPressed ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          transform:
              isPressed ? Matrix4.identity().scaled(0.98) : Matrix4.identity(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // icon box kecil sikit supaya tak overflow
              Container(
                padding: const EdgeInsets.all(8), // was 10
                decoration: BoxDecoration(
                  color: geekGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: geekGreen, size: 24), // was 26
              ),

              const SizedBox(height: 10),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 6),

              // ini yang avoid overflow: number akan scale down bila sempit
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Carousel for Admin
  Widget _buildCarousel() {
    return SizedBox(
      height: 180,
      child: PageView(
        controller: _pageController,
        physics: const PageScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _carouselIndex = index;
          });
        },
        children: [
          _buildCarouselCard(
            title: 'User Management',
            description:
                'Monitor and manage all registered users. View user activities, approve accounts, and maintain platform security.',
            icon: Icons.people,
            color: Colors.white,
          ),
          _buildCarouselCard(
            title: 'Badge System',
            description:
                'Create, edit, and manage achievement badges. Track user progress and reward milestones across the platform.',
            icon: Icons.emoji_events,
            color: Colors.white,
          ),
          _buildCarouselCard(
            title: 'Analytics Dashboard',
            description:
                'Access detailed insights on user engagement, platform growth, and content performance metrics.',
            icon: Icons.analytics,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            height: 140,
            child: Lottie.asset(
              'assets/lottie/IQ-Practice.json',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.smart_toy,
                  size: 80,
                  color: Colors.black,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _carouselIndex == index ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _carouselIndex == index ? geekGreen : Colors.grey.shade700,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // Action Card with Arrow
  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    bool isPressed,
    VoidCallback onTapDown,
    VoidCallback onTapUp,
    VoidCallback onTapCancel,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTapDown: (_) => onTapDown(),
        onTapUp: (_) => onTapUp(),
        onTapCancel: onTapCancel,
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPressed ? geekGreen : geekGreen.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: geekGreen.withOpacity(isPressed ? 0.25 : 0.15),
                blurRadius: isPressed ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          transform:
              isPressed ? Matrix4.identity().scaled(0.98) : Matrix4.identity(),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.black38,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
