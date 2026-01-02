import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'badge_form_dialog.dart';

class AdminBadgeCreatorScreen extends StatefulWidget {
  const AdminBadgeCreatorScreen({Key? key}) : super(key: key);

  @override
  State<AdminBadgeCreatorScreen> createState() =>
      _AdminBadgeCreatorScreenState();
}

class _AdminBadgeCreatorScreenState extends State<AdminBadgeCreatorScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  
  static const Color geekGreen = Color(0xFF4BC945);
  
  String _searchQuery = '';
  String _sortBy = 'order';
  bool _showSortMenu = false;

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

  Stream<QuerySnapshot> _getBadgesStream() {
    Query query = _firestore.collection('badge_definitions');
    
    if (_sortBy == 'order') {
      query = query.orderBy('order');
    } else if (_sortBy == 'newest') {
      query = query.orderBy('createdAt', descending: true);
    } else if (_sortBy == 'oldest') {
      query = query.orderBy('createdAt');
    }
    
    return query.snapshots();
  }

  List<DocumentSnapshot> _sortBadges(List<DocumentSnapshot> badges) {
    List<DocumentSnapshot> sortedBadges = List.from(badges);
    
    if (_searchQuery.isNotEmpty) {
      sortedBadges = sortedBadges.where((badge) {
        final data = badge.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final desc = (data['description'] ?? '').toString().toLowerCase();
        final searchLower = _searchQuery.toLowerCase();
        return name.contains(searchLower) || desc.contains(searchLower);
      }).toList();
    }
    
    switch (_sortBy) {
      case 'name_asc':
        sortedBadges.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aName = (aData['name'] ?? '').toString().toLowerCase();
          final bName = (bData['name'] ?? '').toString().toLowerCase();
          return aName.compareTo(bName);
        });
        break;
      case 'name_desc':
        sortedBadges.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aName = (aData['name'] ?? '').toString().toLowerCase();
          final bName = (bData['name'] ?? '').toString().toLowerCase();
          return bName.compareTo(aName);
        });
        break;
    }
    
    return sortedBadges;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Stack(
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
                  Image.asset(
                    'assets/icons/logo_only_white.png',
                    width: 50,
                    height: 50,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.emoji_events,
                        size: 50,
                        color: Colors.white,
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Add Button
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => _showBadgeForm(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: geekGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage Badges',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: geekGreen,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create and manage achievement badges.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Search Bar with Sort
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _searchFocus.hasFocus
                                  ? geekGreen
                                  : Colors.grey[800]!,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, color: Colors.grey[600]),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocus,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintText: 'Search badges...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value;
                                      _showSortMenu = false;
                                    });
                                  },
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                  child: Icon(
                                    Icons.clear,
                                    color: Colors.grey[600],
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showSortMenu = !_showSortMenu;
                          });
                        },
                        child: Container(
                          height: 60,
                          width: 60,
                          decoration: BoxDecoration(
                            color: _showSortMenu ? geekGreen : Colors.grey[900],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _showSortMenu ? geekGreen : Colors.grey[800]!,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.filter_list,
                            color: _showSortMenu ? Colors.white : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  if (_showSortMenu)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey[800]!,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildSortOption('Display Order', 'order'),
                          const Divider(height: 1, color: Colors.grey),
                          _buildSortOption('Newest First', 'newest'),
                          const Divider(height: 1, color: Colors.grey),
                          _buildSortOption('Oldest First', 'oldest'),
                          const Divider(height: 1, color: Colors.grey),
                          _buildSortOption('Name (A-Z)', 'name_asc'),
                          const Divider(height: 1, color: Colors.grey),
                          _buildSortOption('Name (Z-A)', 'name_desc'),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Badges List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getBadgesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: geekGreen,
                        strokeWidth: 3,
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.emoji_events,
                            size: 80,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No badges yet',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + to create your first badge',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final badges = _sortBadges(snapshot.data!.docs);

                  if (badges.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 80,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No badges found',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: badges.length,
                    itemBuilder: (context, index) {
                      final badge = badges[index];
                      final data = badge.data() as Map<String, dynamic>;
                      return _buildBadgeCard(badge.id, data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value) {
    final isSelected = _sortBy == value;
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          color: isSelected ? geekGreen : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: geekGreen, size: 20)
          : null,
      onTap: () {
        setState(() {
          _sortBy = value;
          _showSortMenu = false;
        });
      },
    );
  }

  Widget _buildBadgeCard(String badgeId, Map<String, dynamic> data) {
    final isActive = data['isActive'] ?? true;
    final color = Color(
        int.parse((data['colorHex'] ?? '#4BC945').replaceFirst('#', '0xFF')));
    final imageUrl = data['imageUrl'] as String?;
    final iconName = data['iconName'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? geekGreen.withOpacity(0.3) : Colors.red.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _buildBadgeImage(imageUrl, iconName, color),
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['name'] ?? 'Unnamed Badge',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    if (!isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Inactive',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data['description'] ?? '',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildInfoChip(
                      data['trigger'] ?? 'manual',
                      Icons.flash_on,
                    ),
                    _buildInfoChip(
                      data['category'] ?? 'General',
                      Icons.category,
                    ),
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      _buildInfoChip('Custom Image', Icons.image),
                    if (iconName != null && iconName.isNotEmpty)
                      _buildInfoChip('Icon', Icons.interests),
                  ],
                ),
              ],
            ),
          ),

          Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _showBadgeForm(badgeId: badgeId, existingData: data),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: geekGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: geekGreen,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _toggleBadgeStatus(badgeId, !isActive),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isActive ? Icons.pause : Icons.play_arrow,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _deleteBadge(badgeId, data['imageUrl']),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeImage(String? imageUrl, String? iconName, Color color) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(imageUrl),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                _getIcon(iconName ?? 'emoji_events'),
                color: color,
                size: 32,
              ),
            );
          },
        );
      } catch (e) {
        // Fallback to icon if decoding fails
      }
    }
    
    return Center(
      child: Icon(
        _getIcon(iconName ?? 'emoji_events'),
        color: color,
        size: 32,
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }



  void _showBadgeForm({String? badgeId, Map<String, dynamic>? existingData}) {
    showDialog(
      context: context,
      builder: (context) => BadgeFormDialog(
        badgeId: badgeId,
        existingData: existingData,
      ),
    );
  }

  Future<void> _toggleBadgeStatus(String badgeId, bool isActive) async {
    await _firestore.collection('badge_definitions').doc(badgeId).update({
      'isActive': isActive,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Badge ${isActive ? 'activated' : 'deactivated'}'),
          backgroundColor: geekGreen,
        ),
      );
    }
  }

  Future<void> _deleteBadge(String badgeId, String? imageUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: geekGreen.withOpacity(0.3),
            width: 2,
          ),
        ),
        title: const Text(
          'Delete Badge?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: const Text(
          'This will permanently delete this badge definition. This action cannot be undone.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('badge_definitions').doc(badgeId).delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Badge deleted'),
            backgroundColor: geekGreen,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }
}