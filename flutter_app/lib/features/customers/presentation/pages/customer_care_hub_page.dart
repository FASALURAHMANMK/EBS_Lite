import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../loyalty/data/loyalty_repository.dart';
import '../../../promotions/data/promotions_repository.dart';
import '../../../promotions/presentation/pages/promotions_page.dart';
import 'collections_workbench_page.dart';
import 'customer_warranty_page.dart';
import 'loyalty_gift_redeem_page.dart';
import 'loyalty_management_page.dart';

class CustomerCareHubPage extends ConsumerStatefulWidget {
  const CustomerCareHubPage({super.key});

  @override
  ConsumerState<CustomerCareHubPage> createState() =>
      _CustomerCareHubPageState();
}

class _CustomerCareHubPageState extends ConsumerState<CustomerCareHubPage> {
  bool _loading = true;
  Object? _error;
  LoyaltySettingsDto? _settings;
  List<LoyaltyTierDto> _tiers = const [];
  int _activePromotions = 0;
  int _activeCoupons = 0;
  int _activeRaffles = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loyaltyRepo = ref.read(loyaltyRepositoryProvider);
      final promoRepo = ref.read(promotionsRepositoryProvider);
      final results = await Future.wait([
        loyaltyRepo.getSettings(),
        loyaltyRepo.getTiers(),
        promoRepo.getPromotions(activeOnly: true),
        promoRepo.getCouponSeries(activeOnly: true),
        promoRepo.getRaffleDefinitions(activeOnly: true),
      ]);
      if (!mounted) return;
      setState(() {
        _settings = results[0] as LoyaltySettingsDto;
        _tiers = (results[1] as List<LoyaltyTierDto>)
            .where((item) => item.isActive)
            .toList(growable: false);
        _activePromotions = (results[2] as List).length;
        _activeCoupons = (results[3] as List).length;
        _activeRaffles = (results[4] as List).length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Customer Care Hub'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const AppLoadingView(label: 'Loading customer care workspace')
          : _error != null
              ? AppErrorView(error: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customer-facing operations',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Use one workspace for collections, loyalty, campaigns, gift redemption, and warranty service.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _MetricChip(
                                  label: 'Active tiers',
                                  value: '${_tiers.length}',
                                ),
                                _MetricChip(
                                  label: 'Campaigns',
                                  value: '$_activePromotions',
                                ),
                                _MetricChip(
                                  label: 'Coupon series',
                                  value: '$_activeCoupons',
                                ),
                                _MetricChip(
                                  label: 'Raffles',
                                  value: '$_activeRaffles',
                                ),
                                if (_settings != null)
                                  _MetricChip(
                                    label: 'Redemption',
                                    value: _settings!.redemptionType,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      icon: Icons.payments_rounded,
                      title: 'Collections Workbench',
                      subtitle:
                          'Review overdue receivables, drill into open invoices, and record collections.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CollectionsWorkbenchPage(),
                        ),
                      ),
                    ),
                    _ActionCard(
                      icon: Icons.loyalty_rounded,
                      title: 'Loyalty Management',
                      subtitle:
                          'Maintain point rules, redemption behavior, and tier thresholds.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LoyaltyManagementPage(),
                        ),
                      ),
                    ),
                    _ActionCard(
                      icon: Icons.redeem_rounded,
                      title: 'Gift Redeem',
                      subtitle:
                          'Redeem customer points for gift items when the loyalty program uses gift-based redemption.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LoyaltyGiftRedeemPage(),
                        ),
                      ),
                    ),
                    _ActionCard(
                      icon: Icons.percent_rounded,
                      title: 'Promotions',
                      subtitle:
                          'Manage campaigns, coupon series, and raffle promotions from one place.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PromotionsPage(),
                        ),
                      ),
                    ),
                    _ActionCard(
                      icon: Icons.verified_user_rounded,
                      title: 'Warranty Management',
                      subtitle:
                          'Register warranties from invoices and search customer coverage during after-sales support.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CustomerWarrantyPage(),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}
