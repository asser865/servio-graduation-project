import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/backend_service_model.dart';
import '../../core/state/app_state.dart';
import '../../core/state/services_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class TechnicianServicesScreen extends StatefulWidget {
  const TechnicianServicesScreen({super.key});

  @override
  State<TechnicianServicesScreen> createState() =>
      _TechnicianServicesScreenState();
}

class _TechnicianServicesScreenState extends State<TechnicianServicesScreen> {
  late Set<String> _selectedIds;
  late TextEditingController _certsCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final account = context.read<SessionProvider>().account;
    _selectedIds = Set<String>.from(account?.serviceIds ?? []);
    _certsCtrl = TextEditingController(
      text: account?.skills.join('\n') ?? '',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServicesProvider>().fetchAll();
    });
  }

  @override
  void dispose() {
    _certsCtrl.dispose();
    super.dispose();
  }

  Map<String, List<BackendService>> _groupByCategory(
      List<BackendService> services) {
    final map = <String, List<BackendService>>{};
    for (final svc in services) {
      map.putIfAbsent(svc.category, () => []).add(svc);
    }
    return map;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final session = context.read<SessionProvider>();
    final account = session.account;

    final selectedServices = context
        .read<ServicesProvider>()
        .services
        .where((s) => _selectedIds.contains(s.id))
        .toList();

    final newCategories = selectedServices
        .map((s) => s.category)
        .toSet()
        .difference(Set<String>.from(account?.categories ?? []));

    final certs = _certsCtrl.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    try {
      await session.updateProfile({
        'services': _selectedIds.toList(),
        'skills': certs,
      });
      await session.refreshAccount();
      if (!mounted) return;
      if (newCategories.isNotEmpty) {
        final cats = newCategories.join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Services saved. $cats: pending admin review.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Services saved.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = context.watch<SessionProvider>().account;
    final allServices = context.watch<ServicesProvider>().services;
    final isLoading = context.watch<ServicesProvider>().isLoading;

    final verifiedCats = Set<String>.from(account?.categories ?? []);
    final pendingCats = Set<String>.from(account?.pendingCategories ?? []);

    final grouped = _groupByCategory(
      allServices.where((s) => s.isActive).toList(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Services'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: theme.textTheme.headlineMedium?.copyWith(
          fontFamily: 'Poppins',
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ServioSpacing.screenPadding,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      ...grouped.entries.map((entry) {
                        final cat = entry.key;
                        final svcs = entry.value;
                        final selectedInCat = svcs
                            .where((s) => _selectedIds.contains(s.id))
                            .length;
                        return _CategorySection(
                          category: cat,
                          services: svcs,
                          selectedCount: selectedInCat,
                          isVerified: verifiedCats.contains(cat),
                          isPending: pendingCats.contains(cat),
                          selectedIds: _selectedIds,
                          onToggle: (id, selected) {
                            setState(() {
                              if (selected) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 16),
                      Text(
                        'Certifications',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _certsCtrl,
                        maxLines: 4,
                        maxLength: 300,
                        decoration: InputDecoration(
                          hintText:
                              'One certification per line (e.g. Plumbing License 2023)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ServioPrimaryButton(
                        label: 'Save Services',
                        onPressed: _saving ? null : _save,
                        isLoading: _saving,
                      ),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CategorySection extends StatefulWidget {
  const _CategorySection({
    required this.category,
    required this.services,
    required this.selectedCount,
    required this.isVerified,
    required this.isPending,
    required this.selectedIds,
    required this.onToggle,
  });

  final String category;
  final List<BackendService> services;
  final int selectedCount;
  final bool isVerified;
  final bool isPending;
  final Set<String> selectedIds;
  final void Function(String id, bool selected) onToggle;

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.selectedCount > 0;
  }

  static const Map<String, String> _categoryLabels = {
    'plumbing': 'Plumbing',
    'electrical': 'Electrical',
    'hvac': 'HVAC / AC',
    'carpentry': 'Carpentry',
    'appliance': 'Appliance Repair',
    'handyman': 'Handyman',
    'renovation': 'Renovation',
    'painting': 'Painting',
    'flooring': 'Flooring',
    'drywall': 'Drywall',
    'roofing': 'Roofing',
    'cleaning': 'Cleaning',
    'pest-control': 'Pest Control',
    'landscaping': 'Landscaping',
    'installation': 'Installation',
    'other': 'Other',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final label = _categoryLabels[widget.category] ?? widget.category;

    Color? badgeColor;
    String? badgeLabel;
    if (widget.isVerified) {
      badgeColor = Colors.green.shade600;
      badgeLabel = 'Verified';
    } else if (widget.isPending) {
      badgeColor = Colors.orange.shade600;
      badgeLabel = 'Pending';
    } else if (widget.selectedCount > 0) {
      badgeColor = Colors.blue.shade600;
      badgeLabel = 'Re-verify';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (badgeLabel != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor!.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badgeLabel,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.selectedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${widget.selectedCount} selected',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: servio.textSecondary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: servio.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) const Divider(height: 1),
          if (_expanded)
            ...widget.services.map(
              (svc) => _ServiceRow(
                service: svc,
                isSelected: widget.selectedIds.contains(svc.id),
                onToggle: widget.onToggle,
              ),
            ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.isSelected,
    required this.onToggle,
  });

  final BackendService service;
  final bool isSelected;
  final void Function(String id, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return InkWell(
      onTap: () => onToggle(service.id, !isSelected),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (v) => onToggle(service.id, v ?? false),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${service.basePrice.toStringAsFixed(0)} ${service.priceUnitLabel}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'Inter',
                      color: servio.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
