import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/state/app_state.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class ServiceAreaScreen extends StatefulWidget {
  const ServiceAreaScreen({super.key});

  @override
  State<ServiceAreaScreen> createState() => _ServiceAreaScreenState();
}

class _ServiceAreaScreenState extends State<ServiceAreaScreen> {
  late final TextEditingController _areaCtrl;
  bool _isLocked = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionProvider>();
    final initial = session.account?.locationLabel ?? '';
    _areaCtrl = TextEditingController(text: initial);
    _isLocked = initial.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    final value = _areaCtrl.text.trim();
    if (value.isEmpty) {
      _snack('Enter at least one area.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    final session = context.read<SessionProvider>();
    final error = await session.updateProfile(<String, dynamic>{
      'locationLabel': value,
    });
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (error == null) _isLocked = true;
    });
    _snack(
      error ?? 'Service area saved.',
      isError: error != null,
    );
  }

  void _handleEdit() => setState(() => _isLocked = false);

  void _snack(String message, {required bool isError}) {
    final servio = context.servio;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? servio.danger : servio.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Area'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Stack(
        children: <Widget>[
          ListView(
            padding: EdgeInsets.fromLTRB(
              ServioSpacing.screenPadding,
              ServioSpacing.screenPadding,
              ServioSpacing.screenPadding,
              120 + bottomInset,
            ),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: ServioGradients.brand,
                  borderRadius: BorderRadius.circular(ServioRadius.xl),
                  boxShadow: ServioShadows.rest,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius:
                                BorderRadius.circular(ServioRadius.sm),
                          ),
                          child: const Icon(
                            Icons.map_outlined,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Coverage Area',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Choose the cities and neighborhoods you serve so we match you to nearby jobs.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (_isLocked) ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: ServioColors.tint(servio.success),
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                    border: Border.all(
                      color: servio.success.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.check_circle_rounded,
                          size: 18, color: servio.success),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Service area saved. Tap Edit to change.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: servio.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              ServioCard(
                radius: ServioRadius.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Your Service Area',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Separate multiple areas with commas. e.g. Cairo, Giza, New Cairo.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    IgnorePointer(
                      ignoring: _isLocked,
                      child: AnimatedOpacity(
                        duration: ServioMotion.normal,
                        opacity: _isLocked ? 0.6 : 1,
                        child: TextField(
                          controller: _areaCtrl,
                          readOnly: _isLocked,
                          maxLines: 3,
                          minLines: 2,
                          maxLength: 250,
                          textInputAction: TextInputAction.done,
                          style: theme.textTheme.bodyMedium,
                          decoration: InputDecoration(
                            hintText: 'Cairo, Giza, 6th of October',
                            hintStyle: theme.textTheme.bodyMedium
                                ?.copyWith(color: servio.textSecondary),
                            filled: true,
                            fillColor: servio.backgroundSoft,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(ServioRadius.sm),
                              borderSide: BorderSide(color: servio.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(ServioRadius.sm),
                              borderSide: BorderSide(color: servio.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(ServioRadius.sm),
                              borderSide:
                                  BorderSide(color: servio.accent, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: servio.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Customers in these areas will see you in nearby search results.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  ServioSpacing.screenPadding,
                  10,
                  ServioSpacing.screenPadding,
                  12,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SizedBox(
                      width: double.infinity,
                      child: ServioPrimaryButton(
                        label: _isLocked
                            ? 'Edit Service Area'
                            : (_isSaving ? 'Saving...' : 'Save Service Area'),
                        onPressed: _isLocked
                            ? _handleEdit
                            : (_isSaving ? null : _handleSave),
                        isLoading: _isSaving,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
