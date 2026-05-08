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
      color: AppColors.primaryDark,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  path: '/dashboard',
                  currentPath: currentPath,
                ),
                _buildNavItem(
                  icon: Icons.hiking,
                  label: 'Sentiers',
                  path: '/trails',
                  currentPath: currentPath,
                ),
                _buildNavItem(
                  icon: Icons.location_on,
                  label: 'Points d\'interet',
                  path: '/pois',
                  currentPath: currentPath,
                ),
                _buildNavItem(
                  icon: Icons.people,
                  label: 'Utilisateurs',
                  path: '/users',
                  currentPath: currentPath,
                ),
                _buildNavItem(
                  icon: Icons.quiz,
                  label: 'Quiz',
                  path: '/quizzes',
                  currentPath: currentPath,
                ),
                _buildNavItem(
                  icon: Icons.store,
                  label: 'Services locaux',
                  path: '/local-services',
                  currentPath: currentPath,
                ),
                _buildNavItem(
                  icon: Icons.warning,
                  label: 'Alertes SOS',
                  path: '/sos-alerts',
                  currentPath: currentPath,
                ),
                _buildNavItem(
                  icon: Icons.settings,
                  label: 'Parametres',
                  path: '/settings',
                  currentPath: currentPath,
                ),
              ],
            ),
          ),
          _buildCollapseButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 28),
          ),
          if (_isExpanded) ...[
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Eco-Guide Admin',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go(path),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isExpanded ? 16 : 0,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment:
                  _isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white70,
                  size: 24,
                ),
                if (_isExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
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

  Widget _buildCollapseButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: IconButton(
        onPressed: () => setState(() => _isExpanded = !_isExpanded),
        icon: Icon(
          _isExpanded ? Icons.chevron_left : Icons.chevron_right,
          color: Colors.white70,
        ),
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
          Text(
            _getPageTitle(GoRouterState.of(context).matchedLocation),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary,
                radius: 18,
                child: Text(
                  authProvider.user?.fullName.substring(0, 1).toUpperCase() ?? 'A',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                authProvider.user?.fullName ?? 'Admin',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () async {
                  await authProvider.logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                tooltip: 'Deconnexion',
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPageTitle(String path) {
    if (path.startsWith('/dashboard')) return 'Dashboard';
    if (path.startsWith('/trails')) return 'Gestion des Sentiers';
    if (path.startsWith('/pois')) return 'Points d\'Interet';
    if (path.startsWith('/users')) return 'Utilisateurs';
    if (path.startsWith('/quizzes')) return 'Quiz';
    if (path.startsWith('/local-services')) return 'Services Locaux';
    if (path.startsWith('/sos-alerts')) return 'Alertes SOS';
    if (path.startsWith('/settings')) return 'Parametres';
    return 'Eco-Guide Admin';
  }
}
