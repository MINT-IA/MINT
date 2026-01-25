class GeneratedLetter {
  final String title;
  final String content;
  final String disclaimer;

  GeneratedLetter(
      {required this.title, required this.content, required this.disclaimer});
}

class LetterGeneratorService {
  static const String _legalFooter =
      "\n\n------------------------------------------------\n"
      "DISCLAIMER juridique : Ce document est un modèle généré automatiquement à titre d'aide administrative. "
      "Il ne constitue pas un conseil juridique. L'utilisateur est seul responsable de la vérification de son contenu, "
      "de son adaptation à sa situation personnelle, et de son envoi. Mint (l'application) décline toute responsabilité "
      "quant aux conséquences de l'utilisation de ce modèle.";

  static GeneratedLetter generateBuybackRequest({
    required String userName,
    required String userAddress,
    required String insuranceNumber,
  }) {
    final date = DateTime.now().toIso8601String().split('T')[0];

    return GeneratedLetter(
      title: "Demande de Rachat LPP",
      content: """
$userName
$userAddress

À l'attention de la Fondation de Prévoyance

Le $date

Concerne : Demande de rachat de prestations de libre passage
N° AVS/Assuré : $insuranceNumber

Madame, Monsieur,

Je souhaite par la présente examiner la possibilité d'effectuer un rachat dans ma caisse de pension (2ème pilier).

Pourriez-vous s'il vous plaît me transmettre :
1. Le montant maximal de rachat possible à ce jour.
2. Un formulaire ou bulletin de versement pour procéder à un rachat.
3. Une confirmation que mes avoirs ne sont pas bloqués suite à un versement anticipé pour l'encouragement à la propriété du logement (EPL) ou suite à un divorce récent.

Dans l'attente de votre réponse, je vous prie d'agréer, Madame, Monsieur, mes salutations distinguées.

$userName
""",
      disclaimer: _legalFooter,
    );
  }

  static GeneratedLetter generateTaxCertificateRequest({
    required String userName,
    required int year,
  }) {
    final date = DateTime.now().toIso8601String().split('T')[0];

    return GeneratedLetter(
      title: "Demande d'attestation fiscale",
      content: """
$userName

Le $date

Concerne : Demande d'attestation fiscale $year

Madame, Monsieur,

Je vous prie de bien vouloir me faire parvenir mon attestation fiscale relative à l'année $year pour :
[ ] Mon compte 3ème pilier 3a
[ ] Mes rachats LPP effectués en $year

Merci de me l'envoyer par courrier ou email dès que possible.

Meilleures salutations,

$userName
""",
      disclaimer: _legalFooter,
    );
  }
}
