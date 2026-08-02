// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'mint_next_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class MintNextLocalizationsPt extends MintNextLocalizations {
  MintNextLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get brand => 'MINT';

  @override
  String get quit => 'Sair';

  @override
  String get todayEyebrow => 'HOJE · PILAR 3A';

  @override
  String get todayTitle => 'O que muda se contribuir para o pilar 3a este ano?';

  @override
  String get todayBody =>
      'Vamos compreender os efeitos passo a passo. A MINT informa-te, mas não decide por ti.';

  @override
  String get start => 'Compreender';

  @override
  String get orientationEyebrow => 'ANTES DOS NÚMEROS';

  @override
  String get orientationTitle =>
      'Poupar para a tua reforma também pode reduzir os teus impostos.';

  @override
  String get orientationBody =>
      'Uma contribuição para o pilar 3a pode reduzir o teu rendimento tributável — o montante sobre o qual os impostos são calculados. O teu dinheiro disponível diminui agora e o capital 3a fica vinculado até à reforma, salvo nos casos previstos por lei.';

  @override
  String get orientationNote =>
      'Primeiro verificamos o ano e a tua situação. Não será recomendado qualquer montante.';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get backLabel => 'Voltar';

  @override
  String get taxYearEyebrow => 'PASSO 1 · ANO FISCAL';

  @override
  String get taxYearTitle => 'De que ano estamos a falar?';

  @override
  String get taxYearBody =>
      'O limite depende do ano e da tua situação, incluindo o rendimento profissional e a filiação numa caixa de pensões. O ano atual é proposto, nunca escolhido por ti.';

  @override
  String currentYearLabel(int year) {
    return 'Ano atual: $year';
  }

  @override
  String confirmYear(int year) {
    return 'Escolher $year';
  }

  @override
  String yearChosen(int year) {
    return 'Ano $year selecionado';
  }

  @override
  String get partialBoundary =>
      'O ecrã seguinte será adicionado no próximo pequeno lote. Nada é guardado.';

  @override
  String get safeExitTitle => 'Queres parar aqui?';

  @override
  String get safeExitBody =>
      'Este Design Lab não guarda dados financeiros pessoais.';

  @override
  String get resume => 'Continuar aqui';

  @override
  String get leave => 'Sair sem guardar';

  @override
  String get dismissedTitle => 'Percurso encerrado';

  @override
  String get startShort => 'Começar';

  @override
  String get keepReferenceUnavailable =>
      'Referência local — disponível em breve';

  @override
  String get lppQuestionEyebrow => 'A TUA SITUAÇÃO';

  @override
  String get lppQuestionTitle => 'Tens atualmente uma caixa de pensões?';

  @override
  String get lppQuestionBody =>
      'Também se chama previdência profissional, LPP ou segundo pilar. Podes estar afiliado através do trabalho ou voluntariamente. Perguntamos se tens cobertura atualmente, não quanto pagas.';

  @override
  String get lppQuestionEvidence =>
      'Para verificar, procura uma linha LPP ou caixa de pensões num recibo de salário, consulta um certificado recente ou pergunta à tua caixa de pensões, empregador ou recursos humanos.';

  @override
  String get lppChoiceYes => 'Sim';

  @override
  String get lppChoiceNo => 'Não';

  @override
  String get lppChoiceUnknown => 'Não sei';

  @override
  String get lppUnknownEyebrow => 'SEM PROBLEMA';

  @override
  String get lppUnknownTitle => 'Podes verificar sem adivinhar.';

  @override
  String get lppUnknownBody =>
      'Começa pelo que for mais fácil para ti. Quando tiveres a resposta, retoma este percurso e responde novamente à pergunta.';

  @override
  String get lppUnknownListLabel => 'Três formas de verificar a tua afiliação';

  @override
  String get lppUnknownPayslip =>
      'Procura LPP, segundo pilar ou caixa de pensões num recibo de salário recente.';

  @override
  String get lppUnknownCertificate =>
      'Procura um certificado de previdência recente enviado pela tua caixa de pensões.';

  @override
  String get lppUnknownAsk =>
      'Pergunta à tua caixa de pensões, empregador ou recursos humanos se estás atualmente afiliado.';

  @override
  String get lppBackToQuestion => 'Voltar à pergunta';

  @override
  String get lppKeepChecklist => 'Guardar esta lista neste dispositivo';

  @override
  String get localReferenceUnavailable => 'Em breve';

  @override
  String get withoutLppEyebrow => 'APLICA-SE OUTRA REGRA';

  @override
  String get withoutLppTitle =>
      'Talvez possas contribuir para o pilar 3a, mas aplicam-se outras regras.';

  @override
  String get withoutLppBody =>
      'A tua resposta não significa que não tens direito ao pilar 3a. Este primeiro cálculo simplesmente ainda não cobre este caso.';

  @override
  String get lppCorrectAnswer => 'Corrigir a minha resposta';

  @override
  String get withoutLppKeepExplanation =>
      'Guardar esta explicação neste dispositivo';

  @override
  String get nextStepEyebrow => 'PRÓXIMO PASSO';

  @override
  String get nextStepTitle => 'A tua afiliação está clara.';

  @override
  String get nextStepBody =>
      'A próxima pergunta será sobre o que já pagaste este ano. Será adicionada no próximo pequeno lote. Nada é guardado.';
}
