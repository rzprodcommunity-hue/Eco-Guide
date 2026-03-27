import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/eco_page_header.dart';
import '../../models/activity.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/activity_service.dart';
import '../../services/api_client.dart';
import '../../services/quiz_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserStats? _stats;
  QuizSummary? _quizSummary;
  bool _isLoading = false;

  final List<_TrailHistoryItem> _historyItems = const [
    _TrailHistoryItem(
      title: 'Sentier des Cretes',
      date: 'Hier, 14:20',
      distance: '12.4 km',
      duration: '3h 45m',
      imageUrl:
          'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=300&q=80',
    ),
    _TrailHistoryItem(
      title: 'Foret de Broceliande',
      date: '12 Oct 2023',
      distance: '8.2 km',
      duration: '2h 10m',
      imageUrl:
          'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=300&q=80',
    ),
    _TrailHistoryItem(
      title: 'Cascade du Dard',
      date: '05 Oct 2023',
      distance: '5.5 km',
      duration: '1h 30m',
      imageUrl:
          'https://images.unsplash.com/photo-1551524164-6cf2ac9f4b4d?auto=format&fit=crop&w=300&q=80',
    ),
    _TrailHistoryItem(
      title: 'Col de la Forclaz',
      date: '28 Sep 2023',
      distance: '15.1 km',
      duration: '5h 20m',
      imageUrl:
          'https://images.unsplash.com/photo-1483728642387-6c3bdd6c93e5?auto=format&fit=crop&w=300&q=80',
    ),
  ];

  final List<double> _weeklyBars = const [28, 36, 58, 48, 84, 68, 94];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) return;

    setState(() => _isLoading = true);

    try {
      final apiClient = context.read<ApiClient>();
      final activityService = ActivityService(apiClient);
      final quizService = QuizService(apiClient);

      final results = await Future.wait<dynamic>([
        activityService.getMyStats(),
        quizService.getMySummary(),
      ]);

      if (!mounted) return;
      setState(() {
        _stats = results[0] as UserStats;
        _quizSummary = results[1] as QuizSummary;
      });
    } catch (_) {
      // UI-only screen: ignore fetch failures and keep fallbacks.
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Non connecte')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F2),
      appBar: const EcoPageHeader(
        title: 'Profil',
        showAccountBadge: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await authProvider.refreshProfile();
          await _loadStats();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(user),
              const SizedBox(height: 22),
              _buildStatsSection(),
              const SizedBox(height: 24),
              _buildBadgesSection(),
              const SizedBox(height: 24),
              _buildActivitySection(),
              const SizedBox(height: 24),
              _buildHistorySection(),
              const SizedBox(height: 28),
              const Divider(color: Color(0xFFD7C7AB)),
              const SizedBox(height: 16),
              _buildBottomActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User user) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryColor, width: 3),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                  backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                      ? Text(
                          _initials(user.fullName),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryColor,
                            fontSize: 24,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF25B845),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: const TextStyle(
                  fontSize: 36 / 2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _roleLabel(user.role),
                style: const TextStyle(
                  fontSize: 17,
                  color: Color(0xFF5F5F5F),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Niveau 12',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EEE8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCFCBD0)),
                    ),
                    child: const Text(
                      'Pro',
                      style: TextStyle(
                        color: Color(0xFF2C8C39),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    final distance = _stats?.distanceText ?? '124 km';
    final completed = _stats?.totalTrailsCompleted ?? 18;

    final cards = [
      _KpiData(
        icon: Icons.landscape,
        iconColor: AppTheme.primaryColor,
        value: distance,
        label: 'Distance Totale',
      ),
      const _KpiData(
        icon: Icons.help,
        iconColor: Color(0xFFE38020),
        value: '3.2k m',
        label: 'Denivele Positif',
      ),
      _KpiData(
        icon: Icons.local_fire_department,
        iconColor: const Color(0xFFE53A32),
        value: '$completed',
        label: 'Sentiers Completes',
      ),
    ];

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards
            .map(
              (item) => SizedBox(
                width: (MediaQuery.of(context).size.width - 56) / 3,
                child: _KpiCard(data: item),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBadgesSection() {
    final badges = _quizSummary?.badges ?? const <QuizBadgeModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Badges & Succes',
          style: TextStyle(
            fontSize: 40 / 2,
            fontWeight: FontWeight.w700,
            color: Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _BadgeTile(
                color: const Color(0xFFF8EFCB),
                icon: Icons.military_tech,
                iconColor: const Color(0xFFF4BA09),
                label: badges.isNotEmpty ? badges.first.label : 'Sommet',
              ),
              const SizedBox(width: 12),
              const _BadgeTile(
                color: Color(0xFFDFF0E3),
                icon: Icons.eco,
                iconColor: Color(0xFF47B35B),
                label: 'Eco-Guide',
              ),
              const SizedBox(width: 12),
              const _BadgeTile(
                color: Color(0xFFDDEDFC),
                icon: Icons.explore,
                iconColor: Color(0xFF2996ED),
                label: 'Pionnier',
              ),
              const SizedBox(width: 12),
              const _BadgeTile(
                color: Color(0xFFF0EEE8),
                icon: Icons.lock,
                iconColor: Color(0xFFA7A7A7),
                label: '???',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Activite Mensuelle',
                style: TextStyle(
                  fontSize: 40 / 2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF212121),
                ),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text(
                'Voir details',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF2EFE8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD5C0A0), width: 1.2),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 130,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _weeklyBars
                      .map(
                        (bar) => Expanded(
                          child: Center(
                            child: Container(
                              width: 24,
                              height: bar,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  _WeekLabel(label: 'L'),
                  _WeekLabel(label: 'M'),
                  _WeekLabel(label: 'M'),
                  _WeekLabel(label: 'J'),
                  _WeekLabel(label: 'V'),
                  _WeekLabel(label: 'S'),
                  _WeekLabel(label: 'D'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'Historique des Randonnees',
                style: TextStyle(
                  fontSize: 40 / 2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF212121),
                ),
              ),
            ),
            Icon(Icons.tune, color: Color(0xFF4A4A4A)),
          ],
        ),
        const SizedBox(height: 10),
        ..._historyItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _TrailHistoryCard(item: item),
          );
        }),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.settings),
            label: const Text('Parametres'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF242424),
              side: const BorderSide(color: Color(0xFFBCBCC0)),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Deconnexion'),
                  content: const Text('Voulez-vous vous deconnecter ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Deconnecter'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await authProvider.logout();
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Deconnexion'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4D1E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
      ],
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Administrateur';
      case 'guide':
        return 'Guide Expert';
      default:
        return 'Explorateur Passionne';
    }
  }

  String _initials(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'E';
    if (words.length == 1) return words.first[0].toUpperCase();
    return (words.first[0] + words.last[0]).toUpperCase();
  }
}

