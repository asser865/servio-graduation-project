import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api/ai_api.dart';
import '../dev/ai_performance_dashboard.dart';
import '../../core/knowledge/finishing_knowledge_graph.dart';
import '../../core/state/room_finishing_provider.dart';
import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_animated_entry.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_status_chip.dart';

const List<String> _kStyles = <String>['modern', 'classic', 'minimal', 'luxe'];

/// Customer-facing entry point for the AI finishing model. Hands off all
/// data work to [RoomFinishingProvider]; this widget only renders state.
class AiRoomFinisherScreen extends StatefulWidget {
  const AiRoomFinisherScreen({super.key});

  @override
  State<AiRoomFinisherScreen> createState() => _AiRoomFinisherScreenState();
}

class _AiRoomFinisherScreenState extends State<AiRoomFinisherScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _lengthCtrl = TextEditingController(text: '4');
  final TextEditingController _widthCtrl = TextEditingController(text: '4');
  final TextEditingController _heightCtrl = TextEditingController(text: '2.7');
  final TextEditingController _budgetCtrl =
      TextEditingController(text: '15000');
  String _style = 'modern';
  String? _formError;

  @override
  void dispose() {
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      context.read<RoomFinishingProvider>().setImage(
            bytes: bytes,
            filename: file.name,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _formError = 'Could not load image: $e');
    }
  }

  Future<void> _showSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (source != null) await _pickImage(source);
  }

  void _submit() {
    setState(() => _formError = null);
    final length = double.tryParse(_lengthCtrl.text.trim()) ?? 0;
    final width = double.tryParse(_widthCtrl.text.trim()) ?? 0;
    final height = double.tryParse(_heightCtrl.text.trim()) ?? 0;
    final budget = int.tryParse(_budgetCtrl.text.trim()) ?? 0;

    if (length < 1 || length > 50) {
      setState(() => _formError = 'Length must be 1 – 50 m.');
      return;
    }
    if (width < 1 || width > 50) {
      setState(() => _formError = 'Width must be 1 – 50 m.');
      return;
    }
    if (height < 2 || height > 6) {
      setState(() => _formError = 'Height must be 2 – 6 m.');
      return;
    }
    if (budget < 1000) {
      setState(() => _formError = 'Budget must be at least EGP 1,000.');
      return;
    }

    final provider = context.read<RoomFinishingProvider>();
    if (!provider.hasImage) {
      setState(() => _formError = 'Please pick a room photo first.');
      return;
    }

    provider.analyze(
      lengthM: length,
      widthM: width,
      heightM: height,
      budgetEgp: budget,
      style: _style,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ServioThemeExtension servio = context.servio;
    final provider = context.watch<RoomFinishingProvider>();
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Room Finisher'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: <Widget>[
          if (provider.phase == RoomFinishingPhase.success)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Start over',
              onPressed: provider.reset,
            ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded),
              tooltip: 'AI Performance',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AiPerformanceDashboard(),
                ),
              ),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : ServioMotion.normal,
        switchInCurve: ServioMotion.spring,
        switchOutCurve: ServioMotion.spring,
        transitionBuilder: (Widget child, Animation<double> anim) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<RoomFinishingPhase>(provider.phase),
          child: _bodyForPhase(provider, servio, reduceMotion),
        ),
      ),
    );
  }

  Widget _bodyForPhase(
    RoomFinishingProvider provider,
    ServioThemeExtension servio,
    bool reduceMotion,
  ) {
    switch (provider.phase) {
      case RoomFinishingPhase.uploading:
      case RoomFinishingPhase.analyzing:
        return _AnalyzingView(
          phase: provider.phase,
          reduceMotion: reduceMotion,
          elapsedSeconds: provider.elapsedSeconds,
          onCancel: provider.cancel,
        );
      case RoomFinishingPhase.success:
        return _ResultView(
          response: provider.response!,
          graph: provider.graph!,
          onRetry: provider.reset,
          reduceMotion: reduceMotion,
        );
      case RoomFinishingPhase.error:
        return _ErrorView(
          message: provider.errorMessage ?? 'Something went wrong.',
          statusCode: provider.errorStatusCode,
          onRetry: _submit,
          onChangeImage: _showSourceSheet,
        );
      case RoomFinishingPhase.idle:
        return _IdleView(
          provider: provider,
          lengthCtrl: _lengthCtrl,
          widthCtrl: _widthCtrl,
          heightCtrl: _heightCtrl,
          budgetCtrl: _budgetCtrl,
          style: _style,
          onStyleChange: (String s) => setState(() => _style = s),
          formError: _formError,
          onPickImage: _showSourceSheet,
          onSubmit: _submit,
        );
    }
  }
}

