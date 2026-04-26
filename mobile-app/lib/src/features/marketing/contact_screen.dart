import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';
import '../../design_system/widgets/servio_primary_button.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSubmitting = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _successMessage = null;
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _errorMessage = 'Please complete the required fields before sending.';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      _successMessage = 'Message sent. We will reply within 2 business hours.';
      _nameController.clear();
      _emailController.clear();
      _subjectController.clear();
      _messageController.clear();
    });
  }

  Future<void> _launchContact(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || launched) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open ${uri.scheme}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Contact Us'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: <Widget>[
            const SliverToBoxAdapter(child: _ContactHero()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  <Widget>[
                    _ContactFormCard(
                      formKey: _formKey,
                      nameController: _nameController,
                      emailController: _emailController,
                      subjectController: _subjectController,
                      messageController: _messageController,
                      isSubmitting: _isSubmitting,
                      successMessage: _successMessage,
                      errorMessage: _errorMessage,
                      onSubmit: _submit,
                    ),
                    const SizedBox(height: 18),
                    _ContactDetailsCard(onLaunch: _launchContact),
                    const SizedBox(height: 14),
                    const _SupportHoursCard(),
                    const SizedBox(height: 14),
                    const _ResponsePromiseCard(),
                    const SizedBox(height: ServioSpacing.sectionGap),
                    const _FaqSection(),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactHero extends StatelessWidget {
  const _ContactHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 42, 20, 38),
      decoration: const BoxDecoration(gradient: ServioGradients.brand),
      child: Stack(
        children: <Widget>[
          PositionedDirectional(
            top: -52,
            start: -42,
            child: _SoftDisc(size: 142, color: ServioColors.accentLight),
          ),
          PositionedDirectional(
            bottom: -58,
            end: -46,
            child: _SoftDisc(size: 160, color: ServioColors.accent),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: _HeroKicker(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Get in touch',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "We'd love to",
                textAlign: TextAlign.center,
                style:
                    theme.textTheme.displayLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'hear from you.',
                textAlign: TextAlign.center,
                style: theme.textTheme.displayLarge?.copyWith(
                  color: ServioColors.accentLight,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Have a question, feedback, or need support? Send us a message and we'll get back to you within 24 hours, usually sooner.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContactFormCard extends StatelessWidget {
  const _ContactFormCard({
    required this.formKey,
    required this.nameController,
    required this.emailController,
    required this.subjectController,
    required this.messageController,
    required this.isSubmitting,
    required this.onSubmit,
    this.successMessage,
    this.errorMessage,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController subjectController;
  final TextEditingController messageController;
  final bool isSubmitting;
  final String? successMessage;
  final String? errorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      padding: const EdgeInsets.all(20),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ServioColors.tint(servio.accent),
                    borderRadius: BorderRadius.circular(ServioRadius.sm),
                    border: Border.all(
                        color: servio.accent.withValues(alpha: 0.22)),
                  ),
                  child: Icon(Icons.mail_outline_rounded, color: servio.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Send a message',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        "Fill out the form below and we'll reply to your email.",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: servio.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'Your name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                hintText: 'you@example.com',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: _emailValidator,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: subjectController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'How can we help?',
                prefixIcon: Icon(Icons.subject_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: messageController,
              minLines: 5,
              maxLines: 7,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Tell us what you need...',
                alignLabelWithHint: true,
              ),
              validator: _requiredValidator,
            ),
            if (successMessage != null || errorMessage != null) ...<Widget>[
              const SizedBox(height: 14),
              _InlineMessage(
                message: successMessage ?? errorMessage!,
                color: successMessage != null ? servio.success : servio.danger,
                icon: successMessage != null
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
              ),
            ],
            const SizedBox(height: 18),
            ServioPrimaryButton(
              label: 'Send Message',
              isLoading: isSubmitting,
              onPressed: isSubmitting ? null : onSubmit,
            ),
          ],
        ),
      ),
    );
  }

  static String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required.';
    return null;
  }

  static String? _emailValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email is required.';
    if (!trimmed.contains('@') || !trimmed.contains('.')) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}

class _ContactDetailsCard extends StatelessWidget {
  const _ContactDetailsCard({required this.onLaunch});

  final ValueChanged<Uri> onLaunch;

  @override
  Widget build(BuildContext context) {
    return ServioCard(
      radius: ServioRadius.lg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Contact Details',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          _ContactDetailRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: 'support@servio.com',
            onTap: () =>
                onLaunch(Uri(scheme: 'mailto', path: 'support@servio.com')),
          ),
          _ContactDetailRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: '+20 100 000 0000',
            onTap: () => onLaunch(Uri(scheme: 'tel', path: '+201000000000')),
          ),
          _ContactDetailRow(
            icon: Icons.location_on_outlined,
            label: 'Office',
            value: '123 Service Lane, Cairo, Egypt',
            onTap: () => onLaunch(
              Uri.https('www.google.com', '/maps/search/', <String, String>{
                'api': '1',
                'query': '123 Service Lane Cairo Egypt',
              }),
            ),
            bottomPadding: 0,
          ),
        ],
      ),
    );
  }
}

