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
}
