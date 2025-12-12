import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'welcome_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  String _emailError = '';
  String _passwordError = '';
  String _confirmPasswordError = '';
  String _nameError = '';
  String _usernameError = '';

  // Focus nodes for interactive highlighting
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmPasswordFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _backgroundController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _role = 'user';

  // GeeksforGeeks color palette - matching login
  static const Color gfgGreen = Color(0xFF2F8D46);
  static const Color gfgLightGreen = Color(0xFF4CAF50);
  static const Color gfgAccent = Color(0xFF66BB6A);
  static const Color gfgBackground = Color(0xFFE8F5E9);

  @override
  void initState() {
    super.initState();

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

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _nameFocus.dispose();
    _usernameFocus.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email);
  }

  bool _isValidPassword(String password) {
    return password.length >= 6;
  }

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
      _emailError = '';
      _passwordError = '';
      _confirmPasswordError = '';
      _nameError = '';
      _usernameError = '';
    });

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _usernameController.text.isEmpty) {
      setState(() {
        if (_emailController.text.isEmpty) _emailError = 'Email is required';
        if (_passwordController.text.isEmpty)
          _passwordError = 'Password is required';
        if (_confirmPasswordController.text.isEmpty)
          _confirmPasswordError = 'Confirm Password is required';
        if (_nameController.text.isEmpty) _nameError = 'Name is required';
        if (_usernameController.text.isEmpty)
          _usernameError = 'Username is required';
        _isLoading = false;
      });
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _passwordError = 'Passwords do not match';
        _confirmPasswordError = 'Passwords do not match';
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
        _passwordError = 'Password must be at least 6 characters long';
        _isLoading = false;
      });
      return;
    }

    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Initialize user document with badge fields
      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        'uid': userCredential.user?.uid,
        'name': _nameController.text,
        'username': _usernameController.text,
        'email': _emailController.text,
        'role': _role,
        'profilePhotoUrl': null, // Initialize as null
        'badges': {}, // Initialize empty badges map
        'badgeCount': 0, // Initialize badge count
        'birthdate': null, // Initialize birthdate as null
        'gender': null, // Initialize gender as null
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Registration Successful!'),
          backgroundColor: gfgGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WelcomePage()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'email-already-in-use') {
          _emailError = 'This email is already registered';
        } else if (e.code == 'weak-password') {
          _passwordError = 'Password is too weak';
        } else {
          _emailError = e.message ?? 'Something went wrong';
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
            // Animated gradient background
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

            // Floating bubbles - matching login screen
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

            // Main content
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
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
                                          builder: (context) => WelcomePage()),
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

                        // Title with gradient
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [gfgGreen, gfgLightGreen],
                            ).createShader(bounds),
                            child: const Text(
                              'Create Your\nAccount',
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
                        _buildTextField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          icon: Icons.email_outlined,
                          hintText: 'Enter Your Email',
                          error: _emailError,
                        ),

                        const SizedBox(height: 16),

                        // Name Field
                        _buildTextField(
                          controller: _nameController,
                          focusNode: _nameFocus,
                          icon: Icons.person_outline,
                          hintText: 'Enter Your Name',
                          error: _nameError,
                        ),

                        const SizedBox(height: 16),

                        // Username Field
                        _buildTextField(
                          controller: _usernameController,
                          focusNode: _usernameFocus,
                          icon: Icons.account_box_outlined,
                          hintText: 'Enter Your Username',
                          error: _usernameError,
                        ),

                        const SizedBox(height: 16),

                        // Password Field
                        _buildTextField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          icon: Icons.lock_outline,
                          hintText: 'Password',
                          error: _passwordError,
                          obscureText: !_isPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: gfgGreen,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Confirm Password Field
                        _buildTextField(
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocus,
                          icon: Icons.lock_outline,
                          hintText: 'Confirm Password',
                          error: _confirmPasswordError,
                          obscureText: !_isConfirmPasswordVisible,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: gfgGreen,
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible =
                                    !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Register Button
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isLoading ? null : _register,
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
                                          'Register',
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

                        // Sign In option
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Already Have An Account?",
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
                                      builder: (context) =>
                                          const LoginScreen()),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: gfgGreen,
                              ),
                              child: const Text(
                                'Sign In',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String hintText,
    required String error,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: error.isNotEmpty ? 80 : 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: focusNode.hasFocus
                  ? gfgGreen
                  : error.isNotEmpty
                      ? Colors.red
                      : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: focusNode.hasFocus
                    ? gfgGreen.withOpacity(0.2)
                    : Colors.black.withOpacity(0.05),
                blurRadius: focusNode.hasFocus ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    obscureText: obscureText,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      icon: Icon(
                        icon,
                        color: focusNode.hasFocus ? gfgGreen : Colors.grey,
                      ),
                      hintText: hintText,
                      hintStyle: const TextStyle(fontSize: 16),
                      suffixIcon: suffixIcon,
                    ),
                  ),
                ),
              ),
              if (error.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 8),
                    child: Text(
                      error,
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
    );
  }
}
