import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/services/debt_prevention_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mint_mobile/widgets/common/debt_tools_nav.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Ecran des ressources d'aide en cas de dette.
///
/// Liens vers Dettes Conseils Suisse, Caritas et services cantonaux.
/// Note privacy nLPD et disclaimer.
class HelpResourcesScreen extends StatefulWidget {
  const HelpResourcesScreen({super.key});

  @override
  State<HelpResourcesScreen> createState() => _HelpResourcesScreenState();
}

class _HelpResourcesScreenState extends State<HelpResourcesScreen> {
  String _canton = 'VD';

  @override
  Widget build(BuildContext context) {
    final cantonalResource = DebtHelpResources.getCantonalResource(_canton);

    return Scaffold(
      backgroundColor: MintColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: MintColors.white,
            surfaceTintColor: MintColors.white,
            foregroundColor: MintColors.textPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(
              S.of(context)!.helpResourcesAppBarTitle,
              style: MintTextStyles.titleMedium(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(MintSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Intro
                MintEntrance(child: _buildIntroCard()),
                const SizedBox(height: 24),

                // Dettes Conseils Suisse
                MintEntrance(delay: const Duration(milliseconds: 100), child: _buildNationalResourceCard(
                  nom: S.of(context)!.helpResourcesDettesName,
                  description: S.of(context)!.helpResourcesDettesDesc,
                  url: 'https://www.dettes.ch',
                  telephone: '0800 40 40 40',
                  icon: Icons.phone_in_talk,
                  color: MintColors.info,
                )),
                const SizedBox(height: 16),

                // Caritas
                MintEntrance(delay: const Duration(milliseconds: 200), child: _buildNationalResourceCard(
                  nom: S.of(context)!.helpResourcesCaritasName,
                  description: S.of(context)!.helpResourcesCaritasDesc,
                  url: 'https://www.caritas.ch/dettes',
                  telephone: '0800 708 708',
                  icon: Icons.favorite_outline,
                  color: MintColors.error,
                )),
                const SizedBox(height: 24),

                // Service cantonal
                MintEntrance(delay: const Duration(milliseconds: 300), child: _buildCantonalSection(cantonalResource)),
                const SizedBox(height: 24),

                // Note privacy nLPD
                MintEntrance(delay: const Duration(milliseconds: 400), child: _buildPrivacyNote()),
                const SizedBox(height: 24),

                // Disclaimer
                _buildDisclaimer(),
                const SizedBox(height: 24),

                // Navigation croisée dette
                const DebtToolsNav(currentRoute: '/debt/help'),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard() {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent,
                  color: MintColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                S.of(context)!.helpResourcesIntroTitle,
                style: MintTextStyles.titleMedium(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.helpResourcesIntroBody,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.helpResourcesIntroNote,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildNationalResourceCard({
    required String nom,
    required String description,
    required String url,
    required String telephone,
    required IconData icon,
    required Color color,
  }) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nom,
                      style: MintTextStyles.titleMedium(),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: MintColors.successBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        S.of(context)!.helpResourcesFreeLabel,
                        style: MintTextStyles.labelSmall(color: MintColors.success),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _launchUrl(url),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(S.of(context)!.helpResourceSiteWeb),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _launchUrl('tel:$telephone'),
                  icon: const Icon(Icons.phone, size: 16),
                  label: Text(telephone, style: const TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCantonalSection(HelpResource? cantonalResource) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.lg),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.helpResourcesCantonalHeader,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: 16),

          // Dropdown canton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context)!.helpResourcesCantonLabel,
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: MintColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _canton,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
                    items: DebtHelpResources.cantons
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _canton = v);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (cantonalResource != null) ...[
            Semantics(
              label: cantonalResource.nom,
              button: true,
              child: InkWell(
              onTap: () => _launchUrl(cantonalResource.url),
              borderRadius: BorderRadius.circular(12),
              child: MintSurface(
                tone: MintSurfaceTone.porcelaine,
                padding: const EdgeInsets.all(16),
                radius: 12,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MintColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.location_city,
                          color: MintColors.primary, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cantonalResource.nom,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cantonalResource.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: MintColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new,
                        color: MintColors.textMuted, size: 18),
                  ],
                ),
              ),
            ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                S.of(context)!.helpResourcesNoService,
                style: MintTextStyles.bodySmall(color: MintColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.neutralBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.neutralBg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: MintColors.blueDark, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.helpResourcesPrivacyTitle,
                  style: MintTextStyles.bodySmall(color: MintColors.blueMaterial900),
                ),
                const SizedBox(height: 4),
                Text(
                  S.of(context)!.helpResourcesPrivacyBody,
                  style: MintTextStyles.labelSmall(color: MintColors.blueDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.helpResourcesDisclaimer,
              style: MintTextStyles.micro(color: MintColors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
