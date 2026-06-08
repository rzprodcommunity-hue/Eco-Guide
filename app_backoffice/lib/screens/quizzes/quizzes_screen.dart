import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/providers/quizzes_provider.dart';
import '../../core/models/quiz_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/responsive.dart';
import '../../core/services/supabase_storage_service.dart';

class QuestionDraft {
  final TextEditingController questionCtrl = TextEditingController();
  final TextEditingController correctCtrl = TextEditingController();
  final TextEditingController distractor1Ctrl = TextEditingController();
  final TextEditingController distractor2Ctrl = TextEditingController();

  String? mediaUrl;
  Uint8List? mediaBytes;
  bool isUploading = false;

  void dispose() {
    questionCtrl.dispose();
    correctCtrl.dispose();
    distractor1Ctrl.dispose();
    distractor2Ctrl.dispose();
  }

  bool get isValid =>
      questionCtrl.text.trim().isNotEmpty &&
      correctCtrl.text.trim().isNotEmpty &&
      distractor1Ctrl.text.trim().isNotEmpty;
}

class QuizzesScreen extends StatefulWidget {
  const QuizzesScreen({super.key});

  @override
  State<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends State<QuizzesScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _editingId;
  final _pointsController = TextEditingController(text: '50');

  List<QuestionDraft> _questions = [QuestionDraft()];

  QuizCategory _selectedCategory = QuizCategory.flora;
  bool _isSaving = false;

