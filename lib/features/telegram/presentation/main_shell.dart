import 'package:flutter/material.dart';

import '../../bookmarks/presentation/pages/bookmarks_page.dart';
import '../../channels/presentation/pages/channels_page.dart';
import '../../feed/presentation/pages/feed_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  void _openChannels() {
    setState(() => _selectedIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          FeedPage(onOpenChannels: _openChannels),
          const ChannelsPage(),
          const BookmarksPage(),
          const _AboutPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed_rounded),
            label: 'خبرها',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign_rounded),
            label: 'کانال‌ها',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'ذخیره‌شده‌ها',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline_rounded),
            selectedIcon: Icon(Icons.info_rounded),
            label: 'درباره',
          ),
        ],
      ),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('درباره برنامه')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.newspaper_rounded,
                  size: 52,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  'خبرخوان تلگرام',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.onPrimaryContainer,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'مطالعه یک‌جا و منظم پست‌های کانال‌های تلگرام',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _AboutTile(
            icon: Icons.telegram,
            title: 'اتصال مستقیم به تلگرام',
            subtitle: 'دریافت اطلاعات از طریق TDLib و MTProto پس از ورود به حساب',
          ),
          const _AboutTile(
            icon: Icons.offline_pin_rounded,
            title: 'ذخیره محلی',
            subtitle: 'نشانک‌ها و رسانه‌های دانلودشده روی دستگاه نگهداری می‌شوند.',
          ),
          const _AboutTile(
            icon: Icons.lock_outline_rounded,
            title: 'حریم خصوصی',
            subtitle: 'کد ورود به سرور برنامه ارسال نمی‌شود و نشست تلگرام روی دستگاه ذخیره می‌شود.',
          ),
          const SizedBox(height: 12),
          Text(
            'نسخه ۱.۱.۰',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
