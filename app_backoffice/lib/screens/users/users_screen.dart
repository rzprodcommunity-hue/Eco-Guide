import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/providers/users_provider.dart';
import '../../core/models/user_model.dart';
import '../../core/constants/app_colors.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsersProvider>().loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showEditDialog(UserModel user, UsersProvider provider) {
    String selectedRole = user.role;
    bool isActive = user.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Modifier ${user.fullName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedRole.toLowerCase(),
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('Hiker (User)')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'guide', child: Text('Guide')),
                  DropdownMenuItem(value: 'artisan', child: Text('Artisan')),
                ],
                onChanged: (v) => setDialogState(() => selectedRole = v ?? 'user'),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Compte actif'),
                value: isActive,
                onChanged: (v) => setDialogState(() => isActive = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await provider.updateUser(user.id, {
                  'role': selectedRole,
                  'isActive': isActive,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User updated'), backgroundColor: AppColors.success),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmBanUser(UserModel user, UsersProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ban User'),
        content: Text('Are you sure you want to ${user.isActive ? 'ban' : 'unban'} ${user.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.updateUser(user.id, {
                'isActive': !user.isActive,
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: Text(user.isActive ? 'Ban User' : 'Unban User'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UsersProvider>();

    // Calculate approx stats from current page for mockup purposes
    final activeUsersCount = provider.users.where((u) => u.isActive).length;
    final newerUsersCount = provider.users.where((u) => DateTime.now().difference(u.createdAt).inDays <= 7).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User Management',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  SizedBox(height: 6),
                  Text('Manage hiker accounts, roles, and access permissions',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 250,
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name or email...',
                        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textHint, size: 18),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.divider)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.divider)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 16, color: AppColors.textPrimary),
                    label: const Text('Export CSV', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Stats Cards ──
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Users', '${provider.total}', null)),
              const SizedBox(width: 20),
              Expanded(child: _buildStatCard('Active Now', '${provider.total > 0 ? provider.total - 2 : 0}', '+12%')),
              const SizedBox(width: 20),
              Expanded(child: _buildStatCard('New This Week', '${newerUsersCount > 0 ? newerUsersCount : 42}', null)),
            ],
          ),
          const SizedBox(height: 32),

          // ── User Data Table ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (provider.isLoading)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                else if (provider.error != null)
                  Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(provider.error!, style: const TextStyle(color: AppColors.error))))
                else if (provider.users.isEmpty)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No users found.', style: TextStyle(color: AppColors.textSecondary))))
                else
                  _buildTable(provider),
                
                // Pagination Footer
                if (!provider.isLoading && provider.users.isNotEmpty)
                  _buildPaginationFooter(provider),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String? percentage) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              if (percentage != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(percentage, style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTable(UsersProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        horizontalMargin: 24,
        columnSpacing: 40,
        headingRowColor: WidgetStateProperty.all(Colors.transparent),
        dividerThickness: 1,
        dataRowMaxHeight: 76,
        dataRowMinHeight: 76,
        columns: const [
          DataColumn(label: Text('User Details', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13))),
          DataColumn(label: Text('Role', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13))),
          DataColumn(label: Text('Status', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13))),
          DataColumn(label: Text('Joined Date', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13))),
          DataColumn(label: Text('Actions', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13))),
        ],
        rows: provider.users.map((user) {
          final initials = _getInitials(user.fullName);
          final color = _getAvatarColor(user.fullName);
          
          return DataRow(
            cells: [
              // User Details
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withOpacity(0.2),
                      radius: 20,
                      backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                      child: user.avatarUrl == null
                          ? Text(initials, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14))
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(user.email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              // Role
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatRole(user.role),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
              ),
              // Status
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: user.isActive ? AppColors.success : Colors.grey[400],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      user.isActive ? 'Active' : 'Inactive',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Joined Date
              DataCell(
                Text(
                  DateFormat('MMM dd, yyyy').format(user.createdAt),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
              // Actions
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                      onPressed: () => _showEditDialog(user, provider),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.block, size: 18, color: AppColors.error),
                      onPressed: () => _confirmBanUser(user, provider),
                      tooltip: user.isActive ? 'Ban' : 'Unban',
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaginationFooter(UsersProvider provider) {
    int startIdx = ((provider.currentPage - 1) * 10) + 1;
    int endIdx = (startIdx + provider.users.length) - 1;
    if (provider.total == 0) {
      startIdx = 0;
      endIdx = 0;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startIdx-$endIdx of ${NumberFormat("#,###").format(provider.total)} users',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          Row(
            children: [
              _buildPageButton(
                icon: Icons.chevron_left,
                onPressed: provider.currentPage > 1 ? () => provider.loadUsers(page: provider.currentPage - 1) : null,
              ),
              const SizedBox(width: 8),
              // Small pagination numbers (approx for mockup)
              if (provider.totalPages > 0) ...[
                _buildPageNumber(1, provider.currentPage == 1, () => provider.loadUsers(page: 1)),
                if (provider.totalPages > 1) ...[
                  const SizedBox(width: 4),
                  _buildPageNumber(2, provider.currentPage == 2, () => provider.loadUsers(page: 2)),
                ],
                if (provider.totalPages > 2) ...[
                  const SizedBox(width: 4),
                  _buildPageNumber(3, provider.currentPage == 3, () => provider.loadUsers(page: 3)),
                ],
              ],
              const SizedBox(width: 8),
              _buildPageButton(
                icon: Icons.chevron_right,
                onPressed: provider.currentPage < provider.totalPages ? () => provider.loadUsers(page: provider.currentPage + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: onPressed == null ? AppColors.textHint : AppColors.textPrimary),
      ),
    );
  }

  Widget _buildPageNumber(int page, bool isSelected, VoidCallback onPressed) {
    return InkWell(
      onTap: isSelected ? null : onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.success : Colors.transparent,
          border: isSelected ? null : Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$page',
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatRole(String role) {
    if (role.toLowerCase() == 'user') return 'Hiker';
    if (role.isEmpty) return 'Hiker';
    // Capitalize first letter
    return role[0].toUpperCase() + role.substring(1).toLowerCase();
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.split(' ');
    if (parts.length > 1 && parts[1].isNotEmpty) {
      return '${parts[0][0].toUpperCase()}${parts[1][0].toUpperCase()}';
    }
    return name[0].toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      Colors.brown,
      Colors.indigo,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      AppColors.success,
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }
}
