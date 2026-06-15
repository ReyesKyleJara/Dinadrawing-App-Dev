import 'dart:typed_data';

import 'package:flutter/material.dart';

class ProfileService {
  ProfileService._private();

  static final ProfileService instance = ProfileService._private();

  /// Image selected during the current app session.
  ///
  /// This is displayed first so the newly selected photo appears
  /// immediately, even before the network image is downloaded.
  final ValueNotifier<Uint8List?> avatarBytes = ValueNotifier<Uint8List?>(null);

  /// Permanent profile-photo URL returned by the backend.
  final ValueNotifier<String?> avatarUrl = ValueNotifier<String?>(null);

  /// Kept for compatibility with previous built-in avatars.
  final ValueNotifier<IconData?> avatarIcon = ValueNotifier<IconData?>(null);

  final ValueNotifier<String> name = ValueNotifier<String>('User');

  final ValueNotifier<String> username = ValueNotifier<String>('@user');

  void updateProfile({
    Uint8List? bytes,
    String? photoUrl,
    IconData? icon,
    String? newName,
    String? newUsername,
    bool clearAvatar = false,
  }) {
    if (clearAvatar) {
      avatarBytes.value = null;
      avatarUrl.value = null;
      avatarIcon.value = null;
    } else if (icon != null) {
      avatarBytes.value = null;
      avatarUrl.value = null;
      avatarIcon.value = icon;
    } else {
      if (photoUrl != null && photoUrl.trim().isNotEmpty) {
        avatarUrl.value = photoUrl.trim();
        avatarIcon.value = null;
      }

      if (bytes != null && bytes.isNotEmpty) {
        /*
         * Keep both:
         * - bytes for immediate display
         * - URL for permanent backend loading
         */
        avatarBytes.value = bytes;
        avatarIcon.value = null;
      } else if (photoUrl != null && photoUrl.trim().isNotEmpty) {
        avatarBytes.value = null;
      }
    }

    if (newName != null && newName.trim().isNotEmpty) {
      name.value = newName.trim();
    }

    if (newUsername != null && newUsername.trim().isNotEmpty) {
      username.value = _formatUsername(newUsername);
    }
  }

  /// Loads profile values returned by the backend.
  void syncFromUser(
    Map<String, dynamic>? user, {
    bool clearAvatarWhenMissing = false,
  }) {
    if (user == null) {
      return;
    }

    final profileName = user['name']?.toString().trim();

    final profileUsername = user['username']?.toString().trim();

    final profilePhotoUrl = _firstValidUrl([
      user['profile_photo_url'],
      user['photo_url'],
      user['avatar_url'],
    ]);

    if (profileName != null && profileName.isNotEmpty) {
      name.value = profileName;
    }

    if (profileUsername != null && profileUsername.isNotEmpty) {
      username.value = _formatUsername(profileUsername);
    }

    if (profilePhotoUrl != null) {
      avatarUrl.value = profilePhotoUrl;
      avatarIcon.value = null;

      /*
       * Preserve locally selected bytes when available.
       * They are usually more reliable immediately after upload.
       */
      if (avatarBytes.value == null) {
        avatarBytes.value = null;
      }
    } else if (clearAvatarWhenMissing) {
      avatarBytes.value = null;
      avatarUrl.value = null;
      avatarIcon.value = null;
    }
  }

  void resetProfile() {
    avatarBytes.value = null;
    avatarUrl.value = null;
    avatarIcon.value = null;

    name.value = 'User';
    username.value = '@user';
  }

  String? _firstValidUrl(List<dynamic> values) {
    for (final value in values) {
      final url = value?.toString().trim();

      if (url != null && url.isNotEmpty) {
        return url;
      }
    }

    return null;
  }

  String _formatUsername(String value) {
    final cleanUsername = value.trim();

    if (cleanUsername.isEmpty) {
      return '@user';
    }

    return cleanUsername.startsWith('@') ? cleanUsername : '@$cleanUsername';
  }
}

/// Reusable avatar that automatically reflects:
///
/// - newly selected local image bytes
/// - backend profile-photo URL
/// - previous built-in avatar icon
/// - default user initial
class ProfileAvatar extends StatelessWidget {
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const ProfileAvatar({
    super.key,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final service = ProfileService.instance;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([
        service.avatarBytes,
        service.avatarUrl,
        service.avatarIcon,
        service.name,
      ]),
      builder: (context, _) {
        final bytes = service.avatarBytes.value;
        final url = service.avatarUrl.value;
        final icon = service.avatarIcon.value;

        final size = radius * 2;

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: backgroundColor ?? colorScheme.surfaceContainerHighest,
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildAvatarContent(
            context: context,
            bytes: bytes,
            url: url,
            icon: icon,
          ),
        );
      },
    );
  }

  Widget _buildAvatarContent({
    required BuildContext context,
    required Uint8List? bytes,
    required String? url,
    required IconData? icon,
  }) {
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) {
          return _buildFallback(context, icon: icon);
        },
      );
    }

    if (url != null && url.trim().isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) {
          return _buildFallback(context, icon: icon);
        },
      );
    }

    return _buildFallback(context, icon: icon);
  }

  Widget _buildFallback(BuildContext context, {IconData? icon}) {
    final service = ProfileService.instance;
    final colorScheme = Theme.of(context).colorScheme;

    if (icon != null) {
      return Center(
        child: Icon(
          icon,
          size: radius,
          color: foregroundColor ?? colorScheme.onSurfaceVariant,
        ),
      );
    }

    final profileName = service.name.value.trim();

    final firstCharacter =
        profileName.isNotEmpty && profileName.toLowerCase() != 'user'
        ? profileName.substring(0, 1).toUpperCase()
        : null;

    if (firstCharacter != null) {
      return Center(
        child: Text(
          firstCharacter,
          style: TextStyle(
            fontSize: radius * 0.82,
            fontWeight: FontWeight.w700,
            color: foregroundColor ?? colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Center(
      child: Icon(
        Icons.person_rounded,
        size: radius,
        color: foregroundColor ?? colorScheme.onSurfaceVariant,
      ),
    );
  }
}
