import 'package:flutter/material.dart';

import '../../design_system/servio_theme_extension.dart';
import '../../design_system/servio_tokens.dart';
import '../../design_system/widgets/servio_bottom_navigation_bar.dart';
import '../../design_system/widgets/servio_card.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final servio = context.servio;
    final theme = Theme.of(context);

    return Scaffold(
      bottomNavigationBar: ServioBottomNavigationBar(
        items: const <ServioBottomNavItem>[
          ServioBottomNavItem(icon: Icons.home_rounded, label: 'Home'),
          ServioBottomNavItem(icon: Icons.grid_view_rounded, label: 'Services'),
          ServioBottomNavItem(icon: Icons.auto_awesome_rounded, label: 'Smart Match', highlighted: true),
          ServioBottomNavItem(icon: Icons.calendar_month_rounded, label: 'Bookings'),
          ServioBottomNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
        currentIndex: 3,
        onTap: (_) {},
      ),
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(ServioSpacing.screenPadding),
        child: Column(
          children: <Widget>[
            TextField(
              decoration: InputDecoration(
                hintText: 'Search conversations',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: servio.surfaceAlt,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ServioRadius.full),
                  borderSide: BorderSide(color: servio.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(ServioRadius.full),
                  borderSide: BorderSide(color: servio.accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: 5,
                separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  final names = <String>['Ahmed Nabil', 'Mariam Adel', 'Youssef Tarek', 'Nour Hany', 'Karim Adel'];
                  final previews = <String>[
                    'I can arrive around 10 AM and inspect the leak first.',
                    'Please send a photo of the switchboard if possible.',
                    'I finished the first coat and can return tomorrow.',
                    'I have the materials list ready for review.',
                    'I am on my way and should reach the location shortly.'
                  ];

                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChatScreen(contactName: names[index]),
                        ),
                      );
                    },
                    child: ServioCard(
                      child: Row(
                        children: <Widget>[
                          Stack(
                            clipBehavior: Clip.none,
                            children: <Widget>[
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: ServioGradients.warm,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: servio.accent, width: 2),
                                ),
                                child: Center(child: Text(names[index][0])),
                              ),
                              Positioned(
                                right: -1,
                                bottom: -1,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: ServioColors.success,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: theme.colorScheme.surface, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(names[index], style: theme.textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  previews[index],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(color: servio.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Text(
                                '10:${index}0 AM',
                                style: theme.textTheme.bodySmall?.copyWith(color: servio.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              if (index < 3)
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: servio.accent,
                                    borderRadius: BorderRadius.circular(ServioRadius.full),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
