import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';

class StopRuleCallout extends StatelessWidget {
  const StopRuleCallout({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.disclaimerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.yellowGold),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.pause_circle_filled, color: MintColors.amberDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Stop Rule Triggered",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: MintColors.amberDark,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  "SI 'Variables' est à 0, ALORS pause des dépenses discrétionnaires jusqu’à la prochaine période.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MintColors.amberDark,
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
