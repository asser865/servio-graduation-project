import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_card.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> with TickerProviderStateMixin {
  final Set<int> _openIndexes = <int>{};

  static const List<_FaqItemData> _items = <_FaqItemData>[
    _FaqItemData(
      'Booking or account issue?',
      'Log in to your account and use Report a Problem in your profile, or contact us via the Contact Us page. Our team will investigate and get back to you within 24 hours.',
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('FAQ'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            ServioSpacing.screenPadding,
            28,
            ServioSpacing.screenPadding,
            40,
          ),
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
            const SizedBox(height: 24),
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
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
