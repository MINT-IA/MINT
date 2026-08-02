import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_next_design_lab/design_lab_app.dart';

void main() {
  const semanticContracts = {
    "fr": {
      "contributionTitle":
          "En {taxYear}, l’un de tes 3a a-t-il reçu un nouveau versement ?",
      "contributionBody":
          "Réponds pour tous tes 3a, y compris une assurance 3a.",
      "contributionCreditedNote":
          "Compte seulement l’argent neuf reçu pour {taxYear}. Un paiement seulement envoyé ou débité ne compte pas encore ; un transfert, un rendement ou un remboursement de frais non plus.",
      "contributionChoiceYes": "Oui, un nouveau versement a été reçu",
      "contributionChoiceNo": "Non, aucun nouveau versement",
      "contributionChoiceUnknown": "Je ne sais pas",
      "contributionEdgePending":
          "Un paiement planifié, envoyé ou débité ne compte qu’une fois reçu sur ton 3a.",
      "contributionEdgeTransfer":
          "Ne compte pas un transfert entre deux 3a : ce n’est pas de l’argent neuf.",
      "contributionEdgeBuyback":
          "Garde séparé un rachat pour une année passée.",
      "contributionUnknownBody":
          "Cherche si une cotisation ordinaire a été créditée pour {taxYear} sur chacun de tes 3a. Si un transfert, un rachat ou un remboursement rend la réponse incertaine, garde « Je ne sais pas ».",
      "contributionUnknownInsuranceCertificate":
          "Pour une assurance 3a, regarde l’attestation annuelle ou demande quelle cotisation ordinaire a été créditée.",
      "contributionUnknownTransferWarning":
          "N’additionne jamais un transfert entre deux 3a. Ce serait compter le même argent deux fois.",
      "contributionUnknownEducationLimit":
          "Tu peux continuer sans montant personnel. MINT montrera seulement une explication générale.",
    },
    "en": {
      "contributionTitle":
          "In {taxYear}, did one of your pillar 3a accounts receive a new contribution?",
      "contributionBody":
          "Answer for all your pillar 3a accounts, including a 3a insurance policy.",
      "contributionCreditedNote":
          "Count only new money received for {taxYear}. A payment merely sent or debited does not count yet; nor do a transfer, investment return or fee refund.",
      "contributionChoiceYes": "Yes, a new contribution was received",
      "contributionChoiceNo": "No, no new contribution",
      "contributionChoiceUnknown": "I don’t know",
      "contributionEdgePending":
          "A scheduled, sent or debited payment counts only once your pillar 3a receives it.",
      "contributionEdgeTransfer":
          "Do not count a transfer between two pillar 3a providers: it is not new money.",
      "contributionEdgeBuyback":
          "Keep a retroactive/catch-up contribution for a past year separate.",
      "contributionUnknownBody":
          "Check whether an ordinary contribution was received for {taxYear} on each of your pillar 3a accounts. If a transfer, retroactive/catch-up contribution for a past year, or refund makes the answer unclear, keep “I don’t know”.",
      "contributionUnknownInsuranceCertificate":
          "For a pillar 3a insurance policy, check the annual certificate or ask which ordinary contribution was received.",
      "contributionUnknownTransferWarning":
          "Never add a transfer between two pillar 3a accounts. That would count the same money twice.",
      "contributionUnknownEducationLimit":
          "You may continue without a personal amount. MINT will show only a general explanation.",
    },
    "de": {
      "contributionTitle":
          "Hat eine deiner Säulen 3a im Jahr {taxYear} eine neue Einzahlung erhalten?",
      "contributionBody":
          "Antworte für alle deine 3a-Konten, auch für eine 3a-Versicherung.",
      "contributionCreditedNote":
          "Zähle nur neues Geld, das für {taxYear} eingegangen ist. Eine nur gesendete oder belastete Zahlung zählt noch nicht; ebenso wenig ein Transfer, Anlageertrag oder eine Gebührenrückerstattung.",
      "contributionChoiceYes": "Ja, eine neue Einzahlung ist eingegangen",
      "contributionChoiceNo": "Nein, keine neue Einzahlung",
      "contributionChoiceUnknown": "Ich weiss es nicht",
      "contributionEdgePending":
          "Eine geplante, gesendete oder belastete Zahlung zählt erst, wenn sie auf deiner Säule 3a eingegangen ist.",
      "contributionEdgeTransfer":
          "Zähle einen Transfer zwischen zwei Säulen 3a nicht: Er ist kein neues Geld.",
      "contributionEdgeBuyback":
          "Halte einen nachträglichen Einkauf für ein früheres Jahr getrennt.",
      "contributionUnknownBody":
          "Prüfe bei jeder deiner Säulen 3a, ob für {taxYear} eine ordentliche Einzahlung eingegangen ist. Wenn Transfer, Einkauf oder Rückzahlung die Antwort unklar machen, bleibe bei «Ich weiss es nicht».",
      "contributionUnknownInsuranceCertificate":
          "Prüfe bei einer 3a-Versicherung die Jahresbescheinigung oder frage nach der eingegangenen ordentlichen Einzahlung.",
      "contributionUnknownTransferWarning":
          "Addiere nie einen Transfer zwischen zwei Säulen 3a. Sonst zählst du dasselbe Geld doppelt.",
      "contributionUnknownEducationLimit":
          "Du kannst ohne persönlichen Betrag fortfahren. MINT zeigt nur eine allgemeine Erklärung.",
    },
    "it": {
      "contributionTitle":
          "Nel {taxYear}, uno dei tuoi pilastri 3a ha ricevuto un nuovo versamento?",
      "contributionBody":
          "Rispondi considerando tutti i tuoi pilastri 3a, compresa un’assicurazione 3a.",
      "contributionCreditedNote":
          "Conta solo il denaro nuovo ricevuto per il {taxYear}. Un pagamento soltanto inviato o addebitato non conta ancora; nemmeno un trasferimento, un rendimento o un rimborso di spese.",
      "contributionChoiceYes": "Sì, è stato ricevuto un nuovo versamento",
      "contributionChoiceNo": "No, nessun nuovo versamento",
      "contributionChoiceUnknown": "Non lo so",
      "contributionEdgePending":
          "Un pagamento pianificato, inviato o addebitato conta solo quando arriva sul tuo 3a.",
      "contributionEdgeTransfer":
          "Non contare un trasferimento tra due pilastri 3a: non è denaro nuovo.",
      "contributionEdgeBuyback":
          "Tieni separato un riscatto retroattivo per un anno passato.",
      "contributionUnknownBody":
          "Controlla su ogni tuo 3a se nel {taxYear} è stato ricevuto un versamento ordinario. Se un trasferimento, riscatto o rimborso rende incerta la risposta, mantieni «Non lo so».",
      "contributionUnknownInsuranceCertificate":
          "Per un’assicurazione 3a, consulta l’attestazione annuale o chiedi quale versamento ordinario è stato ricevuto.",
      "contributionUnknownTransferWarning":
          "Non sommare mai un trasferimento tra due 3a: conteresti due volte lo stesso denaro.",
      "contributionUnknownEducationLimit":
          "Puoi continuare senza un importo personale. MINT mostrerà solo una spiegazione generale.",
    },
    "es": {
      "contributionTitle":
          "En {taxYear}, ¿alguno de tus pilares 3a recibió una nueva aportación?",
      "contributionBody":
          "Responde teniendo en cuenta todos tus pilares 3a, incluido un seguro 3a.",
      "contributionCreditedNote":
          "Cuenta solo el dinero nuevo recibido para {taxYear}. Un pago solo enviado o cargado aún no cuenta; tampoco una transferencia, un rendimiento o un reembolso de gastos.",
      "contributionChoiceYes": "Sí, se recibió una nueva aportación",
      "contributionChoiceNo": "No, ninguna nueva aportación",
      "contributionChoiceUnknown": "No lo sé",
      "contributionEdgePending":
          "Un pago programado, enviado o cargado solo cuenta cuando llega a tu 3a.",
      "contributionEdgeTransfer":
          "No cuentes una transferencia entre dos pilares 3a: no es dinero nuevo.",
      "contributionEdgeBuyback":
          "Mantén separada una aportación retroactiva para cubrir una laguna de un año anterior.",
      "contributionUnknownBody":
          "Comprueba en cada uno de tus 3a si se recibió una aportación ordinaria para {taxYear}. Si una transferencia, una aportación retroactiva para cubrir una laguna de un año anterior o una devolución hace dudosa la respuesta, mantén «No lo sé».",
      "contributionUnknownInsuranceCertificate":
          "Para un seguro 3a, consulta el certificado anual o pregunta qué aportación ordinaria se recibió.",
      "contributionUnknownTransferWarning":
          "Nunca sumes una transferencia entre dos 3a. Contarías dos veces el mismo dinero.",
      "contributionUnknownEducationLimit":
          "Puedes continuar sin un importe personal. MINT solo mostrará una explicación general.",
    },
    "pt": {
      "contributionTitle":
          "Em {taxYear}, algum dos teus pilares 3a recebeu uma nova contribuição?",
      "contributionBody":
          "Responde considerando todos os teus pilares 3a, incluindo um seguro 3a.",
      "contributionCreditedNote":
          "Conta apenas o dinheiro novo recebido para {taxYear}. Um pagamento apenas enviado ou debitado ainda não conta; nem uma transferência, rendimento ou reembolso de despesas.",
      "contributionChoiceYes": "Sim, foi recebida uma nova contribuição",
      "contributionChoiceNo": "Não, nenhuma nova contribuição",
      "contributionChoiceUnknown": "Não sei",
      "contributionEdgePending":
          "Um pagamento planeado, enviado ou debitado só conta quando chega ao teu 3a.",
      "contributionEdgeTransfer":
          "Não contes uma transferência entre dois pilares 3a: não é dinheiro novo.",
      "contributionEdgeBuyback":
          "Mantém separada uma contribuição retroativa para colmatar uma lacuna de um ano anterior.",
      "contributionUnknownBody":
          "Verifica em cada um dos teus 3a se foi recebida uma contribuição ordinária para {taxYear}. Se uma transferência, uma contribuição retroativa para colmatar uma lacuna de um ano anterior ou um reembolso tornar a resposta incerta, mantém «Não sei».",
      "contributionUnknownInsuranceCertificate":
          "Para um seguro 3a, consulta a declaração anual ou pergunta que contribuição ordinária foi recebida.",
      "contributionUnknownTransferWarning":
          "Nunca somes uma transferência entre dois 3a. Contarias o mesmo dinheiro duas vezes.",
      "contributionUnknownEducationLimit":
          "Podes continuar sem um valor pessoal. A MINT mostrará apenas uma explicação geral.",
    },
  };
  const catchUpTerms = {
    'fr': 'rachat pour une année passée',
    'en': 'catch-up contribution for a past year',
    'de': 'nachträglichen Einkauf für ein früheres Jahr',
    'it': 'riscatto retroattivo per un anno passato',
    'es': 'aportación retroactiva para cubrir una laguna de un año anterior',
    'pt': 'contribuição retroativa para colmatar uma lacuna de um ano anterior',
  };
  const forbiddenFalseFriends = {
    'en': ['buyback'],
    'es': ['recompra'],
    'pt': ['resgate'],
  };
  for (final locale in ['fr', 'en', 'de', 'it', 'es', 'pt']) {
    test(
      '$locale source preserves reviewed contribution semantics exactly',
      () {
        final source =
            jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
                as Map<String, dynamic>;
        for (final entry in semanticContracts[locale]!.entries) {
          expect(
            source[entry.key],
            entry.value,
            reason: '$locale ${entry.key}',
          );
        }
      },
    );

    testWidgets(
      '$locale renders the contribution slice without fallback marker',
      (tester) async {
        await tester.pumpWidget(
          MintNextDesignLabApp(locale: Locale(locale), currentYear: 2026),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('node:today_3a_intent')),
          findsOneWidget,
        );
        for (final action in [
          'action:today_3a_intent.start',
          'action:orientation.continue',
          'action:fact_tax_year.confirm_current_year',
          'action:fact_tax_year.continue',
          'action:fact_lpp_affiliation.choose_yes',
        ]) {
          final finder = find.byKey(ValueKey(action));
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }
        expect(
          find.byKey(const ValueKey('node:fact_contribution')),
          findsOneWidget,
        );
        final disclosure = find.byKey(
          const ValueKey('action:fact_contribution.toggle_edge_help'),
        );
        await tester.ensureVisible(disclosure);
        await tester.tap(disclosure);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('content:fact_contribution.edge_help')),
          findsOneWidget,
        );
        expect(find.textContaining(catchUpTerms[locale]!), findsWidgets);
        for (final falseFriend in forbiddenFalseFriends[locale] ?? const []) {
          expect(find.textContaining(falseFriend), findsNothing);
        }
        final unknown = find.byKey(
          const ValueKey('action:fact_contribution.choose_unknown'),
        );
        await tester.ensureVisible(unknown);
        await tester.tap(unknown);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('node:contribution_unknown_help')),
          findsOneWidget,
        );
        expect(find.textContaining('MISSING_'), findsNothing);
      },
    );
  }
}
