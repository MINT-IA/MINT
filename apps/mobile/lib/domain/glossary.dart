
class GlossaryTerm {
  final String term;
  final String definition;
  final String? context;

  const GlossaryTerm({
    required this.term,
    required this.definition,
    this.context,
  });
}

class GlossaryService {
  static const Map<String, GlossaryTerm> _terms = {
    'volatilité': GlossaryTerm(
      term: 'Volatilité',
      definition: 'Amplitude de variation du prix d\'un actif financier. Une forte volatilité signifie des hauts et des bas fréquents.',
      context: 'Utilisé souvent pour les actions et le 3ème pilier investi.',
    ),
    'intérêt composé': GlossaryTerm(
      term: 'Intérêt composé',
      definition: 'Intérêts calculés sur le capital initial et sur les intérêts accumulés des périodes précédentes.',
      context: 'L\'effet "boule de neige" de votre épargne.',
    ),
    'taux marginal': GlossaryTerm(
      term: 'Taux marginal',
      definition: 'Le taux d\'imposition appliqué à la dernière tranche de votre revenu.',
      context: 'Crucial pour calculer l\'économie d\'impôt d\'un 3a.',
    ),
    'amortissement indirect': GlossaryTerm(
      term: 'Amortissement indirect',
      definition: 'Remboursement de la dette hypothécaire via un compte 3a plutôt que directement à la banque.',
      context: 'Permet de garder une dette élevée pour déduire plus d\'intérêts des impôts.',
    ),
  };

  static GlossaryTerm? getTerm(String term) {
    return _terms[term.toLowerCase()];
  }
}
