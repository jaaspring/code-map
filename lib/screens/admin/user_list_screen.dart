import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_details_screen.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  _UserListScreenState createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  String _searchQuery = '';
  List<String> _searchHistory = [];
  bool _showSearchHistory = false;
  String _sortBy = 'newest'; // newest, oldest, name_asc, name_desc
  bool _showSortMenu = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  static const Color geekGreen = Color(0xFF4BC945);

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _searchFocus.addListener(() {
      setState(() {
        _showSearchHistory = _searchFocus.hasFocus && _searchHistory.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    // Load search history from Firestore
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data?['searchHistory'] != null) {
          setState(() {
            _searchHistory = List<String>.from(data!['searchHistory']);
          });
        }
      }
    }
  }

  Future<void> _saveSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Remove duplicate and add to front
      _searchHistory.remove(query);
      _searchHistory.insert(0, query);
      
      // Keep only last 10 searches
      if (_searchHistory.length > 10) {
        _searchHistory = _searchHistory.sublist(0, 10);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
        'searchHistory': _searchHistory,
      }, SetOptions(merge: true));

      setState(() {});
    }
  }

  Future<void> _clearSearchHistory() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'searchHistory': [],
      });

      setState(() {
        _searchHistory.clear();
        _showSearchHistory = false;
      });
    }
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _searchController.text = query;
      _showSearchHistory = false;
      _showSortMenu = false;
    });
    _searchFocus.unfocus();
    _saveSearchHistory(query);
  }

  Stream<QuerySnapshot> _getSortedUsersStream() {
    Query query = FirebaseFirestore.instance.collection('users');
    
    if (_searchQuery.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: _searchQuery)
          .where('name', isLessThan: '$_searchQuery\uf8ff');
    }
    
    return query.snapshots();
  }

  List<QueryDocumentSnapshot> _sortUsers(List<QueryDocumentSnapshot> users) {
    List<QueryDocumentSnapshot> sortedUsers = List.from(users);
    
    switch (_sortBy) {
      case 'newest':
        sortedUsers.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = aData['createdAt'] as Timestamp?;
          final bDate = bData['createdAt'] as Timestamp?;
          if (aDate == null || bDate == null) return 0;
          return bDate.compareTo(aDate);
        });
        break;
      case 'oldest':
        sortedUsers.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDate = aData['createdAt'] as Timestamp?;
          final bDate = bData['createdAt'] as Timestamp?;
          if (aDate == null || bDate == null) return 0;
          return aDate.compareTo(bDate);
        });
        break;
      case 'name_asc':
        sortedUsers.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aName = (aData['name'] ?? '').toString().toLowerCase();
          final bName = (bData['name'] ?? '').toString().toLowerCase();
          return aName.compareTo(bName);
        });
        break;
      case 'name_desc':
        sortedUsers.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aName = (aData['name'] ?? '').toString().toLowerCase();
          final bName = (bData['name'] ?? '').toString().toLowerCase();
          return bName.compareTo(aName);
        });
        break;
    }
    
    return sortedUsers;
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

  // Function to delete a user (both Firestore and Firebase Authentication)
  Future<void> _deleteUser(String userId, BuildContext context) async {
    try {
      // Deleting user from Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      // If user was created with Firebase Auth, delete from Authentication as well
      final user = FirebaseAuth.instance.currentUser;
      if (user?.uid == userId) {
        await user?.delete(); // Delete user from Firebase Auth
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully'),
            backgroundColor: geekGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting user: $e')),
        );
      }
    }
  }

  Widget _buildProfileImage(String? photoUrl) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[800],
        border: Border.all(
          color: geekGreen,
          width: 3,
        ),
      ),
      child: ClipOval(
        child: photoUrl != null && photoUrl.isNotEmpty
            ? Image.memory(
                base64Decode(photoUrl),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.person,
                    size: 30,
                    color: Colors.grey,
                  );
                },
              )
            : const Icon(
                Icons.person,
                size: 30,
                color: Colors.grey,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button, logo and logout
            Padding(
              padding: const EdgeInsets.all(24),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Back button aligned to the left
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
                  // Centered Logo
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
                  // Logout button aligned to the right
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                          if (mounted) {
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.logout,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
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
                    'All Users',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: geekGreen,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage and view all registered users.',
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

            // Search Bar with History
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
                                    hintText: 'Search by user or email...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                    ),
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value;
                                      _showSearchHistory = value.isEmpty && 
                                          _searchHistory.isNotEmpty &&
                                          _searchFocus.hasFocus;
                                      _showSortMenu = false;
                                    });
                                  },
                                  onSubmitted: (value) {
                                    if (value.isNotEmpty) {
                                      _performSearch(value);
                                    }
                                  },
                                ),
                              ),
                              if (_searchQuery.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                      _showSearchHistory = _searchHistory.isNotEmpty;
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
                      // Sort Button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showSortMenu = !_showSortMenu;
                            _showSearchHistory = false;
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
                  
                  // Sort Menu
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
                  
                  // Search History Dropdown
                  if (_showSearchHistory)
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Recent Searches',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _clearSearchHistory,
                                  child: const Text(
                                    'Clear All',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: Colors.grey[800]),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _searchHistory.length,
                            itemBuilder: (context, index) {
                              final searchTerm = _searchHistory[index];
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.history,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                title: Text(
                                  searchTerm,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                                trailing: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _searchHistory.removeAt(index);
                                    });
                                    final currentUser = FirebaseAuth.instance.currentUser;
                                    if (currentUser != null) {
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(currentUser.uid)
                                          .update({
                                        'searchHistory': _searchHistory,
                                      });
                                    }
                                  },
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.grey[600],
                                    size: 18,
                                  ),
                                ),
                                onTap: () => _performSearch(searchTerm),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // User List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getSortedUsersStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: geekGreen,
                        strokeWidth: 3,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        "Error loading users",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  final users = snapshot.data?.docs ?? [];

                  // Get the current user ID
                  final currentUser = FirebaseAuth.instance.currentUser;
                  final currentUserId = currentUser?.uid;

                  // Filter out the current user from the list
                  List<QueryDocumentSnapshot> filteredUsers = users.where((user) {
                    return user.id != currentUserId;
                  }).toList();

                  // Apply sorting
                  filteredUsers = _sortUsers(filteredUsers);

                  if (filteredUsers.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 80,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No users found',
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
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final userData = user.data() as Map<String, dynamic>;
                      final photoUrl = userData['photoUrl'] as String?;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: geekGreen.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Profile Image
                            _buildProfileImage(photoUrl),
                            const SizedBox(width: 16),

                            // User Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userData['name'] ?? 'Unnamed',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    userData['email'] ?? 'No email',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (userData['username'] != null &&
                                      userData['username'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '@${userData['username']}',
                                        style: TextStyle(
                                          color: geekGreen.withOpacity(0.8),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Action Buttons
                            Column(
                              children: [
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              UserDetailsScreen(userId: user.id),
                                        ),
                                      );
                                    },
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
                                    onTap: () {
                                      // Confirm before deletion
                                      showDialog(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          backgroundColor: Colors.grey[900],
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            side: BorderSide(
                                              color: geekGreen.withOpacity(0.3),
                                              width: 2,
                                            ),
                                          ),
                                          title: const Text(
                                            'Confirm Deletion',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            ),
                                          ),
                                          content: Text(
                                            'Are you sure you want to delete ${userData['name']}? This action cannot be undone.',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 16,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(dialogContext).pop();
                                              },
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                Navigator.of(dialogContext).pop();
                                                await _deleteUser(
                                                  user.id,
                                                  context,
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
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
                                    },
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
}