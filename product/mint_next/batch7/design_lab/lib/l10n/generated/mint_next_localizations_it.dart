// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'mint_next_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class MintNextLocalizationsIt extends MintNextLocalizations {
  MintNextLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get brand => 'MINT';

  @override
  String get quit => 'Esci';

  @override
  String get todayEyebrow => 'OGGI · PILASTRO 3A';

  @override
  String get todayTitle =>
      'Cosa cambia con un versamento nel pilastro 3a quest’anno?';

  @override
  String get todayBody =>
      'Capiremo gli effetti un passo alla volta. MINT ti informa, ma non decide al tuo posto.';

  @override
  String get start => 'Capire';

  @override
  String get orientationEyebrow => 'PRIMA DEI NUMERI';

  @override
  String get orientationTitle =>
      'Risparmiare per la tua pensione può anche ridurre le imposte.';

  @override
  String get orientationBody =>
      'Un versamento nel pilastro 3a può ridurre il tuo reddito imponibile — l’importo sul quale vengono calcolate le imposte. Il denaro che hai a disposizione diminuisce ora e il capitale 3a resta vincolato fino alla pensione, salvo i casi previsti dalla legge.';

  @override
  String get orientationNote =>
      'Prima verificheremo l’anno e la tua situazione. Non verrà consigliato alcun importo.';

  @override
  String get continueLabel => 'Continua';

  @override
  String get backLabel => 'Indietro';

  @override
  String get taxYearEyebrow => 'PASSO 1 · ANNO FISCALE';

  @override
  String get taxYearTitle => 'Di quale anno stiamo parlando?';

  @override
  String get taxYearBody =>
      'Il limite dipende dall’anno e dalla tua situazione, in particolare dal reddito da attività lucrativa e dall’affiliazione a una cassa pensione. L’anno corrente viene proposto, mai scelto al tuo posto.';

  @override
  String currentYearLabel(int year) {
    return 'Anno corrente: $year';
  }

  @override
  String confirmYear(int year) {
    return 'Scegli $year';
  }

  @override
  String yearChosen(int year) {
    return 'Anno $year selezionato';
  }

  @override
  String get partialBoundary =>
      'La schermata successiva sarà aggiunta nel prossimo piccolo lotto. Nulla viene salvato.';

  @override
  String get safeExitTitle => 'Vuoi fermarti qui?';

  @override
  String get safeExitBody =>
      'Nessun dato finanziario personale viene salvato in questo Design Lab.';

  @override
  String get resume => 'Continua qui';

  @override
  String get leave => 'Esci senza salvare';

  @override
  String get dismissedTitle => 'Percorso chiuso';

  @override
  String get startShort => 'Iniziare';

  @override
  String get keepReferenceUnavailable =>
      'Promemoria locale — presto disponibile';

  @override
  String get lppQuestionEyebrow => 'LA TUA SITUAZIONE';

  @override
  String get lppQuestionTitle => 'Hai attualmente una cassa pensione?';

  @override
  String get lppQuestionBody =>
      'È chiamata anche previdenza professionale, LPP o secondo pilastro. Puoi essere affiliato tramite il lavoro o volontariamente. Ti chiediamo se sei attualmente assicurato, non quanto versi.';

  @override
  String get lppQuestionEvidence =>
      'Per verificare, cerca una voce LPP o cassa pensione su un conteggio salario, consulta un certificato recente oppure chiedi alla tua cassa pensione, al datore di lavoro o alle risorse umane.';

  @override
  String get lppChoiceYes => 'Sì';

  @override
  String get lppChoiceNo => 'No';

  @override
  String get lppChoiceUnknown => 'Non lo so';

  @override
  String get lppUnknownEyebrow => 'NESSUN PROBLEMA';

  @override
  String get lppUnknownTitle => 'Puoi verificarlo senza indovinare.';

  @override
  String get lppUnknownBody =>
      'Inizia da ciò che ti sembra più semplice. Quando avrai la risposta, riprendi questo percorso e rispondi di nuovo alla domanda.';

  @override
  String get lppUnknownListLabel =>
      'Tre modi per verificare la tua affiliazione';

  @override
  String get lppUnknownPayslip =>
      'Cerca LPP, secondo pilastro o cassa pensione su un conteggio salario recente.';

  @override
  String get lppUnknownCertificate =>
      'Cerca un certificato di previdenza recente inviato dalla tua cassa pensione.';

  @override
  String get lppUnknownAsk =>
      'Chiedi alla tua cassa pensione, al datore di lavoro o alle risorse umane se sei attualmente affiliato.';

  @override
  String get lppBackToQuestion => 'Torna alla domanda';

  @override
  String get lppKeepChecklist => 'Conserva questa lista sul dispositivo';

  @override
  String get localReferenceUnavailable => 'Disponibile presto';

  @override
  String get withoutLppEyebrow => 'SI APPLICA UN’ALTRA REGOLA';

  @override
  String get withoutLppTitle =>
      'Potresti comunque poter versare nel pilastro 3a, ma con regole diverse.';

  @override
  String get withoutLppBody =>
      'La tua risposta non significa che non hai diritto al pilastro 3a. Questo primo calcolo semplicemente non copre ancora il tuo caso.';

  @override
  String get lppCorrectAnswer => 'Correggi la mia risposta';

  @override
  String get withoutLppKeepExplanation =>
      'Conserva questa spiegazione sul dispositivo';

  @override
  String get nextStepEyebrow => 'PROSSIMO PASSO';

  @override
  String get nextStepTitle => 'La tua affiliazione è chiara.';

  @override
  String get nextStepBody =>
      'La prossima domanda riguarderà ciò che hai già versato quest’anno. Sarà aggiunta nel prossimo piccolo lotto. Nulla viene salvato.';

  @override
  String get quitJourney => 'Uscire da questo percorso';

  @override
  String contributionEyebrow(int taxYear) {
    return 'I TUOI VERSAMENTI 3A · $taxYear';
  }

  @override
  String contributionTitle(int taxYear) {
    return 'Nel $taxYear, uno dei tuoi pilastri 3a ha ricevuto un nuovo versamento?';
  }

  @override
  String get contributionBody =>
      'Rispondi considerando tutti i tuoi pilastri 3a, compresa un’assicurazione 3a.';

  @override
  String contributionCreditedNote(int taxYear) {
    return 'Conta solo il denaro nuovo ricevuto per il $taxYear. Un pagamento soltanto inviato o addebitato non conta ancora; nemmeno un trasferimento, un rendimento o un rimborso di spese.';
  }

  @override
  String get contributionAmountNote =>
      'Non devi ancora conoscere il totale. Te lo chiederemo solo se rispondi sì.';

  @override
  String get contributionChoiceYes =>
      'Sì, è stato ricevuto un nuovo versamento';

  @override
  String get contributionChoiceNo => 'No, nessun nuovo versamento';

  @override
  String get contributionChoiceUnknown => 'Non lo so';

  @override
  String contributionChoiceGroupLabel(int taxYear) {
    return 'Nuovi versamenti 3a ricevuti nel $taxYear';
  }

  @override
  String get contributionEdgeHelp => 'Che cosa conta — e che cosa no';

  @override
  String get contributionEdgePending =>
      'Un pagamento pianificato, inviato o addebitato conta solo quando arriva sul tuo 3a.';

  @override
  String get contributionEdgeTransfer =>
      'Non contare un trasferimento tra due pilastri 3a: non è denaro nuovo.';

  @override
  String get contributionEdgeBuyback =>
      'Tieni separato un riscatto retroattivo per un anno passato.';

  @override
  String get contributionEdgeFullRefund =>
      'Dopo un rimborso totale, rispondi no se non resta alcun versamento ordinario effettivo.';

  @override
  String get contributionEdgePartialRefund =>
      'Dopo un rimborso parziale, rispondi sì se l’istituto conferma un importo netto positivo.';

  @override
  String get contributionEdgeUnclearCorrection =>
      'Se una correzione rende incerto l’importo effettivo, scegli «Non lo so».';

  @override
  String get contributionEdgeMixedTransfer =>
      'Se arrivano insieme un trasferimento e denaro nuovo, conta solo il denaro nuovo.';

  @override
  String get contributionEdgeReturn =>
      'Non contare rendimenti o interessi come versamento.';

  @override
  String get contributionEdgeAdjustment =>
      'Non contare rimborsi di spese, accrediti o altre rettifiche.';

  @override
  String get contributionUnknownEyebrow => 'NESSUN PROBLEMA';

  @override
  String get contributionUnknownTitle =>
      'Puoi verificare senza fare tu la somma.';

  @override
  String contributionUnknownBody(int taxYear) {
    return 'Controlla su ogni tuo 3a se nel $taxYear è stato ricevuto un versamento ordinario. Se un trasferimento, riscatto o rimborso rende incerta la risposta, mantieni «Non lo so».';
  }

  @override
  String get contributionUnknownListLabel => 'Come verificare senza indovinare';

  @override
  String contributionUnknownProviderStatement(int taxYear) {
    return 'Nell’app o nell’estratto di ogni banca o fintech 3a, cerca un accredito ricevuto per il $taxYear.';
  }

  @override
  String get contributionUnknownInsuranceCertificate =>
      'Per un’assicurazione 3a, consulta l’attestazione annuale o chiedi quale versamento ordinario è stato ricevuto.';

  @override
  String get contributionUnknownProviderQuestion =>
      'In caso di dubbio, chiedi all’istituto se il movimento è un versamento ordinario, un trasferimento, un riscatto o un rimborso.';

  @override
  String get contributionUnknownTransferWarning =>
      'Non sommare mai un trasferimento tra due 3a: conteresti due volte lo stesso denaro.';

  @override
  String get contributionUnknownEducationLimit =>
      'Puoi continuare senza un importo personale. MINT mostrerà solo una spiegazione generale.';

  @override
  String get contributionUnknownContinueEducation =>
      'Continuare con una spiegazione generale';

  @override
  String get contributionBackToQuestion => 'Tornare alla domanda';

  @override
  String contributionAmountBoundaryTitle(int taxYear) {
    return 'In seguito MINT chiederà il totale ordinario già ricevuto per il $taxYear.';
  }

  @override
  String contributionAmountBoundaryBody(int taxYear) {
    return 'Il totale dovrà comprendere tutti i tuoi conti e le tue polizze 3a. Dopo un rimborso parziale potrai usare l’importo netto confermato dall’istituto. Per ora nessun importo è noto o calcolato.';
  }

  @override
  String contributionCantonBoundaryTitle(int taxYear) {
    return 'In base alla tua risposta, per il $taxYear non viene considerato alcun versamento ordinario.';
  }

  @override
  String get contributionCantonBoundaryBody =>
      'Non è ancora stato calcolato alcun risultato fiscale personale. Il prossimo passo chiederà il tuo cantone.';

  @override
  String get contributionBoundaryBack => 'Correggere la risposta';

  @override
  String get contributionEducationTitle =>
      'Puoi capire la regola senza indicare un importo.';

  @override
  String get contributionEducationBody =>
      'Questa spiegazione resta generale: non vengono calcolati importi personali, margine 3a o risparmi fiscali personali.';

  @override
  String get contributionEducationBack => 'Tornare alle verifiche';

  @override
  String batch11AmountEyebrow(int taxYear) {
    return 'I TUOI CONTRIBUTI 3A · $taxYear';
  }

  @override
  String batch11AmountTitle(int taxYear) {
    return 'Quanto hanno effettivamente ricevuto in totale tutti i tuoi istituti 3a nel $taxYear?';
  }

  @override
  String get batch11AmountBody =>
      'Inserisci per ogni istituto il totale confermato dei contributi ordinari. MINT li somma.';

  @override
  String get batch11ProviderNameLabel =>
      'Nome dell’istituto (ad es. VIAC o la tua banca)';

  @override
  String get batch11ProviderNamePrivacy =>
      'Non inserire numeri di conto, polizza, AVS o IBAN.';

  @override
  String batch11OrdinaryAmountLabel(int taxYear) {
    return 'Contributi ordinari confermati per il $taxYear';
  }

  @override
  String get batch11NotTaxResult =>
      'Questo totale non è ancora un risultato fiscale.';

  @override
  String batch11AllProvidersReviewed(int taxYear) {
    return 'Ho verificato tutti i miei istituti 3a per il $taxYear';
  }

  @override
  String get batch11WhereFindTitle => 'Dove trovo l’importo?';

  @override
  String get batch11WhereFindBody =>
      'Sull’attestazione di ogni istituto cerca «Totale contributi al pilastro 3a». Usa una sola volta il totale dell’istituto, anche se comprende più contratti.';

  @override
  String get batch11UnknownAmount => 'Non conosco ancora alcun importo';

  @override
  String get batch11Continue => 'Continua';

  @override
  String get batch11CorrectPrevious => 'Correggi la risposta precedente';

  @override
  String get batch11ProviderNameEmpty => 'Inserisci il nome dell’istituto.';

  @override
  String get batch11ProviderNameSensitive =>
      'Usa solo il nome dell’istituto, senza numeri di conto, polizza, AVS o IBAN.';

  @override
  String get batch11AmountInvalid => 'Inserisci un importo CHF valido.';

  @override
  String get batch11AmountZero => 'L’importo deve essere superiore a zero.';

  @override
  String get batch11ReviewAllRequired =>
      'Conferma di avere verificato tutti i tuoi istituti 3a.';

  @override
  String get batch11HelpTitle => 'Trova prima un importo confermato.';

  @override
  String get batch11HelpUnknownBody =>
      'Inizia dall’attestazione di un istituto 3a. Cerca il totale dei contributi ordinari dell’anno, senza aggiungere trasferimenti, contributi retroattivi o rimborsi.';

  @override
  String get batch11HelpFoundFirst => 'Ho trovato un primo importo';

  @override
  String get batch11HelpEducationOnly =>
      'Continua con una spiegazione generale';

  @override
  String get batch11HelpBack => 'Torna all’inserimento';
}
