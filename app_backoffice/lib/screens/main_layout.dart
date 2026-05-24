import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/theme_provider.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/responsive.dart';

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _isExpanded = true;
  bool _autoSet = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_autoSet) {
      _autoSet = true;
      _isExpanded = Responsive.isDesktop(context);
    }
  }

  // ── Shell color helpers (dark navigation chrome) ──────────────────────────
  Color _navSurface(bool dark) => dark ? AppColors.darkSurface : Colors.white;
  Color _navCard(bool dark) => dark ? AppColors.darkSurfaceAlt : Colors.white;
  Color _navBorder(bool dark) => dark ? AppColors.darkBorder : AppColors.divider;
  Color _navText(bool dark) =>
      dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color _navMuted(bool dark) =>
      dark ? AppColors.darkTextSecondary : AppColors.textSecondary;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final dark = context.watch<ThemeProvider>().isDark;
    final currentPath = GoRouterState.of(context).matchedLocation;
    final isCompact = Responsive.isCompact(context);
    final useDrawer = Responsive.isMobile(context) ||
        (Responsive.isTablet(context) &&
            MediaQuery.of(context).orientation == Orientation.portrait);

    if (useDrawer) {
      return _buildMobileScaffold(currentPath, authProvider, dark);
    }

    // On tablet landscape, force collapsed sidebar; on desktop respect toggle.
    final expanded = Responsive.isTablet(context) ? false : _isExpanded;

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: expanded ? 280 : 80,
            child: _buildSidebar(currentPath, authProvider, expanded, dark),
          ),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(authProvider, currentPath,
                    isMobile: isCompact, dark: dark),
                Expanded(
                  child: Container(
                    color: AppColors.background,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile layout (Drawer) ────────────────────────────────────────────────

  Widget _buildMobileScaffold(
    String currentPath,
    AuthProvider authProvider,
    bool dark,
  ) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: _navSurface(dark),
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        surfaceTintColor: _navSurface(dark),
        iconTheme: IconThemeData(color: _navMuted(dark)),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu, color: _navMuted(dark)),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          _getPageTitle(currentPath),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _navText(dark),
          ),
        ),
        actions: [_buildThemeToggle(dark)],
      ),
      drawer: Drawer(
        width: 280,
        backgroundColor: _navSurface(dark),
        child: _buildSidebar(currentPath, authProvider, true, dark),
      ),
      body: widget.child,
    );
  }

  // ── Dark mode toggle ──────────────────────────────────────────────────────

  Widget _buildThemeToggle(bool dark) {
    return IconButton(
      icon: Icon(
        dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
        color: _navMuted(dark),
      ),
      tooltip: dark ? 'Mode clair' : 'Mode sombre',
      onPressed: () => context.read<ThemeProvider>().toggle(),
    );
  }

  // ── Sidebar ───────────────────────────────────────────────────────────────

  Widget _buildSidebar(
    String currentPath,
    AuthProvider authProvider,
    bool isExpanded,
    bool dark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _navSurface(dark),
        border: Border(right: BorderSide(color: _navBorder(dark), width: 1)),
      ),
      child: Column(
        children: [
          _buildHeader(isExpanded, dark),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(
                  icon: Icons.grid_view,
                  label: 'Dashboard',
                  path: '/dashboard',
                  currentPath: currentPath,
                  isExpanded: isExpanded,
                  dark: dark,
                ),
                _buildNavItem(
                  icon: Icons.route,
                  label: 'Trail Management',
                  path: '/trails',
                  currentPath: currentPath,
                  isExpanded: isExpanded,
                  dark: dark,
                ),
                _buildNavItem(
                  icon: Icons.location_on,
                  label: 'Points of Interest',
                  path: '/pois',
                  currentPath: currentPath,
                  isExpanded: isExpanded,
                  dark: dark,
                ),
                _buildNavItem(
                  icon: Icons.people,
                  label: 'User Management',
                  path: '/users',
                  currentPath: currentPath,
                  isExpanded: isExpanded,
                  dark: dark,
                ),
                _buildNavItem(
                  icon: Icons.quiz,
                  label: 'Quiz Builder',
                  path: '/quizzes',
                  currentPath: currentPath,
                  isExpanded: isExpanded,
                  dark: dark,
                ),
                _buildNavItem(
                  icon: Icons.store,
                  label: 'Local Economy',
                  path: '/local-services',
                  currentPath: currentPath,
                  isExpanded: isExpanded,
                  dark: dark,
                ),
                _buildNavItem(
                  icon: Icons.warning,
                  label: 'SOS Alerts',
                  path: '/sos-alerts',
                  currentPath: currentPath,
                  isExpanded: isExpanded,
                  dark: dark,
                ),
              ],
            ),
          ),
          _buildUserProfile(authProvider, isExpanded, dark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isExpanded, bool dark) {
    return Container(
      height: 80,
      padding: EdgeInsets.symmetric(
        horizontal: isExpanded ? 20 : 12,
        vertical: 16,
      ),
      child: Row(
        mainAxisAlignment:
            isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.landscape,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Eco-Guide',
                style: TextStyle(
                  color: dark ? AppColors.primaryLight : AppColors.primaryDark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String path,
    required String currentPath,
    required bool isExpanded,
    required bool dark,
  }) {
    final isSelected = currentPath.startsWith(path);
    final selectedColor =
        dark ? AppColors.primaryLight : AppColors.primaryDark;
    final unselectedColor =
        dark ? AppColors.darkTextSecondary : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.go(path);
            // Close drawer if open (mobile / tablet portrait)
            if (Scaffold.maybeOf(context)?.hasDrawer == true &&
                Scaffold.of(context).isDrawerOpen) {
              Navigator.of(context).pop();
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isExpanded ? 16 : 0,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: dark ? 0.24 : 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: isExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? selectedColor : unselectedColor,
                  size: 22,
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? selectedColor : unselectedColor,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfile(
    AuthProvider authProvider,
    bool isExpanded,
    bool dark,
  ) {
    return Container(
      padding: EdgeInsets.all(isExpanded ? 20 : 10),
      margin: EdgeInsets.all(isExpanded ? 16 : 10),
      decoration: BoxDecoration(
        color: _navCard(dark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _navBorder(dark).withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.15 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment:
            isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary,
            radius: isExpanded ? 18 : 16,
            child: Text(
              authProvider.user?.fullName.substring(0, 2).toUpperCase() ?? 'AD',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    authProvider.user?.fullName ?? 'Admin User',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _navText(dark),
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Super Admin',
                    style: TextStyle(
                      color: _navMuted(dark),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async {
                await authProvider.logout();
                if (mounted) context.go('/login');
              },
              icon: Icon(
                Icons.logout,
                color: _navMuted(dark),
                size: 20,
              ),
              tooltip: 'Deconnexion',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopBar(
    AuthProvider authProvider,
    String currentPath, {
    required bool isMobile,
    required bool dark,
  }) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _navSurface(dark),
        border: Border(bottom: BorderSide(color: _navBorder(dark))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.18 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isExpanded ? Icons.menu_open : Icons.menu,
              color: _navMuted(dark),
            ),
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _getPageTitle(currentPath),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _navText(dark),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildThemeToggle(dark),
        ],
      ),
    );
  }

  String _getPageTitle(String path) {
    if (path.startsWith('/dashboard')) return 'Dashboard';
    if (path.startsWith('/trails')) return 'Trail Management';
    if (path.startsWith('/pois')) return 'Points of Interest';
    if (path.startsWith('/users')) return 'User Management';
    if (path.startsWith('/quizzes')) return 'Quiz Builder';
    if (path.startsWith('/local-services')) return 'Local Economy';
    if (path.startsWith('/sos-alerts')) return 'SOS Alerts';
    if (path.startsWith('/settings')) return 'Settings';
    return 'Eco-Guide Admin';
  }
}
