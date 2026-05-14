import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/user_avatar_badge.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../services/quiz_service.dart';
import '../profile/profile_screen.dart';
import 'quiz_game_screen.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<QuizProvider>();
      provider.loadCategoryStats();
      provider.loadUserScores();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  static const List<Map<String, dynamic>> _categories = [
    {
      'key': 'flora',
      'emoji': '🌿',
      'icon': Icons.local_florist,
      'color': Color(0xFF2E7D32),
      'bg': Color(0xFFE8F5E9),
      'bgDark': Color(0xFF1B3A1C),
    },
    {
      'key': 'fauna',
      'emoji': '🦊',
      'icon': Icons.pets,
      'color': Color(0xFFE65100),
      'bg': Color(0xFFFFF3E0),
      'bgDark': Color(0xFF3E2000),
    },
    {
      'key': 'ecology',
      'emoji': '♻️',
      'icon': Icons.eco,
      'color': Color(0xFF0277BD),
      'bg': Color(0xFFE3F2FD),
      'bgDark': Color(0xFF002B47),
    },
    {
      'key': 'geography',
      'emoji': '🏔️',
      'icon': Icons.terrain,
      'color': Color(0xFF4E342E),
      'bg': Color(0xFFEFEBE9),
      'bgDark': Color(0xFF2A1A17),
    },
    {
      'key': 'history',
      'emoji': '📜',
      'icon': Icons.history_edu,
      'color': Color(0xFF6A1B9A),
      'bg': Color(0xFFF3E5F5),
      'bgDark': Color(0xFF2A0A3E),
    },
    {
      'key': 'safety',
      'emoji': '🛡️',
      'icon': Icons.shield,
      'color': Color(0xFFC62828),
      'bg': Color(0xFFFFEBEE),
      'bgDark': Color(0xFF3E0000),
    },
  ];

  String _categoryName(String key, LocaleProvider lp) {
    switch (key) {
      case 'flora':
        return lp.languageCode == 'ar' ? 'النباتات' : (lp.languageCode == 'en' ? 'Flora' : 'Flore');
      case 'fauna':
        return lp.languageCode == 'ar' ? 'الحيوانات' : (lp.languageCode == 'en' ? 'Fauna' : 'Faune');
      case 'ecology':
        return lp.languageCode == 'ar' ? 'البيئة' : (lp.languageCode == 'en' ? 'Ecology' : 'Écologie');
      case 'geography':
        return lp.languageCode == 'ar' ? 'الجغرافيا' : (lp.languageCode == 'en' ? 'Geography' : 'Géographie');
      case 'history':
        return lp.languageCode == 'ar' ? 'التاريخ' : (lp.languageCode == 'en' ? 'History' : 'Histoire');
      case 'safety':
        return lp.languageCode == 'ar' ? 'السلامة' : (lp.languageCode == 'en' ? 'Safety' : 'Sécurité');
      default:
        return key;
    }
  }

  String _categoryDesc(String key, LocaleProvider lp) {
    switch (key) {
      case 'flora':
        return lp.languageCode == 'ar' ? 'اكتشف النباتات' : (lp.languageCode == 'en' ? 'Discover vegetation' : 'Découvrez la végétation');
      case 'fauna':
        return lp.languageCode == 'ar' ? 'تعلم عن الحيوانات' : (lp.languageCode == 'en' ? 'Learn about animals' : 'Apprenez sur les animaux');
      case 'ecology':
        return lp.languageCode == 'ar' ? 'احم البيئة' : (lp.languageCode == 'en' ? 'Protect the environment' : 'Protégez l\'environnement');
      case 'geography':
        return lp.languageCode == 'ar' ? 'استكشف المناظر' : (lp.languageCode == 'en' ? 'Explore landscapes' : 'Explorez les paysages');
      case 'history':
        return lp.languageCode == 'ar' ? 'سافر عبر الزمن' : (lp.languageCode == 'en' ? 'Travel through time' : 'Voyagez dans le temps');
      case 'safety':
        return lp.languageCode == 'ar' ? 'امش بأمان' : (lp.languageCode == 'en' ? 'Hike safely' : 'Randonnez en sécurité');
      default:
        return '';
    }
  }

  void _startQuiz({String? category}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizGameScreen(category: category)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lp = context.watch<LocaleProvider>();
    final quizProvider = context.watch<QuizProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverHeader(context, isDark, lp),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildScoreHero(context, isDark, lp, quizProvider),
                  const SizedBox(height: 20),
                  _buildQuickPlay(context, isDark, lp),
                  const SizedBox(height: 28),
                  _buildSectionTitle(context, lp),
                  const SizedBox(height: 14),
                ],
              ),
            ),
            _buildCategoryGrid(context, isDark, lp, quizProvider),
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom)),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverHeader(
      BuildContext context, bool isDark, LocaleProvider lp) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.quiz_rounded,
                color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(width: 10),
          Text(
            lp.t('quiz.title'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        _ProfileAvatarAction(),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildScoreHero(BuildContext context, bool isDark, LocaleProvider lp,
      QuizProvider provider) {
    final totalScore = provider.userScores.fold<int>(
        0, (sum, s) => sum + s.totalScore);
    final totalQuizzes = provider.userScores.fold<int>(
        0, (sum, s) => sum + s.quizzesCompleted);
    final totalCorrect = provider.userScores.fold<int>(
        0, (sum, s) => sum + s.correctAnswers);
    final totalQuestions = provider.userScores.fold<int>(
        0, (sum, s) => sum + s.totalQuestions);
    final avgPct =
        totalQuestions > 0 ? (totalCorrect / totalQuestions) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0E7A23), Color(0xFF1A9A35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0E7A23).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: 60,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Score ring
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: avgPct.toDouble(),
                              strokeWidth: 6,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                              strokeCap: StrokeCap.round,
                            ),
                            const Icon(Icons.emoji_events_rounded,
                                color: Colors.white, size: 30),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lp.languageCode == 'ar'
                                  ? 'مجموع النقاط'
                                  : (lp.languageCode == 'en'
                                      ? 'Total Score'
                                      : 'Score Total'),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                            Text(
                              '$totalScore pts',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statPill(
                        Icons.check_circle_outline_rounded,
                        '$totalQuizzes',
                        lp.languageCode == 'ar'
                            ? 'منجز'
                            : (lp.languageCode == 'en' ? 'Done' : 'Joués'),
                      ),
                      Container(
                          width: 1, height: 36, color: Colors.white24),
                      _statPill(
                        Icons.percent_rounded,
                        '${(avgPct * 100).round()}%',
                        lp.languageCode == 'ar'
                            ? 'متوسط'
                            : (lp.languageCode == 'en' ? 'Avg' : 'Moyenne'),
                      ),
                      Container(
                          width: 1, height: 36, color: Colors.white24),
                      _statPill(
                        Icons.star_rounded,
                        '$totalCorrect',
                        lp.languageCode == 'ar'
                            ? 'صحيح'
                            : (lp.languageCode == 'en' ? 'Correct' : 'Bonnes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        Text(label,
            style:
                const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _buildQuickPlay(
      BuildContext context, bool isDark, LocaleProvider lp) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => _startQuiz(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A2B1C)
                : const Color(0xFFF0FAF1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E7A23), Color(0xFF1A9A35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0E7A23).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lp.languageCode == 'ar'
                          ? 'اختبار عشوائي'
                          : (lp.languageCode == 'en'
                              ? 'Random Quiz'
                              : 'Quiz Aléatoire'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lp.languageCode == 'ar'
                          ? '10 أسئلة · جميع الفئات'
                          : (lp.languageCode == 'en'
                              ? '10 questions · All categories'
                              : '10 questions · Toutes catégories'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_forward_rounded,
                    color: AppTheme.primaryColor, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, LocaleProvider lp) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            lp.languageCode == 'ar'
                ? 'اختر فئة'
                : (lp.languageCode == 'en'
                    ? 'Choose a Category'
                    : 'Choisir une Catégorie'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(BuildContext context, bool isDark, LocaleProvider lp,
      QuizProvider provider) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (ctx, index) {
            final cat = _categories[index];
            final score = provider.getScoreForCategory(cat['key'] as String);
            final quizCount = provider.categoryStats
                .where((s) => s.category == cat['key'])
                .fold<int>(0, (sum, s) => sum + s.quizCount);
            return _buildCategoryCard(
                context, isDark, lp, cat, score, quizCount);
          },
          childCount: _categories.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.82,
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    bool isDark,
    LocaleProvider lp,
    Map<String, dynamic> cat,
    QuizScore? score,
    int quizCount,
  ) {
    final color = cat['color'] as Color;
    final bg = isDark ? (cat['bgDark'] as Color) : (cat['bg'] as Color);
    final pct = score != null && score.totalQuestions > 0
        ? score.correctAnswers / score.totalQuestions
        : 0.0;
    final hasPlayed = score != null;

    return GestureDetector(
      onTap: () => _startQuiz(category: cat['key'] as String),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasPlayed
                ? color.withValues(alpha: 0.35)
                : Theme.of(context).dividerColor.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + quiz count badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                    child: Text(cat['emoji'] as String,
                        style: const TextStyle(fontSize: 24)),
                  ),
                  const Spacer(),
                  if (quizCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$quizCount',
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Category name
              Text(
                _categoryName(cat['key'] as String, lp),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _categoryDesc(cat['key'] as String, lp),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        hasPlayed
                            ? '${(pct * 100).round()}%'
                            : (lp.languageCode == 'ar'
                                ? 'جديد'
                                : (lp.languageCode == 'en' ? 'New' : 'Nouveau')),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: hasPlayed ? color : Colors.grey,
                        ),
                      ),
                      if (hasPlayed)
                        Row(
                          children: [
                            Icon(Icons.star_rounded,
                                size: 12, color: Colors.amber[600]),
                            const SizedBox(width: 2),
                            Text(
                              '${score.totalScore}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber[700],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.toDouble(),
                      minHeight: 5,
                      backgroundColor:
                          color.withValues(alpha: isDark ? 0.2 : 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatarAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = user?.fullName ?? 'Guest';
    final words = displayName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final initials = words.isEmpty
        ? 'G'
        : words.length == 1
            ? words.first[0].toUpperCase()
            : (words.first[0] + words.last[0]).toUpperCase();

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      ),
      child: UserAvatarBadge(
        avatarUrl: user?.avatarUrl,
        initials: initials,
        isDark: isDark,
      ),
    );
  }
}