  // Client-side search / filter / pagination state for the quizzes list.
  final _searchController = TextEditingController();
  String _searchQuery = '';
  QuizCategory? _filterCategory; // null => 'Toutes'
  int _quizPage = 0;
  static const int _quizPageSize = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizzesProvider>().loadQuizzes();
    });
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _searchController.dispose();
    for (var q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  /// Applies the search query and category filter (client-side) over the full
  /// list of quizzes loaded in the provider.
  List<QuizModel> _filteredQuizzes(QuizzesProvider provider) {
    final query = _searchQuery.trim().toLowerCase();
    return provider.quizzes.where((q) {
      final matchesCategory =
          _filterCategory == null || q.category == _filterCategory;
      if (!matchesCategory) return false;
      if (query.isEmpty) return true;
      final inQuestion = q.question.toLowerCase().contains(query);
      final inCategory =
          (q.category?.name.toLowerCase().contains(query) ?? false) ||
              q.categoryLabel.toLowerCase().contains(query);
      return inQuestion || inCategory;
    }).toList();
  }

  void _addQuestionBlock() {
    setState(() {
      _questions.add(QuestionDraft());
    });
  }

  void _removeQuestionBlock(int index) {
    if (_questions.length > 1) {
      setState(() {
        final q = _questions.removeAt(index);
        q.dispose();
      });
    }
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      for (var q in _questions) {
        q.dispose();
      }
      _questions = [QuestionDraft()];
      _pointsController.text = '50';
      _selectedCategory = QuizCategory.flora;
    });
  }

  void _editQuiz(QuizModel quiz) {
    _clearForm();
    setState(() {
      _editingId = quiz.id;
      _selectedCategory = quiz.category ?? QuizCategory.flora;
      _pointsController.text = quiz.points.toString();

      final q = _questions.first;
      q.questionCtrl.text = quiz.question;
      q.mediaUrl = quiz.imageUrl;

      if (quiz.answers.isNotEmpty) {
        final correctIdx = quiz.correctAnswerIndex;
        q.correctCtrl.text = quiz.answers.length > correctIdx
            ? quiz.answers[correctIdx]
            : '';

        final distractors = [];
        for (int i = 0; i < quiz.answers.length; i++) {
          if (i != correctIdx) distractors.add(quiz.answers[i]);
        }

        q.distractor1Ctrl.text = distractors.isNotEmpty ? distractors[0] : '';
        q.distractor2Ctrl.text = distractors.length > 1 ? distractors[1] : '';
      }
    });
  }

  Future<void> _pickAndUploadImage(QuestionDraft q) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;
    setState(() {
      q.mediaBytes = file.bytes;
      q.isUploading = true;
    });

    try {
      final ext = file.name.split('.').last.toLowerCase();
      final contentType = switch (ext) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final url = await SupabaseStorageService.uploadBytes(
        bucket: 'images',
        fileName: file.name,
        bytes: file.bytes!,
        contentType: contentType,
      );
      setState(() {
        q.mediaUrl = url;
        q.isUploading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo téléchargée !'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => q.isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de téléchargement : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveQuiz() async {
    // Validate all instances
    bool isValid = true;
    for (var q in _questions) {
      if (!q.isValid) isValid = false;
    }

    if (!isValid || !_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir toutes les questions et réponses.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final provider = context.read<QuizzesProvider>();

    bool allSuccess = true;

    try {
      if (_editingId != null) {
        // Edit mode (single question)
        final q = _questions.first;
        final answers = [
          q.correctCtrl.text.trim(),
          q.distractor1Ctrl.text.trim(),
        ];
        if (q.distractor2Ctrl.text.trim().isNotEmpty)
          answers.add(q.distractor2Ctrl.text.trim());

        final data = {
          'question': q.questionCtrl.text.trim(),
          'answers': answers,
          'correctAnswerIndex': 0,
          'points': int.tryParse(_pointsController.text) ?? 50,
          'category': _selectedCategory.name,
          'imageUrl': q.mediaUrl,
          'isActive': true,
        };

        allSuccess = await provider.updateQuiz(_editingId!, data);
      } else {
        // Create mode (multiple questions)
        for (var q in _questions) {
          final answers = [
            q.correctCtrl.text.trim(),
            q.distractor1Ctrl.text.trim(),
          ];
          if (q.distractor2Ctrl.text.trim().isNotEmpty)
            answers.add(q.distractor2Ctrl.text.trim());

          final data = {
            'question': q.questionCtrl.text.trim(),
            'answers': answers,
            'correctAnswerIndex': 0,
            'points': int.tryParse(_pointsController.text) ?? 50,
            'category': _selectedCategory.name,
            'imageUrl': q.mediaUrl,
            'isActive': true,
          };
          final res = await provider.createQuiz(data);
          if (!res) allSuccess = false;
        }
      }

      setState(() => _isSaving = false);
      if (allSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _editingId != null
                    ? 'Quiz mis à jour !'
                    : '${_questions.length} question(s) créée(s) !',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
        _clearForm();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.error ?? 'Échec de l\'enregistrement complet'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _deleteQuiz(QuizModel quiz) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Supprimer le quiz'),
          ],
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer ce quiz ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success =
                  await context.read<QuizzesProvider>().deleteQuiz(quiz.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? 'Quiz supprimé' : 'Échec de la suppression'),
                  backgroundColor:
                      success ? AppColors.success : AppColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuizzesProvider>();

    final isCompact = Responsive.isCompact(context);

    final headerTitle = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestion des quiz',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Créez et gérez des défis éducatifs pour les randonneurs.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
      ],
    );

    final createButton = ElevatedButton.icon(
      onPressed: _clearForm,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Créer un nouveau quiz'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
    );

    return Padding(
      padding: Responsive.pagePadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCompact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headerTitle,
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: createButton),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [headerTitle, createButton],
            ),
          SizedBox(height: isCompact ? 20 : 32),
          Expanded(
            child: isCompact
                // On compact / mobile we use a plain ListView so that nothing
                // nested inside (form / recent quizzes) needs its own
                // scrollable — that was making the whole content silently
                // collapse to 0 px height.
                ? ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildQuizForm(),
                      const SizedBox(height: 24),
                      _buildInsightsCard(provider),
                      const SizedBox(height: 24),
                      _buildRecentQuizzes(provider),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 13, child: _buildQuizForm()),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 10,
                        child: Column(
                          children: [
                            _buildInsightsCard(provider),
                            const SizedBox(height: 24),
                            Expanded(child: _buildRecentQuizzes(provider)),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizForm() {
    final isCompact = Responsive.isCompact(context);
    final formContent = Padding(
      padding: EdgeInsets.all(isCompact ? 16 : 32),
      child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestion des quiz',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              
              _ResponsiveTriRow(
                isCompact: isCompact,
                spacing: 20,
                children: [
                  _buildLabeledField(
                    'Catégorie',
                    DropdownButtonFormField<QuizCategory>(
                      value: _selectedCategory,
                      isExpanded: true,
                      decoration: _fieldDecoration(),
                      items: QuizCategory.values.map((cat) {
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(cat.name.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (v) => setState(
                        () => _selectedCategory = v ?? QuizCategory.flora,
                      ),
                    ),
                  ),
                  _buildLabeledField(
                    'Points de récompense',
                    TextFormField(
                      controller: _pointsController,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration(),
                      validator: (v) =>
                          v?.isEmpty == true ? 'Requis' : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 24 : 40),
              Container(height: 1, color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Questions',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (_editingId ==
                      null) // only allow multiple additions in create mode
                    TextButton.icon(
                      onPressed: _addQuestionBlock,
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.success,
                        size: 16,
                      ),
                      label: const Text(
                        'Ajouter une question',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // dynamic list of questions
              ...List.generate(
                _questions.length,
                (index) => _buildQuestionBlock(index, _questions[index]),
              ),

              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _clearForm,
                    child: const Text(
                      'Réinitialiser le formulaire',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveQuiz,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _editingId == null ? 'Publier le quiz' : 'Mettre à jour le quiz',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    

    final decoration = BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );

    // Compact (mobile / narrow): no inner scroll — the parent ListView
    // handles the page scroll. Desktop: keep the inner scroll so the form
    // can scroll independently of the sidebar.
    return Container(
      decoration: decoration,
      child: isCompact ? formContent : SingleChildScrollView(child: formContent),
    );
  }

  InputDecoration _fieldDecoration({String? hintText, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Theme.of(context).cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildLabeledField(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  Widget _buildQuestionBlock(int index, QuestionDraft q) {
    final isCompact = Responsive.isCompact(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor, // Professional slight contrast
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Détails de la question',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (_questions.length > 1)
                IconButton(
                  onPressed: () => _removeQuestionBlock(index),
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.error,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Question text field + photo upload: side-by-side on desktop,
          // stacked on mobile.
          isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildQuestionTextField(q),
                    const SizedBox(height: 12),
                    Center(child: _buildPhotoUpload(q)),
                    const SizedBox(height: 16),
                    _buildAnswerFields(q, stacked: true),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildQuestionTextField(q),
                          const SizedBox(height: 16),
                          _buildAnswerFields(q, stacked: false),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildPhotoUpload(q),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildQuestionTextField(QuestionDraft q) {
    return TextFormField(
      controller: q.questionCtrl,
      decoration: _fieldDecoration(hintText: 'Saisissez le texte de la question...'),
      validator: (v) => v?.trim().isEmpty == true ? 'Requis' : null,
    );
  }

  Widget _buildAnswerFields(QuestionDraft q, {required bool stacked}) {
    final correct = TextFormField(
      controller: q.correctCtrl,
      decoration: InputDecoration(
        hintText: 'Bonne réponse...',
        fillColor: Theme.of(context).cardColor,
        filled: true,
        prefixIcon: const Icon(
          Icons.check_circle,
          color: AppColors.success,
          size: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.success),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.success),
        ),
      ),
    );
    final d1 = TextFormField(
      controller: q.distractor1Ctrl,
      decoration: _fieldDecoration(hintText: 'Mauvaise réponse 1'),
    );
    final d2 = TextFormField(
      controller: q.distractor2Ctrl,
      decoration: _fieldDecoration(hintText: 'Mauvaise réponse 2'),
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          correct,
          const SizedBox(height: 10),
          d1,
          const SizedBox(height: 10),
          d2,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: correct),
        const SizedBox(width: 12),
        Expanded(child: d1),
        const SizedBox(width: 12),
        Expanded(child: d2),
      ],
    );
  }

  Widget _buildPhotoUpload(QuestionDraft q) {
    // Photo Upload Component
    return GestureDetector(
                onTap: q.isUploading ? null : () => _pickAndUploadImage(q),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: q.isUploading
                      ? const Center(child: CircularProgressIndicator())
                      : (q.mediaBytes != null || q.mediaUrl != null)
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: q.mediaBytes != null
                                  ? Image.memory(
                                      q.mediaBytes!,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      q.mediaUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.image),
                                    ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_photo_alternate_outlined,
                              color: AppColors.success,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ajouter\nune photo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
    );
  }

  Widget _buildInsightsCard(QuizzesProvider provider) {
    // Real statistics derived from the loaded quizzes.
    final distinctCategories = provider.quizzes
        .map((q) => q.category)
        .whereType<QuizCategory>()
        .toSet()
        .length;
    final totalPoints = provider.quizzes
        .fold<int>(0, (sum, q) => sum + q.points);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF2C6B3F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // const Text(
          //   'Statistiques des quiz',
          //   style: TextStyle(
          //     color: Colors.white,
          //     fontSize: 16,
          //     fontWeight: FontWeight.bold,
          //   ),
          // ),
          // const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildInsightStat('${provider.total}', 'Questions'),
              ),
              _buildInsightDivider(),
              Expanded(
                child: _buildInsightStat('$distinctCategories', 'Catégories'),
              ),
              _buildInsightDivider(),
              Expanded(
                child: _buildInsightStat('$totalPoints', 'Points total'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildInsightDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.2),
    );
  }

  Widget _quizIconFallback() => Container(
        width: 44,
        height: 44,
        color: AppColors.success.withValues(alpha: 0.1),
        child: const Icon(Icons.help_outline, color: AppColors.success),
      );

  Widget _buildRecentQuizzes(QuizzesProvider provider) {
    final isCompact = Responsive.isCompact(context);
    if (provider.isLoading && provider.quizzes.isEmpty)
      return const Center(child: CircularProgressIndicator());

    // Apply search + category filter client-side over the full list.
    final filtered = _filteredQuizzes(provider);

    // Clamp the current page so it stays within bounds after filtering.
    final totalItems = filtered.length;
    final pageCount =
        totalItems == 0 ? 1 : ((totalItems - 1) ~/ _quizPageSize) + 1;
    if (_quizPage > pageCount - 1) _quizPage = pageCount - 1;
    if (_quizPage < 0) _quizPage = 0;

    final startIndex = _quizPage * _quizPageSize;
    final pageItems =
        filtered.skip(startIndex).take(_quizPageSize).toList();

    final rangeStart = totalItems == 0 ? 0 : startIndex + 1;
    final rangeEnd =
        (startIndex + pageItems.length).clamp(0, totalItems);

    // On compact the list must not scroll on its own — otherwise it fights
    // the parent page ListView and the scroll gets stuck. Let it shrink-wrap
    // so the parent handles all scrolling. On desktop it keeps its own scroll.
    final Widget recentList = pageItems.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Aucun quiz trouvé.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          )
        : ListView.separated(
                  shrinkWrap: isCompact,
                  physics:
                      isCompact ? const NeverScrollableScrollPhysics() : null,
                  itemCount: pageItems.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final quiz = pageItems[index];
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.01),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child:
                                (quiz.imageUrl != null && quiz.imageUrl!.isNotEmpty)
                                    ? Image.network(
                                        quiz.imageUrl!,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _quizIconFallback(),
                                      )
                                    : _quizIconFallback(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  quiz.question,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        quiz.category?.name.toUpperCase() ??
                                            'AUCUNE',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${quiz.points} points',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.edit_note,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  size: 22,
                                ),
                                onPressed: () => _editQuiz(quiz),
                              ),
                              const SizedBox(height: 8),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                onPressed: () => _deleteQuiz(quiz),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text(
        //   'Quiz récents',
        //   style: TextStyle(
        //     fontSize: 16,
        //     fontWeight: FontWeight.bold,
        //     color: Theme.of(context).colorScheme.onSurface,
        //   ),
        // ),
        // const SizedBox(height: 12),
        // Search field.
        TextField(
          controller: _searchController,
          decoration: _fieldDecoration(
            hintText: 'Rechercher un quiz...',
            prefixIcon: Icon(
              Icons.search,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          onChanged: (value) => setState(() {
            _searchQuery = value;
            _quizPage = 0;
          }),
        ),
        const SizedBox(height: 12),
        // Category filter chips ('Toutes' + one per category).
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildCategoryChip(null, 'Toutes'),
            ...QuizCategory.values.map(
              (cat) => _buildCategoryChip(cat, _categoryLabel(cat)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        isCompact ? recentList : Expanded(child: recentList),
        const SizedBox(height: 12),
        _buildPaginationFooter(
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          total: totalItems,
          pageCount: pageCount,
        ),
      ],
    );
  }

  String _categoryLabel(QuizCategory cat) {
    switch (cat) {
      case QuizCategory.flora:
        return 'Flore';
      case QuizCategory.fauna:
        return 'Faune';
      case QuizCategory.ecology:
        return 'Écologie';
      case QuizCategory.history:
        return 'Histoire';
      case QuizCategory.geography:
        return 'Géographie';
      case QuizCategory.safety:
        return 'Sécurité';
    }
  }

  Widget _buildCategoryChip(QuizCategory? category, String label) {
    final selected = _filterCategory == category;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() {
        _filterCategory = category;
        _quizPage = 0;
      }),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
      ),
      selectedColor: AppColors.success,
      backgroundColor: Theme.of(context).cardColor,
      side: BorderSide(
        color: selected ? AppColors.success : Theme.of(context).dividerColor,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildPaginationFooter({
    required int rangeStart,
    required int rangeEnd,
    required int total,
    required int pageCount,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final canPrev = _quizPage > 0;
    final canNext = _quizPage < pageCount - 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            'Affichage $rangeStart-$rangeEnd sur $total',
            style: TextStyle(
              fontSize: 12,
              color: onSurface.withValues(alpha: 0.6),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: canPrev ? () => setState(() => _quizPage--) : null,
              icon: const Icon(Icons.chevron_left, size: 18),
              label: const Text('Précédent'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.success,
                disabledForegroundColor: onSurface.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: canNext ? () => setState(() => _quizPage++) : null,
              icon: const Icon(Icons.chevron_right, size: 18),
              label: const Text('Suivant'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.success,
                disabledForegroundColor: onSurface.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Lays out 3 children side-by-side when `isCompact` is false, or stacked
/// in a single column with [spacing] between them when compact (mobile).
class _ResponsiveTriRow extends StatelessWidget {
  final bool isCompact;
  final double spacing;
  final List<Widget> children;

  const _ResponsiveTriRow({
    required this.isCompact,
    required this.children,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) SizedBox(height: spacing),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i != children.length - 1) SizedBox(width: spacing),
        ],
      ],
    );
  }
}
