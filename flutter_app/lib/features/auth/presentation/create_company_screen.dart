import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_notifier.dart';
import '../../dashboard/presentation/dashboard_screen.dart';

class CreateCompanyScreen extends ConsumerStatefulWidget {
  const CreateCompanyScreen({super.key});

  @override
  ConsumerState<CreateCompanyScreen> createState() => _CreateCompanyScreenState();
}

class _CreateCompanyScreenState extends ConsumerState<CreateCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Create Company')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Company Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email (optional)'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: state.isLoading
                    ? null
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          final company = await ref
                              .read(authNotifierProvider.notifier)
                              .createCompany(
                                name: _nameController.text,
                                email: _emailController.text.isEmpty
                                    ? null
                                    : _emailController.text,
                              );
                          if (company != null && mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const DashboardScreen()),
                              (route) => false,
                            );
                          } else if (mounted && state.error != null) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text(state.error!)));
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: state.isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
