import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _pinController = TextEditingController();
  Timer? _resendTicker;
  bool _canResend = false;
  int _resendTimer = 60;
  bool _isCodeComplete = false;

  @override
  void initState() {
    super.initState();
    _pinController.addListener(() {
      final isComplete = _pinController.text.trim().length == 6;
      if (isComplete != _isCodeComplete) {
        setState(() {
          _isCodeComplete = isComplete;
        });
      }
    });
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTicker?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTicker?.cancel();
    setState(() {
      _canResend = false;
      _resendTimer = 60;
    });

    _resendTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendTimer <= 1) {
        timer.cancel();
        setState(() {
          _resendTimer = 0;
          _canResend = true;
        });
        return;
      }

      setState(() {
        _resendTimer -= 1;
      });
    });
  }

  String get _maskedPhone {
    if (widget.phoneNumber.length <= 4) return widget.phoneNumber;
    final head = widget.phoneNumber.substring(0, widget.phoneNumber.length - 4);
    final tail = widget.phoneNumber.substring(widget.phoneNumber.length - 4);
    return '$head••••$tail';
  }

  Future<void> _verifyOTP() async {
    final code = _pinController.text.trim();
    if (code.length != 6) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.verifyOTP(widget.phoneNumber, code);
      if (mounted && authProvider.isAuthenticated) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hindi ma-verify ang code: ${e.toString()}'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    }
  }

  Future<void> _resendOTP() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.signInWithPhone(widget.phoneNumber);
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bagong OTP naipadala na.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hindi naipadala ang OTP: ${e.toString()}'),
            backgroundColor: AppColors.critical,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final titleStyle = const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary,
    );
    final subtitleStyle = const TextStyle(
      fontSize: 15,
      color: AppColors.textSecondary,
      height: 1.45,
    );

    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/auth'),
        ),
        title: const Text('I-verify ang Numero'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(
                  Icons.sms_rounded,
                  size: 34,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 24),

              // Title
              Text(
                'Ilagay ang 6-digit code',
                style: titleStyle,
              ),

              const SizedBox(height: 10),

              // Subtitle
              Text(
                'May ipinadala kaming OTP sa\n$_maskedPhone',
                textAlign: TextAlign.center,
                style: subtitleStyle,
              ),

              const SizedBox(height: 32),

              // PIN input
              Pinput(
                controller: _pinController,
                length: 6,
                keyboardType: TextInputType.number,
                onCompleted: (_) => _verifyOTP(),
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                ),
                submittedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(color: AppColors.primaryLight),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Verify button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (authProvider.isLoading || !_isCodeComplete)
                      ? null
                      : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: authProvider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'I-verify ang Code',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Resend code
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Walang natanggap na code? '),
                  TextButton(
                    onPressed: (_canResend && !authProvider.isLoading) ? _resendOTP : null,
                    child: Text(
                      _canResend ? 'Magpadala muli' : 'Magpadala muli sa ${_resendTimer}s',
                      style: TextStyle(
                        color: _canResend ? AppColors.primary : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),

              // Error message
              if (authProvider.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  authProvider.error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}