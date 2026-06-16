import 'package:flutter/material.dart';

class Plan {
  final int? id;
  final int? adminId;

  final String title;
  final String? description;
  final String date;
  final String? planDate;
  final String? planTime;
  final String location;
  final String status;
  final Color statusColor;
  final String? inviteCode;
  final String? bannerColor;
  final String? bannerImageUrl;
  final String themeColor;

  final bool isArchived;
  final bool isDeleted;

  final List<Map<String, dynamic>> members;

  Plan({
    this.id,
    this.adminId,
    required this.title,
    this.description,
    required this.date,
    this.planDate,
    this.planTime,
    required this.location,
    required this.status,
    required this.statusColor,
    this.inviteCode,
    this.bannerColor,
    this.bannerImageUrl,
    this.themeColor = '#F2B73F',
    this.isArchived = false,
    this.isDeleted = false,
    this.members = const <Map<String, dynamic>>[],
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? 'Plan Ongoing';

    return Plan(
      id: _parseInt(json['id']),
      adminId: _parseInt(json['admin_id']),
      title: json['title']?.toString() ?? 'Untitled Plan',
      description: json['description']?.toString(),
      date: _formatDisplayDate(json['plan_date']?.toString()),
      planDate: json['plan_date']?.toString(),
      planTime: json['plan_time']?.toString(),
      location: json['location']?.toString() ?? '',
      status: status,
      statusColor: getStatusColor(status),
      inviteCode: json['invite_code']?.toString(),
      bannerColor: json['banner_color']?.toString(),
      bannerImageUrl: json['banner_image_url']?.toString(),
      themeColor: json['theme_color']?.toString() ?? '#F2B73F',
      isArchived: _parseBool(json['is_archived']),
      isDeleted: _parseBool(json['is_deleted']),
      members: _parseMembers(json['members']),
    );
  }

  static List<Map<String, dynamic>> _parseMembers(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((member) => Map<String, dynamic>.from(member))
        .toList(growable: false);
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static bool _parseBool(dynamic value) {
    return value == 1 || value == true || value == '1' || value == 'true';
  }

  static String _formatDisplayDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return '';
    }

    try {
      final date = DateTime.parse(dateString);
      return '${_monthName(date.month)} ${date.day}';
    } catch (_) {
      return dateString;
    }
  }

  static String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    if (month < 1 || month > 12) {
      return '';
    }

    return months[month - 1];
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'Plan Ongoing':
        return const Color(0xFFFFE4AD);
      case 'Planned':
        return const Color(0xFFB8E4C1);
      case 'Plan Postponed':
        return const Color(0xFFBFDBFE);
      case 'Plan Canceled':
        return const Color(0xFFFECACA);
      case 'Completed':
        return const Color(0xFF86EFAC);
      default:
        return const Color(0xFFFFE4AD);
    }
  }

  static Color parseColor(String? hexColor) {
    if (hexColor == null || hexColor.trim().isEmpty) {
      return const Color(0xFFF7F7FF);
    }

    var cleanHex = hexColor.trim().replaceAll('#', '');

    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }

    if (cleanHex.length != 8) {
      return const Color(0xFFF7F7FF);
    }

    try {
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return const Color(0xFFF7F7FF);
    }
  }
}
