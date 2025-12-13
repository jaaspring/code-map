import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user/home_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/welcome_page.dart';
import '../screens/sign_up_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _emailError = '';
  String _passwordError = '';

  // Focus nodes for interactive highlighting
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _backgroundController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // GeeksforGeeks color palette
  static const Color gfgGreen = Color(0xFF2F8D46);
  static const Color gfgLightGreen = Color(0xFF4CAF50);
  static const Color gfgAccent = Color(0xFF66BB6A);
  static const Color gfgBackground = Color(0xFFE8F5E9); // Light green tint

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Start animations
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegExp =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegExp.hasMatch(email);
  }

  bool _isValidPassword(String password) {
    return password.length >= 6;
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _emailError = '';
      _passwordError = '';
    });

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        if (_emailController.text.isEmpty) _emailError = 'Email is required';
        if (_passwordController.text.isEmpty)
          _passwordError = 'Password is required';
        _isLoading = false;
      });
      return;
    }

    if (!_isValidEmail(_emailController.text)) {
      setState(() {
        _emailError = 'Please enter a valid email address';
        _isLoading = false;
      });
      return;
    }

    if (!_isValidPassword(_passwordController.text)) {
      setState(() {
        _passwordError = 'Please enter a valid password';
        _isLoading = false;
      });
      return;
    }

    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      String uid = userCredential.user?.uid ?? '';
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();

      if (userDoc.exists) {
        String role = userDoc['role'] ?? 'user';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Login Successful!'),
            backgroundColor: gfgGreen,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminDashboard()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not found in Firestore')),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found' ||
            e.code == 'wrong-password' ||
            e.code == 'invalid-email' ||
            e.code == 'invalid-credential') {
          _emailError = 'Your email or password is incorrect';
          _passwordError = 'Your email or password is incorrect';
        } else if (e.code == 'too-many-requests') {
          _emailError = 'Too many failed attempts. Please try again later.';
          _passwordError = 'Too many failed attempts. Please try again later.';
        } else {
          _emailError = e.message ?? 'Something went wrong';
          _passwordError = e.message ?? 'Something went wrong';
        }
      });
    } catch (e) {
      setState(() {
        _emailError = 'Something went wrong. Please try again.';
        _passwordError = 'Something went wrong. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Animated gradient background with wave effect
            AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(
                        -1.5 + (_backgroundController.value * 1.0),
                        -1.0 + (_backgroundController.value * 0.8),
                      ),
                      end: Alignment(
                        1.5 - (_backgroundController.value * 1.0),
                        1.0 - (_backgroundController.value * 0.8),
                      ),
                      colors: [
                        gfgBackground,
                        Colors.white,
                        gfgLightGreen.withOpacity(0.2),
                        gfgBackground,
                      ],
                    ),
                  ),
                );
              },
            ),

            // Large moving bubble - Top Right (above logo area)
            Positioned(
              top: -100 + (_backgroundController.value * 50),
              right: -80 + (_backgroundController.value * 60),
              child: AnimatedBuilder(
                animation: _backgroundController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.2 + (_backgroundController.value * 0.4),
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            gfgAccent.withOpacity(0.2),
                            gfgAccent.withOpacity(0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Large moving bubble - Bottom area (below buttons)
            Positioned(
              bottom: -150 - (_backgroundController.value * 50),
              left: -120 + (_backgroundController.value * 80),
              child: AnimatedBuilder(
                animation: _backgroundController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.4 + ((1 - _backgroundController.value) * 0.3),
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            gfgLightGreen.withOpacity(0.18),
                            gfgLightGreen.withOpacity(0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Medium bubble - Far Right (outside content area)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.5 +
                  (_backgroundController.value * 100),
              right: -100 + (_backgroundController.value * 40),
              child: AnimatedBuilder(
                animation: _backgroundController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_backgroundController.value * 0.5),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            gfgGreen.withOpacity(0.15),
                            gfgGreen.withOpacity(0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Small floating dot - Top Left corner
            Positioned(
              top: 40 + (_backgroundController.value * 60),
              left: -20 + (_backgroundController.value * 20),
              child: AnimatedBuilder(
                animation: _backgroundController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.8 + (_backgroundController.value * 0.6),
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: gfgAccent.withOpacity(0.2),
                        boxShadow: [
                          BoxShadow(
                            color: gfgAccent.withOpacity(0.25),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Small floating dot - Bottom Right corner
            Positioned(
              bottom: 50 - (_backgroundController.value * 80),
              right: -30 + (_backgroundController.value * 30),
              child: AnimatedBuilder(
                animation: _backgroundController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 0.9 + ((1 - _backgroundController.value) * 0.6),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: gfgLightGreen.withOpacity(0.18),
                        boxShadow: [
                          BoxShadow(
                            color: gfgLightGreen.withOpacity(0.2),
                            blurRadius: 25,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Tiny dot - Left edge
            Positioned(
              top: MediaQuery.of(context).size.height * 0.65 +
                  (_backgroundController.value * 40),
              left: -25 - (_backgroundController.value * 5),
              child: AnimatedBuilder(
                animation: _backgroundController,
                builder: (context, child) {
                  return Opacity(
                    opacity: 0.3 + (_backgroundController.value * 0.4),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            gfgGreen.withOpacity(0.25),
                            gfgGreen.withOpacity(0.08),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Glowing dot - Top center area
            Positioned(
              top: 20 + (_backgroundController.value * 40),
              right: MediaQuery.of(context).size.width * 0.3 -
                  (_backgroundController.value * 30),
              child: AnimatedBuilder(
                animation: _backgroundController,
                builder: (context, child) {
                  return Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.5),
                      boxShadow: [
                        BoxShadow(
                          color: gfgAccent.withOpacity(0.4),
                          blurRadius: 25,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Main content
            SingleChildScrollView(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // Back button and logo
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(25),
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => WelcomePage(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(25),
                                      boxShadow: [
                                        BoxShadow(
                                          color: gfgGreen.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.arrow_back,
                                        color: gfgGreen),
                                  ),
                                ),
                              ),
                            ),
                            // Logo without border - just shadow
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: gfgGreen.withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/logo_only.png',
                                width: 30,
                                height: 30,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // Login Title with gradient
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [gfgGreen, gfgLightGreen],
                            ).createShader(bounds),
                            child: const Text(
                              'Login Your\nAccount',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Email Field
                        AnimatedBuilder(
                          animation: _emailFocus,
                          builder: (context, child) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: _emailError.isNotEmpty ? 80 : 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _emailFocus.hasFocus
                                      ? gfgGreen
                                      : _emailError.isNotEmpty
                                          ? Colors.red
                                          : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _emailFocus.hasFocus
                                        ? gfgGreen.withOpacity(0.2)
                                        : Colors.black.withOpacity(0.05),
                                    blurRadius: _emailFocus.hasFocus ? 12 : 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: TextField(
                                        controller: _emailController,
                                        focusNode: _emailFocus,
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          icon: Icon(
                                            Icons.email_outlined,
                                            color: _emailFocus.hasFocus
                                                ? gfgGreen
                                                : Colors.grey,
                                          ),
                                          hintText: 'Enter Your Email',
                                          hintStyle:
                                              const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_emailError.isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            left: 40, bottom: 8),
                                        child: Text(
                                          _emailError,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // Password Field
                        AnimatedBuilder(
                          animation: _passwordFocus,
                          builder: (context, child) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: _passwordError.isNotEmpty ? 80 : 60,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _passwordFocus.hasFocus
                                      ? gfgGreen
                                      : _passwordError.isNotEmpty
                                          ? Colors.red
                                          : Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _passwordFocus.hasFocus
                                        ? gfgGreen.withOpacity(0.2)
                                        : Colors.black.withOpacity(0.05),
                                    blurRadius:
                                        _passwordFocus.hasFocus ? 12 : 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: TextField(
                                        controller: _passwordController,
                                        focusNode: _passwordFocus,
                                        obscureText: _obscurePassword,
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          icon: Icon(
                                            Icons.lock_outline,
                                            color: _passwordFocus.hasFocus
                                                ? gfgGreen
                                                : Colors.grey,
                                          ),
                                          hintText: 'Password',
                                          hintStyle:
                                              const TextStyle(fontSize: 16),
                                          suffixIcon: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                              onTap: () {
                                                setState(() {
                                                  _obscurePassword =
                                                      !_obscurePassword;
                                                });
                                              },
                                              child: Icon(
                                                _obscurePassword
                                                    ? Icons
                                                        .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                color: gfgGreen,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_passwordError.isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                            left: 40, bottom: 8),
                                        child: Text(
                                          _passwordError,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 8),

                        // Forget Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: gfgGreen,
                            ),
                            child: const Text(
                              'Forget Password?',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isLoading ? null : _login,
                              borderRadius: BorderRadius.circular(12),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [gfgGreen, gfgLightGreen],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: gfgGreen.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 3,
                                          ),
                                        )
                                      : const Text(
                                          'Log In',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Sign up option
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Create New Account?",
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 15,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => SignUpPage()),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: gfgGreen,
                              ),
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
