import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  runApp(const AxReproApp());
}

class AxReproApp extends StatelessWidget {
  const AxReproApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AxReproScreen(),
      theme: ThemeData(useMaterial3: true),
    );
  }
}

class AxReproScreen extends StatefulWidget {
  const AxReproScreen({super.key});

  @override
  State<AxReproScreen> createState() => _AxReproScreenState();
}

class _AxReproScreenState extends State<AxReproScreen> {
  var taps = 0;

  void _tap() => setState(() => taps += 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Avant de te montrer...',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MOYENNE SUISSE',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.2,
                              color: Colors.redAccent,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Trois scènes, trois chiffres — la réalité de ta tranche.',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Semantics(
                      key: const ValueKey('repro-inline-button'),
                      container: true,
                      identifier: 'repro-inline-button',
                      label: 'Voir inline',
                      button: true,
                      onTap: _tap,
                      child: _Button(label: 'Voir inline', onPressed: _tap),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Semantics(
                key: const ValueKey('repro-shell-slot-button'),
                container: true,
                identifier: 'repro-shell-slot-button',
                label: 'Voir slot',
                button: true,
                onTap: _tap,
                child: _Button(label: 'Voir slot', onPressed: _tap),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black.withValues(alpha: 0.04),
              child: Text('TON DOSSIER · taps=$taps'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
