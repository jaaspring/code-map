import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../login_screen.dart';
import 'profile_screen.dart';
import 'badges_screen.dart';
import '../../widgets/custom_button_nav.dart';
import 'assessment_screen.dart';
import 'career_roadmap_screen.dart';
import 'report_history.dart';
import 'recent_report_widget.dart';
import '../../models/user_responses.dart';
import '../../services/assessment_state_service.dart';
import '../follow_up_test/follow_up_screen.dart';
import '../educational_background_test/educational_background_screen.dart';
import '../educational_background_test/education_level.dart';
import '../educational_background_test/education_major.dart';
import '../educational_background_test/cgpa.dart';
import '../educational_background_test/coursework_experience.dart';
import '../educational_background_test/programming_languages.dart';
import '../educational_background_test/thesis_topic.dart';
import '../skill_reflection_test/skill_reflection_screen.dart';
import '../skill_reflection_test/skill_reflection_test.dart';
import '../skill_reflection_test/thesis_findings.dart';
import '../skill_reflection_test/career_goals.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int _carouselIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final PageController _pageController = PageController();

  bool _isAssessmentPressed = false;
  bool _isAchievementPressed = false;

  // Color scheme
  static const Color geekGreen = Color(0xFF4BC945);
  static const Color geekDarkGreen = Color(0xFF3AA036);
  static const Color geekLightGreen = Color(0xFF5DD954);
  static const Color geekAccent = Color(0xFF6BE062);
  static const Color geekCardBg = Color(0xFF1A1A1A);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _profileImageUrl = '';
  String _name = '';
  int _unlockedBadgesCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchProfileData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          final badges = List<String>.from(data?['badges'] ?? []);
          setState(() {
            _profileImageUrl = data?['photoUrl'] ?? '';
            _name = data?['name'] ?? '';
            _unlockedBadgesCount = badges.length;
          });
        }
      } catch (e) {
        print('Error fetching profile data: $e');
      }
    }
  }

  String get userName {
    if (_name.isNotEmpty) {
      return _name;
    }
    final user = _auth.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!;
    } else if (user?.email != null) {
      return user!.email!.split('@')[0];
    }
    return '';
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(),
      ),
    ).then((_) {
      _fetchProfileData();
    });
  }

  void _navigateToBadges() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BadgesScreen(),
      ),
    ).then((_) {
      _fetchProfileData();
    });
  }

  void _resumeAssessment(BuildContext context, String testId, int attemptNumber) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final draft = await AssessmentStateService.fetchDraft(testId);
    
    if (!mounted) return;
    Navigator.pop(context); // Hide loading

    if (draft != null) {
      final responses = UserResponses.fromJson(draft['responses']);
      final step = draft['currentStep'];

      Widget nextScreen;
      switch (step) {
        case 'EducationalBackgroundTestScreen':
          nextScreen = EducationalBackgroundTestScreen(existingUserTestId: testId);
          break;
        case 'EducationLevel':
          nextScreen = EducationLevel(userResponse: responses);
          break;
        case 'EducationMajor':
          nextScreen = EducationMajor(userResponse: responses);
          break;
        case 'Cgpa':
          nextScreen = Cgpa(userResponse: responses);
          break;
        case 'CourseworkExperience':
          nextScreen = CourseworkExperience(userResponse: responses);
          break;
        case 'ProgrammingLanguages':
          nextScreen = ProgrammingLanguages(userResponse: responses);
          break;
        case 'ThesisTopic':
          nextScreen = ThesisTopic(userResponse: responses);
          break;
        case 'SkillReflectionScreen':
          nextScreen = SkillReflectionScreen(userResponse: responses);
          break;
        case 'SkillReflectionTest':
          nextScreen = SkillReflectionTest(userResponse: responses);
          break;
        case 'ThesisFindings':
          nextScreen = ThesisFindings(userResponse: responses);
          break;
        case 'CareerGoals':
          nextScreen = CareerGoals(userResponse: responses);
          break;
        case 'FollowUpScreen':
        case 'FollowUpTest':
             nextScreen = FollowUpScreen(userResponse: responses, userTestId: testId, attemptNumber: attemptNumber); 
             break;
        default:
          nextScreen = AssessmentScreen(existingUserTestId: testId);
      }
      Navigator.push(context, MaterialPageRoute(builder: (_) => nextScreen));
    } else {
      // Fallback if no draft found but we have an ID
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AssessmentScreen(existingUserTestId: testId),
        ),
      );
    }
  }

  // Modified to use internal state and content switching
  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Removed direct navigation to profile here as requested by 'case logic' implementation
    // Case 3 will handle profile display
  }

  // Added method to handle tab content switching logic
  Widget _getContentForTab(int index) {
    switch (index) {
      case 0:
        // Case 0: The existing "Home" content
        return Column(
          children: [
            // Refined Header matching Figma design
            Container(
              padding: const EdgeInsets.only(
                  top: 50, bottom: 20, left: 20, right: 20),
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
                  // Top bar - logo and logout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _logout(context),
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
                  const SizedBox(height: 16),
                  // User greeting
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _navigateToProfile,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.white,
                              width: 2.5,
                            ),
                          ),
                          child: ClipOval(
                            child: _profileImageUrl.isEmpty
                                ? Container(
                                    color: geekLightGreen,
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  )
                                : Image.memory(
                                    base64Decode(_profileImageUrl),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: geekLightGreen,
                                        child: const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Welcome Back,',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$userName :3',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
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

                      // Badge Achievement card with rounded border
                      _buildStatCard(
                        icon: Icons.emoji_events,
                        label: 'Badge and\nAchievement',
                        value: '$_unlockedBadgesCount',
                        color: geekGreen,
                        onTap: _navigateToBadges,
                      ),

                      const SizedBox(height: 24),

                      // Get Started section
                      const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: geekGreen,
                          letterSpacing: 0.3,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Career Assessment with pulse animation
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(_auth.currentUser?.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          bool canResume = false;
                          Map<String, dynamic>? pendingAttempt;
                          int attemptNumber = 1;

                          if (snapshot.hasData && snapshot.data!.exists) {
                            final data = snapshot.data!.data() as Map<String, dynamic>?;
                            final attempts = data?['assessmentAttempts'] as List<dynamic>? ?? [];

                            if (attempts.isNotEmpty) {
                              // Sort by completedAt to find the latest
                                attempts.sort((a, b) {
                                  String? dateA = a['completedAt'];
                                  String? dateB = b['completedAt'];
                                  if (dateA == null) return -1;
                                  if (dateB == null) return 1;
                                  return DateTime.parse(dateA).compareTo(DateTime.parse(dateB));
                                });
                                
                              final lastAttempt = attempts.last;
                              final status = lastAttempt['status'];
                              if (status == 'Abandoned' || status == 'In progress') {
                                canResume = true;
                                pendingAttempt = lastAttempt;
                                attemptNumber = lastAttempt['attemptNumber'] ?? attempts.length;
                              }
                              // If specific logic dictates attemptNumber is count + 1 for new, but here we resume existing
                            }
                          }

                          String cardTitle = canResume ? 'Resume Assessment' : 'Career Assessment';
                          String cardDesc = canResume 
                              ? 'Continue where you left off.' 
                              : 'Start navigating your IT future.';
                          String btnText = canResume ? 'Resume' : 'Get Started';

                          return ScaleTransition(
                            scale: _pulseAnimation,
                            child: GestureDetector(
                              onTap: () {
                                if (canResume && pendingAttempt != null) {
                                  final testId = pendingAttempt['testId'];
                                  _resumeAssessment(context, testId, attemptNumber);
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AssessmentScreen(),
                                    ),
                                  );
                                }
                              },
                              onTapDown: (_) =>
                                  setState(() => _isAssessmentPressed = true),
                              onTapUp: (_) =>
                                  setState(() => _isAssessmentPressed = false),
                              onTapCancel: () =>
                                  setState(() => _isAssessmentPressed = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [geekGreen, geekDarkGreen],
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  border: _isAssessmentPressed
                                      ? Border.all(color: Colors.white, width: 2)
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: geekGreen.withOpacity(
                                          _isAssessmentPressed ? 0.5 : 0.35),
                                      blurRadius: _isAssessmentPressed ? 20 : 15,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                transform: _isAssessmentPressed
                                    ? Matrix4.identity().scaled(0.98)
                                    : Matrix4.identity(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cardTitle,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      cardDesc,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Text(
                                            btnText,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.arrow_forward,
                                            color: Colors.black,
                                            size: 18,
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
                      ),

                      const SizedBox(height: 18),

                      // Carousel slider
                      _buildCarousel(),

                      const SizedBox(height: 12),

                      // Carousel indicators
                      _buildCarouselIndicators(),

                      const SizedBox(height: 24),

                      // Recent Report Section
                      const Text(
                        'Recent Report',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: geekGreen,
                          letterSpacing: 0.3,
                        ),
                      ),

                      const SizedBox(height: 14),

                      const RecentReportWidget(),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      case 1:
        return const CareerRoadmapScreen();
      case 2:
        return const ReportHistoryScreen();
      case 3:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline, size: 60, color: geekGreen),
              const SizedBox(height: 20),
              const Text(
                'Profile Screen',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Hello, $userName!',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _navigateToProfile,
                style: ElevatedButton.styleFrom(backgroundColor: geekGreen),
                child: const Text('Go to Full Profile',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      default:
        return const Center(child: Text('Home Content'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _getContentForTab(_selectedIndex),
      bottomNavigationBar: SimpleBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTapDown: (_) => setState(() => _isAchievementPressed = true),
        onTapUp: (_) => setState(() => _isAchievementPressed = false),
        onTapCancel: () => setState(() => _isAchievementPressed = false),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: _isAchievementPressed ? Colors.white : color,
                width: 2.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(_isAchievementPressed ? 0.25 : 0.12),
                blurRadius: _isAchievementPressed ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          transform: _isAchievementPressed
              ? Matrix4.identity().scaled(0.98)
              : Matrix4.identity(),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    return SizedBox(
      height: 180,
      child: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _carouselIndex = index;
          });
        },
        children: [
          _buildCarouselCard(
            title: 'Career Assessment',
            description:
                'Complete three parts of the assessment to discover the IT career path that best matches your skills and background.',
            icon: Icons.explore,
            color: Colors.white,
          ),
          _buildCarouselCard(
            title: 'Skill Development',
            description:
                'Track your progress and unlock achievements as you learn new programming skills.',
            icon: Icons.trending_up,
            color: Colors.white,
          ),
          _buildCarouselCard(
            title: 'Career Resources',
            description:
                'Access curated learning materials and career guides tailored to your goals.',
            icon: Icons.library_books,
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
          // Robot animation - smaller size
          SizedBox(
            width: 140,
            height: 140,
            child: Lottie.asset(
              'assets/lottie/IQ-Practice.json',
              fit: BoxFit.contain,
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
}