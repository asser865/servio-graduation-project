import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';
import '../../design_system/widgets/servio_status_chip.dart';

class AiFinishingEstimatorScreen extends StatefulWidget {
  const AiFinishingEstimatorScreen({super.key});

  @override
  State<AiFinishingEstimatorScreen> createState() => _AiFinishingEstimatorScreenState();
}

class _AiFinishingEstimatorScreenState extends State<AiFinishingEstimatorScreen> {
  int _step = 0;
  int _roomIndex = 0;
  int _finishIndex = 1;
  bool _meterUnit = true;

  static const List<String> _rooms = <String>[
    'Living Room',
    'Kitchen',
    'Bedroom',
    'Bathroom',
    'Dining',
    'Office',
    'Outdoor',
    'Other',
  ];

  static const List<String> _finishes = <String>['Economy', 'Standard', 'Premium'];

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final progress = (_step + 1) / 4;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Finishing Estimator'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Step ${_step + 1} of 4',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (BuildContext ctx, BoxConstraints constraints) {
                return Stack(
                  children: <Widget>[
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: servio.backgroundSoft,
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                      ),
                    ),
                    AnimatedContainer(
                      duration: ServioMotion.normal,
                      curve: ServioMotion.spring,
                      height: 8,
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        gradient: ServioGradients.accent,
                        borderRadius: BorderRadius.circular(ServioRadius.full),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: ServioMotion.micro,
              child: _buildStep(context),
            ),
            const SizedBox(height: 24),
            ServioPrimaryButton(
              label: _step == 3 ? 'Book Service' : 'Continue',
              onPressed: () {
                if (_step < 3) {
                  setState(() => _step += 1);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    return switch (_step) {
      0 => _StepRoomType(
          key: const ValueKey<int>(0),
          selectedIndex: _roomIndex,
          onSelect: (int value) => setState(() => _roomIndex = value),
          rooms: _rooms,
        ),
      1 => _StepDimensions(
          key: const ValueKey<int>(1),
          meterUnit: _meterUnit,
          onUnitChange: (bool value) => setState(() => _meterUnit = value),
        ),
      2 => _StepBudget(
          key: const ValueKey<int>(2),
          finishIndex: _finishIndex,
          onFinishChanged: (int value) => setState(() => _finishIndex = value),
          finishes: _finishes,
        ),
      _ => const _StepResults(key: ValueKey<int>(3)),
    };
  }
}

class _StepRoomType extends StatelessWidget {
  const _StepRoomType({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.rooms,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final List<String> rooms;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Select Room Type', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const ServioStatusChip(label: 'AI POWERED'),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rooms.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemBuilder: (BuildContext context, int index) {
            final selected = index == selectedIndex;
            return GestureDetector(
              onTap: () => onSelect(index),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected ? servio.accent : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(ServioRadius.md),
                  border: Border.all(color: selected ? servio.accent : servio.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.weekend_outlined, color: selected ? Colors.white : servio.accent),
                    const SizedBox(height: 10),
                    Text(
                      rooms[index],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: selected ? Colors.white : null,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StepDimensions extends StatelessWidget {
  const _StepDimensions({
    super.key,
    required this.meterUnit,
    required this.onUnitChange,
  });

  final bool meterUnit;
  final ValueChanged<bool> onUnitChange;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Room Dimensions', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const ServioStatusChip(label: 'AI POWERED'),
        const SizedBox(height: 20),
        ServioCard(
          padding: const EdgeInsets.all(6),
          radius: ServioRadius.full,
          backgroundColor: servio.backgroundSoft,
          borderColor: Colors.transparent,
          child: Row(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  onTap: () => onUnitChange(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: meterUnit ? servio.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                    ),
                    child: Text(
                      'Meters',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: meterUnit ? Colors.white : servio.textSecondary,
                          ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onUnitChange(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: !meterUnit ? servio.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(ServioRadius.full),
                    ),
                    child: Text(
                      'Feet',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: !meterUnit ? Colors.white : servio.textSecondary,
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const TextField(decoration: InputDecoration(labelText: 'Length', suffixText: 'm')),
        const SizedBox(height: 12),
        const TextField(decoration: InputDecoration(labelText: 'Width', suffixText: 'm')),
        const SizedBox(height: 12),
        const TextField(decoration: InputDecoration(labelText: 'Ceiling Height', suffixText: 'm')),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: () {}, child: const Text('Use Standard (2.7m)')),
        ),
        Text(
          'Your data is processed securely by SERVIO AI',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
        ),
      ],
    );
  }
}

class _StepBudget extends StatelessWidget {
  const _StepBudget({
    super.key,
    required this.finishIndex,
    required this.onFinishChanged,
    required this.finishes,
  });

  final int finishIndex;
  final ValueChanged<int> onFinishChanged;
  final List<String> finishes;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('What is your budget range?', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        ServioCard(
          backgroundColor: servio.surfaceAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'AI Cost Suggestion',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: servio.accent),
              ),
              const SizedBox(height: 8),
              Text(
                'Based on your 24m² room, similar projects typically cost between 3,200 EGP and 5,500 EGP.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List<Widget>.generate(finishes.length, (int index) {
            final active = index == finishIndex;
            return GestureDetector(
              onTap: () => onFinishChanged(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: active ? ServioGradients.brand : null,
                  color: active ? null : servio.backgroundSoft,
                  borderRadius: BorderRadius.circular(ServioRadius.full),
                ),
                child: Text(
                  finishes[index],
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: active ? Colors.white : servio.textSecondary,
                      ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Row(
          children: const <Widget>[
            Expanded(child: TextField(decoration: InputDecoration(labelText: 'Min', prefixText: 'EGP '))),
            SizedBox(width: 12),
            Expanded(child: TextField(decoration: InputDecoration(labelText: 'Max', prefixText: 'EGP '))),
          ],
        ),
        const SizedBox(height: 20),
        Slider(
          value: 0.45,
          onChanged: (_) {},
          activeColor: servio.accent,
        ),
      ],
    );
  }
}

class _StepResults extends StatelessWidget {
  const _StepResults({super.key});

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const ServioStatusChip(
          label: 'AI ANALYSIS COMPLETE',
          type: ServioStatusChipType.success,
        ),
        const SizedBox(height: 16),
        Text(
          'Total Estimated Range',
          style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
        ),
        const SizedBox(height: 6),
        Text('3,250 EGP - 3,800 EGP', style: theme.textTheme.displayLarge?.copyWith(fontSize: 30)),
        const SizedBox(height: 12),
        const ServioStatusChip(
          label: '-5% vs. Market Average',
          type: ServioStatusChipType.success,
        ),
        const SizedBox(height: 24),
        Text('Cost Breakdown', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        const _BreakdownRow(label: 'Labor & Services', amount: '~1,600 EGP', value: 0.8),
        const SizedBox(height: 10),
        const _BreakdownRow(label: 'Materials', amount: '~1,200 EGP', value: 0.65),
        const SizedBox(height: 10),
        const _BreakdownRow(label: 'Logistics & Fees', amount: '~750 EGP', value: 0.35),
        const SizedBox(height: 20),
        Text('Estimated Materials', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        const _MaterialCard(name: 'Wall Paint', brand: 'Jotun', quantity: '4 cans', unitPrice: '280 EGP'),
        const SizedBox(height: 10),
        const _MaterialCard(name: 'Primer', brand: 'Sipes', quantity: '2 cans', unitPrice: '190 EGP'),
        const SizedBox(height: 20),
        Text('Vendor Quotes', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: const <Widget>[
            Expanded(child: _QuoteCard(name: 'Ahmed Nabil', price: '3,400 EGP')),
            SizedBox(width: 12),
            Expanded(child: _QuoteCard(name: 'Mariam Adel', price: '3,550 EGP')),
          ],
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.amount,
    required this.value,
  });

  final String label;
  final String amount;
  final double value;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label)),
            Text(
              amount,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: servio.accent),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(ServioRadius.full),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: servio.backgroundSoft,
            valueColor: AlwaysStoppedAnimation<Color>(servio.accent),
          ),
        ),
      ],
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.name,
    required this.brand,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final String brand;
  final String quantity;
  final String unitPrice;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return ServioCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '$brand • $quantity',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            unitPrice,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: servio.accent),
          ),
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({
    required this.name,
    required this.price,
  });

  final String name;
  final String price;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    return ServioCard(
      radius: ServioRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: ServioGradients.warm,
                  shape: BoxShape.circle,
                  border: Border.all(color: servio.accent, width: 2),
                ),
                child: Center(child: Text(name[0])),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: Theme.of(context).textTheme.labelLarge)),
            ],
          ),
          const SizedBox(height: 12),
          const ServioStatusChip(label: 'BEST MATCH'),
          const SizedBox(height: 12),
          Text(
            price,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: servio.accent),
          ),
        ],
      ),
    );
  }
}
