import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/navigation/mint_nav.dart';

/// A domain hub screen listing available tools and screens.
class ExploreHubScreen extends StatelessWidget {
  final String title;
  final List<HubEntry> entries;

  const ExploreHubScreen({
    required this.title,
    required this.entries,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: MintTextStyles.headlineSmall(color: MintColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
          onPressed: () => MintNav.back(context),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(MintSpacing.md),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: MintColors.lightBorder),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return ListTile(
            leading: Icon(entry.icon, color: MintColors.accent),
            title: Text(entry.label, style: MintTextStyles.bodyLarge(color: MintColors.textPrimary)),
            subtitle: entry.subtitle != null
                ? Text(entry.subtitle!, style: MintTextStyles.bodySmall(color: MintColors.textSecondary))
                : null,
            trailing: const Icon(Icons.chevron_right, color: MintColors.textMuted),
            onTap: () => context.push(entry.route),
          );
        },
      ),
    );
  }
}

class HubEntry {
  final IconData icon;
  final String label;
  final String? subtitle;
  final String route;

  const HubEntry({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.route,
  });
}
