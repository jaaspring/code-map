import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String? iconName;
  final String? imageUrl;
  final String colorHex;
  final String category;
  // New fields for logic
  final String trigger;
  final String conditionType;
  final String? conditionField;
  final dynamic conditionValue;

  BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    this.iconName,
    this.imageUrl,
    required this.colorHex,
    required this.category,
    this.trigger = 'manual',
    this.conditionType = 'none',
    this.conditionField,
    this.conditionValue,
  });

  factory BadgeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BadgeModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      iconName: data['iconName'],
      imageUrl: data['imageUrl'],
      colorHex: data['colorHex'] ?? '#4BC945',
      category: data['category'] ?? 'General',
      trigger: data['trigger'] ?? 'manual',
      conditionType: data['conditionType'] ?? 'none',
      conditionField: data['conditionField'],
      conditionValue: data['conditionValue'],
    );
  }

  IconData get icon {
    if (iconName == null) return Icons.emoji_events;

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
      'code': Icons.code,
      'rocket_launch': Icons.rocket_launch,
      'workspace_premium': Icons.workspace_premium,
      'stars': Icons.stars,
      'military_tech': Icons.military_tech,
      'auto_awesome': Icons.auto_awesome,
    };
    return iconMap[iconName] ?? Icons.emoji_events;
  }

  Color get color {
    try {
      return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF4BC945);
    }
  }

  String get criteriaDescription {
    if (conditionType == 'manual') {
      return "Manual assignment";
    }
    
    if (conditionType == 'count') {
      if (conditionField == 'assessments') {
         return "Complete $conditionValue assessments";
      }
      return "Reach $conditionValue in $conditionField";
    }

    if (trigger == 'manual') return "Manual assignment";

    // Fallback
    String suffix = "";
    if (conditionField != null) suffix += " $conditionField";
    if (conditionValue != null) suffix += " $conditionValue";
    return "Criteria: $conditionType$suffix";
  }
}

class BadgeWithStatus {
  final BadgeModel badge;
  final bool isUnlocked;

  BadgeWithStatus({
    required this.badge,
    required this.isUnlocked,
  });
}
