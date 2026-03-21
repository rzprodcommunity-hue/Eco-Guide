import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../core/providers/quizzes_provider.dart';
import '../../core/models/quiz_model.dart';
import '../../core/constants/app_colors.dart';

class QuizzesScreen extends StatefulWidget {
  const QuizzesScreen({super.key});

  @override
  State<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends State<QuizzesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizzesProvider>().loadQuizzes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuizzesProvider>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${provider.total} quiz au total',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => context.go('/quizzes/create'),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau Quiz'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Error Banner
          if (provider.error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Erreur de chargement',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          provider.error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      provider.clearError();
                      provider.loadQuizzes();
                    },
                    icon: const Icon(Icons.refresh, color: AppColors.error),
                    tooltip: 'Reessayer',
                  ),
                ],
              ),
            ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildDataTable(provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(QuizzesProvider provider) {
    return Column(
      children: [
        Expanded(
          child: DataTable2(
            columnSpacing: 16,
            horizontalMargin: 16,
            minWidth: 800,
            headingRowColor: WidgetStateProperty.all(AppColors.background),
            columns: const [
              DataColumn2(label: Text('Question'), size: ColumnSize.L),
              DataColumn2(label: Text('Categorie')),
              DataColumn2(label: Text('Points')),
              DataColumn2(label: Text('Statut')),
              DataColumn2(label: Text('Actions'), fixedWidth: 120),
            ],
            rows: provider.quizzes.map((quiz) => _buildRow(quiz, provider)).toList(),
          ),
        ),
        _buildPagination(provider),
      ],
    );
  }

  DataRow _buildRow(QuizModel quiz, QuizzesProvider provider) {
    return DataRow(
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                quiz.question,
                style: const TextStyle(fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${quiz.answers.length} reponses',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        DataCell(_buildCategoryChip(quiz.category)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${quiz.points} pts',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DataCell(_buildStatusChip(quiz.isActive)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => context.go('/quizzes/edit/${quiz.id}'),
                icon: const Icon(Icons.edit, color: AppColors.secondary),
                tooltip: 'Modifier',
              ),
              IconButton(
                onPressed: () => _confirmDelete(quiz, provider),
                icon: const Icon(Icons.delete, color: AppColors.error),
                tooltip: 'Supprimer',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(QuizCategory? category) {
    if (category == null) {
      return const Text('-');
    }

    final colors = {
      QuizCategory.flora: Colors.green,
      QuizCategory.fauna: Colors.orange,
      QuizCategory.ecology: Colors.teal,
      QuizCategory.history: Colors.purple,
      QuizCategory.geography: Colors.blue,
      QuizCategory.safety: Colors.red,
    };

    final labels = {
      QuizCategory.flora: 'Flore',
      QuizCategory.fauna: 'Faune',
      QuizCategory.ecology: 'Ecologie',
      QuizCategory.history: 'Histoire',
      QuizCategory.geography: 'Geographie',
      QuizCategory.safety: 'Securite',
    };

    final color = colors[category] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        labels[category] ?? category.name,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withOpacity(0.1)
            : AppColors.textHint.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Actif' : 'Inactif',
        style: TextStyle(
          color: isActive ? AppColors.success : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPagination(QuizzesProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: provider.currentPage > 1
                ? () => provider.loadQuizzes(page: provider.currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 16),
          Text('Page ${provider.currentPage} sur ${provider.totalPages}'),
          const SizedBox(width: 16),
          IconButton(
            onPressed: provider.currentPage < provider.totalPages
                ? () => provider.loadQuizzes(page: provider.currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(QuizModel quiz, QuizzesProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer ce quiz ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await provider.deleteQuiz(quiz.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
