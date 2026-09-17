import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: [
                    // The launcher icon itself, so this never drifts from it.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/icon/icon.png',
                        width: 72,
                        height: 72,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      info?.appName ?? 'Deep Flashcard',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info == null
                          ? ' '
                          : 'Version ${info.version} (${info.buildNumber})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _Section(
                title: 'Credits',
                children: [
                  _InfoTile(
                    icon: Icons.translate,
                    text:
                        'Translation powered by Google ML Kit '
                        '(free, on-device).',
                  ),
                  _InfoTile(
                    icon: Icons.format_quote,
                    text:
                        'Example sentences from the Tatoeba Project, '
                        'CC BY 2.0 FR — tatoeba.org contributors.',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const _Section(
                title: 'Privacy',
                children: [
                  _InfoTile(
                    icon: Icons.lock_outline,
                    text:
                        'This app stores all data locally on your device. '
                        'Nothing is sent to any server.',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _Section(
                title: 'Legal',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Credits & Licenses'),
                    subtitle: const Text(
                      'Full attribution for Tatoeba, ML Kit, and open source libraries',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/credits-licenses'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(text),
    );
  }
}
