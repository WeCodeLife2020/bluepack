import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_profile.dart';

/// First screen — collects user details before navigating to Add Device.
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _heightController = TextEditingController(text: '170');
  final _weightController = TextEditingController(text: '70');
  final _ageController = TextEditingController(text: '25');
  bool _isMale = true;
  bool _submitting = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final profile = await UserProfile.load();
    if (profile != null && mounted) {
      setState(() {
        _nameController.text = profile.name;
        _heightController.text = profile.heightCm.round().toString();
        _weightController.text = profile.weightKg.round().toString();
        _ageController.text = profile.age.toString();
        _isMale = profile.isMale;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final profile = UserProfile(
      name: _nameController.text.trim(),
      heightCm: double.parse(_heightController.text.trim()),
      weightKg: double.parse(_weightController.text.trim()),
      age: int.parse(_ageController.text.trim()),
      isMale: _isMale,
    );

    await profile.save();

    if (mounted) {
      Navigator.of(context).pop(profile);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String label, String hint, IconData icon) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  // Header
                  Icon(
                    Icons.person_outline_rounded,
                    size: 56,
                    color: cs.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your Profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'We need a few details for accurate\nhealth measurements',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withValues(alpha: 0.5),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Name
                  TextFormField(
                    controller: _nameController,
                    decoration: _inputDecoration('Name', 'Enter your name', Icons.badge_outlined),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 16),

                  // Height & Weight row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _heightController,
                          decoration: _inputDecoration('Height', 'cm', Icons.height),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final n = int.tryParse(v);
                            if (n == null || n < 50 || n > 250) return '50–250';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _weightController,
                          decoration: _inputDecoration('Weight', 'kg', Icons.monitor_weight_outlined),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final n = int.tryParse(v);
                            if (n == null || n < 20 || n > 300) return '20–300';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Age
                  TextFormField(
                    controller: _ageController,
                    decoration: _inputDecoration('Age', 'years', Icons.cake_outlined),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final n = int.tryParse(v);
                      if (n == null || n < 5 || n > 120) return '5–120';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Gender
                  Text(
                    'Gender',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _GenderCard(
                          icon: Icons.male,
                          label: 'Male',
                          selected: _isMale,
                          color: const Color(0xFF448AFF),
                          onTap: () => setState(() => _isMale = true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _GenderCard(
                          icon: Icons.female,
                          label: 'Female',
                          selected: !_isMale,
                          color: const Color(0xFFFF4081),
                          onTap: () => setState(() => _isMale = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // Submit
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _GenderCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: selected ? color : cs.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
