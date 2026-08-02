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

  @override
  String get quitJourney => 'Sair deste percurso';

  @override
  String contributionEyebrow(int taxYear) {
    return 'AS TUAS CONTRIBUIÇÕES 3A · $taxYear';
  }

  @override
  String contributionTitle(int taxYear) {
    return 'Em $taxYear, algum dos teus pilares 3a recebeu uma nova contribuição?';
  }

  @override
  String get contributionBody =>
      'Responde considerando todos os teus pilares 3a, incluindo um seguro 3a.';

  @override
  String contributionCreditedNote(int taxYear) {
    return 'Conta apenas o dinheiro novo recebido para $taxYear. Um pagamento apenas enviado ou debitado ainda não conta; nem uma transferência, rendimento ou reembolso de despesas.';
  }

  @override
  String get contributionAmountNote =>
      'Ainda não precisas de saber o total. Só perguntaremos se responderes sim.';

  @override
  String get contributionChoiceYes => 'Sim, foi recebida uma nova contribuição';

  @override
  String get contributionChoiceNo => 'Não, nenhuma nova contribuição';

  @override
  String get contributionChoiceUnknown => 'Não sei';

  @override
  String contributionChoiceGroupLabel(int taxYear) {
    return 'Novas contribuições 3a recebidas em $taxYear';
  }

  @override
  String get contributionEdgeHelp => 'O que conta — e o que não conta';

  @override
  String get contributionEdgePending =>
      'Um pagamento planeado, enviado ou debitado só conta quando chega ao teu 3a.';

  @override
  String get contributionEdgeTransfer =>
      'Não contes uma transferência entre dois pilares 3a: não é dinheiro novo.';

  @override
  String get contributionEdgeBuyback =>
      'Mantém separada uma contribuição retroativa para colmatar uma lacuna de um ano anterior.';

  @override
  String get contributionEdgeFullRefund =>
      'Após um reembolso total, responde não se não restar nenhuma contribuição ordinária efetiva.';

  @override
  String get contributionEdgePartialRefund =>
      'Após um reembolso parcial, responde sim se a instituição confirmar um valor líquido positivo.';

  @override
  String get contributionEdgeUnclearCorrection =>
      'Se uma correção tornar incerto o valor efetivo, escolhe «Não sei».';

  @override
  String get contributionEdgeMixedTransfer =>
      'Se uma transferência e dinheiro novo chegarem juntos, conta apenas o dinheiro novo.';

  @override
  String get contributionEdgeReturn =>
      'Não contes rendimentos ou juros como contribuição.';

  @override
  String get contributionEdgeAdjustment =>
      'Não contes reembolsos de despesas, bonificações ou outros ajustes.';

  @override
  String get contributionUnknownEyebrow => 'SEM PROBLEMA';

  @override
  String get contributionUnknownTitle =>
      'Podes verificar sem fazer as contas sozinho.';

  @override
  String contributionUnknownBody(int taxYear) {
    return 'Verifica em cada um dos teus 3a se foi recebida uma contribuição ordinária para $taxYear. Se uma transferência, uma contribuição retroativa para colmatar uma lacuna de um ano anterior ou um reembolso tornar a resposta incerta, mantém «Não sei».';
  }

  @override
  String get contributionUnknownListLabel => 'Como verificar sem adivinhar';

  @override
  String contributionUnknownProviderStatement(int taxYear) {
    return 'Na app ou extrato de cada banco ou fintech 3a, procura um crédito recebido para $taxYear.';
  }

  @override
  String get contributionUnknownInsuranceCertificate =>
      'Para um seguro 3a, consulta a declaração anual ou pergunta que contribuição ordinária foi recebida.';

  @override
  String get contributionUnknownProviderQuestion =>
      'Em caso de dúvida, pergunta à instituição se o movimento é uma contribuição ordinária, uma transferência, uma contribuição retroativa para colmatar uma lacuna de um ano anterior ou um reembolso.';

  @override
  String get contributionUnknownTransferWarning =>
      'Nunca somes uma transferência entre dois 3a. Contarias o mesmo dinheiro duas vezes.';

  @override
  String get contributionUnknownEducationLimit =>
      'Podes continuar sem um valor pessoal. A MINT mostrará apenas uma explicação geral.';

  @override
  String get contributionUnknownContinueEducation =>
      'Continuar com uma explicação geral';

  @override
  String get contributionBackToQuestion => 'Voltar à pergunta';

  @override
  String contributionAmountBoundaryTitle(int taxYear) {
    return 'Depois, a MINT pedirá o total ordinário já recebido para $taxYear.';
  }

  @override
  String contributionAmountBoundaryBody(int taxYear) {
    return 'O total deverá abranger todas as tuas contas e apólices 3a. Após um reembolso parcial, poderás usar o valor líquido confirmado pela instituição. Por agora, nenhum valor é conhecido ou calculado.';
  }

  @override
  String contributionCantonBoundaryTitle(int taxYear) {
    return 'Segundo a tua resposta, nenhuma contribuição ordinária é considerada para $taxYear.';
  }

  @override
  String get contributionCantonBoundaryBody =>
      'Ainda não foi calculado qualquer resultado fiscal pessoal. O passo seguinte perguntará o teu cantão.';

  @override
  String get contributionBoundaryBack => 'Corrigir a minha resposta';

  @override
  String get contributionEducationTitle =>
      'Podes compreender a regra sem indicar um valor.';

  @override
  String get contributionEducationBody =>
      'Esta explicação continua geral: não é calculado qualquer valor pessoal, margem 3a ou poupança fiscal pessoal.';

  @override
  String get contributionEducationBack => 'Voltar às verificações';

  @override
  String batch11AmountEyebrow(int taxYear) {
    return 'AS TUAS CONTRIBUIÇÕES 3A · $taxYear';
  }

  @override
  String batch11AmountTitle(int taxYear) {
    return 'Quanto receberam efetivamente, no total, todos os teus prestadores 3a em $taxYear?';
  }

  @override
  String get batch11AmountBody =>
      'Indica o total confirmado das contribuições ordinárias de cada prestador. A MINT soma os valores.';

  @override
  String get batch11ProviderNameLabel =>
      'Nome do prestador (por ex., VIAC ou o teu banco)';

  @override
  String get batch11ProviderNamePrivacy =>
      'Não indiques números de conta, apólice, seguro social suíço ou IBAN.';

  @override
  String batch11OrdinaryAmountLabel(int taxYear) {
    return 'Contribuições ordinárias confirmadas de $taxYear';
  }

  @override
  String get batch11NotTaxResult =>
      'Este total ainda não é um resultado fiscal.';

  @override
  String batch11AllProvidersReviewed(int taxYear) {
    return 'Verifiquei todos os meus prestadores 3a de $taxYear';
  }

  @override
  String get batch11WhereFindTitle => 'Onde encontro o valor?';

  @override
  String get batch11WhereFindBody =>
      'No certificado de cada prestador, procura o total das contribuições para o pilar 3a. Usa-o uma única vez, mesmo que inclua vários contratos.';

  @override
  String get batch11UnknownAmount => 'Ainda não conheço nenhum valor';

  @override
  String get batch11Continue => 'Continuar';

  @override
  String get batch11CorrectPrevious => 'Corrigir a resposta anterior';

  @override
  String get batch11ProviderNameEmpty => 'Indica o nome do prestador.';

  @override
  String get batch11ProviderNameSensitive =>
      'Usa apenas o nome do prestador, sem números de conta, apólice, seguro social suíço ou IBAN.';

  @override
  String get batch11AmountInvalid => 'Indica um valor CHF válido.';

  @override
  String get batch11AmountZero => 'O valor deve ser superior a zero.';

  @override
  String get batch11ReviewAllRequired =>
      'Confirma que verificaste todos os teus prestadores 3a.';

  @override
  String get batch11HelpTitle => 'Primeiro encontra um valor confirmado.';

  @override
  String get batch11HelpUnknownBody =>
      'Começa pelo certificado de um prestador 3a. Procura o total das contribuições ordinárias do ano, sem adicionar transferências, contribuições retroativas ou reembolsos.';

  @override
  String get batch11HelpFoundFirst => 'Encontrei um primeiro valor';

  @override
  String get batch11HelpEducationOnly => 'Continuar com uma explicação geral';

  @override
  String get batch11HelpBack => 'Voltar à introdução';
}
