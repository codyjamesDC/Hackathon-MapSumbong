import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _selectedCountryCode = '+63';

  // ── Set this to false before releasing to production ──────────────────────
  static const bool _devMode = true;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitPhoneNumber() async {
    if (!_formKey.currentState!.validate()) return;

    final fullPhone =
        '$_selectedCountryCode${_phoneController.text.trim()}';
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.signInWithPhone(fullPhone);
      if (mounted) {
        context.go('/otp?phone=${Uri.encodeComponent(fullPhone)}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),

                // Logo + title
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .primaryColor
                              .withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 56,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'MapSumbong',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Report disasters in your community',
                        style: TextStyle(fontSize: 15, color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 56),

                const Text(
                  'Enter your phone number',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                const Text(
                  'We\'ll send a one-time code to verify your identity.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Phone input row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Country code
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCountryCode,
                          items: const [
                            DropdownMenuItem(
                                value: '+63',
                                child: Text('+63 🇵🇭')),
                            DropdownMenuItem(
                                value: '+1', child: Text('+1 🇺🇸')),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedCountryCode = v!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Number field
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone number',
                          hintText: '9123456789',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Phone number is required';
                          }
                          if (v.trim().length < 9) {
                            return 'Enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading
                        ? null
                        : _submitPhoneNumber,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Continue',
                            style: TextStyle(fontSize: 16)),
                  ),
                ),

                // Error
                if (authProvider.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authProvider.error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── Dev bypass ─────────────────────────────────────────────
                if (_devMode) ...[
                  const SizedBox(height: 32),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('DEV ONLY',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: authProvider.isLoading
                          ? null
                          : _devBypass,
                      icon: const Icon(Icons.developer_mode, size: 18),
                      label: const Text('Skip login (Dev mode)'),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        side: BorderSide(color: Colors.orange.shade300),
                        foregroundColor: Colors.orange.shade700,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Remove before production release',
                      style: TextStyle(
                          fontSize: 11, color: Colors.orange.shade400),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}