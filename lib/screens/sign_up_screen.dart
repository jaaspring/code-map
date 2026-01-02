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

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _role = 'user';

  // Green color palette - BLACK THEME
  static const Color geekGreen = Color(0xFF4BC945);
  static const Color geekDarkGreen = Color(0xFF3AA036);

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

  // Award "app_open" badge on successful registration
  Future<void> _awardWelcomeBadge(String userId) async {
    try {
      final appOpenBadgeQuery = await _firestore
          .collection('badge_definitions')
          .where('trigger', isEqualTo: 'app_open')
          .limit(1)
          .get();

      if (appOpenBadgeQuery.docs.isNotEmpty) {
        final appOpenBadgeId = appOpenBadgeQuery.docs.first.id;
        await _firestore.collection('users').doc(userId).update({
          'badges': FieldValue.arrayUnion([appOpenBadgeId]),
        });
        print('✅ Awarded "Welcome Aboard" badge to new user');
      } else {
        print('⚠️ No "app_open" badge found in badge_definitions');
      }
    } catch (e) {
      print('❌ Error awarding Welcome badge: $e');
    }
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

      final userId = userCredential.user?.uid;

      // Initialize user document with badge fields
      await _firestore.collection('users').doc(userId).set({
        'uid': userId,
        'name': _nameController.text,
        'username': _usernameController.text,
        'email': _emailController.text,
        'role': _role,
        'profilePhotoUrl': null,
        'badges': [],
        'birthdate': null,
        'gender': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Award Welcome Aboard badge
      if (userId != null) {
        await _awardWelcomeBadge(userId);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Registration Successful! Welcome aboard! 🎉'),
          backgroundColor: geekGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomePage()),
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
      backgroundColor: Colors.black, // BLACK THEME
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
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
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const WelcomePage()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.arrow_back,
                                color: Colors.black, size: 20),
                          ),
                        ),
                      ),
                    ),
                    Image.asset(
                      'assets/icons/logo_only_white.png',
                      width: 50,
                      height: 50,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.code,
                          size: 50,
                          color: Colors.white,
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Title - BLACK THEME
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Create Your\nAccount',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: geekGreen,
                      height: 1.2,
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
                      color: geekGreen,
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
                      color: geekGreen,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: geekGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
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
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Sign In option - BLACK THEME
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already Have An Account? ",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const LoginScreen()),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: geekGreen,
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: focusNode.hasFocus
                  ? geekGreen
                  : error.isNotEmpty
                      ? Colors.red
                      : geekGreen.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: focusNode.hasFocus
                    ? geekGreen.withOpacity(0.2)
                    : Colors.black.withOpacity(0.05),
                blurRadius: focusNode.hasFocus ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 60,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  obscureText: obscureText,
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    prefixIcon: Icon(
                      icon,
                      color: focusNode.hasFocus ? geekGreen : Colors.grey,
                    ),
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                    suffixIcon: suffixIcon,
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