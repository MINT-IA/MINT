// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'mint_next_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class MintNextLocalizationsDe extends MintNextLocalizations {
  MintNextLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get brand => 'MINT';

  @override
  String get quit => 'Beenden';

  @override
  String get todayEyebrow => 'HEUTE · SÄULE 3A';

  @override
  String get todayTitle =>
      'Was ändert eine Einzahlung in die Säule 3a dieses Jahr?';

  @override
  String get todayBody =>
      'Wir verstehen die Auswirkungen Schritt für Schritt. MINT informiert dich, entscheidet aber nicht für dich.';

  @override
  String get start => 'Verstehen';

  @override
  String get orientationEyebrow => 'VOR DEN ZAHLEN';

  @override
  String get orientationTitle =>
      'Für deine Pensionierung sparen kann auch deine Steuern senken.';

  @override
  String get orientationBody =>
      'Eine Einzahlung in die Säule 3a kann dein steuerbares Einkommen senken — den Betrag, auf dem deine Steuern berechnet werden. Dein verfügbares Geld sinkt jetzt und das 3a-Kapital bleibt bis zur Pensionierung gebunden, ausser in den gesetzlich vorgesehenen Fällen.';

  @override
  String get orientationNote =>
      'Zuerst prüfen wir das Jahr und deine Situation. Es wird kein Betrag empfohlen.';

  @override
  String get continueLabel => 'Weiter';

  @override
  String get backLabel => 'Zurück';

  @override
  String get taxYearEyebrow => 'SCHRITT 1 · STEUERJAHR';

  @override
  String get taxYearTitle => 'Über welches Jahr sprechen wir?';

  @override
  String get taxYearBody =>
      'Der Höchstbetrag hängt vom Jahr und von deiner Situation ab, insbesondere von deinem Erwerbseinkommen und dem Anschluss an eine Pensionskasse. Das laufende Jahr wird vorgeschlagen, nie für dich gewählt.';

  @override
  String currentYearLabel(int year) {
    return 'Laufendes Jahr: $year';
  }

  @override
  String confirmYear(int year) {
    return '$year auswählen';
  }

  @override
  String yearChosen(int year) {
    return 'Jahr $year ausgewählt';
  }

  @override
  String get partialBoundary =>
      'Der nächste Bildschirm folgt im nächsten kleinen Paket. Nichts wird gespeichert.';

  @override
  String get safeExitTitle => 'Möchtest du hier aufhören?';

  @override
  String get safeExitBody =>
      'In diesem Design Lab werden keine persönlichen Finanzdaten gespeichert.';

  @override
  String get resume => 'Hier weitermachen';

  @override
  String get leave => 'Ohne Speichern beenden';

  @override
  String get dismissedTitle => 'Ablauf beendet';

  @override
  String get startShort => 'Starten';

  @override
  String get keepReferenceUnavailable => 'Lokaler Merker — bald verfügbar';

  @override
  String get lppQuestionEyebrow => 'DEINE SITUATION';

  @override
  String get lppQuestionTitle => 'Hast du derzeit eine Pensionskasse?';

  @override
  String get lppQuestionBody =>
      'Das wird auch berufliche Vorsorge, BVG oder zweite Säule genannt. Du kannst über deine Arbeit oder freiwillig versichert sein. Hier geht es darum, ob du aktuell versichert bist – nicht darum, wie viel du einzahlst.';

  @override
  String get lppQuestionEvidence =>
      'Prüfe auf einer Lohnabrechnung eine Zeile zu BVG oder Pensionskasse, sieh in einem aktuellen Vorsorgeausweis nach oder frage deine Pensionskasse, deinen Arbeitgeber oder die Personalabteilung.';

  @override
  String get lppChoiceYes => 'Ja';

  @override
  String get lppChoiceNo => 'Nein';

  @override
  String get lppChoiceUnknown => 'Ich weiss es nicht';

  @override
  String get lppUnknownEyebrow => 'KEIN PROBLEM';

  @override
  String get lppUnknownTitle => 'Du kannst es prüfen, ohne zu raten.';

  @override
  String get lppUnknownBody =>
      'Beginne mit dem, was für dich am einfachsten ist. Wenn du die Antwort kennst, starte diesen Weg erneut und beantworte die Frage nochmals.';

  @override
  String get lppUnknownListLabel =>
      'Drei Möglichkeiten, deine Pensionskassen-Zugehörigkeit zu prüfen';

  @override
  String get lppUnknownPayslip =>
      'Suche auf einer aktuellen Lohnabrechnung nach BVG, zweiter Säule oder Pensionskasse.';

  @override
  String get lppUnknownCertificate =>
      'Suche nach einem aktuellen Vorsorgeausweis deiner Pensionskasse.';

  @override
  String get lppUnknownAsk =>
      'Frage deine Pensionskasse, deinen Arbeitgeber oder die Personalabteilung, ob du aktuell versichert bist.';

  @override
  String get lppBackToQuestion => 'Zurück zur Frage';

  @override
  String get lppKeepChecklist => 'Diese Liste auf diesem Gerät behalten';

  @override
  String get localReferenceUnavailable => 'Bald verfügbar';

  @override
  String get withoutLppEyebrow => 'ES GILT EINE ANDERE REGEL';

  @override
  String get withoutLppTitle =>
      'Du kannst möglicherweise trotzdem in die Säule 3a einzahlen, aber es gelten andere Regeln.';

  @override
  String get withoutLppBody =>
      'Deine Antwort bedeutet nicht, dass du kein Recht auf die Säule 3a hast. Diese erste Berechnung deckt diesen Fall einfach noch nicht ab.';

  @override
  String get lppCorrectAnswer => 'Meine Antwort korrigieren';

  @override
  String get withoutLppKeepExplanation =>
      'Diese Erklärung auf diesem Gerät behalten';

  @override
  String get nextStepEyebrow => 'NÄCHSTER SCHRITT';

  @override
  String get nextStepTitle => 'Deine Zugehörigkeit ist geklärt.';

  @override
  String get nextStepBody =>
      'Als Nächstes geht es darum, was du dieses Jahr bereits eingezahlt hast. Diese Frage kommt im nächsten kleinen Paket. Nichts wird gespeichert.';

  @override
  String get quitJourney => 'Diesen Weg verlassen';

  @override
  String contributionEyebrow(int taxYear) {
    return 'DEINE 3A-EINZAHLUNGEN · $taxYear';
  }

  @override
  String contributionTitle(int taxYear) {
    return 'Hat eine deiner Säulen 3a im Jahr $taxYear eine neue Einzahlung erhalten?';
  }

  @override
  String get contributionBody =>
      'Antworte für alle deine 3a-Konten, auch für eine 3a-Versicherung.';

  @override
  String contributionCreditedNote(int taxYear) {
    return 'Zähle nur neues Geld, das für $taxYear eingegangen ist. Eine nur gesendete oder belastete Zahlung zählt noch nicht; ebenso wenig ein Transfer, Anlageertrag oder eine Gebührenrückerstattung.';
  }

  @override
  String get contributionAmountNote =>
      'Den Gesamtbetrag musst du jetzt noch nicht kennen. Wir fragen nur danach, wenn du Ja antwortest.';

  @override
  String get contributionChoiceYes =>
      'Ja, eine neue Einzahlung ist eingegangen';

  @override
  String get contributionChoiceNo => 'Nein, keine neue Einzahlung';

  @override
  String get contributionChoiceUnknown => 'Ich weiss es nicht';

  @override
  String contributionChoiceGroupLabel(int taxYear) {
    return 'Neue 3a-Einzahlungen, die $taxYear eingegangen sind';
  }

  @override
  String get contributionEdgeHelp => 'Was zählt — und was nicht';

  @override
  String get contributionEdgePending =>
      'Eine geplante, gesendete oder belastete Zahlung zählt erst, wenn sie auf deiner Säule 3a eingegangen ist.';

  @override
  String get contributionEdgeTransfer =>
      'Zähle einen Transfer zwischen zwei Säulen 3a nicht: Er ist kein neues Geld.';

  @override
  String get contributionEdgeBuyback =>
      'Halte einen nachträglichen Einkauf für ein früheres Jahr getrennt.';

  @override
  String get contributionEdgeFullRefund =>
      'Antworte nach einer vollständigen Rückzahlung Nein, wenn keine wirksame ordentliche Einzahlung übrig bleibt.';

  @override
  String get contributionEdgePartialRefund =>
      'Antworte nach einer teilweisen Rückzahlung Ja, wenn der Anbieter einen positiven Nettobetrag bestätigt.';

  @override
  String get contributionEdgeUnclearCorrection =>
      'Wenn eine Korrektur den wirksamen Betrag unklar macht, wähle «Ich weiss es nicht».';

  @override
  String get contributionEdgeMixedTransfer =>
      'Wenn Transfer und neues Geld zusammen eingehen, zähle nur das neue Geld.';

  @override
  String get contributionEdgeReturn =>
      'Zähle Anlageerträge oder Zinsen nicht als Einzahlung.';

  @override
  String get contributionEdgeAdjustment =>
      'Zähle keine Gebührenrückerstattung, Vergütung oder andere Korrektur.';

  @override
  String get contributionUnknownEyebrow => 'KEIN PROBLEM';

  @override
  String get contributionUnknownTitle =>
      'Du kannst nachsehen, ohne selbst zusammenzurechnen.';

  @override
  String contributionUnknownBody(int taxYear) {
    return 'Prüfe bei jeder deiner Säulen 3a, ob für $taxYear eine ordentliche Einzahlung eingegangen ist. Wenn Transfer, Einkauf oder Rückzahlung die Antwort unklar machen, bleibe bei «Ich weiss es nicht».';
  }

  @override
  String get contributionUnknownListLabel => 'So prüfst du es, ohne zu raten';

  @override
  String contributionUnknownProviderStatement(int taxYear) {
    return 'Suche in jeder Bank- oder Fintech-App oder Abrechnung nach einer für $taxYear eingegangenen Gutschrift.';
  }

  @override
  String get contributionUnknownInsuranceCertificate =>
      'Prüfe bei einer 3a-Versicherung die Jahresbescheinigung oder frage nach der eingegangenen ordentlichen Einzahlung.';

  @override
  String get contributionUnknownProviderQuestion =>
      'Frage im Zweifel den Anbieter, ob die Bewegung eine ordentliche Einzahlung, ein Transfer, Einkauf oder eine Rückzahlung ist.';

  @override
  String get contributionUnknownTransferWarning =>
      'Addiere nie einen Transfer zwischen zwei Säulen 3a. Sonst zählst du dasselbe Geld doppelt.';

  @override
  String get contributionUnknownEducationLimit =>
      'Du kannst ohne persönlichen Betrag fortfahren. MINT zeigt nur eine allgemeine Erklärung.';

  @override
  String get contributionUnknownContinueEducation =>
      'Mit einer allgemeinen Erklärung fortfahren';

  @override
  String get contributionBackToQuestion => 'Zurück zur Frage';

  @override
  String contributionAmountBoundaryTitle(int taxYear) {
    return 'Als Nächstes fragt MINT nach dem bereits für $taxYear eingegangenen ordentlichen Gesamtbetrag.';
  }

  @override
  String contributionAmountBoundaryBody(int taxYear) {
    return 'Der Gesamtbetrag muss alle deine 3a-Konten und -Policen umfassen. Nach einer teilweisen Rückzahlung kannst du den vom Anbieter bestätigten Nettobetrag verwenden. Noch ist kein Betrag bekannt oder berechnet.';
  }

  @override
  String contributionCantonBoundaryTitle(int taxYear) {
    return 'Gemäss deiner Antwort wird für $taxYear keine ordentliche Einzahlung berücksichtigt.';
  }

  @override
  String get contributionCantonBoundaryBody =>
      'Es wurde noch kein persönliches Steuerergebnis berechnet. Als Nächstes fragen wir nach deinem Kanton.';

  @override
  String get contributionBoundaryBack => 'Antwort korrigieren';

  @override
  String get contributionEducationTitle =>
      'Du kannst die Regel ohne Betrag verstehen.';

  @override
  String get contributionEducationBody =>
      'Diese Erklärung bleibt allgemein: Es werden weder ein persönlicher Betrag noch dein 3a-Spielraum oder eine persönliche Steuerersparnis berechnet.';

  @override
  String get contributionEducationBack => 'Zurück zur Prüfung';

  @override
  String batch11AmountEyebrow(int taxYear) {
    return 'DEINE 3A-BEITRÄGE · $taxYear';
  }

  @override
  String batch11AmountTitle(int taxYear) {
    return 'Wie viel haben alle deine 3a-Anbieter $taxYear tatsächlich erhalten?';
  }

  @override
  String get batch11AmountBody =>
      'Erfasse pro Anbieter den bestätigten Gesamtbetrag der ordentlichen Beiträge. MINT addiert.';

  @override
  String get batch11ProviderNameLabel =>
      'Name des Anbieters (z. B. VIAC oder deine Bank)';

  @override
  String get batch11ProviderNamePrivacy =>
      'Keine Konto-, Policen-, AHV- oder IBAN-Nummer eingeben.';

  @override
  String batch11OrdinaryAmountLabel(int taxYear) {
    return 'Bestätigte ordentliche Beiträge für $taxYear';
  }

  @override
  String get batch11NotTaxResult => 'Diese Summe ist noch kein Steuerergebnis.';

  @override
  String batch11AllProvidersReviewed(int taxYear) {
    return 'Ich habe alle meine 3a-Anbieter für $taxYear geprüft';
  }

  @override
  String get batch11WhereFindTitle => 'Wo finde ich den Betrag?';

  @override
  String get batch11WhereFindBody =>
      'Suche auf der Bescheinigung jedes Anbieters „Total Beiträge an die Säule 3a“. Verwende dieses Anbietertotal einmal, auch wenn es mehrere Verträge umfasst.';

  @override
  String get batch11UnknownAmount => 'Ich kenne noch keinen Betrag';

  @override
  String get batch11Continue => 'Weiter';

  @override
  String get batch11CorrectPrevious => 'Vorherige Antwort korrigieren';

  @override
  String get batch11ProviderNameEmpty => 'Gib den Namen des Anbieters ein.';

  @override
  String get batch11ProviderNameSensitive =>
      'Verwende nur den Anbieternamen, ohne Konto-, Policen-, AHV- oder IBAN-Nummer.';

  @override
  String get batch11AmountInvalid => 'Gib einen gültigen CHF-Betrag ein.';

  @override
  String get batch11AmountZero => 'Der Betrag muss grösser als null sein.';

  @override
  String get batch11ReviewAllRequired =>
      'Bestätige, dass du alle deine 3a-Anbieter geprüft hast.';

  @override
  String get batch11HelpTitle => 'Finde zuerst einen bestätigten Betrag.';

  @override
  String get batch11HelpUnknownBody =>
      'Beginne mit der Bescheinigung eines 3a-Anbieters. Suche den Gesamtbetrag der ordentlichen Beiträge des Jahres, ohne Transfer, Einkauf oder Rückerstattung.';

  @override
  String get batch11HelpFoundFirst => 'Ich habe einen ersten Betrag gefunden';

  @override
  String get batch11HelpEducationOnly =>
      'Mit einer allgemeinen Erklärung fortfahren';

  @override
  String get batch11HelpBack => 'Zurück zur Eingabe';

  @override
  String get batch11MissingAmount => 'Mir fehlt der Betrag eines 3a-Anbieters';

  @override
  String get batch11HelpPartialBody =>
      'Behalte die bereits erfassten Beträge. Mindestens ein Anbieter fehlt noch: Finde seinen bestätigten Gesamtbetrag vor der Bestätigung.';

  @override
  String get batch11HelpFoundPartial => 'Fehlenden Betrag hinzufügen';
}
