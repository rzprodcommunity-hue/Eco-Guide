import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../screens/home/home_screen.dart';
import 'user_avatar_badge.dart';

class EcoPageHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final bool centerTitle;
  final bool showAccountBadge;
  final List<Widget>? actions;

  const EcoPageHeader({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.centerTitle = true,
    this.showAccountBadge = true,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 6);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      leadingWidth: 52,
      leading: showBackButton && canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : const SizedBox.shrink(),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w800,
          fontSize: 24,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        ...?actions,
        if (showAccountBadge) const _AccountBadge(),
        const SizedBox(width: 12),
      ],
    );
  }
}

class _AccountBadge extends StatelessWidget {
  const _AccountBadge();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    final displayName = user?.fullName ?? 'Guest';
    final avatarUrl = user?.avatarUrl;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 7)),
          (route) => false,
        );
      },
      child: UserAvatarBadge(
        avatarUrl: avatarUrl,
        initials: _initials(displayName),
        isDark: isDark,
      ),
    );
  }

  String _initials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'G';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words.first[0] + words.last[0]).toUpperCase();
  }
}
