import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _acceptTerms = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final lp = context.read<LocaleProvider>();
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lp.t('auth.register.acceptTerms')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final fullName = _fullNameController.text.trim();
    final nameParts = fullName.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : null;
    final lastName =
        nameParts.length > 1 ? nameParts.sublist(1).join(' ') : null;

    final success = await authProvider.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: firstName,
      lastName: lastName,
    );

    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.error_outline,
            color: AppTheme.errorColor,
            size: 48,
          ),
          title: Text(lp.t('auth.register.failed.title')),
          content: Text(
            authProvider.error ?? lp.t('auth.register.failed.body'),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(lp.t('common.ok')),
            ),
          ],
          actionsAlignment: MainAxisAlignment.center,
        ),
      );
      authProvider.clearError();
    }
  }

  Future<void> _continueWithGoogle() async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.loginWithGoogle();
    if (mounted && !success && authProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error!),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final lp = context.watch<LocaleProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF12181C) : const Color(0xFFF5F0EA);
    final fieldFill =
        isDark ? const Color(0xFF1E262C) : const Color(0xFFF0EBE3);
    final onSurface = theme.colorScheme.onSurface;
    final mutedText = isDark ? Colors.grey[400] : Colors.grey[500];
    final dividerColor = isDark ? Colors.white24 : Colors.grey[300]!;

    return Scaffold(
      backgroundColor: bg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero Image ──
            Stack(
              children: [
                SizedBox(
                  height: 300,
                  width: double.infinity,
                  child: Image.network(
                    'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800',
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) => Container(
                      color: const Color(0xFF1B5E20),
                      child: const Icon(Icons.landscape, size: 80, color: Colors.white54),
                    ),
                  ),
                ),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 56,
                  left: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.terrain, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'ECO-GUIDE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        lp.t('auth.tagline'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Form Card ──
            Container(
              color: bg,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 28),

                  // ── Tabs ──
                  TabBar(
                    controller: _tabController,
                    indicator: const UnderlineTabIndicator(
                      borderSide: BorderSide(color: AppTheme.primaryColor, width: 2.5),
                    ),
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: Colors.transparent,
                    labelColor: onSurface,
                    unselectedLabelColor: mutedText,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                    tabs: [
                      Tab(text: lp.t('auth.tab.signin')),
                      Tab(text: lp.t('auth.tab.create')),
                    ],
                    onTap: (index) {
                      if (index == 0) Navigator.pop(context);
                    },
                  ),

                  const SizedBox(height: 28),

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Full Name
                        _fieldLabel(lp.t('auth.field.fullname')),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _fullNameController,
                          hint: 'John Trail',
                          icon: Icons.person_outline,
                          textCapitalization: TextCapitalization.words,
                          fillColor: fieldFill,
                          isDark: isDark,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return lp.t('auth.validation.name.required');
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Email
                        _fieldLabel(lp.t('auth.field.email')),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _emailController,
                          hint: 'hiker@forest.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          fillColor: fieldFill,
                          isDark: isDark,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return lp.t('auth.validation.email.required');
                            }
                            if (!v.contains('@')) {
                              return lp.t('auth.validation.email.invalid');
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Password
                        _fieldLabel(lp.t('auth.field.password')),
                        const SizedBox(height: 8),
                        _buildField(
                          controller: _passwordController,
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          obscure: _obscurePassword,
                          fillColor: fieldFill,
                          isDark: isDark,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return lp.t('auth.validation.password.required');
                            }
                            if (v.length < 6) {
                              return lp.t('auth.validation.password.min');
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Terms checkbox
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _acceptTerms,
                                onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                                activeColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: onSurface.withValues(alpha: 0.7),
                                    height: 1.4,
                                  ),
                                  children: [
                                    TextSpan(
                                        text: lp.t('auth.register.terms.prefix')),
                                    TextSpan(
                                      text: lp.t('auth.register.terms.terms'),
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextSpan(text: lp.t('auth.register.terms.and')),
                                    TextSpan(
                                      text: lp.t('auth.register.terms.privacy'),
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Create Account button
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: authProvider.isLoading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 0,
                            ),
                            child: authProvider.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    lp.t('auth.register.cta'),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // OR CONTINUE WITH
                        Row(
                          children: [
                            Expanded(child: Divider(color: dividerColor)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                lp.t('auth.or'),
                                style: TextStyle(
                                  color: mutedText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: dividerColor)),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Social buttons
                        Row(
                          children: [
                            Expanded(child: _socialButton(
                              onTap: authProvider.isLoading ? null : _continueWithGoogle,
                              icon: Image.network(
                                'https://www.google.com/favicon.ico',
                                width: 20, height: 20,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.g_mobiledata, size: 22),
                              ),
                              label: 'Google',
                            )),
                            const SizedBox(width: 14),
                            Expanded(child: _socialButton(
                              onTap: () {},
                              icon: Icon(
                                Icons.apple,
                                size: 22,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              label: 'Apple',
                            )),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // Privacy note
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: fieldFill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: dividerColor),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.eco,
                                color: onSurface.withValues(alpha: 0.6),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: onSurface.withValues(alpha: 0.7),
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                    children: [
                                      TextSpan(text: lp.t('auth.terms.prefix')),
                                      TextSpan(
                                        text: lp.t('auth.terms.link'),
                                        style: const TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const TextSpan(text: '.'),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color fillColor,
    required bool isDark,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    final hintColor = isDark ? Colors.grey[500] : Colors.grey[400];
    final borderColor = isDark ? Colors.white12 : Colors.grey[300]!;

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: TextStyle(
        fontSize: 15,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: hintColor, fontSize: 14),
        prefixIcon: Icon(icon, color: hintColor, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      validator: validator,
    );
  }

  Widget _socialButton({
    required VoidCallback? onTap,
    required Widget icon,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E262C) : const Color(0xFFF0EBE3);
    final borderColor = isDark ? Colors.white12 : Colors.grey[300]!;
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