class _SupportHoursCard extends StatelessWidget {
  const _SupportHoursCard();

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      borderColor: servio.info.withValues(alpha: 0.38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const <Widget>[
          _CardTitle(icon: Icons.schedule_rounded, title: 'Support Hours'),
          SizedBox(height: 14),
          _HoursRow(day: 'Mon - Fri', time: '9:00 AM - 6:00 PM'),
          _HoursRow(day: 'Saturday', time: '10:00 AM - 4:00 PM'),
          _HoursRow(day: 'Sunday', time: 'Closed', isClosed: true),
        ],
      ),
    );
  }
}

class _ResponsePromiseCard extends StatelessWidget {
  const _ResponsePromiseCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return ServioCard(
      radius: ServioRadius.lg,
      backgroundColor: servio.backgroundSoft,
      borderColor: servio.accent.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: servio.accent,
              borderRadius: BorderRadius.circular(ServioRadius.sm),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Fast Response Guarantee',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'We reply within 2 business hours. Urgent? Mention it in your message.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: servio.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqSection extends StatefulWidget {
  const _FaqSection();

  @override
  State<_FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<_FaqSection>
    with TickerProviderStateMixin {
  final Set<int> _openIndexes = <int>{};

  static const List<_FaqItemData> _items = <_FaqItemData>[
    _FaqItemData(
      'Booking or account issue?',
      'Log in to your account and use in-app help, or describe the issue in the contact form above. Our team will investigate and get back to you within 24 hours.',
    ),
    _FaqItemData(
      'Want to join as a professional?',
      'Sign up as a technician and we will guide you through verification. It typically takes 2-3 business days to get verified.',
    ),
    _FaqItemData(
      'How does SERVIO verify professionals?',
      'Every professional goes through profile review, identity verification, and skill assessment before accepting bookings.',
    ),
    _FaqItemData(
      'Just browsing?',
      'Explore services and book when you are ready. You can compare professionals, read reviews, and get estimates before signing up.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'QUICK ANSWERS',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: servio.accent,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Frequently Asked Questions',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: 18),
        ...List<Widget>.generate(_items.length, (int index) {
          final item = _items[index];
          final expanded = _openIndexes.contains(index);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ServioCard(
              radius: ServioRadius.md,
              padding: EdgeInsets.zero,
              borderColor:
                  expanded ? servio.accent.withValues(alpha: 0.42) : null,
              child: Column(
                children: <Widget>[
                  InkWell(
                    borderRadius: BorderRadius.circular(ServioRadius.md),
                    onTap: () {
                      setState(() {
                        if (expanded) {
                          _openIndexes.remove(index);
                        } else {
                          _openIndexes.add(index);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              item.question,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          AnimatedRotation(
                            turns: expanded ? 0.5 : 0,
                            duration: ServioMotion.normal,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: expanded
                                  ? servio.accent
                                  : servio.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: ServioMotion.normal,
                    curve: ServioMotion.spring,
                    child: expanded
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              item.answer,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: servio.textSecondary,
                                height: 1.55,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ContactDetailRow extends StatelessWidget {
  const _ContactDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.bottomPadding = 16,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: InkWell(
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: ServioColors.tint(servio.accent),
                borderRadius: BorderRadius.circular(ServioRadius.sm),
                border:
                    Border.all(color: servio.accent.withValues(alpha: 0.22)),
              ),
              child: Icon(icon, color: servio.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: servio.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded,
                color: servio.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;

    return Row(
      children: <Widget>[
        Icon(icon, color: servio.info, size: 20),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _HoursRow extends StatelessWidget {
  const _HoursRow({
    required this.day,
    required this.time,
    this.isClosed = false,
  });

  final String day;
  final String time;
  final bool isClosed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final servio = context.servio;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(day, style: theme.textTheme.bodyMedium)),
          Text(
            time,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isClosed ? servio.danger : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ServioRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroKicker extends StatelessWidget {
  const _HeroKicker({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: ServioColors.accentLight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ServioRadius.full),
        border:
            Border.all(color: ServioColors.accentLight.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: ServioColors.accentLight),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: ServioColors.accentLight,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
          ),
        ],
      ),
    );
  }
}

class _SoftDisc extends StatelessWidget {
  const _SoftDisc({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.14),
        ),
      ),
    );
  }
}

class _FaqItemData {
  const _FaqItemData(this.question, this.answer);

  final String question;
  final String answer;
}
