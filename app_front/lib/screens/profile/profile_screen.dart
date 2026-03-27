import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/eco_page_header.dart';
import '../../providers/auth_provider.dart';
import '../../models/activity.dart';
import '../../services/api_client.dart';
import '../../services/activity_service.dart';
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
      final statsFuture = activityService.getMyStats();
      final quizSummaryFuture = quizService.getMySummary();

      final results = await Future.wait<dynamic>([
        statsFuture,
        quizSummaryFuture,
      ]);

      if (!mounted) return;
      setState(() {
        _stats = results[0] as UserStats;
        _quizSummary = results[1] as QuizSummary;
      });
    } catch (e) {
      // Ignore errors
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

    return Scaffold(
      appBar: EcoPageHeader(
        title: 'Profil',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
        ],
      ),
      body: authProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const Center(child: Text('Non connecte'))
              : RefreshIndicator(
                  onRefresh: () async {
                    await authProvider.refreshProfile();
                    await _loadStats();
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Avatar and info
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                          backgroundImage: user.avatarUrl != null
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                          child: user.avatarUrl == null
                              ? Text(
                                  user.fullName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    color: AppTheme.primaryColor,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.fullName,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),

                        // Stats cards
                        if (_isLoading)
                          const CircularProgressIndicator()
                        else if (_stats != null)
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.hiking,
                                      label: 'Randonnees',
                                      value: '${_stats!.totalTrailsCompleted}',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.place,
                                      label: 'POIs visites',
                                      value: '${_stats!.totalPoisVisited}',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.straighten,
                                      label: 'Distance',
                                      value: _stats!.distanceText,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _StatCard(
                                      icon: Icons.quiz,
                                      label: 'Quiz',
                                      value: '${_stats!.totalQuizzesAnswered}',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),

                        if (_quizSummary != null) _buildQuizProgressSection(),
                        if (_quizSummary != null) const SizedBox(height: 24),

                        // Member since
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.grey),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Membre depuis',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  Text(
                                    '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Logout button
                        OutlinedButton.icon(
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
                          label: const Text('Se deconnecter'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildQuizProgressSection() {
    final summary = _quizSummary;
    if (summary == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E9EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progression Quiz',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip('Score total', '${summary.totalScore} pts'),
              _buildInfoChip('Quiz joues', '${summary.quizzesCompleted}'),
              _buildInfoChip(
                'Moyenne',
                '${summary.averagePercentage.toStringAsFixed(0)}%',
              ),
              _buildInfoChip(
                'Meilleur',
                '${summary.bestPercentage.toStringAsFixed(0)}%',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Scores par categorie',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (summary.categoryScores.isEmpty)
            Text(
              'Aucun score enregistre pour le moment.',
              style: TextStyle(color: Colors.grey[600]),
            )
          else
            Column(
              children: summary.categoryScores
                  .where((score) => score.category != null)
                  .map(
                    (score) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.bar_chart, color: AppTheme.primaryColor),
                      title: Text(_categoryLabel(score.category)),
                      subtitle: Text(
                        '${score.correctAnswers}/${score.totalQuestions} bonnes reponses',
                      ),
                      trailing: Text(
                        '${score.totalScore} pts',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 16),
          const Text(
            'Badges debloques',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (summary.badges.isEmpty)
            Text(
              'Continuez pour debloquer vos premiers badges (>100 pts).',
              style: TextStyle(color: Colors.grey[600]),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: summary.badges
                  .map(
                    (badge) => Chip(
                      avatar: Icon(
                        _iconFromName(badge.icon),
                        size: 18,
                        color: Colors.white,
                      ),
                      backgroundColor:
                          _parseColor(badge.color).withValues(alpha: 0.9),
                      labelStyle: const TextStyle(color: Colors.white),
                      label: Text(badge.label),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$label: $value'),
    );
  }

  String _categoryLabel(String? category) {
    switch (category) {
      case 'flora':
        return 'Flore';
      case 'fauna':
        return 'Faune';
      case 'ecology':
        return 'Ecologie';
      case 'history':
        return 'Histoire';
      case 'geography':
        return 'Geographie';
      case 'safety':
        return 'Securite';
      default:
        return 'General';
    }
  }

  IconData _iconFromName(String? iconName) {
    switch (iconName) {
      case 'emoji_events':
        return Icons.emoji_events;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'verified':
        return Icons.verified;
      case 'military_tech':
      default:
        return Icons.military_tech;
    }
  }

  Color _parseColor(String? color) {
    if (color == null || color.isEmpty) {
      return AppTheme.primaryColor;
    }

    final hex = color.replaceAll('#', '');
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    final parsed = int.tryParse(normalized, radix: 16);
    if (parsed == null) return AppTheme.primaryColor;
    return Color(parsed);
  }

  void _showSettingsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parametres',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Langue'),
              subtitle: const Text('Francais'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Changement de langue bientot disponible')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              trailing: Switch(value: true, onChanged: (_) {}),
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('GPS'),
              trailing: Switch(value: true, onChanged: (_) {}),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
