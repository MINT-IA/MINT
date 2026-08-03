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
      'Beginne mit deinem 3a-Anbieter. Wenn du mehrere hast, gib nach diesem ersten Betrag an, dass noch einer fehlt.';

  @override
  String get batch11ProviderNameLabel => '3a-Anbieter';

  @override
  String get batch11ProviderNamePrivacy =>
      'Keine Konto-, Policen-, AHV- oder IBAN-Nummer eingeben.';

  @override
  String batch11OrdinaryAmountLabel(int taxYear) {
    return 'Gutgeschriebene ordentliche Beiträge · $taxYear';
  }

  @override
  String get batch11NotTaxResult => 'Diese Summe ist noch kein Steuerergebnis.';

  @override
  String batch11AllProvidersReviewed(int taxYear) {
    return 'Ich habe nur einen 3a-Anbieter und seinen Gesamtbetrag für $taxYear geprüft';
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
  String get batch11MissingAmount => 'Ich habe mehrere 3a-Anbieter';

  @override
  String get batch11HelpPartialBody =>
      'Dieser erste Ablauf kann mehrere Anbieter noch nicht addieren. Bestätige den Gesamtbetrag hier nicht. Falls du dich geirrt hast und nur einen hast, korrigiere deine Angabe; sonst fahre mit allgemeinen Hinweisen fort.';

  @override
  String get batch11HelpFoundPartial => 'Ich habe doch nur einen 3a-Anbieter';

  @override
  String batch12PositiveCantonTitle(int taxYear) {
    return 'Die Summe deiner ordentlichen Beiträge für $taxYear ist bereit.';
  }

  @override
  String get batch12PositiveCantonBody =>
      'Es wurde noch kein Steuerergebnis berechnet. Im nächsten Schritt wird dein Kanton gefragt.';

  @override
  String get batch12CorrectAmounts => 'Meine Beträge korrigieren';

  @override
  String get batch14AmountBody =>
      'Füge jeden Säule-3a-Anbieter einzeln hinzu. MINT addiert die Beträge lokal, ohne bereits ein Steuerergebnis zu berechnen.';

  @override
  String get batch14AddProvider => 'Säule-3a-Anbieter hinzufügen';

  @override
  String batch14ProviderRowLabel(int index) {
    return 'Säule-3a-Anbieter Nr. $index';
  }

  @override
  String batch14ProvisionalSubtotal(String amount) {
    return 'Vorläufige Summe — kein Steuerergebnis berechnet: $amount';
  }

  @override
  String batch14AllReviewed(int taxYear) {
    return 'Ich bestätige, dass ich für $taxYear nur die tatsächlich gutgeschriebenen ordentlichen Einzahlungen bei allen meinen Säule-3a-Anbietern erfasst habe';
  }

  @override
  String get batch14RemoveEmpty => 'Diese leere Zeile entfernen';

  @override
  String get batch14Duplicate =>
      'Dieser Anbieter ist bereits aufgeführt. Korrigiere seine Zeile, damit er nicht doppelt gezählt wird.';

  @override
  String get batch14AggregateOverflow =>
      'Die Summe ist zu gross. Prüfe die eingegebenen Beträge.';

  @override
  String get batch14EmptyBeforeAdd =>
      'Beginne oder entferne die leere Zeile, bevor du eine weitere hinzufügst.';

  @override
  String batch14ClassificationGuide(int taxYear) {
    return 'Für $taxYear entspricht eine Zeile dem Jahrestotal eines Anbieters, auch wenn du dort mehrere Verträge oder Policen hast. Erfasse nur tatsächlich gutgeschriebene ordentliche Einzahlungen und jeden Betrag nur einmal. Überträge, rückwirkende Einzahlungen, noch ausstehende oder nur belastete Zahlungen sowie Anlagerenditen gehören nicht dazu. Verwende nach einer Korrektur oder Rückerstattung den vom Anbieter bestätigten Nettobetrag.';
  }

  @override
  String get batch14Privacy =>
      'Lokale, vorübergehende Eingabe: Nichts wird gespeichert oder gesendet. Keine Konto-, Policen-, AHV- oder IBAN-Nummer eingeben. Beim Verlassen werden Namen und Beträge gelöscht.';

  @override
  String get batch14RemovedAnnouncement =>
      'Leere Zeile entfernt. Der Fokus liegt nun auf der benachbarten Zeile.';

  @override
  String get batch14ProviderCapacity =>
      'Diese Eingabe erlaubt höchstens 50 Anbieter. Prüfe die Liste, bevor du fortfährst.';

  @override
  String get batch15RemoveProvider =>
      'Diese Zeile aus meiner Eingabe entfernen';

  @override
  String batch15TombstoneLabel(int rowNumber) {
    return 'Zeile $rowNumber aus dieser Eingabe entfernt';
  }

  @override
  String batch15UndoRemoval(int rowNumber) {
    return 'Entfernen von Zeile $rowNumber rückgängig machen';
  }

  @override
  String batch15FinalizeRemoval(int rowNumber) {
    return 'Zeile $rowNumber endgültig aus dieser Eingabe löschen';
  }

  @override
  String batch15TombstonedAnnouncement(String subtotal) {
    return 'Zeile aus dieser Eingabe entfernt. Neuer vorläufiger Zwischensaldo: $subtotal.';
  }

  @override
  String batch15RestoredAnnouncement(String subtotal) {
    return 'Zeile in dieser Eingabe wiederhergestellt. Neuer vorläufiger Zwischensaldo: $subtotal.';
  }

  @override
  String get batch15FinalizedAnnouncement =>
      'Die entfernte Zeile wurde endgültig aus dieser Eingabe gelöscht.';

  @override
  String get batch15NoProvisionalSubtotal => 'kein positiver Betrag erfasst';

  @override
  String get batch15ResolveTombstoneError =>
      'Mache das Entfernen rückgängig oder lösche diese Zeile endgültig, bevor du fortfährst.';

  @override
  String get batch16AnnualOrdinaryTotalMeaning =>
      'Erfasse für jeden Anbieter einmal den Jahrestotalbetrag der ordentlichen Beiträge aus seiner Jahresbescheinigung.';

  @override
  String batch16ActuallyCreditedMeaning(int taxYear) {
    return 'Zähle nur, was für $taxYear tatsächlich gutgeschrieben wurde, nicht was geplant, überwiesen oder belastet wurde.';
  }

  @override
  String get batch16ExcludedMovementsMeaning =>
      'Schliesse Überträge, rückwirkende Einkäufe, ausstehende Bewegungen, Rückerstattungen und Anlagegewinne aus.';

  @override
  String get batch16ProviderConfirmedNetMeaning =>
      'Frage den Anbieter nach einer Korrektur oder Rückerstattung nach dem bestätigten Nettototal der ordentlichen Beiträge; ziehe selbst nichts ab.';

  @override
  String get batch16InsuranceCertificateMeaning =>
      'Verwende bei einer Versicherung die Jahresbescheinigung; nutze weder den Rückkaufswert noch die Aufteilung in Risiko und Sparen.';

  @override
  String get batch16RefundVsAllZeroMeaning =>
      'Eine vollständige Rückerstattung eines Anbieters bedeutet nicht, dass bei allen Anbietern null verbleibt.';

  @override
  String get batch16MintNotVerifiedMeaning =>
      'MINT hat den eingegebenen Betrag nicht überprüft.';

  @override
  String get batch16NoTaxAdviceMeaning =>
      'Dieser Schritt liefert weder ein Steuerergebnis noch eine Empfehlung.';

  @override
  String batch16RowContext(int rowNumber, int taxYear) {
    return 'Zeile $rowNumber · $taxYear';
  }

  @override
  String get batch16HelpTitle => 'Brauchst du Hilfe?';

  @override
  String get batch16HelpCompactTitle => 'Hilfe';

  @override
  String get batch16HelpCompactBody => 'MINT: nicht geprüft.';

  @override
  String get batch16HelpBody =>
      'MINT hat diesen Gesamtbetrag nicht geprüft. Wähle nur, wenn du sicher bist.';

  @override
  String get batch16HelpDetails => 'Regeln für diese Zeile verstehen';

  @override
  String get batch16HelpProviderTotal => 'Ordentlichen Gesamtbetrag erhalten';

  @override
  String get batch16HelpProviderTotalCompact => '3a-Betrag erhalten';

  @override
  String get batch16HelpProviderRefunded =>
      'Vollständige Rückerstattung dieses Anbieters';

  @override
  String get batch16HelpAllZero =>
      'Bei allen meinen Anbietern ist der Betrag null';

  @override
  String get batch16HelpEducation => 'Ich möchte verstehen, was zählt';

  @override
  String get batch16HelpBack => 'Zurück zur Eingabe';

  @override
  String get batch16StatusUnreviewed => 'Zu prüfen';

  @override
  String get batch16StatusConfirmed => 'Bestätigt';

  @override
  String get batch16StatusUnresolved => 'Ungeklärte Frage';

  @override
  String get batch16UnresolvedError =>
      'Beantworte diese Frage, bevor du fortfährst.';

  @override
  String get batch16CorrectionTitle => 'Diese Antwort korrigieren';

  @override
  String get batch16CorrectionDataLoss =>
      'Wenn du „Nein“ oder „Ich weiß es nicht“ wählst, löscht MINT sofort alle Anbieter und Beträge dieser lokalen Eingabe. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get batch16CurrentYes => 'Aktuelle Antwort: Ja';

  @override
  String get batch16Unselected => 'Keine Antwort ausgewählt';

  @override
  String get batch16ChooseYes => 'Ja auswählen';

  @override
  String get batch16ChooseNo => 'Nein — diese Beträge löschen und fortfahren';

  @override
  String get batch16ChooseUnknown =>
      'Ich weiß es nicht — Beträge löschen und prüfen';

  @override
  String get batch16Back => 'Zurück';
}
