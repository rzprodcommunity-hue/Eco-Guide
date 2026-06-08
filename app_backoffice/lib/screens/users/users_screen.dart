import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import '../../core/providers/users_provider.dart';
import '../../core/providers/sos_alerts_provider.dart';
import '../../core/models/user_model.dart';
import '../../core/models/sos_alert_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/responsive.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _searchController = TextEditingController();
  int _userPage = 0;
  static const int _userPageSize = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsersProvider>().loadUsers();
      // Load SOS alerts so we can show each user's SOS + messages.
      context.read<SosAlertsProvider>().loadAlerts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Shows the SOS alerts + messages emitted by [user] (read from the loaded
  /// SOS alerts, matched by userId).
  void _showUserSos(UserModel user) {
    final alerts = context
        .read<SosAlertsProvider>()
        .alerts
        .where((a) => a.userId == user.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.sos, color: AppColors.error, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text('SOS & messages — ${user.fullName}')),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: alerts.isEmpty
              ? const Text(
                  'Aucune alerte SOS enregistrée pour cet utilisateur.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 16,
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.4),
                  ),
                  itemBuilder: (c, i) {
                    final SosAlertModel a = alerts[i];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          a.isResolved
                              ? Icons.check_circle
                              : Icons.warning_amber_rounded,
                          color: a.isResolved
                              ? AppColors.success
                              : AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (a.message != null && a.message!.isNotEmpty)
                                    ? a.message!
                                    : '(Aucun message)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${DateFormat('dd/MM/yyyy à HH:mm').format(a.createdAt)} · ${a.isResolved ? 'Résolu' : 'Actif'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              Text(
                                '${a.latitude.toStringAsFixed(5)}, ${a.longitude.toStringAsFixed(5)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UsersProvider>();

    // Dynamic stats computed from the loaded users.
    final now = DateTime.now();
    final newWeekCount = provider.users
        .where((u) => now.difference(u.createdAt).inDays <= 7)
        .length;
    final newMonthCount = provider.users
        .where((u) => now.difference(u.createdAt).inDays <= 30)
        .length;

    final isMobile = Responsive.isMobile(context);
    final isCompact = Responsive.isCompact(context);

    // Client-side filtering across all loaded users
    final q = _searchController.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? provider.users
        : provider.users
            .where((u) =>
                u.fullName.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q))
            .toList();

    // Clamp current page and compute the visible page slice
    final pageCount = (filtered.length / _userPageSize).ceil();
    if (pageCount > 0 && _userPage > pageCount - 1) {
      _userPage = pageCount - 1;
    }
    if (_userPage < 0) _userPage = 0;
    final pageItems =
        filtered.skip(_userPage * _userPageSize).take(_userPageSize).toList();

    final searchField = SizedBox(
      width: isMobile ? double.infinity : 250,
      height: 40,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() => _userPage = 0),
        decoration: InputDecoration(
          hintText: 'Rechercher par nom ou e-mail...',
          hintStyle: const TextStyle(
            color: AppColors.textHint,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textHint,
            size: 18,
          ),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
      ),
    );

    final exportButton = OutlinedButton.icon(
      onPressed: () => _exportCsv(filtered),
      icon: Icon(
        Icons.download,
        size: 16,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      label: Text(
        'Exporter CSV',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: Theme.of(context).cardColor,
        side: BorderSide(color: Theme.of(context).dividerColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );

    final headerTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestion des utilisateurs',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Gérez les comptes des randonneurs et les autorisations d\'accès',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
      ],
    );

    return SingleChildScrollView(
      padding: Responsive.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          if (isCompact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerTitle,
                const SizedBox(height: 16),
                searchField,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: exportButton),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerTitle,
                Row(
                  children: [
                    searchField,
                    const SizedBox(width: 16),
                    exportButton,
                  ],
                ),
              ],
            ),
          SizedBox(height: isMobile ? 20 : 32),

          // ── Stats Cards ──
          if (isMobile)
            Column(
              children: [
                _buildStatCard(context, 'Total des utilisateurs', '${provider.total}', null),
                const SizedBox(height: 12),
                _buildStatCard(context, 'Nouveaux cette semaine', '$newWeekCount', null),
                const SizedBox(height: 12),
                _buildStatCard(context, 'Nouveaux ce mois', '$newMonthCount', null),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                      context, 'Total des utilisateurs', '${provider.total}', null),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildStatCard(
                      context, 'Nouveaux cette semaine', '$newWeekCount', null),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildStatCard(
                      context, 'Nouveaux ce mois', '$newMonthCount', null),
                ),
              ],
            ),
          SizedBox(height: isMobile ? 20 : 32),

          // ── User Data Table ──
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (provider.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (provider.error != null)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        provider.error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  )
                else if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'Aucun utilisateur trouvé.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  )
                else
                  _buildTable(pageItems),

                // Pagination Footer
                if (!provider.isLoading && filtered.isNotEmpty)
                  _buildPaginationFooter(filtered),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    String? percentage,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (percentage != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    percentage,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<UserModel> pageItems) {
    return Column(
      children: [
        // Header (full width)
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                  flex: 5,
                  child: _userColHeader('Détails de l\'utilisateur')),
              Expanded(flex: 3, child: _userColHeader('Date d\'inscription')),
              SizedBox(width: 130, child: _userColHeader('SOS & messages')),
            ],
          ),
        ),
        ...pageItems.map(_buildUserRow),
      ],
    );
  }

  Widget _userColHeader(String label) => Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      );

  Widget _buildUserRow(UserModel user) {
    final initials = _getInitials(user.fullName);
    final color = _getAvatarColor(user.fullName);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          // User details (fills available width)
          Expanded(
            flex: 5,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.2),
                  radius: 20,
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Text(initials,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 14))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(user.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(height: 4),
                      Text(user.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Joined date
          Expanded(
            flex: 3,
            child: Text(
              DateFormat('dd/MM/yyyy').format(user.createdAt),
              style: TextStyle(
                fontSize: 13,
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          // SOS & messages action
          SizedBox(
            width: 130,
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _showUserSos(user),
                icon: const Icon(Icons.sos, size: 16, color: AppColors.error),
                label: Text(
                  'Voir',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(List<UserModel> filtered) {
    final total = filtered.length;
    final pageCount = (total / _userPageSize).ceil();
    final currentPage = pageCount == 0 ? 0 : _userPage.clamp(0, pageCount - 1);

    int startIdx = total == 0 ? 0 : (currentPage * _userPageSize) + 1;
    int endIdx =
        total == 0 ? 0 : ((currentPage + 1) * _userPageSize).clamp(0, total);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Affichage de $startIdx-$endIdx sur ${NumberFormat("#,###").format(total)} utilisateurs',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          Row(
            children: [
              _buildPageButton(
                icon: Icons.chevron_left,
                onPressed: currentPage > 0
                    ? () => setState(() => _userPage = currentPage - 1)
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                'Page ${pageCount == 0 ? 0 : currentPage + 1} / $pageCount',
                style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              _buildPageButton(
                icon: Icons.chevron_right,
                onPressed: currentPage < pageCount - 1
                    ? () => setState(() => _userPage = currentPage + 1)
                    : null,
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
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onPressed == null
              ? AppColors.textHint
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  void _exportCsv(List<UserModel> users) {
    final buffer = StringBuffer();
    buffer.writeln('Nom,E-mail,Statut,Inscription');
    for (final user in users) {
      final nom = _csvEscape(user.fullName);
      final email = _csvEscape(user.email);
      final statut = user.isActive ? 'Actif' : 'Inactif';
      final date = DateFormat('dd/MM/yyyy').format(user.createdAt);
      buffer.writeln('$nom,$email,$statut,$date');
    }
    final csv = buffer.toString();

    if (kIsWeb) {
      final blob = web.Blob(
        [csv.toJS].toJS,
        web.BlobPropertyBag(type: 'text/csv'),
      );
      final url = web.URL.createObjectURL(blob);
      final anchor = web.HTMLAnchorElement()
        ..href = url
        ..download = 'utilisateurs.csv';
      anchor.click();
      web.URL.revokeObjectURL(url);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export CSV généré'),
          backgroundColor: AppColors.success,
        ),
      );
    }
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
