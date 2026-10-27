import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/ui/app_ui.dart';
import '../../providers/pharmacy_provider.dart';
import '../../widgets/address_sheet.dart';

/// Saved addresses, used for medicine delivery and home sample collection.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<PharmacyProvider>().loadCheckoutData());
  }

  Future<void> _act(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '')), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PharmacyProvider>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: const AppTopBar(title: 'Saved addresses'),
      body: p.isLoading && p.addresses.isEmpty
          ? const AppListSkeleton(count: 3)
          : p.addresses.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: AppEmptyState(
                  illustration: Illustrations.address,
                  title: 'No saved addresses',
                  message: 'Save where you live or work for quick deliveries and home sample collection.',
                  actionLabel: 'Add address',
                  onAction: () => showAddressSheet(context),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              itemCount: p.addresses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final a = p.addresses[i];
                final def = a['isDefault'] == true;
                return AppEntrance(
                  index: i.clamp(0, 6),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: def ? AppColors.brand : AppColors.borderStrong, width: def ? 1.5 : 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: AppColors.brandVeryLight, borderRadius: BorderRadius.circular(12)),
                          child: Icon(
                            switch ((a['label'] ?? '').toString()) {
                              'Work' => LucideIcons.briefcase,
                              'Other' => LucideIcons.mapPin,
                              _ => LucideIcons.house,
                            },
                            size: 18,
                            color: AppColors.brand,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text((a['label'] ?? 'Address').toString(), style: AppType.sans(fontSize: AppType.body + 0.5, fontWeight: FontWeight.w800, color: AppColors.textStrong)),
                                  if (def) ...[
                                    const SizedBox(width: 8),
                                    const AppStatusPill(text: 'Default', color: AppColors.brand, background: AppColors.brandVeryLight),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  '${a['contactName'] ?? ''} · ${a['phone'] ?? ''}',
                                  [a['line1'], a['line2'], a['landmark'], a['city'], a['state'], a['pincode']]
                                      .where((e) => e != null && e.toString().trim().isNotEmpty)
                                      .join(', '),
                                ].join('\n'),
                                style: AppType.sans(fontSize: AppType.small, height: 1.45, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'More',
                          icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                          onSelected: (v) {
                            if (v == 'default') _act(() => p.setDefaultAddress(idOf(a)));
                            if (v == 'delete') _act(() => p.deleteAddress(idOf(a)));
                          },
                          itemBuilder: (_) => [
                            if (!def) const PopupMenuItem(value: 'default', child: Text('Make default')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: p.addresses.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showAddressSheet(context),
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              icon: const Icon(LucideIcons.plus),
              label: const Text('Add address'),
            ),
    );
  }
}
