import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/quizzes_provider.dart';
import '../../core/models/quiz_model.dart';
import '../../core/services/quiz_service.dart';
import '../../core/constants/app_colors.dart';

class QuizFormScreen extends StatefulWidget {
  final String? quizId;

  const QuizFormScreen({super.key, this.quizId});

  @override
  State<QuizFormScreen> createState() => _QuizFormScreenState();
}

class _QuizFormScreenState extends State<QuizFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _explanationController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _pointsController = TextEditingController(text: '10');

  List<TextEditingController> _answerControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  int _correctAnswerIndex = 0;
  QuizCategory? _category;
  bool _isActive = true;
  bool _isLoading = false;
  bool _isLoadingQuiz = false;

  bool get isEditing => widget.quizId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadQuiz();
    }
  }

  Future<void> _loadQuiz() async {
    setState(() => _isLoadingQuiz = true);
    try {
      final quiz = await QuizService.getQuiz(widget.quizId!);
      _questionController.text = quiz.question;
      _explanationController.text = quiz.explanation ?? '';
      _imageUrlController.text = quiz.imageUrl ?? '';
      _pointsController.text = quiz.points.toString();
      _correctAnswerIndex = quiz.correctAnswerIndex;
      _category = quiz.category;
      _isActive = quiz.isActive;

      _answerControllers = [];
      for (int i = 0; i < quiz.answers.length; i++) {
        _answerControllers.add(TextEditingController(text: quiz.answers[i]));
      }
      while (_answerControllers.length < 2) {
        _answerControllers.add(TextEditingController());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    }
    setState(() => _isLoadingQuiz = false);
  }

  @override
  void dispose() {
    _questionController.dispose();
    _explanationController.dispose();
    _imageUrlController.dispose();
    _pointsController.dispose();
    for (final c in _answerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final answers = _answerControllers
        .where((c) => c.text.trim().isNotEmpty)
        .map((c) => c.text.trim())
        .toList();

    if (answers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez ajouter au moins 2 reponses'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final data = {
      'question': _questionController.text.trim(),
      'answers': answers,
      'correctAnswerIndex': _correctAnswerIndex,
      'explanation': _explanationController.text.trim().isNotEmpty
          ? _explanationController.text.trim()
          : null,
      'category': _category?.name,
      'imageUrl': _imageUrlController.text.trim().isNotEmpty
          ? _imageUrlController.text.trim()
          : null,
      'points': int.parse(_pointsController.text),
      'isActive': _isActive,
    };

    final provider = context.read<QuizzesProvider>();
    bool success;

    if (isEditing) {
      success = await provider.updateQuiz(widget.quizId!, data);
    } else {
      success = await provider.createQuiz(data);
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Quiz modifie' : 'Quiz cree'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/quizzes');
    } else if (provider.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingQuiz) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go('/quizzes'),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Text(
                isEditing ? 'Modifier le quiz' : 'Nouveau quiz',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('Question', [
                    _buildTextField(
                      controller: _questionController,
                      label: 'Question',
                      maxLines: 2,
                      validator: (v) => v?.isEmpty == true ? 'Requis' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildCategoryDropdown()),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 100,
                          child: _buildTextField(
                            controller: _pointsController,
                            label: 'Points',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Reponses', [
                    ..._answerControllers.asMap().entries.map((entry) {
                      final index = entry.key;
                      final controller = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Radio<int>(
                              value: index,
                              groupValue: _correctAnswerIndex,
                              onChanged: (v) => setState(() => _correctAnswerIndex = v ?? 0),
                              activeColor: AppColors.success,
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: controller,
                                decoration: InputDecoration(
                                  labelText: 'Reponse ${index + 1}',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  suffixIcon: index >= 2
                                      ? IconButton(
                                          icon: const Icon(Icons.remove_circle, color: AppColors.error),
                                          onPressed: () {
                                            setState(() {
                                              _answerControllers.removeAt(index);
                                              if (_correctAnswerIndex >= _answerControllers.length) {
                                                _correctAnswerIndex = 0;
                                              }
                                            });
                                          },
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (_answerControllers.length < 6)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _answerControllers.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter une reponse'),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.success),
                          SizedBox(width: 8),
                          Text(
                            'Selectionnez la bonne reponse avec le bouton radio',
                            style: TextStyle(color: AppColors.success),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Explication', [
                    _buildTextField(
                      controller: _explanationController,
                      label: 'Explication (affichee apres la reponse)',
                      maxLines: 3,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Image', [
                    _buildTextField(
                      controller: _imageUrlController,
                      label: 'URL de l\'image (optionnel)',
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Statut', [
                    SwitchListTile(
                      title: const Text('Quiz actif'),
                      subtitle: const Text('Les quiz inactifs ne sont pas visibles'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                      activeColor: AppColors.primary,
                    ),
                  ]),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => context.go('/quizzes'),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(isEditing ? 'Enregistrer' : 'Creer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final categories = {
      QuizCategory.flora: 'Flore',
      QuizCategory.fauna: 'Faune',
      QuizCategory.ecology: 'Ecologie',
      QuizCategory.history: 'Histoire',
      QuizCategory.geography: 'Geographie',
      QuizCategory.safety: 'Securite',
    };

    return DropdownButtonFormField<QuizCategory?>(
      value: _category,
      decoration: InputDecoration(
        labelText: 'Categorie',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Aucune')),
        ...QuizCategory.values.map((c) {
          return DropdownMenuItem(value: c, child: Text(categories[c] ?? c.name));
        }),
      ],
      onChanged: (v) => setState(() => _category = v),
    );
  }
}
