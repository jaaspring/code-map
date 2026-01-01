import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/education_skills_data.dart';

class EditInformationScreen extends StatefulWidget {
  const EditInformationScreen({Key? key}) : super(key: key);

  @override
  State<EditInformationScreen> createState() => _EditInformationScreenState();
}

class _EditInformationScreenState extends State<EditInformationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _birthdateController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _careerGoalsController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _birthdateFocus = FocusNode();
  final FocusNode _careerGoalsFocus = FocusNode();

  bool _isLoading = false;
  File? _imageFile;
  String? _existingImageBase64;

  String _selectedGender = 'Male';
  List<String> _selectedSkills = [];
  final ImagePicker _picker = ImagePicker();

  static const Color geekGreen = Color(0xFF4BC945);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? '';

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        setState(() {
          _nameController.text = data?['name'] ?? '';
          _usernameController.text = data?['username'] ?? '';
          _birthdateController.text = data?['birthdate'] ?? '';
          _selectedGender = data?['gender'] ?? 'Male';
          _educationController.text = data?['education'] ?? '';
          if (data?['skills'] != null && data!['skills'].isNotEmpty) {
            _selectedSkills = (data['skills'] as String).split(', ');
          }
          _careerGoalsController.text = data?['careerGoals'] ?? '';
          _existingImageBase64 = data?['photoUrl'];
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        String? base64Image;
        if (_imageFile != null) {
          base64Image = await _encodeImageToBase64(_imageFile!);
        } else {
          base64Image = _existingImageBase64;
        }

        await _firestore.collection('users').doc(user.uid).update({
          'name': _nameController.text,
          'username': _usernameController.text,
          'photoUrl': base64Image,
          'birthdate': _birthdateController.text,
          'gender': _selectedGender,
          'education': _educationController.text,
          'skills': _selectedSkills.join(', '),
          'careerGoals': _careerGoalsController.text,
        });

        await _awardProfileBadges(user.uid, base64Image);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: geekGreen,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _awardProfileBadges(String userId, String? photoUrl) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>;
      final badges = List<String>.from(userData['badges'] ?? []);

      final profileBadgesQuery = await _firestore
          .collection('badge_definitions')
          .where('trigger', isEqualTo: 'profile_update')
          .get();

      for (var badgeDoc in profileBadgesQuery.docs) {
        final badgeData = badgeDoc.data();
        final conditionField = badgeData['conditionField'];
        final badgeId = badgeDoc.id;

        if (!badges.contains(badgeId)) {
          bool shouldAward = false;

          if (conditionField == 'name' && _nameController.text.isNotEmpty) {
            shouldAward = true;
          } else if (conditionField == 'profileImageUrl' &&
              photoUrl != null &&
              photoUrl.isNotEmpty) {
            shouldAward = true;
          }

          if (shouldAward) {
            badges.add(badgeId);
          }
        }
      }

      await _firestore.collection('users').doc(userId).update({
        'badges': badges,
      });
    } catch (e) {
      // Silent error
    }
  }

  Future<String> _encodeImageToBase64(File image) async {
    final bytes = await image.readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectBirthdate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: geekGreen,
              onPrimary: Colors.white,
              surface: Colors.grey[900]!,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) {
      setState(() {
        _birthdateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
      });
    }
  }

  void _showEducationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: geekGreen,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Education',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: EducationSkillsData.educationOptions.length,
                  itemBuilder: (context, index) {
                    final education =
                        EducationSkillsData.educationOptions[index];
                    final isSelected = _educationController.text == education;
                    return ListTile(
                      leading: Icon(
                        Icons.school_outlined,
                        color: isSelected ? geekGreen : Colors.grey,
                      ),
                      title: Text(
                        education,
                        style: TextStyle(
                          color: isSelected ? geekGreen : Colors.black,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: geekGreen)
                          : null,
                      onTap: () {
                        setState(() {
                          _educationController.text = education;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSkillsPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: geekGreen,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Skills',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedSkills.clear();
                                });
                                setModalState(() {});
                              },
                              child: const Text(
                                'Clear',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.check, color: Colors.white),
                              onPressed: () {
                                setState(() {});
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_selectedSkills.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedSkills.map((skill) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: geekGreen,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              skill,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: EducationSkillsData.skillsOptions.length,
                      itemBuilder: (context, index) {
                        final skill = EducationSkillsData.skillsOptions[index];
                        final isSelected = _selectedSkills.contains(skill);
                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(
                            skill,
                            style: TextStyle(
                              color: isSelected ? geekGreen : Colors.black,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          activeColor: geekGreen,
                          onChanged: (bool? value) {
                            setModalState(() {
                              if (value == true) {
                                _selectedSkills.add(skill);
                              } else {
                                _selectedSkills.remove(skill);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button and Logo
              Stack(
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
                    'assets/logo_only_white.png',
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

              // Title
              const Text(
                'Edit Your\nProfile',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: geekGreen,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              // Description
              const Text(
                'Update your personal information and preferences.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 30),

              // Profile Photo Section
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
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
                          child: _imageFile != null
                              ? Image.file(_imageFile!, fit: BoxFit.cover)
                              : _existingImageBase64 != null
                                  ? Image.memory(
                                      base64Decode(_existingImageBase64!),
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(Icons.person,
                                      size: 60, color: Colors.grey),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: geekGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Full Name
              _buildInputField(
                controller: _nameController,
                focusNode: _nameFocus,
                label: 'Full Name',
                icon: Icons.person_outline,
              ),

              const SizedBox(height: 16),

              // Username
              _buildInputField(
                controller: _usernameController,
                focusNode: _usernameFocus,
                label: 'Username',
                icon: Icons.account_box_outlined,
              ),

              const SizedBox(height: 16),

              // Email (disabled)
              _buildInputField(
                controller: _emailController,
                focusNode: _emailFocus,
                label: 'Email',
                icon: Icons.email_outlined,
                enabled: false,
              ),

              const SizedBox(height: 16),

              // Birthdate
              GestureDetector(
                onTap: _selectBirthdate,
                child: AbsorbPointer(
                  child: _buildInputField(
                    controller: _birthdateController,
                    focusNode: _birthdateFocus,
                    label: 'Birthdate',
                    icon: Icons.calendar_today_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Gender Dropdown
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: geekGreen.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedGender,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    icon: const Icon(Icons.arrow_drop_down, color: geekGreen),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                    items: ['Male', 'Female', 'Others']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Row(
                          children: [
                            Icon(Icons.person, color: Colors.grey, size: 20),
                            const SizedBox(width: 16),
                            Text(value),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedGender = newValue!;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Education Dropdown
              GestureDetector(
                onTap: () => _showEducationPicker(),
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: geekGreen.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.school_outlined, color: Colors.grey),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _educationController.text.isEmpty
                              ? 'Education'
                              : _educationController.text,
                          style: TextStyle(
                            fontSize: 16,
                            color: _educationController.text.isEmpty
                                ? Colors.grey.shade600
                                : Colors.black,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: geekGreen),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Skills Selection
              GestureDetector(
                onTap: () => _showSkillsPicker(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: geekGreen.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.workspace_premium_outlined,
                          color: Colors.grey),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _selectedSkills.isEmpty
                            ? Text(
                                'Select Skills',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedSkills.map((skill) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: geekGreen.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: geekGreen,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      skill,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                      Icon(Icons.arrow_drop_down, color: geekGreen),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Career Goals
              _buildInputField(
                controller: _careerGoalsController,
                focusNode: _careerGoalsFocus,
                label: 'Career Goals',
                icon: Icons.flag_outlined,
                maxLines: 3,
              ),

              const SizedBox(height: 30),

              // Update Profile Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
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
                          'Update Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    bool enabled = true,
    int maxLines = 1,
  }) {
    return AnimatedBuilder(
      animation: focusNode,
      builder: (context, child) {
        return Container(
          height: maxLines > 1 ? null : 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: !enabled
                  ? Colors.grey.shade400
                  : focusNode.hasFocus
                      ? geekGreen
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
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled
                    ? (focusNode.hasFocus ? geekGreen : Colors.grey)
                    : Colors.grey.shade500,
                size: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  maxLines: maxLines,
                  style: TextStyle(
                    fontSize: 16,
                    color: enabled ? Colors.black : Colors.grey.shade600,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: maxLines > 1 ? 18 : 18,
                    ),
                    hintText: label,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
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

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _birthdateController.dispose();
    _educationController.dispose();
    _careerGoalsController.dispose();
    _nameFocus.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _birthdateFocus.dispose();
    _careerGoalsFocus.dispose();
    super.dispose();
  }
}