// ── Idle (input) view ───────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.provider,
    required this.lengthCtrl,
    required this.widthCtrl,
    required this.heightCtrl,
    required this.budgetCtrl,
    required this.style,
    required this.onStyleChange,
    required this.formError,
    required this.onPickImage,
    required this.onSubmit,
  });

  final RoomFinishingProvider provider;
  final TextEditingController lengthCtrl;
  final TextEditingController widthCtrl;
  final TextEditingController heightCtrl;
  final TextEditingController budgetCtrl;
  final String style;
  final ValueChanged<String> onStyleChange;
  final String? formError;
  final VoidCallback onPickImage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final ServioThemeExtension servio = context.servio;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ServioAnimatedEntry(
            child: Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: ServioGradients.accent,
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Finish my room with AI',
                        style: theme.textTheme.headlineMedium,
                      ),
                      Text(
                        'Upload a photo. Get a plan, a render, and a budget.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: servio.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ServioAnimatedEntry(
            delay: const Duration(milliseconds: 80),
            child: _ImagePickerCard(
              provider: provider,
              onPick: onPickImage,
            ),
          ),
          const SizedBox(height: 20),
          ServioAnimatedEntry(
            delay: const Duration(milliseconds: 140),
            child: Text('Room dimensions', style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 10),
          ServioAnimatedEntry(
            delay: const Duration(milliseconds: 180),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _NumField(
                    controller: lengthCtrl,
                    label: 'Length',
                    suffix: 'm',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumField(
                    controller: widthCtrl,
                    label: 'Width',
                    suffix: 'm',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumField(
                    controller: heightCtrl,
                    label: 'Height',
                    suffix: 'm',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ServioAnimatedEntry(
            delay: const Duration(milliseconds: 220),
            child: _NumField(
              controller: budgetCtrl,
              label: 'Budget',
              suffix: 'EGP',
              integerOnly: true,
            ),
          ),
          const SizedBox(height: 20),
          ServioAnimatedEntry(
            delay: const Duration(milliseconds: 260),
            child: Text('Preferred style', style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: 10),
          ServioAnimatedEntry(
            delay: const Duration(milliseconds: 300),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final s in _kStyles)
                  _StyleChip(
                    label: s,
                    selected: s == style,
                    onTap: () => onStyleChange(s),
                  ),
              ],
            ),
          ),
          if (formError != null) ...<Widget>[
            const SizedBox(height: 16),
            ServioCard(
              backgroundColor: ServioColors.danger.withValues(alpha: 0.08),
              borderColor: ServioColors.danger,
              child: Text(
                formError!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: ServioColors.danger),
              ),
            ),
          ],
          const SizedBox(height: 24),
          ServioAnimatedEntry(
            delay: const Duration(milliseconds: 340),
            child: ServioPrimaryButton(
              label: 'Analyze with AI',
              onPressed: provider.isBusy ? null : onSubmit,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({required this.provider, required this.onPick});

  final RoomFinishingProvider provider;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final hasImage = provider.hasImage;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onPick,
      child: AnimatedContainer(
        duration: ServioMotion.micro,
        curve: ServioMotion.spring,
        height: 220,
        decoration: BoxDecoration(
          color: servio.backgroundSoft,
          borderRadius: BorderRadius.circular(ServioRadius.lg),
          border: Border.all(
            color: hasImage ? servio.accent : servio.border,
            width: hasImage ? 1.5 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.memory(
                    Uint8List.fromList(provider.selectedImageBytes!),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const <Widget>[
                          Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Change',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 36,
                    color: servio.accent,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a room photo',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'JPEG / PNG / WebP · max 10 MB',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: servio.textSecondary),
                  ),
                ],
              ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({
    required this.controller,
    required this.label,
    required this.suffix,
    this.integerOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final bool integerOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: integerOnly
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(
          integerOnly ? RegExp(r'[0-9]') : RegExp(r'[0-9.]'),
        ),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: ServioMotion.micro,
        curve: ServioMotion.spring,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color:
              selected ? servio.accent : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(ServioRadius.full),
          border: Border.all(
            color: selected ? servio.accent : servio.border,
          ),
        ),
        child: Text(
          label[0].toUpperCase() + label.substring(1),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ),
    );
  }
}

// ── Analyzing view (loading) ────────────────────────────────────────────────

class _AnalyzingView extends StatefulWidget {
  const _AnalyzingView({
    required this.phase,
    required this.reduceMotion,
    required this.elapsedSeconds,
    this.onCancel,
  });

  final RoomFinishingPhase phase;
  final bool reduceMotion;
  final int elapsedSeconds;
  final VoidCallback? onCancel;

  @override
  State<_AnalyzingView> createState() => _AnalyzingViewState();
}

class _AnalyzingViewState extends State<_AnalyzingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringController;

  static const List<String> _messages = <String>[
    'Reading your room…',
    'Composing finishing plan…',
    'Rendering the finish…',
  ];

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (!widget.reduceMotion) {
      _ringController.repeat();
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 160,
              height: 160,
              child: widget.reduceMotion
                  ? Center(
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 48,
                        color: servio.accent,
                      ),
                    )
                  : AnimatedBuilder(
                      animation: _ringController,
                      builder: (BuildContext _, Widget? child) {
                        return CustomPaint(
                          painter: _AnalyzingRingPainter(
                            progress: _ringController.value,
                            accent: servio.accent,
                            accentSoft: servio.accent.withValues(alpha: 0.18),
                          ),
                          child: child,
                        );
                      },
                      child: Center(
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 36,
                          color: servio.accent,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 24),
            // Cycles status messages every 1.6s — derived from the same
            // controller so we don't add a second Timer.
            AnimatedBuilder(
              animation: _ringController,
              builder: (BuildContext _, Widget? __) {
                final idx = widget.reduceMotion
                    ? 1
                    : ((_ringController.value * _messages.length) %
                            _messages.length)
                        .floor();
                return AnimatedSwitcher(
                  duration: ServioMotion.normal,
                  child: Text(
                    _messages[idx],
                    key: ValueKey<int>(idx),
                    style: theme.textTheme.titleMedium,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'This may take 30–90 seconds.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              _formatElapsed(widget.elapsedSeconds),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
            if (widget.onCancel != null) ...<Widget>[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: servio.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatElapsed(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s elapsed';
  }
}

class _AnalyzingRingPainter extends CustomPainter {
  _AnalyzingRingPainter({
    required this.progress,
    required this.accent,
    required this.accentSoft,
  });

  final double progress;
  final Color accent;
  final Color accentSoft;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = accentSoft;
    canvas.drawCircle(center, maxRadius - 4, ringPaint);

    // Pulsing inner rings
    for (int i = 0; i < 3; i++) {
      final t = ((progress + i / 3) % 1.0);
      final r = (maxRadius - 18) * t + 8;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = accent.withValues(alpha: (1 - t) * 0.6);
      canvas.drawCircle(center, r, paint);
    }

    // Sweep arc
    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = accent;
    final rect = Rect.fromCircle(center: center, radius: maxRadius - 4);
    canvas.drawArc(
      rect,
      progress * 2 * math.pi,
      math.pi * 0.6,
      false,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AnalyzingRingPainter old) =>
      old.progress != progress ||
      old.accent != accent ||
      old.accentSoft != accentSoft;
}

// ── Result view ─────────────────────────────────────────────────────────────

class _ResultView extends StatefulWidget {
  const _ResultView({
    required this.response,
    required this.graph,
    required this.onRetry,
    required this.reduceMotion,
  });

  final RoomAnalysisResponse response;
  final FinishingKnowledgeGraph graph;
  final VoidCallback onRetry;
  final bool reduceMotion;

  @override
  State<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<_ResultView> {
  late int _selectedIdx;

  @override
  void initState() {
    super.initState();
    _selectedIdx = widget.response.plans.indexWhere(
      (FinishingPlan p) => p.name == widget.response.recommendedPlanName,
    );
    if (_selectedIdx < 0) _selectedIdx = 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    final plans = widget.response.plans;
    final selectedPlan =
        plans.isNotEmpty ? plans[_selectedIdx] : widget.response.recommendedPlan;

    return ListView(
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      children: <Widget>[
        const ServioStatusChip(
          label: 'AI FINISH READY',
          type: ServioStatusChipType.success,
        ),
        const SizedBox(height: 16),
        _BeforeAfter(
          generatedBase64: widget.response.generatedImageBase64,
          reduceMotion: widget.reduceMotion,
        ),
        const SizedBox(height: 20),

        // ── Plan selector tabs ───────────────────────────────────────────
        if (plans.length > 1) ...<Widget>[
          _PlanTabBar(
            plans: plans,
            selectedIdx: _selectedIdx,
            recommendedName: widget.response.recommendedPlanName,
            onSelect: (int i) => setState(() => _selectedIdx = i),
          ),
          const SizedBox(height: 16),
        ],

        // ── Full plan detail ─────────────────────────────────────────────
        _FullPlanDetail(
          key: ValueKey<String>(selectedPlan.name),
          plan: selectedPlan,
          isRecommended:
              selectedPlan.name == widget.response.recommendedPlanName,
        ),

        // ── Knowledge graph ──────────────────────────────────────────────
        const SizedBox(height: 24),
        Text('Knowledge graph', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'How the AI structured this finish — exportable as a knowledge graph '
          'for downstream tooling.',
          style:
              theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
        ),
        const SizedBox(height: 10),
        _KnowledgeGraphPanel(graph: widget.graph),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: widget.onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Analyse another room'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Plan tab selector ────────────────────────────────────────────────────────

class _PlanTabBar extends StatelessWidget {
  const _PlanTabBar({
    required this.plans,
    required this.selectedIdx,
    required this.recommendedName,
    required this.onSelect,
  });

  final List<FinishingPlan> plans;
  final int selectedIdx;
  final String recommendedName;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Row(
      children: <Widget>[
        for (var i = 0; i < plans.length; i++) ...<Widget>[
          Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                decoration: BoxDecoration(
                  color: i == selectedIdx
                      ? servio.accent
                      : servio.backgroundSoft,
                  borderRadius: BorderRadius.circular(ServioRadius.md),
                  border: Border.all(
                    color: i == selectedIdx
                        ? servio.accent
                        : servio.border,
                  ),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      plans[i].name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: i == selectedIdx
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (plans[i].name == recommendedName) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        'AI Pick',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: i == selectedIdx
                              ? Colors.white70
                              : servio.accent,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (i < plans.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

// ── Full plan detail ─────────────────────────────────────────────────────────

class _FullPlanDetail extends StatelessWidget {
  const _FullPlanDetail({
    super.key,
    required this.plan,
    required this.isRecommended,
  });

  final FinishingPlan plan;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Plan name + description
        if (plan.summary.isNotEmpty) ...<Widget>[
          Text(
            plan.summary,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: servio.textSecondary),
          ),
          const SizedBox(height: 16),
        ],

        // Cost + duration + breakdown
        _PlanSummary(plan: plan),

        // Materials
        if (plan.materials.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.square_foot_rounded,
            label: 'Materials',
            count: plan.materials.length,
          ),
          const SizedBox(height: 8),
          ServioCard(
            child: Column(
              children: <Widget>[
                _TableHeader(),
                const Divider(height: 1),
                for (var i = 0; i < plan.materials.length; i++) ...<Widget>[
                  _MaterialRow(material: plan.materials[i]),
                  if (i < plan.materials.length - 1)
                    Divider(height: 1, color: servio.border),
                ],
              ],
            ),
          ),
        ],

        // Labor
        if (plan.labor.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.engineering_rounded,
            label: 'Labor',
            count: plan.labor.length,
          ),
          const SizedBox(height: 8),
          ServioCard(
            child: Column(
              children: <Widget>[
                for (var i = 0; i < plan.labor.length; i++) ...<Widget>[
                  _LaborRow(labor: plan.labor[i]),
                  if (i < plan.labor.length - 1)
                    Divider(height: 1, color: servio.border),
                ],
              ],
            ),
          ),
        ],

        // Color palette
        if (plan.palette.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.palette_outlined,
            label: 'Color palette',
          ),
          const SizedBox(height: 8),
          _PaletteRow(palette: plan.palette),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    this.count,
  });

  final IconData icon;
  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: servio.accent),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.titleMedium),
        if (count != null) ...<Widget>[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: servio.backgroundSoft,
              borderRadius: BorderRadius.circular(ServioRadius.full),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: servio.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: servio.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Expanded(flex: 3, child: Text('Item', style: style)),
          Expanded(flex: 2, child: Text('Qty', style: style)),
          Expanded(
            flex: 2,
            child: Text('Price', textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}

class _LaborRow extends StatelessWidget {
  const _LaborRow({required this.labor});

  final PlanLabor labor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      labor.trade,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (labor.description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        labor.description,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: servio.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    labor.totalEgp > 0
                        ? '${_fmt(labor.totalEgp.round())} EGP'
                        : '—',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: servio.accent),
                  ),
                  if (labor.days > 0 && labor.dailyRateEgp > 0)
                    Text(
                      '${labor.days} day${labor.days > 1 ? 's' : ''}'
                      ' × ${_fmt(labor.dailyRateEgp.round())}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BeforeAfter extends StatefulWidget {
  const _BeforeAfter({
    required this.generatedBase64,
    required this.reduceMotion,
  });

  final String? generatedBase64;
  final bool reduceMotion;

  @override
  State<_BeforeAfter> createState() => _BeforeAfterState();
}

class _BeforeAfterState extends State<_BeforeAfter> {
  late final Uint8List? _decoded = _decode(widget.generatedBase64);

  static Uint8List? _decode(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      // The model may already return raw base64 or a data URI.
      final clean = b64.contains(',') ? b64.split(',').last : b64;
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_decoded == null) {
      // No render returned. Show graceful fallback rather than blank space.
      final servio = context.servio;
      return ServioCard(
        backgroundColor: servio.backgroundSoft,
        child: Row(
          children: <Widget>[
            Icon(Icons.image_not_supported_outlined, color: servio.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'AI render unavailable for this room. Plan still applies.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(ServioRadius.lg),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: widget.reduceMotion
            ? Image.memory(_decoded, fit: BoxFit.cover, gaplessPlayback: true)
            : TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (BuildContext _, double t, Widget? child) {
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Container(color: Colors.black12),
                      ClipPath(
                        clipper: _RevealClipper(progress: t),
                        child: child,
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 400),
                          opacity: t > 0.95 ? 1.0 : 0.0,
                          child: const ServioStatusChip(
                            label: 'AFTER',
                            type: ServioStatusChipType.success,
                          ),
                        ),
                      ),
                    ],
                  );
                },
                child: Image.memory(
                  _decoded,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
      ),
    );
  }
}

class _RevealClipper extends CustomClipper<Path> {
  _RevealClipper({required this.progress});

  final double progress;

  @override
  Path getClip(Size size) {
    final path = Path();
    path.addRect(
      Rect.fromLTWH(0, 0, size.width * progress, size.height),
    );
    return path;
  }

  @override
  bool shouldReclip(covariant _RevealClipper old) => old.progress != progress;
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.plan});

  final FinishingPlan plan;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return ServioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Total cost',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: plan.totalCostEgp.toDouble(),
                      ),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (BuildContext _, double v, Widget? __) {
                        return Text(
                          '${_fmt(v.round())} EGP',
                          style: theme.textTheme.headlineMedium,
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (plan.durationDays > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      'Duration',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: servio.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plan.durationDays} days',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
            ],
          ),
          if (plan.breakdown.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            for (final entry in plan.breakdown.entries)
              _BreakdownLine(
                label: entry.key,
                amount: entry.value,
                total: plan.totalCostEgp,
              ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownLine extends StatelessWidget {
  const _BreakdownLine({
    required this.label,
    required this.amount,
    required this.total,
  });

  final String label;
  final num amount;
  final num total;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final double pct =
        total > 0 ? (amount / total).clamp(0, 1).toDouble() : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _humanise(label),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Text(
                '${_fmt(amount.round())} EGP',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(ServioRadius.full),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: pct),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (BuildContext _, double t, Widget? __) {
                return LinearProgressIndicator(
                  value: t,
                  minHeight: 8,
                  backgroundColor: servio.backgroundSoft,
                  valueColor: AlwaysStoppedAnimation<Color>(servio.accent),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({required this.palette});

  final List<String> palette;

  Color _parse(String hexOrName) {
    final h = hexOrName.trim().replaceAll('#', '');
    if (h.length == 6) {
      final v = int.tryParse(h, radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return ServioColors.accentLight;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final c in palette)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _parse(c),
                    shape: BoxShape.circle,
                    border: Border.all(color: context.servio.border),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MaterialRow extends StatelessWidget {
  const _MaterialRow({required this.material});

  final PlanMaterial material;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: Text(
              material.name,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${material.quantity} ${material.unit}'.trim(),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: servio.textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              material.estimatedCostEgp > 0
                  ? '${_fmt(material.estimatedCostEgp.round())} EGP'
                  : '—',
              textAlign: TextAlign.right,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: servio.accent),
            ),
          ),
        ],
      ),
    );
  }
}


class _KnowledgeGraphPanel extends StatelessWidget {
  const _KnowledgeGraphPanel({required this.graph});

  final FinishingKnowledgeGraph graph;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return ServioCard(
      backgroundColor: servio.backgroundSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.hub_outlined, color: servio.accent),
              const SizedBox(width: 8),
              Text(
                '${graph.nodes.length} nodes · ${graph.edges.length} edges',
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final type in _nodeTypeCounts(graph).entries)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(ServioRadius.full),
                    border: Border.all(color: servio.border),
                  ),
                  child: Text(
                    '${type.key} · ${type.value}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, int> _nodeTypeCounts(FinishingKnowledgeGraph g) {
    final m = <String, int>{};
    for (final n in g.nodes) {
      m[n.type] = (m[n.type] ?? 0) + 1;
    }
    return m;
  }
}

// ── Error view ──────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.statusCode,
    required this.onRetry,
    required this.onChangeImage,
  });

  final String message;
  final int? statusCode;
  final VoidCallback onRetry;
  final VoidCallback onChangeImage;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);
    final isAuth = statusCode == 401;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(ServioSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ServioCard(
            backgroundColor: ServioColors.danger.withValues(alpha: 0.06),
            borderColor: ServioColors.danger,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.error_outline, color: ServioColors.danger),
                    const SizedBox(width: 8),
                    Text(
                      isAuth ? 'Please sign in again' : 'Analysis failed',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: ServioColors.danger),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium,
                ),
                if (statusCode != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    'Status code: $statusCode',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: servio.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          ServioPrimaryButton(
            label: isAuth ? 'Go back' : 'Try again',
            onPressed:
                isAuth ? () => Navigator.of(context).maybePop() : onRetry,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onChangeImage,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Pick a different photo'),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

String _fmt(num n) => n.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );

String _humanise(String key) {
  return key
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'(^|\s)\S'), (m) => m[0]!.toUpperCase());
}
