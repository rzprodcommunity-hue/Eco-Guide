import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/eco_page_header.dart';
import '../../core/widgets/logout_dialog.dart';
import '../../models/activity.dart';
import '../../models/trail.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/trail_provider.dart';
import '../../services/activity_service.dart';
import '../../services/api_client.dart';
import '../../services/badge_service.dart';
import '../../services/offline_progress_service.dart';
import '../trails/trail_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  UserStats? _stats;
  List<UserBadge> _badges = [];
  List<Activity> _trailActivities = [];
  Set<String> _completedTrailIds = {};
  int _localCompleted = 0;
  double _localDistanceKm = 0;
  bool _isLoading = false;

  late AnimationController _barController;
  late Animation<double> _barAnimation;


  // Computed from real progress (offline-first), never hardcoded.
  int _localQuizzes = 0;
  List<double> _weeklyData = const [0, 0, 0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    _barController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _barAnimation = CurvedAnimation(
      parent: _barController,
      curve: Curves.easeOutCubic,
    );
    _loadStats();
    _barController.forward();
  }

  @override
  void dispose() {
    _barController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthenticated) return;
    // Capture before any await (avoids using context across an async gap).
    final activityService = ActivityService(context.read<ApiClient>());

    setState(() => _isLoading = true);

    // 1) Offline-first: load locally stored progress so the profile works
    //    fully without a connection (badges, completed trails, distances).
    final offline = OfflineProgressService.instance;
    final localBadges = await offline.getBadges();
    final localCompleted = await offline.getCompletedTrailIds();
    final localCount = await offline.completedTrailCount();
    final localDistance = await offline.totalDistanceKm();
    final localQuizzes = await offline.totalQuizzesCompleted();
    final weekly = await offline.getWeeklyActivityBars();
    if (mounted) {
      setState(() {
        _badges = localBadges;
        _completedTrailIds = {..._completedTrailIds, ...localCompleted};
        _localCompleted = localCount;
        _localDistanceKm = localDistance;
        _localQuizzes = localQuizzes;
        _weeklyData = weekly;
      });
    }

    // 2) Then sync with the backend and merge when connected.
    try {
      final results = await Future.wait<dynamic>([
        activityService.getMyStats(),
        BadgeService.getMyBadges(),
        activityService.getMyActivities(limit: 30),
      ]);

      if (!mounted) return;
      final allActivities = results[2] as List<Activity>;
      final serverBadges = results[1] as List<UserBadge>;
      await offline.mergeServerBadges(serverBadges);
      final mergedBadges = await offline.getBadges();

      setState(() {
        _stats = results[0] as UserStats;
        _badges = mergedBadges;
        _completedTrailIds = {
          ..._completedTrailIds,
          ...allActivities
              .where((a) => a.type == 'trail_completed' && a.trailId != null)
              .map((a) => a.trailId!),
        };
        _trailActivities = allActivities
            .where((a) => a.type == 'trail_started' && a.trailId != null)
            .toList();
      });
    } catch (_) {
      // Offline (or fetch failed): keep the locally loaded values.
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ── Computed stats (offline-first, never hardcoded) ──────────────────────

  /// Best known number of completed trails (server vs locally tracked).
  int _completedCount() {
    final server = _stats?.totalTrailsCompleted ?? 0;
    final local = _completedTrailIds.isNotEmpty
        ? _completedTrailIds.length
        : _localCompleted;
    return server > local ? server : local;
  }

  /// Best known number of quizzes completed (server vs offline store).
  int _quizCount() {
    final server = _stats?.totalQuizzesAnswered ?? 0;
    return server > _localQuizzes ? server : _localQuizzes;
  }

  /// Gamified level from real progress: 2 pts/trail + 1 pt/quiz, 10 pts/level.
  int _computedLevel() {
    final fromProgress =
        1 + ((_completedCount() * 2 + _quizCount()) / 10).floor();
    final fromStats = _stats?.level ?? 1;
    return fromStats > fromProgress ? fromStats : fromProgress;
  }

  /// Engagement tier (translation key) derived from real activity.
  String _tierKey() {
    final score = _completedCount() + _quizCount();
    if (score >= 15) return 'profile.tier.expert';
    if (score >= 5) return 'profile.tier.pro';
    return 'profile.tier.beginner';
  }

  /// Total positive elevation gain (m) summed over completed trails. Reads the
  /// cached trails so it works offline; 0 when none are known.
  String _elevationText() {
    final trails = context.read<TrailProvider>().trails;
    var sum = 0.0;
    for (final t in trails) {
      if (_completedTrailIds.contains(t.id)) sum += t.elevationGain ?? 0;
    }
    if (sum <= 0) return '0 m';
    if (sum >= 1000) return '${(sum / 1000).toStringAsFixed(1)}k m';
    return '${sum.toStringAsFixed(0)} m';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text(
            context.watch<LocaleProvider>().t('profile.offlineError'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: EcoPageHeader(
          title: context.watch<LocaleProvider>().t('profile.title'),
          showAccountBadge: false),
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
              _buildFavoritesSection(),
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
                  backgroundColor: AppTheme.primaryColor.withValues(
                    alpha: 0.12,
                  ),
                  backgroundImage:
                      user.avatarUrl != null && user.avatarUrl!.isNotEmpty
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
                style: TextStyle(
                  fontSize: 36 / 2,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _roleLabel(user.role),
                style: const TextStyle(fontSize: 17, color: Color(0xFF5F5F5F)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${context.watch<LocaleProvider>().t('profile.level')} ${_computedLevel()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EEE8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCFCBD0)),
                    ),
                    child: Text(
                      context.watch<LocaleProvider>().t(_tierKey()),
                      style: const TextStyle(
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
    final lp = context.watch<LocaleProvider>();
    // Prefer the server stats, but fall back to (and never under-report) the
    // locally stored offline progress.
    final distance = _stats?.distanceText ??
        (_localDistanceKm > 0
            ? '${_localDistanceKm.toStringAsFixed(_localDistanceKm < 10 ? 1 : 0)} km'
            : '0 km');
    final completed = _completedCount();

    final cards = [
      _KpiData(
        icon: Icons.landscape,
        iconColor: AppTheme.primaryColor,
        value: distance,
        label: lp.t('profile.stats.totalDistance'),
      ),
      _KpiData(
        icon: Icons.terrain,
        iconColor: const Color(0xFFE38020),
        value: _elevationText(),
        label: lp.t('profile.stats.elevation'),
      ),
      _KpiData(
        icon: Icons.local_fire_department,
        iconColor: const Color(0xFFE53A32),
        value: '$completed',
        label: lp.t('profile.stats.completedTrails'),
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
    final earnedKeys = _badges.map((b) => b.key).toSet();
    final allDefs = BadgeService.allDefinitions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.watch<LocaleProvider>().t('profile.badges'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              '${_badges.length}/${allDefs.length}',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_badges.isEmpty && !_isLoading)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppTheme.darkCard
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                context.watch<LocaleProvider>().t('profile.noBadges'),
                style: const TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: allDefs.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final def = allDefs[i];
                final key = def['key']!;
                final earned = earnedKeys.contains(key);
                final bgColor = _hexColor(def['color']!);
                final iconColor = earned
                    ? _hexColor(def['iconColor']!)
                    : const Color(0xFFA7A7A7);
                return _BadgeTile(
                  color: earned
                      ? bgColor
                      : (Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.darkCard
                          : const Color(0xFFF0F0F0)),
                  icon: earned ? _iconFromKey(def['icon']!) : Icons.lock,
                  iconColor: iconColor,
                  label: earned ? def['label']! : '???',
                  locked: !earned,
                  tooltip: def['description']!,
                );
              },
            ),
          ),
      ],
    );
  }

  Color _hexColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  IconData _iconFromKey(String key) {
    switch (key) {
      case 'school': return Icons.school;
      case 'grade': return Icons.grade;
      case 'military_tech': return Icons.military_tech;
      case 'eco': return Icons.eco;
      case 'explore': return Icons.explore;
      case 'emoji_events': return Icons.emoji_events;
      default: return Icons.stars;
    }
  }

  Widget _buildFavoritesSection() {
    final favs = context.watch<FavoritesProvider>().favorites;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.watch<LocaleProvider>().t('profile.favorites'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              '${favs.length} sentier${favs.length != 1 ? 's' : ''}',
              style: const TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (favs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkCard
                : const Color(0xFFF2EFE8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkBorder
                    : const Color(0xFFD5C0A0),
                width: 1.2),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 40,
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 10),
                Text(
                  context.watch<LocaleProvider>().t('profile.noFavorites'),
                  style: const TextStyle(
                    color: Color(0xFF7A7A7A),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.watch<LocaleProvider>().t('profile.favorites.hint'),
                  style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: favs.length,
              separatorBuilder: (context, i) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _FavoriteTrailCard(trail: favs[index]),
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
            Expanded(
              child: Text(
                context.watch<LocaleProvider>().t('profile.activity'),
                style: TextStyle(
                  fontSize: 40 / 2,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                context.watch<LocaleProvider>().t('profile.activity.seeDetails'),
                style: const TextStyle(
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
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkCard
                : const Color(0xFFF2EFE8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkBorder
                    : const Color(0xFFD5C0A0),
                width: 1.2),
          ),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _barAnimation,
                builder: (context, child) {
                  final todayIndex = DateTime.now().weekday - 1;
                  final maxVal =
                      _weeklyData.fold<double>(0, (m, v) => v > m ? v : m);
                  double barHeight(int i) {
                    if (maxVal <= 0) return 6;
                    return 10 + (_weeklyData[i] / maxVal) * 100;
                  }

                  return SizedBox(
                    height: 130,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(_weeklyData.length, (i) {
                        final isToday = i == todayIndex;
                        return Expanded(
                          child: Center(
                            child: Container(
                              width: isToday ? 28 : 24,
                              height: barHeight(i) * _barAnimation.value,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? const Color(0xFFE53935)
                                    : AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trails = context.read<TrailProvider>().trails;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.watch<LocaleProvider>().t('profile.history'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextMain : const Color(0xFF212121),
                ),
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (!_isLoading && _trailActivities.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.hiking_rounded,
                    size: 48,
                    color: (isDark ? AppTheme.darkTextSub : AppTheme.textSecondary)
                        .withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text(
                  context.watch<LocaleProvider>().t('profile.history.empty'),
                  style: TextStyle(
                    color: isDark ? AppTheme.darkTextSub : AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          ..._trailActivities.map((activity) {
            final trail = trails.firstWhere(
              (t) => t.id == activity.trailId,
              orElse: () => Trail(
                id: activity.trailId!,
                name: activity.metadata?['trailName'] as String? ?? 'Sentier',
                description: '',
                distance: (activity.metadata?['distance'] as num?)?.toDouble() ?? 0,
                difficulty: '',
                estimatedDuration: (activity.metadata?['duration'] as num?)?.toInt() ?? 0,
                elevationGain: 0,
                imageUrls: activity.metadata?['imageUrl'] != null
                    ? [activity.metadata!['imageUrl'] as String]
                    : null,
                region: '',
                isActive: true,
                createdAt: activity.createdAt,
              ),
            );
            final isCompleted = _completedTrailIds.contains(activity.trailId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _TrailHistoryCard(
                activity: activity,
                trail: trail,
                isCompleted: isCompleted,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TrailDetailScreen(trail: trail),
                  ),
                ),
              ),
            );
          }),
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
            label: Text(context.watch<LocaleProvider>().t('profile.actions.settings')),
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
              final confirm = await showLogoutDialog(context);
              if (confirm) {
                await authProvider.logout();
              }
            },
            icon: const Icon(Icons.logout),
            label: Text(context.watch<LocaleProvider>().t('profile.actions.logout')),
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
    final lp = context.read<LocaleProvider>();
    switch (role) {
      case 'admin':
        return lp.t('profile.role.admin');
      case 'guide':
        return lp.t('profile.role.guide');
      default:
        return lp.t('profile.role.user');
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
        color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkCard
                : const Color(0xFFF2EFE8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkBorder
                    : const Color(0xFFD5C0A0),
                width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, color: data.iconColor, size: 24),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
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

class _FavoriteTrailCard extends StatelessWidget {
  final Trail trail;

  const _FavoriteTrailCard({required this.trail});

  @override
  Widget build(BuildContext context) {
    final favProvider = context.read<FavoritesProvider>();
    return Container(
      width: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkCard
                : const Color(0xFFF2EFE8),
        border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.darkBorder
                : const Color(0xFFD5C0A0),
            width: 1.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (trail.imageUrls != null && trail.imageUrls!.isNotEmpty)
            Image.network(
              trail.imageUrls!.first,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => Container(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                child: const Icon(Icons.landscape, color: AppTheme.primaryColor),
              ),
            )
          else
            Container(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              child: const Icon(Icons.landscape, color: AppTheme.primaryColor),
            ),
          // gradient overlay
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)],
              ),
            ),
          ),
          // remove heart
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => favProvider.toggle(trail),
              child: const Icon(Icons.favorite, color: Color(0xFFE91E8C), size: 20),
            ),
          ),
          // trail name
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Text(
              trail.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
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
  final bool locked;
  final String tooltip;

  const _BadgeTile({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.locked = false,
    this.tooltip = '',
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: locked
                ? const Color(0xFFDDDDDD)
                : iconColor.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: locked
                    ? const Color(0xFFAAAAAA)
                    : const Color(0xFF2A2A2A),
              ),
            ),
          ],
        ),
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

class _TrailHistoryCard extends StatelessWidget {
  final Activity activity;
  final Trail trail;
  final bool isCompleted;
  final VoidCallback onTap;

  const _TrailHistoryCard({
    required this.activity,
    required this.trail,
    required this.isCompleted,
    required this.onTap,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Aujourd\'hui';
    if (diff.inDays == 1) return 'Hier';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String _formatDistance() {
    final meta = activity.metadata;
    final traveled = meta?['distanceTraveled'];
    if (traveled != null && (traveled as num) > 0) {
      return '${(traveled).toStringAsFixed(1)} km';
    }
    final dist = trail.distance;
    return dist > 0 ? '${dist.toStringAsFixed(1)} km' : '—';
  }

  String _formatDuration() {
    final meta = activity.metadata;
    final rawSeconds = meta?['elapsedSeconds'];
    final seconds = rawSeconds is num ? rawSeconds.toInt() : null;
    if (seconds != null && seconds > 0) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      return h > 0 ? '${h}h ${m}min' : '${m}min';
    }
    final dur = trail.estimatedDuration;
    if (dur != null && dur > 0) {
      final h = dur ~/ 60;
      final m = dur % 60;
      return h > 0 ? '${h}h ${m}min' : '${m}min';
    }
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageUrl = trail.imageUrls?.isNotEmpty == true
        ? trail.imageUrls!.first
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : const Color(0xFFF2EFE8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFD5C0A0),
            width: 1.1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: 96,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => _imageFallback(),
                    )
                  : _imageFallback(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trail.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isDark
                                ? AppTheme.darkTextMain
                                : const Color(0xFF232323),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppTheme.primaryColor.withValues(alpha: 0.12)
                              : Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isCompleted ? 'Terminé' : 'En cours',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isCompleted
                                ? AppTheme.primaryColor
                                : Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_month,
                          size: 13,
                          color: isDark
                              ? AppTheme.darkTextSub
                              : const Color(0xFF616161)),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(activity.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppTheme.darkTextSub
                              : const Color(0xFF616161),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    children: [
                      _TrailMetaInfo(
                          icon: Icons.straighten, value: _formatDistance()),
                      _TrailMetaInfo(
                          icon: Icons.timer, value: _formatDuration()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 26,
              color: isDark ? AppTheme.darkTextSub : const Color(0xFFCFAF80),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() => Container(
        width: 96,
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child:
            const Icon(Icons.hiking_rounded, color: AppTheme.primaryColor, size: 32),
      );
}

class _TrailMetaInfo extends StatelessWidget {
  final IconData icon;
  final String value;

  const _TrailMetaInfo({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppTheme.primaryColor),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
