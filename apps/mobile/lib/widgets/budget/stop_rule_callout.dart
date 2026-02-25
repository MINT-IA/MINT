import 'package:flutter/material.dart';

class StopRuleCallout extends StatelessWidget {
  const StopRuleCallout({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: const BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.pause_circle_filled, color: Colors.amber.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Stop Rule Triggered",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  "SI 'Variables' est à 0, ALORS pause des dépenses discrétionnaires jusqu’à la prochaine période.",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.amber.shade900,
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
