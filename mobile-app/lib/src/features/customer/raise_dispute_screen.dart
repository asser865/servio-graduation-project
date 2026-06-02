import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/models/booking_model.dart';
import '../../core/state/disputes_provider.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class RaiseDisputeScreen extends StatefulWidget {
  const RaiseDisputeScreen({required this.booking, super.key});
  final BookingModel booking;

  @override
  State<RaiseDisputeScreen> createState() => _RaiseDisputeScreenState();
}

class _RaiseDisputeScreenState extends State<RaiseDisputeScreen>
    with SingleTickerProviderStateMixin {
  static const _categories = [
    ('Quality of Work', 'quality'),
    ('Incorrect Pricing', 'pricing'),
    ('Worker No-Show', 'no_show'),
    ('Property Damage', 'damage'),
    ('Other', 'other'),
  ];

  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  String _category = 'quality';
  final _reasonCtrl = TextEditingController();
  final List<List<int>> _evidenceBytes = [];
  final List<String> _evidenceFilenames = [];
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: ServioMotion.page);
    _fade = CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.0, 0.6, curve: ServioMotion.spring),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _anim,
      curve: const Interval(0.1, 0.7, curve: ServioMotion.spring),
    ));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    if (_evidenceBytes.length >= 4) return;
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _evidenceBytes.add(bytes);
      _evidenceFilenames.add(file.name);
    });
  }

  Future<void> _submit() async {
    final reason = _reasonCtrl.text.trim();
    if (reason.length < 20) {
      setState(() =>
          _error = 'Describe the issue in at least 20 characters.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final disputes = context.read<DisputesProvider>();
      final dispute = await disputes.openDispute(
        bookingId: widget.booking.id,
        paymentId: '',
        reason: reason,
        category: _category,
      );
      if (_evidenceBytes.isNotEmpty) {
        await disputes.submitEvidence(
          disputeId: dispute.id,
          description: 'Customer-submitted evidence',
          imageBytesList: _evidenceBytes,
          filenames: _evidenceFilenames,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Dispute submitted. Our team will review it shortly.')),
      );
    } catch (e) {
      setState(() => _error = 'Failed to submit: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Report a Problem')),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(widget.booking.serviceName,
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '${widget.booking.date} · ${widget.booking.time}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Text('Category', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final (label, value) in _categories)
                RadioListTile<String>(
                  dense: true,
                  title: Text(label),
                  value: value,
                  groupValue: _category,
                  onChanged: (v) => setState(() => _category = v!),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonCtrl,
                decoration: const InputDecoration(
                  labelText:
                      'Describe the issue (min. 20 characters)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                maxLength: 1000,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Evidence (${_evidenceBytes.length}/4)',
                      style: theme.textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _evidenceBytes.length < 4
                        ? _pickEvidence
                        : null,
                    icon: const Icon(
                        Icons.add_photo_alternate_outlined),
                    label: const Text('Add Photo'),
                  ),
                ],
              ),
              if (_evidenceBytes.isNotEmpty)
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _evidenceBytes.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                    itemBuilder: (ctx, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _evidenceBytes[i] as dynamic,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style:
                        TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 24),
              ServioPrimaryButton(
                label:
                    _submitting ? 'Submitting...' : 'Submit Dispute',
                onPressed: _submitting ? null : _submit,
                isLoading: _submitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
