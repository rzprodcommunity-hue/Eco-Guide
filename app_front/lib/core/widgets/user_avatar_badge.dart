import 'package:flutter/material.dart';

class UserAvatarBadge extends StatelessWidget {
  final String? avatarUrl;
  final String initials;
  final bool isDark;

  const UserAvatarBadge({
    super.key,
    required this.avatarUrl,
    required this.initials,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF22B53A), Color(0xFF15972C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22B53A).withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF121212) : Colors.white,
          ),
          child: ClipOval(
            child: avatarUrl != null && avatarUrl!.isNotEmpty
                ? Image.network(
                    avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, _) => _initials(),
                  )
                : _initials(),
          ),
        ),
      ),
    );
  }

  Widget _initials() => Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Color(0xFF22B53A),
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}
