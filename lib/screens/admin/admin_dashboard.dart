import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:codemapv1/screens/login_screen.dart';
import 'user_list_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _backgroundController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // GeeksforGeeks color scheme - matching user home screen
  static const Color geekGreen = Color(0xFF2F8D46);
  static const Color geekDarkGreen = Color(0xFF1B5E20);
  static const Color geekLightGreen = Color(0xFF4CAF50);
  static const Color geekAccent = Color(0xFF66BB6A);
  static const Color geekBackground = Color(0xFFE8F5E9);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  Future<Map<String, int>> getDashboardStats() async {
    final usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();
    return {
      'totalUsers': usersSnapshot.size,
      'activeUsers': usersSnapshot.size,
      'newUsers': 5,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background matching user home screen
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    geekBackground,
                    Colors.white,
                    geekLightGreen.withOpacity(0.2),
                    geekBackground,
                  ],
                ),
              ),
            ),
          ),
          // Background with code symbols pattern
          Positioned.fill(
            child: CustomPaint(
              painter: CodePatternPainter(),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom App Bar with GeeksforGeeks gradient
                Container(
                  padding: const EdgeInsets.only(top: 20, bottom: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [geekGreen, geekDarkGreen],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: geekGreen.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '.CodeMap.',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Admin Dashboard',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
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
                            borderRadius: BorderRadius.circular(25),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: const Icon(Icons.logout,
                                  color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Dashboard Content
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Stats Cards Section
                              FutureBuilder<Map<String, int>>(
                                future: getDashboardStats(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return Center(
                                      child: CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                geekGreen),
                                      ),
                                    );
                                  }
                                  if (snapshot.hasError) {
                                    return const Text("Error fetching data");
                                  }

                                  final stats = snapshot.data ?? {};
                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        const UserListScreen(),
                                                  ),
                                                );
                                              },
                                              child: _buildStatsCard(
                                                'Total Users',
                                                stats['totalUsers']
                                                        ?.toString() ??
                                                    '0',
                                                Icons.people,
                                                geekGreen,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 15),
                                          Expanded(
                                            child: _buildStatsCard(
                                              'Active Users',
                                              stats['activeUsers']
                                                      ?.toString() ??
                                                  '0',
                                              Icons.person_outline,
                                              geekLightGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 15),
                                      _buildStatsCard(
                                        'New Users This Week',
                                        stats['newUsers']?.toString() ?? '0',
                                        Icons.trending_up,
                                        geekAccent,
                                        isWide: true,
                                      ),
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(height: 32),

                              // Quick Actions Section
                              const Text(
                                'Quick Actions',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Action Buttons
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                crossAxisSpacing: 15,
                                mainAxisSpacing: 15,
                                childAspectRatio: 1.2,
                                children: [
                                  _buildActionCard(
                                    'Manage Users',
                                    Icons.manage_accounts,
                                    geekGreen,
                                    () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const UserListScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  _buildActionCard(
                                    'View Stats',
                                    Icons.analytics,
                                    geekLightGreen,
                                    () => ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('View Stats coming soon!'),
                                        backgroundColor: geekGreen,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    ),
                                  ),
                                  _buildActionCard(
                                    'Settings',
                                    Icons.settings,
                                    geekAccent,
                                    () => ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text('Settings coming soon!'),
                                        backgroundColor: geekGreen,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    ),
                                  ),
                                  _buildActionCard(
                                    'Reports',
                                    Icons.assessment,
                                    geekDarkGreen,
                                    () => ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text('Reports coming soon!'),
                                        backgroundColor: geekGreen,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(String title, String value, IconData icon, Color color,
      {bool isWide = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title: $value'),
              backgroundColor: geekGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: isWide ? double.infinity : null,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 0,
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 0,
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom painter for code pattern background (same as user home screen)
class CodePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final codeSymbols = [
      '</>',
      '{',
      '}',
      '()',
      '[]',
      ';',
      'if',
      'for',
      'fn',
      'var',
      '==',
      'let'
    ];

    for (var i = 0; i < 30; i++) {
      final x = (i * 80.0) % size.width;
      final y = ((i * 50.0) % size.height);
      final symbol = codeSymbols[i % codeSymbols.length];

      textPainter.text = TextSpan(
        text: symbol,
        style: TextStyle(
          fontSize: 20,
          color: const Color(0xFF2F8D46).withOpacity(0.05),
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      );

      textPainter.layout();
      textPainter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
