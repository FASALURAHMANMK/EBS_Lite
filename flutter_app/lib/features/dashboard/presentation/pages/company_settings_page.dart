import 'package:ebs_lite/features/auth/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_repository.dart';
import '../../data/currency_repository.dart';
import '../../data/company_repository.dart';
import 'taxes_management_page.dart';
import 'payment_modes_page.dart';
import 'package:file_picker/file_picker.dart';
import '../../../auth/controllers/auth_notifier.dart';
import '../../../../core/api_client.dart';
import 'locations_management_page.dart';
import 'printer_settings_page.dart';

class CompanySettingsPage extends ConsumerStatefulWidget {
  const CompanySettingsPage({super.key});

  @override
  ConsumerState<CompanySettingsPage> createState() =>
      _CompanySettingsPageState();
}

class _CompanySettingsPageState extends ConsumerState<CompanySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _taxNumber = TextEditingController();
  int? _currencyId;
  String? _logoPath; // served path like /uploads/...
  List<CurrencyDto> _currencies = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _taxNumber.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final auth = ref.read(authNotifierProvider);
      final companyId = auth.company?.companyId;
      if (companyId == null) throw Exception('No company context');

      // Load currencies
      try {
        _currencies =
            await ref.read(currencyRepositoryProvider).getCurrencies();
      } catch (_) {}

      // Prefer companies API for full details; fallback to settings
      Company? comp;
      try {
        final list = await ref.read(companyRepositoryProvider).getCompanies();
        comp = list.firstWhere((c) => c.companyId == companyId,
            orElse: () => auth.company!);
      } catch (_) {
        comp = auth.company;
      }

      if (comp != null) {
        _name.text = comp.name;
        _address.text = comp.address ?? '';
        _phone.text = comp.phone ?? '';
        _email.text = comp.email ?? '';
        _taxNumber.text = comp.taxNumber ?? '';
        _currencyId = comp.currencyId;
        _logoPath = comp.logo;
      } else {
        final cfg =
            await ref.read(settingsRepositoryProvider).getCompanySettings();
        _name.text = cfg.name ?? '';
        _address.text = cfg.address ?? '';
        _phone.text = cfg.phone ?? '';
        _email.text = cfg.email ?? '';
      }
    } catch (e) {
      if (!mounted) return;
      // Fallback: prefill from auth state if permission denied
      final auth = ref.read(
          // ignore: deprecated_member_use
          authNotifierProvider);
      final fallbackName = auth.company?.name;
      if (fallbackName != null && _name.text.isEmpty) {
        _name.text = fallbackName;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text(
                'Unable to load company settings. You might not have permission.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;
    setState(() => _saving = true);
    try {
      final auth = ref.read(authNotifierProvider);
      final companyId = auth.company?.companyId;
      if (companyId == null) throw Exception('No company context');
      await ref.read(companyRepositoryProvider).updateCompany(
            companyId,
            name: _name.text.trim().isEmpty ? null : _name.text.trim(),
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            taxNumber:
                _taxNumber.text.trim().isEmpty ? null : _taxNumber.text.trim(),
            currencyId: _currencyId,
            logo: _logoPath,
          );
      // Refresh auth state to propagate changes (logo/name)
      final me = await ref.read(authRepositoryProvider).me();
      ref
          .read(authNotifierProvider.notifier)
          .setAuth(user: me.user.toUser(), company: me.company);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Company settings updated')));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Company Settings')),
      body: _loading
          ? const LinearProgressIndicator(minHeight: 2)
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Logo preview + upload
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: _logoProvider(context),
                        child: _logoPath == null
                            ? const Icon(Icons.business)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _saving ? null : _pickAndUploadLogo,
                        icon: const Icon(Icons.upload_rounded),
                        label: const Text('Upload Logo'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Company Name',
                      prefixIcon: Icon(Icons.business_rounded),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if ((v ?? '').trim().isEmpty) {
                        return 'Company name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.print_rounded),
                    title: const Text('Printer Settings (Device)'),
                    subtitle: const Text('Configure thermal printer connectivity'),
                    tileColor: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PrinterSettingsPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      prefixIcon: Icon(Icons.location_on_rounded),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_rounded),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_rounded),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _taxNumber,
                    decoration: const InputDecoration(
                      labelText: 'Company Tax ID',
                      prefixIcon: Icon(Icons.confirmation_number_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Base Currency',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_exchange_rounded),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value: _currencyId,
                        items: _currencies
                            .map((c) => DropdownMenuItem<int?>(
                                  value: c.currencyId,
                                  child: Text(
                                      '${c.code} — ${c.name}${c.symbol != null ? ' (${c.symbol})' : ''}'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _currencyId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Management sections
                  ListTile(
                    leading: const Icon(Icons.percent_rounded),
                    title: const Text('Manage Taxes'),
                    subtitle:
                        const Text('Add or edit tax types (name, percentage)'),
                    tileColor: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const TaxesManagementPage()));
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_rounded),
                    title: const Text('Payment Modes'),
                    subtitle: const Text(
                        'Manage payment modes and allowed currencies'),
                    tileColor: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const PaymentModesPage()));
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.location_city_rounded),
                    title: const Text('Manage Locations'),
                    subtitle: const Text('Add, edit, or remove locations'),
                    tileColor: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const LocationsManagementPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded),
                      label: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  ImageProvider? _logoProvider(BuildContext context) {
    final logo = _logoPath;
    if (logo == null || logo.isEmpty) return null;
    final dio = ref.read(dioProvider);
    var base = dio.options.baseUrl; // e.g. http://10.0.2.2:8080/api/v1
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    if (base.endsWith('/api/v1')) {
      base = base.substring(0, base.length - '/api/v1'.length);
    }
    final url = logo.startsWith('http') ? logo : (base + logo);
    return NetworkImage(url);
  }

  Future<void> _pickAndUploadLogo() async {
    final auth = ref.read(authNotifierProvider);
    final companyId = auth.company?.companyId;
    if (companyId == null) return;
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.single;
    final path = f.path;
    if (path == null) return;
    try {
      setState(() => _saving = true);
      final logo = await ref
          .read(companyRepositoryProvider)
          .uploadLogo(companyId, path, f.name);
      setState(() => _logoPath = logo);
      // Also refresh auth so sidebar updates immediately
      final me = await ref.read(authRepositoryProvider).me();
      ref
          .read(authNotifierProvider.notifier)
          .setAuth(user: me.user.toUser(), company: me.company);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Logo upload failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