class _KpiData {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _KpiData({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;

  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EFE8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD5C0A0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: data.iconColor, size: 24),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF535353),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Color iconColor;
  final String label;

  const _BadgeTile({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 34),
          const SizedBox(height: 8),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2A2A2A),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekLabel extends StatelessWidget {
  final String label;

  const _WeekLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF6E6E6E),
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _TrailHistoryItem {
  final String title;
  final String date;
  final String distance;
  final String duration;
  final String imageUrl;

  const _TrailHistoryItem({
    required this.title,
    required this.date,
    required this.distance,
    required this.duration,
    required this.imageUrl,
  });
}

class _TrailHistoryCard extends StatelessWidget {
  final _TrailHistoryItem item;

  const _TrailHistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EFE8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD5C0A0), width: 1.1),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              item.imageUrl,
              width: 96,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 96,
                height: 80,
                color: AppTheme.primaryColor.withValues(alpha: 0.2),
                child: const Icon(Icons.image, color: AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Color(0xFF232323),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 17, color: Color(0xFF616161)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF616161),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _TrailMetaInfo(
                      icon: Icons.straighten,
                      value: item.distance,
                    ),
                    _TrailMetaInfo(
                      icon: Icons.timer,
                      value: item.duration,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, size: 28, color: Color(0xFFCFAF80)),
        ],
      ),
    );
  }
}

class _TrailMetaInfo extends StatelessWidget {
  final IconData icon;
  final String value;

  const _TrailMetaInfo({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppTheme.primaryColor),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF2F2F2F),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
