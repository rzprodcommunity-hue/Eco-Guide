import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/auth_provider.dart';
import '../core/constants/app_colors.dart';

class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentPath = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isExpanded ? 280 : 80,
            child: _buildSidebar(currentPath, authProvider),
          ),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(authProvider),
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

  Widget _buildSidebar(String currentPath, AuthProvider authProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
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
                ),
                _buildNavItem(
                  icon: Icons.route,
                  label: 'Trail Management',
                  path: '/trails',
                  currentPath: currentPath,
                ),
                _buildNavItem(
                  icon: Icons.location_on,
                  label: 'Points of Interest',
                  path: '/pois',
                  currentPath: currentPath,
                ),
                _buildNavItem(
                  icon: Icons.people,
                  label: 'User Management',
                  path: '/users',
                  currentPath: currentPath,
                ),
                _buildNavItem(
                  icon: Icons.quiz,
                  label: 'Quiz Builder',
                  path: '/quizzes',
                  currentPath: currentPath,
                ),
                _buildNavItem(
                  icon: Icons.store,
                  label: 'Local Economy',
                  path: '/local-services',
                  currentPath: currentPath,
                ),
                _buildNavItem(
                  icon: Icons.warning,
                  label: 'SOS Alerts',
                  path: '/sos-alerts',
                  currentPath: currentPath,
                ),
                _buildNavItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  path: '/settings',
                  currentPath: currentPath,
                ),
              ],
            ),
          ),
          _buildUserProfile(authProvider),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.landscape, color: Colors.white, size: 24),
          ),
          if (_isExpanded) ...[
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Eco-Guide',
                style: TextStyle(
                  color: AppColors.primaryDark,
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
  }) {
    final isSelected = currentPath.startsWith(path);
    final selectedColor = AppColors.primaryDark;
    final unselectedColor = const Color(0xFF64748B); // Slate grey

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(path),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isExpanded ? 16 : 0,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment:
                  _isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? selectedColor : unselectedColor,
                  size: 22,
                ),
                if (_isExpanded) ...[
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

  Widget _buildUserProfile(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary,
            radius: 18,
            child: Text(
              authProvider.user?.fullName.substring(0, 2).toUpperCase() ?? 'AD',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          if (_isExpanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    authProvider.user?.fullName ?? 'Admin User',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Super Admin',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async {
                await authProvider.logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              icon: const Icon(Icons.logout, color: AppColors.textSecondary, size: 20),
              tooltip: 'Deconnexion',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopBar(AuthProvider authProvider) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              color: AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
          ),
          const SizedBox(width: 16),
          Text(
            _getPageTitle(GoRouterState.of(context).matchedLocation),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
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
