import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MintShapeReproApp());
}

class MintShapeReproApp extends StatelessWidget {
  const MintShapeReproApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const MintShapeReproScreen(),
    );
  }
}

class MintShapeReproScreen extends StatefulWidget {
  const MintShapeReproScreen({super.key});

  @override
  State<MintShapeReproScreen> createState() => _MintShapeReproScreenState();
}

class _MintShapeReproScreenState extends State<MintShapeReproScreen> {
  var advanced = false;

  void _advance() => setState(() => advanced = true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F5),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(advanced),
                  child: advanced
                      ? const _DoneStep()
                      : _InsightStep(onAdvance: _advance),
                ),
              ),
            ),
            if (!advanced) const _DossierStrip(),
          ],
        ),
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.prompt,
    required this.child,
  });

  final String prompt;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              prompt,
              style: const TextStyle(
                color: Color(0xFF1D1D1F),
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _InsightStep extends StatelessWidget {
  const _InsightStep({required this.onAdvance});

  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      prompt: 'Avant de te montrer…',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFBF8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF1D1D1F).withValues(alpha: 0.08),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MOYENNE SUISSE',
                  style: TextStyle(
                    color: Color(0xFFE6855E),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Trois scènes, trois chiffres — la réalité de ta tranche.',
                  style: TextStyle(
                    color: Color(0xFF1D1D1F),
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Semantics(
            key: const ValueKey('onboarding-insight-view'),
            container: true,
            identifier: 'onboarding-insight-view',
            label: 'Voir',
            button: true,
            onTap: onAdvance,
            child: ExcludeSemantics(
              child: _PrimaryButton(
                label: 'Voir',
                onPressed: onAdvance,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1D1D1F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DossierStrip extends StatelessWidget {
  const _DossierStrip();

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.40;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBF8),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF1D1D1F).withValues(alpha: 0.08),
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('TON DOSSIER'),
              SizedBox(height: 8),
              _DossierLine(label: 'Intention', value: 'Je regarde'),
              _DossierLine(label: 'Date de naissance', value: '15.07.1992'),
              _DossierLine(label: 'Canton', value: 'Vaud'),
              _DossierLine(
                label: 'Revenu net mensuel',
                value: "7'000 – 7'500 CHF",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DossierLine extends StatelessWidget {
  const _DossierLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
        ],
      ),
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Aujourd'hui · card_cap_du_jour · mint_card_action_bar",
        textAlign: TextAlign.center,
      ),
    );
  }
}
