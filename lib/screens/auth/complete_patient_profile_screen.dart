import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aadya_plus/providers/auth_provider.dart';
import 'package:aadya_plus/utils/constants.dart';

class CompletePatientProfileScreen extends StatefulWidget {
  const CompletePatientProfileScreen({super.key});

  @override
  State<CompletePatientProfileScreen> createState() =>
      _CompletePatientProfileScreenState();
}

class _CompletePatientProfileScreenState
    extends State<CompletePatientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _dateOfBirth;
  String? _gender;

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (selected != null && mounted) {
      setState(() => _dateOfBirth = selected);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _dateOfBirth == null) return;

    try {
      await context.read<AuthProvider>().completePatientProfile(
            dateOfBirth: _dateOfBirth!,
            gender: _gender!,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Complete your profile'),
        actions: [
          TextButton(
            onPressed: auth.isLoading ? null : () => auth.logout(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.person_add_alt_1,
                  size: 72,
                  color: AppConstants.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome${auth.user?.name.isNotEmpty == true ? ', ${auth.user!.name}' : ''}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AadyaMed needs your date of birth and gender to create your patient profile before bookings and medical records can be used.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                FormField<DateTime>(
                  validator: (_) => _dateOfBirth == null
                      ? 'Please select your date of birth'
                      : null,
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: auth.isLoading ? null : _selectDate,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date of birth',
                            prefixIcon: const Icon(Icons.cake_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            errorText: field.errorText,
                          ),
                          child: Text(
                            _dateOfBirth == null
                                ? 'Select date'
                                : '${_dateOfBirth!.day.toString().padLeft(2, '0')}/'
                                    '${_dateOfBirth!.month.toString().padLeft(2, '0')}/'
                                    '${_dateOfBirth!.year}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: const Icon(Icons.wc),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                    DropdownMenuItem(
                      value: 'prefer_not_to_say',
                      child: Text('Prefer not to say'),
                    ),
                  ],
                  onChanged: auth.isLoading
                      ? null
                      : (value) => setState(() => _gender = value),
                  validator: (value) =>
                      value == null ? 'Please select your gender' : null,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
