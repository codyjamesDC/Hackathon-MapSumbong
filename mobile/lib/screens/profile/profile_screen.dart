import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _displayNameController;
  late final TextEditingController _barangayController;
  late final TextEditingController _purokController;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    _displayNameController = TextEditingController(text: user?.displayName ?? '');
    _barangayController = TextEditingController(text: user?.barangay ?? '');
    _purokController = TextEditingController(text: user?.purok ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _barangayController.dispose();
    _purokController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.updateProfile(
      displayName: _displayNameController.text.trim(),
      barangay: _barangayController.text.trim(),
      purok: _purokController.text.trim(),
    );

    if (!mounted) return;

    if (auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error!),
          backgroundColor: AppColors.critical,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated.'),
        backgroundColor: AppColors.low,
      ),
    );
  }

  Future<void> _signOut() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.signOut();
    if (!mounted) return;
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoTile(
                label: 'Anonymous ID',
                value: user?.anonymousId ?? '-',
              ),
              const SizedBox(height: 10),
              _InfoTile(
                label: 'Current Barangay',
                value: user?.barangay?.isNotEmpty == true ? user!.barangay! : '-',
              ),
              const SizedBox(height: 20),
              const Text(
                'Edit Profile',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Display Name',
                controller: _displayNameController,
                hintText: 'Juan Dela Cruz',
              ),
              const SizedBox(height: 10),
              _Field(
                label: 'Barangay',
                controller: _barangayController,
                hintText: 'Batong Malake',
              ),
              const SizedBox(height: 10),
              _Field(
                label: 'Purok (optional)',
                controller: _purokController,
                hintText: 'Purok 3',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: auth.isLoading ? null : _saveProfile,
                  icon: auth.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Save Profile'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: auth.isLoading ? null : _signOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.critical,
                    side: const BorderSide(color: AppColors.critical),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;

  const _Field({
    required this.label,
    required this.controller,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(
        fontFamily: 'Nunito',
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      validator: (value) {
        if (label != 'Purok (optional)' && (value == null || value.trim().isEmpty)) {
          return 'Required';
        }
        return null;
      },
    );
  }
}
