import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+63';

  late final AnimationController _slideController;
  late final AnimationController _fadeController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  static const bool _devMode = true;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitPhoneNumber() async {
    if (!_formKey.currentState!.validate()) return;
    final fullPhone = '$_selectedCountryCode${_phoneController.text.trim()}';
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.signInWithPhone(fullPhone);
      if (mounted) {
        context.go('/otp?phone=${Uri.encodeComponent(fullPhone)}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    }
  }

  Future<void> _devBypass() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.signInAsGuest();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: size.height * 0.07),

                    // ── Logo ───────────────────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1340B0), Color(0xFF2E63E8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: AppShadows.fab,
                            ),
                            child: const Icon(
                              Icons.location_city_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'MapSumbong',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Mag-ulat ng mga isyu sa inyong komunidad',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              color: AppColors.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: size.height * 0.06),

                    // ── Phone Input ────────────────────────────────────────
                    const Text(
                      'Ipasok ang inyong numero',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PhoneField(
                      controller: _phoneController,
                      selectedCode: _selectedCountryCode,
                      maxDigits: _selectedCountryCode == '+63' ? 10 : 15,
                      onCodeChanged: (v) =>
                          setState(() => _selectedCountryCode = v),
                    ),

                    const SizedBox(height: 20),

                    // ── Submit button ──────────────────────────────────────
                    _PrimaryButton(
                      label: 'Magpadala ng OTP',
                      isLoading: authProvider.isLoading,
                      onTap: _submitPhoneNumber,
                    ),

                    // ── Error ──────────────────────────────────────────────
                    if (authProvider.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _ErrorCard(message: authProvider.error!),
                      ),

                    // ── Dev Mode ───────────────────────────────────────────
                    if (_devMode) ...[
                      const SizedBox(height: 32),
                      const _DevDivider(),
                      const SizedBox(height: 16),
                      _DevBypassButton(
                        onTap: authProvider.isLoading ? null : _devBypass,
                      ),
                    ],

                    const SizedBox(height: 40),

                    // ── Terms ──────────────────────────────────────────────
                    const Center(
                      child: Text(
                        'Sa pagpapatuloy, tinatanggap mo ang aming\nTerms of Service at Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String selectedCode;
  final int maxDigits;
  final void Function(String) onCodeChanged;

  const _PhoneField({
    required this.controller,
    required this.selectedCode,
    required this.maxDigits,
    required this.onCodeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Country code picker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.border),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedCode,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                items: const [
                  DropdownMenuItem(value: '+63', child: Text('🇵🇭 +63')),
                  DropdownMenuItem(value: '+1',  child: Text('🇺🇸 +1')),
                  DropdownMenuItem(value: '+44', child: Text('🇬🇧 +44')),
                ],
                onChanged: (v) => v != null ? onCodeChanged(v) : null,
              ),
            ),
          ),

          // Number input
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(maxDigits),
              ],
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              onFieldSubmitted: (_) {
                FocusScope.of(context).unfocus();
              },
              decoration: const InputDecoration(
                hintText: '9XX XXX XXXX',
                hintStyle: TextStyle(
                  color: AppColors.textMuted,
                  fontFamily: 'Nunito',
                  fontSize: 15,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Kinakailangan ang numero ng telepono';
                }
                final digits = v.trim();
                if (selectedCode == '+63' && digits.length != 10) {
                  return 'Maglagay ng 10-digit na mobile number';
                }
                if (selectedCode != '+63' && digits.length < 8) {
                  return 'Maglagay ng tamang numero';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLoading
              ? [AppColors.primary.withOpacity(0.7), AppColors.primaryLight.withOpacity(0.7)]
              : [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: isLoading ? [] : AppShadows.button,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.criticalLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.critical.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.critical, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: AppColors.critical,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DevDivider extends StatelessWidget {
  const _DevDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Text(
            'DEV MODE',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.orange.shade600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class _DevBypassButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _DevBypassButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.developer_mode_rounded,
                  size: 16, color: Colors.orange.shade600),
              const SizedBox(width: 8),
              Text(
                'Laktawan ang login (Dev mode)',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}