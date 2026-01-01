import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class BadgeFormDialog extends StatefulWidget {
  final String? badgeId;
  final Map<String, dynamic>? existingData;

  const BadgeFormDialog({Key? key, this.badgeId, this.existingData})
      : super(key: key);

  @override
  State<BadgeFormDialog> createState() => _BadgeFormDialogState();
}

class _BadgeFormDialogState extends State<BadgeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _orderController = TextEditingController();
  final _conditionValueController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedIcon = 'emoji_events';
  String _selectedColor = '#4BC945';
  String _selectedCategory = 'General';
  String _selectedTrigger = 'manual';
  String _selectedConditionType = 'always';
  String _conditionField = '';
  String _imageType = 'icon';
  File? _selectedImage;
  String? _existingImageUrl;
  bool _isUploading = false;

  static const Color geekGreen = Color(0xFF4BC945);

  final List<String> _triggers = [
    'manual',
    'app_open',
    'profile_update',
    'assessment_complete',
    'career_explore',
    'goal_set',
    'roadmap_create',
  ];

  final List<String> _conditionTypes = [
    'always',
    'exists',
    'count',
    'array_length',
  ];

  final List<String> _availableIcons = [
    'emoji_events',
    'waving_hand',
    'person_outline',
    'photo_camera',
    'badge',
    'explore',
    'psychology',
    'flag',
    'lightbulb_outline',
    'checklist',
    'route',
    'search',
    'people_outline',
    'thumb_up',
  ];

  final List<String> _availableColors = [
    '#4BC945',
    '#2196F3',
    '#9C27B0',
    '#E91E63',
    '#FF9800',
    '#FFC107',
    '#4CAF50',
    '#00BCD4',
    '#FF5722',
    '#607D8B',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      _nameController.text = widget.existingData!['name'] ?? '';
      _descController.text = widget.existingData!['description'] ?? '';
      _orderController.text = widget.existingData!['order']?.toString() ?? '0';
      _selectedIcon = widget.existingData!['iconName'] ?? 'emoji_events';
      _selectedColor = widget.existingData!['colorHex'] ?? '#4BC945';
      _selectedCategory = widget.existingData!['category'] ?? 'General';
      _selectedTrigger = widget.existingData!['trigger'] ?? 'manual';
      _selectedConditionType =
          widget.existingData!['conditionType'] ?? 'always';
      _conditionField = widget.existingData!['conditionField'] ?? '';
      _conditionValueController.text =
          widget.existingData!['conditionValue']?.toString() ?? '';
      _existingImageUrl = widget.existingData!['imageUrl'];
      _imageType = _existingImageUrl != null ? 'image' : 'icon';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _orderController.dispose();
    _conditionValueController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _imageType = 'image';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return _existingImageUrl;

    try {
      setState(() => _isUploading = true);

      final fileName =
          'badge_${DateTime.now().millisecondsSinceEpoch}_${_nameController.text.replaceAll(' ', '_')}.jpg';
      final storageRef =
          FirebaseStorage.instance.ref().child('badges').child(fileName);

      await storageRef.putFile(_selectedImage!);
      final downloadUrl = await storageRef.getDownloadURL();

      setState(() => _isUploading = false);
      return downloadUrl;
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
      return null;
    }
  }

  IconData _getIcon(String name) {
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
    return iconMap[name] ?? Icons.emoji_events;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: geekGreen.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.badgeId == null ? 'Create Badge' : 'Edit Badge',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Image Type Selection
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text(
                          'Use Icon',
                          style: TextStyle(color: Colors.white),
                        ),
                        value: 'icon',
                        groupValue: _imageType,
                        onChanged: (v) => setState(() => _imageType = v!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: geekGreen,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text(
                          'Upload Image',
                          style: TextStyle(color: Colors.white),
                        ),
                        value: 'image',
                        groupValue: _imageType,
                        onChanged: (v) => setState(() => _imageType = v!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: geekGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Icon or Image Selector
                if (_imageType == 'icon') ...[
                  const Text(
                    'Select Icon:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableIcons.map((iconName) {
                      final isSelected = _selectedIcon == iconName;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = iconName),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? geekGreen.withOpacity(0.2)
                                : Colors.grey[800],
                            border: Border.all(
                              color: isSelected
                                  ? geekGreen
                                  : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getIcon(iconName),
                            color: isSelected
                                ? geekGreen
                                : Colors.grey[400],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_selectedImage!,
                                  fit: BoxFit.cover),
                            )
                          : _existingImageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(_existingImageUrl!,
                                      fit: BoxFit.cover),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate,
                                        size: 48, color: Colors.grey[500]),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to upload image',
                                      style: TextStyle(color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Color Selection
                const Text(
                  'Badge Color:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableColors.map((colorHex) {
                    final color =
                        Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                    final isSelected = _selectedColor == colorHex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = colorHex),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.grey[700]!,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Form Fields
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Badge Name *',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: geekGreen, width: 2),
                    ),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Description *',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: geekGreen, width: 2),
                    ),
                  ),
                  maxLines: 2,
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Category',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: geekGreen, width: 2),
                    ),
                  ),
                  items: [
                    'General',
                    'Profile',
                    'Career',
                    'Learning',
                    'Achievement'
                  ]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v!),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedTrigger,
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Trigger',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: geekGreen, width: 2),
                    ),
                  ),
                  items: _triggers
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedTrigger = v!),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedConditionType,
                  dropdownColor: Colors.grey[800],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Condition Type',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: geekGreen, width: 2),
                    ),
                  ),
                  items: _conditionTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedConditionType = v!),
                ),

                if (_selectedConditionType != 'always') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _conditionField,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Condition Field (e.g., name, careersExplored)',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: geekGreen, width: 2),
                      ),
                    ),
                    onChanged: (v) => _conditionField = v,
                  ),
                ],

                if (_selectedConditionType == 'count' ||
                    _selectedConditionType == 'array_length') ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _conditionValueController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Condition Value',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: geekGreen, width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],

                const SizedBox(height: 16),

                TextFormField(
                  controller: _orderController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Display Order',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[700]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: geekGreen, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed:
                            _isUploading ? null : () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: _isUploading ? Colors.grey : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _saveBadge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: geekGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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
    );
  }

  Future<void> _saveBadge() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      String? imageUrl;
      if (_imageType == 'image') {
        imageUrl = await _uploadImage();
        if (imageUrl == null && _selectedImage != null) {
          return;
        }
      }

      final data = {
        'name': _nameController.text,
        'description': _descController.text,
        'colorHex': _selectedColor,
        'category': _selectedCategory,
        'trigger': _selectedTrigger,
        'conditionType': _selectedConditionType,
        'conditionField': _conditionField.isNotEmpty ? _conditionField : null,
        'conditionValue': _conditionValueController.text.isNotEmpty
            ? int.tryParse(_conditionValueController.text)
            : null,
        'order': int.tryParse(_orderController.text) ?? 0,
        'isActive': true,
      };

      if (_imageType == 'icon') {
        data['iconName'] = _selectedIcon;
        data['imageUrl'] = null;
      } else {
        data['imageUrl'] = imageUrl;
        data['iconName'] = null;
      }

      if (widget.badgeId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('badge_definitions')
            .add(data);
      } else {
        if (_imageType == 'image' &&
            _existingImageUrl != null &&
            imageUrl != _existingImageUrl) {
          try {
            await FirebaseStorage.instance
                .refFromURL(_existingImageUrl!)
                .delete();
          } catch (e) {
            print('Error deleting old image: $e');
          }
        }

        await FirebaseFirestore.instance
            .collection('badge_definitions')
            .doc(widget.badgeId)
            .update(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Badge saved successfully!'),
            backgroundColor: geekGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}