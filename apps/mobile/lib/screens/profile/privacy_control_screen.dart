import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/biography/fact_card.dart';
import 'package:mint_mobile/widgets/biography/fact_edit_sheet.dart';

/// Privacy control screen -- "Ce que MINT sait de toi".
///
/// Displays all stored [BiographyFact]s grouped by category with
/// edit (bottom sheet) and delete (confirmation dialog) actions.
/// Users can view source, date, and freshness of each fact.
///
/// Route: /profile/privacy-control
/// Entry: ProfileDrawer "Ce que MINT sait de toi"
///
/// See: BIO-05 (nLPD compliance, user data control).
class PrivacyControlScreen extends StatefulWidget {
  const PrivacyControlScreen({super.key});

  @override
  State<PrivacyControlScreen> createState() => _PrivacyControlScreenState();
}

class _PrivacyControlScreenState extends State<PrivacyControlScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Schedule after build to avoid notifyListeners during build phase.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<BiographyProvider>().loadFacts();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final provider = context.watch<BiographyProvider>();

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      appBar: AppBar(
        backgroundColor: MintColors.porcelaine,
        surfaceTintColor: MintColors.porcelaine,
        elevation: 0,
        title: Text(
          l.privacyControlTitle,
          style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
        ),
      ),
      body: _buildBody(context, l, provider),
    );
  }

  Widget _buildBody(BuildContext context, S l, BiographyProvider provider) {
    // Loading state
    if (provider.isLoading && provider.facts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error state
    if (provider.error != null && provider.facts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.privacyControlError,
                style: MintTextStyles.bodyMedium(
                  color: MintColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MintSpacing.md),
              TextButton(
                onPressed: () => provider.loadFacts(),
                child: Text(l.privacyControlDeleteCancel),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (provider.facts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MintSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 48,
                color: MintColors.textMuted,
              ),
              const SizedBox(height: MintSpacing.md),
              Text(
                l.privacyControlEmpty,
                style: MintTextStyles.headlineSmall(
                  color: MintColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MintSpacing.sm),
              Text(
                l.privacyControlEmptyBody,
                style: MintTextStyles.bodyMedium(
                  color: MintColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Data state
    final allFacts = provider.facts;
    final freshCount = provider.activeFreshFacts.length;
    final percent = allFacts.isNotEmpty
        ? (freshCount / allFacts.length * 100).round()
        : 0;
    final grouped = provider.factsByCategory;

    return RefreshIndicator(
      onRefresh: () => provider.loadFacts(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(MintSpacing.lg),
            children: [
              // Summary stat
              Center(
                child: Text(
                  l.privacyControlSummary(allFacts.length, percent),
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: MintSpacing.xl),

              // Grouped sections
              _buildSection(
                context,
                l,
                l.privacyControlSectionFinancial,
                grouped['Donnees financieres'] ?? [],
                provider,
              ),
              _buildSection(
                context,
                l,
                l.privacyControlSectionLifeEvents,
                grouped['Evenements de vie'] ?? [],
                provider,
              ),
              _buildSection(
                context,
                l,
                l.privacyControlSectionDecisions,
                grouped['Decisions'] ?? [],
                provider,
              ),

              const SizedBox(height: MintSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    S l,
    String title,
    List<BiographyFact> facts,
    BiographyProvider provider,
  ) {
    if (facts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: MintTextStyles.headlineSmall(
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: MintSpacing.md),
        ...facts.map(
          (fact) => Padding(
            padding: const EdgeInsets.only(bottom: MintSpacing.sm),
            child: FactCard(
              fact: fact,
              onEdit: () => _showEditSheet(context, fact, provider),
              onDelete: () => _showDeleteDialog(context, l, fact, provider),
            ),
          ),
        ),
        const SizedBox(height: MintSpacing.lg),
      ],
    );
  }

  void _showEditSheet(
    BuildContext context,
    BiographyFact fact,
    BiographyProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => FactEditSheet(
        fact: fact,
        onSave: (newValue) {
          provider.updateFactValue(fact.id, newValue);
        },
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    S l,
    BiographyFact fact,
    BiographyProvider provider,
  ) {
    final factLabel = FactCard.factLabel(fact.factType, l);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          l.privacyControlDeleteTitle,
          style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
        ),
        content: Text(
          l.privacyControlDeleteBody(factLabel),
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.privacyControlDeleteCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.hardDeleteFact(fact.id);
            },
            style: TextButton.styleFrom(foregroundColor: MintColors.error),
            child: Text(l.privacyControlDeleteConfirm),
          ),
        ],
      ),
    );
  }
}
