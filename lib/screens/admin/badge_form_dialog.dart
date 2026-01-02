import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
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

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _descFocus = FocusNode();
  final FocusNode _orderFocus = FocusNode();
  final FocusNode _conditionValueFocus = FocusNode();
  final FocusNode _conditionFieldFocus = FocusNode();

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
  static const Color geekLightGreen = Color(0xFF81D67C);

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
    
    _nameFocus.dispose();
    _descFocus.dispose();
    _orderFocus.dispose();
    _conditionValueFocus.dispose();
    _conditionFieldFocus.dispose();
    
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
          SnackBar(
            content: Text('Error picking image: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<String?> _encodeImageToBase64(File image) async {
    try {
      final bytes = await image.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error encoding image: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _existingImageUrl != null || _selectedImage != null
                              ? geekGreen
                              : geekGreen.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(_selectedImage!,
                                  fit: BoxFit.cover),
                            )
                          : _existingImageUrl != null && _existingImageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.memory(
                                      base64Decode(_existingImageUrl!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.broken_image,
                                              size: 48, color: Colors.red)),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_photo_alternate,
                                        size: 48, color: geekGreen),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to upload image',
                                      style: TextStyle(color: Colors.grey.shade600),
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

                _buildStyledField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  hintText: 'Badge Name *',
                  icon: Icons.badge_outlined,
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                _buildStyledField(
                  controller: _descController,
                  focusNode: _descFocus,
                  hintText: 'Description *',
                  icon: Icons.description_outlined,
                  maxLines: 2,
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black),
                  decoration: _getInputDecoration(
                    hintText: 'Category',
                    icon: Icons.category_outlined,
                  ),
                  items: [
                    'General',
                    'Profile',
                    'Career',
                    'Assessment',
                    'Achievement'
                  ]
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v!),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedTrigger,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black),
                  decoration: _getInputDecoration(
                    hintText: 'Trigger',
                    icon: Icons.bolt_outlined,
                  ),
                  items: _triggers
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedTrigger = v!),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedConditionType,
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: Colors.black),
                  decoration: _getInputDecoration(
                    hintText: 'Condition Type',
                    icon: Icons.rule_outlined,
                  ),
                  items: _conditionTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedConditionType = v!),
                ),
                const SizedBox(height: 16),

                if (_selectedConditionType != 'always') ...[
                  _buildStyledField(
                    controller: null,
                    focusNode: _conditionFieldFocus,
                    hintText: 'Condition Field',
                    icon: Icons.code_outlined,
                    initialValue: _conditionField,
                    onChanged: (v) => _conditionField = v,
                  ),
                  const SizedBox(height: 16),
                ],

                if (_selectedConditionType == 'count' ||
                    _selectedConditionType == 'array_length') ...[
                  _buildStyledField(
                    controller: _conditionValueController,
                    focusNode: _conditionValueFocus,
                    hintText: 'Condition Value',
                    icon: Icons.numbers_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                ],

                _buildStyledField(
                  controller: _orderController,
                  focusNode: _orderFocus,
                  hintText: 'Display Order',
                  icon: Icons.sort_outlined,
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 32),


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
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 0,
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 18,
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

    setState(() => _isUploading = true);

    try {
      String? base64Image;
      if (_imageType == 'image') {
        if (_selectedImage != null) {
          base64Image = await _encodeImageToBase64(_selectedImage!);
          if (base64Image == null) {
            setState(() => _isUploading = false);
            return;
          }
        } else {
          base64Image = _existingImageUrl;
        }
      }

      final data = {
        'name': _nameController.text,
        'description': _descController.text,
        'colorHex': _selectedColor,
        'category': _selectedCategory,
        'trigger': _selectedTrigger,
        'conditionType': _selectedConditionType,
        'conditionField': _conditionField.trim().isEmpty ? null : _conditionField.trim(),
        'conditionValue': (_selectedConditionType == 'count' ||
                _selectedConditionType == 'array_length')
            ? int.tryParse(_conditionValueController.text)
            : null,
        'order': int.tryParse(_orderController.text) ?? 0,
        'isActive': true,
      };

      if (_imageType == 'icon') {
        data['iconName'] = _selectedIcon;
      } else {
        data['imageUrl'] = base64Image;
      }

      if (widget.badgeId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('badge_definitions')
            .add(data);
      } else {
        // Only for updates: ensure previous fields are cleaned up
        if (_imageType == 'icon') {
          data['imageUrl'] = FieldValue.delete();
        } else {
          data['iconName'] = FieldValue.delete();
        }
        
        await FirebaseFirestore.instance
            .collection('badge_definitions')
            .doc(widget.badgeId)
            .update(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Badge saved successfully!'),
            backgroundColor: geekGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        
        String errorMessage = 'Error: $e';
        if (e.toString().contains('UNAVAILABLE') || e.toString().contains('host')) {
          errorMessage = 'Network error: Please check your internet connection and try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _buildStyledField({
    required TextEditingController? controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData icon,
    int maxLines = 1,
    String? initialValue,
    TextInputType keyboardType = TextInputType.text,
    Function(String)? onChanged,
    String? Function(String?)? validator,
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
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            initialValue: initialValue,
            keyboardType: keyboardType,
            onChanged: onChanged,
            validator: validator,
            maxLines: maxLines,
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
            ),
          ),
        );
      },
    );
  }

  InputDecoration _getInputDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      prefixIcon: Icon(
        icon,
        color: Colors.grey,
      ),
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 16,
      ),
    );
  }
}