// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class SPt extends S {
  SPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'MINT';

  @override
  String get landingHero => 'Financial OS.';

  @override
  String get landingSubtitle => 'O teu copiloto financeiro suico.';

  @override
  String get landingBetaBadge => 'Beta Privada';

  @override
  String get landingHeroPrefix => 'O primeiro';

  @override
  String get landingSubtitleLong =>
      'A inteligencia de um CFO, no teu bolso.\nZero tretas. Puro conselho.';

  @override
  String get landingFeature1Title => 'Diagnostico Instantaneo';

  @override
  String get landingFeature1Desc => 'Analise 360° em 5 minutos.';

  @override
  String get landingFeature2Title => '100% Privado & Local';

  @override
  String get landingFeature2Desc => 'Os teus dados ficam no teu dispositivo.';

  @override
  String get landingFeature3Title => 'Estrategia Neutra';

  @override
  String get landingFeature3Desc => 'Zero comissao. Zero conflito.';

  @override
  String get landingDiagnosticSubtitle => 'Balanco 360° • 5 minutos';

  @override
  String get landingResumeDiagnostic => 'Retomar o meu diagnostico';

  @override
  String get startDiagnostic => 'Iniciar o meu diagnostico';

  @override
  String get tabNow => 'AGORA';

  @override
  String get tabExplore => 'Explorar';

  @override
  String get tabTrack => 'SEGUIR';

  @override
  String get budgetTitle => 'Dominar o meu Orcamento';

  @override
  String get simulatorsTitle => 'Simuladores de Viagem';

  @override
  String get recommendations => 'As tuas Recomendacoes';

  @override
  String get disclaimer =>
      'Os resultados apresentados sao estimativas a titulo indicativo. Nao constituem aconselhamento financeiro personalizado.';

  @override
  String get onboardingSkip => 'Saltar';

  @override
  String onboardingProgress(String step, String total) {
    return 'Passo $step de $total';
  }

  @override
  String get onboardingStep1Title => 'Ola, sou o teu mentor.';

  @override
  String get onboardingStep1Subtitle =>
      'Vamos comecar por nos conhecer. Qual e a tua situacao atual?';

  @override
  String get onboardingHouseholdSingle => 'Sozinho/a';

  @override
  String get onboardingHouseholdSingleDesc =>
      'Giro as minhas financas sozinho/a';

  @override
  String get onboardingHouseholdCouple => 'Em casal';

  @override
  String get onboardingHouseholdCoupleDesc =>
      'Partilhamos os nossos objetivos financeiros';

  @override
  String get onboardingHouseholdFamily => 'Familia';

  @override
  String get onboardingHouseholdFamilyDesc => 'Com filhos a cargo';

  @override
  String get onboardingHouseholdSingleParent => 'Pai/mae solteiro(a)';

  @override
  String get onboardingHouseholdSingleParentDesc =>
      'Giro sozinho(a) com filhos a cargo';

  @override
  String get onboardingStep2Title => 'Muito bem.';

  @override
  String get onboardingStep2Subtitle =>
      'Que viagem financeira queres empreender em primeiro lugar?';

  @override
  String get onboardingGoalHouse => 'Tornar-me proprietario';

  @override
  String get onboardingGoalHouseDesc => 'Preparar a minha entrada e hipoteca';

  @override
  String get onboardingGoalRetire => 'Serenidade na Reforma';

  @override
  String get onboardingGoalRetireDesc => 'Maximizar o meu futuro a longo prazo';

  @override
  String get onboardingGoalInvest => 'Investir & Crescer';

  @override
  String get onboardingGoalInvestDesc =>
      'Fazer crescer as minhas poupancas de forma inteligente';

  @override
  String get onboardingGoalTaxOptim => 'Otimizacao Fiscal';

  @override
  String get onboardingGoalTaxOptimDesc =>
      'Reduzir os meus impostos legalmente';

  @override
  String get onboardingStep3Title => 'Quase la.';

  @override
  String get onboardingStep3Subtitle =>
      'Estes detalhes permitem-nos personalizar os teus calculos segundo a lei suica.';

  @override
  String get onboardingCantonLabel => 'Cantao de residencia';

  @override
  String get onboardingCantonHint => 'Seleciona o teu cantao';

  @override
  String get onboardingBirthYearLabel => 'Ano de nascimento (opcional)';

  @override
  String get onboardingBirthYearHint => 'Ex: 1990';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingStep4Title => 'Pronto para comecar?';

  @override
  String get onboardingStep4Subtitle =>
      'O Mint e um ambiente seguro. Eis os nossos compromissos contigo.';

  @override
  String get onboardingTrustTransparency => 'Transparencia total';

  @override
  String get onboardingTrustTransparencyDesc =>
      'Todas as hipoteses sao visiveis.';

  @override
  String get onboardingTrustPrivacy => 'Privacidade';

  @override
  String get onboardingTrustPrivacyDesc =>
      'Calculos locais, sem armazenamento de dados sensiveis.';

  @override
  String get onboardingTrustSecurity => 'Seguranca';

  @override
  String get onboardingTrustSecurityDesc =>
      'Sem acesso direto ao teu dinheiro.';

  @override
  String get onboardingEnterSpace => 'Entrar no meu espaco';

  @override
  String get advisorMiniStep1Title => 'Qual e a tua prioridade?';

  @override
  String get advisorMiniStep1Subtitle =>
      'A MINT adapta-se ao que mais importa para ti agora';

  @override
  String get advisorMiniFirstNameLabel => 'Primeiro nome (opcional)';

  @override
  String get advisorMiniFirstNameHint => 'Nome';

  @override
  String get advisorMiniStressBudget => 'Controlar o meu orcamento';

  @override
  String get advisorMiniStressDebt => 'Reduzir as minhas dividas';

  @override
  String get advisorMiniStressTax => 'Otimizar os meus impostos';

  @override
  String get advisorMiniStressRetirement => 'Proteger a minha reforma';

  @override
  String advisorMiniResumeDiagnostic(String progress) {
    return 'Retomar o meu diagnostico ($progress%)';
  }

  @override
  String get advisorMiniFullDiagnostic => 'Diagnostico completo (10 min)';

  @override
  String get advisorMiniStep2Title => 'O essencial';

  @override
  String get advisorMiniStep2Subtitle => 'Idade e cantao mudam tudo na Suica';

  @override
  String get advisorMiniBirthYearLabel => 'Ano de nascimento';

  @override
  String get advisorMiniBirthYearInvalid => 'Ano invalido';

  @override
  String advisorMiniBirthYearRange(String maxYear) {
    return 'Entre 1940 e $maxYear';
  }

  @override
  String get advisorMiniCantonLabel => 'Cantao de residencia';

  @override
  String get advisorMiniCantonHint => 'Selecionar';

  @override
  String get advisorMiniStep3Title => 'O teu rendimento';

  @override
  String get advisorMiniStep3Subtitle =>
      'Para calcular o teu potencial de poupanca';

  @override
  String get advisorMiniIncomeLabel => 'Rendimento liquido mensal (CHF)';

  @override
  String get advisorMiniHousingTitle => 'Habitacao';

  @override
  String get advisorMiniHousingTenant => 'Arrendatario/a';

  @override
  String get advisorMiniHousingOwner => 'Proprietario/a';

  @override
  String get advisorMiniHousingHosted => 'Alojado/a / sem renda';

  @override
  String get advisorMiniHousingCostTenant => 'Renda / custos habitacao / mes';

  @override
  String get advisorMiniHousingCostOwner => 'Custos habitacao / hipoteca / mes';

  @override
  String get advisorMiniDebtPaymentsLabel =>
      'Prestacoes de divida / leasing / mes';

  @override
  String get advisorMiniPatrimonyTitle => 'Património (opcional)';

  @override
  String get advisorMiniCashSavingsLabel => 'Liquidez / poupança disponível';

  @override
  String get advisorMiniInvestmentsTotalLabel =>
      'Investimentos (títulos, ETF, fundos)';

  @override
  String get advisorMiniPillar3aTotalLabel => 'Total 3a aproximado';

  @override
  String get advisorMiniCivilStatusLabel => 'Estado civil do casal';

  @override
  String get advisorMiniCivilStatusMarried => 'Casado/a';

  @override
  String get advisorMiniCivilStatusConcubinage => 'Em uniao de facto';

  @override
  String get advisorMiniPartnerIncomeLabel =>
      'Rendimento liquido mensal do parceiro';

  @override
  String get advisorMiniPartnerBirthYearLabel =>
      'Ano de nascimento do parceiro';

  @override
  String get advisorMiniPartnerFirstNameLabel =>
      'Primeiro nome do parceiro (opcional)';

  @override
  String get advisorMiniPartnerFirstNameHint => 'Nome';

  @override
  String get advisorMiniPartnerStatusHint => 'Parceiro';

  @override
  String get advisorMiniPartnerStatusInactive => 'Sem atividade';

  @override
  String get advisorMiniPartnerRequiredTitle =>
      'Dados do parceiro obrigatorios';

  @override
  String get advisorMiniPartnerRequiredBody =>
      'Adiciona estado civil, rendimento, ano de nascimento e estado do parceiro para uma projecao familiar fiavel.';

  @override
  String get advisorMiniPartnerProfileTitle => 'Perfil do/da parceiro/a';

  @override
  String get advisorReadinessLabel => 'Completude do perfil';

  @override
  String get advisorReadinessLevel => 'Nível';

  @override
  String get advisorReadinessSufficient =>
      'Base suficiente para um plano inicial.';

  @override
  String get advisorReadinessToComplete => 'A completar';

  @override
  String get advisorMiniCoachIntroTitle => 'O teu coach MINT';

  @override
  String get advisorMiniCoachIntroControl =>
      'Agora tens um plano concreto. Avancamos com 3 prioridades em 7 dias e depois ajustamos com o teu coach.';

  @override
  String get advisorMiniWelcomeTitle => 'Bem-vindo/a!';

  @override
  String get advisorMiniWelcomeBody =>
      'O teu espaço financeiro está pronto. Descobre o que o teu coach preparou.';

  @override
  String get advisorMiniCoachIntroWarmth =>
      'Vamos juntos. Todas as semanas, ajudo-te a avançar num ponto concreto.';

  @override
  String get advisorMiniCoachPriorityBaseline =>
      'Confirmar score e trajetoria inicial';

  @override
  String get advisorMiniCoachPriorityCouple =>
      'Alinhar a estrategia do agregado para evitar pontos cegos de casal';

  @override
  String get advisorMiniCoachPrioritySingleParent =>
      'Priorizar protecao do agregado e fundo de emergencia';

  @override
  String get advisorMiniCoachPriorityBudget =>
      'Estabilizar primeiro o orcamento e custos fixos';

  @override
  String get advisorMiniCoachPriorityTax =>
      'Identificar otimizacoes fiscais prioritarias';

  @override
  String get advisorMiniCoachPriorityRetirement =>
      'Reforcar a trajetoria reforma com acoes concretas';

  @override
  String get advisorMiniCoachPriorityRealEstate =>
      'Verificar sustentabilidade do projeto imobiliario';

  @override
  String get advisorMiniCoachPriorityDebtFree =>
      'Acelerar reducao da divida sem quebrar liquidez';

  @override
  String get advisorMiniCoachPriorityWealth =>
      'Construir plano robusto de acumulacao de patrimonio';

  @override
  String get advisorMiniCoachPriorityPension =>
      'Otimizar 3a/LPP e nivel de rendimento na reforma';

  @override
  String get advisorMiniQuickPickLabel => 'Escolha rapida';

  @override
  String get advisorMiniQuickPickIncomeLabel => 'Montantes frequentes';

  @override
  String get advisorMiniFixedCostsTitle => 'Custos fixos (opcional)';

  @override
  String get advisorMiniFixedCostsHint =>
      'Inclui: internet/movel, seguros casa/RC/auto, transportes, subscricoes e encargos recorrentes.';

  @override
  String get advisorMiniFixedCostsSubtitle =>
      'Adiciona impostos, LAMal e outros custos fixos para um orcamento realista desde o inicio.';

  @override
  String get advisorMiniPrefillEstimates => 'Preencher estimativas';

  @override
  String get advisorMiniPrefillHint =>
      'Estimado com base no teu cantão — ajusta se diferente.';

  @override
  String advisorMiniPrefillTaxCouple(String canton) {
    return 'Preenchido a partir do teu rendimento acima (cantão $canton, casal)';
  }

  @override
  String advisorMiniPrefillTaxSingle(String canton) {
    return 'Preenchido a partir do teu rendimento acima (cantão $canton)';
  }

  @override
  String advisorMiniPrefillLamalFamily(String adults, String children) {
    return 'LAMal estimada para $adults adulto(s) + $children criança(s)';
  }

  @override
  String advisorMiniPrefillLamalCouple(String adults) {
    return 'LAMal estimada para $adults adultos';
  }

  @override
  String get advisorMiniPrefillLamalSingle => 'LAMal estimada para 1 adulto';

  @override
  String get advisorMiniPrefillAdjust => 'Ajusta se diferente.';

  @override
  String get advisorMiniTaxProvisionLabel => 'Provisao de impostos / mes';

  @override
  String get advisorMiniLamalLabel => 'Premios LAMal / mes';

  @override
  String get advisorMiniOtherFixedLabel => 'Outros custos fixos / mes';

  @override
  String get advisorMiniStep2AhaTitle => 'O teu cantao em resumo';

  @override
  String advisorMiniStep2AhaHorizon(String years) {
    return 'Horizonte de reforma: ~$years anos';
  }

  @override
  String advisorMiniStep2AhaTaxQualitative(String canton, String pressure) {
    return 'Fiscalidade em $canton: $pressure em relacao a media suica';
  }

  @override
  String get advisorMiniStep2AhaPressureLow => 'baixa';

  @override
  String get advisorMiniStep2AhaPressureMedium => 'moderada';

  @override
  String get advisorMiniStep2AhaPressureHigh => 'elevada';

  @override
  String get advisorMiniStep2AhaPressureVeryHigh => 'muito elevada';

  @override
  String get advisorMiniStep2AhaPressureLabel => 'Pressao fiscal';

  @override
  String get advisorMiniStep2AhaQualitativeHint =>
      'Vai ser refinado com o teu rendimento no proximo passo.';

  @override
  String get advisorMiniStep2AhaDisclaimer =>
      'Ordem de grandeza educativa baseada em dados cantonais de referencia MINT.';

  @override
  String get advisorMiniProjectionDisclaimer =>
      'Ferramenta educativa — nao constitui aconselhamento financeiro (LAVS/LPP).';

  @override
  String get advisorMiniExitTitle => 'Sair agora?';

  @override
  String get advisorMiniExitBodyControl =>
      'O teu progresso esta guardado. Podes retomar mais tarde.';

  @override
  String get advisorMiniExitBodyChallenge =>
      'So mais alguns segundos e tens a tua trajetoria personalizada.';

  @override
  String get advisorMiniExitStay => 'Continuar';

  @override
  String get advisorMiniExitLeave => 'Sair';

  @override
  String get advisorMiniMetricsTitle => 'Metricas onboarding';

  @override
  String get advisorMiniMetricsSubtitle =>
      'Tracking local das variantes control/challenge';

  @override
  String get advisorMiniMetricsControl => 'Control';

  @override
  String get advisorMiniMetricsChallenge => 'Challenge';

  @override
  String get advisorMiniMetricsStarts => 'Starts';

  @override
  String get advisorMiniMetricsCompletionRate => 'Taxa de completion';

  @override
  String get advisorMiniMetricsExitStayRate =>
      'Taxa de stay apos prompt de saida';

  @override
  String get advisorMiniMetricsAhaToStep3 => 'Step2 A-ha -> Step3';

  @override
  String get advisorMiniMetricsQuickPicks => 'Quick picks';

  @override
  String get advisorMiniMetricsAvgStepTime => 'Tempo medio por step';

  @override
  String get advisorMiniMetricsReset => 'Reset metrics';

  @override
  String advisorMiniEtaLabel(String seconds) {
    return 'Tempo restante estimado: ${seconds}s';
  }

  @override
  String get advisorMiniEtaConfidenceHigh => 'Confianca alta';

  @override
  String get advisorMiniEtaConfidenceLow => 'Confianca media';

  @override
  String get advisorMiniEmploymentLabel => 'Estatuto profissional';

  @override
  String get advisorMiniHouseholdLabel => 'O teu agregado';

  @override
  String get advisorMiniHouseholdSubtitle =>
      'Ajustamos impostos e custos fixos ao teu contexto';

  @override
  String get advisorMiniReadyTitle => 'Validado';

  @override
  String get advisorMiniReadyLabel => 'O que a MINT entendeu';

  @override
  String get advisorMiniReadyStep1 =>
      'Prioridade registada. Personalizamos a tua trajetoria.';

  @override
  String get advisorMiniReadyStep2 =>
      'Base fiscal pronta. Contexto cantonal calibrado.';

  @override
  String get advisorMiniReadyStep3 =>
      'Perfil minimo pronto. Projecao indicativa disponivel.';

  @override
  String advisorMiniReadyStress(String label) {
    return 'Prioridade: $label';
  }

  @override
  String advisorMiniReadyProfile(String employment, String household) {
    return 'Perfil: $employment · $household';
  }

  @override
  String advisorMiniReadyLocation(String canton, String horizon) {
    return 'Base fiscal: $canton · $horizon';
  }

  @override
  String advisorMiniReadyIncome(String income) {
    return 'Rendimento liquido: CHF $income/mes';
  }

  @override
  String advisorMiniReadyFixed(String count) {
    return 'Custos fixos captados: $count/3';
  }

  @override
  String get advisorMiniEmploymentEmployee => 'Assalariado/a';

  @override
  String get advisorMiniEmploymentSelfEmployed => 'Independente';

  @override
  String get advisorMiniEmploymentStudent => 'Estudante / Aprendiz';

  @override
  String get advisorMiniEmploymentUnemployed => 'Sem emprego';

  @override
  String get advisorMiniSeeProjection => 'Ver a minha projecao';

  @override
  String get advisorMiniPreferFullDiagnostic =>
      'Prefiro o diagnostico completo (10 min)';

  @override
  String advisorMiniQuickInsight(String low, String high, String horizon) {
    return 'Estimativa rapida: uma poupanca regular entre CHF $low e CHF $high/mes ja pode mudar a tua trajetoria. $horizon';
  }

  @override
  String advisorMiniHorizon(String years) {
    return 'Horizonte de reforma: ~$years anos.';
  }

  @override
  String get advisorMiniStep4Title => 'O teu objetivo';

  @override
  String get advisorMiniStep4Subtitle =>
      'A MINT personaliza o teu plano segundo a tua prioridade principal';

  @override
  String get advisorMiniGoalRetirement => 'Preparar a minha reforma';

  @override
  String get advisorMiniGoalRealEstate => 'Comprar um imovel';

  @override
  String get advisorMiniGoalDebtFree => 'Reduzir as minhas dividas';

  @override
  String get advisorMiniGoalIndependence =>
      'Construir a minha independencia financeira';

  @override
  String get advisorMiniActivateDashboard => 'Ativar o meu dashboard';

  @override
  String get advisorMiniAdjustLater =>
      'Poderas ajustar tudo depois no Dashboard e Agir.';

  @override
  String advisorMiniPreviewTitle(String goal) {
    return 'Preview de trajetoria: $goal';
  }

  @override
  String advisorMiniPreviewSubtitle(String years) {
    return 'Projecao indicativa em ~$years anos';
  }

  @override
  String get advisorMiniPreviewPrudent => 'Prudente';

  @override
  String get advisorMiniPreviewBase => 'Base';

  @override
  String get advisorMiniPreviewOptimistic => 'Otimista';

  @override
  String get homeSafeModeActive => 'MODO PROTECAO ATIVADO';

  @override
  String get homeHide => 'Ocultar';

  @override
  String get homeSafeModeMessage =>
      'Detetamos sinais de tensao. O MINT aconselha-te a estabilizar o teu orcamento antes de investir.';

  @override
  String get homeSafeModeResources => 'Recursos & Ajuda gratuita';

  @override
  String get homeMentorAdvisor => 'Mentor Advisor';

  @override
  String get homeMentorDescription =>
      'Inicia a tua sessao personalizada para obter um diagnostico completo da tua situacao financeira.';

  @override
  String get homeStartSession => 'Iniciar a minha sessao';

  @override
  String get homeSimulator3a => 'Reforma 3a';

  @override
  String get homeSimulatorGrowth => 'Crescimento';

  @override
  String get homeSimulatorLeasing => 'Leasing';

  @override
  String get homeSimulatorCredit => 'Credito ao Consumo';

  @override
  String get homeReportV2Title => '🧪 NOVO: Relatorio V2 (Demo)';

  @override
  String get homeReportV2Subtitle =>
      'Score por circulo, comparador 3a, estrategia LPP';

  @override
  String get profileTitle => 'O MEU PERFIL MENTOR';

  @override
  String get profilePrecisionIndex => 'Indice de Precisao';

  @override
  String get profilePrecisionMessage =>
      'Quanto mais completo o teu perfil, mais poderoso e o teu relatorio \"Statement of Advice\".';

  @override
  String get profileFactFindTitle => 'Detalhes FactFind';

  @override
  String get profileSectionIdentity => 'Identidade & Agregado';

  @override
  String get profileSectionIncome => 'Rendimentos & Poupanca';

  @override
  String get profileSectionPension => 'Previdencia (LPP)';

  @override
  String get profileSectionProperty => 'Imoveis & Dividas';

  @override
  String get profileStatusComplete => 'Completo';

  @override
  String get profileStatusPartial => 'Parcial (Liquido)';

  @override
  String get profileStatusMissing => 'Em falta';

  @override
  String get profileReward15 => '+15% de precisao';

  @override
  String get profileReward10 => '+10% de precisao';

  @override
  String get profileSecurityTitle => 'Seguranca & Dados';

  @override
  String get profileConsentControl => 'Controlo de Partilhas';

  @override
  String get profileConsentManage => 'Gerir os meus acessos bLink';

  @override
  String get profileAccountTitle => 'Conta';

  @override
  String get profileUser => 'Utilizador';

  @override
  String get profileDeleteData => 'Eliminar os meus dados locais';

  @override
  String get rentVsCapitalTitle => 'Renda vs Capital';

  @override
  String get rentVsCapitalDescription =>
      'Compara a renda vitalicia e o levantamento de capital do teu 2º pilar';

  @override
  String get rentVsCapitalSubtitle => 'Simula o teu 2º pilar • LPP';

  @override
  String get rentVsCapitalAvoirOblig => 'Haver obrigatorio';

  @override
  String get rentVsCapitalAvoirSurob => 'Haver supra-obrigatorio';

  @override
  String get rentVsCapitalTauxConversion =>
      'Taxa de conversao supra-obrigatoria';

  @override
  String get rentVsCapitalAgeRetraite => 'Idade de reforma';

  @override
  String get rentVsCapitalCanton => 'Cantao';

  @override
  String get rentVsCapitalStatutCivil => 'Estado civil';

  @override
  String get rentVsCapitalSingle => 'Solteiro/a';

  @override
  String get rentVsCapitalMarried => 'Casado/a';

  @override
  String get rentVsCapitalRenteViagere => 'Renda vitalicia';

  @override
  String get rentVsCapitalCapitalNet => 'Capital liquido';

  @override
  String get rentVsCapitalBreakEven => 'Break-even';

  @override
  String get rentVsCapitalCapitalA85 => 'Capital aos 85 anos';

  @override
  String get rentVsCapitalJamais => 'Nunca';

  @override
  String get rentVsCapitalPrudent => 'Prudente (1%)';

  @override
  String get rentVsCapitalCentral => 'Central (3%)';

  @override
  String get rentVsCapitalOptimiste => 'Otimista (5%)';

  @override
  String get rentVsCapitalTauxConversionExpl =>
      'A taxa de conversao determina o montante da tua renda anual em funcao do teu haver de velhice. A taxa legal minima e de 6,8% para a parte obrigatoria (LPP art. 14). Para a parte supra-obrigatoria, cada caixa de pensoes fixa a sua propria taxa, geralmente entre 3% e 6%.';

  @override
  String get rentVsCapitalChoixExpl =>
      'A renda oferece um rendimento regular vitalicio, mas cessa com a morte (eventualmente com uma renda de sobrevivente reduzida). O capital oferece mais flexibilidade, mas comporta um risco de esgotamento se os rendimentos forem baixos ou a longevidade elevada.';

  @override
  String get rentVsCapitalDisclaimer =>
      'Os resultados apresentados sao estimativas a titulo indicativo. Nao constituem aconselhamento financeiro personalizado. Consulta a tua caixa de pensoes e um consultor qualificado antes de qualquer decisao.';

  @override
  String get disabilityGapTitle => 'A minha rede de segurança';

  @override
  String get disabilityGapSubtitle =>
      'O que acontece se já não puder trabalhar?';

  @override
  String get disabilityGapRevenu => 'Rendimento mensal liquido';

  @override
  String get disabilityGapCanton => 'Cantao';

  @override
  String get disabilityGapStatut => 'Estatuto profissional';

  @override
  String get disabilityGapSalarie => 'Assalariado';

  @override
  String get disabilityGapIndependant => 'Independente';

  @override
  String get disabilityGapAnciennete => 'Anos de servico';

  @override
  String get disabilityGapIjm => 'IJM coletiva via o meu empregador';

  @override
  String get disabilityGapDegre => 'Grau de invalidez';

  @override
  String get disabilityGapPhase1 => 'Fase 1 — Empregador';

  @override
  String get disabilityGapPhase2 => 'Fase 2 — IJM';

  @override
  String get disabilityGapPhase3 => 'Fase 3 — AI + LPP';

  @override
  String get disabilityGapRevenuActuel => 'Rendimento atual';

  @override
  String get disabilityGapGapMensuel => 'Lacuna mensal maxima';

  @override
  String get disabilityGapRiskCritical => 'Risco critico';

  @override
  String get disabilityGapRiskHigh => 'Risco elevado';

  @override
  String get disabilityGapRiskMedium => 'Risco moderado';

  @override
  String get disabilityGapRiskLow => 'Risco baixo';

  @override
  String get disabilityGapDisclaimer =>
      'Estes resultados são estimativas indicativas baseadas em tabelas legais. A tua cobertura real depende do teu contrato de trabalho, do teu fundo de pensões e dos teus seguros individuais. Consulta o teu empregador e um·a especialista qualificado·a.';

  @override
  String get disabilityGapIjmExpl =>
      'A IJM (indemnizacao diaria de doenca) e um seguro que cobre 80% do teu salario durante max. 720 dias em caso de doenca. O empregador nao e obrigado a subscreve-la, mas muitos fazem-no via seguro coletivo. Sem IJM, apos o periodo legal de manutencao do salario, nao recebes mais nada ate a eventual renda AI.';

  @override
  String get disabilityGapCo324aExpl =>
      'Segundo o art. 324a CO, o empregador deve pagar o salario durante um periodo limitado em caso de doenca. Esta duracao depende dos anos de servico e da escala cantonal aplicavel (bernesa, zurichesa ou basileia). Apos este periodo, so a IJM (se existir) assume.';

  @override
  String get authLogin => 'Iniciar sessao';

  @override
  String get authRegister => 'Criar conta';

  @override
  String get authEmail => 'Endereco de e-mail';

  @override
  String get authPassword => 'Palavra-passe';

  @override
  String get authConfirmPassword => 'Confirmar palavra-passe';

  @override
  String get authDisplayName => 'Nome de exibicao (opcional)';

  @override
  String get authCreateAccount => 'Criar a minha conta';

  @override
  String get authAlreadyAccount => 'Ja registado?';

  @override
  String get authNoAccount => 'Ainda nao tens conta?';

  @override
  String get authLogout => 'Terminar sessao';

  @override
  String get authLoginTitle => 'Inicio de sessao';

  @override
  String get authRegisterTitle => 'Cria a tua conta';

  @override
  String get authPasswordHint => 'Minimo 8 caracteres';

  @override
  String get authError => 'Erro de inicio de sessao';

  @override
  String get authEmailInvalid => 'Endereco de e-mail invalido';

  @override
  String get authPasswordTooShort =>
      'A palavra-passe deve ter pelo menos 8 caracteres';

  @override
  String get authPasswordMismatch => 'As palavras-passe nao correspondem';

  @override
  String get authForgotTitle => 'Repor palavra-passe';

  @override
  String get authForgotSteps =>
      '1) Pedir link  2) Colar token  3) Escolher nova palavra-passe';

  @override
  String get authForgotSendLink => 'Enviar link de reposicao';

  @override
  String get authForgotResetTokenLabel => 'Token de reposicao';

  @override
  String get authForgotNewPasswordLabel => 'Nova palavra-passe';

  @override
  String get authForgotSubmitNewPassword => 'Confirmar nova palavra-passe';

  @override
  String get authForgotRequestAccepted =>
      'Se existir conta, foi enviado um link de reposicao.';

  @override
  String get authForgotResetSuccess =>
      'Palavra-passe atualizada. Ja podes iniciar sessao.';

  @override
  String get authVerifyTitle => 'Verificar o meu email';

  @override
  String get authVerifyInstructions =>
      'Pede um novo link e cola o token de verificacao.';

  @override
  String get authVerifySendLink => 'Enviar link de verificacao';

  @override
  String get authVerifyTokenLabel => 'Token de verificacao';

  @override
  String get authVerifySubmit => 'Confirmar verificacao';

  @override
  String get authVerifyRequestAccepted =>
      'Link de verificacao enviado (se a conta existir).';

  @override
  String get authVerifySuccess => 'Email verificado. Ja podes iniciar sessao.';

  @override
  String get authTokenRequired => 'Token obrigatorio.';

  @override
  String get authEmailInvalidPrompt => 'Introduz um endereco de email valido.';

  @override
  String get authDebugTokenLabel => 'Token debug (tests)';

  @override
  String get adminObsTitle => 'Admin observability';

  @override
  String get adminObsExportCsv => 'Exportar CSV de coortes';

  @override
  String get adminObsCsvCopied =>
      'CSV de coortes copiado para a area de transferencia';

  @override
  String get adminObsExportFailed => 'Nao foi possivel exportar';

  @override
  String get adminObsWindowLabel => 'Janela';

  @override
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonDays => 'dias';

  @override
  String get analyticsConsentTitle => 'Estatisticas anonimas';

  @override
  String get analyticsConsentMessage =>
      'O MINT utiliza estatisticas anonimas para melhorar a experiencia. Nenhum dado pessoal e recolhido.';

  @override
  String get analyticsAccept => 'Aceitar';

  @override
  String get analyticsRefuse => 'Recusar';

  @override
  String get askMintTitle => 'Ask MINT';

  @override
  String get askMintSubtitle => 'Faz as tuas perguntas sobre financas suicas';

  @override
  String get askMintConfigureTitle => 'Configura a tua IA';

  @override
  String get askMintConfigureBody =>
      'Para fazer perguntas sobre finanças suíças, liga a tua própria chave API (Claude, OpenAI ou Mistral). A tua chave é encriptada localmente e nunca armazenada nos nossos servidores.';

  @override
  String get askMintConfigureButton => 'Configurar a minha chave API';

  @override
  String get askMintEmptyTitle => 'Faz-me uma pergunta';

  @override
  String get askMintEmptySubtitle =>
      'Posso ajudar-te com financas suicas: 3º pilar, LPP, impostos, orcamento...';

  @override
  String get askMintSuggestedTitle => 'SUGESTOES';

  @override
  String get askMintSuggestion1 =>
      'Comment fonctionne le 3e pilier en Suisse ?';

  @override
  String get askMintSuggestion2 =>
      'Dois-je choisir la rente ou le capital LPP ?';

  @override
  String get askMintSuggestion3 => 'Como posso otimizar os meus impostos?';

  @override
  String get askMintSuggestion4 => 'O que e o resgate LPP?';

  @override
  String get askMintInputHint => 'Faz a tua pergunta sobre financas suicas...';

  @override
  String get askMintSourcesTitle => 'Fontes';

  @override
  String get askMintErrorInvalidKey =>
      'A tua chave API parece invalida ou expirada. Verifica-a nas definicoes.';

  @override
  String get askMintErrorRateLimit =>
      'Limite de pedidos atingido. Aguarda um momento antes de tentares novamente.';

  @override
  String get askMintErrorGeneric =>
      'Ocorreu um erro. Verifica a tua ligacao e tenta novamente.';

  @override
  String get askMintDisclaimer =>
      'As respostas sao geradas por IA e nao constituem aconselhamento financeiro personalizado.';

  @override
  String get byokTitle => 'Inteligencia Artificial';

  @override
  String get byokSubtitle =>
      'Liga o teu proprio LLM para respostas personalizadas';

  @override
  String get byokProviderLabel => 'Fornecedor';

  @override
  String get byokApiKeyLabel => 'Chave API';

  @override
  String get byokTestButton => 'Testar a chave';

  @override
  String get byokTesting => 'Teste em curso...';

  @override
  String get byokSaveButton => 'Guardar';

  @override
  String get byokSaved => 'Chave guardada com sucesso';

  @override
  String get byokTestSuccess => 'Ligacao bem sucedida! A tua IA esta pronta.';

  @override
  String get byokPrivacyTitle => 'A tua chave, os teus dados';

  @override
  String get byokPrivacyBody =>
      'A tua chave API é armazenada de forma encriptada no teu dispositivo. É transmitida de forma segura (HTTPS) ao nosso servidor para comunicar com o fornecedor de IA, e imediatamente eliminada — nunca armazenada no servidor.';

  @override
  String get byokPrivacyShort =>
      'Chave encriptada localmente, nunca armazenada nos nossos servidores';

  @override
  String get byokClearButton => 'Eliminar a chave guardada';

  @override
  String get byokClearTitle => 'Eliminar a chave?';

  @override
  String get byokClearMessage =>
      'Isto eliminara a tua chave API armazenada localmente. Podes configurar uma nova a qualquer momento.';

  @override
  String get byokClearCancel => 'Cancelar';

  @override
  String get byokClearConfirm => 'Eliminar';

  @override
  String get byokLearnTitle => 'Sobre o BYOK';

  @override
  String get byokLearnHeading => 'O que e o BYOK (Bring Your Own Key)?';

  @override
  String get byokLearnBody =>
      'O BYOK permite-te usar a tua propria chave API de um fornecedor de IA (Claude, OpenAI, Mistral) para obter respostas personalizadas sobre financas suicas.\n\nVantagens:\n• Controlo total sobre os teus dados\n• Sem custos ocultos do MINT\n• So pagas o que consomes\n• Chave encriptada no teu dispositivo';

  @override
  String get profileAiTitle => 'Inteligencia Artificial';

  @override
  String get profileAiByok => 'Ask MINT (BYOK)';

  @override
  String get profileAiConfigured => 'Configurado';

  @override
  String get profileAiNotConfigured => 'Nao configurado';

  @override
  String get documentsTitle => 'Os meus documentos';

  @override
  String get documentsSubtitle =>
      'Upload e analise dos teus documentos financeiros';

  @override
  String get documentsUploadTitle => 'Carrega o teu certificado LPP';

  @override
  String get documentsUploadBody =>
      'O MINT extrai automaticamente os teus dados de previdencia profissional';

  @override
  String get documentsUploadButton => 'Escolher um ficheiro PDF';

  @override
  String get documentsAnalyzing => 'Analise em curso...';

  @override
  String documentsConfidence(String confidence) {
    return 'Confianca: $confidence%';
  }

  @override
  String documentsFieldsFound(String found, String total) {
    return '$found campos extraidos de $total';
  }

  @override
  String get documentsConfirmButton => 'Confirmar e atualizar o meu perfil';

  @override
  String get documentsDeleteButton => 'Eliminar este documento';

  @override
  String get documentsDeleteTitle => 'Eliminar o documento?';

  @override
  String get documentsDeleteMessage => 'Esta acao e irreversivel.';

  @override
  String get documentsPrivacy =>
      'Os teus documentos sao analisados localmente e nunca sao partilhados com terceiros. Podes elimina-los a qualquer momento.';

  @override
  String get documentsEmpty => 'Nenhum documento';

  @override
  String get documentsLppCertificate => 'Certificado LPP';

  @override
  String get documentsUnknown => 'Documento desconhecido';

  @override
  String get documentsCategoryEpargne => 'Poupanca';

  @override
  String get documentsCategorySalaire => 'Salario';

  @override
  String get documentsCategoryTaux => 'Taxa de conversao';

  @override
  String get documentsCategoryRisque => 'Cobertura de risco';

  @override
  String get documentsCategoryRachat => 'Resgate';

  @override
  String get documentsCategoryCotisations => 'Contribuicoes';

  @override
  String get documentsFieldAvoirObligatoire => 'Haver de velhice obrigatorio';

  @override
  String get documentsFieldAvoirSurobligatoire =>
      'Haver de velhice supra-obrigatorio';

  @override
  String get documentsFieldAvoirTotal => 'Haver de velhice total';

  @override
  String get documentsFieldSalaireAssure => 'Salario segurado';

  @override
  String get documentsFieldSalaireAvs => 'Salario AVS';

  @override
  String get documentsFieldDeductionCoordination => 'Deducao de coordenacao';

  @override
  String get documentsFieldTauxObligatoire => 'Taxa de conversao obrigatoria';

  @override
  String get documentsFieldTauxSurobligatoire =>
      'Taxa de conversao supra-obrigatoria';

  @override
  String get documentsFieldTauxEnveloppe => 'Taxa de conversao envolvente';

  @override
  String get documentsFieldRenteInvalidite => 'Renda anual de invalidez';

  @override
  String get documentsFieldCapitalDeces => 'Capital de falecimento';

  @override
  String get documentsFieldRenteConjoint => 'Renda anual do conjuge';

  @override
  String get documentsFieldRenteEnfant => 'Renda anual por filho';

  @override
  String get documentsFieldRachatMax => 'Resgate maximo possivel';

  @override
  String get documentsFieldCotisationEmploye =>
      'Contribuicao anual do empregado';

  @override
  String get documentsFieldCotisationEmployeur =>
      'Contribuicao anual do empregador';

  @override
  String get documentsWarningsTitle => 'Pontos de atencao';

  @override
  String get profileDocuments => 'Os meus documentos';

  @override
  String profileDocumentsCount(String count) {
    return '$count documento(s)';
  }

  @override
  String get bankImportTitle => 'Importar os meus extratos';

  @override
  String get bankImportSubtitle => 'Analise automatica das tuas transacoes';

  @override
  String get bankImportUploadTitle => 'Importa o teu extrato bancario';

  @override
  String get bankImportUploadBody =>
      'CSV ou PDF — UBS, PostFinance, Raiffeisen, ZKB e outros bancos suicos';

  @override
  String get bankImportUploadButton => 'Escolher um ficheiro';

  @override
  String get bankImportAnalyzing => 'Analise das transacoes...';

  @override
  String bankImportBankDetected(String bank) {
    return '$bank detetado';
  }

  @override
  String bankImportPeriod(String start, String end) {
    return 'Periodo: $start - $end';
  }

  @override
  String bankImportTransactionCount(String count) {
    return '$count transacoes';
  }

  @override
  String get bankImportIncome => 'Rendimentos';

  @override
  String get bankImportExpenses => 'Despesas';

  @override
  String get bankImportCategories => 'Reparticao por categoria';

  @override
  String get bankImportRecurring => 'Encargos recorrentes detetados';

  @override
  String bankImportPerMonth(String amount) {
    return '$amount/mes';
  }

  @override
  String get bankImportBudgetPreview => 'O teu orcamento estimado';

  @override
  String get bankImportMonthlyIncome => 'Rendimento mensal';

  @override
  String get bankImportFixedCharges => 'Encargos fixos';

  @override
  String get bankImportVariable => 'Despesas variaveis';

  @override
  String get bankImportSavingsRate => 'Taxa de poupanca';

  @override
  String get bankImportButton => 'Importar para o meu orcamento';

  @override
  String get bankImportPrivacy =>
      'Os teus extratos sao analisados localmente. As transacoes nunca sao armazenadas nos nossos servidores.';

  @override
  String get bankImportSuccess => 'Orcamento atualizado com sucesso';

  @override
  String get bankImportCategoryLogement => 'Alojamento';

  @override
  String get bankImportCategoryAlimentation => 'Alimentacao';

  @override
  String get bankImportCategoryTransport => 'Transporte';

  @override
  String get bankImportCategoryAssurance => 'Seguro';

  @override
  String get bankImportCategoryTelecom => 'Telecom';

  @override
  String get bankImportCategoryImpots => 'Impostos';

  @override
  String get bankImportCategorySante => 'Saude';

  @override
  String get bankImportCategoryLoisirs => 'Lazer';

  @override
  String get bankImportCategoryEpargne => 'Poupanca';

  @override
  String get bankImportCategorySalaire => 'Salario';

  @override
  String get bankImportCategoryRestaurant => 'Restaurante';

  @override
  String get bankImportCategoryDivers => 'Diversos';

  @override
  String get jobCompareTitle => 'Comparar dois empregos';

  @override
  String get jobCompareSubtitle => 'Descobre o salário invisível';

  @override
  String get jobCompareIntro =>
      'O salário bruto não diz tudo. Compara o salário invisível (previdência, seguros) entre dois postos.';

  @override
  String get jobCompareCurrentJob => 'EMPREGO ATUAL';

  @override
  String get jobCompareNewJob => 'EMPREGO PREVISTO';

  @override
  String get jobCompareSalaireBrut => 'Salario bruto anual';

  @override
  String get jobCompareAge => 'A tua idade';

  @override
  String get jobComparePartEmployeur => 'Parte empregador LPP';

  @override
  String get jobCompareTauxConversion => 'Taxa de conversao';

  @override
  String get jobCompareAvoirVieillesse => 'Haver de velhice atual';

  @override
  String get jobCompareCouvertureInvalidite => 'Cobertura de invalidez';

  @override
  String get jobCompareCapitalDeces => 'Capital de falecimento';

  @override
  String get jobCompareRachatMax => 'Resgate maximo';

  @override
  String get jobCompareIjm => 'IJM coletiva incluída';

  @override
  String get jobCompareButton => 'Comparar';

  @override
  String get jobCompareResults => 'Resultados';

  @override
  String get jobCompareAxis => 'Eixo';

  @override
  String get jobCompareActuel => 'Atual';

  @override
  String get jobCompareNouveau => 'Novo';

  @override
  String get jobCompareDelta => 'Diferenca';

  @override
  String get jobCompareSalaireNet => 'Salario liquido';

  @override
  String get jobCompareCotisLpp => 'Contribuicoes LPP';

  @override
  String get jobCompareCapitalRetraite => 'Capital de reforma';

  @override
  String get jobCompareRenteMois => 'Renda/mes';

  @override
  String get jobCompareCouvertureDeces => 'Cobertura de falecimento';

  @override
  String get jobCompareInvalidite => 'Cobertura de invalidez';

  @override
  String get jobCompareRachat => 'Resgate max';

  @override
  String get jobCompareLifetimeImpact => 'Impacto em toda a reforma';

  @override
  String get jobCompareAlerts => 'Pontos de atencao';

  @override
  String get jobCompareChecklist => 'Antes de assinar';

  @override
  String get jobCompareChecklistReglement =>
      'Pedir o regulamento da caixa de pensoes';

  @override
  String get jobCompareChecklistTaux =>
      'Verificar a taxa de conversao supra-obrigatoria';

  @override
  String get jobCompareChecklistPart => 'Comparar a parte do empregador';

  @override
  String get jobCompareChecklistCoordination =>
      'Verificar a deducao de coordenacao';

  @override
  String get jobCompareChecklistIjm =>
      'Perguntar se a IJM coletiva esta incluida';

  @override
  String get jobCompareChecklistRachat =>
      'Verificar o prazo de espera para resgate';

  @override
  String get jobCompareChecklistRisque =>
      'Calcular o impacto nas prestacoes de risco';

  @override
  String get jobCompareChecklistLibrePassage =>
      'Verificar a livre passagem: transferencia em 30 dias max';

  @override
  String get jobCompareEducational =>
      'O salario invisivel representa 10-30% da tua remuneracao total.';

  @override
  String get jobCompareVerdictBetter => 'O novo posto e globalmente melhor';

  @override
  String get jobCompareVerdictWorse => 'O posto atual oferece melhor protecao';

  @override
  String get jobCompareVerdictComparable => 'Os dois postos sao comparaveis';

  @override
  String get jobCompareDetailedComparison => 'Comparacao detalhada';

  @override
  String get jobCompareDetailedSubtitle => '7 eixos de previdência';

  @override
  String get jobCompareReduce => 'Reduzir';

  @override
  String get jobCompareShowDetails => 'Ver detalhes';

  @override
  String get jobCompareChecklistSubtitle => 'Lista de verificação';

  @override
  String get jobCompareLifetimeTitle => 'Impacto em toda a reforma';

  @override
  String get jobCompareDisclaimer =>
      'Os resultados apresentados são estimativas indicativas. Não constituem aconselhamento financeiro personalizado. Consulta o teu fundo de pensões e um·a especialista qualificado·a antes de qualquer decisão.';

  @override
  String get divorceTitle => 'Impacto financeiro de um divorcio';

  @override
  String get divorceSubtitle => 'Antecipar as consequencias financeiras';

  @override
  String get divorceIntro =>
      'Um divorcio tem consequencias financeiras frequentemente subestimadas: divisao do patrimonio, da previdencia (LPP/3a), impacto fiscal e pensao de alimentos.';

  @override
  String get divorceSituationFamiliale => 'SITUAÇÃO FAMILIAR';

  @override
  String get divorceSituationSubtitle => 'Duração do casamento, filhos, regime';

  @override
  String get divorceDureeMariage => 'Duração do casamento';

  @override
  String get divorceNombreEnfants => 'Numero de filhos';

  @override
  String get divorceRegimeMatrimonial => 'Regime matrimonial';

  @override
  String get divorceRegimeAcquets =>
      'Participacao nos adquiridos (por defeito)';

  @override
  String get divorceRegimeCommunaute => 'Comunhao de bens';

  @override
  String get divorceRegimeSeparation => 'Separacao de bens';

  @override
  String get divorceRevenus => 'RENDIMENTOS';

  @override
  String get divorceRevenusSubtitle => 'Rendimento anual de cada cônjuge';

  @override
  String get divorceConjoint1Revenu => 'Cônjuge 1 — rendimento anual';

  @override
  String get divorceConjoint2Revenu => 'Cônjuge 2 — rendimento anual';

  @override
  String get divorcePrevoyance => 'PREVIDÊNCIA';

  @override
  String get divorcePrevoyanceSubtitle =>
      'LPP e 3a acumulados durante o casamento';

  @override
  String get divorceLppConjoint1 => 'LPP Cônjuge 1 (durante o casamento)';

  @override
  String get divorceLppConjoint2 => 'LPP Cônjuge 2 (durante o casamento)';

  @override
  String get divorce3aConjoint1 => '3a Cônjuge 1';

  @override
  String get divorce3aConjoint2 => '3a Cônjuge 2';

  @override
  String get divorcePatrimoine => 'PATRIMÓNIO';

  @override
  String get divorcePatrimoineSubtitle => 'Fortuna e dívidas comuns';

  @override
  String get divorceFortuneCommune => 'Patrimonio comum';

  @override
  String get divorceDettesCommunes => 'Dividas comuns';

  @override
  String get divorceSimuler => 'Simular';

  @override
  String get divorcePartageLpp => 'PARTILHA LPP';

  @override
  String get divorceTotalLpp => 'Total LPP (durante o casamento)';

  @override
  String get divorcePartConjoint1 => 'Parte Cônjuge 1';

  @override
  String get divorcePartConjoint2 => 'Parte Cônjuge 2';

  @override
  String get divorceTransfert => 'Transferencia';

  @override
  String get divorceImpactFiscal => 'IMPACTO FISCAL';

  @override
  String get divorceImpotMarie => 'Imposto estimado (casado)';

  @override
  String get divorceImpotConjoint1 => 'Imposto Cônjuge 1 (individual)';

  @override
  String get divorceImpotConjoint2 => 'Imposto Cônjuge 2 (individual)';

  @override
  String get divorceTotalApresDivorce => 'Total após divórcio';

  @override
  String get divorceDifference => 'Diferenca';

  @override
  String get divorcePartagePatrimoine => 'PARTILHA DO PATRIMÓNIO';

  @override
  String get divorceFortuneNette => 'Fortuna líquida';

  @override
  String get divorcePensionAlimentaire => 'PENSÃO ALIMENTAR (ESTIMAÇÃO)';

  @override
  String get divorcePensionAlimentaireNote =>
      'Estimativa baseada na diferenca de rendimentos e no numero de filhos.';

  @override
  String get divorcePointsAttention => 'PONTOS DE ATENÇÃO';

  @override
  String get divorceActions => 'Acoes a empreender';

  @override
  String get divorceActionsSubtitle => 'Checklist de preparação';

  @override
  String get divorceEduAcquets => 'O que e a participacao nos adquiridos?';

  @override
  String get divorceEduAcquetsBody =>
      'A participacao nos adquiridos e o regime matrimonial por defeito na Suica (CC art. 181 ss). Os adquiridos sao divididos em partes iguais em caso de divorcio.';

  @override
  String get divorceEduLpp => 'Como funciona a divisao LPP?';

  @override
  String get divorceEduLppBody =>
      'Os haveres LPP acumulados durante o casamento sao divididos em partes iguais (CC art. 122).';

  @override
  String get divorceDisclaimer =>
      'Os resultados apresentados são estimativas indicativas e não constituem aconselhamento jurídico ou financeiro personalizado. Cada situação é única. Consulte um(a) advogado(a) especializado(a) em direito de família e um·a especialista em finanças antes de qualquer decisão.';

  @override
  String get successionTitle => 'Sucessão e transmissão';

  @override
  String get successionSubtitle => 'Novo direito sucessorio 2023';

  @override
  String get successionIntro =>
      'O novo direito sucessorio (2023) alargou a quota disponivel. Tens agora mais liberdade para favorecer certos herdeiros.';

  @override
  String get successionSituationPersonnelle => 'Situacao pessoal';

  @override
  String get successionSituationSubtitle => 'Estado civil, herdeiros';

  @override
  String get successionStatutCivil => 'Estado civil';

  @override
  String get successionCivilMarie => 'Casado/a';

  @override
  String get successionCivilCelibataire => 'Solteiro/a';

  @override
  String get successionCivilDivorce => 'Divorciado/a';

  @override
  String get successionCivilVeuf => 'Viuvo/a';

  @override
  String get successionCivilConcubinage => 'Uniao de facto';

  @override
  String get successionNombreEnfants => 'Numero de filhos';

  @override
  String get successionParentsVivants => 'Pais vivos';

  @override
  String get successionFratrie => 'Irmaos/Irmas';

  @override
  String get successionConcubin => 'Companheiro/a';

  @override
  String get successionFortune => 'Patrimonio';

  @override
  String get successionFortuneSubtitle => 'Patrimonio total, 3a, LPP';

  @override
  String get successionFortuneTotale => 'Patrimonio total';

  @override
  String get successionAvoirs3a => 'Haveres 3º pilar';

  @override
  String get successionCapitalDecesLpp => 'Capital de falecimento LPP';

  @override
  String get successionCanton => 'Cantao';

  @override
  String get successionTestament => 'Testamento';

  @override
  String get successionTestamentSubtitle => 'CC art. 498–504';

  @override
  String get successionHasTestament => 'Tenho um testamento';

  @override
  String get successionQuotiteBeneficiaire => 'Quem recebe a quota disponivel?';

  @override
  String get successionBeneficiaireConjoint => 'Conjuge';

  @override
  String get successionBeneficiaireEnfants => 'Filhos';

  @override
  String get successionBeneficiaireConcubin => 'Companheiro/a';

  @override
  String get successionBeneficiaireTiers => 'Terceiros / Obra';

  @override
  String get successionSimuler => 'Simular';

  @override
  String get successionRepartitionLegale => 'Reparticao legal';

  @override
  String get successionRepartitionTestament => 'Reparticao com testamento';

  @override
  String get successionReservesHereditaires => 'Reservas hereditarias (2023)';

  @override
  String get successionReservesNote =>
      'Montantes protegidos por lei (intocaveis)';

  @override
  String get successionQuotiteDisponible => 'Quota disponivel';

  @override
  String get successionQuotiteNote =>
      'Este montante pode ser livremente atribuido por testamento.';

  @override
  String get successionFiscalite => 'Fiscalidade sucessoria';

  @override
  String get successionExonere => 'Isento';

  @override
  String get successionTotalImpot => 'Total imposto sucessorio';

  @override
  String get succession3aOpp3 => 'Beneficiarios 3a (OPP3 art. 2)';

  @override
  String get succession3aNote =>
      'O 3º pilar NAO segue o teu testamento. A ordem de beneficiarios e fixada por lei.';

  @override
  String get successionPointsAttention => 'Pontos de atencao';

  @override
  String get successionChecklist => 'Protecao dos meus entes queridos';

  @override
  String get successionChecklistSubtitle => 'Ações a empreender';

  @override
  String get successionEduQuotite => 'O que e a quota disponivel?';

  @override
  String get successionEduQuotiteBody =>
      'A quota disponivel e a parte da tua sucessao que podes livremente atribuir por testamento. Desde 2023, a reserva dos descendentes e de 1/2.';

  @override
  String get successionEdu3a => 'O 3a e a sucessao: atencao!';

  @override
  String get successionEdu3aBody =>
      'O 3º pilar e pago diretamente segundo a OPP3, nao segundo o teu testamento.';

  @override
  String get successionEduConcubin => 'Companheiros e a sucessao';

  @override
  String get successionEduConcubinBody =>
      'Os companheiros nao tem direitos sucessorios legais. Sem testamento, nao recebem nada.';

  @override
  String get successionDisclaimer =>
      'Informação educativa, não aconselhamento jurídico (LSFin/CC).';

  @override
  String get lifeEventsSection => 'Eventos de vida';

  @override
  String get lifeEventDivorce => 'Divorcio';

  @override
  String get lifeEventSuccession => 'Sucessao';

  @override
  String get coachingTitle => 'Coaching proativo';

  @override
  String get coachingSubtitle => 'As tuas sugestoes personalizadas';

  @override
  String get coachingIntro =>
      'Sugestoes personalizadas baseadas no teu perfil. Quanto mais completo o perfil, mais pertinentes os conselhos.';

  @override
  String get coachingFilterAll => 'Todos';

  @override
  String get coachingFilterHigh => 'Alta prioridade';

  @override
  String get coachingFilterFiscal => 'Fiscalidade';

  @override
  String get coachingFilterPrevoyance => 'Previdencia';

  @override
  String get coachingFilterBudget => 'Orcamento';

  @override
  String get coachingFilterRetraite => 'Reforma';

  @override
  String get coachingNoTips => 'O teu perfil está completo. Nada a assinalar.';

  @override
  String coachingImpact(String amount) {
    return 'Impacto estimado: $amount';
  }

  @override
  String get coachingSource => 'Fonte';

  @override
  String coachingTipCount(String count) {
    return '$count conselhos';
  }

  @override
  String get coachingPriorityHigh => 'Alta prioridade';

  @override
  String get coachingPriorityMedium => 'Prioridade media';

  @override
  String get coachingPriorityLow => 'Informacao';

  @override
  String get coaching3aDeadlineTitle =>
      'Contribuicao 3a antes de 31 de dezembro';

  @override
  String coaching3aDeadlineMessage(
      String remaining, String plafond, String impact) {
    return 'Resta-te $remaining de margem no teu teto 3a ($plafond). Uma contribuicao antes de 31 de dezembro poderia reduzir a tua carga fiscal em cerca de $impact.';
  }

  @override
  String get coaching3aDeadlineAction => 'Simular o meu 3a';

  @override
  String get coaching3aMissingTitle => 'Nao tens 3º pilar';

  @override
  String coaching3aMissingMessage(
      String plafond, String impact, String canton) {
    return 'Abrir um 3º pilar permitiria deduzir ate $plafond do teu rendimento tributavel por ano. A poupanca fiscal estimada e de $impact por ano no cantao de $canton.';
  }

  @override
  String get coaching3aMissingAction => 'Descobrir o 3º pilar';

  @override
  String get coaching3aNotMaxedTitle => 'Teto 3a nao atingido';

  @override
  String coaching3aNotMaxedMessage(
      String current, String plafond, String remaining, String impact) {
    return 'A tua contribuicao 3a atual e de $current num teto de $plafond. Contribuir com o restante $remaining poderia representar uma poupanca fiscal de cerca de $impact.';
  }

  @override
  String get coaching3aNotMaxedAction => 'Simular o meu 3a';

  @override
  String get coachingLppBuybackTitle => 'Resgate LPP possivel';

  @override
  String coachingLppBuybackMessage(String gap, String impact) {
    return 'Tens uma lacuna de previdencia de $gap. Um resgate voluntario poderia poupar-te cerca de $impact de impostos melhorando a tua reforma.';
  }

  @override
  String get coachingLppBuybackAction => 'Simular um resgate LPP';

  @override
  String get coachingTaxDeadlineTitle => 'Declaracao de impostos a entregar';

  @override
  String coachingTaxDeadlineMessage(String canton, String days) {
    return 'O prazo para a tua declaracao fiscal no cantao de $canton e 31 de marco. Restam $days dias.';
  }

  @override
  String get coachingTaxDeadlineAction => 'Ver a minha checklist fiscal';

  @override
  String coachingRetirementTitle(String years) {
    return 'Reforma em $years anos';
  }

  @override
  String coachingRetirementMessage(String years) {
    return 'A $years anos da reforma, e importante verificar a tua estrategia de previdencia. Otimizaste os teus resgates LPP? As tuas contas 3a sao diversificadas?';
  }

  @override
  String get coachingRetirementAction => 'Planear a minha reforma';

  @override
  String get coachingEmergencyTitle => 'Reserva de emergencia insuficiente';

  @override
  String coachingEmergencyMessage(String months, String deficit) {
    return 'A tua poupanca disponivel cobre $months meses de encargos fixos. Os especialistas recomendam pelo menos 3 meses. Faltam-te cerca de $deficit.';
  }

  @override
  String get coachingEmergencyAction => 'Ver o meu orcamento';

  @override
  String coachingDebtTitle(String ratio) {
    return 'Taxa de endividamento elevada ($ratio%)';
  }

  @override
  String coachingDebtMessage(String ratio) {
    return 'A tua taxa de endividamento estimada e de $ratio%, acima do limiar de 33% recomendado pelos bancos suicos.';
  }

  @override
  String get coachingDebtAction => 'Analisar as minhas dividas';

  @override
  String get coachingPartTimeTitle => 'Tempo parcial: lacuna de previdencia';

  @override
  String coachingPartTimeMessage(String rate) {
    return 'A $rate% de atividade, a tua previdencia profissional esta reduzida. A deducao de coordenacao penaliza ainda mais os trabalhadores a tempo parcial.';
  }

  @override
  String get coachingPartTimeAction => 'Simular a minha previdencia';

  @override
  String get coachingIndependantTitle => 'Independente: sem LPP obrigatoria';

  @override
  String get coachingIndependantMessage =>
      'Como independente, nao estas sujeito a LPP obrigatoria. A tua previdencia baseia-se no AVS e no 3º pilar. Maximiza as tuas contribuicoes 3a.';

  @override
  String get coachingIndependantAction => 'Explorar as minhas opcoes';

  @override
  String get coachingBudgetMissingTitle => 'Ainda sem orcamento';

  @override
  String get coachingBudgetMissingMessage =>
      'Um orcamento estruturado e a base de qualquer estrategia financeira. Permite identificar a tua capacidade real de poupanca.';

  @override
  String get coachingBudgetMissingAction => 'Criar o meu orcamento';

  @override
  String get coachingAge25Title => '25 anos: abrir o 3º pilar';

  @override
  String get coachingAge25Message =>
      'Aos 25 anos e o momento ideal para abrir um 3º pilar. Gracas aos juros compostos, cada ano conta.';

  @override
  String get coachingAge35Title => '35 anos: ponto de situacao de previdencia';

  @override
  String get coachingAge35Message =>
      'Aos 35 anos, verifica que a tua previdencia esta no bom caminho. Tens um 3a? A tua LPP e suficiente?';

  @override
  String get coachingAge45Title => '45 anos: otimizar a estrategia';

  @override
  String get coachingAge45Message =>
      'Aos 45 anos, faltam 20 anos para a reforma. E o momento de otimizar: maximizar o 3a, considerar resgates LPP.';

  @override
  String get coachingAge50Title => '50 anos: preparar a reforma';

  @override
  String get coachingAge50Message =>
      'Aos 50 anos, a reforma aproxima-se. Verifica o teu haver LPP e planeia os ultimos resgates.';

  @override
  String get coachingAge55Title => '55 anos: ultima reta';

  @override
  String get coachingAge55Message =>
      'Aos 55 anos, o planeamento fiscal do levantamento torna-se crucial. Escalonar os levantamentos 3a pode representar uma poupanca significativa.';

  @override
  String get coachingAge58Title => '58 anos: reforma antecipada possivel';

  @override
  String get coachingAge58Message =>
      'A partir dos 58 anos, um levantamento antecipado do 2º pilar e possivel. Atencao: a renda sera reduzida.';

  @override
  String get coachingAge63Title => '63 anos: ultimos ajustes';

  @override
  String get coachingAge63Message =>
      'A 2 anos da reforma legal: finalizar a estrategia. Ultimo resgate LPP, escolha renda/capital.';

  @override
  String get coachingDisclaimer =>
      'As sugestoes apresentadas sao pistas de reflexao baseadas em estimativas simplificadas. Nao constituem aconselhamento financeiro personalizado. Consulta um profissional qualificado antes de qualquer decisao.';

  @override
  String get coachingDemoMode =>
      'Modo demo: perfil exemplo (35 anos, VD, CHF 85\'000). Completa o teu diagnostico para conselhos personalizados.';

  @override
  String get coachingNowCardTitle => 'Coaching proativo';

  @override
  String get coachingNowCardSubtitle =>
      'Conselhos personalizados baseados no teu perfil';

  @override
  String get coachingCategoryFiscalite => 'Fiscalidade';

  @override
  String get coachingCategoryPrevoyance => 'Previdencia';

  @override
  String get coachingCategoryBudget => 'Orcamento';

  @override
  String get coachingCategoryRetraite => 'Reforma';

  @override
  String get segmentsSection => 'Segmentos';

  @override
  String get segmentsGenderGapTitle => 'Gender gap previdencia';

  @override
  String get segmentsGenderGapSubtitle => 'Impacto do tempo parcial na reforma';

  @override
  String get segmentsGenderGapAppBar => 'GENDER GAP PREVIDENCIA';

  @override
  String get segmentsGenderGapHeader => 'Lacuna de previdencia';

  @override
  String get segmentsGenderGapHeaderSub =>
      'Impacto do tempo parcial na reforma';

  @override
  String get segmentsGenderGapIntro =>
      'A deducao de coordenacao (CHF 25\'725) nao e proporcional ao tempo parcial, o que penaliza ainda mais as pessoas que trabalham a tempo reduzido. Desloca o cursor para ver o impacto.';

  @override
  String get segmentsGenderGapTauxLabel => 'Taxa de atividade';

  @override
  String get segmentsGenderGapParams => 'Parametros';

  @override
  String get segmentsGenderGapRevenuLabel => 'Rendimento anual bruto (100%)';

  @override
  String get segmentsGenderGapAgeLabel => 'Idade';

  @override
  String get segmentsGenderGapAvoirLabel => 'Haver LPP atual';

  @override
  String get segmentsGenderGapAnneesCotisLabel => 'Anos de contribuicao';

  @override
  String get segmentsGenderGapCantonLabel => 'Cantao';

  @override
  String get segmentsGenderGapRenteTitle => 'Renda LPP estimada';

  @override
  String segmentsGenderGapRenteSub(String years) {
    return 'Projecao a $years anos (idade 65)';
  }

  @override
  String get segmentsGenderGapAt100 => 'A 100%';

  @override
  String segmentsGenderGapAtCurrent(String rate) {
    return 'A $rate%';
  }

  @override
  String get segmentsGenderGapLacuneAnnuelle => 'Lacuna anual';

  @override
  String get segmentsGenderGapLacuneTotale => 'Lacuna total (~20 anos)';

  @override
  String get segmentsGenderGapCoordinationTitle =>
      'Compreender a deducao de coordenacao';

  @override
  String get segmentsGenderGapCoordinationBody =>
      'A deducao de coordenacao e um montante fixo de CHF 25\'725 subtraido do teu salario bruto para calcular o salario coordenado (base LPP). Este montante e o mesmo quer trabalhes a 100% ou a 50%.';

  @override
  String get segmentsGenderGapSalaireBrut100 => 'Salario bruto a 100%';

  @override
  String get segmentsGenderGapSalaireCoord100 => 'Salario coordenado a 100%';

  @override
  String segmentsGenderGapSalaireBrutCurrent(String rate) {
    return 'Salario bruto a $rate%';
  }

  @override
  String segmentsGenderGapSalaireCoordCurrent(String rate) {
    return 'Salario coordenado a $rate%';
  }

  @override
  String get segmentsGenderGapDeductionFixe => 'Deducao de coordenacao (fixa)';

  @override
  String get segmentsGenderGapOfsTitle => 'Estatistica OFS';

  @override
  String get segmentsGenderGapOfsStat =>
      'Na Suica, as mulheres recebem em media 37% menos de renda que os homens (OFS 2024)';

  @override
  String get segmentsGenderGapRecTitle => 'RECOMENDACOES';

  @override
  String get segmentsGenderGapRecRachat => 'Resgate LPP voluntario';

  @override
  String get segmentsGenderGapRecRachatDesc =>
      'Um resgate voluntario permite colmatar parcialmente a lacuna de previdencia beneficiando de uma deducao fiscal.';

  @override
  String get segmentsGenderGapRec3a => '3º pilar maximizado';

  @override
  String get segmentsGenderGapRec3aDesc =>
      'Contribui com o teto anual de CHF 7\'258 (assalariados) para compensar parcialmente a lacuna LPP.';

  @override
  String get segmentsGenderGapRecCoord =>
      'Verificar a proporcionalidade da coordenacao';

  @override
  String get segmentsGenderGapRecCoordDesc =>
      'Algumas caixas de pensoes proporcionam a deducao de coordenacao em funcao da taxa de atividade.';

  @override
  String get segmentsGenderGapRecTaux =>
      'Explorar um aumento da taxa de atividade';

  @override
  String get segmentsGenderGapRecTauxDesc =>
      'Mesmo um aumento de 10 a 20 pontos pode reduzir significativamente a lacuna.';

  @override
  String get segmentsGenderGapDisclaimer =>
      'Os resultados apresentados sao estimativas simplificadas a titulo indicativo. Nao constituem aconselhamento financeiro personalizado. Consulta a tua caixa de pensoes e um profissional qualificado.';

  @override
  String get segmentsGenderGapSources => 'Fontes';

  @override
  String get segmentsFrontalierTitle => 'Frontaleiro';

  @override
  String get segmentsFrontalierSubtitle => 'Direitos e obrigacoes por pais';

  @override
  String get segmentsFrontalierAppBar => 'PERCURSO FRONTALEIRO';

  @override
  String get segmentsFrontalierHeader => 'Trabalhador frontaleiro';

  @override
  String get segmentsFrontalierHeaderSub => 'Direitos e obrigacoes por pais';

  @override
  String get segmentsFrontalierIntro =>
      'As regras fiscais, de previdencia e de seguro variam segundo o teu pais de residencia e o teu cantao de trabalho.';

  @override
  String get segmentsFrontalierPaysLabel => 'Pais de residencia';

  @override
  String get segmentsFrontalierCantonLabel => 'Cantao de trabalho';

  @override
  String get segmentsFrontalierRulesTitle => 'REGRAS APLICAVEIS';

  @override
  String get segmentsFrontalierCatFiscal => 'Regime fiscal';

  @override
  String get segmentsFrontalierCat3a => '3º pilar';

  @override
  String get segmentsFrontalierCatLpp => 'LPP / Livre passagem';

  @override
  String get segmentsFrontalierCatAvs => 'AVS / Coordenacao';

  @override
  String get segmentsFrontalierQuasiResidentTitle =>
      'Estatuto de quase-residente (GE)';

  @override
  String get segmentsFrontalierQuasiResidentDesc =>
      'O estatuto de quase-residente e acessivel se pelo menos 90% dos rendimentos do agregado provem da Suica.';

  @override
  String get segmentsFrontalierQuasiResidentCondition =>
      'Condicao: >= 90% dos rendimentos do agregado provenientes da Suica';

  @override
  String get segmentsFrontalierChecklist => 'Checklist frontaleiro';

  @override
  String get segmentsFrontalierPaysFR => 'Franca';

  @override
  String get segmentsFrontalierPaysDE => 'Alemanha';

  @override
  String get segmentsFrontalierPaysIT => 'Italia';

  @override
  String get segmentsFrontalierPaysAT => 'Austria';

  @override
  String get segmentsFrontalierPaysLI => 'Liechtenstein';

  @override
  String get segmentsFrontalierAttention => 'Atencao';

  @override
  String get segmentsFrontalierDisclaimer =>
      'As informacoes apresentadas sao gerais e podem variar segundo a tua situacao pessoal. Consulta um fiduciario especializado em situacoes transfrontaleiras.';

  @override
  String get segmentsFrontalierSources => 'Fontes';

  @override
  String get segmentsIndependantTitle => 'Independente';

  @override
  String get segmentsIndependantSubtitle => 'Cobertura e protecao social';

  @override
  String get segmentsIndependantAppBar => 'PERCURSO INDEPENDENTE';

  @override
  String get segmentsIndependantHeader => 'Independente';

  @override
  String get segmentsIndependantHeaderSub => 'Analise de cobertura e protecao';

  @override
  String get segmentsIndependantIntro =>
      'Como independente, nao tens LPP obrigatoria, nem IJM, nem LAA. A tua protecao depende das tuas diligencias pessoais.';

  @override
  String get segmentsIndependantRevenuLabel => 'Rendimento liquido anual';

  @override
  String get segmentsIndependantCoverageTitle => 'A minha cobertura atual';

  @override
  String get segmentsIndependantLpp => 'LPP (filiacao voluntaria)';

  @override
  String get segmentsIndependantIjm => 'IJM (indemnizacao diaria de doenca)';

  @override
  String get segmentsIndependantLaa => 'LAA (seguro de acidentes)';

  @override
  String get segmentsIndependant3a => '3º pilar (3a)';

  @override
  String get segmentsIndependantAnalyseTitle => 'ANALISE DE COBERTURA';

  @override
  String get segmentsIndependantCouvert => 'Coberto';

  @override
  String get segmentsIndependantNonCouvert => 'NAO COBERTO';

  @override
  String get segmentsIndependantCritique => 'NAO COBERTO — Critico';

  @override
  String get segmentsIndependantProtectionTitle => 'Custo da protecao completa';

  @override
  String get segmentsIndependantProtectionSub => 'Estimativa mensal';

  @override
  String get segmentsIndependantAvs => 'AVS / AI / APG';

  @override
  String get segmentsIndependantIjmEst => 'IJM (estimativa)';

  @override
  String get segmentsIndependantLaaEst => 'LAA (estimativa)';

  @override
  String get segmentsIndependant3aMax => '3º pilar (max)';

  @override
  String get segmentsIndependantTotalMensuel => 'Total mensal';

  @override
  String get segmentsIndependantAvsTitle => 'Contribuicao AVS independente';

  @override
  String segmentsIndependantAvsDesc(String amount) {
    return 'A tua contribuicao AVS estimada: $amount/ano (taxa degressiva para rendimentos inferiores a CHF 58\'800).';
  }

  @override
  String get segmentsIndependant3aTitle => '3º pilar — teto independente';

  @override
  String get segmentsIndependant3aWithLpp =>
      'Com LPP voluntaria: teto 3a standard de CHF 7\'258/ano.';

  @override
  String get segmentsIndependant3aWithoutLpp =>
      'Sem LPP: teto 3a \'grande\' de 20% do rendimento liquido, max CHF 36\'288/ano.';

  @override
  String get segmentsIndependantRecTitle => 'RECOMENDACOES';

  @override
  String get segmentsIndependantDisclaimer =>
      'Os montantes apresentados sao estimativas indicativas. Consulta um fiduciario ou segurador antes de qualquer decisao.';

  @override
  String get segmentsIndependantSources => 'Fontes';

  @override
  String get segmentsIndependantAlertIjm =>
      'CRITICO: Nao tens seguro IJM. Em caso de doenca, nao teras nenhum rendimento de substituicao.';

  @override
  String get segmentsIndependantAlertLaa =>
      'IMPORTANTE: Sem seguro de acidentes individual (LAA), as despesas medicas em caso de acidente nao sao cobertas.';

  @override
  String get segmentsIndependantAlertLpp =>
      'A tua previdencia baseia-se unicamente no AVS e no 3º pilar.';

  @override
  String get segmentsIndependantAlert3a =>
      'Nao aproveitas o 3º pilar. Teto independente: CHF 36\'288/ano.';

  @override
  String get segmentsDemoMode =>
      'Modo demo: perfil exemplo. Completa o teu diagnostico para resultados personalizados.';

  @override
  String get assurancesLamalTitle => 'Otimizador de franquia LAMal';

  @override
  String get assurancesLamalSubtitle =>
      'Encontra a franquia ideal segundo as tuas despesas de saude';

  @override
  String get assurancesLamalPrimeMensuelle => 'Premio mensal (franquia 300)';

  @override
  String get assurancesLamalDepensesSante =>
      'Despesas de saude anuais estimadas';

  @override
  String get assurancesLamalAdulte => 'Adulto';

  @override
  String get assurancesLamalEnfant => 'Crianca';

  @override
  String get assurancesLamalFranchise => 'Franquia';

  @override
  String get assurancesLamalPrimeAnnuelle => 'Premio anual';

  @override
  String get assurancesLamalCoutTotal => 'Custo total';

  @override
  String get assurancesLamalEconomie => 'Poupanca vs 300';

  @override
  String get assurancesLamalOptimale => 'Franquia recomendada';

  @override
  String get assurancesLamalBreakEven => 'Limiar de rentabilidade';

  @override
  String get assurancesLamalDelaiRappel =>
      'Lembrete: alteracao possivel antes de 30 de novembro';

  @override
  String get assurancesLamalQuotePart => 'Quota-parte (10%, max 700 CHF)';

  @override
  String get assurancesCoverageTitle => 'Check-up de cobertura';

  @override
  String get assurancesCoverageSubtitle => 'Avalia a tua protecao de seguros';

  @override
  String get assurancesCoverageScore => 'Score de cobertura';

  @override
  String get assurancesCoverageLacunes => 'Lacunas identificadas';

  @override
  String get assurancesCoverageStatut => 'Estatuto profissional';

  @override
  String get assurancesCoverageSalarie => 'Assalariado';

  @override
  String get assurancesCoverageIndependant => 'Independente';

  @override
  String get assurancesCoverageSansEmploi => 'Sem emprego';

  @override
  String get assurancesCoverageHypotheque => 'Hipoteca em curso';

  @override
  String get assurancesCoverageFamille => 'Pessoas a cargo';

  @override
  String get assurancesCoverageLocataire => 'Inquilino';

  @override
  String get assurancesCoverageVoyages => 'Viagens frequentes';

  @override
  String get assurancesCoverageIjm => 'IJM coletiva (empregador)';

  @override
  String get assurancesCoverageLaa => 'LAA (seguro de acidentes)';

  @override
  String get assurancesCoverageRc => 'RC privada';

  @override
  String get assurancesCoverageMenage => 'Seguro de recheio';

  @override
  String get assurancesCoverageJuridique => 'Protecao juridica';

  @override
  String get assurancesCoverageVoyage => 'Seguro de viagem';

  @override
  String get assurancesCoverageDeces => 'Seguro de falecimento';

  @override
  String get assurancesCoverageCouvert => 'Coberto';

  @override
  String get assurancesCoverageNonCouvert => 'Nao coberto';

  @override
  String get assurancesCoverageAVerifier => 'A verificar';

  @override
  String get assurancesCoverageCritique => 'Critico';

  @override
  String get assurancesCoverageHaute => 'Alta';

  @override
  String get assurancesCoverageMoyenne => 'Media';

  @override
  String get assurancesCoverageBasse => 'Baixa';

  @override
  String get assurancesDemoMode => 'MODO DEMO';

  @override
  String get assurancesDisclaimer =>
      'Esta analise e indicativa. Os premios variam segundo a seguradora, a regiao e o modelo de seguro. Consulta a tua caixa de saude para valores exatos.';

  @override
  String get assurancesSection => 'Seguros';

  @override
  String get assurancesLamalTile => 'Franquia LAMal';

  @override
  String get assurancesLamalTileSub => 'Encontra a franquia ideal';

  @override
  String get assurancesCoverageTile => 'Check-up de cobertura';

  @override
  String get assurancesCoverageTileSub => 'Avalia a tua protecao de seguros';

  @override
  String get openBankingTitle => 'Open Banking';

  @override
  String get openBankingSubtitle => 'Liga as tuas contas bancarias';

  @override
  String get openBankingFinmaGate =>
      'Funcionalidade em preparacao — consulta regulamentar FINMA em curso';

  @override
  String get openBankingDemoData =>
      'Os dados exibidos sao exemplos de demonstracao';

  @override
  String get openBankingTotalBalance => 'Saldo total';

  @override
  String get openBankingAccounts => 'Contas ligadas';

  @override
  String get openBankingAddBank => 'Adicionar um banco';

  @override
  String get openBankingAddBankDisabled => 'Disponivel apos consulta FINMA';

  @override
  String get openBankingTransactions => 'Transacoes';

  @override
  String get openBankingNoTransactions => 'Nenhuma transacao';

  @override
  String get openBankingIncome => 'Rendimentos';

  @override
  String get openBankingExpenses => 'Despesas';

  @override
  String get openBankingNetSavings => 'Poupanca liquida';

  @override
  String get openBankingSavingsRate => 'Taxa de poupanca';

  @override
  String get openBankingConsents => 'Consentimentos';

  @override
  String get openBankingConsentActive => 'Ativo';

  @override
  String get openBankingConsentExpiring => 'Expira em breve';

  @override
  String get openBankingConsentExpired => 'Expirado';

  @override
  String get openBankingConsentRevoke => 'Revogar';

  @override
  String get openBankingConsentRevoked => 'Revogado';

  @override
  String get openBankingConsentScopes => 'Autorizacoes';

  @override
  String get openBankingConsentScopeAccounts => 'Contas';

  @override
  String get openBankingConsentScopeBalances => 'Saldos';

  @override
  String get openBankingConsentScopeTransactions => 'Transacoes';

  @override
  String get openBankingConsentDuration => 'Duracao maxima: 90 dias';

  @override
  String get openBankingNlpdTitle => 'Os teus direitos (nLPD)';

  @override
  String get openBankingNlpdRevoke =>
      'Podes revogar o teu consentimento a qualquer momento';

  @override
  String get openBankingNlpdNoSharing =>
      'Os teus dados nunca sao partilhados com terceiros';

  @override
  String get openBankingNlpdReadOnly =>
      'Acesso em leitura apenas — nenhuma operacao financeira';

  @override
  String get openBankingNlpdDuration =>
      'Duracao maxima de consentimento: 90 dias';

  @override
  String get openBankingSelectBank => 'Escolher um banco';

  @override
  String get openBankingSelectScopes => 'Escolher as autorizacoes';

  @override
  String get openBankingConfirm => 'Confirmar';

  @override
  String get openBankingCancel => 'Cancelar';

  @override
  String get openBankingBack => 'Voltar';

  @override
  String get openBankingNext => 'Seguinte';

  @override
  String get openBankingCategoryAll => 'Todas';

  @override
  String get openBankingCategoryAlimentation => 'Alimentacao';

  @override
  String get openBankingCategoryTransport => 'Transporte';

  @override
  String get openBankingCategoryLogement => 'Alojamento';

  @override
  String get openBankingCategoryTelecom => 'Telecom';

  @override
  String get openBankingCategoryAssurances => 'Seguros';

  @override
  String get openBankingCategoryEnergie => 'Energia';

  @override
  String get openBankingCategorySante => 'Saude';

  @override
  String get openBankingCategoryLoisirs => 'Lazer';

  @override
  String get openBankingCategoryImpots => 'Impostos';

  @override
  String get openBankingCategoryEpargne => 'Poupanca';

  @override
  String get openBankingCategoryDivers => 'Diversos';

  @override
  String get openBankingCategoryRevenu => 'Rendimento';

  @override
  String get openBankingLastSync => 'Ultima sincronizacao';

  @override
  String get openBankingIbanMasked => 'IBAN mascarado';

  @override
  String get openBankingFilterAll => 'Todas';

  @override
  String get openBankingThisMonth => 'Este mes';

  @override
  String get openBankingLastMonth => 'Mes anterior';

  @override
  String get openBankingDemoMode => 'MODO DEMO';

  @override
  String get openBankingDisclaimer =>
      'Esta funcionalidade esta em desenvolvimento. Os dados exibidos sao exemplos. A ativacao do servico Open Banking esta sujeita a uma consulta regulamentar previa.';

  @override
  String get openBankingBlink => 'Alimentado por bLink (SIX)';

  @override
  String get openBankingFinancialOverview => 'Visao geral financeira';

  @override
  String get openBankingTopExpenses => 'Top 3 despesas';

  @override
  String get openBankingViewTransactions => 'Ver transacoes';

  @override
  String get openBankingManageConsents => 'Gerir consentimentos';

  @override
  String get openBankingMonthlySummary => 'Resumo mensal';

  @override
  String get openBankingAddConsent => 'Adicionar consentimento';

  @override
  String get openBankingConsentGrantedOn => 'Concedido em';

  @override
  String get openBankingConsentExpiresOn => 'Expira em';

  @override
  String get openBankingConsentRevokedConfirm => 'Consentimento revogado';

  @override
  String get openBankingScopeAccountsDesc => 'Contas (lista das tuas contas)';

  @override
  String get openBankingScopeBalancesDesc =>
      'Saldos (saldo atual das tuas contas)';

  @override
  String get openBankingScopeTransactionsDesc =>
      'Transacoes (historico de movimentos)';

  @override
  String get openBankingReadOnlyInfo =>
      'Acesso em leitura apenas. Nenhuma operacao financeira pode ser efetuada.';

  @override
  String get openBankingConsentConfirmText =>
      'Ao confirmar, autorizas o MINT a aceder aos dados selecionados em modo de leitura durante 90 dias. Podes revogar este consentimento a qualquer momento.';

  @override
  String get openBankingSection => 'Open Banking';

  @override
  String get openBankingTile => 'Open Banking';

  @override
  String get openBankingTileSub => 'Liga as tuas contas bancarias';

  @override
  String get lppDeepSection => 'LPP APROFUNDADO';

  @override
  String get lppDeepRachatTitle => 'Resgate escalonado';

  @override
  String get lppDeepRachatSubtitle =>
      'Otimiza os teus resgates LPP ao longo de varios anos';

  @override
  String get lppDeepRachatAppBar => 'RESGATE LPP ESCALONADO';

  @override
  String get lppDeepRachatIntroTitle => 'Porque escalonar os resgates?';

  @override
  String get lppDeepRachatIntroBody =>
      'O imposto suico sendo progressivo, repartir um resgate LPP por varios anos permite ficar em escaloes marginais mais elevados cada ano, maximizando assim a poupanca fiscal total.';

  @override
  String get lppDeepRachatParams => 'Parametros';

  @override
  String get lppDeepRachatAvoirActuel => 'Haver LPP atual';

  @override
  String get lppDeepRachatMax => 'Resgate maximo';

  @override
  String get lppDeepRachatRevenu => 'Rendimento tributavel';

  @override
  String get lppDeepRachatTauxMarginal => 'Taxa marginal estimada';

  @override
  String get lppDeepRachatHorizon => 'Horizonte (anos)';

  @override
  String get lppDeepRachatComparaison => 'Comparacao';

  @override
  String get lppDeepRachatBloc => 'TUDO EM 1 ANO';

  @override
  String get lppDeepRachatBlocSub => 'Resgate em bloco';

  @override
  String lppDeepRachatEchelonne(String years) {
    return 'ESCALONADO EM $years ANOS';
  }

  @override
  String get lppDeepRachatEchelonneSub => 'Resgate repartido';

  @override
  String get lppDeepRachatEconomie => 'Poupanca fiscal';

  @override
  String lppDeepRachatEconomieDelta(String amount) {
    return 'Ao escalonar, poupas mais CHF $amount de impostos.';
  }

  @override
  String get lppDeepRachatPlanAnnuel => 'Plano anual';

  @override
  String get lppDeepRachatAnnee => 'Ano';

  @override
  String get lppDeepRachatMontant => 'Resgate';

  @override
  String get lppDeepRachatEcoFiscale => 'Poupanca';

  @override
  String get lppDeepRachatCoutNet => 'Custo liquido';

  @override
  String get lppDeepRachatTotal => 'Total';

  @override
  String get lppDeepRachatBlocageEpl => 'LPP art. 79b al. 3 — Bloqueio EPL';

  @override
  String get lppDeepRachatBlocageEplBody =>
      'Apos cada resgate, qualquer levantamento EPL (incentivo a propriedade de habitacao) fica bloqueado durante 3 anos. Planeia em conformidade se uma compra imobiliaria estiver prevista.';

  @override
  String get lppDeepRachatDisclaimer =>
      'Simulacao pedagogica baseada numa progressividade estimada. O resgate LPP esta sujeito a aceitacao pela caixa de pensoes. Consulta a tua caixa de pensoes e um especialista em previdencia antes de qualquer decisao.';

  @override
  String get lppDeepLibrePassageTitle => 'Livre passagem';

  @override
  String get lppDeepLibrePassageSubtitle =>
      'Checklist em caso de mudanca de emprego ou partida';

  @override
  String get lppDeepLibrePassageAppBar => 'LIVRE PASSAGEM';

  @override
  String get lppDeepLibrePassageSituation => 'Situacao';

  @override
  String get lppDeepLibrePassageChangement => 'Mudanca de emprego';

  @override
  String get lppDeepLibrePassageDepart => 'Partida da Suica';

  @override
  String get lppDeepLibrePassageCessation => 'Cessacao de atividade';

  @override
  String get lppDeepLibrePassageNewEmployer => 'Novo empregador';

  @override
  String get lppDeepLibrePassageNewEmployerSub => 'Ja tens um novo empregador?';

  @override
  String get lppDeepLibrePassageAlertes => 'Alertas';

  @override
  String get lppDeepLibrePassageChecklist => 'Checklist';

  @override
  String get lppDeepLibrePassageRecommandations => 'Recomendacoes';

  @override
  String get lppDeepLibrePassageUrgenceCritique => 'Critico';

  @override
  String get lppDeepLibrePassageUrgenceHaute => 'Alta';

  @override
  String get lppDeepLibrePassageUrgenceMoyenne => 'Media';

  @override
  String get lppDeepLibrePassageCentrale => 'Central do 2º pilar (sfbvg.ch)';

  @override
  String get lppDeepLibrePassageCentraleSub =>
      'Pesquisa haveres de livre passagem esquecidos';

  @override
  String get lppDeepLibrePassagePrivacy =>
      'Os teus dados ficam no teu dispositivo. Nenhuma informacao e transmitida a terceiros. Conforme com a nLPD.';

  @override
  String get lppDeepLibrePassageDisclaimer =>
      'Estas informacoes sao pedagogicas e nao constituem aconselhamento juridico ou financeiro personalizado. As regras dependem da tua caixa de pensoes e da tua situacao. Base legal: LFLP, OLP.';

  @override
  String get lppDeepEplTitle => 'Levantamento EPL';

  @override
  String get lppDeepEplSubtitle => 'Financiar uma habitacao com o teu 2º pilar';

  @override
  String get lppDeepEplAppBar => 'LEVANTAMENTO EPL';

  @override
  String get lppDeepEplIntroTitle =>
      'Levantamento EPL — Propriedade de habitacao';

  @override
  String get lppDeepEplIntroBody =>
      'O EPL permite utilizar o teu haver LPP para financiar a compra de uma habitacao, amortizar uma hipoteca ou financiar renovacoes. Montante minimo: CHF 20\'000.';

  @override
  String get lppDeepEplParams => 'Parametros';

  @override
  String get lppDeepEplAvoirTotal => 'Haver LPP total';

  @override
  String get lppDeepEplAge => 'Idade';

  @override
  String get lppDeepEplMontantSouhaite => 'Montante desejado';

  @override
  String get lppDeepEplRachatsRecents => 'Resgates LPP recentes';

  @override
  String get lppDeepEplRachatsRecentsSub =>
      'Efetuaste um resgate LPP nos ultimos 3 anos?';

  @override
  String get lppDeepEplAnneesSDepuisRachat => 'Anos desde o resgate';

  @override
  String get lppDeepEplResultat => 'Resultado';

  @override
  String get lppDeepEplMontantMaxRetirable => 'Montante maximo levantavel';

  @override
  String get lppDeepEplMontantApplicable => 'Montante aplicavel';

  @override
  String get lppDeepEplRetraitImpossible =>
      'O levantamento nao e possivel na configuracao atual.';

  @override
  String get lppDeepEplImpactPrestations => 'Impacto nas prestacoes';

  @override
  String get lppDeepEplReductionInvalidite =>
      'Reducao da renda de invalidez (estimativa anual)';

  @override
  String get lppDeepEplReductionDeces =>
      'Reducao do capital de falecimento (estimativa)';

  @override
  String get lppDeepEplImpactNote =>
      'O levantamento EPL reduz proporcionalmente as tuas prestacoes de risco. Verifica junto da tua caixa de pensoes os montantes exatos.';

  @override
  String get lppDeepEplEstimationFiscale => 'Estimativa fiscal';

  @override
  String get lppDeepEplMontantRetire => 'Montante levantado';

  @override
  String get lppDeepEplImpotEstime => 'Imposto estimado sobre o levantamento';

  @override
  String get lppDeepEplMontantNet => 'Montante liquido apos imposto';

  @override
  String get lppDeepEplTaxNote =>
      'O levantamento em capital e tributado a uma taxa reduzida (cerca de 1/5 do bareme ordinario). A taxa exata depende do cantao e da situacao pessoal.';

  @override
  String get lppDeepEplPointsAttention => 'Pontos de atencao';

  @override
  String get lppDeepEplDisclaimer =>
      'Simulacao pedagogica a titulo indicativo. O montante levantavel exato depende do regulamento da tua caixa de pensoes. O imposto varia segundo o cantao e a situacao pessoal. Base legal: art. 30c LPP, OEPL.';

  @override
  String get exploreTitle => 'EXPLORAR';

  @override
  String get explorePillarComprendreTitle => 'Quero entender';

  @override
  String get explorePillarComprendreSub =>
      'O essencial das financas suicas, sem jargao. Quiz incluido.';

  @override
  String get explorePillarComprendreCta => 'Explorar os 9 temas';

  @override
  String get explorePillarCalculerTitle => 'Quero calcular';

  @override
  String get explorePillarCalculerSub =>
      'Simula, compara, otimiza. 49 ferramentas a tua disposicao.';

  @override
  String get explorePillarCalculerCta => 'Ver todas as ferramentas';

  @override
  String get explorePillarLifeTitle => 'Esta a acontecer-me algo';

  @override
  String get explorePillarLifeSub =>
      'Casamento, nascimento, divorcio, mudanca... acompanhamos-te.';

  @override
  String get exploreGoalBudget => 'Dominar o meu orcamento';

  @override
  String get exploreGoalBudgetSub => 'Gerir as minhas despesas → 3 min';

  @override
  String get exploreGoalProperty => 'Tornar-me proprietario';

  @override
  String get exploreGoalPropertySub => 'Simular a minha compra → 5 min';

  @override
  String get exploreGoalTax => 'Pagar menos impostos';

  @override
  String get exploreGoalTaxSub => 'Otimizar o meu 3a → 3 min';

  @override
  String get exploreGoalRetirement => 'Preparar a minha reforma';

  @override
  String get exploreGoalRetirementSub => 'Ver o meu plano → 10 min';

  @override
  String get exploreEventMarriage => 'Casamento';

  @override
  String get exploreEventMarriageSub => 'Impacto fiscal e LPP';

  @override
  String get exploreEventBirth => 'Nascimento';

  @override
  String get exploreEventBirthSub => 'Abonos e deducoes';

  @override
  String get exploreEventConcubinage => 'Uniao de facto';

  @override
  String get exploreEventConcubinageSub => 'Proteger o teu casal';

  @override
  String get exploreEventDivorce => 'Divorcio';

  @override
  String get exploreEventDivorceSub => 'Partilha LPP e AVS';

  @override
  String get exploreEventSuccession => 'Sucessao';

  @override
  String get exploreEventSuccessionSub => 'Direitos e planeamento';

  @override
  String get exploreEventHouseSale => 'Venda imobiliaria';

  @override
  String get exploreEventHouseSaleSub => 'Imposto mais-valia';

  @override
  String get exploreEventDonation => 'Doacao';

  @override
  String get exploreEventDonationSub => 'Fiscalidade e limites';

  @override
  String get exploreEventExpat => 'Expatriacao';

  @override
  String get exploreEventExpatSub => 'Partida ou chegada';

  @override
  String get exploreDocUploadLpp => 'Certificados e documentos';

  @override
  String get exploreDocUploadLppSub => 'Certificado LPP, extratos AVS →';

  @override
  String get exploreAskMintTitle => 'Ask MINT';

  @override
  String get exploreAskMintConfigured =>
      'Faz as tuas perguntas sobre financas suicas →';

  @override
  String get exploreAskMintNotConfigured => 'Configura a tua IA para comecar →';

  @override
  String get exploreLearn3a => 'O que e o pilar 3a?';

  @override
  String get exploreLearnLpp => 'LPP: Como funciona';

  @override
  String get exploreLearnFiscal => 'Fiscalidade suica 101';

  @override
  String get coachWelcome => 'Os teus números estão prontos';

  @override
  String coachHello(String firstName) {
    return 'Bonjour $firstName';
  }

  @override
  String get coachFitnessTitle => 'Ton Fitness Financier';

  @override
  String get coachFinancialForm => 'Forme financière';

  @override
  String get coachScoreComposite => 'Score composite · 3 piliers';

  @override
  String get coachPillarBudget => 'Budget';

  @override
  String get coachPillarPrevoyance => 'Prévoyance';

  @override
  String get coachPillarPatrimoine => 'Patrimoine';

  @override
  String get coachCompletePrompt =>
      'Completa o teu diagnóstico para ver a tua pontuação';

  @override
  String get coachDiscoverScore => 'Ver a minha pontuação — 10 min';

  @override
  String get coachTrajectory => 'Ta trajectoire';

  @override
  String get coachTrajectoryPrompt => 'Ta trajectoire financière t\'attend';

  @override
  String get coachDidYouKnow => 'Le savais-tu ?';

  @override
  String get coachFact3a =>
      'Le 3e pilier peut te faire économiser jusqu\'à CHF 2\'500 d\'impôts par an, selon ton canton et ton revenu.';

  @override
  String get coachFact3aLink => 'Simuler mon économie 3a';

  @override
  String get coachFactAvs =>
      'En Suisse, chaque année AVS manquante = −2.3% de rente à vie. Un rattrapage est possible dans certains cas.';

  @override
  String get coachFactAvsLink => 'Vérifier mes années AVS';

  @override
  String get coachFactLpp =>
      'Le rachat LPP est l\'un des leviers fiscaux les plus puissants pour les salarié·es en Suisse. Il est intégralement déductible du revenu imposable.';

  @override
  String get coachFactLppLink => 'Explorer le rachat LPP';

  @override
  String get coachMotivation =>
      'Rejoins les milliers d\'utilisateurs qui ont déjà fait leur diagnostic financier';

  @override
  String get coachMotivationSub => 'et recevoir des actions concrètes.';

  @override
  String get coachLaunchDiagnostic => 'Lancer mon diagnostic';

  @override
  String get coachQuickActions => 'Actions rapides';

  @override
  String get coachCheckin => 'Check-in\nmensuel';

  @override
  String get coachVerse3a => 'Verser\n3a';

  @override
  String get coachSimBuyback => 'Simuler\nrachat';

  @override
  String get coachExplore => 'Explorer';

  @override
  String get coachDisclaimer =>
      'Ferramenta educativa — as respostas não constituem aconselhamento financeiro. LSFin.';

  @override
  String get eduTheme3aTitle => 'Le 3e pilier (3a)';

  @override
  String get eduTheme3aQuestion =>
      'C\'est quoi le 3a et pourquoi tout le monde en parle ?';

  @override
  String get eduTheme3aAction => 'Estimer mon économie fiscale';

  @override
  String get eduTheme3aReminder =>
      'Décembre → Dernier moment pour verser cette année';

  @override
  String get eduThemeLppTitle => 'La caisse de pension (LPP)';

  @override
  String get eduThemeLppQuestion => 'Est-ce que j\'ai une caisse de pension ?';

  @override
  String get eduThemeLppAction => 'Analyser mon certificat LPP';

  @override
  String get eduThemeLppReminder =>
      'Demander mon certificat LPP à mon employeur';

  @override
  String get eduThemeAvsTitle => 'Les lacunes AVS';

  @override
  String get eduThemeAvsQuestion =>
      'Ai-je des années de cotisation manquantes ?';

  @override
  String get eduThemeAvsAction => 'Vérifier mon extrait de compte AVS';

  @override
  String get eduThemeAvsReminder => 'Commander mon extrait sur ahv-iv.ch';

  @override
  String get eduThemeEmergencyTitle => 'Le fonds d\'urgence';

  @override
  String get eduThemeEmergencyQuestion => 'Combien je devrais avoir de côté ?';

  @override
  String get eduThemeEmergencyAction => 'Calculer mon objectif';

  @override
  String get eduThemeEmergencyReminder =>
      'Vérifier mon épargne de sécurité chaque trimestre';

  @override
  String get eduThemeDebtTitle => 'Les dettes';

  @override
  String get eduThemeDebtQuestion => 'Combien me coûte vraiment ma dette ?';

  @override
  String get eduThemeDebtAction => 'Calculer le coût total';

  @override
  String get eduThemeDebtReminder => 'Priorité: rembourser avant d\'investir';

  @override
  String get eduThemeMortgageTitle => 'L\'hypothèque';

  @override
  String get eduThemeMortgageQuestion =>
      'Fixe ou SARON, c\'est quoi la différence ?';

  @override
  String get eduThemeMortgageAction => 'Comparer les deux stratégies';

  @override
  String get eduThemeMortgageReminder =>
      'Avant renouvellement: comparer 3 mois à l\'avance';

  @override
  String get eduThemeBudgetTitle => 'Le reste à vivre';

  @override
  String get eduThemeBudgetQuestion =>
      'Combien il me reste après les charges fixes ?';

  @override
  String get eduThemeBudgetAction => 'Estimer mon reste à vivre';

  @override
  String get eduThemeBudgetReminder => 'Revoir mon budget chaque mois';

  @override
  String get eduThemeLamalTitle => 'Les subsides LAMal';

  @override
  String get eduThemeLamalQuestion =>
      'Ai-je droit à une aide pour mes primes ?';

  @override
  String get eduThemeLamalAction => 'Vérifier mon éligibilité';

  @override
  String get eduThemeLamalReminder => 'Les critères changent selon le canton';

  @override
  String get eduThemeFiscalTitle => 'La fiscalité suisse';

  @override
  String get eduThemeFiscalQuestion =>
      'Comment fonctionnent les impôts en Suisse ?';

  @override
  String get eduThemeFiscalAction => 'Simuler mon économie 3a';

  @override
  String get eduThemeFiscalReminder =>
      'Deadline déclaration fiscale : 31 mars (extensible)';

  @override
  String get eduHubTitle => 'J\'Y COMPRENDS RIEN';

  @override
  String get eduHubSubtitle =>
      'Escolhe um tema. O essencial em claro, uma ação concreta no final.';

  @override
  String get eduHubReadQuiz => 'Lire + quiz • 2 min';

  @override
  String get askMintSuggestDebt =>
      'J\'ai des dettes — par où commencer pour m\'en sortir ?';

  @override
  String askMintSuggestAge3a(String age) {
    return 'J\'ai $age ans, est-ce que je devrais déjà cotiser au 3e pilier ?';
  }

  @override
  String askMintSuggestAgeLpp(String age) {
    return 'J\'ai $age ans, est-ce que je devrais racheter du LPP ?';
  }

  @override
  String askMintSuggestAgeRetirement(String age) {
    return 'J\'ai $age ans, comment préparer ma retraite au mieux ?';
  }

  @override
  String get askMintSuggestSelfEmployed =>
      'Je suis indépendant·e — comment me protéger sans LPP ?';

  @override
  String get askMintSuggestUnemployed =>
      'Je suis au chômage — quel impact sur ma prévoyance ?';

  @override
  String askMintSuggestCanton(String canton) {
    return 'Quelles déductions fiscales sont possibles dans le canton de $canton ?';
  }

  @override
  String get askMintSuggestIncome =>
      'Avec mon revenu, combien je peux déduire fiscalement par an ?';

  @override
  String get askMintSuggestGeneric1 =>
      'Rente ou capital LPP — quelle est la différence ?';

  @override
  String get askMintSuggestGeneric2 =>
      'Comment optimiser mes impôts cette année ?';

  @override
  String get askMintSuggestGeneric3 =>
      'Qu\'est-ce que le rachat LPP et est-ce que ça vaut le coup ?';

  @override
  String get askMintSuggestGeneric4 =>
      'Comment fonctionne la franchise LAMal ?';

  @override
  String get askMintEmptyBody =>
      'Finance suisse, décryptage des lois, simulateurs — je t\'explique tout, sources à l\'appui.';

  @override
  String get askMintPrivacyBadge => 'Tes données restent sur ton appareil';

  @override
  String get askMintForYou => 'POUR TOI';

  @override
  String get byokRecommended => 'Recommandé';

  @override
  String byokGetKeyOn(String provider) {
    return 'Obtenir une clé sur $provider';
  }

  @override
  String get byokCopilotActivated => 'Ton copilote financier est activé';

  @override
  String get byokCopilotBody =>
      'Pose ta première question sur la finance suisse — 3e pilier, impôts, LPP, budget...';

  @override
  String get byokTryNow => 'Essayer maintenant';

  @override
  String get trajectoryTitle => 'Ta trajectoire';

  @override
  String trajectorySubtitle(String years) {
    return '3 scénarios · $years ans';
  }

  @override
  String get trajectoryOptimiste => 'Optimiste';

  @override
  String get trajectoryBase => 'Base';

  @override
  String get trajectoryPrudent => 'Prudent';

  @override
  String get trajectoryTauxRemplacement => 'Taux de remplacement estimé : ';

  @override
  String get trajectoryEmpty => 'Sem projeção ainda';

  @override
  String get trajectoryEmptySub =>
      'Um scan do teu certificado LPP, e tudo se esclarece.';

  @override
  String get trajectoryDisclaimer =>
      'Estimativas educativas — não constitui aconselhamento financeiro.';

  @override
  String get trajectoryDragHint => 'Glisse pour explorer';

  @override
  String get trajectoryGoalLabel => 'Cible';

  @override
  String get agirTitle => 'AGIR';

  @override
  String get agirThisMonth => 'Ce mois';

  @override
  String get agirTimeline => 'Timeline';

  @override
  String get agirTimelineSub => 'Tes prochaines échéances';

  @override
  String get agirHistory => 'Historique';

  @override
  String get agirHistorySub => 'Tes check-ins passés';

  @override
  String agirCheckinDone(String month) {
    return 'Check-in $month effectué';
  }

  @override
  String get agirDone => 'Fait';

  @override
  String agirCheckinCta(String month) {
    return 'Faire mon check-in $month';
  }

  @override
  String get agirNoCheckin => 'Pas encore de check-in';

  @override
  String get agirNoCheckinSub =>
      'Fais ton premier check-in pour commencer à suivre ta progression.';

  @override
  String get agirTimeline3a => 'Dernier jour versement 3a';

  @override
  String get agirTimeline3aSub =>
      'Vérifie que ton plafond est atteint avant fin décembre.';

  @override
  String get agirTimeline3aCta => 'Vérifier mon 3a';

  @override
  String agirTimelineTax(String canton) {
    return 'Déclaration impôts $canton';
  }

  @override
  String get agirTimelineTaxSub =>
      'Pense à rassembler tes attestations 3a et LPP.';

  @override
  String get agirTimelineTaxCta => 'Préparer mes documents';

  @override
  String get agirTimelineLamal => 'Franchise LAMal (changer ?)';

  @override
  String get agirTimelineLamalSub =>
      'Évalue si ta franchise actuelle est toujours adaptée.';

  @override
  String get agirTimelineLamalCta => 'Simuler les franchises';

  @override
  String get agirTimelineRetireSub => 'Ton objectif principal.';

  @override
  String get agirAuto => 'Auto';

  @override
  String get agirManuel => 'Manuel';

  @override
  String get agirDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier personnalisé. Les échéances et projections sont indicatives. Consulte un·e spécialiste pour un accompagnement adapté. LSFin.';

  @override
  String checkinTitle(String month) {
    return 'CHECK-IN $month';
  }

  @override
  String checkinHeader(String month) {
    return 'Check-in $month';
  }

  @override
  String get checkinSubtitle => 'Confirme tes versements du mois';

  @override
  String get checkinPlannedSection => 'Versements planifiés';

  @override
  String get checkinEventsSection => 'Événements du mois';

  @override
  String get checkinExpenses => 'Dépenses exceptionnelles ?';

  @override
  String get checkinExpensesHint => 'Ex: 2000 (réparation voiture)';

  @override
  String get checkinRevenues => 'Revenus exceptionnels ?';

  @override
  String get checkinRevenuesHint => 'Ex: 5000 (bonus annuel)';

  @override
  String get checkinNoteSection => 'Note du mois (optionnel)';

  @override
  String get checkinNoteHint =>
      'Ex: Mois compliqué, dépense imprévue pour la voiture...';

  @override
  String get checkinSubmit => 'Valider le check-in';

  @override
  String get checkinInvalidAmount => 'Montant invalide';

  @override
  String checkinSuccessTitle(String month) {
    return 'Feito. Check-in $month concluído.';
  }

  @override
  String get checkinSeeTrajectory => 'Voir ma trajectoire mise à jour';

  @override
  String get checkinImpactLabel => 'Impact sur ta trajectoire';

  @override
  String checkinImpactCapital(String amount) {
    return 'Capital projeté +$amount ce mois';
  }

  @override
  String checkinImpactTotal(String amount) {
    return 'Total versements : $amount';
  }

  @override
  String get checkinStreakLabel => 'Série en cours';

  @override
  String checkinStreakCount(String count) {
    return '$count mois consécutifs on-track !';
  }

  @override
  String get checkinCoachTip => 'Tip du coach';

  @override
  String get checkinAuto => 'Auto';

  @override
  String get checkinManuel => 'Manuel';

  @override
  String get checkinDisclaimer =>
      'Outil éducatif — ne constitue pas un conseil financier personnalisé. Les projections sont basées sur des hypothèses et peuvent varier. Consulte un·e spécialiste pour un accompagnement adapté. LSFin.';

  @override
  String get checkinAddContribution => 'Adicionar um pagamento';

  @override
  String get checkinCategoryLabel => 'Categoria';

  @override
  String get checkinCat3a => 'Pilar 3a';

  @override
  String get checkinCatLpp => 'Resgate LPP';

  @override
  String get checkinCatInvest => 'Investimento';

  @override
  String get checkinCatEpargne => 'Poupança livre';

  @override
  String get checkinLabelField => 'Nome';

  @override
  String get checkinLabelHint => 'Ex: 3a VIAC, Poupança férias...';

  @override
  String get checkinAmountField => 'Valor mensal';

  @override
  String get checkinAutoToggle => 'Ordem permanente (automático)';

  @override
  String get checkinAddConfirm => 'Adicionar';

  @override
  String get vaultTitle => 'Coffre-fort';

  @override
  String get vaultHeaderTitle => 'Ton coffre-fort financier';

  @override
  String get vaultHeaderSubtitle =>
      'Centralise, comprends et agis sur tes documents';

  @override
  String vaultDocCount(String count) {
    return '$count documents';
  }

  @override
  String get vaultCategoryLpp => 'Prévoyance LPP';

  @override
  String get vaultCategorySalary => 'Certificat de salaire';

  @override
  String get vaultCategory3a => '3e pilier';

  @override
  String get vaultCategoryInsurance => 'Assurances';

  @override
  String get vaultCategoryLease => 'Bail';

  @override
  String get vaultCategoryLamal => 'Santé (LAMal)';

  @override
  String get vaultCategoryOther => 'Autre';

  @override
  String vaultCategoryCount(String count) {
    return '$count';
  }

  @override
  String get vaultCategoryNone => 'Aucun';

  @override
  String get vaultGuidanceTitle => 'Guidance juridique';

  @override
  String get vaultGuidanceLeaseTitle => 'Bail — Tes droits de locataire';

  @override
  String get vaultGuidanceLeaseBody =>
      'En Suisse, le loyer peut être contesté s\'il dépasse le rendement admissible (CO art. 269). Le préavis légal est de 3 mois pour un appartement, sauf clause contraire dans le bail. L\'ASLOCA offre des consultations gratuites dans la plupart des cantons.';

  @override
  String get vaultGuidanceLeaseSource => 'CO art. 269-270, OBLF art. 12-13';

  @override
  String get vaultGuidanceInsuranceTitle => 'Assurances — Audit de couverture';

  @override
  String get vaultGuidanceInsuranceBody =>
      'La RC privée et l\'assurance ménage ne sont pas obligatoires en Suisse, mais fortement recommandées. Vérifie que ta somme assurée ménage couvre la valeur réelle de tes biens. La sous-assurance peut réduire l\'indemnisation proportionnellement (LCA art. 69).';

  @override
  String get vaultGuidanceInsuranceSource => 'LCA art. 69, CGA assureurs';

  @override
  String get vaultGuidanceLamalTitle => 'LAMal — Optimisation franchise';

  @override
  String get vaultGuidanceLamalBody =>
      'Tu peux changer de franchise LAMal chaque année au 30 novembre (franchise plus haute) ou au 31 décembre (franchise plus basse). Un·e adulte en bonne santé peut économiser jusqu\'à 1\'500 CHF/an avec une franchise de 2\'500 CHF vs 300 CHF.';

  @override
  String get vaultGuidanceLamalSource => 'LAMal art. 62, OAMal art. 93-94';

  @override
  String get vaultGuidanceSalaryTitle => 'Salaire — Vérification du certificat';

  @override
  String get vaultGuidanceSalaryBody =>
      'Ton certificat de salaire (Lohnausweis) est le document clé pour ta déclaration fiscale. Vérifie que les cotisations LPP, AVS et allocations familiales correspondent à tes fiches de paie. Toute erreur peut impacter tes impôts et ta prévoyance.';

  @override
  String get vaultGuidanceSalarySource => 'LIFD art. 127, OFS formulaire 11';

  @override
  String get vaultUploadTitle => 'Quel type de document ?';

  @override
  String get vaultUploadButton => 'Choisir un fichier PDF';

  @override
  String get vaultEmptyTitle => 'Aucun document';

  @override
  String get vaultEmptySubtitle =>
      'Ajoute ton premier document pour alimenter tes simulations avec des données réelles';

  @override
  String get vaultPremiumTitle => 'Coffre-fort Premium';

  @override
  String get vaultPremiumBody =>
      'Passe à MINT Premium pour stocker un nombre illimité de documents et débloquer l\'audit de couverture automatique';

  @override
  String get vaultPremiumCta => 'Découvrir Premium';

  @override
  String get vaultDocListTitle => 'Mes documents';

  @override
  String vaultConfidence(String confidence) {
    return 'Confiance : $confidence%';
  }

  @override
  String get vaultAnalyzing => 'Analyse en cours...';

  @override
  String get vaultDeleteTitle => 'Supprimer le document ?';

  @override
  String get vaultDeleteMessage => 'Cette action est irréversible.';

  @override
  String get vaultDeleteButton => 'Supprimer';

  @override
  String get vaultPrivacy =>
      'Tes documents sont analysés localement et ne sont jamais partagés avec des tiers. Tu peux les supprimer à tout moment.';

  @override
  String get vaultDisclaimer =>
      'MINT est un outil éducatif. Les informations juridiques présentées sont à titre informatif et ne constituent pas un conseil juridique personnalisé (LSFin, nLPD). Pour toute question spécifique, consulte un·e spécialiste qualifié·e.';

  @override
  String get soaTitle => 'Ton Plan Mint';

  @override
  String get soaScoreLabel => 'Score de Santé Financière';

  @override
  String get soaPrioritiesTitle => 'Tes 3 Actions Prioritaires';

  @override
  String get soaDiagnosticTitle => 'Diagnostic par Cercle';

  @override
  String get soaTaxTitle => 'Simulation Fiscale';

  @override
  String get soaRetirementTitle => 'Projection Retraite (65 ans)';

  @override
  String get soaLppTitle => 'Stratégie Rachat LPP';

  @override
  String get soaBudgetTitle => 'Ton Budget Calculé';

  @override
  String get soaTransparencyTitle => 'Transparence & Plan de Route';

  @override
  String get soaDisclaimerText =>
      'Outil éducatif — ne constitue pas un conseil financier au sens de la LSFin. Les montants sont des estimations basées sur les données déclarées.';

  @override
  String get soaNextTitle => 'Et ensuite ?';

  @override
  String get soaNextSubtitle => 'Modules adaptés à ton profil';

  @override
  String get soaExportPdf => 'Export PDF';

  @override
  String get soaActionStart => 'Commencer';

  @override
  String get soaTaxableIncome => 'Revenu imposable';

  @override
  String get soaDeductions => 'Déductions';

  @override
  String get soaEstimatedTax => 'Impôts estimés';

  @override
  String get soaEffectiveRate => 'Taux effectif';

  @override
  String get soaCapitalEstimate => 'Capital estimé';

  @override
  String get soaAvsRent => 'Rente AVS mensuelle';

  @override
  String get soaLppRent => 'Rente LPP mensuelle';

  @override
  String get soaTotalMonthly => 'TOTAL mensuel';

  @override
  String soaAvsGapWarning(String gap) {
    return 'Attention : Lacunes AVS détectées ($gap ans)';
  }

  @override
  String soaBuybackYear(String year) {
    return 'Année $year';
  }

  @override
  String soaBuybackAmount(String amount) {
    return 'Rachat: CHF $amount';
  }

  @override
  String soaBuybackSaving(String amount) {
    return 'Économie: CHF $amount';
  }

  @override
  String soaTotalSaving(String amount) {
    return 'Économie fiscale totale : CHF $amount';
  }

  @override
  String soaNature(String nature) {
    return 'Nature : $nature';
  }

  @override
  String get soaAssumptions => 'Hypothèses de Travail';

  @override
  String get soaConflicts => 'Conflits d\'intérêts & Commissions';

  @override
  String get soaNoConflict =>
      'Aucun conflit d\'intérêt identifié pour ce rapport.';

  @override
  String get soaSafeModeLocked => 'Priorité au désendettement';

  @override
  String get soaSafeModeMessage =>
      'Tes actions prioritaires sont remplacées par un plan de désendettement.';

  @override
  String get soaLimitations => 'Limitations';

  @override
  String get soaProtectionSources => 'Sources : LP art. 93, Directives CSIAS';

  @override
  String get soaPrevoyanceSources => 'Sources : LPP art. 14, OPP3, LAVS';

  @override
  String get soaCroissanceSources => 'Sources : LIFD art. 33';

  @override
  String get soaOptimisationSources => 'Sources : CC art. 470, LIFD';

  @override
  String get soaAvailableMonth => 'Disponible / mois';

  @override
  String get soaRemainder => 'Reste à vivre';

  @override
  String get soaEstimatedTaxLabel => 'Impôts Estimés';

  @override
  String get soaSavingsRate => 'Taux d\'épargne';

  @override
  String get soaSavingsGoal => 'Objectif: 20%';

  @override
  String get soaProtectionScore => 'Score Protection';

  @override
  String get soaActiveDebts => 'Dettes actives';

  @override
  String get soaSerene => 'Serein';

  @override
  String get soaNetIncome => 'Revenu net';

  @override
  String get soaHousing => 'Logement';

  @override
  String get soaDebtRepayment => 'Remboursement dettes';

  @override
  String get soaAvailable => 'Disponible';

  @override
  String get soaImportant => 'IMPORTANT:';

  @override
  String get soaDisclaimer1 =>
      'Ceci est un outil éducatif, ne constitue pas un conseil financier (LSFin).';

  @override
  String get soaDisclaimer2 =>
      'Les montants sont basés sur les informations déclarées.';

  @override
  String get soaDisclaimer3 =>
      '\'Disponible\' = Revenus - Logement - Dettes - Impôts - LAMal - Charges fixes.';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get profileCompleteBanner =>
      'Perfil completo! O teu coach tem todos os dados para conselhos fiáveis.';

  @override
  String get profileAnnualRefreshTitle => 'Atualização anual';

  @override
  String get profileAnnualRefreshBody =>
      'Os teus dados têm mais de 10 meses. Um check-up rápido (2 min) melhora o teu plano.';

  @override
  String get profileAnnualRefreshCta => 'Iniciar check-up';

  @override
  String get profileDangerZoneTitle => 'Zona de perigo';

  @override
  String get profileDangerZoneSubtitle =>
      'Repõe o teu histórico financeiro local sem eliminar a tua conta.';

  @override
  String get profileResetDialogTitle => 'Repor a minha situação?';

  @override
  String get profileResetDialogBody =>
      'Esta ação elimina o teu diagnóstico, os teus check-ins, a tua pontuação e o teu orçamento local.';

  @override
  String get profileResetDialogConfirmLabel => 'Escreve RESET para confirmar:';

  @override
  String get profileResetDialogInvalid => 'Palavra-chave inválida.';

  @override
  String get profileResetDialogAction => 'Repor';

  @override
  String get profileResetSuccess => 'Histórico financeiro local reposto.';

  @override
  String get profileResetScopeNote =>
      'Conserva a ligação e a chave BYOK. Os documentos do backend não são eliminados.';

  @override
  String get coachPulseTitle => 'Coach Pulse';

  @override
  String get coachIaBadge => 'Coach IA';

  @override
  String get agirCoachPulseDone =>
      'Tu es à jour ce mois-ci. Priorise maintenant l\'action la plus impactante.';

  @override
  String get agirCoachPulsePending =>
      'Ton check-in mensuel est la prochaine action critique pour garder ta trajectoire fiable.';

  @override
  String agirCoachPulseWhyNow(String reason) {
    return 'Pourquoi maintenant: $reason';
  }

  @override
  String get agirScenarioBriefTitle => 'Scénarios de retraite en bref';

  @override
  String agirScenarioBriefSummary(
      String years, String baseCapital, String replacement, String gapCapital) {
    return 'Dans ~$years ans, ton scénario Base vise $baseCapital (~$replacement% de remplacement). L\'écart Prudent vs Optimiste est $gapCapital.';
  }

  @override
  String get agirScenarioBriefCta => 'Ouvrir la simulation complète';

  @override
  String get advisorMiniWeekOneCta => 'Lancer ma semaine 1';

  @override
  String get advisorMiniStartWithDashboard => 'Commencer avec le dashboard';

  @override
  String get advisorMiniCoachIntroChallenge =>
      'Objectif: passer de l\'analyse à l\'action cette semaine. On commence maintenant avec 3 priorités.';

  @override
  String get checkinScoreReasonStable =>
      'Score stable ce mois: continue la régularité de tes actions.';

  @override
  String checkinScoreReasonPositiveContrib(String amount) {
    return 'Hausse principale: versements confirmés ($amount) ce mois.';
  }

  @override
  String get checkinScoreReasonPositiveIncome =>
      'Hausse principale: revenu exceptionnel ajouté ce mois.';

  @override
  String get checkinScoreReasonPositiveGeneral =>
      'Hausse principale: progression globale de ta discipline financière.';

  @override
  String checkinScoreReasonNegativeExpense(String amount) {
    return 'Baisse principale: dépenses exceptionnelles ce mois ($amount).';
  }

  @override
  String checkinScoreReasonNegativeContrib(String amount) {
    return 'Baisse principale: réduction de tes versements planifiés ($amount/mois).';
  }

  @override
  String get checkinScoreReasonNegativeGeneral =>
      'Baisse temporaire ce mois. On ajuste le plan au prochain check-in.';

  @override
  String get checkinImpactPending => 'Impact en cours de calcul';

  @override
  String get coachDataQualityTitle => 'Qualite des donnees';

  @override
  String coachDataQualityBody(String dataPoints, String percentage) {
    return 'Calcul actuel: $dataPoints donnees saisies ($percentage%). Les postes non renseignes restent en estimation jusqu au diagnostic complet.';
  }

  @override
  String get coachShockTitle => 'Os teus números-chave';

  @override
  String get coachShockSubtitle =>
      'Des montants personnalises pour eclairer tes decisions';

  @override
  String get coachScenarioDecodedTitle => 'Tes scenarios decryptes';

  @override
  String get coachBadgeStatic => 'Coach';

  @override
  String get agirActionsRecommendedTitle => 'Actions recommandees';

  @override
  String get agirActionsRecommendedSubtitle => 'Triees par priorite';

  @override
  String get profileCoachKnowledgeTitle => 'Ce que MINT sait de toi';

  @override
  String get profileStateFull => 'Profil complet';

  @override
  String get profileStatePartial => 'Profil partiel';

  @override
  String get profileStateMissing => 'Profil non renseigne';

  @override
  String profileCoachKnowledgeSummary(String profileState, String precision,
      String checkins, String scorePart) {
    return '$profileState • Precision $precision% • Check-ins: $checkins$scorePart';
  }

  @override
  String get profileChipEntered => 'saisi';

  @override
  String get profileChipEstimated => 'estime';

  @override
  String get profileChipToComplete => 'a completer';

  @override
  String get coachNarrativeModeConcise => 'Curto';

  @override
  String get coachNarrativeModeDetailed => 'Detalhado';

  @override
  String get advisorMiniMetricsWinnerLive => 'Vencedor ao vivo';

  @override
  String get advisorMiniMetricsUplift => 'Ganho challenge vs control';

  @override
  String get advisorMiniMetricsSignal => 'Sinal';

  @override
  String get advisorMiniMetricsSignalInsufficient =>
      'Aguardar >=10 inicios por variante';

  @override
  String get profileCoachMonthlyTitle => 'Resumo coach do mes';

  @override
  String get profileCoachMonthlyTrendInsufficient =>
      'Ainda nao ha check-ins suficientes para uma tendencia mensal.';

  @override
  String profileCoachMonthlyTrendUp(String delta) {
    return '+$delta pontos este mes, boa dinamica.';
  }

  @override
  String profileCoachMonthlyTrendDown(String delta) {
    return '-$delta pontos este mes, vamos ajustar as prioridades.';
  }

  @override
  String get profileCoachMonthlyTrendFlat =>
      'Pontuacao estavel este mes, mantem o ritmo.';

  @override
  String profileCoachMonthlyByokPrefix(String trend) {
    return 'Leitura coach IA: $trend';
  }

  @override
  String get profileCoachMonthlyActionComplete =>
      'Proximo passo: completar o diagnostico para tornar as recomendacoes mais fiaveis.';

  @override
  String get profileCoachMonthlyActionCheckin =>
      'Proximo passo: fazer o check-in mensal para recalibrar o plano.';

  @override
  String get profileCoachMonthlyActionAgir =>
      'Proximo passo: executar uma acao prioritaria no Agir.';

  @override
  String get profileGuidanceTitle => 'Secao recomendada';

  @override
  String profileGuidanceBody(String section) {
    return 'Completa agora $section para tornar o teu plano mais fiavel.';
  }

  @override
  String profileGuidanceCta(String section) {
    return 'Completar $section';
  }

  @override
  String get advisorMiniMetricsLiveTitle =>
      'Qualidade onboarding em tempo real';

  @override
  String get advisorMiniMetricsLiveStep => 'Passo atual';

  @override
  String get advisorMiniMetricsLiveQuality => 'Pontuacao de qualidade';

  @override
  String get advisorMiniMetricsLiveNext => 'Secao recomendada';

  @override
  String get coachPersonaPriorityCouple => 'Prioridade casal';

  @override
  String get coachPersonaPriorityFamily => 'Prioridade familia';

  @override
  String get coachPersonaPrioritySingleParent =>
      'Prioridade pai/mae solteiro(a)';

  @override
  String get coachPersonaPrioritySingle => 'Prioridade pessoal';

  @override
  String get coachWizardSectionIdentity => 'Identidade e agregado';

  @override
  String get coachWizardSectionIncome => 'Rendimento e agregado';

  @override
  String get coachWizardSectionPension => 'Previdencia';

  @override
  String get coachWizardSectionProperty => 'Imobiliario e divida';

  @override
  String coachPersonaGuidanceCouple(String section) {
    return 'Para tornar fiaveis as projecoes do agregado, completa agora $section.';
  }

  @override
  String coachPersonaGuidanceSingleParent(String section) {
    return 'O teu plano depende da protecao do agregado. Completa agora $section.';
  }

  @override
  String coachPersonaGuidanceSingle(String section) {
    return 'Para personalizar o teu plano coach, completa agora $section.';
  }

  @override
  String coachEnrichTargetTitle(String current, String target) {
    return 'Passar de $current% para $target% de precisao';
  }

  @override
  String get coachEnrichBodyIdentity =>
      'Adiciona bases de identidade/agregado para ativar calculos fiaveis desde hoje.';

  @override
  String get coachEnrichBodyIncome =>
      'Completa rendimento e estrutura do agregado para recomendacoes realmente personalizadas.';

  @override
  String get coachEnrichBodyPension =>
      'Adiciona AVS/LPP/3a para uma projecao de reforma acionavel.';

  @override
  String get coachEnrichBodyProperty =>
      'Adiciona imobiliario e dividas para calibrar orcamento e risco reais.';

  @override
  String get coachEnrichBodyDefault =>
      'O diagnostico completo demora 10 minutos e desbloqueia a tua trajetoria personalizada.';

  @override
  String get coachEnrichActionIdentity => 'Completar Identidade e agregado';

  @override
  String get coachEnrichActionIncome => 'Completar Rendimento e agregado';

  @override
  String get coachEnrichActionPension => 'Completar Previdencia';

  @override
  String get coachEnrichActionProperty => 'Completar Imobiliario e divida';

  @override
  String get coachEnrichActionDefault => 'Completar o meu diagnostico';

  @override
  String coachAgirPartialTitle(String quality) {
    return 'Plano em construcao ($quality%)';
  }

  @override
  String coachAgirPartialBody(String section) {
    return 'Para ativar as tuas acoes prioritarias, completa agora $section.';
  }

  @override
  String coachAgirPartialAction(String section) {
    return 'Completar $section';
  }

  @override
  String get landingTagline => 'O teu coach financeiro suíço';

  @override
  String get landingRegister => 'Registar';

  @override
  String get landingHeroRetirementNow1 => 'A tua reforma,';

  @override
  String get landingHeroRetirementNow2 => 'é agora.';

  @override
  String landingHeroCountdown1(String years) {
    return 'Em $years anos,';
  }

  @override
  String get landingHeroCountdown1Single => 'Em 1 ano,';

  @override
  String get landingHeroCountdown2 => 'começa a tua reforma.';

  @override
  String get landingHeroSubtitle =>
      'A maioria dos suíços descobre o seu défice de reforma demasiado tarde.';

  @override
  String get landingSliderAge => 'A tua idade';

  @override
  String landingSliderAgeSuffix(String age) {
    return '$age anos';
  }

  @override
  String get landingSliderSalary => 'O teu salário bruto';

  @override
  String landingSliderSalarySuffix(String amount) {
    return '$amount CHF/ano';
  }

  @override
  String get landingToday => 'Hoje';

  @override
  String get landingChfPerMonth => 'CHF/mês';

  @override
  String get landingAtRetirement => 'Na reforma*';

  @override
  String landingDropPurchasingPower(String percent) {
    return '-$percent% de poder de compra';
  }

  @override
  String landingLppCapNotice(String amount) {
    return 'Acima de $amount CHF/ano, a pensão obrigatória é limitada.';
  }

  @override
  String landingHookHigh(String amount) {
    return 'Um défice de $amount/mês é significativo. MINT ajuda-te a perceber onde agir.';
  }

  @override
  String get landingHookMedium =>
      'O teu défice é gerível. MINT mostra-te as alavancas concretas (resgate LPP, 3a, reforma antecipada).';

  @override
  String get landingHookLow =>
      'Estás em boa posição. MINT mostra-te como manter o rumo e otimizar os teus pilares.';

  @override
  String get landingWhyMint => 'Porquê MINT?';

  @override
  String get landingFeaturePillarsTitle =>
      'Todos os teus pilares, um só painel';

  @override
  String get landingFeaturePillarsSubtitle =>
      'AVS, LPP e 3a calculados para a tua situação real — não médias suíças.';

  @override
  String get landingFeatureCoachTitle => 'Coach adaptado à tua fase de vida';

  @override
  String get landingFeatureCoachSubtitle =>
      '25 ou 60 anos, fronteiriço ou independente — os conselhos mudam conforme quem és.';

  @override
  String get landingFeaturePrivacyTitle =>
      '100% privado, dados no teu dispositivo';

  @override
  String get landingFeaturePrivacySubtitle =>
      'Sem partilha, sem publicidade. O teu perfil fica local a menos que cries uma conta.';

  @override
  String get landingTrustSwiss => 'Feito na Suíça';

  @override
  String get landingTrustPrivate => '100% privado';

  @override
  String get landingTrustNoCommitment => 'Sem compromisso';

  @override
  String get landingCtaTitle => 'O teu plano em 30 segundos';

  @override
  String get landingCtaSubtitle => '3 perguntas • Grátis • Sem compromisso';

  @override
  String get landingLegalFooter =>
      '*Estimativa indicativa (1.° + 2.° pilar), baseada no salário atual como proxy de carreira. Não constitui aconselhamento financeiro nos termos da LSFin. Os teus dados ficam no teu dispositivo.';

  @override
  String get onboardingConsentTitle => 'Guardar respostas localmente';

  @override
  String get onboardingConsentBody =>
      'As tuas respostas podem ser guardadas localmente no teu dispositivo para retomar mais tarde. Nenhum dado é enviado sem o teu consentimento.';

  @override
  String get onboardingConsentAllow => 'Autorizar';

  @override
  String get onboardingConsentContinueWithout => 'Continuar sem guardar';

  @override
  String get profileBilanTitle => 'O meu resumo financeiro';

  @override
  String get profileBilanSubtitleComplete =>
      'Rendimentos, previdência, património, dívidas';

  @override
  String get profileBilanSubtitleIncomplete =>
      'Completa o teu perfil para ver os teus números';

  @override
  String get profileFamilyTitle => 'Família';

  @override
  String get profileHouseholdTitle => 'O nosso agregado';

  @override
  String get profileHouseholdStatus => 'Casal+';

  @override
  String get profileAiSlmTitle => 'IA on-device (SLM)';

  @override
  String get profileAiSlmReady => 'Modelo pronto';

  @override
  String get profileAiSlmNotInstalled => 'Modelo não instalado';

  @override
  String get profileLanguageTitle => 'Idioma';

  @override
  String get profileAdminObservability => 'Admin observability';

  @override
  String get profileAdminAnalytics => 'Analytics beta testers';

  @override
  String get profileDeleteCloudAccount => 'Eliminar a minha conta cloud';

  @override
  String get profileDeleteCloudTitle => 'Eliminar a conta?';

  @override
  String get profileDeleteCloudBody =>
      'Esta ação elimina a tua conta cloud e os dados associados. Os teus dados locais ficam neste dispositivo.';

  @override
  String get profileDeleteCloudConfirm => 'Eliminar';

  @override
  String get profileDeleteCloudSuccess => 'Conta eliminada com sucesso.';

  @override
  String get profileDeleteCloudError =>
      'Eliminação não possível de momento. Tenta novamente mais tarde.';

  @override
  String get dashboardDefaultUserName => 'Tu';

  @override
  String get dashboardDefaultConjointName => 'Parceiro/a';

  @override
  String get dashboardGoalRetirement => 'Reforma';

  @override
  String dashboardAppBarWithName(String firstName) {
    return 'Reforma · $firstName';
  }

  @override
  String get dashboardAppBarDefault => 'O meu painel';

  @override
  String get dashboardMyData => 'Os meus dados';

  @override
  String get dashboardQuickStartTitle =>
      'Descobre a tua projeção em 30 segundos';

  @override
  String get dashboardQuickStartBody =>
      '4 informações bastam para estimar o teu rendimento na reforma. Podes afinar com documentos e detalhes.';

  @override
  String get dashboardQuickStartCta => 'Começar';

  @override
  String get dashboardEnrichScanTitle => 'Digitaliza o teu certificado LPP';

  @override
  String get dashboardEnrichScanImpact => '+20 pts de precisão';

  @override
  String get dashboardEnrichCoachTitle => 'Fala com o Coach';

  @override
  String get dashboardEnrichCoachImpact => 'Responde às tuas dúvidas';

  @override
  String get dashboardEnrichSimTitle => 'Simula um cenário';

  @override
  String get dashboardEnrichSimImpact => '3a, LPP, hipoteca...';

  @override
  String get dashboardNextSteps => 'Próximos passos';

  @override
  String get dashboardEduTitle => 'O sistema de reforma suíço';

  @override
  String get dashboardEduAvs => '1.º pilar — AVS';

  @override
  String get dashboardEduAvsDesc =>
      'Base obrigatória para todos. Financiado pelas tuas contribuições (LAVS art. 21).';

  @override
  String get dashboardEduLpp => '2.º pilar — LPP';

  @override
  String get dashboardEduLppDesc =>
      'Previdência profissional através da tua caixa de pensões (LPP art. 14).';

  @override
  String get dashboardEdu3a => '3.º pilar — 3a';

  @override
  String get dashboardEdu3aDesc =>
      'Poupança voluntária com dedução fiscal (OPP3 art. 7).';

  @override
  String get dashboardDisclaimer =>
      'Ferramenta educativa simplificada. Não constitui aconselhamento financeiro (LSFin). Fontes: LAVS art. 21-29, LPP art. 14, OPP3 art. 7.';

  @override
  String get dashboardCockpitLink => 'Cockpit detalhado';

  @override
  String dashboardImpactEstimate(String amount) {
    return 'Impacto estimado: CHF $amount';
  }

  @override
  String get dashboardMetricMonthlyIncome => 'Rendimento mensal';

  @override
  String get dashboardMetricChfMonth => 'CHF/mês';

  @override
  String get dashboardMetricReplacementRate => 'Taxa de substituição';

  @override
  String get dashboardMetricRetirementDuration => 'Duração estimada da reforma';

  @override
  String get dashboardMetricYears => 'anos';

  @override
  String get dashboardMetricLifeExpectancy =>
      'Esperança de vida estimada: 85 anos';

  @override
  String get dashboardMetricMonthlyGap => 'Diferença mensal';

  @override
  String get dashboardMetricVsTarget => 'Vs objetivo 70% do salário bruto';

  @override
  String get dashboardNextActionLabel => 'Melhorar a tua precisão';

  @override
  String get dashboardNextActionDetail =>
      'Digitaliza o teu certificado LPP para afinar as tuas projeções.';

  @override
  String get dashboardWeatherSunny =>
      'Mercados favoráveis, poupança maximizada.';

  @override
  String get dashboardWeatherPartlyCloudy =>
      'Trajetória atual, alguns ajustes.';

  @override
  String get dashboardWeatherRainy => 'Choques de mercado ou lacunas AVS/LPP.';

  @override
  String get dashboardAgeBandYoungTitle => 'A tua alavanca principal: o 3a';

  @override
  String get dashboardAgeBandYoungSubtitle =>
      'Cada franco investido agora trabalha 40 anos. Abrir o teu 3a demora 15 minutos.';

  @override
  String get dashboardAgeBandYoungCta => 'Simular o meu 3a';

  @override
  String get dashboardAgeBandStabTitle => '3a + proteção familiar';

  @override
  String get dashboardAgeBandStabSubtitle =>
      'Habitação, cobertura morte/invalidez: agora é o momento de construir a arquitetura.';

  @override
  String get dashboardAgeBandStabCta => 'Ver simuladores';

  @override
  String get dashboardAgeBandPeakTitle => 'Recompra LPP + otimização fiscal';

  @override
  String get dashboardAgeBandPeakSubtitle =>
      'Os teus rendimentos estão no pico — é a janela para reduzir a diferença na reforma.';

  @override
  String get dashboardAgeBandPeakCta => 'Simular uma recompra';

  @override
  String get dashboardAgeBandPreRetTitle =>
      'A tua diferença de reforma em CHF/mês';

  @override
  String get dashboardAgeBandPreRetSubtitle =>
      'Renda vs capital, reforma antecipada, recompra escalonada: as decisões aproximam-se.';

  @override
  String get dashboardAgeBandPreRetCta => 'Renda vs Capital';

  @override
  String get dashboardAgeBandRetWithdrawTitle => 'Ordem de levantamento 3a';

  @override
  String get dashboardAgeBandRetWithdrawSubtitle =>
      'Escalonar os teus levantamentos 3a em 3–5 anos reduz significativamente o imposto conforme o cantão.';

  @override
  String get dashboardAgeBandRetWithdrawCta => 'Planear os meus levantamentos';

  @override
  String get dashboardAgeBandRetSuccessionTitle => 'Sucessão e transmissão';

  @override
  String get dashboardAgeBandRetSuccessionSubtitle =>
      'Testamento, doação em vida, beneficiários LPP: proteger quem amas.';

  @override
  String get dashboardAgeBandRetSuccessionCta => 'Explorar';

  @override
  String get agirResetTooltip => 'Reiniciar';

  @override
  String get agirResetHistoryLabel => 'Reiniciar o meu histórico do coach';

  @override
  String get agirResetDiagnosticLabel => 'Recomeçar o meu diagnóstico';

  @override
  String get agirResetHistoryTitle => 'Reiniciar o teu histórico do coach?';

  @override
  String get agirResetHistoryMessage =>
      'Isto elimina os teus check-ins, o histórico de pontuação e o progresso dos simuladores.';

  @override
  String get agirResetHistoryCta => 'Reiniciar';

  @override
  String get agirResetDiagnosticTitle => 'Recomeçar o teu diagnóstico?';

  @override
  String get agirResetDiagnosticMessage =>
      'Isto elimina o teu diagnóstico atual e as tuas respostas do mini-onboarding.';

  @override
  String get agirResetDiagnosticCta => 'Recomeçar';

  @override
  String get agirHistoryResetSnackbar => 'Histórico do coach reiniciado.';

  @override
  String get agirSwipeDone => 'Feito';

  @override
  String get agirSwipeSnooze => 'Adiar 30d';

  @override
  String agirSwipeDoneSnackbar(String title) {
    return '$title — marcado como feito';
  }

  @override
  String agirSwipeSnoozeSnackbar(String title) {
    return '$title — adiado 30 dias';
  }

  @override
  String get agirDependencyDebt => 'Depois: reembolso de dívida';

  @override
  String get agirEmptyTitle => 'O teu plano de ação espera-te';

  @override
  String get agirEmptyBody =>
      'Completa o teu diagnóstico para obteres um plano mensal personalizado baseado na tua situação real.';

  @override
  String get agirEmptyLaunchCta => 'Lançar o meu diagnóstico — 10 min';

  @override
  String get agirNoContribTitle => 'Nenhuma contribuição planeada';

  @override
  String get agirNoContribBody =>
      'Faz o teu primeiro check-in para configurar as tuas contribuições mensais.';

  @override
  String get agirNoContribCta => 'Configurar as minhas contribuições';

  @override
  String get agirProgressTitle => 'Progresso anual';

  @override
  String agirProgressSubtitle(String year) {
    return 'Planeado vs pago em $year';
  }

  @override
  String get agirConfirmLabel => 'A confirmar';

  @override
  String agirVersesLabel(String amount) {
    return '$amount pagos';
  }

  @override
  String agirObjectifLabel(String amount) {
    return 'Objetivo: $amount';
  }

  @override
  String get agirPriorityImmediate => 'Prioridade imediata';

  @override
  String get agirPriorityTrimestre => 'Este trimestre';

  @override
  String get agirPriorityAnnee => 'Este ano';

  @override
  String get agirPriorityLongTerme => 'Longo prazo';

  @override
  String get agirTimelineCheckinTitle => 'Check-in mensal';

  @override
  String get agirTimelineCheckinDone =>
      'Feito — contribuições confirmadas para este mês.';

  @override
  String get agirTimelineCheckinPending =>
      'Confirma as tuas contribuições do mês em 2 min.';

  @override
  String get agirTimelineCheckinCta => 'Fazer o meu check-in';

  @override
  String agirTimelineRetirementTitle(String name) {
    return 'Reforma $name (65 anos)';
  }

  @override
  String get agirTimelineThisMonth => 'Este mês';

  @override
  String agirTimelineInMonths(String months) {
    return 'em $months meses';
  }

  @override
  String agirTimelineInYears(String years) {
    return 'em $years anos';
  }

  @override
  String get agirTimelineInOneYear => 'em 1 ano';

  @override
  String get agirPerYear => '/ano';

  @override
  String get agirCoachPulseWhyDefault =>
      'Começa com uma ação simples para ativar a tua dinâmica.';

  @override
  String get checkinScoreTitle => 'A tua pontuação financeira';

  @override
  String checkinScorePositive(String delta) {
    return '+$delta pts — as tuas ações dão frutos!';
  }

  @override
  String checkinScoreNegative(String delta) {
    return '$delta pts — continua, cada mês conta';
  }

  @override
  String get budgetEmptyTitle => 'O teu orçamento constrói-se automaticamente';

  @override
  String get budgetEmptyBody =>
      'Completa o teu diagnóstico para desbloquear o teu plano mensal com os teus rendimentos e despesas reais.';

  @override
  String get budgetEmptyAction => 'Fazer o meu diagnóstico';

  @override
  String get budgetMonthlyTitle => 'Orçamento mensal';

  @override
  String get budgetAvailableThisMonth => 'Disponível este mês';

  @override
  String get budgetNetIncome => 'Rendimento líquido';

  @override
  String get budgetHousing => 'Habitação';

  @override
  String get budgetDebtRepayment => 'Pagamento de dívidas';

  @override
  String get budgetDebts => 'Dívidas';

  @override
  String get budgetTaxProvision => 'Provisão impostos';

  @override
  String get budgetHealthInsurance => 'Seguro saúde (LAMal)';

  @override
  String get budgetOtherFixed => 'Outras despesas fixas';

  @override
  String get budgetNotProvided => '(não indicado)';

  @override
  String get budgetQualityEstimated => 'estimado';

  @override
  String get budgetQualityEntered => 'inserido';

  @override
  String get budgetQualityMissing => 'em falta';

  @override
  String get budgetAvailable => 'Disponível';

  @override
  String get budgetMissingDataBanner =>
      'Algumas despesas ainda estão em falta. Completa o teu diagnóstico para tornar este orçamento mais fiável.';

  @override
  String get budgetEstimatedDataBanner =>
      'Este orçamento inclui estimativas (impostos/LAMal). Insere os teus montantes reais para uma projeção mais fiável.';

  @override
  String get budgetCompleteData => 'Completar os meus dados →';

  @override
  String get budgetEnvelopeFuture => '🔒 Futuro (Poupança, Projetos)';

  @override
  String get budgetEnvelopeVariables => '🛍️ Variáveis (Viver)';

  @override
  String get budgetNeeds => 'Necessidades';

  @override
  String get budgetLife => 'Vida';

  @override
  String get budgetFuture => 'Futuro';

  @override
  String get budgetVariables => 'Variáveis';

  @override
  String get budgetExampleRent => 'Renda';

  @override
  String get budgetExampleLamal => 'LAMal';

  @override
  String get budgetExampleTaxes => 'impostos';

  @override
  String get budgetExampleDebts => 'dívidas';

  @override
  String get budgetExampleFood => 'Alimentação';

  @override
  String get budgetExampleTransport => 'transporte';

  @override
  String get budgetExampleLeisure => 'lazer';

  @override
  String get budgetExampleSavings => 'Poupança';

  @override
  String get budgetExampleProjects => 'projetos';

  @override
  String budgetChiffreChoc503020(String monthly, String total) {
    return 'Poupando CHF $monthly/mês, acumulas CHF $total em 10 anos.';
  }

  @override
  String get budgetEmergencyFund => 'Fundo de emergência';

  @override
  String get budgetEmergencyGoalReached => 'Objetivo alcançado';

  @override
  String get budgetEmergencyOnTrack => 'No bom caminho';

  @override
  String get budgetEmergencyToReinforce => 'A reforçar';

  @override
  String budgetEmergencyMonthsCovered(String months) {
    return '$months meses cobertos';
  }

  @override
  String budgetEmergencyTarget(String target) {
    return 'Objetivo: $target meses';
  }

  @override
  String get budgetEmergencyComplete =>
      'Estás protegido contra imprevistos. Continua assim.';

  @override
  String budgetEmergencyIncomplete(String target) {
    return 'Poupa pelo menos $target meses de despesas para te protegeres contra imprevistos (perda de emprego, reparações...).';
  }

  @override
  String get budgetDisclaimerTitle => 'IMPORTANTE:';

  @override
  String get budgetDisclaimerEducational =>
      '• Esta é uma ferramenta educativa, não aconselhamento financeiro (LSFin).';

  @override
  String get budgetDisclaimerDeclarative =>
      '• Os montantes baseiam-se nas informações declaradas.';

  @override
  String get budgetDisclaimerFormula =>
      '• \'Disponível\' = Rendimentos - Habitação - Dívidas - Impostos - LAMal - Custos fixos.';

  @override
  String get toolsAllTools => 'Todas as ferramentas';

  @override
  String get toolsSearchHint => 'Procurar uma ferramenta...';

  @override
  String toolsToolCount(String count) {
    return '$count ferramentas';
  }

  @override
  String toolsCategoryCount(String count) {
    return '$count categorias';
  }

  @override
  String get toolsClear => 'Limpar';

  @override
  String get toolsNoResults => 'Nenhuma ferramenta encontrada';

  @override
  String get toolsNoResultsHint => 'Tenta com outras palavras-chave';

  @override
  String get toolsCatPrevoyance => 'Previdência';

  @override
  String get toolsRetirementPlanner => 'Planificador de reforma';

  @override
  String get toolsRetirementPlannerDesc =>
      'Simula a tua reforma AVS + LPP + 3a';

  @override
  String get toolsSimulator3a => 'Simulador 3a';

  @override
  String get toolsSimulator3aDesc => 'Calcula a tua poupança fiscal anual';

  @override
  String get toolsComparator3a => 'Comparador 3a';

  @override
  String get toolsComparator3aDesc => 'Compara provedores (banco vs seguro)';

  @override
  String get toolsRealReturn3a => 'Rendimento real 3a';

  @override
  String get toolsRealReturn3aDesc =>
      'Rendimento líquido após taxas e inflação';

  @override
  String get toolsStaggeredWithdrawal3a => 'Levantamento escalonado 3a';

  @override
  String get toolsStaggeredWithdrawal3aDesc =>
      'Otimiza o levantamento em vários anos';

  @override
  String get toolsRenteVsCapital => 'Renda vs Capital';

  @override
  String get toolsRenteVsCapitalDesc =>
      'Compara renda LPP e levantamento de capital';

  @override
  String get toolsRachatLpp => 'Recompra escalonada LPP';

  @override
  String get toolsRachatLppDesc =>
      'Otimiza as tuas recompras LPP em vários anos';

  @override
  String get toolsLibrePassage => 'Livre passagem';

  @override
  String get toolsLibrePassageDesc => 'Checklist mudança de emprego ou saída';

  @override
  String get toolsDisabilityGap => 'Rede de segurança';

  @override
  String get toolsDisabilityGapDesc =>
      'Simula a tua lacuna invalidez/falecimento';

  @override
  String get toolsGenderGap => 'Gender gap previdência';

  @override
  String get toolsGenderGapDesc => 'Impacto do tempo parcial na tua reforma';

  @override
  String get toolsCatFamily => 'Família';

  @override
  String get toolsMarriage => 'Casamento & fiscalidade';

  @override
  String get toolsMarriageDesc =>
      'Penalidade/bónus do casamento + regimes + sobrevivente';

  @override
  String get toolsBirth => 'Nascimento & família';

  @override
  String get toolsBirthDesc => 'Licença parental, abonos, impacto fiscal';

  @override
  String get toolsConcubinage => 'Casamento vs Concubinato';

  @override
  String get toolsConcubinageDesc => 'Comparador + checklist de proteção';

  @override
  String get toolsDivorce => 'Simulador divórcio';

  @override
  String get toolsDivorceDesc => 'Impacto financeiro do divórcio na LPP';

  @override
  String get toolsSuccession => 'Simulador sucessão';

  @override
  String get toolsSuccessionDesc => 'Calcula as quotas legais e impostos';

  @override
  String get toolsCatEmployment => 'Emprego';

  @override
  String get toolsFirstJob => 'Primeiro emprego';

  @override
  String get toolsFirstJobDesc =>
      'Compreende o teu recibo de vencimento e os teus direitos';

  @override
  String get toolsUnemployment => 'Simulador desemprego';

  @override
  String get toolsUnemploymentDesc => 'Calcula as tuas indemnizações e duração';

  @override
  String get toolsJobComparison => 'Comparador de emprego';

  @override
  String get toolsJobComparisonDesc =>
      'Compara duas ofertas (líquido + LPP + vantagens)';

  @override
  String get toolsSelfEmployed => 'Independente';

  @override
  String get toolsSelfEmployedDesc => 'Cobertura social e proteção';

  @override
  String get toolsAvsContributions => 'Contribuições AVS indep.';

  @override
  String get toolsAvsContributionsDesc =>
      'Calcula as tuas contribuições AVS/AI/APG';

  @override
  String get toolsIjm => 'Seguro IJM';

  @override
  String get toolsIjmDesc => 'Indemnização diária por doença';

  @override
  String get tools3aSelfEmployed => '3a independente';

  @override
  String get tools3aSelfEmployedDesc => 'Teto majorado para independentes';

  @override
  String get toolsDividendVsSalary => 'Dividendo vs Salário';

  @override
  String get toolsDividendVsSalaryDesc =>
      'Otimiza a tua remuneração em SA/Sàrl';

  @override
  String get toolsLppVoluntary => 'LPP voluntária';

  @override
  String get toolsLppVoluntaryDesc =>
      'Previdência facultativa para independentes';

  @override
  String get toolsCrossBorder => 'Fronteiriço';

  @override
  String get toolsCrossBorderDesc =>
      'Imposto na fonte, 90 dias, encargos sociais';

  @override
  String get toolsExpatriation => 'Expatriação';

  @override
  String get toolsExpatriationDesc => 'Forfait fiscal, partida, lacunas AVS';

  @override
  String get toolsCatRealEstate => 'Imobiliário';

  @override
  String get toolsAffordability => 'Capacidade de compra';

  @override
  String get toolsAffordabilityDesc =>
      'Calcula o preço máximo que podes comprar';

  @override
  String get toolsAmortization => 'Plano de amortização';

  @override
  String get toolsAmortizationDesc => 'Calendário de reembolso hipotecário';

  @override
  String get toolsSaronVsFixed => 'SARON vs Fixo';

  @override
  String get toolsSaronVsFixedDesc => 'Compara os tipos de hipoteca';

  @override
  String get toolsImputedRental => 'Valor locativo';

  @override
  String get toolsImputedRentalDesc => 'Estima o valor locativo imputado';

  @override
  String get toolsEplCombined => 'EPL combinado';

  @override
  String get toolsEplCombinedDesc =>
      'Levantamento antecipado LPP + 3a para habitação';

  @override
  String get toolsEplLpp => 'Levantamento EPL (LPP)';

  @override
  String get toolsEplLppDesc => 'Financiar habitação com o teu 2.° pilar';

  @override
  String get toolsCatTax => 'Fiscalidade';

  @override
  String get toolsFiscalComparator => 'Comparador fiscal';

  @override
  String get toolsFiscalComparatorDesc =>
      'Compara a tua carga fiscal entre cantões';

  @override
  String get toolsCompoundInterest => 'Juros compostos';

  @override
  String get toolsCompoundInterestDesc =>
      'Visualiza o crescimento das tuas poupanças';

  @override
  String get toolsCatHealth => 'Saúde';

  @override
  String get toolsLamalDeductible => 'Franquia LAMal';

  @override
  String get toolsLamalDeductibleDesc => 'Encontra a franquia ideal para ti';

  @override
  String get toolsCoverageCheckup => 'Check-up cobertura';

  @override
  String get toolsCoverageCheckupDesc => 'Avalia a tua proteção seguradora';

  @override
  String get toolsCatBudgetDebt => 'Orçamento & Dívidas';

  @override
  String get toolsBudget => 'Orçamento';

  @override
  String get toolsBudgetDesc =>
      'Planifica e acompanha as tuas despesas mensais';

  @override
  String get toolsDebtCheck => 'Check dívida';

  @override
  String get toolsDebtCheckDesc => 'Avalia o teu risco de sobreendividamento';

  @override
  String get toolsDebtRatio => 'Rácio de endividamento';

  @override
  String get toolsDebtRatioDesc => 'Diagnóstico visual da tua situação';

  @override
  String get toolsRepaymentPlan => 'Plano de reembolso';

  @override
  String get toolsRepaymentPlanDesc => 'Estratégia adaptada para reembolsar';

  @override
  String get toolsDebtHelp => 'Ajuda e recursos';

  @override
  String get toolsDebtHelpDesc => 'Contactos e organismos de apoio';

  @override
  String get toolsConsumerCredit => 'Crédito ao consumo';

  @override
  String get toolsConsumerCreditDesc => 'Simula o custo real de um crédito';

  @override
  String get toolsLeasing => 'Calculadora leasing';

  @override
  String get toolsLeasingDesc => 'Custo real e alternativas ao leasing';

  @override
  String get toolsCatBankDocs => 'Banco & Documentos';

  @override
  String get toolsOpenBanking => 'Open Banking';

  @override
  String get toolsOpenBankingDesc => 'Conecta as tuas contas bancárias';

  @override
  String get toolsBankImport => 'Importação bancária';

  @override
  String get toolsBankImportDesc => 'Importa os teus extratos CSV/PDF';

  @override
  String get toolsDocuments => 'Os meus documentos';

  @override
  String get toolsDocumentsDesc => 'Certificados LPP e documentos importantes';

  @override
  String get toolsPortfolio => 'Portfolio';

  @override
  String get toolsPortfolioDesc => 'Visão geral da tua situação';

  @override
  String get toolsTimeline => 'Timeline';

  @override
  String get toolsTimelineDesc => 'Os teus prazos e lembretes importantes';

  @override
  String get toolsConsent => 'Consentimentos';

  @override
  String get toolsConsentDesc => 'Gere as tuas autorizações de dados';

  @override
  String get vaultPremiumBadge => 'Premium';

  @override
  String get vaultExtractedFields => 'Campos extraídos';

  @override
  String get vaultCancelButton => 'Cancelar';

  @override
  String get vaultOkButton => 'OK';

  @override
  String get naissanceTitle => 'Nascimento e família';

  @override
  String get naissanceTabConge => 'Licença';

  @override
  String get naissanceTabAllocations => 'Abonos';

  @override
  String get naissanceTabImpact => 'Impacto';

  @override
  String get naissanceTabChecklist => 'Checklist';

  @override
  String get naissanceLeaveType => 'Tipo de licença';

  @override
  String get naissanceMother => 'Mãe';

  @override
  String get naissanceFather => 'Pai';

  @override
  String get naissanceMonthlySalary => 'Salário mensal bruto';

  @override
  String naissanceCongeLabel(String type) {
    return 'LICENÇA $type';
  }

  @override
  String naissanceWeeks(int count) {
    return '$count semanas';
  }

  @override
  String get naissanceApgPerDay => 'APG por dia';

  @override
  String get naissanceTotalApg => 'Total APG';

  @override
  String naissanceCappedAt(String amount) {
    return 'Limitado a CHF $amount/dia';
  }

  @override
  String get naissanceDailyDetail => 'DETALHE DIÁRIO';

  @override
  String get naissanceSalaryPerDay => 'Salário/dia';

  @override
  String get naissanceApgDay => 'APG/dia';

  @override
  String get naissanceDiffPerDay => 'Diferença/dia';

  @override
  String get naissanceNoLoss => 'Sem perda';

  @override
  String naissanceTotalLossEstimated(String amount) {
    return 'Perda total estimada durante a licença: $amount';
  }

  @override
  String naissanceChiffreChocText(String type, String amount, int weeks) {
    return 'A tua licença de $type representa $amount de APG em $weeks semanas';
  }

  @override
  String get naissanceMaternite => 'maternidade';

  @override
  String get naissancePaternite => 'paternidade';

  @override
  String get naissanceCongeEducational =>
      'A Suíça só introduziu a licença de paternidade em 2021. Com 2 semanas, continua a ser uma das mais curtas da Europa. A licença de maternidade (14 semanas) existe desde 2005.';

  @override
  String get naissanceCanton => 'Cantão';

  @override
  String get naissanceNbEnfants => 'Número de filhos';

  @override
  String get naissanceRanking26 => 'CLASSIFICAÇÃO 26 CANTÕES';

  @override
  String naissanceBestCanton(String canton) {
    return '$canton oferece um dos abonos de família mais vantajosos da Suíça!';
  }

  @override
  String naissanceAllocDiff(String bestCanton, String canton, String amount) {
    return 'Morando em $bestCanton em vez de $canton, receberias $amount a mais por ano em abonos de família.';
  }

  @override
  String get naissanceRevenuAnnuel => 'Rendimento anual bruto';

  @override
  String get naissanceFraisGarde => 'Custos de guarda mensal/criança';

  @override
  String get naissanceTaxSavings => 'Poupanças fiscais';

  @override
  String get naissanceDeductionPerChild => 'Dedução por filho';

  @override
  String get naissanceDeductionChildcare => 'Dedução custos de guarda';

  @override
  String get naissanceEstimatedTaxSaving => 'Poupança fiscal estimada';

  @override
  String get naissanceAllowanceIncome => 'Rendimento de abonos';

  @override
  String get naissanceAnnualAllowances => 'Abonos anuais';

  @override
  String get naissanceCareerImpact => 'Impacto na carreira (LPP)';

  @override
  String get naissanceEstimatedInterruption => 'Interrupção estimada';

  @override
  String naissanceMonths(int count) {
    return '$count meses';
  }

  @override
  String get naissanceLppLossEstimated => 'Perda LPP estimada';

  @override
  String get naissanceLppLessContributions =>
      'Menos contribuições LPP = menos capital na reforma';

  @override
  String get naissanceNetAnnualImpact => 'Impacto líquido anual estimado';

  @override
  String get naissanceNetFormula =>
      'Poupanças fiscais + abonos - custo estimado';

  @override
  String get naissanceWaterfallRevenu => 'Rendimento bruto anual';

  @override
  String get naissanceWaterfallAlloc => 'Abonos de família';

  @override
  String get naissanceWaterfallCosts => 'Custos base (est.)';

  @override
  String get naissanceWaterfallChildcare => 'Custos de guarda anuais';

  @override
  String get naissanceWaterfallAfter => 'Após filho(s)';

  @override
  String get naissanceChildCostEducational =>
      'Um filho custa em média CHF 1\'500/mês na Suíça (alimentação, roupa, atividades, seguro). Mas os abonos e deduções fiscais reduzem significativamente o impacto líquido.';

  @override
  String get naissanceChecklistIntro =>
      'A chegada de um filho implica muitos passos administrativos e financeiros. Aqui estão os passos a não esquecer.';

  @override
  String naissanceStepsCompleted(int done, int total) {
    return '$done/$total passos concluídos';
  }

  @override
  String get naissanceDidYouKnow => 'Sabias que?';

  @override
  String get naissanceDisclaimer =>
      'Estimativas simplificadas para fins educativos — não constitui aconselhamento de previdência ou fiscal. Os montantes dependem de muitos fatores (cantão, município, situação familiar, etc.). Consulta um·a especialista para um cálculo personalizado.';

  @override
  String get mariageTitle => 'Casamento e fiscalidade';

  @override
  String get mariageTabImpots => 'Impostos';

  @override
  String get mariageTabRegime => 'Regime';

  @override
  String get mariageTabProtection => 'Proteção';

  @override
  String get mariageRevenu1 => 'Rendimento 1';

  @override
  String get mariageRevenu2 => 'Rendimento 2';

  @override
  String get mariageCanton => 'Cantão';

  @override
  String get mariageEnfants => 'Filhos';

  @override
  String get mariageFiscalComparison => 'COMPARAÇÃO FISCAL';

  @override
  String get mariageTwoCelibataires => '2 solteiros';

  @override
  String get mariageMaries => 'Casados';

  @override
  String mariagePenaltyAmount(String amount) {
    return 'Penalização +$amount/ano';
  }

  @override
  String mariageBonusAmount(String amount) {
    return 'Bónus -$amount/ano';
  }

  @override
  String get mariageDeductions => 'DEDUÇÕES CASAMENTO';

  @override
  String get mariageDeductionCouple => 'Dedução casal casado';

  @override
  String get mariageDeductionInsurance => 'Dedução seguro (casada)';

  @override
  String get mariageDeductionDualIncome => 'Dedução rendimento duplo';

  @override
  String get mariageDeductionChildren => 'Dedução filhos';

  @override
  String get mariageTotalDeductions => 'Total deduções';

  @override
  String get mariageEducationalPenalty =>
      'Sabias que a penalização do casamento afeta ~700\'000 casais na Suíça? O Tribunal Federal considerou esta situação inconstitucional em 1984, mas ainda não foi corrigida.';

  @override
  String get mariageRegimeMatrimonial => 'REGIME MATRIMONIAL';

  @override
  String get mariageParticipation => 'Participação nos adquiridos';

  @override
  String get mariageParticipationSub => 'Regime por defeito (CC art. 181)';

  @override
  String get mariageParticipationDesc =>
      'Cada um mantém os seus bens próprios. Os adquiridos (ganhos durante o casamento) são divididos 50/50 em caso de dissolução.';

  @override
  String get mariageSeparation => 'Separação de bens';

  @override
  String get mariageSeparationSub => 'CC art. 247';

  @override
  String get mariageSeparationDesc =>
      'Cada um mantém a totalidade dos seus bens e rendimentos. Sem partilha automática.';

  @override
  String get mariageCommunaute => 'Comunhão de bens';

  @override
  String get mariageCommunauteSub => 'CC art. 221';

  @override
  String get mariageCommunauteDesc =>
      'Tudo é partilhado: bens próprios e adquiridos. Partilha igualitária total em caso de dissolução.';

  @override
  String get mariagePatrimoine1 => 'Património Pessoa 1';

  @override
  String get mariagePatrimoine2 => 'Património Pessoa 2';

  @override
  String get mariageChiffreChocDefault =>
      'No regime por defeito, esta parte dos teus adquiridos passaria para o teu cônjuge em caso de dissolução';

  @override
  String get mariageChiffreChocCommunaute =>
      'Em comunhão de bens, este montante seria partilhado com o teu cônjuge';

  @override
  String get mariageProtectionIntro =>
      'O que acontece se um de vocês morrer? Compara a proteção legal entre casados e concubinos.';

  @override
  String get mariageLppRenteLabel => 'Renda LPP mensal do falecido';

  @override
  String get mariageAvsSurvivor => 'Renda AVS de sobrevivente';

  @override
  String get mariageAvsSurvivorSub => '80% da renda máxima do falecido';

  @override
  String get mariageAvsSurvivorFootnote => 'LAVS art. 35 — apenas para casados';

  @override
  String get mariageLppSurvivor => 'Renda LPP de sobrevivente';

  @override
  String get mariageLppSurvivorSub => '60% da renda segurada do falecido';

  @override
  String get mariageLppSurvivorFootnote =>
      'LPP art. 19 — casados (concubinos: cláusula necessária)';

  @override
  String get mariageSurvivorMonthly =>
      'Rendimento mensal do sobrevivente casado';

  @override
  String get mariageVsConcubin => 'CASADO VS CONCUBINO';

  @override
  String get mariageRenteAvsSurvivor => 'Renda AVS sobrevivente';

  @override
  String get mariageRenteLppSurvivor => 'Renda LPP sobrevivente';

  @override
  String get mariageHeritageExonere => 'Herança isenta';

  @override
  String get mariagePensionAlimentaire => 'Pensão alimentar';

  @override
  String get mariageConcubinWarning =>
      'Em concubinato, o parceiro sobrevivente não tem direitos por defeito — nem renda AVS, nem herança isenta. Tudo deve ser previsto por contrato.';

  @override
  String get mariageProtectionsEssentielles => 'PROTEÇÕES ESSENCIAIS';

  @override
  String get mariageChecklistIntro =>
      'O casamento tem consequências financeiras e jurídicas. Aqui estão os passos essenciais a antecipar para te preparares bem.';

  @override
  String get mariageDisclaimer =>
      'Estimativas simplificadas para fins educativos — não constitui aconselhamento fiscal ou jurídico. Os montantes dependem de muitos fatores (deduções, município, património, etc.). Consulta um·a especialista fiscal para um cálculo personalizado.';

  @override
  String get divorceAppBarTitle => 'Divórcio — Impacto financeiro';

  @override
  String get divorceHeaderTitle => 'Impacto financeiro de um divórcio';

  @override
  String get divorceHeaderSubtitle => 'Antecipa as consequências financeiras';

  @override
  String get divorceIntroText =>
      'Um divórcio tem consequências financeiras muitas vezes subestimadas: partilha do património, da previdência (LPP/3a), impacto fiscal e pensão alimentar. Esta ferramenta ajuda-te a ver com mais clareza.';

  @override
  String divorceYears(int count) {
    return '$count anos';
  }

  @override
  String get divorceNbEnfants => 'Número de filhos';

  @override
  String get divorceParticipationDefault =>
      'Participação nos adquiridos (defeito)';

  @override
  String get divorceCommunaute => 'Comunhão de bens';

  @override
  String get divorceSeparation => 'Separação de bens';

  @override
  String get divorceFortune => 'Fortuna comum';

  @override
  String get divorceDettes => 'Dívidas comuns';

  @override
  String get divorcePensionDescription =>
      'Estimativa baseada na diferença de rendimentos e no número de filhos. O montante real depende de muitos fatores (guarda, necessidades, nível de vida).';

  @override
  String get divorceActionsTitle => 'Ações a tomar';

  @override
  String get divorceComprendre => 'COMPREENDER';

  @override
  String get divorceEduParticipationTitle =>
      'O que é a participação nos adquiridos?';

  @override
  String get divorceEduParticipationContent =>
      'A participação nos adquiridos é o regime matrimonial por defeito na Suíça (CC art. 181 ss). Cada cônjuge mantém os seus bens próprios (adquiridos antes do casamento ou por sucessão/doação). Os adquiridos (bens adquiridos durante o casamento) são partilhados em partes iguais em caso de divórcio. É o regime mais comum na Suíça.';

  @override
  String get divorceEduLppTitle => 'Como funciona a partilha LPP?';

  @override
  String get divorceEduLppContent =>
      'Desde 1 de janeiro de 2017 (CC art. 122), os haveres de previdência profissional (2° pilar) acumulados durante o casamento são partilhados em partes iguais em caso de divórcio. A partilha é feita diretamente entre as duas caixas de pensões, sem passar pelas contas pessoais dos cônjuges. É um direito imperativo ao qual os cônjuges só podem renunciar sob condições estritas.';

  @override
  String get successionAppBarTitle => 'Sucessão — Planeamento';

  @override
  String get successionHeaderTitle => 'Planear a minha sucessão';

  @override
  String get successionHeaderSubtitle => 'Novo direito sucessório 2023';

  @override
  String get successionIntroText =>
      'O novo direito sucessório (2023) alargou a quota disponível. Agora tens mais liberdade para favorecer certos herdeiros. Esta ferramenta mostra-te a distribuição legal e o impacto de um testamento.';

  @override
  String get donationAppBarTitle => 'Doação — Simulador';

  @override
  String get donationHeaderTitle => 'Simular uma doação';

  @override
  String get donationHeaderSubtitle =>
      'Fiscalidade, reserva hereditária, impacto';

  @override
  String get housingSaleAppBarTitle => 'Venda imobiliária';

  @override
  String get housingSaleHeaderTitle => 'Simula a tua venda imobiliária';

  @override
  String get housingSaleHeaderSubtitle =>
      'Imposto sobre mais-valias, EPL, produto líquido';

  @override
  String get housingSaleCalculer => 'Calcular';

  @override
  String get lifeEventComprendre => 'COMPREENDER';

  @override
  String get lifeEventPointsAttention => 'PONTOS DE ATENÇÃO';

  @override
  String get lifeEventActionsTitle => 'Ações a tomar';

  @override
  String get lifeEventChecklistSubtitle => 'Checklist de preparação';

  @override
  String get lifeEventDidYouKnow => 'Sabias que?';

  @override
  String get unemploymentTitle => 'Perda de emprego';

  @override
  String get unemploymentHeaderDesc =>
      'Estima os teus direitos ao desemprego (LACI). O cálculo depende do teu salário segurado, da tua idade e do período de contribuição nos últimos 2 anos.';

  @override
  String get unemploymentGainSliderTitle => 'Rendimento segurado mensal';

  @override
  String get unemploymentAgeSliderTitle => 'A tua idade';

  @override
  String unemploymentAgeValue(int age) {
    return '$age anos';
  }

  @override
  String get unemploymentAgeMin => '18 anos';

  @override
  String get unemploymentAgeMax => '65 anos';

  @override
  String get unemploymentContribTitle =>
      'Meses de contribuição (últimos 2 anos)';

  @override
  String unemploymentContribValue(int months) {
    return '$months meses';
  }

  @override
  String get unemploymentContribMax => '24 meses';

  @override
  String get unemploymentSituationTitle => 'Situação pessoal';

  @override
  String get unemploymentSituationSubtitle =>
      'Influencia a taxa de indemnização (70% ou 80%)';

  @override
  String get unemploymentChildrenToggle => 'Obrigação de alimentos (filhos)';

  @override
  String get unemploymentDisabilityToggle => 'Deficiência reconhecida';

  @override
  String get unemploymentNotEligible => 'Não elegível';

  @override
  String get unemploymentCompensationRate => 'Taxa de indemnização';

  @override
  String get unemploymentRateEnhanced =>
      'Taxa majorada (80%): obrigação de alimentos, deficiência ou salário < CHF 3\'797';

  @override
  String get unemploymentRateStandard =>
      'Taxa padrão (70%): aplicável nas outras situações';

  @override
  String get unemploymentDailyBenefit => 'Indemnização /dia';

  @override
  String get unemploymentMonthlyBenefit => 'Indemnização /mês';

  @override
  String get unemploymentInsuredEarnings => 'Rendimento segurado retido';

  @override
  String get unemploymentWaitingPeriod => 'Período de carência';

  @override
  String unemploymentWaitingDays(int days) {
    return '$days dias';
  }

  @override
  String get unemploymentDurationHeader => 'DURAÇÃO DAS PRESTAÇÕES';

  @override
  String get unemploymentDailyBenefits => 'indemnizações diárias';

  @override
  String get unemploymentCoverageMonths => 'meses de cobertura';

  @override
  String get unemploymentYouTag => 'TU';

  @override
  String get unemploymentChecklistHeader => 'CHECKLIST';

  @override
  String get unemploymentCheckItem1 =>
      'Inscrever-se no ORP desde o 1.º dia sem emprego';

  @override
  String get unemploymentCheckItem2 =>
      'Depositar o dossier na caixa de desemprego';

  @override
  String get unemploymentCheckItem3 => 'Adaptar o orçamento ao novo rendimento';

  @override
  String get unemploymentCheckItem4 =>
      'Transferir o capital LPP para uma conta de livre passagem';

  @override
  String get unemploymentCheckItem5 =>
      'Verificar os direitos a uma redução de prémio LAMal';

  @override
  String get unemploymentCheckItem6 =>
      'Atualizar o orçamento MINT com o novo rendimento';

  @override
  String get unemploymentGoodToKnow => 'BOM SABER';

  @override
  String get unemploymentEduFastTitle => 'Inscrição rápida';

  @override
  String get unemploymentEduFastBody =>
      'Inscreve-te no ORP o mais cedo possível. Cada dia de atraso pode resultar numa suspensão das tuas indemnizações.';

  @override
  String get unemploymentEdu3aTitle => '3.º pilar em pausa';

  @override
  String get unemploymentEdu3aBody =>
      'Sem rendimento de trabalho, já não podes contribuir para o 3a. As indemnizações de desemprego não são consideradas rendimento de trabalho para efeitos do 3.º pilar.';

  @override
  String get unemploymentEduLppTitle => 'LPP e desemprego';

  @override
  String get unemploymentEduLppBody =>
      'Durante o desemprego, apenas os riscos de morte e invalidez são cobertos pelo LPP. A poupança para a reforma para. Transfere o teu capital para uma conta de livre passagem.';

  @override
  String get unemploymentEduLamalTitle => 'Redução de prémio LAMal';

  @override
  String get unemploymentEduLamalBody =>
      'Com um rendimento mais baixo, podes ter direito a subsídios LAMal. Faz o pedido junto do teu cantão.';

  @override
  String get unemploymentTsunamiTitle => 'O teu tsunami financeiro em 3 ondas';

  @override
  String get unemploymentDisclaimer =>
      'Estimativas educativas — não constitui aconselhamento nos termos da LSFin — LACI/LPP/OPP3. Os montantes apresentados são aproximados e dependem da tua situação pessoal. Consulta um·a especialista ou o ORP do teu cantão.';

  @override
  String get firstJobTitle => 'Primeiro emprego';

  @override
  String get firstJobHeaderDesc =>
      'Compreende o teu recibo de salário! Mostramos-te para onde vão as tuas contribuições, o que o teu empregador paga a mais e os primeiros reflexos financeiros a adotar.';

  @override
  String get firstJobSalaryTitle => 'Salário bruto mensal';

  @override
  String get firstJobActivityRate => 'Taxa de atividade';

  @override
  String get firstJob3aHeader => 'PILAR 3A — ABRIR AGORA';

  @override
  String get firstJob3aAnnualCap => 'Teto anual';

  @override
  String get firstJob3aMonthlySuggestion => 'Sugestão /mês';

  @override
  String get firstJob3aWarningTitle => 'ATENÇÃO — SEGURO DE VIDA 3A';

  @override
  String get firstJobLamalHeader => 'COMPARAÇÃO FRANQUIAS LAMAL';

  @override
  String get firstJobChecklistHeader => 'PRIMEIROS REFLEXOS';

  @override
  String get firstJobEduLppTitle => 'LPP a partir dos 25 anos';

  @override
  String get firstJobEduLppBody =>
      'A contribuição LPP (2.º pilar) começa aos 25 anos para a poupança reforma. Antes dos 25 anos, apenas os riscos de morte e invalidez são cobertos.';

  @override
  String get firstJobEdu13Title => '13.º salário';

  @override
  String get firstJobEdu13Body =>
      'Se o teu contrato prevê um 13.º salário, este também está sujeito às deduções sociais. O teu salário mensal bruto é então o salário anual dividido por 13.';

  @override
  String get firstJobEduBudgetTitle => 'Regra do 50/30/20';

  @override
  String get firstJobEduBudgetBody =>
      'Um bom reflexo para o teu primeiro salário: 50% para despesas fixas, 30% para lazer, 20% para poupança e previdência (3a incluído).';

  @override
  String get firstJobEduTaxTitle => 'Declaração fiscal';

  @override
  String get firstJobEduTaxBody =>
      'Desde o teu primeiro emprego, terás de preencher uma declaração fiscal. Guarda todas as tuas certificações (salário, 3a, despesas profissionais).';

  @override
  String get firstJobAnalysisHeader => 'Análise MINT — O filme do teu salário';

  @override
  String get firstJobProfileBadge => 'O teu perfil';

  @override
  String get firstJobIllustrativeBadge => 'Ilustrativo';

  @override
  String get firstJobDisclaimer =>
      'Estimativas educativas — não constitui aconselhamento — LACI/LPP/OPP3. Os montantes são aproximados e não consideram todas as especificidades cantonais. Consulta priminfo.admin.ch para os prémios LAMal exatos. Consulta um·a especialista em previdência.';

  @override
  String get independantAppBarTitle => 'PERCURSO INDEPENDENTE';

  @override
  String get independantTitle => 'Independente';

  @override
  String get independantSubtitle => 'Análise de cobertura e proteção';

  @override
  String get independantIntroDesc =>
      'Como independente, não tens LPP obrigatório, nem IJM, nem LAA. A tua proteção social depende inteiramente das tuas diligências pessoais. Identifica as tuas lacunas.';

  @override
  String get independantRevenueTitle => 'Rendimento líquido anual';

  @override
  String independantAgeLabel(int age) {
    return 'Idade: $age anos';
  }

  @override
  String get independantCoverageTitle => 'A minha cobertura atual';

  @override
  String get independantToggleLpp => 'LPP (afiliação voluntária)';

  @override
  String get independantToggleIjm => 'IJM (indemnização diária de doença)';

  @override
  String get independantToggleLaa => 'LAA (seguro de acidentes)';

  @override
  String get independantToggle3a => '3.º pilar (3a)';

  @override
  String get independantCoverageAnalysis => 'ANÁLISE DE COBERTURA';

  @override
  String get independantProtectionCostTitle =>
      'Custo da minha proteção completa';

  @override
  String get independantProtectionCostSubtitle => 'Estimativa mensal';

  @override
  String get independantTotalMonthly => 'Total mensal';

  @override
  String get independantAvsTitle => 'Contribuição AVS independente';

  @override
  String get independant3aTitle => '3.º pilar — teto independente';

  @override
  String get independantRecommendationsHeader => 'RECOMENDAÇÕES';

  @override
  String get independantAnalysisHeader =>
      'Análise MINT — O teu kit de independente';

  @override
  String get independantSourcesTitle => 'Fontes';

  @override
  String get independantSourcesBody =>
      'LPP art. 4 (sem obrigação para independentes) / LPP art. 44 (afiliação voluntária) / OPP3 art. 7 (3a grande: 20% do rendimento líquido, máx. 36\'288) / LAVS art. 8 (contribuições independentes) / LAA art. 4 / LAMal';

  @override
  String get independantDisclaimer =>
      'Os montantes apresentados são estimativas indicativas. As contribuições reais dependem da tua situação pessoal e das ofertas de seguros disponíveis. Consulta um fiduciário ou segurador antes de qualquer decisão.';

  @override
  String get jobCompareAgeTitle => 'A tua idade';

  @override
  String get jobCompareAgeSubtitle =>
      'Utilizado para projetar o capital de reforma';

  @override
  String get jobCompareSalaryLabel => 'Salário bruto anual';

  @override
  String get jobCompareEmployerShare => 'Parte empregador LPP';

  @override
  String get jobCompareConversionRate => 'Taxa de conversão';

  @override
  String get jobCompareRetirementAssets => 'Capital de velhice atual';

  @override
  String get jobCompareDisabilityCoverage => 'Cobertura de invalidez';

  @override
  String get jobCompareDeathCapital => 'Capital por morte';

  @override
  String get jobCompareMaxBuyback => 'Resgate máximo';

  @override
  String get jobCompareVerdictLabel => 'VEREDITO';

  @override
  String get jobCompareDetailedTitle => 'Comparação detalhada';

  @override
  String get jobCompareRetirementImpact => 'IMPACTO EM TODA A REFORMA';

  @override
  String get jobCompareAttentionPoints => 'PONTOS DE ATENÇÃO';

  @override
  String get jobCompareChecklistTitle => 'Antes de assinar';

  @override
  String get jobCompareUnderstandHeader => 'COMPREENDER';

  @override
  String get jobCompareEduInvisibleTitle => 'O que é o salário invisível?';

  @override
  String get jobCompareEduInvisibleBody =>
      'O \"salário invisível\" representa 10-30% da tua remuneração total. Inclui a parte do empregador para o fundo de pensões (LPP), seguros (IJM, acidente) e por vezes vantagens complementares. Dois postos com o mesmo salário bruto podem oferecer proteções muito diferentes.';

  @override
  String get jobCompareEduCertTitle =>
      'Como ler o meu certificado de previdência?';

  @override
  String get jobCompareEduCertBody =>
      'O teu certificado de previdência (LPP) contém todas as informações necessárias: salário segurado, dedução de coordenação, taxa de contribuição, capital de velhice, taxa de conversão, prestações de risco (invalidez e morte) e possível resgate. Pede-o ao teu RH ou fundo de pensões.';

  @override
  String get jobCompareAxisLabel => 'Eixo';

  @override
  String get jobCompareCurrentLabel => 'Atual';

  @override
  String get jobCompareNewLabel => 'Novo';

  @override
  String get disabilityGapParamsTitle => 'Os teus parâmetros';

  @override
  String get disabilityGapParamsSubtitle => 'Ajusta à tua situação';

  @override
  String get disabilityGapIncomeLabel => 'Rendimento mensal líquido';

  @override
  String get disabilityGapCantonLabel => 'Cantão';

  @override
  String get disabilityGapStatusLabel => 'Estatuto profissional';

  @override
  String get disabilityGapEmployee => 'Assalariado';

  @override
  String get disabilityGapSelfEmployed => 'Indep.';

  @override
  String get disabilityGapSeniorityLabel => 'Anos de antiguidade';

  @override
  String get disabilityGapIjmLabel => 'IJM coletiva através do meu empregador';

  @override
  String get disabilityGapDegreeLabel => 'Grau de invalidez';

  @override
  String get disabilityGapChartTitle => 'Evolução da tua cobertura';

  @override
  String get disabilityGapChartSubtitle => 'As 3 fases de proteção';

  @override
  String get disabilityGapCurrentIncome => 'Rendimento atual';

  @override
  String get disabilityGapMaxGap => 'GAP MENSAL MÁXIMO';

  @override
  String get disabilityGapPhaseDetail => 'DETALHE DAS FASES';

  @override
  String get disabilityGapPhase1Title => 'Fase 1: Empregador';

  @override
  String get disabilityGapPhase2Title => 'Fase 2: IJM';

  @override
  String get disabilityGapPhase3Title => 'Fase 3: AI + LPP';

  @override
  String get disabilityGapDurationLabel => 'Duração:';

  @override
  String get disabilityGapCoverageLabel => 'Cobertura:';

  @override
  String get disabilityGapLegalLabel => 'Fonte legal:';

  @override
  String get disabilityGapIfYouAre => 'SE ÉS...';

  @override
  String get disabilityGapEduTitle => 'COMPREENDER';

  @override
  String get disabilityGapEduIjmTitle => 'IJM vs AI: qual a diferença?';

  @override
  String get disabilityGapEduIjmBody =>
      'A IJM (indemnização diária de doença) é um seguro que cobre 80% do teu salário durante máx. 720 dias em caso de doença. O empregador não é obrigado a subscrevê-la, mas muitos fazem-no através de um seguro coletivo. Sem IJM, após o período legal de manutenção do salário, não recebes mais nada até à eventual renda AI.';

  @override
  String get disabilityGapEduCoTitle =>
      'A obrigação do teu empregador (CO art. 324a)';

  @override
  String get disabilityGapEduCoBody =>
      'Segundo o art. 324a CO, o empregador deve pagar o salário durante um período limitado em caso de doença. Esta duração depende dos anos de serviço e da escala cantonal aplicável (bernesa, zuriquesa ou basileia). Após este período, apenas a IJM (se existente) toma o lugar.';

  @override
  String get successionIntroDesc =>
      'O novo direito sucessório (2023) alargou a quota disponível. Agora tens mais liberdade para favorecer certos herdeiros. Esta ferramenta mostra-te a distribuição legal e o impacto de um testamento.';

  @override
  String get successionSimulateButton => 'Simular';

  @override
  String get successionLegalDistribution => 'DISTRIBUIÇÃO LEGAL';

  @override
  String get successionTestamentDistribution => 'DISTRIBUIÇÃO COM TESTAMENTO';

  @override
  String get successionReservesTitle => 'Reservas hereditárias';

  @override
  String get successionReservesSubtitle => 'CC art. 470–471';

  @override
  String get successionQuotiteTitle => 'Porção disponível';

  @override
  String get successionQuotiteDesc =>
      'Este montante pode ser livremente atribuído por testamento à pessoa da tua escolha.';

  @override
  String get successionBeneficiaries3aTitle => 'BENEFICIÁRIOS 3a (OPP3 ART. 2)';

  @override
  String get successionBeneficiaries3aDesc =>
      'O 3.º pilar NÃO segue o teu testamento. A ordem de beneficiários é fixada por lei:';

  @override
  String get successionChecklistTitle => 'Checklist proteção patrimonial';

  @override
  String get successionTotalTax => 'Total imposto sucessório';

  @override
  String get successionTestamentSwitch => 'Tenho um testamento';

  @override
  String get successionBeneficiaryQuestion => 'Quem recebe a quota disponível?';

  @override
  String get successionCivilStatusLabel => 'Estado civil';

  @override
  String get successionFortuneLabel => 'Fortuna total';

  @override
  String get successionAvoirs3aLabel => 'Haveres 3a';

  @override
  String get successionDeathCapitalLabel => 'Capital de morte LPP';

  @override
  String get successionChildrenLabel => 'Número de filhos';

  @override
  String get successionParentsAlive => 'Pais vivos';

  @override
  String get successionSiblings => 'Irmãos (irmãos/irmãs)';

  @override
  String get mariageProtectionItem1 =>
      'Redigir um testamento (cláusula de usufruto)';

  @override
  String get mariageProtectionItem2 =>
      'Cláusula de beneficiário LPP (perguntar ao fundo de pensão)';

  @override
  String get mariageProtectionItem3 =>
      'Seguro de vida cruzado (proteção do parceiro)';

  @override
  String get mariageProtectionItem4 => 'Mandato por incapacidade';

  @override
  String get mariageProtectionItem5 => 'Diretivas antecipadas do paciente';

  @override
  String get mariageChecklistItem1Title =>
      'Simular o impacto fiscal do casamento';

  @override
  String get mariageChecklistItem1Desc =>
      'Antes de casar, compare a carga fiscal a dois (casados vs solteiros). Se os rendimentos são semelhantes e altos, a penalização do casamento pode representar vários milhares de francos por ano.';

  @override
  String get mariageChecklistItem2Title => 'Escolher o regime matrimonial';

  @override
  String get mariageChecklistItem2Desc =>
      'Por defeito, é a participação nos adquiridos (CC art. 181). Para outro regime (separação de bens, comunhão de bens), é preciso assinar um contrato de casamento no notário ANTES ou durante o casamento.';

  @override
  String get mariageChecklistItem3Title =>
      'Atualizar as cláusulas de beneficiários LPP e 3a';

  @override
  String get mariageChecklistItem3Desc =>
      'O casamento muda a ordem dos beneficiários. O cônjuge torna-se automaticamente beneficiário da pensão de sobrevivência LPP (LPP art. 19). Verifica também os beneficiários do 3.º pilar.';

  @override
  String get mariageChecklistItem4Title =>
      'Informar o empregador e o seguro de saúde';

  @override
  String get mariageChecklistItem4Desc =>
      'O empregador deve atualizar os dados (estado civil, deduções). O seguro de saúde deve ser informado — os prémios não mudam, mas os subsídios são recalculados com base no rendimento do agregado.';

  @override
  String get mariageChecklistItem5Title =>
      'Preparar a primeira declaração conjunta';

  @override
  String get mariageChecklistItem5Desc =>
      'A partir do ano do casamento, faz-se uma única declaração fiscal conjunta. Reúne os comprovativos de ambos (certificados de salário, 3a, LPP, etc.). A mudança para declaração conjunta pode alterar o escalão de imposto.';

  @override
  String get mariageChecklistItem6Title => 'Verificar as rendas AVS de casal';

  @override
  String get mariageChecklistItem6Desc =>
      'A renda AVS máxima para um casal é limitada a 150% da renda individual máxima (LAVS art. 35). Se tens direito à renda máxima com o cônjuge, o teto pode reduzir o total.';

  @override
  String get mariageChecklistItem7Title => 'Adaptar o testamento';

  @override
  String get mariageChecklistItem7Desc =>
      'O casamento modifica a ordem de sucessão. O cônjuge torna-se herdeiro legal com direitos importantes (CC art. 462). Se tinhas um testamento a favor de terceiros, pode ser necessário revisá-lo.';

  @override
  String mariageChecklistProgress(int done, int total) {
    return '$done/$total passos concluídos';
  }

  @override
  String get mariageRepartitionDissolution =>
      'REPARTIÇÃO EM CASO DE DISSOLUÇÃO';

  @override
  String get mariagePersonne1Recoit => 'Pessoa 1 recebe';

  @override
  String get mariagePersonne2Recoit => 'Pessoa 2 recebe';

  @override
  String get mariagePersonne1Garde => 'Pessoa 1 mantém';

  @override
  String get mariagePersonne2Garde => 'Pessoa 2 mantém';

  @override
  String get successionSituationTitle => 'SITUAÇÃO PESSOAL';

  @override
  String get successionSituationSubtitle2 => 'Estado civil, herdeiros';

  @override
  String get successionFortuneTitle => 'PATRIMÔNIO';

  @override
  String get successionFortuneSubtitle2 => 'Património total, 3a, LPP';

  @override
  String get successionTestamentTitle => 'Testamento';

  @override
  String get successionTestamentSubtitle2 => 'Vontades testamentárias';

  @override
  String successionQuotitePct(String pct) {
    return 'ou seja, $pct% da sucessão';
  }

  @override
  String get successionExonereLabel => 'Isento';

  @override
  String successionFiscaliteCanton(String canton) {
    return 'FISCALIDADE SUCESSÓRIA ($canton)';
  }

  @override
  String get successionEduQuotiteBody2 =>
      'A quota disponível é a parte da tua sucessão que podes atribuir livremente por testamento. Desde 1 de janeiro de 2023, a reserva dos descendentes foi reduzida de 3/4 para 1/2. Os pais já não têm reserva. Isso dá-te mais liberdade.';

  @override
  String get successionEdu3aBody2 =>
      'O 3.º pilar (3a) NÃO faz parte da massa sucessória ordinária. É pago diretamente aos beneficiários segundo a ordem fixada pela OPP3 (art. 2): cônjuge/parceiro registado, depois descendentes, pais, irmãos. O concubino pode ser designado beneficiário, mas apenas por uma cláusula explícita junto da fundação.';

  @override
  String get successionEduConcubinBody2 =>
      'No direito suíço, os concubinos NÃO têm direitos sucessórios legais. Sem testamento, um concubino não recebe nada. Além disso, o imposto sucessório para concubinos é geralmente muito mais alto do que para cônjuges (frequentemente 20-25% em vez de 0%). Para proteger o teu parceiro, é essencial redigir um testamento, verificar as cláusulas de beneficiários 3a/LPP e considerar seguros de vida.';

  @override
  String get successionDisclaimerText =>
      'Os resultados apresentados são estimativas indicativas e não constituem aconselhamento jurídico ou notarial personalizado. O direito sucessório tem muitas subtilezas. Consulte um notário ou advogado especializado antes de tomar qualquer decisão.';

  @override
  String get donationIntroText =>
      'As doações na Suíça estão sujeitas a um imposto cantonal que varia conforme o parentesco e o cantão. Desde 2023, a reserva hereditária foi reduzida, dando-te mais liberdade. Esta ferramenta ajuda-te a estimar o imposto e a verificar a compatibilidade com os direitos dos herdeiros.';

  @override
  String get donationSectionTitle => 'DOAÇÃO';

  @override
  String get donationSectionSubtitle => 'Montante, beneficiário, tipo';

  @override
  String get donationMontantLabel => 'Montante da doação';

  @override
  String get donationLienParente => 'Grau de parentesco';

  @override
  String get donationTypeDonation => 'Tipo de doação';

  @override
  String get donationValeurImmobiliere => 'Valor imobiliário';

  @override
  String get donationAvancementHoirie => 'Antecipação de herança';

  @override
  String get donationContexteSuccessoral => 'CONTEXTO SUCESSÓRIO';

  @override
  String get donationContexteSubtitle =>
      'Família, património, regime matrimonial';

  @override
  String get donationAgeLabel => 'Idade do doador';

  @override
  String get donationNbEnfants => 'Número de filhos';

  @override
  String get donationFortuneTotale => 'Património total do doador';

  @override
  String get donationRegimeMatrimonial => 'Regime matrimonial';

  @override
  String get donationCalculer => 'Calcular';

  @override
  String get donationImpotTitle => 'IMPOSTO SOBRE A DOAÇÃO';

  @override
  String get donationExoneree => 'Isenta';

  @override
  String donationTauxCanton(String taux, String canton) {
    return 'Taxa: $taux% (cantão $canton)';
  }

  @override
  String get donationMontantRow => 'Montante da doação';

  @override
  String get donationLienRow => 'Grau de parentesco';

  @override
  String get donationReserveTitle => 'RESERVA HEREDITÁRIA (2023)';

  @override
  String get donationReserveProtege => 'montante protegido por lei (intocável)';

  @override
  String get donationReserveNote =>
      'Desde 2023, os pais já não têm reserva. A reserva dos descendentes é de 50% da sua quota legal (CC art. 471).';

  @override
  String get donationQuotiteTitle => 'QUOTA DISPONÍVEL';

  @override
  String get donationQuotiteDesc => 'montante que podes doar livremente';

  @override
  String donationDepassement(String amount) {
    return 'Excesso de $amount — risco de ação de redução';
  }

  @override
  String get donationImpactTitle => 'IMPACTO NA SUCESSÃO';

  @override
  String get donationAvancementNote =>
      'Antecipação de herança: a doação será reportada à massa sucessória.';

  @override
  String get donationHorsPartNote =>
      'Doação fora de parte: é imputada apenas à quota disponível.';

  @override
  String get donationEduQuotiteTitle => 'O que é a quota disponível?';

  @override
  String get donationEduQuotiteBody =>
      'A quota disponível é a parte do teu património que podes doar ou legar livremente sem invadir as reservas hereditárias. Desde 1 de janeiro de 2023, a reserva dos descendentes foi reduzida de 3/4 para 1/2 da sua quota legal, e os pais já não têm reserva. Isso dá-te mais liberdade para fazer doações.';

  @override
  String get donationEduAvancementTitle =>
      'Antecipação de herança vs doação fora de parte';

  @override
  String get donationEduAvancementBody =>
      'Uma antecipação de herança é um adiantamento sobre a quota hereditária do beneficiário. Será reportada à massa sucessória no óbito. Uma doação fora de parte (ou preciput) é imputada apenas à quota disponível e não é reportada. A escolha entre as duas tem um impacto importante no equilíbrio entre herdeiros.';

  @override
  String get donationEduConcubinTitle => 'Doações e concubinos';

  @override
  String get donationEduConcubinBody =>
      'Os concubinos não têm direitos sucessórios legais na Suíça. Uma doação é a forma mais direta de os favorecer. No entanto, o imposto cantonal sobre doações entre concubinos é geralmente elevado (18-25% conforme o cantão). Schwyz é a exceção: sem imposto sobre doações. Considerar um testamento complementar para proteção completa.';

  @override
  String get donationDisclaimer =>
      'Esta ferramenta educativa fornece estimativas indicativas e não constitui aconselhamento jurídico, fiscal ou notarial personalizado nos termos da LSFin. Consulta um especialista (notário) para a tua situação.';

  @override
  String get donationCanton => 'Cantão';

  @override
  String get housingSaleIntroText =>
      'Vender um imóvel na Suíça implica um imposto sobre as mais-valias imobiliárias (LHID art. 12), o eventual reembolso dos fundos de previdência utilizados (EPL) e custos de transação. Esta ferramenta ajuda-te a estimar o produto líquido da venda.';

  @override
  String get housingSaleBienTitle => 'IMÓVEL';

  @override
  String get housingSaleBienSubtitle => 'Preço de compra, venda, investimentos';

  @override
  String get housingSalePrixAchat => 'Preço de compra';

  @override
  String get housingSalePrixVente => 'Preço de venda';

  @override
  String get housingSaleAnneeAchat => 'Ano de compra';

  @override
  String get housingSaleInvestissements => 'Investimentos valorizantes';

  @override
  String get housingSaleFraisAcquisition =>
      'Custos de aquisição (notário, etc.)';

  @override
  String get housingSaleResidencePrincipale => 'Residência principal';

  @override
  String get housingSaleFinancementTitle => 'FINANCIAMENTO';

  @override
  String get housingSaleFinancementSubtitle => 'Hipoteca restante';

  @override
  String get housingSaleHypotheque => 'Hipoteca restante';

  @override
  String get housingSaleEplTitle => 'EPL — PREVIDÊNCIA UTILIZADA';

  @override
  String get housingSaleEplSubtitle => 'LPP e 3a utilizados para a compra';

  @override
  String get housingSaleEplLpp => 'EPL LPP utilizado';

  @override
  String get housingSaleEpl3a => 'EPL 3a utilizado';

  @override
  String get housingSaleRemploiTitle => 'REINVESTIMENTO';

  @override
  String get housingSaleRemploiSubtitle =>
      'Projeto de compra de um novo imóvel';

  @override
  String get housingSaleProjetRemploi => 'Projeto de reinvestimento (recompra)';

  @override
  String get housingSalePrixNouveauBien => 'Preço do novo imóvel';

  @override
  String get housingSalePlusValueTitle => 'MAIS-VALIA IMOBILIÁRIA';

  @override
  String get housingSalePlusValueBrute => 'Mais-valia bruta';

  @override
  String get housingSalePlusValueImposable => 'Mais-valia tributável';

  @override
  String get housingSaleDureeDetention => 'Duração de detenção';

  @override
  String housingSaleYearsCount(int count) {
    return '$count anos';
  }

  @override
  String housingSaleImpotGainsCanton(String canton) {
    return 'IMPOSTO SOBRE GANHOS ($canton)';
  }

  @override
  String get housingSaleTauxImposition => 'Taxa de imposto';

  @override
  String get housingSaleImpotGains => 'Imposto sobre ganhos';

  @override
  String get housingSaleReportRemploi => 'Diferimento (reinvestimento)';

  @override
  String get housingSaleImpotEffectif => 'Imposto efetivo';

  @override
  String get housingSaleReportTitle => 'DIFERIMENTO FISCAL (REINVESTIMENTO)';

  @override
  String get housingSaleReportDesc =>
      'de mais-valia diferida (não tributada agora)';

  @override
  String get housingSaleReportNote =>
      'O diferimento será integrado na revenda do novo imóvel (LHID art. 12 al. 3).';

  @override
  String get housingSaleEplRepaymentTitle => 'REEMBOLSO EPL';

  @override
  String get housingSaleRemboursementLpp => 'Reembolso LPP';

  @override
  String get housingSaleRemboursement3a => 'Reembolso 3a';

  @override
  String get housingSaleEplNote =>
      'Obrigação legal: os fundos de previdência utilizados para a compra devem ser reembolsados na venda da residência principal (LPP art. 30d).';

  @override
  String get housingSaleProduitNetTitle => 'PRODUTO LÍQUIDO DA VENDA';

  @override
  String get housingSaleImpotPlusValue => 'Imposto mais-valia';

  @override
  String get housingSaleRemboursementEplLpp => 'Reembolso EPL LPP';

  @override
  String get housingSaleRemboursementEpl3a => 'Reembolso EPL 3a';

  @override
  String get housingSaleEduImpotTitle =>
      'Como funciona o imposto sobre as mais-valias imobiliárias?';

  @override
  String get housingSaleEduImpotBody =>
      'Na Suíça, qualquer ganho com a venda de um imóvel está sujeito a um imposto cantonal específico (LHID art. 12). A taxa diminui com o período de detenção. Após 20-25 anos conforme o cantão, o ganho pode estar total ou parcialmente isento. Os investimentos valorizantes e os custos de aquisição são dedutíveis.';

  @override
  String get housingSaleEduRemploiTitle => 'O que é o reinvestimento?';

  @override
  String get housingSaleEduRemploiBody =>
      'O reinvestimento permite diferir a tributação da mais-valia se comprares uma nova residência principal num prazo razoável (geralmente 2 anos). Se o novo imóvel custar tanto ou mais, o diferimento é total. Caso contrário, é proporcional. O imposto será devido na revenda do novo imóvel.';

  @override
  String get housingSaleEduEplTitle => 'EPL: o que acontece na venda?';

  @override
  String get housingSaleEduEplBody =>
      'Se utilizaste fundos de previdência (EPL) para a compra da tua residência principal, deves reembolsá-los na venda (LPP art. 30d). Este reembolso é obrigatório e é feito ao teu fundo de pensões (LPP) e/ou à tua fundação 3a. O montante está inscrito no registo predial e não pode ser evitado.';

  @override
  String get housingSaleDisclaimer =>
      'Esta ferramenta educativa fornece estimativas indicativas e não constitui aconselhamento fiscal, jurídico ou imobiliário personalizado nos termos da LSFin. Consulta um especialista para a tua situação pessoal.';

  @override
  String get housingSaleCanton => 'Cantão';

  @override
  String get jobCompareDeltaLabel => 'Delta';

  @override
  String jobCompareRetirementBody(
      String betterJob, String annualDelta, String monthlyDelta) {
    return '$betterJob vale mais $annualDelta/ano em renda vitalícia, ou seja, $monthlyDelta/mês PARA A VIDA após a reforma.';
  }

  @override
  String jobCompareLifetime20Years(String amount) {
    return 'Em 20 anos de reforma: $amount';
  }

  @override
  String jobCompareAxesFavorable(String favorable, String total) {
    return '$favorable eixos favoráveis de $total';
  }

  @override
  String get jobCompareCurrentJobWidget => 'Emprego atual';

  @override
  String get jobCompareNewJobWidget => 'Emprego previsto';

  @override
  String get jobCompareAxisSalary => 'Salário bruto';

  @override
  String get jobCompareAxisLpp => 'Contribuição LPP';

  @override
  String get jobCompareAxisDistance => 'Distância';

  @override
  String get jobCompareAxisVacation => 'Férias';

  @override
  String get jobCompareAxisWeeklyHours => 'Horas semanais';

  @override
  String get jobCompareChecklistSub => 'Lista de verificação';

  @override
  String get independantJourJTitle => 'O Dia D — A grande mudança';

  @override
  String get independantJourJSubtitle =>
      'O que muda em 1 dia quando te tornas independente';

  @override
  String get independantJourJEmployee => 'Assalariado/a';

  @override
  String get independantJourJSelfEmployed => 'Independente';

  @override
  String independantJourJChiffreChoc(String amount) {
    return 'Perdes ~$amount/mês de proteção invisível.\nNão deixaste um emprego. Deixaste um sistema de proteção.';
  }

  @override
  String independantAvsBody(String amount) {
    return 'A tua contribuição AVS estimada: $amount/ano (taxa degressiva para rendimentos inferiores a CHF 58’800, depois ~10.6% acima).';
  }

  @override
  String get independantAvsSource =>
      'Fonte: LAVS art. 8 / Tabelas de contribuição AVS';

  @override
  String get independant3aWithLpp =>
      'Com LPP voluntário: teto 3a padrão de CHF 7’258/ano.';

  @override
  String independant3aWithoutLpp(String amount) {
    return 'Sem LPP: teto 3a \"grande\" de 20% do rendimento líquido, máx. $amount/ano (teto legal CHF 36’288).';
  }

  @override
  String get independant3aSource => 'Fonte: OPP3 art. 7';

  @override
  String get independantPerMonth => '/mês';

  @override
  String get independantPerYear => '/ ano';

  @override
  String get independantCostAvs => 'AVS / AI / APG';

  @override
  String get independantCostIjm => 'IJM (estimativa)';

  @override
  String get independantCostLaa => 'LAA (estimativa)';

  @override
  String get independantCost3a => 'Pilar 3a (máx.)';

  @override
  String disabilityGapSeniorityYears(String years) {
    return '$years anos';
  }

  @override
  String disabilityGapPhase1Duration(String weeks) {
    return '$weeks semanas';
  }

  @override
  String get disabilityGapPhase1Full => '100% do salário';

  @override
  String get disabilityGapNoCoverage => 'Sem cobertura';

  @override
  String get disabilityGapNone => 'Nenhuma';

  @override
  String get disabilityGapPhase2Duration => 'Até 24 meses';

  @override
  String disabilityGapPhase2Coverage(String amount) {
    return '80% do salário ($amount CHF/mês)';
  }

  @override
  String get disabilityGapCollectiveInsurance => 'Seguro coletivo';

  @override
  String get disabilityGapNotSubscribed => 'Não subscrito';

  @override
  String get disabilityGapPhase3Duration => 'Após 24 meses';

  @override
  String get disabilityGapActionSelfIjm => 'Subscreve um IJM individual';

  @override
  String get disabilityGapActionSelfIjmSub =>
      'Prioridade absoluta para independentes';

  @override
  String get disabilityGapActionCheckHr =>
      'Verifica com o teu RH a tua cobertura de doença';

  @override
  String get disabilityGapActionCheckHrSub =>
      'Pergunta se existe um IJM coletivo';

  @override
  String get disabilityGapActionConditions =>
      'Pede as condições exatas do teu IJM';

  @override
  String get disabilityGapActionConditionsSub =>
      'Período de espera, duração, taxa de cobertura';

  @override
  String get successionMarried => 'Casado/a';

  @override
  String get successionSingle => 'Solteiro/a';

  @override
  String get successionDivorced => 'Divorciado/a';

  @override
  String get successionWidowed => 'Viúvo/a';

  @override
  String get successionConcubinage => 'Concubinato';

  @override
  String get successionConjoint => 'Cônjuge';

  @override
  String get successionChildren => 'Filhos';

  @override
  String get successionThirdParty => 'Terceiros / Obra';

  @override
  String get successionQuotiteFreedom =>
      'Este montante pode ser livremente atribuído por testamento à pessoa da tua escolha.';

  @override
  String get successionFiscalTitle => 'FISCALIDADE SUCESSÓRIA';

  @override
  String get successionExempt => 'Isento';

  @override
  String get successionEduQuotiteTitle => 'O que é a quota disponível?';

  @override
  String get successionEdu3aTitle => 'O 3a e a sucessão: atenção!';

  @override
  String get successionEduConcubinTitle => 'Os concubinos e a sucessão';

  @override
  String get successionCantonLabel => 'Cantão';

  @override
  String get debtCheckTitle => 'Check-up de Saúde Financeira';

  @override
  String get debtCheckExportTooltip => 'Exportar meu relatório';

  @override
  String get debtCheckSectionDaily => 'Gestão diária';

  @override
  String get debtCheckOverdraftQuestion => 'Estás regularmente no negativo?';

  @override
  String get debtCheckOverdraftSub =>
      'A tua conta fica negativa antes do fim do mês.';

  @override
  String get debtCheckMultipleCreditsQuestion =>
      'Tens vários créditos em curso?';

  @override
  String get debtCheckMultipleCreditsSub =>
      'Leasing, empréstimos, créditos pequenos, cartões de crédito...';

  @override
  String get debtCheckSectionObligations => 'Obrigações';

  @override
  String get debtCheckLatePaymentsQuestion => 'Tens pagamentos em atraso?';

  @override
  String get debtCheckLatePaymentsSub =>
      'Faturas, impostos ou aluguéis pagos com atraso.';

  @override
  String get debtCheckCollectionQuestion => 'Recebeste cobranças judiciais?';

  @override
  String get debtCheckCollectionSub => 'Mandados de pagamento ou penhoras.';

  @override
  String get debtCheckSectionBehaviors => 'Comportamentos';

  @override
  String get debtCheckImpulsiveQuestion => 'Compras impulsivas frequentes?';

  @override
  String get debtCheckImpulsiveSub =>
      'Despesas não planeadas de que te arrependes.';

  @override
  String get debtCheckGamblingQuestion => 'Jogas dinheiro regularmente?';

  @override
  String get debtCheckGamblingSub =>
      'Casinos, apostas desportivas ou lotarias frequentes.';

  @override
  String get debtCheckAnalyzeButton => 'Analisar a minha situação';

  @override
  String get debtCheckMentorTitle => 'Palavra do Mentor';

  @override
  String get debtCheckMentorBody =>
      'Este check-up de 60 segundos permite-nos detetar sinais de alerta antes que se tornem críticos.';

  @override
  String get debtCheckYes => 'SIM';

  @override
  String get debtCheckNo => 'NÃO';

  @override
  String get debtCheckRiskLow => 'Risco Controlado';

  @override
  String get debtCheckRiskMedium => 'Pontos de Atenção';

  @override
  String get debtCheckRiskHigh => 'Alerta Crítico';

  @override
  String get debtCheckRiskUnknown => 'Indeterminado';

  @override
  String debtCheckFactorsDetected(int count) {
    return '$count fator(es) detetado(s)';
  }

  @override
  String get debtCheckRecommendationsTitle => 'RECOMENDAÇÕES DO MENTOR';

  @override
  String get debtCheckValidateButton => 'Validar o meu check-up';

  @override
  String get debtCheckRedoButton => 'Refazer o check-up';

  @override
  String get debtCheckHonestyQuote =>
      'A honestidade consigo mesmo é o primeiro passo para a serenidade.';

  @override
  String get debtCheckGamblingSupportTitle => 'Apoio a Jogos de Azar';

  @override
  String get debtCheckGamblingSupportBody =>
      'Apoio profissional e anónimo está disponível gratuitamente.';

  @override
  String get debtCheckGamblingSupportCta => 'SOS Jogo - Ajuda online';

  @override
  String get debtCheckPrivacyNote =>
      'Mint respeita a tua privacidade. Nenhum dado é armazenado ou transmitido.';

  @override
  String scoreRevealGreeting(String name) {
    return 'Aqui está a tua pontuação, $name.';
  }

  @override
  String get scoreRevealTitle => 'O teu diagnóstico\nestá pronto.';

  @override
  String get scoreRevealBudget => 'Orçamento';

  @override
  String get scoreRevealPrevoyance => 'Previdência';

  @override
  String get scoreRevealPatrimoine => 'Património';

  @override
  String get scoreRevealLevelExcellent => 'Excelente';

  @override
  String get scoreRevealLevelGood => 'Bom';

  @override
  String get scoreRevealLevelWarning => 'Atenção';

  @override
  String get scoreRevealLevelCritical => 'Crítico';

  @override
  String get scoreRevealCoachLabel => 'O TEU COACH';

  @override
  String get scoreRevealCtaDashboard => 'Ver o meu painel';

  @override
  String get scoreRevealCtaReport => 'Ver relatório detalhado';

  @override
  String get scoreRevealDisclaimer =>
      'Ferramenta educativa — não constitui aconselhamento financeiro (LSFin).';

  @override
  String get affordabilityTitle => 'Capacidade de compra';

  @override
  String get affordabilitySource =>
      'Fonte: diretiva ASB sobre crédito hipotecário, prática bancária suíça.';

  @override
  String get affordabilityIndicators => 'Indicadores';

  @override
  String get affordabilityChargesRatio => 'Rácio encargos / rendimento';

  @override
  String get affordabilityEquityRatio => 'Capitais próprios / preço';

  @override
  String get affordabilityOk => 'OK';

  @override
  String get affordabilityExceeded => 'Excedido';

  @override
  String get affordabilityParameters => 'As tuas hipóteses';

  @override
  String get affordabilityCanton => 'Cantão';

  @override
  String get affordabilityGrossIncome => 'Rendimento bruto anual';

  @override
  String get affordabilityTargetPrice => 'Preço de compra alvo';

  @override
  String get affordabilityAvailableSavings => 'Poupança disponível';

  @override
  String get affordabilityPillar3a => 'Ativos pilar 3a';

  @override
  String get affordabilityPillarLpp => 'Ativos LPP';

  @override
  String get affordabilityCalculationDetail => 'Detalhe do cálculo';

  @override
  String get affordabilityEquityRequired =>
      'Capitais próprios requeridos (20%)';

  @override
  String get affordabilitySavingsLabel => 'Poupança';

  @override
  String get affordabilityLppMax10 => 'Ativos LPP (máx 10% do preço)';

  @override
  String get affordabilityTotalEquity => 'Total capitais próprios';

  @override
  String affordabilityMortgagePercent(String percent) {
    return 'Hipoteca ($percent%)';
  }

  @override
  String get affordabilityMonthlyCharges => 'Encargos mensais teóricos';

  @override
  String get affordabilityCalculationNote =>
      'Cálculo teórico: hipoteca x (5% juro imputado + 1% amortização) + preço x 1% custos acessórios. Máx 33% do rendimento bruto.';

  @override
  String get amortizationSource =>
      'Fonte: OPP3 (pilar 3a), prática hipotecária suíça. Teto 3a assalariado 2026: CHF 7\'258.';

  @override
  String get amortizationIntroTitle => 'Amortização: direta ou indireta?';

  @override
  String get amortizationIntroBody =>
      'Na Suíça, a amortização indireta é uma particularidade única: em vez de reembolsar diretamente a dívida, depositas num pilar 3a dado em penhor. Beneficias de uma dupla dedução fiscal (juros + depósito 3a) e o teu capital permanece investido.';

  @override
  String get amortizationDirect => 'Direta';

  @override
  String get amortizationDirectDesc =>
      'Reembolsas a dívida todos os anos. Os juros diminuem progressivamente.';

  @override
  String get amortizationIndirect => 'Indireta';

  @override
  String get amortizationIndirectDesc =>
      'Depositas num 3a dado em penhor. Dupla dedução fiscal.';

  @override
  String amortizationEvolutionTitle(int years) {
    return 'Evolução em $years anos';
  }

  @override
  String get amortizationLegendDebtDirect => 'Dívida (direta)';

  @override
  String get amortizationLegendDebtIndirect => 'Dívida (indireta)';

  @override
  String get amortizationLegendCapital3a => 'Capital 3a';

  @override
  String get amortizationParameters => 'Parâmetros';

  @override
  String get amortizationMortgageAmount => 'Montante hipotecário';

  @override
  String get amortizationInterestRate => 'Taxa de juro';

  @override
  String get amortizationDuration => 'Duração';

  @override
  String get amortizationMarginalRate => 'Taxa marginal estimada';

  @override
  String get amortizationDetailedComparison => 'Comparação detalhada';

  @override
  String get amortizationDirectTitle => 'Amortização direta';

  @override
  String get amortizationTotalInterest => 'Total de juros pagos';

  @override
  String get amortizationNetCost => 'Custo líquido total';

  @override
  String get amortizationIndirectTitle => 'Amortização indireta';

  @override
  String get amortizationCapital3aAccumulated => 'Capital 3a acumulado';

  @override
  String get fiscalComparatorTitle => 'Comparador fiscal';

  @override
  String get fiscalTabMyTax => 'Meu imposto';

  @override
  String get fiscalTab26Cantons => '26 cantões';

  @override
  String get fiscalTabMove => 'Mudança';

  @override
  String get fiscalGrossAnnualIncome => 'Rendimento bruto anual';

  @override
  String get fiscalCanton => 'Cantão';

  @override
  String get fiscalCivilStatus => 'Estado civil';

  @override
  String get fiscalSingle => 'Solteiro/a';

  @override
  String get fiscalMarried => 'Casado/a';

  @override
  String get fiscalChildren => 'Filhos';

  @override
  String get fiscalNetWealth => 'Património líquido';

  @override
  String get fiscalChurchMember => 'Membro de uma igreja';

  @override
  String get fiscalChurchTax => 'Imposto eclesiástico';

  @override
  String get fiscalEffectiveRate => 'Taxa efetiva estimada';

  @override
  String fiscalBelowAverage(String rate) {
    return 'Abaixo da média suíça (~$rate%)';
  }

  @override
  String fiscalAboveAverage(String rate) {
    return 'Acima da média suíça (~$rate%)';
  }

  @override
  String get fiscalBreakdownTitle => 'DECOMPOSIÇÃO FISCAL';

  @override
  String get fiscalFederalTax => 'Imposto federal';

  @override
  String get fiscalCantonalCommunalTax => 'Imposto cantonal + comunal';

  @override
  String get fiscalWealthTax => 'Imposto sobre o património';

  @override
  String get fiscalTotalBurden => 'Carga fiscal total';

  @override
  String get fiscalNationalPosition => 'POSIÇÃO NACIONAL';

  @override
  String get fiscalRanks => 'classifica-se';

  @override
  String get fiscalCantons => 'cantões';

  @override
  String get fiscalCheapest => 'Mais barato';

  @override
  String get fiscalMostExpensive => 'Mais caro';

  @override
  String get fiscalGapBetweenCantons =>
      'diferença entre o cantão mais barato e o mais caro';

  @override
  String get fiscalMoveIntro =>
      'Simula o impacto fiscal de uma mudança entre dois cantões. Os parâmetros de rendimento e situação familiar são partilhados com o separador \"Meu imposto\".';

  @override
  String get fiscalCurrentCanton => 'Cantão atual';

  @override
  String get fiscalDestinationCanton => 'Cantão de destino';

  @override
  String get fiscalIncomeTaxLabel => 'Imposto sobre o rendimento';

  @override
  String get fiscalEstimateNote => 'Estimativa segundo taxa cantonal';

  @override
  String get fiscalEstimatedRent => 'Renda estimada';

  @override
  String get fiscalRentNote => 'Varia por município e superfície';

  @override
  String get fiscalMovingCosts => 'Custos de mudança';

  @override
  String get fiscalMovingCostsNote => 'Amortizado em 24 meses';

  @override
  String get fiscalWealthTaxTitle => 'IMPOSTO SOBRE O PATRIMÓNIO';

  @override
  String fiscalNetWealthAmount(String amount) {
    return 'Património líquido: $amount';
  }

  @override
  String fiscalWealthSaving(String amount) {
    return 'Poupança património: $amount/ano';
  }

  @override
  String fiscalWealthSurcharge(String amount) {
    return 'Sobretaxa património: $amount/ano';
  }

  @override
  String get fiscalWealthEquivalent => 'Imposto patrimonial equivalente';

  @override
  String get fiscalChecklist1 => 'Declarar a partida ao município atual';

  @override
  String get fiscalChecklist2 => 'Registar-se no novo município em 14 dias';

  @override
  String get fiscalChecklist3 =>
      'Atualizar o endereço junto do seguro de saúde';

  @override
  String get fiscalChecklist4 =>
      'Adaptar a declaração fiscal (prorata temporis)';

  @override
  String get fiscalChecklist5 => 'Verificar subsídios LAMal no novo cantão';

  @override
  String get fiscalChecklist6 => 'Transferir registos (veículo, escolas, etc.)';

  @override
  String get fiscalChecklistTitle => 'CHECKLIST DE MUDANÇA';

  @override
  String get fiscalGoodToKnow => 'BOM SABER';

  @override
  String get fiscalEduDateTitle => 'Data de referência: 31 de dezembro';

  @override
  String get fiscalEduDateBody =>
      'És tributado no cantão onde residias a 31 de dezembro do ano fiscal. Uma mudança a 30 de dezembro conta para o ano inteiro!';

  @override
  String get fiscalEduProrataTitle => 'Prorata temporis';

  @override
  String get fiscalEduProrataBody =>
      'O imposto federal é sempre o mesmo. Apenas os impostos cantonais e comunais mudam. O prorata aplica-se no ano da mudança.';

  @override
  String get fiscalEduRentTitle => 'Rendas e custo de vida';

  @override
  String get fiscalEduRentBody =>
      'Não te esqueças que as poupanças fiscais podem ser compensadas por diferenças de renda e custo de vida. Compara o orçamento global, não apenas os impostos.';

  @override
  String get fiscalCommune => 'Município';

  @override
  String get fiscalCapitalDefault => 'Capital (padrão)';

  @override
  String get fiscalDisclaimer =>
      'Estimativas simplificadas para fins educativos — não constitui consultoria fiscal. As taxas efetivas dependem de muitos fatores (deduções, património, município, etc.). Consulta um especialista fiscal para um cálculo personalizado.';

  @override
  String get expatTitle => 'Expatriação';

  @override
  String get expatTabForfait => 'Forfait';

  @override
  String get expatTabDeparture => 'Partida';

  @override
  String get expatTabAvs => 'AVS';

  @override
  String get expatForfaitEducation =>
      'O forfait fiscal (tributação baseada na despesa) permite a pessoas de nacionalidade estrangeira não serem tributadas sobre o seu rendimento mundial, mas com base nas suas despesas de vida. Cerca de 5\'000 pessoas beneficiam dele na Suíça.';

  @override
  String get expatHighlightSchwyz => 'Fiscalidade mais vantajosa da Suíça';

  @override
  String get expatHighlightZug => 'Hub internacional, acesso a Zurique';

  @override
  String get expatCanton => 'Cantão';

  @override
  String get expatLivingExpenses => 'Despesas de vida anuais';

  @override
  String get expatActualIncome => 'Rendimento real anual';

  @override
  String get expatTaxComparison => 'COMPARAÇÃO FISCAL';

  @override
  String get expatForfaitFiscal => 'Forfait fiscal';

  @override
  String get expatOrdinaryTaxation => 'Tributação ordinária';

  @override
  String get expatOnActualIncome => 'Sobre rendimento real';

  @override
  String get expatAbolishedCantons => 'Cantões que aboliram o forfait';

  @override
  String expatAbolishedNote(String names) {
    return '$names — o forfait fiscal já não está disponível nestes cantões.';
  }

  @override
  String get expatDepartureDate => 'Data de partida';

  @override
  String get expatCurrentCanton => 'Cantão atual';

  @override
  String get expatPillar3aBalance => 'Saldo pilar 3a';

  @override
  String get expatLppBalance => 'Saldo LPP (ativos de reforma)';

  @override
  String get expatNoExitTax => 'Sem imposto de saída na Suíça';

  @override
  String get expatRecommendedTimeline => 'CRONOLOGIA RECOMENDADA';

  @override
  String get expatDepartureChecklist => 'CHECKLIST DE PARTIDA';

  @override
  String get expatAvsEducation =>
      'Para receber uma pensão AVS completa (máx CHF 2\'520/mês), são necessários 44 anos de contribuição sem lacunas. Cada ano em falta reduz a pensão em cerca de 2.3%. Se vives no estrangeiro, podes contribuir voluntariamente para o AVS para evitar lacunas.';

  @override
  String get expatYearsInSwitzerland => 'Anos na Suíça';

  @override
  String get expatYearsAbroad => 'Anos no estrangeiro';

  @override
  String get expatAvsCompleteness => 'COMPLETUDE AVS';

  @override
  String get expatOfPension => 'da pensão';

  @override
  String get expatEstimatedPension => 'Pensão estimada';

  @override
  String get expatAvsComplete =>
      'Confirmado: tens os teus 44 anos completos de contribuição. A tua pensão AVS não deverá ser reduzida.';

  @override
  String get expatPensionImpact => 'IMPACTO NA TUA PENSÃO';

  @override
  String get expatMissingYears => 'Anos em falta';

  @override
  String get expatEstimatedReduction => 'Redução estimada';

  @override
  String get expatMonthlyLoss => 'Perda mensal';

  @override
  String get expatAnnualLoss => 'Perda anual';

  @override
  String get expatVoluntaryContribution => 'CONTRIBUIÇÃO VOLUNTÁRIA';

  @override
  String get expatVoluntaryAvsTitle => 'AVS voluntário desde o estrangeiro';

  @override
  String get expatMinContribution => 'Contribuição mínima';

  @override
  String get expatMaxContribution => 'Contribuição máxima';

  @override
  String get expatVoluntaryAvsBody =>
      'Podes contribuir voluntariamente para o AVS se vives no estrangeiro. Prazo de inscrição: 1 ano após a saída da Suíça. Condição: ter contribuído pelo menos 5 anos consecutivos antes da partida.';

  @override
  String get expatRecommendation => 'RECOMENDADA';

  @override
  String get expatDidYouKnow => 'Sabias que?';

  @override
  String get mariageTimelinePartner1 => 'Pessoa 1';

  @override
  String get mariageTimelinePartner2 => 'Pessoa 2';

  @override
  String get mariageTimelineCoachTip =>
      'Cada fase da vida requer adaptar o contrato de casamento e a previdência.';

  @override
  String get mariageTimelineAct1Title => 'Vocês dois trabalham';

  @override
  String get mariageTimelineAct1Period => '0-10 anos de vida em comum';

  @override
  String get mariageTimelineAct1Insight =>
      'Fase de construção: 3a, LPP, poupança conjunta. Aproveitem os dois rendimentos.';

  @override
  String get mariageTimelineAct2Title => 'Fase de poupança intensiva';

  @override
  String get mariageTimelineAct2Period => '10-25 anos';

  @override
  String get mariageTimelineAct2Insight =>
      'Resgate LPP, 3a máximo, preparação reforma. O vosso capital duplica.';

  @override
  String get mariageTimelineAct3Title => 'Reforma do casal';

  @override
  String get mariageTimelineAct3Period => '25+ anos';

  @override
  String get mariageTimelineAct3Insight =>
      'Atenção: limite AVS casal (150% renda máxima). Planear renda vs capital.';

  @override
  String get naissanceChecklistItem1Title =>
      'Inscrever o bebé no seguro de saúde (3 meses)';

  @override
  String get naissanceChecklistItem1Desc =>
      'Tens 3 meses após o nascimento para inscrever o teu filho numa seguradora de saúde. Se o fizeres dentro deste prazo, a cobertura é retroativa desde o nascimento. Após este prazo, há risco de interrupção da cobertura. Compara os prémios infantis entre seguradoras — as diferenças podem ser significativas.';

  @override
  String get naissanceChecklistItem2Title => 'Solicitar os abonos de família';

  @override
  String get naissanceChecklistItem2Desc =>
      'Solicita através do teu empregador (ou da tua caixa de abonos se fores independente). Os abonos são pagos a partir do mês de nascimento. O montante depende do cantão (CHF 200 a CHF 305/mês por filho).';

  @override
  String get naissanceChecklistItem3Title =>
      'Declarar o nascimento no registo civil';

  @override
  String get naissanceChecklistItem3Desc =>
      'O hospital geralmente transmite o aviso ao registo civil. Verifica que a certidão de nascimento foi corretamente emitida. Vais precisar dela para todos os procedimentos administrativos.';

  @override
  String get naissanceChecklistItem4Title =>
      'Organizar a licença parental (APG)';

  @override
  String get naissanceChecklistItem4Desc =>
      'Licença de maternidade: 14 semanas a 80% do salário (máx. CHF 220/dia). Licença de paternidade: 2 semanas (10 dias), a tomar em 6 meses. A inscrição APG faz-se através do empregador ou diretamente na caixa de compensação.';

  @override
  String get naissanceChecklistItem5Title => 'Atualizar a declaração fiscal';

  @override
  String get naissanceChecklistItem5Desc =>
      'Um filho adicional dá-te direito a uma dedução fiscal de CHF 6\'700/ano (LIFD art. 35). Se tiveres despesas de guarda, podes deduzir até CHF 25\'500/ano. Lembra-te de adaptar os teus pagamentos por conta para o ano em curso.';

  @override
  String get naissanceChecklistItem6Title => 'Adaptar o orçamento familiar';

  @override
  String get naissanceChecklistItem6Desc =>
      'Um filho custa em média CHF 1\'200 a CHF 1\'500/mês na Suíça (alimentação, roupa, atividades, seguro, fraldas, etc.). Reavalia o teu orçamento com o módulo Orçamento do MINT.';

  @override
  String get naissanceChecklistItem7Title =>
      'Verificar a previdência (LPP e 3a)';

  @override
  String get naissanceChecklistItem7Desc =>
      'Se reduzires o teu horário de trabalho, as tuas contribuições LPP diminuem. Cada ano a tempo parcial significa menos capital na reforma. Considera compensar contribuindo o máximo para o 3.º pilar (CHF 7\'258/ano).';

  @override
  String get naissanceChecklistItem8Title =>
      'Redigir ou atualizar o testamento';

  @override
  String get naissanceChecklistItem8Desc =>
      'A chegada de um filho modifica a ordem sucessória. Os filhos são herdeiros legitimários (CC art. 471). Se tens um testamento, verifica que respeita as reservas legais.';

  @override
  String get naissanceChecklistItem9Title =>
      'Subscrever um seguro de risco de morte/invalidez';

  @override
  String get naissanceChecklistItem9Desc =>
      'Com um filho a cargo, a proteção financeira em caso de morte ou invalidez torna-se ainda mais importante. Verifica a tua cobertura atual (LPP, seguro de vida) e complementa se necessário.';

  @override
  String get naissanceBabyCostCreche => 'Creche / guarda';

  @override
  String get naissanceBabyCostCrecheNote =>
      'Tarifa média subsidiada — varia muito consoante o cantão';

  @override
  String get naissanceBabyCostAlimentation => 'Alimentação';

  @override
  String get naissanceBabyCostVetements => 'Roupa e equipamento';

  @override
  String get naissanceBabyCostLamal => 'Seguro de saúde infantil';

  @override
  String get naissanceBabyCostLamalNote =>
      'Prémio médio infantil — sem franquia até aos 18 anos';

  @override
  String get naissanceBabyCostActivites => 'Atividades e lazer';

  @override
  String get naissanceBabyCostDivers => 'Diversos (brinquedos, higiene…)';

  @override
  String get waterfallBrutMensuel => 'Brut mensuel';

  @override
  String get waterfallAvsAc => 'AVS / AC';

  @override
  String get waterfallLppEmploye => 'LPP employé';

  @override
  String get waterfallNetFicheDePaie => 'Net fiche de paie';

  @override
  String get waterfallImpots => 'Impôts';

  @override
  String get waterfallDisponible => 'Disponible';

  @override
  String get waterfallLoyer => 'Loyer';

  @override
  String get waterfallLamal => 'LAMal';

  @override
  String get waterfallLeasing => 'Leasing';

  @override
  String get waterfallAutresFixes => 'Autres fixes';

  @override
  String get waterfallResteAVivre => 'Reste à vivre';

  @override
  String get waterfallPillar3a => '3a';

  @override
  String get waterfallInvestissement => 'Investissement';

  @override
  String get waterfallMargeLibre => 'Marge libre';

  @override
  String get waterfallTitle => 'Cascade budgétaire';

  @override
  String get narrativeDefaultName => 'Tu';

  @override
  String narrativeCouplePositiveMargin(String margin) {
    return 'Ensemble, vous avez une marge de $margin CHF/mois.';
  }

  @override
  String narrativeCoupleTightBudget(String margin) {
    return 'Ensemble, votre budget est serré de $margin CHF/mois.';
  }

  @override
  String narrativeCoupleHighPatrimoine(String patrimoine) {
    return 'Avec un patrimoine de $patrimoine CHF, vous avez des leviers.';
  }

  @override
  String narrativeHighHealth(String name) {
    return '$name, tu es en bonne santé financière. Continue.';
  }

  @override
  String narrativeHighHealthPatrimoine(String patrimoine) {
    return 'Ton patrimoine de $patrimoine CHF te donne une belle marge de manœuvre.';
  }

  @override
  String narrativeLowHealth(String name) {
    return '$name, concentre-toi sur l\'essentiel. On va stabiliser ensemble.';
  }

  @override
  String narrativeLowHealthPatrimoine(String patrimoine) {
    return 'Ton patrimoine de $patrimoine CHF est un atout à protéger.';
  }

  @override
  String narrativeMediumHealth(String name) {
    return '$name, tu as de bonnes bases. Quelques actions peuvent faire la différence.';
  }

  @override
  String narrativeMediumHealthPatrimoine(String patrimoine) {
    return 'Ton patrimoine de $patrimoine CHF est un bon point de départ.';
  }

  @override
  String narrativeConfidenceLabel(String score) {
    return 'Confiance profil : $score%';
  }

  @override
  String patrimoineCoupleTitleCouple(String firstName, String conjointName) {
    return 'Patrimoine — $firstName & $conjointName';
  }

  @override
  String patrimoineCoupleTitleSolo(String firstName) {
    return 'Patrimoine — $firstName';
  }

  @override
  String get patrimoineLiquide => 'LIQUIDE';

  @override
  String get patrimoineImmobilier => 'IMMOBILIER';

  @override
  String get patrimoinePrevoyance => 'PRÉVOYANCE';

  @override
  String get patrimoineEpargne => 'Épargne';

  @override
  String get patrimoineInvest => 'Invest.';

  @override
  String get patrimoineAucunBien => 'Aucun bien';

  @override
  String get patrimoineValeur => 'Valeur';

  @override
  String get patrimoineHypo => '−Hypo.';

  @override
  String get patrimoineNet => 'Net';

  @override
  String get patrimoineLtvSaine => 'LTV saine';

  @override
  String get patrimoineLtvAmortissement => 'Amortissement recommandé';

  @override
  String get patrimoineLtvElevee => 'LTV élevée — amortir';

  @override
  String patrimoineLtvDisplay(String percent) {
    return 'LTV $percent%';
  }

  @override
  String get patrimoineLpp => 'LPP';

  @override
  String get patrimoine3a => '3a';

  @override
  String get patrimoineLibrePassage => 'Libre pass.';

  @override
  String get patrimoineTotal => 'Total';

  @override
  String get patrimoineBrut => 'Patrimoine brut';

  @override
  String get patrimoineDettes => '−Dettes';

  @override
  String get patrimoineNetLabel => 'Patrimoine net';

  @override
  String patrimoineDont(String name, String amount) {
    return 'dont $name ~CHF $amount';
  }

  @override
  String get conjointProfilsLies => 'Profils liés';

  @override
  String get conjointProfilConjoint => 'Profil conjoint·e';

  @override
  String conjointDeclaredStatus(String name) {
    return '$name n\'a pas de compte MINT. Ses données sont estimées (🟡).';
  }

  @override
  String conjointInvitedStatus(String name) {
    return 'Invitation envoyée à $name. En attente de réponse.';
  }

  @override
  String conjointLinkedStatus(String name) {
    return '✅ Profils liés ! Les données de $name sont synchronisées.';
  }

  @override
  String conjointInviteLabel(String name) {
    return 'Inviter $name (5 questions, sans compte)';
  }

  @override
  String get conjointLierProfils => 'Lier nos profils';

  @override
  String get conjointRenvoyerInvitation => 'Renvoyer l\'invitation';

  @override
  String get conjointRegimeLabel => 'Régime matrimonial : ';

  @override
  String get conjointRegimeParticipation => 'Participation aux acquêts';

  @override
  String get conjointRegimeSeparation => 'Séparation de biens';

  @override
  String get conjointRegimeCommunaute => 'Communauté de biens';

  @override
  String get conjointRegimeDefault => '(défaut CC art. 196)';

  @override
  String get conjointModifier => 'modifier';

  @override
  String get futurHorizonTitle => 'Horizon Retraite';

  @override
  String get futurCoupleLabel => 'Couple';

  @override
  String get futurTauxRemplacement => 'Taux de remplacement';

  @override
  String get futurAgeRetraite => 'Age retraite';

  @override
  String get futurConfiance => 'Confiance';

  @override
  String get futurRevenuMensuelProjection =>
      'Revenu mensuel projeté à la retraite';

  @override
  String get futurRenteAvs => 'Rente AVS';

  @override
  String get futurRenteLpp => 'Rente LPP estimée';

  @override
  String get futurPilier3aSwr => 'Pilier 3a (SWR 4%)';

  @override
  String futurCapitalLabel(String amount) {
    return 'Capital $amount';
  }

  @override
  String get futurLibrePassageSwr => 'Libre passage (SWR 4%)';

  @override
  String get futurInvestissementsSwr => 'Investissements (SWR 4%)';

  @override
  String get futurTotalCoupleProjecte => 'Total couple projeté';

  @override
  String get futurTotalMensuelProjecte => 'Total mensuel projeté';

  @override
  String get futurCapitalRetraite => 'Capital à la retraite';

  @override
  String get futurCapitalTotal => 'Capital total (3a + LP + investissements)';

  @override
  String get futurCapitalTaxHint =>
      'Le retrait en capital est taxé séparément (LIFD art. 38). Le SWR n\'est pas un revenu imposable.';

  @override
  String futurMargeIncertitude(String pct) {
    return 'Marge d\'incertitude (± $pct%)';
  }

  @override
  String futurFourchette(String low, String high) {
    return 'Fourchette : CHF $low – $high/mois';
  }

  @override
  String get futurCompleterProfil =>
      'Complete ton profil pour affiner la projection.';

  @override
  String get futurDisclaimer =>
      'Projection éducative — ne constitue pas un conseil (LSFin). SWR 4% = règle des 4%, non garanti. Rentes AVS/LPP estimées selon LAVS art. 21-40, LPP art. 14-16.';

  @override
  String get futurExplorerDetails => 'Explorer les détails';

  @override
  String get financialSummaryTitle => 'RESUMO FINANCEIRO';

  @override
  String get financialSummaryNoProfile => 'Nenhum perfil registado';

  @override
  String get financialSummaryStartDiagnostic => 'Iniciar o diagnóstico';

  @override
  String get financialSummaryRestartDiagnostic => 'Reiniciar o diagnóstico';

  @override
  String get financialSummaryNarrativeFiscalite =>
      'A otimização fiscal é a tua primeira alavanca: 3a, resgate LPP, deduções.';

  @override
  String get financialSummaryNarrativePrevoyance =>
      'A tua previdência determina o teu conforto na reforma. Cada ano conta.';

  @override
  String get financialSummaryNarrativeAvs =>
      'O AVS é a base da tua reforma. Verifica as tuas lacunas de contribuição.';

  @override
  String get financialSummaryLegendSaisi => 'Inserido';

  @override
  String get financialSummaryLegendEstime => 'Estimado';

  @override
  String get financialSummaryLegendCertifie => 'Certificado';

  @override
  String get financialSummarySalaireBrutMensuel => 'Salário bruto mensal';

  @override
  String get financialSummary13emeSalaire => '13.º salário';

  @override
  String financialSummaryNemeMois(String n) {
    return '$n.º mês';
  }

  @override
  String financialSummaryBonusEstime(String pct) {
    return 'Bónus estimado ($pct%)';
  }

  @override
  String financialSummaryConjointBrutMensuel(String name) {
    return '$name — bruto mensal';
  }

  @override
  String get financialSummaryDefaultConjoint => 'Cônjuge';

  @override
  String get financialSummaryRevenuBrutAnnuel => 'Rendimento bruto anual';

  @override
  String get financialSummaryRevenuBrutAnnuelCouple =>
      'Rendimento bruto anual (casal)';

  @override
  String get financialSummarySoitLisseSur12Mois => 'distribuído em 12 meses';

  @override
  String get financialSummaryDeductionsSalariales => 'Deduções salariais';

  @override
  String get financialSummaryChargesSociales => 'Encargos sociais (AVS/AI/AC)';

  @override
  String get financialSummaryCotisationLpp => 'Contribuição LPP empregado·a';

  @override
  String get financialSummaryNetFicheDePaie => 'Líquido recibo de vencimento';

  @override
  String get financialSummaryNetFicheDePaieHint =>
      'O que chega à tua conta todos os meses';

  @override
  String get financialSummaryFiscalite => 'Fiscalidade';

  @override
  String get financialSummaryImpotEstime => 'Imposto estimado (ICC + IFD)';

  @override
  String get financialSummaryTauxMarginalEstime => 'Taxa marginal estimada';

  @override
  String financialSummary13emeEtBonusHint(String label, String montant) {
    return '$label: ~$montant líquido/ano (não incluído no mensal)';
  }

  @override
  String get financialSummaryRevenusEtFiscalite => 'Rendimentos e Fiscalidade';

  @override
  String get financialSummaryDisponibleApresImpot => 'Disponível após impostos';

  @override
  String get financialSummaryFootnoteRevenus =>
      'Estimativa simplificada. A AANP e a IJM variam consoante o empregador e não estão incluídas. A LPP empregado reflete o mínimo legal (50/50) — a tua caixa pode aplicar outra repartição.';

  @override
  String get financialSummaryScanFicheSalaire => 'Digitalizar o meu recibo';

  @override
  String get financialSummaryModifierRevenu => 'Modificar rendimento';

  @override
  String get financialSummaryEditSalaireBrut => 'Salário bruto mensal (CHF)';

  @override
  String get financialSummaryAvs1erPilier => 'AVS (1.º pilar)';

  @override
  String get financialSummaryAnneesCotisees => 'Anos de contribuição';

  @override
  String financialSummaryAnneesUnit(String n) {
    return '$n anos';
  }

  @override
  String get financialSummaryLacunes => 'Lacunas';

  @override
  String get financialSummaryRenteEstimee => 'Renda estimada';

  @override
  String get financialSummaryLpp2ePilier => 'LPP (2.º pilar)';

  @override
  String get financialSummaryAvoirTotal => 'Ativos totais';

  @override
  String get financialSummaryObligatoire => 'Obrigatório';

  @override
  String get financialSummarySurobligatoire => 'Supra-obrigatório';

  @override
  String get financialSummaryTauxConversion => 'Taxa de conversão';

  @override
  String get financialSummaryRachatPossible => 'Resgate possível';

  @override
  String get financialSummaryRachatPlanifie => 'Resgate planeado';

  @override
  String get financialSummaryCaisse => 'Caixa';

  @override
  String get financialSummary3a3ePilier => '3a (3.º pilar)';

  @override
  String financialSummaryNComptes(String n) {
    return '$n conta(s)';
  }

  @override
  String get financialSummaryLibrePassage => 'Livre passagem';

  @override
  String financialSummaryCompteN(String n) {
    return 'Conta $n';
  }

  @override
  String financialSummaryConjointLpp(String name) {
    return '$name — LPP';
  }

  @override
  String financialSummaryConjoint3a(String name) {
    return '$name — 3a';
  }

  @override
  String get financialSummaryFatcaWarning =>
      '⚠️ FATCA — Apenas uma minoria de fornecedores aceita (ex. Raiffeisen)';

  @override
  String get financialSummaryPrevoyanceTitle => 'Previdência';

  @override
  String get financialSummaryScanCertificatLpp =>
      'Digitalizar certificado LPP / AVS';

  @override
  String get financialSummaryModifierPrevoyance => 'Modificar previdência';

  @override
  String get financialSummaryEditAvoirLpp => 'Ativos LPP totais (CHF)';

  @override
  String get financialSummaryEditNombre3a => 'Número de contas 3a';

  @override
  String get financialSummaryEditTotal3a => 'Poupança total 3a (CHF)';

  @override
  String get financialSummaryEditRachatLpp =>
      'Resgate LPP mensal previsto (CHF/mês)';

  @override
  String get financialSummaryLiquidites => 'Liquidez';

  @override
  String get financialSummaryEpargneLiquide => 'Poupança líquida';

  @override
  String get financialSummaryInvestissements => 'Investimentos';

  @override
  String get financialSummaryImmobilier => 'Imobiliário';

  @override
  String get financialSummaryValeurEstimee => 'Valor estimado';

  @override
  String get financialSummaryHypothequeRestante => 'Hipoteca restante';

  @override
  String get financialSummaryValeurNetteImmobiliere =>
      'Valor líquido imobiliário';

  @override
  String financialSummaryLtvAmortissement(String pct) {
    return 'Rácio LTV: $pct% — amortização 2.º grau obrigatória';
  }

  @override
  String financialSummaryLtvBonneVoie(String pct) {
    return 'Rácio LTV: $pct% — bom caminho';
  }

  @override
  String financialSummaryLtvExcellent(String pct) {
    return 'Rácio LTV: $pct% — excelente';
  }

  @override
  String get financialSummaryPrevoyanceCapital => 'Previdência (capital)';

  @override
  String get financialSummaryAvoirLppTotal => 'Ativos LPP totais';

  @override
  String financialSummaryCapital3a(String n, String s) {
    return 'Capital 3a ($n conta$s)';
  }

  @override
  String get financialSummaryPatrimoineBrut => 'Património bruto';

  @override
  String get financialSummaryDettesTotales => 'Dívidas totais';

  @override
  String get financialSummaryPatrimoine => 'Património';

  @override
  String get financialSummaryPatrimoineTotalBloque =>
      'Património total (incl. previdência bloqueada)';

  @override
  String get financialSummaryModifierPatrimoine => 'Modificar património';

  @override
  String get financialSummaryEditEpargneLiquide => 'Poupança líquida (CHF)';

  @override
  String get financialSummaryEditInvestissements => 'Investimentos (CHF)';

  @override
  String get financialSummaryEditValeurImmobiliere => 'Valor imobiliário (CHF)';

  @override
  String get financialSummaryLoyerCharges => 'Renda / encargos';

  @override
  String get financialSummaryAssuranceMaladie => 'Seguro de saúde';

  @override
  String get financialSummaryElectriciteEnergie => 'Eletricidade / energia';

  @override
  String get financialSummaryTransport => 'Transporte';

  @override
  String get financialSummaryTelecom => 'Telecomunicações';

  @override
  String get financialSummaryFraisMedicaux => 'Despesas médicas';

  @override
  String get financialSummaryAutresFraisFixes => 'Outras despesas fixas';

  @override
  String get financialSummaryAucuneDepense => 'Nenhuma despesa registada';

  @override
  String get financialSummaryDepensesFixes => 'Despesas fixas';

  @override
  String get financialSummaryTotalMensuel => 'Total mensal';

  @override
  String get financialSummaryModifierDepenses => 'Modificar despesas';

  @override
  String get financialSummaryEditLoyerCharges => 'Renda / encargos (CHF/mês)';

  @override
  String get financialSummaryEditAssuranceMaladie =>
      'Seguro de saúde (CHF/mês)';

  @override
  String get financialSummaryEditElectricite =>
      'Eletricidade / energia (CHF/mês)';

  @override
  String get financialSummaryEditTransport => 'Transporte (CHF/mês)';

  @override
  String get financialSummaryEditTelecom => 'Telecomunicações (CHF/mês)';

  @override
  String get financialSummaryEditFraisMedicaux => 'Despesas médicas (CHF/mês)';

  @override
  String get financialSummaryEditAutresFraisFixes =>
      'Outras despesas fixas (CHF/mês)';

  @override
  String get financialSummaryModifierDettes => 'Modificar dívidas';

  @override
  String get financialSummaryEditHypotheque => 'Hipoteca (CHF)';

  @override
  String get financialSummaryEditCreditConsommation =>
      'Crédito ao consumo (CHF)';

  @override
  String get financialSummaryEditLeasing => 'Leasing (CHF)';

  @override
  String get financialSummaryEditAutresDettes => 'Outras dívidas (CHF)';

  @override
  String get financialSummaryDettes => 'Dívidas';

  @override
  String get financialSummaryAucuneDetteDeclaree =>
      'Nenhuma dívida declarada — ';

  @override
  String get financialSummaryDetteStructurelle => 'Dívida estrutural';

  @override
  String get financialSummaryHypotheque1erRang => 'Hipoteca 1.º grau';

  @override
  String get financialSummaryHypotheque2emeRang => 'Hipoteca 2.º grau';

  @override
  String get financialSummaryHypotheque => 'Hipoteca';

  @override
  String get financialSummaryChargeMensuelle => 'Encargo mensal';

  @override
  String financialSummaryEcheance(String date, String years) {
    return 'Vencimento: $date (~$years anos)';
  }

  @override
  String financialSummaryInteretsDeductibles(String montant) {
    return 'Juros dedutíveis (LIFD art. 33): $montant/ano';
  }

  @override
  String get financialSummaryDetteConsommation => 'Dívida de consumo';

  @override
  String get financialSummaryCreditConsommation => 'Crédito ao consumo';

  @override
  String get financialSummaryMensualite => 'Mensalidade';

  @override
  String get financialSummaryLeasing => 'Leasing';

  @override
  String get financialSummaryAutresDettes => 'Outras dívidas';

  @override
  String financialSummaryConseilRemboursement(String taux) {
    return 'Paga primeiro a dívida a $taux% antes de investir. Cada CHF reembolsado = $taux% de rendimento efetivo.';
  }

  @override
  String get financialSummaryTotalDettes => 'Dívidas totais';

  @override
  String get financialSummaryScannerDocument => 'Digitalizar um documento';

  @override
  String get financialSummaryCascadeBudgetaire => 'Cascata orçamental';

  @override
  String get financialSummaryToi => 'Tu';

  @override
  String get financialSummaryConjointeDefault => 'Cônjuge';

  @override
  String get financialSummaryDisclaimer =>
      'Ferramenta educativa — não constitui aconselhamento financeiro (LSFin, LAVS, LPP, LIFD). Os valores estimados (~) são calculados a partir de médias suíças. Digitaliza os teus certificados para melhorar a precisão.';

  @override
  String get financialSummaryEnregistrer => 'Guardar';

  @override
  String get financialSummaryCheckSalaireBrut => 'Salário bruto';

  @override
  String get financialSummaryCheckCanton => 'Cantão';

  @override
  String get financialSummaryCheckAvoirLpp => 'Ativos LPP';

  @override
  String get financialSummaryCheckEpargne3a => 'Poupança 3a';

  @override
  String get financialSummaryCheckEpargneLiquide => 'Poupança líquida';

  @override
  String get financialSummaryCheckLoyerHypotheque => 'Renda / hipoteca';

  @override
  String get financialSummaryCheckAssuranceMaladie => 'Seguro de saúde';

  @override
  String get financialSummaryWhatIf3aQuestion =>
      'E se maximizasses o teu 3a todos os anos?';

  @override
  String get financialSummaryWhatIf3aExplanation =>
      'Na tua taxa marginal, cada franco depositado em 3a poupa-te ~30% de impostos.';

  @override
  String get financialSummaryWhatIf3aAction => 'Simular';

  @override
  String get financialSummaryWhatIfLppQuestion =>
      'E se a tua caixa LPP passasse de 1% a 3%?';

  @override
  String get financialSummaryWhatIfLppExplanation =>
      'Um melhor rendimento LPP aumenta o teu capital de reforma sem esforço.';

  @override
  String get financialSummaryWhatIfLppAction => 'Comparar';

  @override
  String get financialSummaryWhatIfAchatQuestion =>
      'E se comprasses em vez de arrendar?';

  @override
  String get financialSummaryWhatIfAchatExplanation =>
      'A amortização indireta pelo 2.º pilar pode reduzir impostos e construir património.';

  @override
  String get financialSummaryWhatIfAchatAction => 'Explorar';

  @override
  String get dataQualityTitle => 'Qualidade dos dados';

  @override
  String dataQualityMissingCount(String count) {
    return '$count informação(ões) a adicionar';
  }

  @override
  String get dataQualityComplete => 'Perfil completo';

  @override
  String get dataQualityKnownSection => 'Dados conhecidos';

  @override
  String get dataQualityMissingSection => 'Dados em falta';

  @override
  String get dataQualityCompleteness => 'Completude';

  @override
  String get dataQualityAccuracy => 'Exatidão';

  @override
  String get dataQualityFreshness => 'Atualidade';

  @override
  String get dataQualityCombined => 'Pontuação combinada';

  @override
  String get dataQualityEnrich => 'Enriquecer meu perfil';

  @override
  String dataQualityEnrichWithImpact(String impact) {
    return 'Enriquecer meu perfil ($impact)';
  }

  @override
  String get confidenceLabelSalaire => 'Salário bruto';

  @override
  String get confidenceLabelAgeCanton => 'Idade / Cantão';

  @override
  String get confidenceLabelAge => 'Idade';

  @override
  String get confidenceLabelCanton => 'Cantão';

  @override
  String get confidenceLabelMenage => 'Situação do agregado';

  @override
  String get confidenceLabelAvoirLpp => 'Ativos LPP';

  @override
  String get confidenceLabelTauxConversion => 'Taxa de conversão';

  @override
  String get confidenceLabelAnneesAvs => 'Anos AVS';

  @override
  String get confidenceLabelEpargne3a => 'Poupança 3a';

  @override
  String get confidenceLabelPatrimoine => 'Património';

  @override
  String get confidencePromptFreshnessPrefix => 'Atualiza: ';

  @override
  String confidencePromptFreshnessStale(String months) {
    return 'Dados de $months meses atrás — rescaneie o seu certificado';
  }

  @override
  String get confidencePromptFreshnessConfirm =>
      'Confirma que este valor ainda é atual';

  @override
  String get confidencePromptAccuracyPrefix => 'Confirma: ';

  @override
  String get confidencePromptAccuracyEstimated => 'Insere o teu valor real';

  @override
  String get confidencePromptAccuracyCertificate =>
      'Digitaliza o teu certificado para confirmar';

  @override
  String get pulseTitle => 'Pulse';

  @override
  String pulseGreeting(String name) {
    return 'Olá $name';
  }

  @override
  String pulseGreetingCouple(String name1, String name2) {
    return 'Olá $name1 e $name2';
  }

  @override
  String get pulseWelcome => 'Bem-vindo ao MINT';

  @override
  String get pulseEmptyTitle => 'Começa por preencher o teu perfil!';

  @override
  String get pulseEmptySubtitle =>
      'Algumas perguntas bastam para obteres a tua primeira estimativa de visibilidade financeira.';

  @override
  String get pulseEmptyCtaStart => 'Começar';

  @override
  String get pulseVisibilityTitle => 'Visibilidade financeira';

  @override
  String get pulsePrioritiesTitle => 'As tuas prioridades';

  @override
  String get pulsePrioritiesSubtitle =>
      'Ações personalizadas com base no teu perfil';

  @override
  String get pulseComprendreTitle => 'Compreender';

  @override
  String get pulseComprendreSubtitle => 'Explora os teus simuladores';

  @override
  String get pulseComprendreRenteCapital => 'Renda ou capital?';

  @override
  String get pulseComprendreRenteCapitalSub =>
      'Compara as duas opções de levantamento';

  @override
  String get pulseComprendreRachatLpp => 'Simular um resgate LPP';

  @override
  String get pulseComprendreRachatLppSub =>
      'Descobre o impacto fiscal de um resgate';

  @override
  String get pulseComprendre3a => 'Explorar o meu 3a';

  @override
  String get pulseComprendre3aSub => 'Descobre a tua poupança fiscal anual';

  @override
  String get pulseComprendre_budget => 'O meu orçamento mensal';

  @override
  String get pulseComprendre_budgetSub =>
      'Visualiza as tuas receitas e despesas';

  @override
  String get pulseComprendreAchat => 'Comprar um imóvel?';

  @override
  String get pulseComprendreAchatSub => 'Estima a tua capacidade de empréstimo';

  @override
  String get pulseDisclaimer =>
      'Ferramenta educativa. Não constitui aconselhamento financeiro personalizado. LSFin art. 3';

  @override
  String get pulseKeyFigRetraite => 'Reforma estimada';

  @override
  String pulseKeyFigRetraitePct(String pct) {
    return '$pct % do rendimento';
  }

  @override
  String get pulseKeyFigBudgetLibre => 'Orçamento livre';

  @override
  String get pulseKeyFigPatrimoine => 'Património';

  @override
  String pulseCoupleRetraite(String montant) {
    return 'Reforma casal: $montant';
  }

  @override
  String pulseCoupleAlertWeak(String name, String score) {
    return 'O perfil de $name está a $score % de visibilidade';
  }

  @override
  String get pulseAxisLiquidite => 'Liquidez';

  @override
  String get pulseAxisFiscalite => 'Fiscalidade';

  @override
  String get pulseAxisRetraite => 'Reforma';

  @override
  String get pulseAxisSecurite => 'Segurança';

  @override
  String get pulseHintAddSalary => 'Adiciona o teu salário para começar';

  @override
  String get pulseHintAddSavings =>
      'Introduz as tuas poupanças e investimentos';

  @override
  String get pulseHintLiquiditeComplete =>
      'Os teus dados de liquidez estão completos';

  @override
  String get pulseHintAddAgeCanton =>
      'Indica a tua idade e cantão de residência';

  @override
  String get pulseHintScanTax => 'Digitaliza a tua declaração fiscal';

  @override
  String get pulseHintFiscaliteComplete =>
      'Os teus dados fiscais estão completos';

  @override
  String get pulseHintAddLpp => 'Adiciona o teu certificado LPP';

  @override
  String get pulseHintExtractAvs => 'Solicita o teu extrato AVS';

  @override
  String get pulseHintAdd3a => 'Introduz as tuas contas 3a';

  @override
  String get pulseHintRetraiteComplete =>
      'Os teus dados de reforma estão completos';

  @override
  String get pulseHintAddFamily => 'Indica a tua situação familiar';

  @override
  String get pulseHintAddStatus => 'Completa o teu estatuto profissional';

  @override
  String get pulseHintSecuriteComplete =>
      'Os teus dados de segurança estão completos';

  @override
  String get pulseNarrativeExcellent =>
      'Tens uma visão clara da tua situação. Continua a manter os teus dados atualizados.';

  @override
  String pulseNarrativeGood(String axis) {
    return 'Boa visibilidade! Refina a tua $axis para ir mais longe.';
  }

  @override
  String pulseNarrativeModerate(String axis) {
    return 'Começas a ver com mais clareza. Concentra-te na tua $axis.';
  }

  @override
  String pulseNarrativeWeak(String hint) {
    return 'Cada informação conta. Começa por $hint.';
  }

  @override
  String get pulseNoCheckinMsg =>
      'Sem check-in este mês. Regista os teus pagamentos para acompanhar o teu progresso.';

  @override
  String get pulseCheckinBtn => 'Check-in';

  @override
  String pulseBriefingTitle(String trend) {
    return 'Balanço do mês — $trend';
  }

  @override
  String get pulseFriLiquidite => 'Liquidez';

  @override
  String get pulseFriFiscalite => 'Otimização fiscal';

  @override
  String get pulseFriRetraite => 'Reforma';

  @override
  String get pulseFriRisque => 'Riscos estruturais';

  @override
  String get pulseFriTitle => 'Solidez financeira';

  @override
  String pulseFriWeakest(String axis) {
    return 'Ponto mais frágil: $axis';
  }

  @override
  String get lppBuybackAdvTitle => 'Otimização de resgate LPP';

  @override
  String get lppBuybackAdvSubtitle =>
      'Alavancagem fiscal + efeito de capitalização';

  @override
  String get lppBuybackAdvPotential => 'Potencial de resgate';

  @override
  String get lppBuybackAdvYears => 'Anos até à reforma';

  @override
  String get lppBuybackAdvStaggering => 'Escalonamento';

  @override
  String get lppBuybackAdvFundRate => 'Taxa do fundo LPP';

  @override
  String get lppBuybackAdvIncome => 'Rendimento tributável';

  @override
  String get lppBuybackAdvFinalCapital => 'Valor final capitalizado';

  @override
  String lppBuybackAdvRealReturn(String pct) {
    return 'Rendimento real: $pct % / ano';
  }

  @override
  String get lppBuybackAdvTaxSaving => 'Poupança fiscal';

  @override
  String get lppBuybackAdvNetEffort => 'Esforço líquido';

  @override
  String get lppBuybackAdvTotalGain => 'Ganho total da operação';

  @override
  String get lppBuybackAdvCapitalMinusEffort => 'Capital - Esforço líquido';

  @override
  String get lppBuybackAdvFundRateLabel => 'Taxa LPP aplicada';

  @override
  String get lppBuybackAdvLeverageEffect => 'Efeito de alavancagem fiscal';

  @override
  String get lppBuybackAdvBonASavoir => 'Bom saber';

  @override
  String get lppBuybackAdvBon1 =>
      'O resgate LPP é uma das poucas ferramentas de planeamento fiscal acessíveis a todos os trabalhadores na Suíça.';

  @override
  String get lppBuybackAdvBon2 =>
      'Cada franco resgatado é dedutível do rendimento tributável (LIFD art. 33 al. 1 let. d).';

  @override
  String get lppBuybackAdvBon3 =>
      'Atenção: qualquer levantamento EPL fica bloqueado durante 3 anos após um resgate (LPP art. 79b al. 3).';

  @override
  String get lppBuybackAdvDisclaimer =>
      'Simulação incluindo juros do fundo e poupança fiscal suavizada. O rendimento real é calculado sobre o teu esforço líquido real.';

  @override
  String get householdTitle => 'A nossa Família';

  @override
  String get householdDiscoverCouplePlus => 'Descobrir Couple+';

  @override
  String get householdLoginPrompt => 'Inicia sessão para gerir o teu agregado';

  @override
  String get householdLogin => 'Iniciar sessão';

  @override
  String get householdRetry => 'Tentar novamente';

  @override
  String get householdInvitePartner => 'Convidar o/a meu/minha parceiro/a';

  @override
  String get householdRemoveMemberTitle => 'Remover este membro?';

  @override
  String get householdRemoveMemberContent =>
      'Esta ação é irreversível. Aplica-se um período de espera de 30 dias antes de poder convidar um novo parceiro.';

  @override
  String get householdCancel => 'Cancelar';

  @override
  String get householdRemove => 'Remover';

  @override
  String get householdSendInvitation => 'Enviar convite';

  @override
  String get householdCodeCopied => 'Código copiado';

  @override
  String get householdMessageCopied => 'Mensagem copiada';

  @override
  String get householdCopy => 'Copiar';

  @override
  String get householdShare => 'Partilhar';

  @override
  String get householdHaveCode => 'Tenho um código de convite';

  @override
  String get householdCouplePlusTitle => 'Couple+';

  @override
  String get householdUpsellDescription =>
      'Otimiza a tua reforma a dois com uma subscrição Couple+. Projeções partilhadas, levantamentos escalonados e coaching de casal.';

  @override
  String get householdEmptyDescription =>
      'Otimiza a tua reforma a dois. Levantamentos escalonados, projeções de casal e calendário fiscal comum.';

  @override
  String get householdHeaderTitle => 'Agregado Couple+';

  @override
  String get householdMembersTitle => 'Membros';

  @override
  String get householdOwnerBadge => 'Proprietário';

  @override
  String get householdPendingStatus => 'Convite pendente';

  @override
  String get householdActiveStatus => 'Ativo';

  @override
  String get householdRemoveTooltip => 'Remover do agregado';

  @override
  String get householdInviteSectionTitle => 'Convidar um parceiro';

  @override
  String get householdInviteInfo =>
      'O teu parceiro receberá um código de convite válido por 72 horas.';

  @override
  String get householdEmailLabel => 'Email do parceiro';

  @override
  String get householdEmailHint => 'parceiro@email.ch';

  @override
  String get householdInviteSentTitle => 'Convite enviado';

  @override
  String get householdValidFor => 'Válido 72 horas';

  @override
  String householdShareMessage(String code) {
    return 'Junta-te ao meu agregado MINT com o código: $code\n\nAbre a app MINT > Família > Tenho um código';
  }

  @override
  String householdMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count membro$_temp0 ativo$_temp1';
  }

  @override
  String get householdPartnerDefault => 'Parceiro';

  @override
  String get documentScanCancel => 'Cancelar';

  @override
  String get documentScanAnalyze => 'Analisar';

  @override
  String get documentScanTakePhoto => 'Tirar uma foto';

  @override
  String get documentScanPasteOcr => 'Colar texto OCR';

  @override
  String get documentScanCreateAccount => 'Criar uma conta';

  @override
  String get documentScanRetakePhoto => 'Tirar outra foto';

  @override
  String get documentScanExtracting => 'A extrair...';

  @override
  String get documentScanImportFile => 'Importar um ficheiro';

  @override
  String get documentScanOcrTitle => 'Texto OCR';

  @override
  String get documentScanPdfAuthTitle => 'Login necessário para PDF';

  @override
  String get documentScanPdfAuthContent =>
      'A análise automática de PDF passa pelo backend e requer uma conta conectada. Sem conta, podes digitalizar uma foto.';

  @override
  String get documentScanOcrHint =>
      'Cola o texto OCR extraído do teu PDF para continuar.';

  @override
  String get documentScanOcrRetryHint =>
      'Cola o texto OCR se a foto continuar ilegível.';

  @override
  String get profileFamilySection => 'Família';

  @override
  String get profileAnalyticsBeta => 'Analytics beta testers';

  @override
  String get profileDeleteAccountTitle => 'Eliminar conta?';

  @override
  String get profileDeleteAccountContent =>
      'Esta ação elimina a tua conta cloud e os dados associados. Os teus dados locais permanecem neste dispositivo.';

  @override
  String get profileDeleteCancel => 'Cancelar';

  @override
  String get profileDeleteConfirm => 'Eliminar';

  @override
  String get consentAllRevoked =>
      'Todos os consentimentos opcionais foram revogados.';

  @override
  String get consentClose => 'Fechar';

  @override
  String get consentExportData => 'Exportar os meus dados (nLPD art. 28)';

  @override
  String get consentRevokeAll => 'REVOGAR TODOS OS CONSENTIMENTOS OPCIONAIS';

  @override
  String get consentControlCenter => 'CENTRO DE CONTROLO DE DADOS';

  @override
  String get consentSecurityMessage =>
      'Os teus dados permanecem no teu dispositivo. Manténs o controlo total sobre o acesso de terceiros.';

  @override
  String get consentRequired => 'Obrigatório';

  @override
  String get consentRequiredTitle => 'Consentimentos obrigatórios';

  @override
  String get consentOptionalTitle => 'Consentimentos opcionais';

  @override
  String get consentExportTitle => 'Exportar os teus dados';

  @override
  String consentRetentionDays(int days) {
    return 'Conservação: $days dias';
  }

  @override
  String get consentLegalSources => 'Fontes legais';

  @override
  String get pillar3aPaymentPerYear => 'Pagamento/ano:';

  @override
  String get pillar3aDuration => 'Duração:';

  @override
  String get pillar3aOpenViac => 'Abrir a minha conta VIAC';

  @override
  String get pillar3aFees => 'Taxas';

  @override
  String get pillar3aReturn => 'Rendimento';

  @override
  String get pillar3aAt65 => 'Aos 65';

  @override
  String get pillar3aComparator => 'Comparador 3a';

  @override
  String pillar3aProjection(int years) {
    return 'Projeção sobre $years anos';
  }

  @override
  String get pillar3aScenarioTitle => 'Cenário: Contribuição máxima anual';

  @override
  String pillar3aDurationYears(int years) {
    return '$years anos (até aos 65)';
  }

  @override
  String get pillar3aViacGainLabel => 'Com VIAC em vez de um banco:';

  @override
  String get pillar3aMoreAtRetirement => 'a mais na reforma!';

  @override
  String get pillar3aDisclaimer =>
      'Hipóteses pedagógicas baseadas em rendimentos históricos médios. Rendimentos passados não garantem rendimentos futuros.';

  @override
  String get pillar3aCapitalEvolution => 'Evolução do teu capital 3a';

  @override
  String get pillar3aYearLabel => 'Ano';

  @override
  String get pillar3aBank15 => 'Banco 1.5%';

  @override
  String get pillar3aViac45 => 'VIAC 4.5%';

  @override
  String pillar3aYearN(int n) {
    return 'Ano $n';
  }

  @override
  String get pillar3aCompoundTip =>
      'Os últimos anos representam +50% do ganho total graças aos juros compostos!';

  @override
  String get pillar3aRecommended => 'RECOMENDADO';

  @override
  String pillar3aVsBank(String amount) {
    return '$amount vs Banco';
  }

  @override
  String get wizardCollapse => 'Reduzir';

  @override
  String get wizardUnderstandTopic => 'Compreender este tema';

  @override
  String get wizardSeeSimulation => 'Ver simulação interativa';

  @override
  String get wizardNext => 'Seguinte';

  @override
  String get wizardExplanation => 'Explicação';

  @override
  String wizardValidateCount(int count) {
    return 'Validar ($count)';
  }

  @override
  String get wizardInvalidNumber => 'Introduz um número válido';

  @override
  String wizardMinValue(String value) {
    return 'Mínimo: $value';
  }

  @override
  String wizardMaxValue(String value) {
    return 'Máximo: $value';
  }

  @override
  String get wizardFieldRequired => 'Este campo é obrigatório';

  @override
  String get slmCancelDownload => 'Cancelar download';

  @override
  String get slmCancel => 'Cancelar';

  @override
  String get slmDownload => 'Descarregar';

  @override
  String get slmDelete => 'Eliminar';

  @override
  String get slmIaOnDevice => 'IA no dispositivo';

  @override
  String get slmPrivacyMessage =>
      'O modelo funciona 100% no teu dispositivo. Nenhum dado sai do teu telefone.';

  @override
  String get slmDownloadModelTitle => 'Descarregar o modelo?';

  @override
  String get slmDeleteModelTitle => 'Eliminar o modelo?';

  @override
  String slmDeleteModelContent(String size) {
    return 'Isto libertará $size de espaço. Podes voltar a descarregá-lo a qualquer momento.';
  }

  @override
  String get slmDeleteModelButton => 'Eliminar modelo';

  @override
  String get slmStartingDownload => 'A iniciar download...';

  @override
  String get slmRetryDownload => 'Tentar download novamente';

  @override
  String get slmDownloadUnavailable => 'Download indisponível nesta versão';

  @override
  String get slmEngineStatus => 'Estado do motor';

  @override
  String get slmHowItWorks => 'Como funciona?';

  @override
  String get landingPunchline1 => 'O sistema financeiro suíço é poderoso.';

  @override
  String get landingPunchline2 => 'Se o compreenderes.';

  @override
  String get landingCtaComprendre => 'Compreender';

  @override
  String get landingJargon1 => 'Dedução de coordenação';

  @override
  String get landingClear1 => 'O que te retiram';

  @override
  String get landingJargon2 => 'Valor locativo';

  @override
  String get landingClear2 => 'O imposto sobre a tua casa';

  @override
  String get landingJargon3 => 'Taxa marginal';

  @override
  String get landingClear3 => 'O que realmente pagas';

  @override
  String get landingJargon4 => 'Lacuna de previdência';

  @override
  String get landingClear4 => 'O que te vai faltar';

  @override
  String get landingJargon5 => 'Imposto de transferência';

  @override
  String get landingClear5 => 'O imposto quando compras';

  @override
  String get landingWhyNobody => 'O que não entendes custa-te. Todos os anos.';

  @override
  String get landingMintDoesIt => 'MINT fá-lo.';

  @override
  String get landingCtaCommencer => 'Começar';

  @override
  String get landingLegalFooterShort =>
      'Ferramenta educativa. Não constitui aconselhamento financeiro (LSFin). Dados no teu dispositivo.';

  @override
  String pulseDigitalTwinPct(String pct) {
    return 'Gémeo digital: $pct%';
  }

  @override
  String get pulseDigitalTwinHint =>
      'Quanto mais completo o teu perfil, mais fiáveis as projeções.';

  @override
  String get pulseActionsThisMonth => 'Para fazer este mês';

  @override
  String get pulseHeroChangeBtn => 'Mudar';

  @override
  String get pulseCoachInsightTitle => 'A análise do coach';

  @override
  String get pulseRefineProfile => 'Refinar meu perfil';

  @override
  String get pulseWhatIf3aQuestion => 'E se contribuísses o máximo no 3a?';

  @override
  String pulseWhatIf3aImpact(String amount) {
    return '−CHF $amount/ano de impostos';
  }

  @override
  String get pulseWhatIfLppQuestion => 'E se fizesses um resgate LPP?';

  @override
  String pulseWhatIfLppImpact(String amount) {
    return 'Até −CHF $amount de impostos';
  }

  @override
  String get pulseWhatIfEarlyQuestion => 'E se te reformasses 1 ano mais cedo?';

  @override
  String pulseWhatIfEarlyImpact(String amount) {
    return '−CHF $amount/mês de pensão';
  }

  @override
  String get pulseActionSignalSingular => '1 ação a fazer';

  @override
  String pulseActionSignalPlural(String count) {
    return '$count ações a fazer';
  }

  @override
  String get agirTopActionCta => 'Começar';

  @override
  String agirOtherActions(String count) {
    return '$count outras ações';
  }

  @override
  String get exploreSuggestionLabel => 'Sugestão para ti';

  @override
  String get exploreSuggestion3aTitle =>
      'Pilar 3a: a tua primeira alavanca fiscal';

  @override
  String get exploreSuggestion3aSub =>
      'Descobre quanto podes poupar em impostos';

  @override
  String get exploreSuggestionLppTitle => 'Resgate LPP: uma oportunidade?';

  @override
  String get exploreSuggestionLppSub =>
      'Simula o impacto na tua reforma e impostos';

  @override
  String get exploreSuggestionRetirementTitle => 'A tua reforma aproxima-se';

  @override
  String get exploreSuggestionRetirementSub =>
      'Renda, capital ou misto? Compara as opções';

  @override
  String get exploreSuggestionBudgetTitle => 'Começa pelo teu orçamento';

  @override
  String get exploreSuggestionBudgetSub =>
      '3 minutos para ver para onde vai o teu dinheiro';

  @override
  String get pulseReadinessTitle => 'Forma financeira';

  @override
  String get pulseReadinessGood => 'Boa preparação';

  @override
  String get pulseReadinessProgress => 'Em progresso';

  @override
  String get pulseReadinessWeak => 'A reforçar';

  @override
  String pulseReadinessRetireIn(int years) {
    return 'Reforma em $years anos';
  }

  @override
  String pulseReadinessYearsToAct(int years) {
    return 'Ainda $years anos para agir';
  }

  @override
  String get pulseReadinessActNow => 'O essencial acontece agora';

  @override
  String get pulseReadinessRetired => 'Já aposentado/a';

  @override
  String get pulseCompleteProfile => 'Complete o seu perfil';

  @override
  String get profileSectionMyFile => 'Meu dossiê';

  @override
  String get profileSectionSettings => 'Configurações';

  @override
  String get profileCompletionLabel => 'O teu dossiê';

  @override
  String get agirBudgetNet => 'Líquido';

  @override
  String get agirBudgetFixed => 'Fixos';

  @override
  String get agirBudgetAvailable => 'Disponível';

  @override
  String get agirBudgetSaved => 'Poupado';

  @override
  String get agirBudgetRemaining => 'Resto';

  @override
  String get agirBudgetWarning =>
      'Os teus contributos excedem o orçamento disponível';

  @override
  String get enrichmentCtaScan => 'Digitalizar um documento';

  @override
  String enrichmentCtaMissing(int count) {
    return '$count campo(s) a completar';
  }

  @override
  String get heroGapTitle => 'Na reforma, vai faltar-te';

  @override
  String get heroGapCovered => 'Estás bem coberto/a';

  @override
  String get heroGapPerMonth => '/mês';

  @override
  String get heroGapToday => 'Hoje';

  @override
  String get heroGapRetirement => 'Reforma';

  @override
  String get heroGapConfidence => 'Confiança';

  @override
  String get heroGapScanCta => 'Digitalizar certificado LPP';

  @override
  String heroGapBoost(int percent) {
    return '+$percent % precisão';
  }

  @override
  String get heroGapMetaphor5k => 'É como passar de um T5 para um estúdio';

  @override
  String get heroGapMetaphor3k => 'É como abdicar do carro e das férias';

  @override
  String get heroGapMetaphor1k => 'É como cortar as saídas ao restaurante';

  @override
  String get heroGapMetaphorSmall => 'É um café por dia de diferença';

  @override
  String get drawerCeQueTuAs => 'O que tens';

  @override
  String get drawerCeQueTuAsSubtitle => 'Património líquido';

  @override
  String get drawerCeQueTuDois => 'O que deves';

  @override
  String get drawerCeQueTuDoisSubtitle => 'Dívida total';

  @override
  String get drawerCeQueTuAuras => 'O que terás';

  @override
  String get drawerCeQueTuAurasSubtitle => 'Rendimento de reforma projetado';

  @override
  String get shellWelcomeBack =>
      'Bem-vindo de volta! Os teus dados estão atualizados.';

  @override
  String get shellRecommendationsUpdated => 'Recomendações atualizadas';

  @override
  String get pulseEnrichirTitle => 'Digitaliza o teu certificado LPP';

  @override
  String pulseEnrichirSubtitle(String points) {
    return 'Confiança → +$points pontos';
  }

  @override
  String get pulseEnrichirCta => 'Digitalizar →';

  @override
  String get tabMoi => 'Eu';

  @override
  String get coupleSwitchSolo => 'Solo';

  @override
  String get coupleSwitchDuo => 'Duo';

  @override
  String get identityStatusSalarie => 'Assalariado';

  @override
  String get identityStatusIndependant => 'Independente';

  @override
  String get identityStatusChomage => 'Em busca';

  @override
  String get identityStatusRetraite => 'Reformado';

  @override
  String get simLppBuybackTitle => 'Optimisation de Rachat LPP';

  @override
  String get simLppBuybackSubtitle => 'Effet levier fiscal + Capitalisation';

  @override
  String get simLppBuybackPotential => 'Potentiel de rachat';

  @override
  String get simLppBuybackYearsToRetirement => 'Années jusqu\'à la retraite';

  @override
  String get simLppBuybackStaggering => 'Lissage (staggering)';

  @override
  String get simLppBuybackFundRate => 'Taux de la caisse LPP';

  @override
  String get simLppBuybackTaxableIncome => 'Revenu imposable';

  @override
  String get simLppBuybackUnitChf => 'CHF';

  @override
  String get simLppBuybackUnitYears => 'ans';

  @override
  String get simLppBuybackFinalCapital => 'Valeur Finale Capitalisée';

  @override
  String simLppBuybackRealReturn(String rate) {
    return 'Rendement Réel : $rate % / an';
  }

  @override
  String get simLppBuybackTaxSavings => 'Économie Impôts';

  @override
  String get simLppBuybackNetEffort => 'Effort Net';

  @override
  String get simLppBuybackTotalGain => 'Gain Total de l\'opération';

  @override
  String get simLppBuybackCapitalMinusEffort => 'Capital - Effort Net';

  @override
  String get simLppBuybackFundRateLabel => 'Taux LPP servi';

  @override
  String get simLppBuybackFiscalLeverage => 'Effet levier fiscal';

  @override
  String get simLppBuybackBonASavoir => 'Bon à savoir';

  @override
  String get simLppBuybackBonASavoirItem1 =>
      'Le rachat LPP est l\'un des rares outils de planification fiscale accessibles à tous les salarié·e·s en Suisse.';

  @override
  String get simLppBuybackBonASavoirItem2 =>
      'Chaque franc racheté est déductible de ton revenu imposable (LIFD art. 33 al. 1 let. d).';

  @override
  String get simLppBuybackBonASavoirItem3 =>
      'Attention : tout retrait EPL est bloqué pendant 3 ans après un rachat (LPP art. 79b al. 3).';

  @override
  String simLppBuybackDisclaimer(
      String fundRate, int staggeringYears, String taxableIncome) {
    return 'Simulation incluant l\'intérêt de la caisse ($fundRate %) et l\'économie d\'impôt lissée sur $staggeringYears ans pour un revenu imposable de CHF $taxableIncome. Le rendement réel est calculé sur ton effort net réel.';
  }

  @override
  String get simRealInterestTitle => 'Simulateur d\'Intérêt Réel';

  @override
  String get simRealInterestSubtitle =>
      'Capital + Économie d\'impôt réinvestie (Virtuel)';

  @override
  String get simRealInterestAmount => 'Montant Investi';

  @override
  String get simRealInterestDuration => 'Durée';

  @override
  String get simRealInterestPessimistic => 'Pessimiste';

  @override
  String get simRealInterestNeutral => 'Neutre';

  @override
  String get simRealInterestOptimistic => 'Optimiste';

  @override
  String simRealInterestHypotheses(String rate) {
    return 'Hypothèses : Taux marginal $rate %. Rendements marché : 2 % / 4 % / 6 %.';
  }

  @override
  String get simRealInterestEducTitle => 'Comprendre le rendement réel';

  @override
  String get simRealInterestEducBullet1 =>
      'Le rendement réel = rendement nominal − inflation − frais';

  @override
  String get simRealInterestEducBullet2 =>
      'Un placement à 3 % avec 1.5 % d\'inflation et 0.5 % de frais rapporte seulement 1 % en réel';

  @override
  String get simRealInterestEducBullet3 =>
      'Sur 30 ans, cette différence peut représenter des dizaines de milliers de francs';

  @override
  String get simBuybackTitle => 'Stratégie Rachat LPP';

  @override
  String get simBuybackSubtitle => 'Optimisation par lissage (Staggering)';

  @override
  String get simBuybackDuration => 'Durée du lissage';

  @override
  String simBuybackYears(int count) {
    return '$count ans';
  }

  @override
  String get simBuybackLessOptimized => 'Moins Optimisé';

  @override
  String get simBuybackSingleShot => 'En 1 fois';

  @override
  String get simBuybackOptimized => 'Optimisé';

  @override
  String simBuybackInNTimes(int count) {
    return 'En $count fois';
  }

  @override
  String simBuybackEstimatedGain(String amount) {
    return 'Gain estimé : + CHF $amount';
  }

  @override
  String get simBuybackSavingsLabel => 'Économie';

  @override
  String get simBuybackMarginalRateQuestion =>
      'Qu\'est-ce que le taux marginal d\'imposition ?';

  @override
  String get simBuybackMarginalRateTitle => 'Taux marginal d\'imposition';

  @override
  String get simBuybackMarginalRateExplanation =>
      'Le taux marginal est le pourcentage d\'impôt sur ton dernier franc gagné. Plus ton revenu est élevé, plus ce taux est fort.';

  @override
  String get simBuybackMarginalRateTip =>
      'En lissant tes rachats, tu restes dans des tranches d\'imposition plus basses chaque année, ce qui augmente ton économie fiscale totale.';

  @override
  String get simBuybackLockedTitle => 'Rachat LPP bloqué';

  @override
  String get simBuybackLockedMessage =>
      'Le rachat LPP est désactivé en mode protection. Un rachat bloque ta liquidité pendant 3 ans (LPP art. 79b al. 3). Rembourse d\'abord tes dettes avant d\'immobiliser du capital.';

  @override
  String get pcWidgetTitle => 'Prestações complementares (PC)';

  @override
  String get pcWidgetSubtitle => 'Lista de verificação de elegibilidade local';

  @override
  String get pcWidgetRevenus => 'Rendimentos';

  @override
  String get pcWidgetFortune => 'Património';

  @override
  String get pcWidgetLoyer => 'Renda';

  @override
  String get pcWidgetEligible =>
      'A tua situação sugere um direito potencial às PC.';

  @override
  String get pcWidgetNotEligible =>
      'Os teus rendimentos parecem suficientes segundo as escalas padrão.';

  @override
  String pcWidgetFindOffice(String canton) {
    return 'Encontrar o escritório PC ($canton)';
  }

  @override
  String get letterGenTitle => 'Secretariado Automático';

  @override
  String get letterGenSubtitle => 'Gera modelos de cartas prontos a usar.';

  @override
  String get letterGenBuybackTitle => 'Pedido de Resgate LPP';

  @override
  String get letterGenBuybackSubtitle =>
      'Para conhecer o teu potencial de resgate.';

  @override
  String get letterGenTaxTitle => 'Certificado Fiscal';

  @override
  String get letterGenTaxSubtitle => 'Para a tua declaração de impostos.';

  @override
  String get letterGenDisclaimer =>
      'Estes documentos são modelos a completar. Não constituem aconselhamento jurídico.';

  @override
  String get precisionPromptTitle => 'Precisão disponível';

  @override
  String get precisionPromptPreciser => 'Precisar';

  @override
  String get precisionPromptContinuer => 'Continuar';

  @override
  String get earlyRetirementHeader => 'E se eu me reformasse aos…';

  @override
  String earlyRetirementAgeDisplay(int age) {
    return '$age anos';
  }

  @override
  String get earlyRetirementZoneRisky =>
      'Arriscado — sacrifício financeiro importante';

  @override
  String get earlyRetirementZoneFeasible => 'Viável — com compromissos';

  @override
  String get earlyRetirementZoneStandard => 'Padrão — sem penalidade';

  @override
  String get earlyRetirementZoneBonus =>
      'Bónus — ganhas mais, mas aproveitas menos tempo';

  @override
  String earlyRetirementResultLine(int age, String amount) {
    return 'Aos $age : $amount/mês';
  }

  @override
  String earlyRetirementNarrativeEarly(
      String amount, int years, String plural) {
    return 'Perdes $amount/mês para a vida. Mas ganhas $years ano$plural de liberdade.';
  }

  @override
  String earlyRetirementNarrativeLate(String amount, int years, String plural) {
    return 'Ganhas $amount/mês a mais. $years ano$plural de trabalho adicional.';
  }

  @override
  String earlyRetirementLifetimeImpact(String amount) {
    return 'Impacto estimado em 25 anos : $amount';
  }

  @override
  String get earlyRetirementDisclaimer =>
      'Estimativas educativas — não constitui aconselhamento financeiro (LSFin).';

  @override
  String earlyRetirementSemanticsLabel(int age) {
    return 'Simulador de idade de reforma. Idade selecionada : $age anos.';
  }

  @override
  String get budgetReportTitle => 'Ton Budget Calculé';

  @override
  String get budgetReportDisponible => 'Disponible';

  @override
  String get budgetReportVariables => 'Variables (Vivre)';

  @override
  String get budgetReportFutur => 'Futur (Épargne)';

  @override
  String budgetReportChfAmount(String amount) {
    return 'CHF $amount';
  }

  @override
  String get budgetReportStopWarning =>
      'Attention : Aucune marge de manœuvre pour les dépenses variables.';

  @override
  String get ninetyDayGaugeTitle => 'Règle des 90 jours';

  @override
  String get ninetyDayGaugeSubtitle => 'Frontaliers  ·  Seuil fiscal';

  @override
  String get ninetyDayGaugeDaysOf90 => '/ 90 jours';

  @override
  String get ninetyDayGaugeStatusRed =>
      'Seuil dépassé — risque d\'imposition ordinaire en Suisse';

  @override
  String ninetyDayGaugeStatusOrange(int remaining, String plural) {
    return 'Attention : plus que $remaining jour$plural avant le seuil';
  }

  @override
  String ninetyDayGaugeStatusGreen(int remaining, String plural) {
    return 'Zone sûre — $remaining jour$plural restants avant le seuil';
  }

  @override
  String ninetyDayGaugeSemanticsLabel(int days, String status) {
    return 'Jauge de la règle des 90 jours. $days jours sur 90. $status';
  }

  @override
  String get ninetyDayGaugeZoneSafe => 'Zone sûre';

  @override
  String get ninetyDayGaugeZoneAttention => 'Attention';

  @override
  String get ninetyDayGaugeZoneRisk => 'Risque fiscal';

  @override
  String get forfaitFiscalTitle => 'Forfait fiscal vs Ordinaire';

  @override
  String get forfaitFiscalSubtitle => 'Comparaison annuelle  ·  Expatriés';

  @override
  String get forfaitFiscalSaving => 'Économie forfait';

  @override
  String get forfaitFiscalSurcharge => 'Surcoût forfait';

  @override
  String get forfaitFiscalPerYear => 'par année';

  @override
  String forfaitFiscalSemanticsLabel(
      String ordinary, String forfait, String savings) {
    return 'Comparaison forfait fiscal. Imposition ordinaire : $ordinary. Forfait fiscal : $forfait. Économie : $savings.';
  }

  @override
  String get forfaitFiscalOrdinaryLabel => 'Imposition\nordinaire';

  @override
  String get forfaitFiscalForfaitLabel => 'Forfait\nfiscal';

  @override
  String get forfaitFiscalBaseLine => 'Base forfaitaire';

  @override
  String get spendingMeterBudgetUnavailable => 'Budget non disponible';

  @override
  String get spendingMeterDisponible => 'Disponible';

  @override
  String spendingMeterVariablesLegend(int percent) {
    return 'Variables $percent%';
  }

  @override
  String spendingMeterFuturLegend(int percent) {
    return 'Futur $percent%';
  }

  @override
  String get avsGuideAppBarTitle => 'EXTRAIT AVS';

  @override
  String get avsGuideHeaderTitle => 'Comment obtenir ton extrait AVS';

  @override
  String get avsGuideHeaderSubtitle =>
      'L\'extrait de compte individuel (CI) contient tes années de cotisation.';

  @override
  String avsGuideConfidencePoints(int points) {
    return '+$points points de confiance';
  }

  @override
  String get avsGuideConfidenceSubtitle =>
      'Années de cotisation, RAMD, lacunes';

  @override
  String get avsGuideStepsTitle => 'En 4 étapes';

  @override
  String get avsGuideStep1Title => 'Va sur www.ahv-iv.ch';

  @override
  String get avsGuideStep1Subtitle => 'C\'est le site officiel de l\'AVS/AI.';

  @override
  String get avsGuideStep2Title =>
      'Connecte-toi avec ton eID ou crée un compte';

  @override
  String get avsGuideStep2Subtitle => 'Tu auras besoin de ton numéro AVS.';

  @override
  String get avsGuideStep3Title =>
      'Demande ton extrait de compte individuel (CI)';

  @override
  String get avsGuideStep3Subtitle =>
      'Cherche la section \"Extrait de compte\" ou \"Kontoauszug\".';

  @override
  String get avsGuideStep4Title => 'Tu le recevras par courrier ou PDF';

  @override
  String get avsGuideStep4Subtitle =>
      'Selon ta caisse, l\'extrait arrive en 5 à 10 jours ouvrables.';

  @override
  String get avsGuideOpenAhvButton => 'Ouvrir ahv-iv.ch';

  @override
  String get avsGuideScanButton => 'J\'ai déjà mon extrait → Scanner';

  @override
  String get avsGuideTestMode => 'MODE TEST';

  @override
  String get avsGuideTestDescription => 'Pas d\'extrait AVS sous la main ?';

  @override
  String get avsGuideTestButton => 'Utiliser un exemple';

  @override
  String get avsGuideFreeNote => 'L\'extrait AVS est gratuit.';

  @override
  String get avsGuidePrivacyNote =>
      'L\'image de ton extrait n\'est jamais stockée.';

  @override
  String avsGuideSnackbarError(String url) {
    return 'Impossible d\'ouvrir $url.';
  }

  @override
  String get dataBlockDisclaimer => 'Outil éducatif simplifié.';

  @override
  String get dataBlockIncomplete => 'Ce bloc est encore incomplet.';

  @override
  String get dataBlockComplete => 'Ce bloc est complet.';

  @override
  String get dataBlockModeForm => 'Formulaire';

  @override
  String get dataBlockModeCoach => 'Parle au coach';

  @override
  String get dataBlockStatusComplete => 'Complet';

  @override
  String get dataBlockStatusPartial => 'Partiel';

  @override
  String get dataBlockStatusMissing => 'Manquant';

  @override
  String get dataBlockRevenuTitle => 'Revenu';

  @override
  String get dataBlockRevenuDesc => 'Ton salaire brut.';

  @override
  String get dataBlockRevenuCta => 'Préciser mon revenu';

  @override
  String get dataBlockLppTitle => 'Prévoyance LPP';

  @override
  String get dataBlockLppDesc => 'Ton avoir LPP.';

  @override
  String get dataBlockLppCta => 'Ajouter mon certificat LPP';

  @override
  String get dataBlockAvsTitle => 'Extrait AVS';

  @override
  String get dataBlockAvsDesc => 'L\'extrait AVS.';

  @override
  String get dataBlockAvsCta => 'Commander mon extrait AVS';

  @override
  String get dataBlock3aTitle => '3e pilier (3a)';

  @override
  String get dataBlock3aDesc => 'Tes comptes 3a.';

  @override
  String get dataBlock3aCta => 'Simuler mon 3a';

  @override
  String get dataBlockPatrimoineTitle => 'Patrimoine';

  @override
  String get dataBlockPatrimoineDesc => 'Épargne libre, investissements.';

  @override
  String get dataBlockPatrimoineCta => 'Renseigner mon patrimoine';

  @override
  String get dataBlockFiscaliteTitle => 'Fiscalité';

  @override
  String get dataBlockFiscaliteDesc => 'Ta commune et ton revenu.';

  @override
  String get dataBlockFiscaliteCta => 'Comparer ma fiscalité';

  @override
  String get dataBlockObjectifTitle => 'Objectif retraite';

  @override
  String get dataBlockObjectifDesc => 'À quel âge ?';

  @override
  String get dataBlockObjectifCta => 'Voir ma projection';

  @override
  String get dataBlockMenageTitle => 'Composition du ménage';

  @override
  String get dataBlockMenageDesc => 'En couple.';

  @override
  String get dataBlockMenageCta => 'Gérer mon ménage';

  @override
  String get dataBlockUnknownTitle => 'Données';

  @override
  String get dataBlockUnknownDesc => 'Lien obsolète.';

  @override
  String get dataBlockUnknownCta => 'Ouvrir le diagnostic';

  @override
  String get dataBlockDefaultTitle => 'Données';

  @override
  String get dataBlockDefaultDesc => 'Complète ce bloc.';

  @override
  String get dataBlockDefaultCta => 'Compléter';

  @override
  String get renteVsCapitalAppBarTitle => 'Rente ou capital : ta décision';

  @override
  String get renteVsCapitalIntro => 'À la retraite, tu choisis.';

  @override
  String get renteVsCapitalRenteLabel => 'Rente';

  @override
  String get renteVsCapitalRenteExplanation => 'Montant fixe chaque mois.';

  @override
  String get renteVsCapitalCapitalLabel => 'Capital';

  @override
  String get renteVsCapitalCapitalExplanation =>
      'Tout ton avoir LPP d\'un coup.';

  @override
  String get renteVsCapitalMixteLabel => 'Mixte';

  @override
  String get renteVsCapitalMixteExplanation =>
      'Obligatoire en rente + surobligatoire en capital.';

  @override
  String get renteVsCapitalEstimateMode => 'Estimer pour moi';

  @override
  String get renteVsCapitalCertificateMode => 'J\'ai mon certificat';

  @override
  String get renteVsCapitalAge => 'Ton âge';

  @override
  String get renteVsCapitalSalary => 'Ton salaire brut annuel (CHF)';

  @override
  String get renteVsCapitalLppTotal => 'Ton avoir LPP actuel (CHF)';

  @override
  String renteVsCapitalEstimatedCapital(int age, String amount) {
    return 'Capital estimé à $age ans : ~$amount';
  }

  @override
  String renteVsCapitalEstimatedRente(String amount) {
    return 'Rente estimée : ~$amount/an';
  }

  @override
  String get renteVsCapitalProjectionSource =>
      'Projection basée sur ton profil';

  @override
  String get renteVsCapitalLppOblig => 'Avoir LPP obligatoire';

  @override
  String get renteVsCapitalLppSurob => 'Avoir LPP surobligatoire';

  @override
  String get renteVsCapitalRenteProposed => 'Rente annuelle proposée';

  @override
  String get renteVsCapitalTcOblig => 'Taux conv. oblig. (%)';

  @override
  String get renteVsCapitalTcSurob => 'Taux conv. surob. (%)';

  @override
  String get renteVsCapitalMaxPrecision => 'Précision maximale.';

  @override
  String get renteVsCapitalCanton => 'Canton';

  @override
  String get renteVsCapitalMarried => 'Marié·e';

  @override
  String get renteVsCapitalRetirementAge => 'Retraite prévue à';

  @override
  String renteVsCapitalAgeYears(int age) {
    return '$age ans';
  }

  @override
  String renteVsCapitalAccrocheTaxEpuise(String taxDelta, int age) {
    return 'Décision importante : $taxDelta d\'impôts à $age ans.';
  }

  @override
  String renteVsCapitalAccrocheTax(String taxDelta) {
    return 'Décision : $taxDelta d\'impôts.';
  }

  @override
  String renteVsCapitalAccrocheEpuise(int age) {
    return 'Capital épuisé dès $age ans.';
  }

  @override
  String get renteVsCapitalHeroRente => 'RENTE';

  @override
  String get renteVsCapitalHeroCapital => 'CAPITAL';

  @override
  String get renteVsCapitalPerMonth => '/mois';

  @override
  String get renteVsCapitalForLife => 'à vie';

  @override
  String renteVsCapitalDuration(String duration) {
    return 'pendant $duration';
  }

  @override
  String get renteVsCapitalMicroRente => 'Montant fixe chaque mois.';

  @override
  String renteVsCapitalMicroCapital(String swr, String rendement) {
    return 'Tu retires $swr % par an à $rendement %.';
  }

  @override
  String renteVsCapitalSyntheseCapitalHigher(String delta) {
    return 'Le capital donne $delta/mois de plus.';
  }

  @override
  String renteVsCapitalSyntheseRenteHigher(String delta) {
    return 'La rente donne $delta/mois de plus.';
  }

  @override
  String get renteVsCapitalAvsEstimated => 'AVS estimée : ';

  @override
  String renteVsCapitalAvsAmount(String amount) {
    return '~$amount/mois';
  }

  @override
  String get renteVsCapitalAvsSupplementary =>
      ' supplémentaires (LAVS art. 29)';

  @override
  String get renteVsCapitalLifeExpectancy => 'Et si je vis jusqu\'à...';

  @override
  String get renteVsCapitalLifeExpectancyRef => 'Espérance de vie suisse';

  @override
  String get renteVsCapitalChartTitle => 'Capital restant vs rente cumulée';

  @override
  String get renteVsCapitalChartSubtitle => 'Capital vs Rente.';

  @override
  String get renteVsCapitalChartAxisLabel => 'Âge';

  @override
  String renteVsCapitalBeyondHorizon(int age) {
    return 'À $age ans : au-delà.';
  }

  @override
  String renteVsCapitalDeltaAtAge(int age) {
    return 'À $age ans : ';
  }

  @override
  String get renteVsCapitalDeltaAdvance => 'd\'avance';

  @override
  String get renteVsCapitalEducationalTitle => 'Ce que ça change';

  @override
  String get renteVsCapitalFiscalTitle => 'Fiscalité';

  @override
  String get renteVsCapitalFiscalLeftSubtitle => 'Imposée chaque année';

  @override
  String get renteVsCapitalFiscalRightSubtitle => 'Taxé une seule fois';

  @override
  String get renteVsCapitalFiscalOver30years => 'sur 30 ans';

  @override
  String get renteVsCapitalFiscalAtRetrait => 'au retrait (LIFD art. 38)';

  @override
  String renteVsCapitalFiscalCapitalSaves(String amount) {
    return 'Économie ~$amount d\'impôts.';
  }

  @override
  String renteVsCapitalFiscalRenteSaves(String amount) {
    return '~$amount d\'impôts en moins.';
  }

  @override
  String get renteVsCapitalInflationTitle => 'Inflation';

  @override
  String get renteVsCapitalInflationToday => 'Aujourd\'hui';

  @override
  String get renteVsCapitalInflationIn20Years => 'Dans 20 ans';

  @override
  String get renteVsCapitalInflationPurchasingPower => 'pouvoir d\'achat';

  @override
  String renteVsCapitalInflationBottomText(int percent) {
    return 'Rente non indexée. $percent % de moins.';
  }

  @override
  String get renteVsCapitalTransmissionTitle => 'Transmission';

  @override
  String get renteVsCapitalTransmissionLeftMarried => 'Ton conjoint reçoit';

  @override
  String get renteVsCapitalTransmissionLeftSingle => 'À ton décès';

  @override
  String renteVsCapitalTransmissionLeftValueMarried(String amount) {
    return '60 % = $amount/mois';
  }

  @override
  String get renteVsCapitalTransmissionLeftValueSingle => 'Rien';

  @override
  String get renteVsCapitalTransmissionLeftDetailMarried => 'LPP art. 19';

  @override
  String get renteVsCapitalTransmissionLeftDetailSingle => 'pour tes héritiers';

  @override
  String get renteVsCapitalTransmissionRightSubtitle =>
      'Tes héritiers reçoivent';

  @override
  String get renteVsCapitalTransmissionRightValue => '100 %';

  @override
  String get renteVsCapitalTransmissionRightDetail => 'du solde restant';

  @override
  String get renteVsCapitalTransmissionBottomMarried =>
      'Seul le conjoint reçoit 60 %.';

  @override
  String get renteVsCapitalTransmissionBottomSingle => 'Rien pour tes proches.';

  @override
  String get renteVsCapitalAffinerTitle => 'Affiner ta simulation';

  @override
  String get renteVsCapitalAffinerSubtitle => 'Pour creuser.';

  @override
  String get renteVsCapitalHypRendement => 'Rendement du capital';

  @override
  String get renteVsCapitalHypSwr => 'Taux de retrait annuel';

  @override
  String get renteVsCapitalHypInflation => 'Inflation';

  @override
  String get renteVsCapitalTornadoToggle => 'Diagramme de sensibilité';

  @override
  String get renteVsCapitalImpactTitle => 'Qu\'est-ce qui change le plus ?';

  @override
  String get renteVsCapitalImpactSubtitle => 'Paramètres les plus influents.';

  @override
  String get renteVsCapitalHypothesesTitle => 'Hypothèses';

  @override
  String get renteVsCapitalWarning => 'Avertissement';

  @override
  String renteVsCapitalSources(String sources) {
    return 'Sources : $sources';
  }

  @override
  String get renteVsCapitalRachatLabel => 'Rachat LPP annuel (CHF)';

  @override
  String renteVsCapitalRachatMax(String amount) {
    return 'max $amount';
  }

  @override
  String get renteVsCapitalRachatHint => '0 (optionnel)';

  @override
  String get renteVsCapitalRachatTooltip => 'Rachats LPP annuels.';

  @override
  String get renteVsCapitalEplLabel => 'Retrait EPL';

  @override
  String get renteVsCapitalEplHint => 'Montant (min 20\'000)';

  @override
  String get renteVsCapitalEplTooltip => 'Réduit ton avoir LPP.';

  @override
  String get renteVsCapitalEplLegalRef => 'LPP art. 30c — OPP2 art. 5';

  @override
  String get renteVsCapitalProfileAutoFill => 'Valeurs pré-remplies';

  @override
  String get frontalierAppBarTitle => 'Frontalier';

  @override
  String get frontalierTabImpots => 'Impôts';

  @override
  String get frontalierTab90Jours => '90 jours';

  @override
  String get frontalierTabCharges => 'Charges';

  @override
  String get frontalierCantonTravail => 'Canton de travail';

  @override
  String get frontalierSalaireBrut => 'Salaire brut mensuel';

  @override
  String get frontalierEtatCivil => 'État civil';

  @override
  String get frontalierCelibataire => 'Célibataire';

  @override
  String get frontalierMarie => 'Marié(e)';

  @override
  String get frontalierEnfantsCharge => 'Enfants à charge';

  @override
  String get frontalierTauxEffectif => 'Taux effectif';

  @override
  String get frontalierTotalAnnuel => 'Total annuel';

  @override
  String get frontalierParMois => 'par mois';

  @override
  String get frontalierQuasiResidentTitle => 'Quasi-résident (Genève)';

  @override
  String get frontalierQuasiResidentDesc =>
      'Si plus de 90% de tes revenus proviennent de Suisse.';

  @override
  String get frontalierTessinTitle => 'Tessin — régime spécial';

  @override
  String get frontalierEducationalTax => 'Frontaliers imposés à la source.';

  @override
  String get frontalierJoursBureau => 'Jours au bureau en Suisse';

  @override
  String get frontalierJoursHomeOffice => 'Jours en home office';

  @override
  String get frontalierJaugeRisque => 'JAUGE DE RISQUE';

  @override
  String get frontalierJoursHomeOfficeLabel => 'jours de home office';

  @override
  String get frontalierRiskLow => 'Pas de risque';

  @override
  String get frontalierRiskMedium => 'Zone d\'attention';

  @override
  String get frontalierRiskHigh => 'Risque fiscal';

  @override
  String frontalierDaysRemaining(int days) {
    return 'Il te reste $days jours';
  }

  @override
  String get frontalierRecommandation => 'RECOMMANDATION';

  @override
  String get frontalierEducational90Days => 'Seuil de 90 jours de télétravail.';

  @override
  String get frontalierChargesCh => 'Charges CH';

  @override
  String frontalierChargesCountry(String country) {
    return 'Charges $country';
  }

  @override
  String frontalierDuSalaire(String percent) {
    return '$percent% du salaire';
  }

  @override
  String frontalierChargesChMoins(String amount) {
    return 'Charges CH moins élevées : $amount/an';
  }

  @override
  String frontalierChargesChPlus(String amount) {
    return 'Charges CH plus élevées : +$amount/an';
  }

  @override
  String get frontalierAssuranceMaladie => 'ASSURANCE MALADIE';

  @override
  String get frontalierLamalTitle => 'LAMal (suisse)';

  @override
  String get frontalierLamalDesc => 'Obligatoire en CH.';

  @override
  String get frontalierCmuTitle => 'CMU/Sécu (France)';

  @override
  String get frontalierCmuDesc => 'Droit d\'option FR.';

  @override
  String get frontalierAssurancePriveeTitle => 'Assurance privée (DE/IT/AT)';

  @override
  String get frontalierAssurancePriveeDesc => 'PKV pour hauts revenus.';

  @override
  String get frontalierEducationalCharges => 'Cotisations sociales suisses.';

  @override
  String get frontalierPaysResidence => 'Pays de résidence';

  @override
  String get frontalierLeSavaisTu => 'Le savais-tu ?';

  @override
  String get concubinageAppBarTitle => 'Mariage vs Concubinage';

  @override
  String get concubinageTabComparateur => 'Comparateur';

  @override
  String get concubinageTabChecklist => 'Checklist';

  @override
  String get concubinageRevenu1 => 'Revenu 1';

  @override
  String get concubinageRevenu2 => 'Revenu 2';

  @override
  String get concubinagePatrimoineTotal => 'Patrimoine total';

  @override
  String get concubinageCanton => 'Canton';

  @override
  String get concubinageAvantages => 'avantages';

  @override
  String get concubinageMariage => 'Mariage';

  @override
  String get concubinageConcubinage => 'Concubinage';

  @override
  String get concubinageDetailFiscal => 'DÉTAIL FISCAL';

  @override
  String get concubinageImpots2Celibataires => 'Impôts 2 célibataires';

  @override
  String get concubinageImpotsMaries => 'Impôts mariés';

  @override
  String get concubinagePenaliteMariage => 'Pénalité mariage';

  @override
  String get concubinageBonusMariage => 'Bonus mariage';

  @override
  String get concubinageImpotSuccession => 'IMPÔT SUR LA SUCCESSION';

  @override
  String get concubinagePatrimoineTransmis => 'Patrimoine transmis';

  @override
  String get concubinageMarieExonere => 'CHF 0 (exonéré)';

  @override
  String concubinageConcubinTaux(String taux) {
    return 'Concubin-e (~$taux%)';
  }

  @override
  String concubinageWarningSuccession(String impot, String patrimoine) {
    return 'Impôt successoral de $impot sur $patrimoine.';
  }

  @override
  String get concubinageNeutralTitle => 'Aucune option n\'est meilleure';

  @override
  String get concubinageNeutralDesc => 'Dépend de ta situation.';

  @override
  String get concubinageChecklistIntro => 'Rien n\'est automatique.';

  @override
  String concubinageProtectionsCount(int count, int total) {
    return '$count/$total protections';
  }

  @override
  String get concubinageChecklist1Title => 'Rédiger un testament';

  @override
  String get concubinageChecklist1Desc => 'Partenaire n\'hérite de rien.';

  @override
  String get concubinageChecklist2Title => 'Clause bénéficiaire LPP';

  @override
  String get concubinageChecklist2Desc => 'Inscrire ton partenaire.';

  @override
  String get concubinageChecklist3Title => 'Convention de concubinage';

  @override
  String get concubinageChecklist3Desc => 'Contrat écrit.';

  @override
  String get concubinageChecklist4Title => 'Assurance-vie croisée';

  @override
  String get concubinageChecklist4Desc => 'Compenser l\'absence de rente.';

  @override
  String get concubinageChecklist5Title => 'Mandat d\'inaptitude';

  @override
  String get concubinageChecklist5Desc => 'Pouvoir de représentation.';

  @override
  String get concubinageChecklist6Title => 'Directives anticipées';

  @override
  String get concubinageChecklist6Desc => 'Volontés médicales.';

  @override
  String get concubinageChecklist7Title => 'Compte joint';

  @override
  String get concubinageChecklist7Desc => 'Dépenses partagées.';

  @override
  String get concubinageChecklist8Title => 'Bail commun';

  @override
  String get concubinageChecklist8Desc => 'Responsabilité solidaire.';

  @override
  String get concubinageDisclaimer => 'Informations éducatives.';

  @override
  String get concubinageCriteriaImpots => 'Impôts';

  @override
  String get concubinageCriteriaPenaliteFiscale => 'Pénalité fiscale';

  @override
  String get concubinageCriteriaBonusFiscal => 'Bonus fiscal';

  @override
  String get concubinageCriteriaAvantageux => 'Avantageux';

  @override
  String get concubinageCriteriaDesavantageux => 'Désavantageux';

  @override
  String get concubinageCriteriaHeritage => 'Héritage';

  @override
  String get concubinageCriteriaHeritageMarriage => 'Exonéré (CC art. 462)';

  @override
  String get concubinageCriteriaHeritageConcubinage => 'Impôt cantonal';

  @override
  String get concubinageCriteriaProtection => 'Protection décès';

  @override
  String get concubinageCriteriaProtectionMarriage => 'AVS + LPP survivant';

  @override
  String get concubinageCriteriaProtectionConcubinage =>
      'Aucune rente automatique';

  @override
  String get concubinageCriteriaFlexibilite => 'Flexibilité';

  @override
  String get concubinageCriteriaFlexibiliteMarriage => 'Procédure judiciaire';

  @override
  String get concubinageCriteriaFlexibiliteConcubinage =>
      'Séparation simplifiée';

  @override
  String get concubinageCriteriaPension => 'Pension alim.';

  @override
  String get concubinageCriteriaPensionMarriage => 'Protégée par le juge';

  @override
  String get concubinageCriteriaPensionConcubinage => 'Accord préalable';

  @override
  String get concubinageMarieExonereLabel => 'Marié·e';

  @override
  String get frontalierChargesTotal => 'Total';

  @override
  String get frontalierJoursSuffix => 'dias';

  @override
  String get conversationHistoryTitle => 'Histórico';

  @override
  String get conversationNew => 'Nova conversa';

  @override
  String get conversationEmptyTitle => 'Sem conversas';

  @override
  String get conversationEmptySubtitle => 'Comece a conversar com seu coach';

  @override
  String get conversationStartFirst => 'Iniciar conversa';

  @override
  String get conversationErrorTitle => 'Erro ao carregar';

  @override
  String get conversationRetry => 'Tentar novamente';

  @override
  String get conversationDeleteTitle => 'Eliminar esta conversa?';

  @override
  String get conversationDeleteConfirm => 'Esta ação é irreversível.';

  @override
  String get conversationDeleteCancel => 'Cancelar';

  @override
  String get conversationDeleteAction => 'Eliminar';

  @override
  String get conversationDateNow => 'Agora';

  @override
  String get conversationDateYesterday => 'Ontem';

  @override
  String conversationDateMinutesAgo(String minutes) {
    return 'Há $minutes min';
  }

  @override
  String conversationDateHoursAgo(String hours) {
    return 'Há ${hours}h';
  }

  @override
  String conversationDateFormatted(String day, String month) {
    return '$day $month';
  }

  @override
  String conversationMonth(String month) {
    String _temp0 = intl.Intl.selectLogic(
      month,
      {
        '1': 'janeiro',
        '2': 'fevereiro',
        '3': 'março',
        '4': 'abril',
        '5': 'maio',
        '6': 'junho',
        '7': 'julho',
        '8': 'agosto',
        '9': 'setembro',
        '10': 'outubro',
        '11': 'novembro',
        '12': 'dezembro',
        'other': 'mês',
      },
    );
    return '$_temp0';
  }

  @override
  String get achievementsTitle => 'Minhas conquistas';

  @override
  String get achievementsEmptyProfile =>
      'Completa o teu perfil para desbloquear conquistas.';

  @override
  String get achievementsDaysSingular => 'dia';

  @override
  String get achievementsDaysPlural => 'dias!';

  @override
  String achievementsRecord(int count) {
    return 'Recorde: $count dias';
  }

  @override
  String achievementsTotalDays(int count) {
    return '$count dias no total';
  }

  @override
  String get achievementsEngageCta =>
      'Faz uma ação hoje para manter a tua série!';

  @override
  String get achievementsEngagedToday => 'Participação registada hoje';

  @override
  String get achievementsBadgesTitle => 'Medalhas';

  @override
  String get achievementsBadgesSubtitle =>
      'Regularidade dos teus check-ins mensais';

  @override
  String achievementsBadgeMonths(int count) {
    return '$count meses';
  }

  @override
  String get achievementsMilestonesTitle => 'Marcos';

  @override
  String get achievementsMilestonesSubtitle => 'Os teus marcos financeiros';

  @override
  String get achievementsDisclaimer =>
      'As tuas conquistas são pessoais — MINT nunca as compara com outros.';

  @override
  String get achievementsDayMon => 'S';

  @override
  String get achievementsDayTue => 'T';

  @override
  String get achievementsDayWed => 'Q';

  @override
  String get achievementsDayThu => 'Q';

  @override
  String get achievementsDayFri => 'S';

  @override
  String get achievementsDaySat => 'S';

  @override
  String get achievementsDaySun => 'D';

  @override
  String get achievementsBadgeFirstStepLabel => 'Primeiro passo';

  @override
  String get achievementsBadgeFirstStepDesc =>
      'Fizeste o teu primeiro check-in.';

  @override
  String get achievementsBadgeRegulierLabel => 'Regular';

  @override
  String get achievementsBadgeRegulierDesc =>
      '3 meses consecutivos de check-in.';

  @override
  String get achievementsBadgeConstantLabel => 'Constante';

  @override
  String get achievementsBadgeConstantDesc => '6 meses sem interrupção.';

  @override
  String get achievementsBadgeDisciplineLabel => 'Disciplinado/a';

  @override
  String get achievementsBadgeDisciplineDesc =>
      '12 meses consecutivos — um ano completo.';

  @override
  String get achievementsCatPatrimoine => 'Património';

  @override
  String get achievementsCatPrevoyance => 'Previdência';

  @override
  String get achievementsCatSecurite => 'Segurança';

  @override
  String get achievementsCatScoreFri => 'Pontuação FRI';

  @override
  String get achievementsCatEngagement => 'Compromisso';

  @override
  String get achievementsFriAbove50Label => 'FRI 50+';

  @override
  String get achievementsFriAbove50Desc =>
      'Alcançar uma pontuação de solidez de 50/100';

  @override
  String get achievementsFriAbove70Label => 'FRI 70+';

  @override
  String get achievementsFriAbove70Desc =>
      'Alcançar uma pontuação de solidez de 70/100';

  @override
  String get achievementsFriAbove85Label => 'FRI 85+';

  @override
  String get achievementsFriAbove85Desc => 'Zona de excelência — 85/100';

  @override
  String get achievementsFriImproved10Label => 'Progresso +10';

  @override
  String get achievementsFriImproved10Desc => 'Ganhar 10 pontos FRI num mês';

  @override
  String get achievementsStreak6MonthsLabel => 'Série 6 meses';

  @override
  String get achievementsStreak6MonthsDesc =>
      '6 meses consecutivos de check-in';

  @override
  String get achievementsStreak12MonthsLabel => 'Série 12 meses';

  @override
  String get achievementsStreak12MonthsDesc =>
      '12 meses consecutivos — um ano completo';

  @override
  String get achievementsFirstArbitrageLabel => 'Primeira comparação';

  @override
  String get achievementsFirstArbitrageDesc =>
      'Completar a tua primeira simulação de comparação';

  @override
  String get nudgeSalaryTitle => 'Dia de salário!';

  @override
  String get nudgeSalaryMessage =>
      'Pensaste na tua transferência 3a este mês? Cada mês conta para a tua previdência.';

  @override
  String get nudgeSalaryAction => 'Ver o meu 3a';

  @override
  String get nudgeTaxTitle => 'Declaração fiscal';

  @override
  String get nudgeTaxMessage =>
      'Verifica o prazo da declaração fiscal no teu cantão. Já verificaste as tuas deduções 3a e LPP?';

  @override
  String get nudgeTaxAction => 'Simular os meus impostos';

  @override
  String get nudge3aTitle => 'Reta final para o teu 3a';

  @override
  String get nudge3aMessageLastDay =>
      'É o último dia para contribuir para o teu 3a!';

  @override
  String nudge3aMessage(String days, String limit, String year) {
    return 'Restam $days dia(s) para contribuir até $limit CHF e reduzir os teus impostos $year.';
  }

  @override
  String get nudge3aAction => 'Calcular a minha poupança';

  @override
  String nudgeBirthdayTitle(String age) {
    return 'Fazes $age anos este ano!';
  }

  @override
  String get nudgeBirthdayAction => 'Ver o meu painel';

  @override
  String get nudgeAnniversaryTitle => 'Já 1 ano juntos!';

  @override
  String get nudgeAnniversaryMessage =>
      'Usas o MINT há um ano. É o momento ideal para atualizar o teu perfil e medir o teu progresso.';

  @override
  String get nudgeAnniversaryAction => 'Atualizar o meu perfil';

  @override
  String get nudgeLppStartTitle => 'Início das contribuições LPP';

  @override
  String get nudgeLppChangeTitle => 'Mudança de escalão LPP';

  @override
  String nudgeLppStartMessage(String rate) {
    return 'As tuas contribuições LPP de velhice começam este ano ($rate %). É o início da tua previdência profissional.';
  }

  @override
  String nudgeLppChangeMessage(String age, String rate) {
    return 'Aos $age anos, o teu crédito de velhice sobe para $rate %. Pode ser um bom momento para considerar um resgate LPP.';
  }

  @override
  String get nudgeLppAction => 'Explorar o resgate';

  @override
  String get nudgeWeeklyTitle => 'Já faz algum tempo!';

  @override
  String get nudgeWeeklyMessage =>
      'A tua situação financeira evolui a cada semana. Dedica 2 minutos a verificar o teu painel.';

  @override
  String get nudgeWeeklyAction => 'Ver o meu Pulse';

  @override
  String get nudgeStreakTitle => 'A tua série está em risco!';

  @override
  String nudgeStreakMessage(String count) {
    return 'Tens uma série de $count dias. Uma pequena ação hoje basta para a manter.';
  }

  @override
  String get nudgeStreakAction => 'Continuar a minha série';

  @override
  String get nudgeGoalTitle => 'O teu objetivo aproxima-se';

  @override
  String nudgeGoalMessage(String desc, String days) {
    return '«$desc» — restam $days dia(s). Fizeste progressos neste tema?';
  }

  @override
  String get nudgeGoalAction => 'Falar com o coach';

  @override
  String get nudgeFhsTitle => 'A tua pontuação de saúde desceu';

  @override
  String nudgeFhsMessage(String drop) {
    return 'O teu Financial Health Score perdeu $drop pontos. Vamos ver o que pode explicar esta mudança.';
  }

  @override
  String get nudgeFhsAction => 'Compreender a descida';

  @override
  String get recapEngagement => 'Envolvimento';

  @override
  String get recapBudget => 'Orçamento';

  @override
  String get recapGoals => 'Objetivos';

  @override
  String get recapFhs => 'Pontuação financeira';

  @override
  String get recapOnTrack => 'Orçamento dentro do esperado esta semana.';

  @override
  String get recapOverBudget =>
      'Orçamento ultrapassado esta semana — verifica as principais rubricas.';

  @override
  String get recapUnderBudget =>
      'Gastaste menos do que previsto — bom controlo!';

  @override
  String get recapNoData => 'Dados de orçamento insuficientes esta semana.';

  @override
  String recapDaysActive(String count) {
    return '$count dia(s) ativo(s) esta semana.';
  }

  @override
  String recapGoalsActive(String count) {
    return '$count objetivo(s) em curso.';
  }

  @override
  String recapFhsUp(String delta) {
    return 'Pontuação subiu +$delta pontos.';
  }

  @override
  String recapFhsDown(String delta) {
    return 'Pontuação desceu $delta pontos.';
  }

  @override
  String get recapFhsStable => 'Pontuação estável esta semana.';

  @override
  String get decesProcheTitre => 'Falecimento de um familiar';

  @override
  String get decesProcheMoisRepudiation =>
      'meses para aceitar ou repudiar a sucessão (CC art. 567)';

  @override
  String get decesProche48hTitre => 'Urgente: primeiras 48 horas';

  @override
  String get decesProche48hActe => 'Obter a certidão de óbito no registo civil';

  @override
  String get decesProche48hBanque =>
      'Informar o banco — as contas são bloqueadas após notificação';

  @override
  String get decesProche48hAssurance =>
      'Contactar as seguradoras (vida, saúde, lar)';

  @override
  String get decesProche48hEmployeur =>
      'Notificar o empregador do falecido sobre o saldo salarial';

  @override
  String get decesProcheSituation => 'A tua situação';

  @override
  String get decesProcheLienParente => 'Parentesco com o falecido';

  @override
  String get decesProcheLienConjoint => 'Cônjuge';

  @override
  String get decesProcheLienParent => 'Pai/Mãe';

  @override
  String get decesProcheLienEnfant => 'Filho/a';

  @override
  String get decesProcheFortune => 'Património estimado do falecido';

  @override
  String get decesProcheCanton => 'Cantão';

  @override
  String get decesProchTestament => 'Existe um testamento';

  @override
  String get decesProchTimelineTitre => 'Cronologia da sucessão';

  @override
  String get decesProchTimeline1Titre => 'Certidão de óbito e bloqueio';

  @override
  String get decesProchTimeline1Desc =>
      'O registo civil emite a certidão. As contas bancárias são bloqueadas.';

  @override
  String get decesProchTimeline2Titre => 'Inventário e notário';

  @override
  String get decesProchTimeline2Desc =>
      'O notário abre a sucessão e estabelece o inventário de bens.';

  @override
  String get decesProchTimeline3Titre => 'Prazo de repúdio';

  @override
  String get decesProchTimeline3Desc =>
      '3 meses para aceitar ou repudiar (CC art. 567). Após este prazo, a sucessão é aceite.';

  @override
  String get decesProchTimeline4Titre => 'Partilha e impostos';

  @override
  String get decesProchTimeline4Desc =>
      'Declaração de sucessão e pagamento do imposto cantonal (se aplicável).';

  @override
  String get decesProchebeneficiairesTitre => 'Beneficiários LPP e 3a';

  @override
  String get decesProchebeneficiairesLpp => 'Capital LPP do falecido';

  @override
  String get decesProchebeneficiaires3a => 'Capital 3a do falecido';

  @override
  String get decesProchebeneficiairesNote =>
      'A ordem dos beneficiários LPP é definida pelo regulamento da caixa (OPP2 art. 48). O 3a segue a OPP3 art. 2.';

  @override
  String get decesProchImpactFiscalTitre => 'Impacto fiscal';

  @override
  String decesProchImpactFiscalExempt(String canton) {
    return 'No cantão $canton, o cônjuge sobrevivente está isento do imposto de sucessão.';
  }

  @override
  String decesProchImpactFiscalTaxe(String canton) {
    return 'No cantão $canton, os herdeiros estão sujeitos ao imposto cantonal de sucessão. A taxa varia conforme o grau de parentesco.';
  }

  @override
  String get decesProchActionsTitre => 'Próximos passos';

  @override
  String get decesProchAction1 =>
      'Reunir documentos: certidão de óbito, testamento, certificados LPP e 3a';

  @override
  String get decesProchAction2 =>
      'Consultar um notário para o inventário sucessório';

  @override
  String get decesProchAction3 =>
      'Verificar os beneficiários LPP e 3a junto das caixas';

  @override
  String get decesProchDisclaimer =>
      'Ferramenta educativa — não constitui aconselhamento jurídico ou fiscal (LSFin). Cada sucessão é única: consulta um notário ou especialista. Fontes: CC art. 457-640, OPP2 art. 48, OPP3 art. 2.';

  @override
  String get demenagementTitre => 'Mudança cantonal';

  @override
  String get demenagementChiffreChocSousTitre =>
      'economia (ou custo adicional) anual estimado';

  @override
  String demenagementChiffreChocDetail(String depart, String arrivee) {
    return 'Ao mudar de $depart para $arrivee (impostos + seguro de saúde)';
  }

  @override
  String get demenagementSituation => 'A tua situação';

  @override
  String get demenagementCantonDepart => 'Cantão atual';

  @override
  String get demenagementCantonArrivee => 'Cantão de destino';

  @override
  String get demenagementRevenu => 'Rendimento bruto anual';

  @override
  String get demenagementCelibataire => 'Solteiro/a';

  @override
  String get demenagementMarie => 'Casado/a';

  @override
  String get demenagementFiscalTitre => 'Comparação fiscal';

  @override
  String get demenagementEconomieFiscale => 'Economia fiscal estimada';

  @override
  String get demenagementLamalTitre => 'Prémios de seguro de saúde';

  @override
  String get demenagementChecklistTitre => 'Checklist de mudança';

  @override
  String get demenagementChecklist1 =>
      'Notificar a partida ao município de origem (8 dias antes)';

  @override
  String get demenagementChecklist2 =>
      'Registar-se no novo município (dentro de 8 dias)';

  @override
  String get demenagementChecklist3 =>
      'Mudar de seguro de saúde ou atualizar a região de prémio';

  @override
  String get demenagementChecklist4 =>
      'Adaptar a declaração fiscal (tributação a 31.12)';

  @override
  String get demenagementChecklist5 =>
      'Verificar os abonos de família cantonais';

  @override
  String get demenagementDisclaimer =>
      'Ferramenta educativa — não constitui aconselhamento fiscal (LSFin). Os valores são estimativas baseadas em índices cantonais simplificados. Consulta um especialista. Fontes: LIFD, LAMal, tabelas cantonais 2025.';

  @override
  String get docScanAppBarTitle => 'DIGITALIZAR UM DOCUMENTO';

  @override
  String get docScanHeaderTitle => 'Melhora a precisão do teu perfil';

  @override
  String get docScanHeaderSubtitle =>
      'Fotografa um documento financeiro e extraímos os números para ti. Verificas cada valor antes de confirmar.';

  @override
  String get docScanDocumentType => 'Tipo de documento';

  @override
  String docScanConfidencePoints(int points) {
    return '+$points pontos de confiança';
  }

  @override
  String get docScanFromGallery => 'Da galeria';

  @override
  String get docScanPasteOcrText => 'Colar texto OCR';

  @override
  String get docScanUseExample => 'Usar um exemplo de teste';

  @override
  String get docScanPrivacyNote =>
      'A imagem é analisada localmente (OCR no dispositivo). Se usares a análise Vision IA, a imagem é enviada ao teu fornecedor IA pela tua própria chave API. Apenas os valores confirmados são guardados no teu perfil.';

  @override
  String get docScanCameraError => 'Impossível abrir a câmara. Usa a galeria.';

  @override
  String get docScanEmptyTextFile => 'O ficheiro de texto está vazio.';

  @override
  String get docScanFileUnreadableTitle => 'Ficheiro não utilizável';

  @override
  String get docScanFileUnreadableMessage =>
      'Não conseguimos ler este ficheiro diretamente do teu dispositivo. Tira uma foto do documento ou cola um texto OCR.';

  @override
  String docScanImportError(String error) {
    return 'Impossível importar o ficheiro: $error';
  }

  @override
  String get docScanOcrNotDetectedTitle => 'Texto não detetado';

  @override
  String get docScanOcrNotDetectedMessage =>
      'Não conseguimos ler texto suficiente da foto.';

  @override
  String get docScanPhotoAnalysisTitle => 'Análise da foto indisponível';

  @override
  String get docScanPhotoAnalysisMessage =>
      'Não conseguimos extrair o texto automaticamente. Tenta novamente com uma foto mais nítida ou cola o texto OCR.';

  @override
  String get docScanNoFieldRecognized =>
      'Nenhum campo reconhecido automaticamente';

  @override
  String get docScanNoFieldHint =>
      'Adiciona ou corrige o texto OCR para melhorar a análise, depois tenta novamente.';

  @override
  String docScanParsingError(String error) {
    return 'Parsing impossível para este documento: $error';
  }

  @override
  String get docScanOcrPasteHint => 'Cola aqui o texto OCR bruto…';

  @override
  String get docScanPdfDetected => 'PDF detetado';

  @override
  String get docScanPdfCannotRead =>
      'Impossível ler este PDF diretamente neste dispositivo. Tira uma foto do documento ou cola um texto OCR.';

  @override
  String get docScanPdfAnalysisUnavailable => 'Análise PDF indisponível';

  @override
  String get docScanPdfNotParsed =>
      'O PDF não pôde ser analisado automaticamente. Podes tirar uma foto (recomendado) ou colar um texto OCR.';

  @override
  String get docScanPdfNotAvailable =>
      'O parsing PDF não está disponível neste contexto. Tira uma foto ou cola um texto OCR.';

  @override
  String get docScanPdfOptimizedLpp =>
      'Por agora, o parsing PDF automático está otimizado principalmente para certificados LPP. Tira uma foto do documento.';

  @override
  String get docScanPdfTypeUnsupported =>
      'Tipo de documento não suportado para parsing PDF.';

  @override
  String get docScanPdfNoData => 'Nenhum dado útil foi extraído deste PDF.';

  @override
  String docScanPdfBackendError(String error) {
    return 'Erro do backend durante o parsing PDF: $error';
  }

  @override
  String get docScanBackendDisclaimer =>
      'Dados extraídos automaticamente: verifica cada valor antes de confirmar.';

  @override
  String get docScanBackendDisclaimerShort =>
      'Verifica os montantes antes de confirmar. Ferramenta educativa (LSFin).';

  @override
  String get docScanVisionAnalyze => 'Analisar com Vision IA';

  @override
  String get docScanVisionDisclaimer =>
      'A imagem será enviada ao teu fornecedor IA pela tua chave API.';

  @override
  String get docScanVisionNoFields =>
      'A IA não conseguiu extrair campos deste documento.';

  @override
  String get docScanVisionDefaultDisclaimer =>
      'Dados extraídos por IA: verifica cada valor. Ferramenta educativa, não constitui um conselho (LSFin).';

  @override
  String get docScanVisionConfigError =>
      'Configura uma chave API nas definições do Coach.';

  @override
  String docScanVisionError(String error) {
    return 'Erro Vision IA: $error';
  }

  @override
  String get docScanLabelLppTotal => 'Total LPP';

  @override
  String get docScanLabelObligatoire => 'Parte obrigatória';

  @override
  String get docScanLabelSurobligatoire => 'Parte supraobrigatória';

  @override
  String get docScanLabelTauxConvOblig => 'Taxa de conversão obrigatória';

  @override
  String get docScanLabelTauxConvSuroblig =>
      'Taxa de conversão supraobrigatória';

  @override
  String get docScanLabelRachatMax => 'Resgate máximo';

  @override
  String get docScanLabelSalaireAssure => 'Salário segurado';

  @override
  String get docScanLabelTauxRemuneration => 'Taxa de remuneração';

  @override
  String get docImpactTitle => 'O teu perfil é mais preciso';

  @override
  String docImpactSubtitle(String docType) {
    return 'Os valores do teu $docType foram integrados nas tuas projeções.';
  }

  @override
  String get docImpactConfidenceLabel => '% confiança';

  @override
  String docImpactDeltaPoints(int points) {
    return '+$points pontos de confiança';
  }

  @override
  String get docImpactChiffreChocTitle => 'Cifra chave recalculada';

  @override
  String docImpactLppRealAmount(String oblig) {
    return 'de ativos LPP reais (dos quais $oblig obrigatórios)';
  }

  @override
  String docImpactRenteOblig(String amount) {
    return 'Renda obrigatória a 6.8%: CHF $amount/ano';
  }

  @override
  String docImpactSurobligWithRate(String suroblig, String rate, String rente) {
    return 'Parte supraobrigatória (CHF $suroblig) a $rate% = CHF $rente/ano';
  }

  @override
  String docImpactSurobligNoRate(String suroblig) {
    return 'Parte supraobrigatória (CHF $suroblig) = taxa de conversão livre da caixa';
  }

  @override
  String docImpactAvsYears(int years) {
    return '$years anos de contribuição';
  }

  @override
  String docImpactAvsCompletion(int maxYears, int pct) {
    return 'de $maxYears necessários para uma renda AVS completa ($pct%)';
  }

  @override
  String get docImpactGenericMessage =>
      'As tuas projeções baseiam-se agora em valores reais.';

  @override
  String get docImpactFieldsUpdated => 'Campos atualizados';

  @override
  String get docImpactReturnDashboard => 'Voltar ao dashboard';

  @override
  String get docImpactDisclaimer =>
      'Ferramenta educativa — não constitui conselho de previdência. Verifica sempre com o certificado original (LSFin).';

  @override
  String get extractionReviewAppBar => 'VERIFICAÇÃO';

  @override
  String get extractionReviewTitle => 'Verifica os valores extraídos';

  @override
  String extractionReviewSubtitle(int count, String reviewPart) {
    return '$count campos detetados$reviewPart. Podes modificar cada valor antes de confirmar.';
  }

  @override
  String extractionReviewNeedsReview(int count) {
    return ' dos quais $count a verificar';
  }

  @override
  String extractionReviewConfidence(int pct) {
    return 'Confiança de extração: $pct%';
  }

  @override
  String extractionReviewSourcePrefix(String text) {
    return 'Lido: \"$text\"';
  }

  @override
  String get extractionReviewConfirmAll => 'Confirmar tudo';

  @override
  String extractionReviewEditTitle(String label) {
    return 'Modificar: $label';
  }

  @override
  String extractionReviewCurrentValue(String value) {
    return 'Valor atual: $value';
  }

  @override
  String get extractionReviewNewValue => 'Novo valor';

  @override
  String get extractionReviewCancel => 'Cancelar';

  @override
  String get extractionReviewValidate => 'Validar';

  @override
  String get extractionReviewEditTooltip => 'Modificar';

  @override
  String get firstSalaryFilmTitle => 'O filme do teu primeiro salário';

  @override
  String firstSalaryFilmSubtitle(String amount) {
    return 'CHF $amount bruto — 5 atos para entender tudo.';
  }

  @override
  String get firstSalaryAct1Label => '1 · Bruto→Líquido';

  @override
  String get firstSalaryAct2Label => '2 · Invisível';

  @override
  String get firstSalaryAct3Label => '3 · 3a';

  @override
  String get firstSalaryAct4Label => '4 · LAMal';

  @override
  String get firstSalaryAct5Label => '5 · Ação';

  @override
  String get firstSalaryAct1Title => 'O banho frio';

  @override
  String firstSalaryAct1Quote(String amount) {
    return '$amount CHF desaparecem. Mas não se perdem — é o teu futuro.';
  }

  @override
  String firstSalaryGross(String amount) {
    return 'Bruto: CHF $amount';
  }

  @override
  String firstSalaryNet(String amount) {
    return 'Líquido: CHF $amount';
  }

  @override
  String firstSalaryNetPercent(int pct) {
    return '$pct% líquido';
  }

  @override
  String get firstSalaryAct2Title => 'O dinheiro invisível';

  @override
  String firstSalaryAct2Quote(String amount) {
    return 'O teu salário real é CHF $amount. O teu empregador paga muito mais do que pensas.';
  }

  @override
  String get firstSalaryVisibleNet => '🌊 Visível: o teu salário líquido';

  @override
  String get firstSalaryVisibleNetSub => 'O que recebes';

  @override
  String get firstSalaryCotisations => '💧 As tuas cotizações';

  @override
  String get firstSalaryCotisationsSub => 'Deduzidas do bruto';

  @override
  String get firstSalaryEmployerCotisations => '🏔️ Cotizações do empregador';

  @override
  String get firstSalaryEmployerCotisationsSub =>
      'Invisíveis no recibo de vencimento';

  @override
  String get firstSalaryTotalEmployerCost => 'Custo total empregador';

  @override
  String get firstSalaryAct3Title => 'O presente fiscal 3a';

  @override
  String firstSalaryAct3Quote(String amount) {
    return 'CHF $amount/mês → potencialmente milionário. Começa agora.';
  }

  @override
  String get firstSalaryAt30 => 'Aos 30';

  @override
  String get firstSalaryAt40 => 'Aos 40';

  @override
  String get firstSalaryAt65 => 'Aos 65';

  @override
  String get firstSalary3aInfo =>
      '💰 Teto 2026: CHF 7\'258/ano · Dedução fiscal direta · OPP3 art. 7';

  @override
  String get firstSalaryAct4Title => 'A armadilha LAMal';

  @override
  String get firstSalaryAct4Quote =>
      'A franquia barata pode custar-te caro se ficares doente.';

  @override
  String get firstSalaryFranchise300Advice => 'Recomendado se doenças crónicas';

  @override
  String get firstSalaryFranchise1500Advice => 'Bom compromisso · Recomendado';

  @override
  String get firstSalaryFranchise2500Advice =>
      'Poupa no prémio · Se tens boa saúde';

  @override
  String firstSalaryFranchiseLabel(String label) {
    return 'Franquia $label';
  }

  @override
  String firstSalaryFranchisePrime(String amount) {
    return '−CHF $amount/mês prémio';
  }

  @override
  String get firstSalaryLamalInfo =>
      '💡 LAMal art. 64 — Franquia anual escolhida, renovável cada ano.';

  @override
  String get firstSalaryAct5Title => 'A tua checklist de arranque';

  @override
  String get firstSalaryAct5Quote => '5 ações. É tudo. Começa esta semana.';

  @override
  String get firstSalaryWeek1 => 'Semana 1';

  @override
  String get firstSalaryWeek2 => 'Semana 2';

  @override
  String get firstSalaryBefore31Dec => 'Antes de 31.12';

  @override
  String get firstSalaryTask1 => 'Abrir uma conta 3a (banco ou fintech)';

  @override
  String get firstSalaryTask2 =>
      'Configurar uma transferência automática mensal';

  @override
  String get firstSalaryTask3 =>
      'Escolher a franquia LAMal (recomendado: CHF 1\'500)';

  @override
  String get firstSalaryTask4 =>
      'Verificar o seguro RC privado (aprox. CHF 100/ano)';

  @override
  String get firstSalaryTask5 =>
      'Depositar o máximo 3a antes de 31 de dezembro';

  @override
  String get firstSalaryBadgeTitle => 'Primeiro passo financeiro';

  @override
  String get firstSalaryBadgeSubtitle =>
      'Agora sabes o que 90% das pessoas nunca sabem.';

  @override
  String get firstSalaryDisclaimer =>
      'Ferramenta educativa · não constitui conselho financeiro (LSFin). Fonte: LAVS art. 3, LPP art. 7, LACI art. 3, OPP3 art. 7 (3a 7\'258 CHF/ano). Taxas de cotização indicativas 2026. Projeção 3a: rendimento hipotético 4%/ano.';

  @override
  String get benchmarkAppBarTitle => 'Referências cantonais';

  @override
  String get benchmarkOptInTitle => 'Ativar referências cantonais';

  @override
  String get benchmarkOptInSubtitle =>
      'Compara a tua situação com ordens de grandeza das estatísticas federais (OFS).';

  @override
  String get benchmarkExplanationTitle => 'Referências, não um ranking';

  @override
  String get benchmarkExplanationBody =>
      'Ativa esta funcionalidade para situar a tua situação financeira face a perfis semelhantes no teu cantão. São ordens de grandeza de estatísticas federais anonimizadas (OFS). Sem ranking, sem comparação social.';

  @override
  String get benchmarkNoProfile =>
      'Completa o teu perfil para aceder às referências cantonais.';

  @override
  String benchmarkNoData(String canton, String ageGroup) {
    return 'Sem dados disponíveis para o cantão $canton (faixa $ageGroup).';
  }

  @override
  String benchmarkSimilarProfiles(String canton, String ageGroup) {
    return 'Perfis semelhantes: $canton, faixa $ageGroup';
  }

  @override
  String benchmarkSourceLabel(String source) {
    return 'Fonte: $source';
  }

  @override
  String get benchmarkWithinRange => 'A tua situação situa-se na faixa típica.';

  @override
  String get benchmarkAboveRange =>
      'A tua situação está acima da faixa típica.';

  @override
  String get benchmarkBelowRange =>
      'A tua situação está abaixo da faixa típica.';

  @override
  String benchmarkTypicalRange(String low, String high) {
    return 'Faixa típica: $low – $high';
  }

  @override
  String get tabPulse => 'Pulse';

  @override
  String get tabMint => 'Mint';

  @override
  String get authGateDocScanTitle => 'Protege os teus documentos';

  @override
  String get authGateDocScanMessage =>
      'Os teus certificados contêm dados sensíveis. Cria uma conta para os proteger com encriptação ponto a ponto.';

  @override
  String get authGateSalaryTitle => 'Protege os teus dados financeiros';

  @override
  String get authGateSalaryMessage =>
      'O teu salário e os teus dados financeiros merecem um cofre seguro.';

  @override
  String get authGateCoachTitle => 'O coach precisa de te conhecer';

  @override
  String get authGateCoachMessage =>
      'Para te dar respostas personalizadas, o coach precisa de uma conta.';

  @override
  String get authGateGoalTitle => 'Acompanha o teu progresso';

  @override
  String get authGateGoalMessage =>
      'Para acompanhar os teus objetivos ao longo do tempo, cria a tua conta.';

  @override
  String get authGateSimTitle => 'Guarda a tua simulação';

  @override
  String get authGateSimMessage =>
      'Para encontrar esta simulação mais tarde, cria a tua conta.';

  @override
  String get authGateByokTitle => 'Protege a tua chave API';

  @override
  String get authGateByokMessage =>
      'A tua chave API será encriptada no teu espaço seguro.';

  @override
  String get authGateCoupleTitle => 'O modo casal requer uma conta';

  @override
  String get authGateCoupleMessage =>
      'Para convidar o·a teu·tua parceiro·a, cria primeiro a tua conta pessoal.';

  @override
  String get authGateProfileTitle => 'Enriquece o teu perfil em segurança';

  @override
  String get authGateProfileMessage =>
      'Quanto mais enriqueceres o teu perfil, mais precisas serão as tuas projeções. Protege os teus dados.';

  @override
  String get authGateCreateAccount => 'Criar a minha conta';

  @override
  String get authGateLogin => 'Já tenho uma conta';

  @override
  String get authGatePrivacyNote =>
      'Os teus dados ficam no teu dispositivo e estão encriptados.';

  @override
  String get budgetTaxProvisionNotProvided =>
      'Provisão impostos (não indicado)';

  @override
  String get budgetHealthInsuranceNotProvided =>
      'Seguro saúde (LAMal) (não indicado)';

  @override
  String get budgetOtherFixedCosts => 'Outros custos fixos';

  @override
  String get budgetOtherFixedCostsNotProvided =>
      'Outros custos fixos (não indicado)';

  @override
  String get budgetQualityProvided => 'inserido';

  @override
  String get budgetBannerMissing =>
      'Algumas despesas ainda estão em falta. Completa o teu diagnóstico para um orçamento mais fiável.';

  @override
  String get budgetBannerEstimated =>
      'Este orçamento inclui estimativas (impostos/LAMal). Insere os teus valores reais.';

  @override
  String get budgetCompleteMyData => 'Completar os meus dados →';

  @override
  String get budgetEmergencyFundTitle => 'Fundo de emergência';

  @override
  String get budgetGoalReached => 'Objetivo alcançado';

  @override
  String get budgetOnTrack => 'No bom caminho';

  @override
  String get budgetToReinforce => 'A reforçar';

  @override
  String budgetMonthsCovered(String months) {
    return '$months meses cobertos';
  }

  @override
  String budgetTargetMonths(String target) {
    return 'Alvo: $target meses';
  }

  @override
  String get budgetEmergencyProtected =>
      'Estás protegido contra imprevistos. Continua assim.';

  @override
  String budgetEmergencySaveMore(String target) {
    return 'Poupa pelo menos $target meses de despesas para te protegeres contra imprevistos.';
  }

  @override
  String get budgetExploreAlso => 'Explorar também';

  @override
  String get budgetDebtRatio => 'Rácio de endividamento';

  @override
  String get budgetDebtRatioSubtitle => 'Avaliar a tua situação de dívida';

  @override
  String get budgetRepaymentPlan => 'Plano de reembolso';

  @override
  String get budgetRepaymentPlanSubtitle => 'Estratégia para sair da dívida';

  @override
  String get budgetHelpResources => 'Recursos de ajuda';

  @override
  String get budgetHelpResourcesSubtitle => 'Onde encontrar ajuda na Suíça';

  @override
  String get budgetCtaEvaluate => 'Avaliar';

  @override
  String get budgetCtaPlan => 'Planear';

  @override
  String get budgetCtaDiscover => 'Descobrir';

  @override
  String get budgetDisclaimerImportant => 'IMPORTANTE:';

  @override
  String get budgetDisclaimerBased =>
      '• Os montantes baseiam-se nas informações declaradas.';

  @override
  String get refreshReturnToDashboard => 'Voltar ao painel';

  @override
  String get refreshOptionNone => 'Nenhum';

  @override
  String get refreshOptionPurchase => 'Compra';

  @override
  String get refreshOptionSale => 'Venda';

  @override
  String get refreshOptionRefinancing => 'Refinanciamento';

  @override
  String get refreshOptionMarriage => 'Casamento';

  @override
  String get refreshOptionBirth => 'Nascimento';

  @override
  String get refreshOptionDivorce => 'Divórcio';

  @override
  String get refreshOptionDeath => 'Falecimento';

  @override
  String get refreshProfileUpdated => 'Perfil atualizado!';

  @override
  String refreshScoreUp(String delta) {
    return 'A tua pontuação subiu $delta pontos!';
  }

  @override
  String refreshScoreDown(String delta) {
    return 'A tua pontuação desceu $delta pontos — verifiquemos juntos';
  }

  @override
  String get refreshScoreStable =>
      'A tua pontuação está estável — continua assim!';

  @override
  String get refreshBefore => 'Antes';

  @override
  String get refreshAfter => 'Depois';

  @override
  String get chiffreChocDisclaimer =>
      'Ferramenta educativa — não constitui conselho financeiro (LSFin). Fontes: LAVS art. 34, LPP art. 14-16, OPP3 art. 7.';

  @override
  String get chiffreChocAction => 'O que posso fazer?';

  @override
  String get chiffreChocEnrich => 'Refinar o meu perfil';

  @override
  String chiffreChocConfidence(String count) {
    return 'Estimativa baseada em $count informações. Quanto mais precisares, mais fiável.';
  }

  @override
  String get chatErrorInvalidKey =>
      'A tua chave API parece inválida ou expirada. Verifica-a nas definições.';

  @override
  String get chatErrorRateLimit =>
      'Limite de pedidos atingido. Tenta novamente em alguns instantes.';

  @override
  String get chatErrorTechnical => 'Erro técnico. Tenta novamente mais tarde.';

  @override
  String get chatErrorConnection =>
      'Erro de ligação. Verifica a tua ligação à internet ou a chave API.';

  @override
  String get chatCoachMint => 'Coach MINT';

  @override
  String get chatEmptyStateMessage =>
      'Completa o teu diagnóstico para falar com o teu coach';

  @override
  String get chatStartButton => 'Começar';

  @override
  String get chatDisclaimer =>
      'Ferramenta educativa — as respostas não constituem conselho financeiro. LSFin.';

  @override
  String get chatTooltipHistory => 'Histórico';

  @override
  String get chatTooltipExport => 'Exportar conversa';

  @override
  String get chatTooltipSettings => 'Definições IA';

  @override
  String get slmChooseModel => 'Escolhe o teu modelo';

  @override
  String get slmTwoSizesAvailable =>
      'Dois tamanhos disponíveis consoante o teu dispositivo';

  @override
  String get slmRecommended => 'Recomendado';

  @override
  String get slmDownloadFailedMessage =>
      'O download falhou. Verifica a tua ligação WiFi e o espaço disponível.';

  @override
  String get slmInitError =>
      'Erro de inicialização do modelo. Verifica se o teu dispositivo é compatível.';

  @override
  String get slmInitializing => 'A inicializar...';

  @override
  String get slmInitEngine => 'Inicializar motor';

  @override
  String get disabilityYourSituation => 'A tua situação';

  @override
  String get disabilityGrossMonthly => 'Salário bruto mensal';

  @override
  String get disabilityYourAge => 'A tua idade';

  @override
  String get disabilityAvailableSavings => 'Poupança disponível';

  @override
  String get disabilityHasIjm => 'Tenho seguro IJM através do meu empregador';

  @override
  String get disabilityExploreAlso => 'Explorar também';

  @override
  String get disabilityCoverageInsurance => 'Cobertura de seguro';

  @override
  String get disabilityCoverageSubtitle => 'IJM, AI, LPP — o teu boletim';

  @override
  String get disabilitySelfEmployed => 'Independente';

  @override
  String get disabilitySelfEmployedSubtitle => 'Riscos específicos sem LPP';

  @override
  String get disabilityCtaEvaluate => 'Avaliar';

  @override
  String get disabilityCtaAnalyze => 'Analisar';

  @override
  String get disabilityAppBarTitle => 'Se não puder mais trabalhar';

  @override
  String get disabilityStatLine1 => '1 em cada 5 pessoas';

  @override
  String get disabilityStatLine2 => 'será afetada antes dos 65 anos';

  @override
  String get authRegisterSubtitle =>
      'Conta opcional: os teus dados permanecem locais por padrão';

  @override
  String get authWhyCreateAccount => 'Porquê criar uma conta?';

  @override
  String get authBenefitProjections =>
      'Projeções AVS/LPP adaptadas à tua situação';

  @override
  String get authBenefitCoach => 'Coach personalizado com o teu nome';

  @override
  String get authBenefitSync =>
      'Backup na nuvem + sincronização multi-dispositivo';

  @override
  String get authFirstName => 'Nome próprio';

  @override
  String get authFirstNameRequired =>
      'O nome é necessário para personalizar o coach';

  @override
  String get authBirthYear => 'Ano de nascimento';

  @override
  String get authBirthYearRequired => 'Necessário para as projeções AVS/LPP';

  @override
  String get authPasswordRequirements =>
      'Usa pelo menos 8 caracteres para proteger a tua conta';

  @override
  String get authCguAccept => 'Li e aceito os ';

  @override
  String get authCguLink => 'Termos e Condições';

  @override
  String get authCguAndPrivacy => ' e a ';

  @override
  String get authPrivacyLink => 'Política de Privacidade';

  @override
  String get authConfirm18 =>
      'Confirmo que tenho 18 anos completos (T&C art. 4.1)';

  @override
  String get authConsentSection => 'Consentimentos opcionais';

  @override
  String get authConsentNotifications =>
      'Notificações de coaching (lembretes 3a, prazos fiscais)';

  @override
  String get authConsentAnalytics =>
      'Dados anónimos para melhorar os benchmarks suíços';

  @override
  String get authPasswordWeak => 'Fraco';

  @override
  String get authPasswordMedium => 'Médio';

  @override
  String get authPasswordStrong => 'Forte';

  @override
  String get authPasswordVeryStrong => 'Muito forte';

  @override
  String get authOrContinueWith => 'ou continuar com';

  @override
  String get authPrivacyReassurance =>
      'Os teus dados permanecem encriptados no teu dispositivo. Sem conexão bancária.';

  @override
  String get authContinueLocal => 'Continuar em modo local';

  @override
  String get authBack => 'Voltar';

  @override
  String coachGreetingSlm(String name) {
    return 'Olá $name. As tuas perguntas ficam no teu dispositivo — nada sai. Pergunta o que quiseres, vamos ver os teus números juntos.';
  }

  @override
  String coachGreetingDefault(String name, String scoreSuffix) {
    return 'Olá $name. Faz a tua pergunta — vou ver os teus números e digo-te o que vejo.$scoreSuffix';
  }

  @override
  String coachScoreSuffix(int score) {
    return ' A tua pontuação Fitness é de $score/100.';
  }

  @override
  String get coachComplianceError =>
      'Não consegui formular uma resposta conforme. Reformula a tua pergunta ou explora os simuladores.';

  @override
  String get coachErrorInvalidKey =>
      'A tua chave API parece inválida ou expirada. Verifica-a nas definições.';

  @override
  String get coachErrorRateLimit =>
      'Limite de pedidos atingido. Tenta novamente daqui a pouco.';

  @override
  String get coachErrorGeneric => 'Erro técnico. Tenta novamente mais tarde.';

  @override
  String get coachErrorConnection =>
      'Sem conexão. As ferramentas continuam aqui.';

  @override
  String get coachSuggestSimulate3a => 'Simular um depósito 3a';

  @override
  String get coachSuggestView3a => 'Ver as minhas contas 3a';

  @override
  String get coachSuggestSimulateLpp => 'Simular um resgate LPP';

  @override
  String get coachSuggestUnderstandLpp => 'Compreender o resgate LPP';

  @override
  String get coachSuggestTrajectory => 'Ver a minha trajetória';

  @override
  String get coachSuggestScenarios => 'Explorar cenários';

  @override
  String get coachSuggestDeductions => 'Deduções fiscais possíveis';

  @override
  String get coachSuggestTaxImpact => 'Simular o impacto fiscal';

  @override
  String get coachSuggestFitness => 'A minha pontuação Fitness';

  @override
  String get coachSuggestRetirement => 'A minha trajetória de reforma';

  @override
  String get coachEmptyStateMessage =>
      'Ainda sem perfil. Três perguntas, e começamos a conversar.';

  @override
  String get coachEmptyStateButton => 'Fazer o meu diagnóstico';

  @override
  String get coachTooltipHistory => 'Histórico';

  @override
  String get coachTooltipExport => 'Exportar conversa';

  @override
  String get coachTooltipSettings => 'Definições de IA';

  @override
  String get coachTooltipLifeEvent => 'Evento de vida';

  @override
  String get coachTierSlm => 'IA on-device';

  @override
  String get coachTierByok => 'IA nuvem (BYOK)';

  @override
  String get coachTierFallback => 'Modo offline';

  @override
  String get coachBadgeSlm => 'On-device';

  @override
  String get coachBadgeByok => 'Nuvem';

  @override
  String get coachBadgeFallback => 'Offline';

  @override
  String get coachLoading => 'A pensar...';

  @override
  String get coachSources => 'Fontes';

  @override
  String get coachInputHint => 'Faz a tua pergunta...';

  @override
  String get coachTitle => 'Coach MINT';

  @override
  String get coachFallbackName => 'amigo/a';

  @override
  String get coachUserMessage => 'A tua mensagem';

  @override
  String get coachCoachMessage => 'Resposta do coach';

  @override
  String get coachSendButton => 'Enviar';

  @override
  String get profileDefaultName => 'Utilizador';

  @override
  String profileNameAge(String name, int age) {
    return '$name, $age anos';
  }

  @override
  String get commonEdit => 'Editar';

  @override
  String get profileSlmTitle => 'IA no dispositivo (SLM)';

  @override
  String get profileSlmReady => 'Modelo pronto';

  @override
  String get profileSlmNotInstalled => 'Modelo não instalado';

  @override
  String get profileDeleteAccountSuccess => 'Conta eliminada com sucesso.';

  @override
  String get profileDeleteAccountError =>
      'Eliminação impossível de momento. Tenta mais tarde.';

  @override
  String get profileChangeLanguage => 'Mudar idioma';

  @override
  String profileDocCount(int count) {
    return '$count documento(s)';
  }

  @override
  String get tabToday => 'Hoje';

  @override
  String get tabDossier => 'Dossiê';

  @override
  String get affordabilityInsightRevenueTitle =>
      'O que te limita: o teu rendimento, não o teu capital próprio';

  @override
  String affordabilityInsightRevenueBody(
      String chargesTheoriques, String chargesReelles) {
    return 'Os bancos suíços calculam com uma taxa teórica de 5 % (diretiva ASB), mesmo que a taxa real do mercado seja muito mais baixa. É um teste de resistência: verificam que poderias assumir os encargos se as taxas subissem. Os teus encargos teóricos: $chargesTheoriques/mês. À taxa de mercado (~1,5 %): $chargesReelles/mês.';
  }

  @override
  String get affordabilityInsightEquityTitle =>
      'O que te limita: o teu capital próprio';

  @override
  String affordabilityInsightEquityBody(String manque) {
    return 'Faltam-te aproximadamente CHF $manque de capital próprio para atingir o mínimo de 20 % exigido pelos bancos.';
  }

  @override
  String get affordabilityInsightOkTitle =>
      'Boa notícia: ambos os critérios estão cumpridos';

  @override
  String get affordabilityInsightOkBody =>
      'O teu rendimento e capital próprio permitem-te aceder a este imóvel. Compara os tipos de hipoteca e as estratégias de amortização.';

  @override
  String affordabilityInsightLppCap(String lppUtilise, String lppTotal) {
    return 'O teu 2.º pilar está limitado: apenas CHF $lppUtilise de $lppTotal contam (máx. 10 % do preço, regra ASB).';
  }

  @override
  String get tabCoach => 'Coach';

  @override
  String get pulseNarrativeRetirementClose =>
      'a tua reforma aproxima-se. Aqui está a tua situação.';

  @override
  String pulseNarrativeYearsToAct(int yearsToRetire) {
    return 'tens $yearsToRetire anos para agir. Cada ano conta.';
  }

  @override
  String get pulseNarrativeTimeToBuild =>
      'tens tempo para construir. Aqui está a tua situação.';

  @override
  String get pulseNarrativeDefault => 'aqui está a tua situação financeira.';

  @override
  String get pulseLabelReplacementRate => 'Taxa de substituição na reforma';

  @override
  String get pulseLabelRetirementIncome => 'Rendimento estimado na reforma';

  @override
  String get pulseLabelFinancialScore => 'Pontuação de preparação financeira';

  @override
  String get exploreHubRetraiteTitle => 'Reforma';

  @override
  String get exploreHubRetraiteSubtitle => 'AVS, LPP, 3a, projeções';

  @override
  String get exploreHubFamilleTitle => 'Família';

  @override
  String get exploreHubFamilleSubtitle => 'Casamento, nascimento, concubinato';

  @override
  String get exploreHubTravailTitle => 'Trabalho & Estatuto';

  @override
  String get exploreHubTravailSubtitle =>
      'Emprego, independente, transfronteiriço';

  @override
  String get exploreHubLogementTitle => 'Habitação';

  @override
  String get exploreHubLogementSubtitle => 'Hipoteca, compra, venda';

  @override
  String get exploreHubFiscaliteTitle => 'Fiscalidade';

  @override
  String get exploreHubFiscaliteSubtitle => 'Impostos, comparador cantonal';

  @override
  String get exploreHubPatrimoineTitle => 'Património & Sucessão';

  @override
  String get exploreHubPatrimoineSubtitle => 'Doação, herança, alocação';

  @override
  String get exploreHubSanteTitle => 'Saúde & Proteção';

  @override
  String get exploreHubSanteSubtitle => 'LAMal, invalidez, cobertura';

  @override
  String get dossierDocumentsTitle => 'Documentos';

  @override
  String get dossierDocumentsSubtitle =>
      'Certificados, extratos, digitalizações';

  @override
  String get dossierCoupleTitle => 'Casal';

  @override
  String get dossierCoupleSubtitle => 'Lar, cônjuge, projeções duo';

  @override
  String get dossierBilanTitle => 'Balanço financeiro';

  @override
  String get dossierBilanSubtitle => 'Visão geral do teu património';

  @override
  String get dossierReglages => 'Definições';

  @override
  String get dossierConsentsTitle => 'Consentimentos';

  @override
  String get dossierConsentsSubtitle => 'Privacidade e partilha de dados';

  @override
  String get dossierAiTitle => 'IA & Coach';

  @override
  String get dossierAiSubtitle => 'Modelo local, chave API';

  @override
  String get dossierStartProfile => 'Começa o teu perfil';

  @override
  String dossierProfileCompleted(int percent) {
    return '$percent % concluído';
  }

  @override
  String get exploreHubFeatured => 'Percursos em destaque';

  @override
  String get exploreHubSeeAll => 'Ver tudo';

  @override
  String get exploreHubLearnMore => 'Compreender este tema';

  @override
  String get retraiteHubFeaturedOverview => 'Visão geral reforma';

  @override
  String get retraiteHubFeaturedOverviewSub =>
      'A tua estimativa personalizada em 3 minutos';

  @override
  String get retraiteHubFeaturedRenteCapital => 'Renda vs Capital';

  @override
  String get retraiteHubFeaturedRenteCapitalSub =>
      'Compara as duas opções lado a lado';

  @override
  String get retraiteHubFeaturedRachat => 'Resgate LPP';

  @override
  String get retraiteHubFeaturedRachatSub =>
      'Simula o impacto fiscal de um resgate';

  @override
  String get retraiteHubToolPilier3a => 'Pilar 3a';

  @override
  String get retraiteHubTool3aComparateur => '3a Comparador';

  @override
  String get retraiteHubTool3aRendement => '3a Rendimento real';

  @override
  String get retraiteHubTool3aRetrait => '3a Levantamento escalonado';

  @override
  String get retraiteHubTool3aRetroactif => '3a Retroativo';

  @override
  String get retraiteHubToolLibrePassage => 'Livre passagem';

  @override
  String get retraiteHubToolDecaissement => 'Desembolso';

  @override
  String get retraiteHubToolEpl => 'EPL';

  @override
  String get familleHubFeaturedMariage => 'Casamento';

  @override
  String get familleHubFeaturedMariageSub =>
      'Impacto nos teus impostos, AVS e previdência';

  @override
  String get familleHubFeaturedNaissance => 'Nascimento';

  @override
  String get familleHubFeaturedNaissanceSub =>
      'Abonos, licença e ajustes financeiros';

  @override
  String get familleHubFeaturedConcubinage => 'Concubinato';

  @override
  String get familleHubFeaturedConcubinageSub =>
      'Proteger o casal sem casamento';

  @override
  String get familleHubToolDivorce => 'Divórcio';

  @override
  String get familleHubToolDecesProche => 'Falecimento de um familiar';

  @override
  String get travailHubFeaturedPremierEmploi => 'Primeiro emprego';

  @override
  String get travailHubFeaturedPremierEmploiSub =>
      'Tudo o que precisas saber para começar bem';

  @override
  String get travailHubFeaturedChomage => 'Desemprego';

  @override
  String get travailHubFeaturedChomageSub =>
      'Os teus direitos, indemnizações e procedimentos';

  @override
  String get travailHubFeaturedIndependant => 'Independente';

  @override
  String get travailHubFeaturedIndependantSub =>
      'Previdência e fiscalidade à medida';

  @override
  String get travailHubToolComparateurEmploi => 'Comparador de emprego';

  @override
  String get travailHubToolFrontalier => 'Transfronteiriço';

  @override
  String get travailHubToolExpatriation => 'Expatriação';

  @override
  String get travailHubToolGenderGap => 'Gender gap';

  @override
  String get travailHubToolAvsIndependant => 'AVS independente';

  @override
  String get travailHubToolIjm => 'IJM';

  @override
  String get travailHubTool3aIndependant => '3a independente';

  @override
  String get travailHubToolDividendeSalaire => 'Dividendo vs Salário';

  @override
  String get travailHubToolLppVolontaire => 'LPP voluntário';

  @override
  String get logementHubFeaturedCapacite => 'Capacidade hipotecária';

  @override
  String get logementHubFeaturedCapaciteSub => 'Quanto podes pedir emprestado?';

  @override
  String get logementHubFeaturedLocationPropriete =>
      'Arrendamento vs Propriedade';

  @override
  String get logementHubFeaturedLocationProprieteSub =>
      'Compara os dois cenários em 20 anos';

  @override
  String get logementHubFeaturedVente => 'Venda imobiliária';

  @override
  String get logementHubFeaturedVenteSub =>
      'Imposto sobre o ganho e reinvestimento';

  @override
  String get logementHubToolAmortissement => 'Amortização';

  @override
  String get logementHubToolEplCombine => 'EPL combinado';

  @override
  String get logementHubToolValeurLocative => 'Valor locativo';

  @override
  String get logementHubToolSaronFixe => 'SARON vs Fixo';

  @override
  String get fiscaliteHubFeaturedComparateur => 'Comparador fiscal';

  @override
  String get fiscaliteHubFeaturedComparateurSub =>
      'Estima o teu imposto segundo diferentes cenários';

  @override
  String get fiscaliteHubFeaturedDemenagement => 'Mudança cantonal';

  @override
  String get fiscaliteHubFeaturedDemenagementSub =>
      'Compara a fiscalidade entre cantões';

  @override
  String get fiscaliteHubFeaturedAllocation => 'Alocação anual';

  @override
  String get fiscaliteHubFeaturedAllocationSub =>
      'Onde colocar as tuas poupanças este ano?';

  @override
  String get fiscaliteHubToolInteretsComposes => 'Juros compostos';

  @override
  String get fiscaliteHubToolBilanArbitrage => 'Balanço arbitragem';

  @override
  String get patrimoineHubFeaturedSuccession => 'Sucessão';

  @override
  String get patrimoineHubFeaturedSuccessionSub =>
      'Antecipa a transmissão do teu património';

  @override
  String get patrimoineHubFeaturedDonation => 'Doação';

  @override
  String get patrimoineHubFeaturedDonationSub =>
      'Fiscalidade e impacto na tua previdência';

  @override
  String get patrimoineHubFeaturedRenteCapital => 'Renda vs Capital';

  @override
  String get patrimoineHubFeaturedRenteCapitalSub =>
      'Compara as duas opções lado a lado';

  @override
  String get patrimoineHubToolBilan => 'Balanço financeiro';

  @override
  String get patrimoineHubToolPortfolio => 'Portfolio';

  @override
  String get santeHubFeaturedFranchise => 'Franquia LAMal';

  @override
  String get santeHubFeaturedFranchiseSub =>
      'Encontra a franquia que te custa menos';

  @override
  String get santeHubFeaturedInvalidite => 'Invalidez';

  @override
  String get santeHubFeaturedInvaliditeSub =>
      'Estima a tua cobertura em caso de incapacidade';

  @override
  String get santeHubFeaturedCheckup => 'Check-up cobertura';

  @override
  String get santeHubFeaturedCheckupSub => 'Verifica que estás bem protegido/a';

  @override
  String get santeHubToolAssuranceInvalidite => 'Seguro de invalidez';

  @override
  String get santeHubToolInvaliditeIndependant => 'Invalidez independente';

  @override
  String get dossierSlmTitle => 'Modelo local (SLM)';

  @override
  String get dossierSlmSubtitle => 'IA integrada, funciona offline';

  @override
  String get dossierByokTitle => 'Chave API (BYOK)';

  @override
  String get dossierByokSubtitle => 'Conecta o teu próprio modelo IA';

  @override
  String get budgetErrorRetry => 'O cálculo falhou. Tentar de novo?';

  @override
  String get budgetChiffreChocCaption =>
      'O que sobra depois de todas as despesas fixas';

  @override
  String get budgetMethodTitle => 'Compreender este orçamento';

  @override
  String get budgetMethodBody =>
      'Este orçamento separa as despesas fixas (renda, seguro de saúde, impostos) do rendimento disponível. A regra 50/30/20 sugere: 50 % para necessidades, 30 % para desejos, 20 % para poupança. É uma referência, não uma obrigação.';

  @override
  String get budgetMethodSource =>
      'Fonte: método 50/30/20 (Elizabeth Warren, 2005)';

  @override
  String get budgetDisclaimerNote =>
      'Estimativa educativa. Não constitui aconselhamento financeiro (LSFin art. 3).';

  @override
  String get chiffreChocIfYouAct => 'Se agires';

  @override
  String get chiffreChocIfYouDontAct => 'Se não fizeres nada';

  @override
  String get chiffreChocAvantApresGapAct =>
      'Uma recompra LPP ou contribuições 3a podem reduzir esta lacuna a metade.';

  @override
  String get chiffreChocAvantApresGapNoAct =>
      'A lacuna cresce todos os anos. Na reforma, será tarde demais.';

  @override
  String get chiffreChocAvantApresLiquidityAct =>
      'Poupar 500 CHF/mês reconstrói 3 meses de reserva em 6 meses.';

  @override
  String get chiffreChocAvantApresLiquidityNoAct =>
      'Uma emergência sem reservas significa crédito ao consumo.';

  @override
  String get chiffreChocAvantApresTaxAct =>
      'Cada ano sem 3a é uma dedução fiscal perdida.';

  @override
  String get chiffreChocAvantApresTaxNoAct =>
      'Sem 3a, pagas a taxa completa e não preparas a reforma.';

  @override
  String get chiffreChocAvantApresIncomeAct =>
      'Alguns ajustes podem melhorar a tua projeção.';

  @override
  String get chiffreChocAvantApresIncomeNoAct =>
      'A tua situação mantém-se estável, mas sem margem de crescimento.';

  @override
  String chiffreChocConfidenceSimple(String count) {
    return 'Baseado em $count dados. Adiciona mais para refinar.';
  }

  @override
  String get quickStartTitle => 'Três números, uma primeira verdade.';

  @override
  String get quickStartSubtitle => 'O resto virá depois.';

  @override
  String get quickStartFirstName => 'O teu nome';

  @override
  String get quickStartFirstNameHint => 'Opcional';

  @override
  String get quickStartAge => 'A tua idade';

  @override
  String quickStartAgeValue(String age) {
    return '$age anos';
  }

  @override
  String get quickStartSalary => 'O teu rendimento bruto anual';

  @override
  String quickStartSalaryValue(String salary) {
    return '$salary/ano';
  }

  @override
  String get quickStartCanton => 'Cantao';

  @override
  String get quickStartPreviewTitle => 'Pre-visualizacao reforma';

  @override
  String get quickStartVerdictGood => 'No bom caminho';

  @override
  String get quickStartVerdictWatch => 'A vigiar';

  @override
  String get quickStartVerdictGap => 'Desvio significativo';

  @override
  String get quickStartToday => 'Hoje';

  @override
  String get quickStartAtRetirement => 'Na reforma';

  @override
  String get quickStartPerMonth => '/mes';

  @override
  String quickStartDropPct(String pct, String gap) {
    return '-$pct % de poder de compra ($gap/mes)';
  }

  @override
  String get quickStartDisclaimer =>
      'Estimativa educativa baseada na tua idade, rendimento e cantão.';

  @override
  String get quickStartCta => 'Ver o que muda';

  @override
  String get quickStartSectionIdentity => 'Identidade & Agregado';

  @override
  String get quickStartSectionIncome => 'Rendimento & Poupanca';

  @override
  String get quickStartSectionPension => 'Previdencia (LPP)';

  @override
  String get quickStartSectionProperty => 'Imoveis & Dividas';

  @override
  String quickStartSectionGuidance(String label) {
    return 'Secao: $label — atualiza as tuas informacoes abaixo.';
  }

  @override
  String quickStartNarrative(String pct) {
    return 'Manténs ~$pct % do teu nível de vida.';
  }

  @override
  String get quickStartNarrativeLow =>
      'Uma primeira ordem de grandeza, a precisar.';

  @override
  String get quickStartCtaSecondary => 'Acrescentarei mais detalhes depois';

  @override
  String get quickStartConfidenceMsg =>
      'Sem certificado LPP, é uma estimativa ampla.';

  @override
  String get quickStartHeroSecondaryLabel => 'hoje';

  @override
  String get quickStartHeroLabel => 'na reforma';

  @override
  String profileCompletionHint(int pct, String missing) {
    return '$pct % — falta $missing';
  }

  @override
  String get profileMissingLpp => 'o teu LPP';

  @override
  String get profileMissingIncome => 'o teu rendimento';

  @override
  String get profileMissingProperty => 'o teu imovel';

  @override
  String get profileMissingIdentity => 'a tua identidade';

  @override
  String get profileMissingAnd => ' e ';

  @override
  String profileAnnualRefreshDays(int days) {
    return 'Última atualização há $days dias';
  }

  @override
  String get chiffreChocBack => 'Voltar';

  @override
  String get chiffreChocShowComparison => 'Mostrar comparação';

  @override
  String get chiffreChocHideComparison => 'Ocultar comparação';

  @override
  String get dashboardNextActionsTitle => 'As tuas próximas ações';

  @override
  String get dashboardExploreAlsoTitle => 'Explorar mais';

  @override
  String get dashboardImproveAccuracyTitle => 'Melhora a tua precisão';

  @override
  String dashboardCurrentConfidence(int score) {
    return 'Confiança atual: $score%';
  }

  @override
  String dashboardPrecisionPtsGain(int pts) {
    return '+$pts pontos de precisão';
  }

  @override
  String get dashboardOnboardingHeroTitle => 'A tua reforma num relance';

  @override
  String get dashboardOnboardingCta => 'Começar — 2 min';

  @override
  String get dashboardOnboardingConsent =>
      'Nenhum dado armazenado sem o teu consentimento.';

  @override
  String get dashboardEducationTitle => 'Como funciona a reforma na Suíça?';

  @override
  String get dashboardEducationSubtitle =>
      'AVS, LPP, 3a — o básico em 5 minutos';

  @override
  String get dashboardCockpitTitle => 'Cockpit detalhado';

  @override
  String get dashboardCockpitSubtitle => 'Decomposição por pilar';

  @override
  String get dashboardCockpitCta => 'Abrir';

  @override
  String get dashboardRenteVsCapitalTitle => 'Renda vs Capital';

  @override
  String get dashboardRenteVsCapitalSubtitle =>
      'Explorar o ponto de equilíbrio';

  @override
  String get dashboardRenteVsCapitalCta => 'Simular';

  @override
  String get dashboardRachatLppTitle => 'Resgate LPP';

  @override
  String get dashboardRachatLppSubtitle => 'Simular o impacto fiscal';

  @override
  String get dashboardRachatLppCta => 'Calcular';

  @override
  String dashboardPrecisionGainPercent(int percent) {
    return 'Precisão +$percent%';
  }

  @override
  String dashboardImpactChf(String amount) {
    return '+CHF $amount';
  }

  @override
  String dashboardDeadlineDays(int days) {
    return 'D-$days';
  }

  @override
  String dashboardBannerDeadline(String title, int days) {
    return '$title — D-$days';
  }

  @override
  String get dashboardOneLinerGoodTrack =>
      'Estás no bom caminho para manter o teu nível de vida.';

  @override
  String get dashboardOneLinerLevers =>
      'Existem opções para melhorar a tua projeção.';

  @override
  String get dashboardOneLinerEveryAction =>
      'Cada ação conta — explora as opções disponíveis.';

  @override
  String get profileFamilyCouple => 'Em casal';

  @override
  String get profileFamilySingle => 'Solteiro/a';

  @override
  String get renteVsCapitalErrorRetry =>
      'O cálculo falhou. Tenta novamente mais tarde.';

  @override
  String get rachatEchelonneTitle => 'Resgate LPP escalonado';

  @override
  String get rachatEchelonneIntroTitle => 'Porquê escalonar os resgates?';

  @override
  String get rachatEchelonneIntroBody =>
      'O imposto suíço é progressivo: distribuir um resgate LPP por vários anos maximiza a poupança fiscal total.';

  @override
  String get rachatEchelonneSavingsCaption =>
      'de poupança adicional escalonando';

  @override
  String get rachatEchelonneBlocBetter =>
      'Resgate em bloco mais vantajoso neste caso';

  @override
  String get rachatEchelonneSituationLpp => 'Situação LPP';

  @override
  String get rachatEchelonneAvoirActuel => 'Ativos LPP atuais';

  @override
  String get rachatEchelonneRachatMax => 'Resgate máximo';

  @override
  String get rachatEchelonneSituationFiscale => 'Situação fiscal';

  @override
  String get rachatEchelonneCanton => 'Cantão';

  @override
  String get rachatEchelonneEtatCivil => 'Estado civil';

  @override
  String get rachatEchelonneCelibataire => 'Solteiro/a';

  @override
  String get rachatEchelonneMarieE => 'Casado/a';

  @override
  String get rachatEchelonneRevenuImposable => 'Rendimento tributável';

  @override
  String get rachatEchelonneTauxMarginal => 'Taxa marginal estimada';

  @override
  String get rachatEchelonneTauxManuel => 'Valor ajustado manualmente';

  @override
  String get rachatEchelonneAjuster => 'Ajustar';

  @override
  String get rachatEchelonneAuto => 'Auto';

  @override
  String get rachatEchelonneStrategie => 'Estratégia';

  @override
  String get rachatEchelonneHorizon => 'Horizonte (anos)';

  @override
  String get rachatEchelonneComparaison => 'Comparação';

  @override
  String get rachatEchelonneBlocTitle => 'Tudo em 1 ano';

  @override
  String get rachatEchelonneBlocSubtitle => 'Resgate em bloco';

  @override
  String get rachatEchelonneEchelonneSubtitle => 'Resgate distribuído';

  @override
  String get rachatEchelonnePlusAdapte => 'O mais adequado';

  @override
  String get rachatEchelonneEconomieFiscale => 'Poupança fiscal';

  @override
  String get rachatEchelonneImpactTranche => 'Impacto por escalão';

  @override
  String get rachatEchelonneImpactBlocExplain =>
      'Em bloco, a dedução atravessa vários escalões. Escalonando, cada dedução fica no escalão mais alto.';

  @override
  String get rachatEchelonneBloc => 'Bloco';

  @override
  String get rachatEchelonneEchelonne => 'Escalonado';

  @override
  String get rachatEchelonnePlanAnnuel => 'Plano anual';

  @override
  String get rachatEchelonneTotal => 'Total';

  @override
  String get rachatEchelonneRachat => 'Resgate';

  @override
  String get rachatEchelonneBlockageTitle =>
      'LPP art. 79b al. 3 — Bloqueio EPL';

  @override
  String get rachatEchelonneBlockageBody =>
      'Após cada resgate, qualquer levantamento EPL fica bloqueado durante 3 anos.';

  @override
  String get rachatEchelonneTauxMarginalTitle => 'Taxa marginal de impostos';

  @override
  String get rachatEchelonneTauxMarginalBody =>
      'A taxa marginal é a percentagem sobre o teu último franco ganho.';

  @override
  String get rachatEchelonneTauxMarginalTip =>
      'É por isso que escalonar os resgates é inteligente.';

  @override
  String get rachatEchelonneTauxMarginalSemantics =>
      'Informação sobre a taxa marginal';

  @override
  String get staggered3aTitle => 'Levantamento 3a escalonado';

  @override
  String get staggered3aEconomie => 'Poupança estimada';

  @override
  String get staggered3aIntroTitle => 'Porquê escalonar os levantamentos 3a?';

  @override
  String get staggered3aIntroBody =>
      'O imposto sobre o levantamento de capital de previdência é progressivo. Ao repartir por várias contas e anos fiscais, reduzes a taxa média.';

  @override
  String get staggered3aParametres => 'Parâmetros';

  @override
  String get staggered3aAvoirTotal => 'Total de ativos 3a';

  @override
  String get staggered3aNbComptes => 'Número de contas 3a';

  @override
  String get staggered3aCanton => 'Cantão';

  @override
  String get staggered3aRevenuImposable => 'Rendimento tributável';

  @override
  String get staggered3aAgeDebut => 'Idade início levantamentos';

  @override
  String get staggered3aAgeFin => 'Idade último levantamento';

  @override
  String get staggered3aResultat => 'Resultado';

  @override
  String get staggered3aEnBloc => 'Em bloco';

  @override
  String get staggered3aRetraitUnique => 'Levantamento único';

  @override
  String get staggered3aEchelonneLabel => 'Escalonado';

  @override
  String get staggered3aImpotEstime => 'Imposto estimado';

  @override
  String get staggered3aPlanAnnuel => 'Plano anual';

  @override
  String get staggered3aAge => 'Idade';

  @override
  String get staggered3aRetrait => 'Levantamento';

  @override
  String get staggered3aImpot => 'Imposto';

  @override
  String get staggered3aNet => 'Líquido';

  @override
  String get staggered3aTotal => 'Total';

  @override
  String get staggered3aAns => 'anos';

  @override
  String get optimDecaissementTitle => 'Ordem de levantamento 3a';

  @override
  String get optimDecaissementChiffre => '+CHF 3\'500';

  @override
  String get optimDecaissementChiffreExplication =>
      'É o imposto adicional ao levantar 2 contas 3a no mesmo ano — LIFD art. 38.';

  @override
  String get optimDecaissementPrincipe => 'O princípio do escalonamento';

  @override
  String get optimDecaissementInfo1Title => '1 conta 3a por ano fiscal';

  @override
  String get optimDecaissementInfo1Body =>
      'O levantamento do 3a é tributado separadamente (LIFD art. 38), mas a taxa aumenta com o montante.';

  @override
  String get optimDecaissementInfo2Title => 'Até 10 contas 3a simultâneas';

  @override
  String get optimDecaissementInfo2Body =>
      'Desde 2026, podes ter várias contas 3a (revisão OPP3 2026).';

  @override
  String get optimDecaissementInfo3Title => 'A fiscalidade varia por cantão';

  @override
  String get optimDecaissementInfo3Body =>
      'Vários cantões oferecem deduções adicionais.';

  @override
  String get optimDecaissementIllustration => 'Exemplo: CHF 150\'000 em 3a';

  @override
  String get optimDecaissementTableSpread => 'Distribuição';

  @override
  String get optimDecaissementTableAmount => 'Montante/levantamento';

  @override
  String get optimDecaissementTableTax => 'Imposto est.*';

  @override
  String get optimDecaissementTableRow1Spread => '1 ano';

  @override
  String get optimDecaissementTableRow1Amount => 'CHF 150\'000';

  @override
  String get optimDecaissementTableRow1Tax => '~CHF 12\'500';

  @override
  String get optimDecaissementTableRow2Spread => '3 anos';

  @override
  String get optimDecaissementTableRow2Amount => 'CHF 50\'000/ano';

  @override
  String get optimDecaissementTableRow2Tax => '~CHF 3\'200/ano';

  @override
  String get optimDecaissementTableRow3Spread => '5 anos';

  @override
  String get optimDecaissementTableRow3Amount => 'CHF 30\'000/ano';

  @override
  String get optimDecaissementTableRow3Tax => '~CHF 1\'700/ano';

  @override
  String get optimDecaissementTableFootnote =>
      '* Estimativas indicativas baseadas numa taxa cantonal média (ZH).';

  @override
  String get optimDecaissementPlanTitle => 'Como planear o teu levantamento';

  @override
  String get optimDecaissementStep1Title => 'Inventário das tuas contas 3a';

  @override
  String get optimDecaissementStep1Body =>
      'Lista cada conta 3a com saldo e instituição.';

  @override
  String get optimDecaissementStep2Title => 'Simula o impacto fiscal';

  @override
  String get optimDecaissementStep2Body =>
      'Compara: tudo em 1 ano vs. distribuir por 3, 5 ou 7 anos.';

  @override
  String get optimDecaissementStep3Title => 'Coordena com a tua reforma LPP';

  @override
  String get optimDecaissementStep3Body =>
      'Esperar 1-2 anos após o levantamento do capital LPP reduz a carga fiscal total.';

  @override
  String get optimDecaissementSpecialisteTitle => 'Consultar um/a especialista';

  @override
  String get optimDecaissementSpecialisteBody =>
      'Um/a especialista pode modelar o teu plano de levantamento.';

  @override
  String get optimDecaissementSources =>
      '• LIFD art. 38 — Tributação separada\n• OPP3 art. 3 — Condições de levantamento\n• OPP3 art. 7 — Limites de dedução';

  @override
  String get optimDecaissementDisclaimer =>
      'Informação educativa, não aconselhamento fiscal (LSFin).';

  @override
  String get successionAlertTitle =>
      'Sem testamento, o/a teu/tua companheiro/a não herda nada';

  @override
  String get successionAlertBody =>
      'O direito sucessório suíço (CC art. 457 ss) protege primeiro descendentes, depois pais e cônjuge legal.';

  @override
  String get successionNotionsCles => 'As noções-chave';

  @override
  String get successionReservesBody =>
      'Uma parte da sucessão é reservada por lei a descendentes e cônjuge.';

  @override
  String get successionQuotiteSubtitle => 'CC art. 470 al. 2';

  @override
  String get successionQuotiteBody =>
      'O que resta após as reservas é a tua porção disponível — legável livremente.';

  @override
  String get successionTestamentBody =>
      'Duas formas: holográfico ou notarial. Sem testamento = sucessão legal.';

  @override
  String get successionDonationTitle => 'Doação em vida';

  @override
  String get successionDonationSubtitle => 'CO art. 239 ss';

  @override
  String get successionDonationBody =>
      'Transmitir em vida antecipa a sucessão e pode reduzir o imposto sucessório.';

  @override
  String get successionBeneficiairesTitle => 'Beneficiários LPP e 3a';

  @override
  String get successionBeneficiairesSubtitle => 'LPP art. 20 · OPP3 art. 2';

  @override
  String get successionBeneficiairesBody =>
      'O capital LPP e o saldo 3a NÃO fazem parte da sucessão ordinária.';

  @override
  String get successionDecesProche =>
      'Em caso de falecimento de um ente querido';

  @override
  String get successionCheck1 => 'Verificar beneficiários em cada conta 3a';

  @override
  String get successionCheck2 => 'Verificar beneficiário LPP junto da caixa';

  @override
  String get successionCheck3 => 'Redigir ou atualizar o testamento';

  @override
  String get successionCheck4 =>
      'Verificar regime matrimonial se casado/a (CC art. 181 ss)';

  @override
  String get successionCheck5 =>
      'Informar os entes queridos da localização do testamento';

  @override
  String get successionSpecialisteTitle =>
      'Consultar um/a notário/a ou especialista';

  @override
  String get successionSpecialisteBody =>
      'Um/a notário/a pode redigir ou rever o teu testamento.';

  @override
  String get successionSources =>
      '• CC art. 457–640 — Direito das sucessões\n• CC art. 470–471 — Reservas hereditárias\n• CC art. 498–504 — Formas de testamento\n• LPP art. 20 — Beneficiários LPP\n• OPP3 art. 2 — Beneficiários 3a';

  @override
  String naissanceAllocForCanton(String canton, int count, String plural) {
    return 'Abonos de família em $canton para $count filho$plural';
  }

  @override
  String naissanceAllocContextNote(String canton, int count, String plural) {
    return '($canton, $count filho$plural)';
  }

  @override
  String get affordabilityEmotionalPositif => 'Podes pagar isto';

  @override
  String get affordabilityEmotionalNegatif => 'Falta uma peça do puzzle';

  @override
  String get affordabilityExploreAlso => 'Explorar mais';

  @override
  String get affordabilityRelatedAmortTitle => 'Amortização direta vs indireta';

  @override
  String get affordabilityRelatedAmortSubtitle =>
      'Impacto fiscal de cada estratégia';

  @override
  String get affordabilityRelatedSaronTitle => 'SARON vs taxa fixa';

  @override
  String get affordabilityRelatedSaronSubtitle => 'Comparar tipos de hipoteca';

  @override
  String get affordabilityRelatedValeurTitle => 'Valor locativo';

  @override
  String get affordabilityRelatedValeurSubtitle =>
      'Compreender a tributação da habitação';

  @override
  String get affordabilityRelatedEplTitle => 'EPL — Usar o meu 2o pilar';

  @override
  String get affordabilityRelatedEplSubtitle =>
      'Levantamento antecipado para compra';

  @override
  String get affordabilityRelatedSimulate => 'Simular';

  @override
  String get affordabilityRelatedCompare => 'Comparar';

  @override
  String get affordabilityRelatedCalculate => 'Calcular';

  @override
  String get affordabilityAdvancedParams => 'Mais hipóteses';

  @override
  String get demenagementTitreV2 => 'Mudar de cantão, quanto poupas?';

  @override
  String get demenagementCtaOptimal => 'Encontrar o cantão adequado';

  @override
  String demenagementInsightPositif(String mois) {
    return 'Esta mudança aumenta o teu poder de compra. A poupança cobre cerca de $mois meses de renda média.';
  }

  @override
  String get demenagementInsightNegatif =>
      'Esta mudança custa mais. Verifica se a qualidade de vida compensa a diferença.';

  @override
  String get demenagementBilanTotal =>
      'Balanço total (impostos + seguro de saúde)';

  @override
  String divorceTransfertAmount(String amount, String direction) {
    return 'Transferência de $amount ($direction)';
  }

  @override
  String divorceFiscalDelta(String sign, String amount) {
    return 'Diferença: $sign$amount/ano';
  }

  @override
  String divorcePensionMois(String amount) {
    return '$amount/mês';
  }

  @override
  String divorcePensionAnnuel(String amount) {
    return 'ou seja $amount/ano';
  }

  @override
  String get divorceConjoint1Label => 'Cônjuge 1';

  @override
  String get divorceConjoint2Label => 'Cônjuge 2';

  @override
  String get divorceSplitC1 => 'C1';

  @override
  String get divorceSplitC2 => 'C2';

  @override
  String get unemploymentVague1Label => 'Onda 1 — Urgência administrativa';

  @override
  String get unemploymentVague1Text =>
      'Inscrição no ORP nos primeiros 5 dias. Caso contrário: perda de subsídios. Cada dia de atraso = subsídio perdido.';

  @override
  String get unemploymentVague2Label => 'Onda 2 — Orçamento a ajustar';

  @override
  String get unemploymentVague2Text =>
      'Queda imediata de rendimentos. O seguro-desemprego não cobre feriados nem o período de espera (5–20 dias). Revê o teu orçamento desde o dia 1.';

  @override
  String get unemploymentVague3Label => 'Onda 3 — Decisões escondidas';

  @override
  String get unemploymentVague3Text =>
      'Nos 30 dias seguintes: transferir o LPP (senão instituição supletiva). Antes do mês seguinte: suspender o 3a, rever o seguro de saúde.';

  @override
  String get unemploymentBudgetLoyer => 'Renda';

  @override
  String get unemploymentBudgetLamal => 'Seguro de saúde';

  @override
  String get unemploymentBudgetTransport => 'Transportes';

  @override
  String get unemploymentBudgetLoisirs => 'Lazer';

  @override
  String get unemploymentBudgetEpargne3a => 'Poupança 3a';

  @override
  String get unemploymentGainMin => 'CHF 0';

  @override
  String get unemploymentGainMax => 'CHF 12\'350';

  @override
  String get unemploymentBracket1 => '12–17 meses contrib.';

  @override
  String get unemploymentBracket1Value => '200 subsídios';

  @override
  String get unemploymentBracket2 => '18–21 meses contrib.';

  @override
  String get unemploymentBracket2Value => '260 subsídios';

  @override
  String unemploymentBracket3(int age) {
    return '>= 22 meses, < $age anos';
  }

  @override
  String get unemploymentBracket3Value => '400 subsídios';

  @override
  String unemploymentBracket4(int age) {
    return '>= 22 meses, >= $age anos';
  }

  @override
  String get unemploymentBracket4Value => '520 subsídios';

  @override
  String get allocAnnuelleTitle => 'Onde colocar os teus CHF?';

  @override
  String get allocAnnuelleBudgetTitle => 'O teu orçamento anual';

  @override
  String get allocAnnuelleMontantLabel => 'Montante disponível por ano (CHF)';

  @override
  String get allocAnnuelleTauxMarginal => 'Taxa marginal de imposto estimada';

  @override
  String get allocAnnuelleAnneesRetraite => 'Anos até à reforma';

  @override
  String allocAnnuelleAnneesValue(int years) {
    return '$years anos';
  }

  @override
  String get allocAnnuelle3aMaxed => '3a já no máximo';

  @override
  String get allocAnnuelleRachatLpp => 'Potencial de resgate LPP';

  @override
  String get allocAnnuelleRachatMontant => 'Montante de resgate possível (CHF)';

  @override
  String get allocAnnuelleProprietaire => 'Proprietário de imóvel';

  @override
  String get allocAnnuelleComparer => 'Comparar estratégias';

  @override
  String get allocAnnuelleTrajectoires => 'Trajetórias comparadas';

  @override
  String get allocAnnuelleGraphHint =>
      'Toca no gráfico para ver os valores de cada ano.';

  @override
  String get allocAnnuelleValeurTerminale => 'Valor terminal estimado';

  @override
  String allocAnnuelleApresAnnees(int years) {
    return 'Após $years anos';
  }

  @override
  String get allocAnnuelleHypotheses => 'Hipóteses utilizadas';

  @override
  String get allocAnnuelleRendementMarche => 'Rendimento do mercado';

  @override
  String get allocAnnuelleRendementLpp => 'Rendimento LPP';

  @override
  String get allocAnnuelleRendement3a => 'Rendimento 3a';

  @override
  String get allocAnnuelleAvertissement => 'Aviso';

  @override
  String allocAnnuelleSources(String sources) {
    return 'Fontes: $sources';
  }

  @override
  String get allocAnnuellePreRempli => 'Valores pré-preenchidos do teu perfil';

  @override
  String get allocAnnuelleEncouragement =>
      'Cada franco bem investido trabalha para ti. Compara as opções e escolhe com conhecimento.';

  @override
  String get expatTab2EduInsert =>
      'A Suíça não aplica um imposto de saída (exit tax) — ao contrário dos EUA ou da França. Os teus ganhos de capital latentes não são tributados na saída. É uma grande vantagem para expatriados.';

  @override
  String get expatTimelineToday => 'Hoje';

  @override
  String get expatTimelineTodayDesc => 'Começa a planear';

  @override
  String get expatTimelineTodayTiming => 'Agora';

  @override
  String get expatTimeline2to3Months => '2-3 meses antes';

  @override
  String get expatTimeline2to3MonthsDesc =>
      'Notificar a comuna, cancelar LAMal';

  @override
  String expatTimeline2to3MonthsTiming(int months) {
    return 'Em ~$months meses';
  }

  @override
  String get expatTimeline1Month => '1 mês antes';

  @override
  String get expatTimeline1MonthDesc => 'Retirar 3a, transferir LPP';

  @override
  String expatTimeline1MonthTiming(int months) {
    return 'Em ~$months meses';
  }

  @override
  String get expatTimelineDDay => 'Dia D';

  @override
  String get expatTimelineDDayDesc => 'Partida efetiva';

  @override
  String expatTimelineDDayTiming(int days) {
    return 'Em $days dias';
  }

  @override
  String get expatTimeline30After => '30 dias depois';

  @override
  String get expatTimeline30AfterDesc => 'Declarar impostos pro rata temporis';

  @override
  String get expatTimeline30AfterTiming => 'Após a partida';

  @override
  String get expatTimelineUrgent => 'Urgente!';

  @override
  String get expatTimelinePassed => 'Passado';

  @override
  String expatSavingsBadge(String amount, String percent) {
    return 'Poupança: $amount (-$percent%)';
  }

  @override
  String expatForfaitMoreCostly(String amount) {
    return 'Forfait mais caro: +$amount';
  }

  @override
  String expatForfaitBase(String amount) {
    return 'Base: $amount';
  }

  @override
  String expatAvsReductionExplain(String percent) {
    return 'Cada ano em falta reduz a tua pensão em cerca de $percent%. A redução é definitiva e aplica-se para toda a vida.';
  }

  @override
  String expatAvsChiffreChoc(String amount) {
    return '-$amount/ano na tua pensão AVS';
  }

  @override
  String expatDepartChiffreChoc(String amount) {
    return '$amount de capital a garantir antes da partida';
  }

  @override
  String get independantCoveredLabel => 'Coberto';

  @override
  String get independantCriticalLabel => 'Sem cobertura — crítico';

  @override
  String get independantHighLabel => 'Sem cobertura';

  @override
  String get independantLowLabel => 'Sem cobertura';

  @override
  String fiscalIncomeInfoLabel(String income, String status, String children) {
    return 'Rendimento: $income | $status$children';
  }

  @override
  String get fiscalStatusMarried => 'Casado/a';

  @override
  String get fiscalStatusSingle => 'Solteiro/a';

  @override
  String fiscalChildrenSuffix(int count) {
    return ' + $count filho(s)';
  }

  @override
  String get fiscalPerMonth => '/mês';

  @override
  String get sim3aTitle => 'O teu 3.º pilar';

  @override
  String get sim3aExportTooltip => 'Exportar o meu relatório';

  @override
  String get sim3aCoachTitle => 'O conselho do Mentor';

  @override
  String get sim3aCoachBody =>
      'O 3a é uma das ferramentas de otimização mais eficazes na Suíça. A poupança fiscal imediata é uma vantagem concreta.';

  @override
  String get sim3aParamsHeader => 'Os teus parâmetros';

  @override
  String get sim3aAnnualContribution => 'Contribuição anual';

  @override
  String get sim3aAnnualContributionIndep =>
      'Contribuição anual (independente sem LPP)';

  @override
  String get sim3aMarginalRate => 'Taxa marginal de imposição';

  @override
  String get sim3aYearsToRetirement => 'Anos até à reforma';

  @override
  String get sim3aExpectedReturn => 'Rendimento anual esperado';

  @override
  String sim3aYearsSuffix(int count) {
    return '$count anos';
  }

  @override
  String get sim3aAnnualTaxSaved => 'Poupança fiscal anual';

  @override
  String get sim3aFinalCapital => 'Capital no vencimento';

  @override
  String get sim3aCumulativeTaxSaved => 'Poupança fiscal acumulada';

  @override
  String get sim3aStrategyHeader => 'Estratégia vencedora';

  @override
  String get sim3aStratBankTitle => 'Banco > Seguro';

  @override
  String get sim3aStratBankBody =>
      'Evita contratos de seguro vinculados. Mantém-te flexível com um 3a bancário investido.';

  @override
  String get sim3aStrat5AccountsTitle => 'A regra dos 5 contas';

  @override
  String get sim3aStrat5AccountsBody =>
      'Abre várias contas para levantar de forma escalonada e reduzir a progressão fiscal.';

  @override
  String get sim3aStrat100ActionsTitle => '100 % Ações';

  @override
  String get sim3aStrat100ActionsBody =>
      'Se a reforma está a mais de 15 anos, uma estratégia de ações poderá maximizar o teu capital.';

  @override
  String get sim3aExploreAlso => 'Explorar também';

  @override
  String get sim3aProviderComparator => 'Comparador de prestadores';

  @override
  String get sim3aProviderComparatorSub => 'VIAC, Finpension, frankly...';

  @override
  String get sim3aRealReturn => 'Rendimento real';

  @override
  String get sim3aRealReturnSub => 'Após custos, inflação e fiscal';

  @override
  String get sim3aStaggeredWithdrawal => 'Levantamento escalonado';

  @override
  String get sim3aStaggeredWithdrawalSub =>
      'Distribuir levantamentos para reduzir impostos';

  @override
  String get sim3aCtaCompare => 'Comparar';

  @override
  String get sim3aCtaCalculate => 'Calcular';

  @override
  String get sim3aCtaPlan => 'Planear';

  @override
  String get sim3aDisclaimer =>
      'Estimativa educativa. As poupanças reais dependem do local de residência e da situação familiar. Não constitui aconselhamento financeiro (LSFin).';

  @override
  String get sim3aDebtLockedTitle => 'Prioridade ao desendividamento';

  @override
  String get sim3aDebtLockedMessage =>
      'Em modo de proteção, as recomendações de ação 3a estão desativadas. A prioridade é estabilizar a tua situação financeira.';

  @override
  String get sim3aDebtStrategyTitle => 'Estratégia bloqueada';

  @override
  String get sim3aDebtStrategyMessage =>
      'As estratégias de investimento 3a estão desativadas enquanto tiveres dívidas ativas. Pagar as dívidas tem um rendimento superior a qualquer investimento.';

  @override
  String get realReturnTitle => 'Rendimento real 3a';

  @override
  String get realReturnChiffreChocLabel =>
      'Taxa equivalente sobre esforço líquido';

  @override
  String realReturnVsNominal(String rate) {
    return 'vs $rate % taxa líquida 3a (bruto − custos)';
  }

  @override
  String realReturnEffortNet(String amount, String pts) {
    return 'Esforço líquido: $amount/ano | Prémio fiscal implícito: +$pts pts';
  }

  @override
  String get realReturnParams => 'Parâmetros';

  @override
  String get realReturnAnnualPayment => 'Contribuição anual';

  @override
  String get realReturnMarginalRate => 'Taxa marginal';

  @override
  String get realReturnGrossReturn => 'Rendimento bruto';

  @override
  String get realReturnMgmtFees => 'Custos de gestão';

  @override
  String get realReturnDuration => 'Duração do investimento';

  @override
  String realReturnYearsSuffix(int count) {
    return '$count anos';
  }

  @override
  String get realReturnCompared => 'Rendimentos comparados';

  @override
  String get realReturnNominal3a => 'Rendimento nominal 3a';

  @override
  String get realReturnRealWithFiscal => 'Rendimento real (com fiscal)';

  @override
  String get realReturnEquivNote =>
      'Esta taxa é equivalente: não representa um rendimento de mercado esperado.';

  @override
  String get realReturnSavingsAccount => 'Rendimento conta poupança';

  @override
  String realReturnFinalCapital(int years) {
    return 'Capital final após $years anos';
  }

  @override
  String get realReturn3aFintech => '3a Fintech + fiscal';

  @override
  String get realReturnSavings15 => 'Conta poupança 1,5 %';

  @override
  String realReturnGainVsSavings(String amount) {
    return 'Ganho vs poupança: CHF $amount';
  }

  @override
  String get realReturnFiscalDetail => 'Detalhe poupança fiscal';

  @override
  String get realReturnTotalPayments => 'Total contribuições';

  @override
  String get realReturnFinalCapital3a => 'Capital final 3a (sem fiscal)';

  @override
  String get realReturnCumulativeFiscal => 'Poupança fiscal acumulada';

  @override
  String get realReturnTotalWithFiscal => 'Total com vantagem fiscal';

  @override
  String realReturnAhaMoment(String netAmount) {
    return 'O teu esforço real: $netAmount/ano. O fisco financia a diferença — uma alavanca rara na Suíça.';
  }

  @override
  String get realReturnPerYear => '/ ano';

  @override
  String get genderGapAppBarTitle => 'Lacuna de previdência';

  @override
  String get genderGapHeaderTitle => 'Lacuna de previdência';

  @override
  String get genderGapHeaderSubtitle => 'Impacto do tempo parcial na reforma';

  @override
  String get genderGapIntro =>
      'A dedução de coordenação (CHF 26\'460) não é proporcional ao tempo parcial, o que penaliza mais as pessoas que trabalham a tempo reduzido. Move o cursor para ver o impacto.';

  @override
  String get genderGapTauxActivite => 'Taxa de atividade';

  @override
  String get genderGapParametres => 'Parâmetros';

  @override
  String get genderGapRevenuAnnuel => 'Rendimento anual bruto (100%)';

  @override
  String get genderGapAge => 'Idade';

  @override
  String genderGapAgeValue(String age) {
    return '$age anos';
  }

  @override
  String get genderGapAvoirLpp => 'Capital LPP atual';

  @override
  String get genderGapAnneesCotisation => 'Anos de contribuição';

  @override
  String get genderGapCanton => 'Cantão';

  @override
  String get genderGapDemoMode =>
      'Modo demo: perfil exemplo. Completa o teu diagnóstico para resultados personalizados.';

  @override
  String get genderGapRenteLppEstimee => 'Renda LPP estimada';

  @override
  String genderGapProjection(String annees) {
    return 'Projeção a $annees anos (idade 65)';
  }

  @override
  String get genderGapAt100 => 'A 100%';

  @override
  String genderGapAtTaux(String taux) {
    return 'A $taux%';
  }

  @override
  String get genderGapPerYear => '/ano';

  @override
  String get genderGapLacuneAnnuelle => 'Lacuna anual';

  @override
  String get genderGapLacuneTotale => 'Lacuna total (~20 anos)';

  @override
  String get genderGapCoordinationTitle => 'Entender a dedução de coordenação';

  @override
  String get genderGapCoordinationBody =>
      'A dedução de coordenação é um montante fixo de CHF 26\'460 subtraído do teu salário bruto para calcular o salário coordenado (base LPP). Este montante é o mesmo quer trabalhes a 100% ou a 50%.';

  @override
  String get genderGapSalaireBrut100 => 'Salário bruto a 100%';

  @override
  String get genderGapSalaireCoordonne100 => 'Salário coordenado a 100%';

  @override
  String genderGapSalaireBrutTaux(String taux) {
    return 'Salário bruto a $taux%';
  }

  @override
  String genderGapSalaireCoordonneTaux(String taux) {
    return 'Salário coordenado a $taux%';
  }

  @override
  String get genderGapDeductionFixe => 'Dedução coordenação (fixa)';

  @override
  String get genderGapSourceCoordination => 'Fonte: LPP art. 8, OPP2 art. 5';

  @override
  String get genderGapStatOfsTitle => 'Estatística OFS';

  @override
  String get genderGapRecommandations => 'Recomendações';

  @override
  String get genderGapDisclaimer =>
      'Os resultados apresentados são estimativas simplificadas a título indicativo. Não constituem aconselhamento financeiro personalizado. Consulta a tua caixa de pensões e um especialista qualificado antes de tomar decisões.';

  @override
  String get genderGapSources => 'Fontes';

  @override
  String get genderGapSourcesBody =>
      'LPP art. 8 (dedução de coordenação) / LPP art. 14 (taxa de conversão 6.8%) / OPP2 art. 5 / OPP3 art. 7 / LPP art. 79b (resgate voluntário) / OFS 2024 (estatísticas gender gap)';

  @override
  String get achievementsErrorMessage =>
      'O carregamento falhou. Tentar novamente?';

  @override
  String get documentsEmptyVoice =>
      'Vazio por enquanto. Digitaliza um certificado e tudo fica mais claro.';

  @override
  String documentsConfidenceChoc(String count, String pct) {
    return '$count documentos = $pct% de confiança';
  }

  @override
  String get lamalFranchiseAppBarTitle => 'Franquia LAMal';

  @override
  String get lamalFranchiseDemoMode => 'MODO DEMO';

  @override
  String get lamalFranchiseHeaderTitle => 'A tua franquia LAMal';

  @override
  String get lamalFranchiseHeaderSubtitle =>
      'Encontra a franquia ideal segundo os teus custos de saúde';

  @override
  String get lamalFranchiseIntro =>
      'Uma franquia alta reduz o teu prémio mensal, mas aumenta os custos em caso de doença. Desloca os cursores para encontrar o equilíbrio.';

  @override
  String get lamalFranchiseToggleAdulte => 'Adulto';

  @override
  String get lamalFranchiseToggleEnfant => 'Criança';

  @override
  String get lamalFranchisePrimeSliderLabel => 'Prémio mensal (franquia 300)';

  @override
  String get lamalFranchiseDepensesSliderLabel =>
      'Custos de saúde anuais estimados';

  @override
  String get lamalFranchiseComparisonHeader => 'COMPARAÇÃO DE FRANQUIAS';

  @override
  String get lamalFranchiseRecommandee => 'RECOMENDADA';

  @override
  String lamalFranchiseTotalPrefix(String amount) {
    return 'Total: $amount';
  }

  @override
  String get lamalFranchisePrimeAn => 'Prémio/ano';

  @override
  String get lamalFranchiseQuotePart => 'Copagamento';

  @override
  String get lamalFranchiseEconomie => 'Poupança';

  @override
  String get lamalFranchiseBreakEvenTitle => 'Limiares de rentabilidade';

  @override
  String lamalFranchiseBreakEvenItem(String seuil, String basse, String haute) {
    return 'Acima de $seuil de custos, a franquia $basse torna-se mais vantajosa que $haute.';
  }

  @override
  String get lamalFranchiseRecommandationsHeader => 'RECOMENDAÇÕES';

  @override
  String get lamalFranchiseAlertText =>
      'Lembrete: podes mudar a tua franquia antes de 30 de novembro de cada ano para o ano seguinte.';

  @override
  String get lamalFranchiseDisclaimer =>
      'Estimativa educativa. Os prémios variam conforme a seguradora, a região e o modelo. Não constitui aconselhamento financeiro (LSFin).';

  @override
  String get lamalFranchiseSourcesHeader => 'Fontes';

  @override
  String get lamalFranchiseSourcesBody =>
      'LAMal art. 62-64 (franquia e copagamento) / OAMal (regulamento) / priminfo.admin.ch (comparador oficial) / LAMal art. 7 (livre escolha do segurador) / LAMal art. 41a (modelos alternativos)';

  @override
  String get lamalFranchisePrimeMin => 'CHF 200';

  @override
  String get lamalFranchisePrimeMax => 'CHF 600';

  @override
  String get lamalFranchiseDepensesMin => 'CHF 0';

  @override
  String get lamalFranchiseDepensesMax => 'CHF 10\'000';

  @override
  String get lamalFranchiseSelectAdulte => 'Selecionar adulto';

  @override
  String get lamalFranchiseSelectEnfant => 'Selecionar criança';

  @override
  String get firstJobCantonLabel => 'Cantão';

  @override
  String get firstJobSalaryMin => 'CHF 2\'000';

  @override
  String get firstJobSalaryMax => 'CHF 15\'000';

  @override
  String get firstJobActivityMin => '10 %';

  @override
  String get firstJobActivityMax => '100 %';

  @override
  String firstJobFiscalSavings(String amount) {
    return 'Poupança fiscal estimada: ~$amount/ano';
  }

  @override
  String firstJobFranchiseSavings(String amount) {
    return 'Franquia 2\'500 vs 300: poupança estimada de ~$amount/ano em prémios';
  }

  @override
  String get firstJobTopBadge => 'TOP';

  @override
  String get authLoginSubtitle => 'Acede ao teu espaço financeiro pessoal';

  @override
  String get authPasswordRequired => 'Palavra-passe obrigatória';

  @override
  String get authForgotPasswordLink => 'Esqueceste a palavra-passe?';

  @override
  String get authVerifyEmailLink => 'Verificar o meu e-mail';

  @override
  String get authDateOfBirth => 'Data de nascimento';

  @override
  String get authDateOfBirthHint => 'dd.mm.aaaa';

  @override
  String get authDateOfBirthRequired => 'Necessária para as projeções AVS/LPP';

  @override
  String get authDateOfBirthTooYoung =>
      'Deves ter pelo menos 18 anos (CGU art. 4.1)';

  @override
  String get authDateOfBirthHelp => 'Data de nascimento';

  @override
  String get authDateOfBirthCancel => 'Cancelar';

  @override
  String get authDateOfBirthConfirm => 'Validar';

  @override
  String get authPasswordHintFull =>
      '8+ caracteres, maiúscula, número, símbolo';

  @override
  String get authPasswordMinChars => 'Mínimo 8 caracteres';

  @override
  String get authPasswordNeedUppercase =>
      'Pelo menos uma maiúscula obrigatória';

  @override
  String get authPasswordNeedDigit => 'Pelo menos um número obrigatório';

  @override
  String get authPasswordNeedSpecial =>
      'Pelo menos um caractere especial obrigatório (!@#\$...)';

  @override
  String get authConfirmRequired => 'Confirmação obrigatória';

  @override
  String get authPrivacyPolicyText => 'política de privacidade';

  @override
  String get slmStatusRunning => 'Pronto — o coach usa IA on-device';

  @override
  String get slmStatusReady => 'Modelo descarregado — inicialização necessária';

  @override
  String get slmStatusError =>
      'Erro — dispositivo não compatível ou memória insuficiente';

  @override
  String get slmStatusDownloading => 'A descarregar…';

  @override
  String get slmStatusNotDownloaded => 'Modelo não descarregado';

  @override
  String get slmStatusModelReady => 'Modelo pronto — inicia a inicialização';

  @override
  String slmSizeLabel(String size) {
    return 'Tamanho: $size';
  }

  @override
  String slmVersionLabel(String version) {
    return 'Versão: $version';
  }

  @override
  String slmWifiEstimate(int minutes) {
    return '~$minutes min em WiFi';
  }

  @override
  String slmDownloadButton(String size) {
    return 'Descarregar ($size)';
  }

  @override
  String slmDownloadDialogBody(String size, int minutes, String hint) {
    return 'O modelo tem $size. Certifica-te de que estás ligado ao WiFi.\n\n~$minutes min em WiFi. Compatível: $hint.';
  }

  @override
  String slmDownloadFailedSnack(String reason) {
    return 'Download falhou. $reason';
  }

  @override
  String get slmDownloadFailedDefault =>
      'Verifica o teu WiFi e o espaço disponível.';

  @override
  String get slmDownloadNotAvailable =>
      'Esta versão não suporta o download do modelo.';

  @override
  String slmInfoDownload(int minutes) {
    return 'Descarrega o modelo uma vez (~$minutes min em WiFi)';
  }

  @override
  String get slmInfoOnDevice => 'A IA funciona diretamente no teu telemóvel';

  @override
  String get slmInfoOffline => 'Funciona mesmo sem internet';

  @override
  String get slmInfoPrivacy => 'Os teus dados nunca saem do teu dispositivo';

  @override
  String get slmInfoSpeed =>
      'Respostas em 2-4 segundos num dispositivo recente';

  @override
  String slmInfoSourceModel(String modelId) {
    return 'Fonte do modelo: $modelId';
  }

  @override
  String get slmInfoAuthConfigured => 'Autenticação HuggingFace: configurada';

  @override
  String get slmInfoAuthNotConfigured =>
      'Autenticação HuggingFace: não configurada (download impossível se o URL Gemma for privado)';

  @override
  String slmInfoCompatibility(String hint, String size, int ram) {
    return 'Compatibilidade: $hint.\nO modelo necessita de $size de espaço e ~$ram GB de RAM.';
  }

  @override
  String get consentErrorMessage => 'Algo correu mal. Tenta mais tarde.';

  @override
  String get adminObsAuthBilling => 'Auth & Billing';

  @override
  String get adminObsOnboardingQuality => 'Qualidade do onboarding';

  @override
  String get adminObsCohorts => 'Coortes (variante x plataforma)';

  @override
  String get adminObsNoData => 'Sem dados';

  @override
  String get adminAnalyticsTitle => 'Analytics';

  @override
  String get adminAnalyticsLoadError =>
      'Não foi possível carregar os analytics';

  @override
  String get adminAnalyticsRetry => 'Tentar novamente';

  @override
  String get adminAnalyticsFunnel => 'Funnel de conversão';

  @override
  String get adminAnalyticsByScreen => 'Eventos por ecrã';

  @override
  String get adminAnalyticsByCategory => 'Eventos por categoria';

  @override
  String get adminAnalyticsNoFunnel => 'Ainda não há dados de funnel.';

  @override
  String get adminAnalyticsNoData => 'Ainda não há dados.';

  @override
  String get adminAnalyticsSessions => 'Sessões';

  @override
  String get adminAnalyticsEvents => 'Eventos';

  @override
  String get amortizationAppBarTitle => 'Direta vs indireta';

  @override
  String get eplCombinedAppBarTitle => 'EPL multi-fontes';

  @override
  String get eplCombinedMinRequired => 'Mínimo exigido: 20 %';

  @override
  String get eplCombinedFundsBreakdown => 'Distribuição dos fundos próprios';

  @override
  String get eplCombinedParameters => 'Parâmetros';

  @override
  String get eplCombinedCanton => 'Cantão';

  @override
  String get eplCombinedTargetPrice => 'Preço de compra alvo';

  @override
  String get eplCombinedCashSavings => 'Poupança em dinheiro';

  @override
  String get eplCombinedAvoir3a => 'Saldo pilar 3a';

  @override
  String get eplCombinedAvoirLpp => 'Saldo LPP';

  @override
  String get eplCombinedSourcesDetail => 'Detalhe das fontes';

  @override
  String get eplCombinedTotalEquity => 'Total fundos próprios';

  @override
  String get eplCombinedEstimatedTaxes => 'Impostos estimados (3a + LPP)';

  @override
  String get eplCombinedNetTotal => 'Montante líquido total';

  @override
  String get eplCombinedRequiredEquity => 'Fundos próprios exigidos (20 %)';

  @override
  String get eplCombinedEstimatedTax => 'Imposto estimado';

  @override
  String get eplCombinedNet => 'Líquido';

  @override
  String get eplCombinedRecommendedOrder => 'Ordem recomendada';

  @override
  String get eplCombinedOrderCashTitle => 'Poupança em dinheiro';

  @override
  String get eplCombinedOrderCashReason =>
      'Sem imposto, sem impacto na previdência';

  @override
  String get eplCombinedOrder3aTitle => 'Levantamento 3a';

  @override
  String get eplCombinedOrder3aReason =>
      'Imposto reduzido no levantamento, impacto limitado na previdência de velhice';

  @override
  String get eplCombinedOrderLppTitle => 'Levantamento LPP (EPL)';

  @override
  String get eplCombinedOrderLppReason =>
      'Impacto direto nas prestações de risco (invalidez, morte). Usar como último recurso.';

  @override
  String get eplCombinedAttentionPoints => 'Pontos de atenção';

  @override
  String get eplCombinedSource =>
      'Fonte: LPP art. 30c (EPL), OPP3, LIFD art. 38. Taxas cantonais estimadas para fins educativos.';

  @override
  String get eplCombinedPriceOfProperty => 'do preço';

  @override
  String get imputedRentalAppBarTitle => 'Valor locativo';

  @override
  String get imputedRentalIntroTitle => 'O que é o valor locativo?';

  @override
  String get imputedRentalIntroBody =>
      'Na Suíça, os proprietários devem declarar um rendimento fictício (valor locativo) correspondente à renda que poderiam obter alugando o seu imóvel. Em contrapartida, podem deduzir os juros hipotecários e os custos de manutenção.';

  @override
  String get imputedRentalDecomposition => 'Decomposição';

  @override
  String get imputedRentalBarLocative => 'Valor locativo';

  @override
  String get imputedRentalBarDeductions => 'Deduções';

  @override
  String get imputedRentalAddedIncome => 'Rendimento tributável adicionado';

  @override
  String get imputedRentalLocativeValue => 'Valor locativo';

  @override
  String get imputedRentalDeductionsLabel => 'Deduções';

  @override
  String get imputedRentalMortgageInterest => 'Juros hipotecários';

  @override
  String get imputedRentalMaintenanceCosts => 'Custos de manutenção';

  @override
  String get imputedRentalBuildingInsurance =>
      'Seguro do edifício (estimativa)';

  @override
  String get imputedRentalTotalDeductions => 'Total deduções';

  @override
  String get imputedRentalNetImpact =>
      'Impacto líquido no rendimento tributável';

  @override
  String imputedRentalFiscalImpact(String rate) {
    return 'Impacto fiscal estimado (taxa marginal $rate %)';
  }

  @override
  String get imputedRentalParameters => 'Parâmetros';

  @override
  String get imputedRentalCanton => 'Cantão';

  @override
  String get imputedRentalPropertyValue => 'Valor venal do imóvel';

  @override
  String get imputedRentalAnnualInterest => 'Juros hipotecários anuais';

  @override
  String get imputedRentalEffectiveMaintenance =>
      'Custos de manutenção efetivos';

  @override
  String get imputedRentalOldProperty => 'Imóvel antigo (≥ 10 anos)';

  @override
  String get imputedRentalForfaitOld =>
      'Forfait manutenção: 20 % do valor locativo';

  @override
  String get imputedRentalForfaitNew =>
      'Forfait manutenção: 10 % do valor locativo';

  @override
  String get imputedRentalMarginalRate => 'Taxa marginal estimada';

  @override
  String get imputedRentalSource =>
      'Fonte: LIFD art. 21 al. 1 let. b, art. 32. Taxas cantonais estimadas para fins educativos.';

  @override
  String get saronVsFixedAppBarTitle => 'SARON vs fixa';

  @override
  String saronVsFixedCumulativeCost(int years) {
    return 'Custo acumulado em $years anos';
  }

  @override
  String get saronVsFixedLegendFixed => 'Fixa';

  @override
  String get saronVsFixedLegendSaronStable => 'SARON estável';

  @override
  String get saronVsFixedLegendSaronRise => 'SARON em alta';

  @override
  String get saronVsFixedParameters => 'Parâmetros';

  @override
  String get saronVsFixedMortgageAmount => 'Montante hipotecário';

  @override
  String get saronVsFixedDuration => 'Duração';

  @override
  String saronVsFixedYears(int years) {
    return '$years anos';
  }

  @override
  String get saronVsFixedCostComparison => 'Comparação de custos';

  @override
  String saronVsFixedRate(String rate) {
    return 'Taxa: $rate';
  }

  @override
  String get saronVsFixedInsightText =>
      'O cenário SARON em alta simula +0,25 %/ano nos 3 primeiros anos. Na realidade, a evolução depende da política monetária do BNS.';

  @override
  String get saronVsFixedSource =>
      'Fonte: taxas indicativas do mercado suíço 2026. Não constitui aconselhamento hipotecário.';

  @override
  String get avsCotisationsTitle => 'Contribuições AVS';

  @override
  String get avsCotisationsHeaderInfo =>
      'Como independente, pagas a totalidade das contribuições AVS/AI/APG. Um empregado paga apenas metade (5.3%), o empregador cobre o resto.';

  @override
  String get avsCotisationsRevenuLabel => 'O teu rendimento líquido anual';

  @override
  String get avsCotisationsSliderMin => 'CHF 0';

  @override
  String get avsCotisationsSliderMax250k => 'CHF 250’000';

  @override
  String avsCotisationsChiffreChocCaption(String amount) {
    return 'Como independente, pagas $amount/ano a mais que um empregado';
  }

  @override
  String get avsCotisationsTauxEffectif => 'Taxa efetiva';

  @override
  String get avsCotisationsCotisationAn => 'Contribuição /ano';

  @override
  String get avsCotisationsCotisationMois => 'Contribuição /mês';

  @override
  String get avsCotisationsTranche => 'Escalão';

  @override
  String get avsCotisationsComparaisonTitle => 'Comparação anual';

  @override
  String get avsCotisationsIndependant => 'Independente';

  @override
  String get avsCotisationsSalarie => 'Empregado (parte empregado)';

  @override
  String avsCotisationsSurcout(String amount) {
    return 'Custo adicional independente: +$amount/ano';
  }

  @override
  String get avsCotisationsBaremeTitle => 'A tua posição na escala';

  @override
  String avsCotisationsTauxEffectifLabel(String taux) {
    return 'A tua taxa efetiva: $taux%';
  }

  @override
  String get avsCotisationsBonASavoir => 'Bom saber';

  @override
  String get avsCotisationsEduDegressifTitle => 'Escala degressiva';

  @override
  String get avsCotisationsEduDegressifBody =>
      'A taxa diminui para rendimentos baixos (entre CHF 10’100 e CHF 60’500). Acima, aplica-se a taxa plena de 10.6%.';

  @override
  String get avsCotisationsEduDoubleChargeTitle => 'Duplo encargo';

  @override
  String get avsCotisationsEduDoubleChargeBody =>
      'Um empregado paga apenas 5.3%; o empregador cobre a outra metade. Como independente, assumes a totalidade.';

  @override
  String get avsCotisationsEduMinTitle => 'Contribuição mínima';

  @override
  String get avsCotisationsEduMinBody =>
      'Mesmo com rendimento muito baixo, a contribuição mínima é CHF 530/ano.';

  @override
  String get avsCotisationsDisclaimer =>
      'Os montantes são estimativas baseadas na escala AVS/AI/APG vigente. Contacta a tua caixa de compensação para valores exatos.';

  @override
  String get ijmTitle => 'Seguro IJM';

  @override
  String get ijmHeaderInfo =>
      'O seguro IJM compensa a perda de rendimento por doença. Como independente, não há proteção por defeito.';

  @override
  String get ijmRevenuMensuel => 'Rendimento mensal';

  @override
  String get ijmSliderMinChf0 => 'CHF 0';

  @override
  String get ijmSliderMax20k => 'CHF 20’000';

  @override
  String get ijmTonAge => 'A tua idade';

  @override
  String get ijmAgeMin => '18 anos';

  @override
  String get ijmAgeMax => '65 anos';

  @override
  String get ijmDelaiCarence => 'Período de espera';

  @override
  String get ijmDelaiCarenceDesc => 'Período sem prestações';

  @override
  String get ijmJours => 'dias';

  @override
  String ijmChiffreChocCaption(String amount, int jours) {
    return 'Sem seguro IJM, perdes $amount durante o período de espera de $jours dias';
  }

  @override
  String get ijmHighRiskTitle => 'Prémios elevados após 50';

  @override
  String get ijmHighRiskBody =>
      'Os prémios IJM aumentam com a idade. Após 50, o custo pode ser 3-4 vezes superior.';

  @override
  String get ijmPrimeMois => 'Prémio /mês';

  @override
  String get ijmPrimeAn => 'Prémio /ano';

  @override
  String get ijmIndemniteJour => 'Indemnização /dia';

  @override
  String get ijmTrancheAge => 'Faixa etária';

  @override
  String get ijmTimelineTitle => 'Cronologia da cobertura';

  @override
  String get ijmTimelineCouvert => 'Coberto';

  @override
  String get ijmTimelineNoCoverage => 'Sem cobertura';

  @override
  String get ijmTimelineCoverageIjm => 'Cobertura IJM (80%)';

  @override
  String ijmTimelineSummary(int jours, String amount) {
    return 'Durante os primeiros $jours dias de doença não tens rendimento. Depois recebes $amount/dia (80% do rendimento mensal).';
  }

  @override
  String get ijmStrategies => 'Estratégias';

  @override
  String get ijmEduFondsTitle => 'Fundo de espera';

  @override
  String get ijmEduFondsBody =>
      'Reserva 3 meses de rendimento para cobrir o período de espera.';

  @override
  String get ijmEduComparerTitle => 'Comparar ofertas';

  @override
  String get ijmEduComparerBody =>
      'Os prémios variam entre seguradoras. Solicita vários orçamentos.';

  @override
  String get ijmEduLamalTitle => 'Cobertura LAMal insuficiente';

  @override
  String get ijmEduLamalBody =>
      'A LAMal cobre apenas despesas médicas, não a perda de rendimento.';

  @override
  String get ijmDisclaimer =>
      'Os prémios são estimativas baseadas em médias de mercado.';

  @override
  String ijmJoursCarenceLabel(int jours) {
    return '$jours dias de espera';
  }

  @override
  String get pillar3aIndepTitle => '3º pilar independente';

  @override
  String get pillar3aIndepHeaderInfo =>
      'Como independente sem LPP, acedes ao «grande 3a»: deduz até 20% do rendimento líquido (máx CHF 36’288/ano).';

  @override
  String get pillar3aIndepLppToggle => 'Afiliado a LPP voluntária?';

  @override
  String get pillar3aIndepPlafondPetit => 'Teto 3a: CHF 7’258 (pequeno 3a)';

  @override
  String get pillar3aIndepPlafondGrand =>
      'Teto 3a: 20% do rendimento, máx CHF 36’288 (grande 3a)';

  @override
  String get pillar3aIndepRevenuLabel => 'Rendimento líquido anual';

  @override
  String get pillar3aIndepSliderMax300k => 'CHF 300’000';

  @override
  String get pillar3aIndepTauxLabel => 'Taxa marginal';

  @override
  String get pillar3aIndepChiffreChocCaption =>
      'de poupança fiscal anual graças ao 3º pilar';

  @override
  String pillar3aIndepChiffreChocAvantageSalarie(String amount) {
    return 'Poupas $amount/ano a mais que um empregado graças ao grande 3a';
  }

  @override
  String get pillar3aIndepPlafondApplicable => 'Teto aplicável';

  @override
  String get pillar3aIndepEconomieFiscaleAn => 'Poupança fiscal /ano';

  @override
  String get pillar3aIndepPlafondSalarie => 'Teto empregado';

  @override
  String get pillar3aIndepEconomieSalarie => 'Poupança empregado';

  @override
  String get pillar3aIndepPlafondsCompares => 'Tetos comparados';

  @override
  String pillar3aIndepSuperPouvoir(int multiplier) {
    return '×$multiplier o teu superpoder';
  }

  @override
  String get pillar3aIndepSalarie => 'Empregado';

  @override
  String get pillar3aIndepIndependantToi => 'Independente (tu)';

  @override
  String get pillar3aIndepGrand3aMax => 'Grande 3a (máx legal)';

  @override
  String get pillar3aIndepEn20ans => 'Em 20 anos a 4%';

  @override
  String get pillar3aIndepVs => 'vs';

  @override
  String get pillar3aIndepToi => 'Tu';

  @override
  String pillar3aIndepDifference(String amount) {
    return 'Diferença: +$amount';
  }

  @override
  String get pillar3aIndepBonASavoir => 'Bom saber';

  @override
  String get pillar3aIndepEduComptesTitle => 'Abre várias contas 3a';

  @override
  String get pillar3aIndepEduComptesBody =>
      'A estratégia de contas múltiplas (até 5) é recomendada para otimizar o levantamento escalonado.';

  @override
  String get pillar3aIndepEduConditionTitle => 'Condição: sem LPP';

  @override
  String get pillar3aIndepEduConditionBody =>
      'O grande 3a só está disponível sem LPP voluntária. Com LPP, o teto desce para 7’258.';

  @override
  String get pillar3aIndepEduInvestirTitle => 'Investir em vez de poupar';

  @override
  String get pillar3aIndepEduInvestirBody =>
      'Para um horizonte longo (>10 anos), um 3a investido em ações pode oferecer rendimentos superiores.';

  @override
  String get pillar3aIndepDisclaimer =>
      'As poupanças fiscais baseiam-se na taxa marginal indicada. Consulta um especialista.';

  @override
  String get dividendeVsSalaireTitle => 'Dividendo vs Salário';

  @override
  String get dividendeVsSalaireHeaderInfo =>
      'Se possuis uma SA ou Sarl, podes pagar-te salário e dividendos. O dividendo é tributado a 50% e escapa às contribuições AVS.';

  @override
  String get dividendeVsSalaireBenefice => 'Lucro total';

  @override
  String get dividendeVsSalaireSliderMax500k => 'CHF 500’000';

  @override
  String get dividendeVsSalairePartSalaire => 'Parte salário';

  @override
  String get dividendeVsSalaireTauxMarginal => 'Taxa marginal';

  @override
  String dividendeVsSalaireChiffreChocPositive(String amount) {
    return 'O split adaptado poupa-te $amount/ano vs 100% salário';
  }

  @override
  String get dividendeVsSalaireChiffreChocNeutral =>
      'Ajusta o split para encontrar poupanças';

  @override
  String get dividendeVsSalaireRequalificationTitle =>
      'Risco de requalificação';

  @override
  String get dividendeVsSalaireRequalificationBody =>
      'Se a parte salarial for inferior a ~60% do lucro, a administração fiscal pode requalificar dividendos como salário.';

  @override
  String get dividendeVsSalairePartSalaireLabel => 'Parte salário';

  @override
  String get dividendeVsSalairePartDividende => 'Parte dividendo';

  @override
  String dividendeVsSalairePctBenefice(int pct) {
    return '$pct% do lucro';
  }

  @override
  String get dividendeVsSalaireChargeSalaire => 'Encargo sobre salário';

  @override
  String get dividendeVsSalaireChargeDividende => 'Encargo sobre dividendo';

  @override
  String get dividendeVsSalaireChargeTotalSplit => 'Encargo total (split)';

  @override
  String get dividendeVsSalaireCharge100Salaire => 'Encargo se 100% salário';

  @override
  String get dividendeVsSalaireChartTitle => 'Encargo total por split';

  @override
  String get dividendeVsSalairePctSalaire0 => '0% salário';

  @override
  String get dividendeVsSalairePctSalaire100 => '100% salário';

  @override
  String get dividendeVsSalaireChargeTotale => 'Encargo total';

  @override
  String get dividendeVsSalaireSplitAdapte => 'Split adaptado';

  @override
  String get dividendeVsSalairePositionActuelle => 'Posição atual';

  @override
  String get dividendeVsSalaireARetenir => 'A reter';

  @override
  String get dividendeVsSalaireEduImpotTitle => 'Imposto sobre lucros';

  @override
  String get dividendeVsSalaireEduImpotBody =>
      'O lucro distribuído como dividendo é tributado primeiro ao nível da empresa, depois ao nível pessoal.';

  @override
  String get dividendeVsSalaireEduAvsTitle => 'AVS apenas sobre salário';

  @override
  String get dividendeVsSalaireEduAvsBody =>
      'As contribuições AVS (~12.5%) aplicam-se apenas à parte salarial.';

  @override
  String get dividendeVsSalaireEduCantonalTitle => 'Prática cantonal';

  @override
  String get dividendeVsSalaireEduCantonalBody =>
      'As autoridades fiscais monitorizam distribuições excessivas de dividendos.';

  @override
  String get dividendeVsSalaireDisclaimer =>
      'Simulação simplificada. Consulta um especialista para uma análise completa.';

  @override
  String get dividendeVsSalaireCantonalDisclaimer =>
      'O impacto fiscal depende da prática cantonal.';

  @override
  String get dividendeVsSalaireComplianceFooter =>
      'Ferramenta educativa — não constitui aconselhamento financeiro (LSFin).';

  @override
  String get dividendeVsSalaireSources =>
      'Fontes: LIFD art. 18, 20, 33; CO art. 660';

  @override
  String get lppVolontaireTitle => 'LPP voluntária';

  @override
  String get lppVolontaireHeaderInfo =>
      'Como independente, podes afiliar-te voluntariamente a um fundo de pensões (LPP). As contribuições são inteiramente dedutíveis.';

  @override
  String get lppVolontaireRevenuLabel => 'Rendimento líquido anual';

  @override
  String get lppVolontaireSliderMax250k => 'CHF 250’000';

  @override
  String get lppVolontaireTonAge => 'A tua idade';

  @override
  String get lppVolontaireAgeMin => '25 anos';

  @override
  String get lppVolontaireAgeMax => '65 anos';

  @override
  String get lppVolontaireTauxMarginal => 'Taxa marginal';

  @override
  String lppVolontaireChiffreChocCaption(String amount) {
    return 'Sem LPP voluntária, perdes $amount/ano de capitalização para a reforma';
  }

  @override
  String get lppVolontaireSalaireCoordonne => 'Salário coordenado';

  @override
  String get lppVolontaireTauxBonification => 'Taxa bonificação';

  @override
  String get lppVolontaireCotisationAn => 'Contribuição /ano';

  @override
  String get lppVolontaireEconomieFiscaleAn => 'Poupança fiscal /ano';

  @override
  String get lppVolontaireTrancheAge => 'Faixa etária';

  @override
  String get lppVolontaireProjectionTitle => 'Projeção de reforma anual';

  @override
  String get lppVolontaireSansLpp => 'Sem LPP (apenas AVS)';

  @override
  String get lppVolontaireAvecLpp => 'Com LPP voluntária';

  @override
  String lppVolontaireGapLabel(String amount) {
    return 'A LPP voluntária poderia adicionar $amount/ano à tua renda';
  }

  @override
  String get lppVolontaireBonificationTitle => 'Taxa de bonificação por idade';

  @override
  String get lppVolontaireToi => 'TU';

  @override
  String get lppVolontaireBonASavoir => 'Bom saber';

  @override
  String get lppVolontaireEduAffiliationTitle => 'Afiliação voluntária';

  @override
  String get lppVolontaireEduAffiliationBody =>
      'Os independentes podem afiliar-se voluntariamente à LPP através de uma fundação coletiva.';

  @override
  String get lppVolontaireEduFiscalTitle => 'Dupla vantagem fiscal';

  @override
  String get lppVolontaireEduFiscalBody =>
      'As contribuições LPP voluntárias são inteiramente dedutíveis do rendimento tributável.';

  @override
  String get lppVolontaireEduImpact3aTitle => 'Impacto no 3a';

  @override
  String get lppVolontaireEduImpact3aBody =>
      'Com a LPP voluntária, o teto 3a desce do grande 3a para o pequeno 3a.';

  @override
  String get lppVolontaireDisclaimer =>
      'As projeções são estimativas. Consulta um especialista em previdência.';

  @override
  String lppVolontairePerAn(String amount) {
    return '$amount/ano';
  }

  @override
  String get coverageCheckTitle => 'Check-up cobertura';

  @override
  String get coverageCheckAppBarTitle => 'Check-up cobertura';

  @override
  String get coverageCheckSubtitle => 'Avalia a tua proteção seguradora';

  @override
  String get coverageCheckDemoMode => 'MODO DEMO';

  @override
  String get coverageCheckTonProfil => 'O teu perfil';

  @override
  String get coverageCheckStatut => 'Estatuto profissional';

  @override
  String get coverageCheckSalarie => 'Empregado';

  @override
  String get coverageCheckIndependant => 'Independente';

  @override
  String get coverageCheckSansEmploi => 'Sem emprego';

  @override
  String get coverageCheckHypotheque => 'Hipoteca em curso';

  @override
  String get coverageCheckPersonnesCharge => 'Pessoas a cargo';

  @override
  String get coverageCheckLocataire => 'Inquilino';

  @override
  String get coverageCheckVoyages => 'Viagens frequentes';

  @override
  String get coverageCheckCouvertureActuelle => 'A minha cobertura atual';

  @override
  String get coverageCheckIjm => 'IJM coletiva (empregador)';

  @override
  String get coverageCheckLaa => 'LAA (seguro acidentes)';

  @override
  String get coverageCheckRcPrivee => 'RC privada';

  @override
  String get coverageCheckMenage => 'Seguro lar';

  @override
  String get coverageCheckProtJuridique => 'Proteção jurídica';

  @override
  String get coverageCheckVoyage => 'Seguro viagem';

  @override
  String get coverageCheckDeces => 'Seguro falecimento';

  @override
  String get coverageCheckScore => 'Score de cobertura';

  @override
  String coverageCheckLacunes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lacunas críticas',
      one: '$count lacuna crítica',
    );
    return '$_temp0';
  }

  @override
  String get coverageCheckAnalyseTitle => 'Análise detalhada';

  @override
  String get coverageCheckRecommandationsTitle => 'Recomendações';

  @override
  String get coverageCheckCouvert => 'Coberto';

  @override
  String get coverageCheckNonCouvert => 'Não coberto';

  @override
  String get coverageCheckAVerifier => 'A verificar';

  @override
  String get coverageCheckCritique => 'Crítico';

  @override
  String get coverageCheckHaute => 'Alta';

  @override
  String get coverageCheckMoyenne => 'Média';

  @override
  String get coverageCheckBasse => 'Baixa';

  @override
  String get coverageCheckDisclaimer =>
      'Esta análise é indicativa. Consulta um especialista em seguros.';

  @override
  String get coverageCheckSources => 'Fontes';

  @override
  String get coverageCheckSourcesBody =>
      'CO art. 41 (RC) / CO art. 324a (IJM) / LAA art. 4 / LAMal art. 34 / LCA / Direito cantonal';

  @override
  String get coverageCheckSlashHundred => '/ 100';

  @override
  String coverageCheckAnsLabel(int age) {
    return '$age anos';
  }

  @override
  String get eplAppBarTitle => 'Levantamento EPL';

  @override
  String get eplIntroTitle => 'Levantamento EPL — Propriedade habitacional';

  @override
  String get eplIntroBody =>
      'O EPL permite utilizar o teu capital LPP para financiar a compra de habitação, amortizar uma hipoteca ou financiar renovações. Montante mínimo: CHF 20’000. Este levantamento impacta diretamente as tuas prestações de risco.';

  @override
  String get eplSectionParametres => 'Parâmetros';

  @override
  String get eplLabelAvoirTotal => 'Capital LPP total';

  @override
  String get eplLabelAge => 'Idade';

  @override
  String eplLabelAgeFormat(int age) {
    return '$age anos';
  }

  @override
  String get eplLabelMontantSouhaite => 'Montante desejado';

  @override
  String get eplLabelCanton => 'Cantão';

  @override
  String get eplLabelRachatsRecents => 'Compras LPP recentes';

  @override
  String get eplLabelRachatsQuestion =>
      'Fizeste uma compra LPP nos últimos 3 anos?';

  @override
  String get eplLabelAnneesSDepuisRachat => 'Anos desde a compra';

  @override
  String eplLabelAnneesSDepuisRachatFormat(int years, String suffix) {
    return '$years ano$suffix';
  }

  @override
  String get eplSectionResultat => 'Resultado';

  @override
  String get eplMontantMaxRetirable => 'Montante máximo retirável';

  @override
  String get eplMontantApplicable => 'Montante aplicável';

  @override
  String get eplRetraitImpossible =>
      'O levantamento não é possível com a configuração atual.';

  @override
  String get eplSectionImpactPrestations => 'Impacto nas prestações';

  @override
  String get eplReductionInvalidite =>
      'Redução renda invalidez (estimativa anual)';

  @override
  String get eplReductionDeces => 'Redução capital-falecimento (estimativa)';

  @override
  String get eplImpactPrestationsNote =>
      'O levantamento EPL reduz proporcionalmente as tuas prestações de risco. Verifica com a tua caixa de pensões os montantes exatos e as possibilidades de seguro complementar.';

  @override
  String get eplSectionImpactRente => 'Impacto na renda';

  @override
  String get eplRenteSansEpl => 'Renda sem EPL';

  @override
  String get eplRenteAvecEpl => 'Renda com EPL';

  @override
  String get eplPerteMensuelle => 'Perda mensal';

  @override
  String get eplImpactRenteNote =>
      'Estimativa educativa baseada num salário de CHF 100’000, rendimento caixa 2%, taxa de conversão 6.8%. O montante real depende da tua situação.';

  @override
  String get eplSectionFiscale => 'Estimativa fiscal';

  @override
  String get eplMontantRetire => 'Montante levantado';

  @override
  String get eplImpotEstime => 'Imposto estimado sobre o levantamento';

  @override
  String get eplMontantNet => 'Montante líquido após impostos';

  @override
  String get eplFiscaleNote =>
      'O levantamento em capital é tributado a uma taxa reduzida (aprox. 1/5 da escala ordinária). A taxa exata depende do cantão, da comuna e da situação pessoal.';

  @override
  String get eplSectionPointsAttention => 'Pontos de atenção';

  @override
  String get librePassageAppBarTitle => 'Livre passagem';

  @override
  String get librePassageSectionSituation => 'Situação';

  @override
  String get librePassageChipChangementEmploi => 'Mudança de emprego';

  @override
  String get librePassageChipDepartSuisse => 'Saída da Suíça';

  @override
  String get librePassageChipCessationActivite => 'Cessação de atividade';

  @override
  String get librePassageSectionProfil => 'O teu perfil';

  @override
  String get librePassageLabelAge => 'A tua idade';

  @override
  String librePassageLabelAgeFormat(int age) {
    return '$age anos';
  }

  @override
  String get librePassageLabelAvoir => 'Capital de livre passagem';

  @override
  String get librePassageLabelNouvelEmployeur => 'Novo empregador';

  @override
  String get librePassageLabelNouvelEmployeurQuestion =>
      'Já tens um novo empregador?';

  @override
  String get librePassageSectionAlertes => 'Alertas';

  @override
  String get librePassageSectionChecklist => 'Checklist';

  @override
  String get librePassageUrgenceCritique => 'Crítico';

  @override
  String get librePassageUrgenceHaute => 'Alta';

  @override
  String get librePassageUrgenceMoyenne => 'Média';

  @override
  String get librePassageSectionRecommandations => 'Recomendações';

  @override
  String get librePassageCentrale2eTitle => 'Central do 2° pilar (sfbvg.ch)';

  @override
  String get librePassageCentrale2eSubtitle =>
      'Procurar capitais de livre passagem esquecidos';

  @override
  String get librePassagePrivacyNote =>
      'Os teus dados ficam no teu dispositivo. Nenhuma informação é transmitida a terceiros. Conforme a nLPD.';

  @override
  String get providerComparatorAppBarTitle => 'Comparador 3a';

  @override
  String providerComparatorChiffreChocLabel(int duree) {
    return 'Diferença em $duree anos';
  }

  @override
  String get providerComparatorChiffreChocSubtitle =>
      'entre o provider mais e menos rentável';

  @override
  String get providerComparatorSectionParametres => 'Parâmetros';

  @override
  String get providerComparatorLabelAge => 'Idade';

  @override
  String providerComparatorLabelAgeFormat(int age) {
    return '$age anos';
  }

  @override
  String get providerComparatorLabelVersement => 'Contribuição anual';

  @override
  String get providerComparatorLabelDuree => 'Duração';

  @override
  String providerComparatorLabelDureeFormat(int duree) {
    return '$duree anos';
  }

  @override
  String get providerComparatorLabelProfilRisque => 'Perfil de risco';

  @override
  String get providerComparatorProfilPrudent => 'Prudente';

  @override
  String get providerComparatorProfilEquilibre => 'Equilibrado';

  @override
  String get providerComparatorProfilDynamique => 'Dinâmico';

  @override
  String get providerComparatorSectionComparaison => 'Comparação';

  @override
  String get providerComparatorRendement => 'Rendimento';

  @override
  String get providerComparatorFrais => 'Custos';

  @override
  String get providerComparatorCapitalFinal => 'Capital final';

  @override
  String get providerComparatorWarningLabel => 'Atenção';

  @override
  String providerComparatorDiffVsPremier(String amount) {
    return '-CHF $amount vs primeiro';
  }

  @override
  String get providerComparatorAssuranceTitle => 'Atenção — Seguro 3a';

  @override
  String get providerComparatorAssuranceNote =>
      'Os seguros 3a combinam poupança e cobertura de risco, mas as comissões elevadas (frequentemente > 1.5%) e a rigidez do contrato tornam-nos desfavoráveis para jovens poupadores.';

  @override
  String documentDetailFieldsExtracted(int found, int total) {
    return '$found campos extraídos de $total';
  }

  @override
  String get documentDetailProfileUpdated => 'Perfil atualizado com sucesso';

  @override
  String get documentDetailCancelButton => 'Cancelar';

  @override
  String get portfolioTitle => 'O meu património';

  @override
  String get portfolioNetWorth => 'Valor líquido total';

  @override
  String get portfolioReadiness => 'Readiness Index';

  @override
  String get portfolioEnvelopeTitle => 'Allocation by envelope';

  @override
  String get portfolioLibre => 'Free (Investment account)';

  @override
  String get portfolioLie => 'Tied (Pillar 3a)';

  @override
  String get portfolioReserve => 'Reserved (Emergency fund)';

  @override
  String get portfolioCoachAdvice =>
      'Your allocation is healthy. Consider rebalancing your 3a soon.';

  @override
  String get portfolioDebtWarning =>
      'Debt alert: Your top priority is debt reduction before any reinvestment.';

  @override
  String get portfolioSafeModeTitle => 'Debt reduction priority';

  @override
  String get portfolioSafeModeMsg =>
      'Allocation advice is disabled in protection mode. Your priority is reducing debt before rebalancing your portfolio.';

  @override
  String get portfolioRetirement => 'Retirement readiness';

  @override
  String get portfolioProperty => 'Property project';

  @override
  String get portfolioFamily => 'Family protection';

  @override
  String get portfolioToday => 'today';

  @override
  String get timelineTitle => 'O meu percurso';

  @override
  String get timelineHeader => 'A tua vida financeira,\npasso a passo.';

  @override
  String get timelineSubheader =>
      'Ferramentas essenciais e eventos de vida — tudo está aqui.';

  @override
  String get timelineSectionTitle => 'Eventos de vida';

  @override
  String get timelineSectionSubtitle =>
      'Seleciona um evento para simular o seu impacto financeiro.';

  @override
  String get confidenceDashboardTitle => 'Precisão do perfil';

  @override
  String get confidenceDetailByAxis => 'Detalhe por eixo';

  @override
  String get confidenceFeatureGates => 'Funcionalidades desbloqueadas';

  @override
  String get confidenceImprove => 'Melhora a tua precisão';

  @override
  String confidenceRequired(int percent) {
    return '$percent % necessário';
  }

  @override
  String get confidenceLevelExcellent => 'Excellent';

  @override
  String get confidenceLevelGood => 'Good';

  @override
  String get confidenceLevelOk => 'Correct';

  @override
  String get confidenceLevelImprove => 'To improve';

  @override
  String get confidenceLevelInsufficient => 'Insufficient';

  @override
  String get confidenceSources => 'Fontes';

  @override
  String get cockpitDetailTitle => 'Cockpit detalhado';

  @override
  String get cockpitEmptyMsg =>
      'Complete your profile to access the detailed cockpit.';

  @override
  String get cockpitEnrichCta => 'Enrich my profile';

  @override
  String get cockpitDisclaimer =>
      'Simplified educational tool. Not financial advice (FinSA). Sources: OASI art. 21-29, BVG art. 14, BVV3 art. 7.';

  @override
  String get annualRefreshTitle => 'Check-up anual';

  @override
  String get annualRefreshIntro =>
      'A few quick questions to update your profile.';

  @override
  String get annualRefreshSubmit => 'Atualizar o meu perfil';

  @override
  String get annualRefreshResult => 'Perfil atualizado!';

  @override
  String get annualRefreshDashboard => 'Back to dashboard';

  @override
  String get annualRefreshDisclaimer =>
      'Esta ferramenta tem fins educativos e não constitui aconselhamento financeiro na aceção da LSFin. Consulta um·a especialista para aconselhamento personalizado.';

  @override
  String get acceptInvitationTitle => 'Aderir a um agregado';

  @override
  String get acceptInvitationPrompt => 'Enter the code from your partner';

  @override
  String get acceptInvitationCodeValidity => 'The code is valid for 72 hours.';

  @override
  String get acceptInvitationJoin => 'Join household';

  @override
  String get acceptInvitationSuccess => 'Welcome to the household!';

  @override
  String get acceptInvitationSuccessBody =>
      'You joined the Couple+ household. Your retirement projections are now linked.';

  @override
  String get acceptInvitationViewHousehold => 'View my household';

  @override
  String get financialReportTitle => 'O teu Plano Mint';

  @override
  String get financialReportBudget => 'Your Budget';

  @override
  String get financialReportProtection => 'Your Protection';

  @override
  String get financialReportRetirement => 'Your Retirement';

  @override
  String get financialReportTax => 'Your Taxes';

  @override
  String get financialReportPriorities => 'Your 3 priority actions';

  @override
  String get financialReportOptimize3a => 'Optimise your 3a';

  @override
  String get financialReportLppStrategy => 'LPP Buyback Strategy';

  @override
  String get financialReportTransparency => 'Transparency and compliance';

  @override
  String get financialReportLegalMention => 'Legal notice';

  @override
  String get financialReportDisclaimer =>
      'Educational tool — not financial advice under FinSA. Amounts are estimates based on declared data.';

  @override
  String get capKindComplete => 'Completar';

  @override
  String get capKindCorrect => 'Corrigir';

  @override
  String get capKindOptimize => 'Otimizar';

  @override
  String get capKindSecure => 'Proteger';

  @override
  String get capKindPrepare => 'Preparar';

  @override
  String get proofSheetSources => 'Fontes';

  @override
  String get pulseFeedbackRecalculated => 'Impacto recalculado';

  @override
  String get pulseFeedbackAddedRecently => 'Adicionado recentemente';

  @override
  String get debtRatioTitle => 'Diagnóstico de dívida';

  @override
  String get debtRatioSubLabel => 'Rácio dívida / rendimento';

  @override
  String get debtRatioRefineLabel => 'Refinar o diagnóstico';

  @override
  String get debtRatioMinVital => 'Mínimo vital (LP art. 93)';

  @override
  String get debtRatioRecommandations => 'Recomendações';

  @override
  String get debtRatioCtaRouge => 'Cria o teu plano de reembolso';

  @override
  String get debtRatioCtaOrange => 'Otimiza os teus reembolsos';

  @override
  String get debtRatioAidePro => 'Ajuda profissional';

  @override
  String get repaymentTitle => 'Plano de reembolso';

  @override
  String get repaymentLibereDans => 'Livre de dívidas em';

  @override
  String get repaymentMesDettes => 'As minhas dívidas';

  @override
  String get repaymentBudgetLabel => 'Orçamento de reembolso';

  @override
  String get repaymentComparaisonStrategies => 'Comparação de estratégias';

  @override
  String get repaymentStrategyNote =>
      'A escolha depende da tua personalidade financeira, não apenas do custo.';

  @override
  String get repaymentTimelineTitle => 'Cronograma (Avalanche)';

  @override
  String get repaymentTimelineMois => 'Mês';

  @override
  String get repaymentTimelinePaiement => 'Pagamento';

  @override
  String get repaymentTimelineSolde => 'Saldo restante';

  @override
  String get retroactive3aTitle => 'Recuperação 3a';

  @override
  String get retroactive3aHeroTitle => 'Recuperação 3a — Novidade 2026';

  @override
  String get retroactive3aHeroSubtitle =>
      'Recupera até 10 anos de contribuições em falta';

  @override
  String get retroactive3aParametres => 'Parâmetros';

  @override
  String get retroactive3aAnneesARattraper => 'Anos a recuperar';

  @override
  String get retroactive3aTauxMarginal => 'Taxa marginal de imposto';

  @override
  String get retroactive3aAffilieLpp => 'Filiado·a numa caixa de pensões (LPP)';

  @override
  String get retroactive3aPetit3a => 'Pequeno 3a : CHF 7’258/ano';

  @override
  String get retroactive3aGrand3a =>
      'Grande 3a : 20 % do rendimento líquido, máx. CHF 36’288/ano';

  @override
  String get retroactive3aEconomiesFiscales => 'Poupanças fiscais estimadas';

  @override
  String get retroactive3aDetailParAnnee => 'Detalhe por ano';

  @override
  String get retroactive3aHeaderAnnee => 'Ano';

  @override
  String get retroactive3aHeaderPlafond => 'Limite';

  @override
  String get retroactive3aHeaderDeductible => 'Dedutível';

  @override
  String get retroactive3aTotal => 'Total';

  @override
  String get retroactive3aAnneeCourante => 'Ano em curso';

  @override
  String get retroactive3aImpactAvantApres => 'Impacto antes / depois';

  @override
  String get retroactive3aSansRattrapage => 'Sem recuperação';

  @override
  String get retroactive3aAnneeCouranteSeule => 'Apenas ano em curso';

  @override
  String get retroactive3aAvecRattrapage => 'Com recuperação';

  @override
  String get retroactive3aEconomieFiscale => 'de poupança fiscal';

  @override
  String get retroactive3aProchainesEtapes => 'Próximos passos';

  @override
  String get retroactive3aOuvrirCompte => 'Abrir uma conta 3a';

  @override
  String get retroactive3aOuvrirCompteSubtitle =>
      'Compara fornecedores e abre uma conta dedicada à recuperação.';

  @override
  String get retroactive3aPrepDocuments => 'Preparar documentos';

  @override
  String get retroactive3aPrepDocumentsSubtitle =>
      'Certificado de salário, comprovativo de contribuições AVS, justificativo de ausência de 3a por cada ano.';

  @override
  String get retroactive3aConsulterSpecialiste => 'Consultar um·a especialista';

  @override
  String get retroactive3aConsulterSpecialisteSubtitle =>
      'Um·a especialista fiscal pode confirmar a tua taxa marginal e otimizar o calendário de pagamentos.';

  @override
  String get retroactive3aSources => 'Fontes';

  @override
  String coverageCriticalGaps(Object count) {
    return 'lacuna$count crítica$count';
  }

  @override
  String get coverageCriticalGapSingular => 'lacuna crítica';

  @override
  String get coverageCriticalGapPlural => 'lacunas críticas';

  @override
  String get reportTonPlanMint => 'O teu Plano Mint';

  @override
  String get reportCommencer => 'Começar';

  @override
  String get reportOptimise3a => 'Otimiza o teu 3a';

  @override
  String get reportActions => '🎯 As tuas 3 Ações Prioritárias';

  @override
  String get reportMentionLegale => 'Aviso legal';

  @override
  String get reportDisclaimerText =>
      'Herramienta educativa — no constituye asesoramiento financiero según la LSFin. Los montos son estimaciones.';

  @override
  String get compoundTitle => 'Juros Compostos';

  @override
  String get compoundMentorTitle => 'Opinión del Mentor';

  @override
  String get compoundMentorIntro => 'Entender el ';

  @override
  String get compoundMentorOutro =>
      ' es entender cómo tu dinero trabaja para ti mientras duermes.';

  @override
  String get compoundConfiguration => 'Configuración';

  @override
  String get compoundCapitalDepart => 'Capital inicial';

  @override
  String get compoundEpargneMensuelle => 'Ahorro mensual';

  @override
  String get compoundTauxRendement => 'Tasa (Rendimiento anual)';

  @override
  String get compoundHorizonTemps => 'Horizonte temporal';

  @override
  String get compoundValeurFinale => 'Valor Final Potencial';

  @override
  String compoundGainsPercent(String percent) {
    return '$percent% de este monto proviene únicamente de tus ganancias de inversión.';
  }

  @override
  String get compoundLeconsTitle => 'Lecciones Clave';

  @override
  String get compoundTempsRoi => 'El tiempo es rey';

  @override
  String get compoundTempsRoiBody =>
      'Esperar 5 años antes de empezar puede costarte la mitad de tu capital final.';

  @override
  String get compoundEffetLevier => 'El efecto palanca';

  @override
  String get compoundEffetLevierBody =>
      'Una vez iniciado, tu capital genera sus propios intereses, que a su vez generan más.';

  @override
  String get compoundDiscipline => 'Disciplina';

  @override
  String get compoundDisciplineBody =>
      'Las contribuciones mensuales regulares suelen ser más efectivas que intentar sincronizar con el mercado.';

  @override
  String get compoundDisclaimer =>
      'Cálculo teórico basado en un rendimiento constante. Rendimientos pasados no garantizan resultados futuros.';

  @override
  String get leasingTitle => 'Análise Anti-Leasing';

  @override
  String get leasingMentorTitle => 'Reflexión del Mentor';

  @override
  String get leasingMentorBody =>
      'El leasing suele ser una \"fuga\" de capital. Este dinero podría construir tu patrimonio en lugar de financiar la depreciación de un vehículo.';

  @override
  String get leasingDonneesContrat => 'Datos del Contrato';

  @override
  String get leasingMensualitePrevue => 'Cuota mensual prevista';

  @override
  String get leasingDuree => 'Duración del leasing';

  @override
  String get leasingRendementAlternatif => 'Rendimiento alternativo esperado';

  @override
  String get leasingCoutOpportunite20 => 'Costo de oportunidad en 20 años';

  @override
  String get leasingInvestirAuLieu =>
      'Si invirtieras esta cuota en lugar de pagar un leasing, este es el capital que habrías construido.';

  @override
  String leasingFondsPropres(String amount) {
    return 'Son aproximadamente $amount de fondos propios para una compra inmobiliaria.';
  }

  @override
  String get leasingAlternativesTitle => 'Escapar del Agujero Negro';

  @override
  String get leasingOccasion => 'Ocasión de Calidad';

  @override
  String get leasingOccasionBody =>
      'Comprar en efectivo un auto de 3-4 años reduce drásticamente la pérdida de valor.';

  @override
  String get leasingAboGeneral => 'Abono General / Transporte';

  @override
  String get leasingAboGeneralBody =>
      'La comodidad del tren en Suiza suele ser más rentable y tranquila.';

  @override
  String get leasingMobility => 'Mobility / Compartir';

  @override
  String get leasingMobilityBody =>
      'Paga solo cuando conduces. Sin seguro, sin mantenimiento, sin leasing.';

  @override
  String get leasingDisclaimer =>
      'El leasing sigue siendo una opción para algunos profesionales. Este análisis busca sensibilizar sobre los costos a largo plazo.';

  @override
  String get creditTitle => 'Crédito ao Consumo';

  @override
  String get creditMentorTitle => 'Puntos de atención del Mentor';

  @override
  String get creditMentorBody =>
      'En Suiza, un crédito cuesta entre 4% y 10%. Este dinero \"perdido\" en intereses podría invertirse para tu futuro.';

  @override
  String get creditParametres => 'Parámetros';

  @override
  String get creditMontantEmprunter => 'Monto a pedir prestado';

  @override
  String get creditDureeRemboursement => 'Duración del reembolso';

  @override
  String get creditTauxAnnuel => 'Tasa anual efectiva';

  @override
  String get creditTaMensualite => 'Tu Cuota Mensual';

  @override
  String get creditCoutInterets => 'Costo de intereses:';

  @override
  String get creditRateWarning =>
      'Atención: Esta tasa supera el máximo legal suizo de 10%.';

  @override
  String get creditConseilsTitle => 'Consejos del Mentor';

  @override
  String get creditEpargnerDabord => 'Ahorrar primero';

  @override
  String creditEpargnerDabordBody(String amount) {
    return 'Ahorrando durante 12 meses en lugar de pedir prestado, guardas $amount en tu bolsillo.';
  }

  @override
  String get creditCercleConfiance => 'Círculo de confianza';

  @override
  String get creditCercleConfianceBody =>
      'Un préstamo familiar a menudo puede obtenerse al 0% de interés.';

  @override
  String get creditDettesConseils => 'Asesoría de Deudas Suiza';

  @override
  String get creditDettesConseilsBody =>
      'Contáctalos ANTES de firmar si tu situación es frágil.';

  @override
  String get creditDisclaimer =>
      'Información preventiva. No constituye asesoramiento jurídico o financiero. Ley suiza de crédito al consumo (LCC) aplicada.';

  @override
  String get arbitrageBilanTitle => 'Resumo de Arbitragem';

  @override
  String get arbitrageBilanEmptyProfile =>
      'Completa tu perfil para ver tus opciones de arbitraje';

  @override
  String get arbitrageBilanLeviers => 'Tus palancas de acción';

  @override
  String arbitrageBilanPotentiel(String amount) {
    return '$amount/mes de potencial identificado';
  }

  @override
  String get arbitrageBilanCaveat =>
      'Estas opciones no necesariamente se suman — algunas están vinculadas entre sí.';

  @override
  String get arbitrageBilanDebloquer => 'Desbloquea más opciones';

  @override
  String get arbitrageBilanLiens => 'Vínculos entre estas opciones';

  @override
  String get arbitrageBilanScenario =>
      'En este escenario simulado — para explorar en detalle';

  @override
  String get arbitrageBilanDisclaimer =>
      'Herramienta educativa — no constituye asesoramiento financiero (LSFin). Fuentes: LPP art. 14, 79b / LIFD art. 22, 33, 38 / OPP3 art. 7.';

  @override
  String get arbitrageBilanCrossDep1 =>
      'Si retiras tu LPP como capital, el calendario de retiros cambia fundamentalmente.';

  @override
  String get arbitrageBilanCrossDep2 =>
      'Una recompra LPP también aumenta el capital disponible para la elección renta vs capital.';

  @override
  String get annualRefreshSubtitle =>
      'Algumas perguntas rápidas para atualizar o teu perfil.';

  @override
  String get annualRefreshQ1 => 'O teu salário bruto mensal mudou?';

  @override
  String get annualRefreshQ2 => 'A tua situação profissional';

  @override
  String get annualRefreshQ3 => 'O teu saldo LPP atual';

  @override
  String get annualRefreshQ3Help =>
      'Consulta o teu certificado de previdência (recebes-o todos os janeiros)';

  @override
  String get annualRefreshQ4 => 'O teu saldo 3a aproximado';

  @override
  String get annualRefreshQ4Help =>
      'Entra na tua app 3a para ver o saldo exato';

  @override
  String get annualRefreshQ5 => 'Algum projeto imobiliário em vista?';

  @override
  String get annualRefreshQ6 => 'Alguma mudança familiar este ano?';

  @override
  String get annualRefreshQ7 => 'A tua tolerância ao risco';

  @override
  String annualRefreshScoreUp(int delta) {
    return 'A tua pontuação aumentou $delta pontos!';
  }

  @override
  String annualRefreshScoreDown(int delta) {
    return 'A tua pontuação desceu $delta pontos — vamos rever juntos';
  }

  @override
  String get annualRefreshScoreStable =>
      'A tua pontuação está estável — continua assim!';

  @override
  String get annualRefreshRetour => 'Voltar ao painel';

  @override
  String get annualRefreshAvant => 'Antes';

  @override
  String get annualRefreshApres => 'Depois';

  @override
  String get annualRefreshMontantPositif => 'O montante deve ser positivo';

  @override
  String get annualRefreshMemeEmploi => 'Mesmo emprego';

  @override
  String get annualRefreshNouvelEmploi => 'Novo emprego';

  @override
  String get annualRefreshIndependant => 'Independente';

  @override
  String get annualRefreshSansEmploi => 'Sem emprego';

  @override
  String get annualRefreshAucun => 'Nenhum';

  @override
  String get annualRefreshAchat => 'Compra';

  @override
  String get annualRefreshVente => 'Venda';

  @override
  String get annualRefreshRefinancement => 'Refinanciamento';

  @override
  String get annualRefreshMariage => 'Casamento';

  @override
  String get annualRefreshNaissance => 'Nascimento';

  @override
  String get annualRefreshDivorce => 'Divórcio';

  @override
  String get annualRefreshDeces => 'Falecimento';

  @override
  String get annualRefreshConservateur => 'Conservador';

  @override
  String get annualRefreshModere => 'Moderado';

  @override
  String get annualRefreshAgressif => 'Agressivo';

  @override
  String get themeInconnu => 'Tema desconhecido';

  @override
  String get themeInconnuBody => 'Este tema não existe. Voltando atrás.';

  @override
  String get acceptInvitationVoirMenage => 'Ver o meu agregado familiar';

  @override
  String get helpResourceSiteWeb => 'Website';

  @override
  String get locationProjetImmobilier => 'Tu proyecto inmobiliario';

  @override
  String get locationCapitalDispo =>
      'Capital disponible / fondos propios (CHF)';

  @override
  String get locationLoyerMensuel => 'Alquiler mensual actual (CHF)';

  @override
  String get locationPrixBien => 'Precio del inmueble (CHF)';

  @override
  String get locationCanton => 'Cantón';

  @override
  String get locationMarie => 'Casado·a';

  @override
  String get locationComparer => 'Comparar trayectorias';

  @override
  String get locationLouerOuAcheter => 'Alugar ou comprar?';

  @override
  String get locationTrajectoires => 'Trayectorias comparadas';

  @override
  String get locationToucheGraphique =>
      'Toca el gráfico para ver los valores de cada año.';

  @override
  String get locationCapaciteFinma =>
      'Verificación de capacidad financiera (FINMA)';

  @override
  String locationChargeTheorique(String amount) {
    return 'Carga teórica anual: $amount (tasa teórica 5% + amortización 1% + mantenimiento 1%). Los bancos exigen que esta carga no supere 1/3 del ingreso bruto anual.';
  }

  @override
  String locationRevenuMinimum(String amount) {
    return 'Ingreso bruto mínimo necesario: $amount';
  }

  @override
  String get locationHypotheses => 'Hipótesis utilizadas';

  @override
  String get locationRendementMarche => 'Rendimiento de mercado';

  @override
  String get locationAppreciationImmo => 'Apreciación inmobiliaria';

  @override
  String get locationTauxHypo => 'Tasa hipotecaria';

  @override
  String get locationHorizon => 'Horizonte';

  @override
  String get locationValeursProfil => 'Valores pre-rellenados desde tu perfil';

  @override
  String get locationAvertissement => 'Aviso';

  @override
  String reportBonjour(String name) {
    return 'Olá $name!';
  }

  @override
  String reportProfileSummary(int age, String canton, String civilStatus) {
    return '$age anos • $canton • $civilStatus';
  }

  @override
  String get reportStatusGood => 'A tua base é sólida, continua assim!';

  @override
  String get reportStatusMedium => 'Alguns ajustes para ficares tranquilo';

  @override
  String get reportStatusLow => 'Prioridade: estabiliza a tua situação';

  @override
  String get reportReasonDebt => 'Dívida ao consumo ativa.';

  @override
  String get reportReasonLeasing => 'Leasing ativo com encargo mensal.';

  @override
  String reportReasonPayments(String amount) {
    return 'Reembolsos de dívida: CHF $amount / mês.';
  }

  @override
  String get reportReasonEmergency =>
      'Fundo de emergência insuficiente (< 3 meses).';

  @override
  String get reportReasonFragility =>
      'Sinal de fragilidade detetado: prioridade à estabilidade orçamental.';

  @override
  String get reportBudgetTitle => 'O teu Orçamento';

  @override
  String get reportBudgetKeyLabel => 'Disponível (após custos fixos)';

  @override
  String get reportBudgetAction => 'Configurar os meus envelopes';

  @override
  String get reportProtectionTitle => 'A tua Proteção';

  @override
  String get reportProtectionKeyLabel =>
      'Fundo de emergência (objetivo: 6 meses)';

  @override
  String get reportProtectionSource => 'Fonte: LP art. 93 — Mínimo vital';

  @override
  String get reportProtectionAction => 'Constituir o meu fundo de emergência';

  @override
  String get reportRetirementTitle => 'A tua Reforma';

  @override
  String get reportRetirementKeyLabel => 'Rendimento estimado aos 65 anos';

  @override
  String get reportRetirementSource => 'Fontes: LPP art. 14, OPP3, LAVS';

  @override
  String get reportRetirement3aNone =>
      'Ainda sem 3a — até CHF 7’258/ano de dedução fiscal possível';

  @override
  String get reportRetirement3aOne =>
      '1 conta 3a — abre uma 2.ª para otimizar o levantamento';

  @override
  String reportRetirement3aMulti(int count) {
    return '$count contas 3a — boa diversificação';
  }

  @override
  String reportRetirementLppText(String available, String savings) {
    return 'Resgate LPP disponível: CHF $available — poupança fiscal estimada: CHF $savings';
  }

  @override
  String get reportTaxTitle => 'Os teus Impostos';

  @override
  String reportTaxKeyLabel(String rate) {
    return 'Impostos estimados (taxa efetiva: $rate%)';
  }

  @override
  String get reportTaxAction => 'Comparar 26 cantões';

  @override
  String get reportTaxSource => 'Fonte: LIFD art. 33';

  @override
  String get reportTaxIncome => 'Rendimento tributável';

  @override
  String get reportTaxDeductions => 'Deduções';

  @override
  String get reportTaxEstimated => 'Impostos estimados';

  @override
  String reportTaxSavings(String amount) {
    return 'Poupança possível com resgate LPP: CHF $amount/ano';
  }

  @override
  String get reportSafeModePriority => 'Prioridade ao desendividamento';

  @override
  String get reportSafeModeActions =>
      'As tuas ações prioritárias são substituídas por um plano de desendividamento. Estabiliza a tua situação antes de explorar as recomendações.';

  @override
  String get reportSafeMode3a =>
      'O comparador 3a está desativado enquanto tiveres dívidas ativas. Pagar as dívidas é prioritário antes de qualquer poupança 3a.';

  @override
  String get reportSafeModeLpp => 'Resgate LPP bloqueado';

  @override
  String get reportSafeModeLppMessage =>
      'O resgate LPP está desativado em modo de proteção. Paga as tuas dívidas antes de bloquear liquidez na previdência.';

  @override
  String get reportLppTitle => '💰 Estratégia de Resgate LPP';

  @override
  String reportLppEconomie(String amount) {
    return 'Poupança fiscal total: CHF $amount';
  }

  @override
  String reportLppYear(int year) {
    return 'Ano $year';
  }

  @override
  String reportLppBuyback(String amount) {
    return 'Resgate: CHF $amount';
  }

  @override
  String reportLppSaving(String amount) {
    return 'Poupança: CHF $amount';
  }

  @override
  String get reportLppHowTitle => 'Como funciona?';

  @override
  String get reportLppHowBody =>
      'Percebe porque escalonar os teus resgates LPP te faz poupar milhares de francos adicionais.';

  @override
  String get reportSoaTitle => 'Transparência e conformidade';

  @override
  String get reportSoaNature => 'Natureza do serviço';

  @override
  String reportSoaEduPhases(int count) {
    return 'Educação financeira — $count fases identificadas';
  }

  @override
  String get reportSoaEduSimple => 'Educação financeira personalizada';

  @override
  String get reportSoaHypotheses => 'Hipóteses de trabalho';

  @override
  String get reportSoaHyp1 => 'Rendimentos declarados estáveis no período';

  @override
  String get reportSoaHyp2 => 'Taxa de conversão LPP obrigatória: 6,8 %';

  @override
  String get reportSoaHyp3 => 'Limite 3a assalariado: CHF 7’258/ano';

  @override
  String get reportSoaHyp4 => 'Pensão AVS máxima: CHF 30’240/ano';

  @override
  String get reportSoaConflicts => 'Conflitos de interesse';

  @override
  String get reportSoaNoConflict =>
      'Nenhum conflito de interesse identificado para este relatório.';

  @override
  String get reportSoaNoCommission =>
      'A MINT não recebe nenhuma comissão sobre os produtos mencionados.';

  @override
  String get reportSoaLimitations => 'Limitações';

  @override
  String get reportSoaLim1 => 'Baseado apenas em informações declarativas';

  @override
  String get reportSoaLim2 =>
      'Estimativa fiscal aproximada (taxas médias cantonais)';

  @override
  String get reportSoaLim3 =>
      'Não tem em conta os rendimentos de património mobiliário';

  @override
  String get reportSoaLim4 => 'As projeções não têm em conta a inflação';

  @override
  String get checkinEvolution => 'A tua evolução';

  @override
  String get portfolioReadinessTitle => 'Índice de Preparação (Marcos)';

  @override
  String get portfolioPerennite => 'Sustentabilidade Reforma';

  @override
  String get portfolioProjetImmo => 'Projeto Imobiliário';

  @override
  String get portfolioProtectionFamille => 'Proteção Familiar';

  @override
  String get portfolioAllocationSaine =>
      'A tua alocação é saudável. Pensa em reequilibrar o teu 3a em breve.';

  @override
  String get portfolioAlerteDettes =>
      'Alerta Dívidas: A tua prioridade é o pagamento de dívidas antes de qualquer reinvestimento.';

  @override
  String get dividendeSplitMin => '0% salário';

  @override
  String get dividendeSplitMax => '100% salário';

  @override
  String get disabilityInsAppBarTitle => 'A minha cobertura';

  @override
  String get disabilityInsTitle => 'A minha cobertura por invalidez';

  @override
  String get disabilityInsSubtitle =>
      'Relatório de cobertura · Franquia LAMal · AI/APG';

  @override
  String get disabilityInsRefineSituation => 'Afina a tua situação';

  @override
  String get disabilityInsGrossSalary => 'Salário bruto mensal';

  @override
  String get disabilityInsSavings => 'Poupança disponível';

  @override
  String get disabilityInsIjmEmployer => 'Subsídio de doença via empregador';

  @override
  String get disabilityInsPrivateLossInsurance =>
      'Seguro privado de perda de rendimento';

  @override
  String get disabilityInsDisclaimer =>
      'Ferramenta educativa — não constitui aconselhamento em seguros. Os montantes de franquia e prémios são indicativos. Compara as ofertas em comparaison.ch ou através de um·a corretor·a independente.';

  @override
  String get disabilityInsSources =>
      '• LAMal art. 64-64a (franquia)\n• OAMal art. 93 (prémios)\n• LAI art. 28 (pensão de invalidez)\n• LPP art. 23-26 (invalidez 2.º pilar)';

  @override
  String repaymentDiffStrategies(String amount) {
    return 'Diferença entre as duas estratégias: CHF $amount';
  }

  @override
  String get repaymentAddDebtHint =>
      'Adiciona as tuas dívidas para gerar um plano de reembolso.';

  @override
  String get repaymentAddDebtTooltip => 'Adicionar uma dívida';

  @override
  String get repaymentDebtNameHint => 'Nome da dívida';

  @override
  String get repaymentFieldAmount => 'Montante';

  @override
  String get repaymentFieldAmountLabel => 'Montante da dívida';

  @override
  String get repaymentFieldRate => 'Taxa';

  @override
  String get repaymentFieldRateLabel => 'Taxa anual';

  @override
  String get repaymentFieldInstallment => 'Prestação mensal';

  @override
  String get repaymentFieldInstallmentLabel => 'Prestação mínima mensal';

  @override
  String get repaymentNewDebt => 'Nova dívida';

  @override
  String get repaymentBudgetEditorLabel => 'Orçamento mensal de reembolso';

  @override
  String repaymentBudgetDisplay(String amount) {
    return 'CHF $amount / mês';
  }

  @override
  String get repaymentAvalancheTitle => 'AVALANCHE';

  @override
  String get repaymentAvalancheSubtitle => 'Taxa mais alta primeiro';

  @override
  String get repaymentAvalanchePro => 'Menos juros pagos';

  @override
  String get repaymentSnowballTitle => 'BOLA DE NEVE';

  @override
  String get repaymentSnowballSubtitle => 'Saldo mais pequeno primeiro';

  @override
  String get repaymentSnowballPro => 'Motivação por pequenas vitórias';

  @override
  String get repaymentRowLiberation => 'Data de libertação';

  @override
  String get repaymentRowInterets => 'Juros totais';

  @override
  String repaymentDifference(String amount) {
    return 'Diferença: CHF $amount';
  }

  @override
  String get repaymentValidate => 'Confirmar';

  @override
  String get repaymentEmptyState =>
      'Adiciona as tuas dívidas e define o teu orçamento mensal de reembolso para ver o plano.';

  @override
  String repaymentMinMax(String minVal, String maxVal) {
    return 'Mín $minVal · Máx $maxVal';
  }

  @override
  String repaymentInteretsDisplay(String amount) {
    return 'CHF $amount juros';
  }

  @override
  String repaymentDurationDisplay(int months) {
    return '$months meses';
  }

  @override
  String get debtRatioLevelSain => 'SAUDÁVEL';

  @override
  String get debtRatioLevelAttention => 'ATENÇÃO';

  @override
  String get debtRatioLevelCritique => 'CRÍTICO';

  @override
  String get debtRatioRevenuNet => 'Rendimento líquido';

  @override
  String get debtRatioChargesDette => 'Encargos com dívida';

  @override
  String get debtRatioLoyer => 'Renda';

  @override
  String get debtRatioAutresCharges => 'Outras despesas';

  @override
  String get debtRatioRefineSuffix => 'Renda, situação, filhos';

  @override
  String get debtRatioSituation => 'Situação';

  @override
  String get debtRatioSeul => 'Sozinho/a';

  @override
  String get debtRatioEnCouple => 'Em casal';

  @override
  String get debtRatioEnfants => 'Filhos';

  @override
  String get debtRatioMinimumVitalLabel => 'Mínimo vital';

  @override
  String get debtRatioMargeDisponible => 'Margem disponível';

  @override
  String get debtRatioMinVitalWarning =>
      'A tua margem residual está abaixo do mínimo vital. Contacta um serviço de apoio profissional.';

  @override
  String get debtRatioCtaSemantics => 'Criar um plano de reembolso';

  @override
  String get debtRatioCtaDescription =>
      'Compara avalanche e bola de neve para reembolsar mais rapidamente.';

  @override
  String get debtRatioDetteConseilNom => 'Dettes Conseils Suisse';

  @override
  String get debtRatioDetteConseilDesc =>
      'Aconselhamento gratuito e confidencial';

  @override
  String get debtRatioCaritasNom => 'Caritas — Apoio às dívidas';

  @override
  String get debtRatioCaritasDesc =>
      'Assistência no saneamento de dívidas e negociação';

  @override
  String get debtRatioValidate => 'Confirmar';

  @override
  String debtRatioMinMaxDisplay(String minVal, String maxVal) {
    return 'Mín $minVal · Máx $maxVal';
  }

  @override
  String get timelineCatFamille => 'FAMÍLIA';

  @override
  String get timelineCatProfessionnel => 'PROFISSIONAL';

  @override
  String get timelineCatPatrimoine => 'PATRIMÓNIO';

  @override
  String get timelineCatSante => 'SAÚDE';

  @override
  String get timelineCatMobilite => 'MOBILIDADE';

  @override
  String get timelineCatCrise => 'CRISE';

  @override
  String get timelineSectionTitleUpper => 'EVENTOS DE VIDA';

  @override
  String get timelineEventMariageTitle => 'Casamento';

  @override
  String get timelineEventMariageSub =>
      'Impacto no LPP, AVS, impostos e regime matrimonial';

  @override
  String get timelineEventConcubinageTitle => 'Coabitação';

  @override
  String get timelineEventConcubitageSub =>
      'Previdência, sucessão e fiscalidade do casal não casado';

  @override
  String get timelineEventNaissanceTitle => 'Nascimento';

  @override
  String get timelineEventNaissanceSub =>
      'Subsídios, deduções fiscais e seguros';

  @override
  String get timelineEventDivorceTitle => 'Divórcio';

  @override
  String get timelineEventDivorceSub =>
      'Divisão LPP, pensão e reorganização financeira';

  @override
  String get timelineEventSuccessionTitle => 'Sucessão';

  @override
  String get timelineEventSuccessionSub =>
      'Reservas hereditárias, partilha e impostos (CC art. 457ss)';

  @override
  String get timelineEventPremierEmploiTitle => 'Primeiro emprego';

  @override
  String get timelineEventPremierEmploiSub =>
      'Primeiros passos : AVS, LPP, 3a e orçamento';

  @override
  String get timelineEventChangementEmploiTitle => 'Mudança de emprego';

  @override
  String get timelineEventChangementEmploiSub =>
      'Comparação LPP, livre passagem e negociação';

  @override
  String get timelineEventIndependantTitle => 'Independente';

  @override
  String get timelineEventIndependantSub =>
      'AVS, LPP voluntário, 3a alargado e dividendo vs salário';

  @override
  String get timelineEventPerteEmploiTitle => 'Perda de emprego';

  @override
  String get timelineEventPerteEmploiSub =>
      'Desemprego, período de espera e proteção previdencial';

  @override
  String get timelineEventRetraiteTitle => 'Reforma';

  @override
  String get timelineEventRetraiteSub =>
      'Renda vs capital, escalonamento 3a, lacuna AVS';

  @override
  String get timelineEventAchatImmoTitle => 'Compra imobiliária';

  @override
  String get timelineEventAchatImmoSub =>
      'Capacidade de empréstimo, EPL e imposto sobre valor locativo';

  @override
  String get timelineEventVenteImmoTitle => 'Venda imobiliária';

  @override
  String get timelineEventVenteImmoSub =>
      'Mais-valia, imposto cantonal e reinvestimento';

  @override
  String get timelineEventHeritageTitle => 'Herança';

  @override
  String get timelineEventHeritageSub =>
      'Estimativa, imposto cantonal e partilha sucessória';

  @override
  String get timelineEventDonationTitle => 'Doação';

  @override
  String get timelineEventDonationSub =>
      'Imposto cantonal, reservas e quota disponível';

  @override
  String get timelineEventInvaliditeTitle => 'Invalidez';

  @override
  String get timelineEventInvaliditeSub =>
      'Lacuna de cobertura AI + LPP e prevenção';

  @override
  String get timelineEventDemenagementTitle => 'Mudança cantonal';

  @override
  String get timelineEventDemenagementSub =>
      'Impacto fiscal da mudança de cantão (26 tabelas)';

  @override
  String get timelineEventExpatriationTitle => 'Expatriação / Fronteiriço';

  @override
  String get timelineEventExpatriationSub =>
      'Dupla tributação, 3a e cobertura social';

  @override
  String get timelineEventSurendettementTitle => 'Sobreendividamento';

  @override
  String get timelineEventSurendettementSub =>
      'Rácio de endividamento, plano de reembolso e ajuda';

  @override
  String get timelineQuickCheckupTitle => 'Check-up financeiro';

  @override
  String get timelineQuickCheckupSub => 'Iniciar o diagnóstico completo';

  @override
  String get timelineQuickBudgetTitle => 'Orçamento';

  @override
  String get timelineQuickBudgetSub => 'Gerir o fluxo de caixa mensal';

  @override
  String get timelineQuickPilier3aTitle => 'Pilar 3a';

  @override
  String get timelineQuickPilier3aSub => 'Otimizar a dedução fiscal';

  @override
  String get timelineQuickFiscaliteTitle => 'Fiscalidade';

  @override
  String get timelineQuickFiscaliteSub => 'Comparar 26 cantões';

  @override
  String get consentFinmaTitle => 'Fonctionnalité en préparation';

  @override
  String get consentFinmaDesc =>
      'Consultation réglementaire FINMA en cours. Les données affichées sont des exemples de démonstration.';

  @override
  String get consentModeDemo => 'MODE DÉMO';

  @override
  String get consentActiveSection => 'CONSENTEMENTS ACTIFS';

  @override
  String get consentAutorisations => 'Autorisations';

  @override
  String consentGrantedAtLabel(String date) {
    return 'Accordé le $date';
  }

  @override
  String consentExpiresAtLabel(String date) {
    return 'Expire le $date';
  }

  @override
  String get consentRevokedLabel => 'Consentement révoqué';

  @override
  String get consentNlpdTitle => 'Tes droits (nLPD)';

  @override
  String get consentNlpdSubtitle =>
      'Tes droits selon la nLPD (Loi fédérale sur la protection des données) :';

  @override
  String get consentNlpdPoint1 =>
      '• Tu peux révoquer ton consentement à tout moment';

  @override
  String get consentNlpdPoint2 =>
      '• Tes données ne sont jamais partagées avec des tiers';

  @override
  String get consentNlpdPoint3 =>
      '• Accès en lecture seule — aucune opération financière';

  @override
  String get consentNlpdPoint4 =>
      '• Durée maximale de consentement : 90 jours (renouvelable)';

  @override
  String get consentStepBanque => 'Banque';

  @override
  String get consentStepAutorisations => 'Autorisations';

  @override
  String get consentStepConfirmation => 'Confirmation';

  @override
  String get consentSelectBankTitle => 'Choisir une banque';

  @override
  String get consentSelectScopesTitle => 'Choisir les autorisations';

  @override
  String consentSelectedBankLabel(String bank) {
    return 'Banque sélectionnée : $bank';
  }

  @override
  String get consentScopeAccountsDesc => 'Comptes (liste de tes comptes)';

  @override
  String get consentScopeBalancesDesc => 'Soldes (solde actuel de tes comptes)';

  @override
  String get consentScopeTransactionsDesc =>
      'Transactions (historique des mouvements)';

  @override
  String get consentReadOnlyInfo =>
      'Accès en lecture seule. Aucune opération financière ne peut être effectuée.';

  @override
  String get consentConfirmTitle => 'Confirmation';

  @override
  String get consentConfirmBanque => 'Banque';

  @override
  String get consentConfirmAutorisations => 'Autorisations';

  @override
  String get consentConfirmDuree => 'Durée';

  @override
  String get consentConfirmDureeValue => '90 jours';

  @override
  String get consentConfirmAcces => 'Accès';

  @override
  String get consentConfirmAccesValue => 'Lecture seule';

  @override
  String get consentConfirmDisclaimer =>
      'En confirmant, tu autorises MINT à accéder aux données sélectionnées en lecture seule pour une durée de 90 jours. Tu peux révoquer ce consentement à tout moment.';

  @override
  String get consentAnnuler => 'Annuler';

  @override
  String get consentScopeComptes => 'Comptes';

  @override
  String get consentScopeSoldes => 'Soldes';

  @override
  String get consentScopeTransactions => 'Transactions';

  @override
  String get consentStatusActif => 'Actif';

  @override
  String get consentStatusExpirantBientot => 'Expire bientôt';

  @override
  String get consentStatusExpire => 'Expiré';

  @override
  String get consentStatusRevoque => 'Révoqué';

  @override
  String get consentStatusInconnu => 'Inconnu';

  @override
  String get consentDisclaimer =>
      'Cette fonctionnalité est en cours de développement. Les données affichées sont des exemples. L\'activation du service Open Banking est soumise à une consultation réglementaire préalable.';

  @override
  String get openBankingHubFinmaTitle => 'Fonctionnalité en préparation';

  @override
  String get openBankingHubFinmaDesc =>
      'Consultation réglementaire FINMA en cours. Les données affichées sont des exemples de démonstration.';

  @override
  String get openBankingHubSubtitle => 'Connecte tes comptes bancaires';

  @override
  String get openBankingHubConnectedAccounts => 'COMPTES CONNECTES';

  @override
  String get openBankingHubApercu => 'APERCU FINANCIER';

  @override
  String get openBankingHubNavigation => 'NAVIGATION';

  @override
  String get openBankingHubViewTransactions => 'Voir les transactions';

  @override
  String get openBankingHubViewTransactionsDesc =>
      'Historique détaillé par catégorie';

  @override
  String get openBankingHubManageConsents => 'Gérer les consentements';

  @override
  String get openBankingHubManageConsentsDesc =>
      'Droits nLPD, révocation, scopes';

  @override
  String get openBankingHubSoldeTotal => 'Solde total';

  @override
  String get openBankingHubComptesConnectes => '3 comptes connectés';

  @override
  String get openBankingHubRevenus => 'Revenus';

  @override
  String get openBankingHubDepenses => 'Dépenses';

  @override
  String get openBankingHubEpargneNette => 'Épargne nette';

  @override
  String get openBankingHubTop3Depenses => 'Top 3 dépenses';

  @override
  String get openBankingHubAddBankLabel => 'Ajouter une banque';

  @override
  String openBankingHubSyncMinutes(int minutes) {
    return 'Il y a $minutes min';
  }

  @override
  String openBankingHubSyncHours(int hours) {
    return 'Il y a ${hours}h';
  }

  @override
  String openBankingHubSyncDays(int days) {
    return 'Il y a ${days}j';
  }

  @override
  String get transactionListFinmaTitle => 'Fonctionnalité en préparation';

  @override
  String get transactionListFinmaDesc =>
      'Consultation réglementaire FINMA en cours. Les données affichées sont des exemples de démonstration.';

  @override
  String get transactionListThisMonth => 'Ce mois';

  @override
  String get transactionListLastMonth => 'Mois précédent';

  @override
  String get transactionListNoTransaction => 'Aucune transaction';

  @override
  String get transactionListRevenus => 'Revenus';

  @override
  String get transactionListDepenses => 'Dépenses';

  @override
  String get transactionListEpargneNette => 'Épargne nette';

  @override
  String get transactionListTauxEpargne => 'Taux d’épargne';

  @override
  String get transactionListModeDemo => 'MODE DÉMO';

  @override
  String get lppVolontaireRevenuMax250k => 'CHF 250’000';

  @override
  String get lppVolontaireSalaireCoordLabel => 'Salaire coordonné';

  @override
  String get lppVolontaireTauxBonifLabel => 'Taux bonification';

  @override
  String get lppVolontaireCotisationLabel => 'Cotisation /an';

  @override
  String get lppVolontaireEconomieFiscaleLabel => 'Économie fiscale /an';

  @override
  String get lppVolontaireTrancheAgeLabel => 'Tranche d’âge';

  @override
  String get lppVolontaireCHF0 => 'CHF 0';

  @override
  String get lppVolontaireTaux10 => '10 %';

  @override
  String get lppVolontaireTaux45 => '45 %';

  @override
  String get pillar3aIndepPlafondApplicableLabel => 'Plafond applicable';

  @override
  String get pillar3aIndepEconomieFiscaleAnLabel => 'Économie fiscale /an';

  @override
  String get pillar3aIndepPlafondSalarieLabel => 'Plafond salarié·e';

  @override
  String get pillar3aIndepEconomieSalarieLabel => 'Économie salarié·e';

  @override
  String get pillar3aIndepCHF0 => 'CHF 0';

  @override
  String get pillar3aIndepTaux10 => '10 %';

  @override
  String get pillar3aIndepTaux45 => '45 %';

  @override
  String get actionSuccessNext => 'Próximo passo';

  @override
  String get actionSuccessDone => 'Entendido';

  @override
  String get dividendeBeneficeTotal => 'Lucro total';

  @override
  String get dividendePartSalaire => 'Parcela salarial';

  @override
  String get dividendeTauxMarginal => 'Taxa marginal de imposto';

  @override
  String get successionUrgence => 'Urgência imediata';

  @override
  String get successionDemarches => 'Trâmites administrativos';

  @override
  String get successionLegale => 'Sucessão legal';

  @override
  String get disabilityGapEmployerSub =>
      'CO art. 324a — 3 a 26 semanas conforme antiguidade';

  @override
  String get disabilityGapAiDelaySub =>
      'Prazo médio decisão AI: 14 meses · LAI art. 28 + LPP art. 23';

  @override
  String get indepCaisseLpp => 'Caixa LPP facultativa';

  @override
  String get indepCaisseLppSub => 'Cobertura pensão invalidez + reforma';

  @override
  String get indepGrand3a => 'Grande 3a (sem LPP)';

  @override
  String get indepAdminUrgent => 'Administrativo urgente';

  @override
  String get indepPrevoyance => 'Previdência';

  @override
  String get indepOptiFiscale => 'Otimização fiscal';

  @override
  String get fhsLevelExcellent => 'Excelente';

  @override
  String get fhsLevelBon => 'Bom';

  @override
  String get fhsLevelAmeliorer => 'A melhorar';

  @override
  String get fhsLevelCritique => 'Crítico';

  @override
  String fhsDeltaLabel(String delta) {
    return 'Tendência: $delta vs ontem';
  }

  @override
  String fhsDeltaText(String delta) {
    return '$delta vs ontem';
  }

  @override
  String get fhsBreakdownLiquidite => 'Liquidez';

  @override
  String get fhsBreakdownFiscalite => 'Fiscalidade';

  @override
  String get fhsBreakdownRetraite => 'Reforma';

  @override
  String get fhsBreakdownRisque => 'Risco';

  @override
  String avsGapLifetimeLoss(String amount) {
    return 'Em 20 anos de reforma, são $amount a menos — definitivamente.';
  }

  @override
  String get avsGapCalculation =>
      'Cálculo: pensão mensal × 13 meses/ano (13.ª pensão AVS desde dez. 2026)';

  @override
  String get chiffreChocRenteCalculation =>
      '(cálculo: pensão mensal × 13 meses/ano, 13.ª pensão incluída).';

  @override
  String get coachBriefingFallbackGreeting => 'Olá';

  @override
  String get coachBriefingBadgeLlm => 'Coach IA';

  @override
  String get coachBriefingBadge => 'Coach';

  @override
  String coachBriefingConfidenceLow(String score) {
    return 'Confiança $score % — Enriquecer';
  }

  @override
  String coachBriefingConfidence(String score) {
    return 'Confiança $score %';
  }

  @override
  String coachBriefingImpactEstimated(String amount) {
    return 'Impacto estimado : CHF $amount';
  }

  @override
  String get chiffreChocSectionDisclaimer =>
      'Simulação educativa. Não constitui aconselhamento financeiro (LSFin). Hipóteses modificáveis — resultados não garantidos.';

  @override
  String get concubinageTabProtection => 'Proteção';

  @override
  String concubinageHeroChiffreChoc(String montant) {
    return 'CHF $montant de património exposto';
  }

  @override
  String get concubinageHeroChiffreChocDesc =>
      'Em concubinato, o teu parceiro não é herdeiro legal. Sem testamento, este montante perde-se por completo.';

  @override
  String get concubinageEducationalAvs =>
      'Na Suíça, o teto de 150 % nas pensões AVS de casal (LAVS art. 35) só se aplica aos casados. Os concubinos recebem cada um a sua pensão individual completa — uma vantagem real quando ambos contribuíram ao máximo.';

  @override
  String get concubinageEducationalLpp =>
      'A pensão LPP de sobrevivente (60 % da pensão do falecido, LPP art. 19) é reservada aos cônjuges. Em concubinato, apenas o regulamento da caixa pode prever um capital por falecimento — e é preciso solicitá-lo.';

  @override
  String get concubinageEducationalSuccession =>
      'Um cônjuge casado está isento do imposto de sucessão na maioria dos cantões (CC art. 462). Um concubino paga imposto à taxa de terceiros, frequentemente entre 20 % e 40 %.';

  @override
  String get concubinageProtectionIntro =>
      'Em concubinato, a Suíça não protege como o casamento. Aqui está o que muda e o que podes antecipar.';

  @override
  String get concubinageProtectionAvsSurvivor => 'Pensão AVS de sobrevivente';

  @override
  String get concubinageProtectionAvsSurvivorMarried =>
      '80 % da pensão do falecido (LAVS art. 23)';

  @override
  String get concubinageProtectionAvsSurvivorConcubin =>
      'Nenhuma pensão — CHF 0/mês';

  @override
  String get concubinageProtectionLppSurvivor => 'Pensão LPP de sobrevivente';

  @override
  String get concubinageProtectionLppSurvivorMarried =>
      '60 % da pensão do falecido (LPP art. 19)';

  @override
  String get concubinageProtectionLppSurvivorConcubin =>
      'Apenas conforme regulamento da caixa';

  @override
  String get concubinageProtectionHeritage => 'Herança legal';

  @override
  String get concubinageProtectionHeritageMarried => 'Isento (CC art. 462)';

  @override
  String get concubinageProtectionHeritageConcubin =>
      'Imposto cantonal (20-40 %)';

  @override
  String get concubinageProtectionPension => 'Pensão alimentícia';

  @override
  String get concubinageProtectionPensionMarried => 'Protegida pelo juiz';

  @override
  String get concubinageProtectionPensionConcubin => 'Sem obrigação legal';

  @override
  String get concubinageProtectionAvsPlafond => 'Teto AVS casal';

  @override
  String get concubinageProtectionAvsPlafondMarried =>
      'Máx. 150 % (LAVS art. 35)';

  @override
  String get concubinageProtectionAvsPlafondConcubin => 'Sem teto — 2×100 %';

  @override
  String get concubinageProtectionMaried => 'Casado';

  @override
  String get concubinageProtectionConcubinLabel => 'Concubino';

  @override
  String get concubinageProtectionWarning =>
      'Em concubinato, se o teu parceiro falecer, não recebes pensão AVS, nem pensão LPP automática, e não és herdeiro legal. Cada proteção deve ser antecipada.';

  @override
  String get concubinageProtectionLppSlider => 'Pensão LPP mensal do parceiro';

  @override
  String concubinageProtectionSurvivorTotal(String montant) {
    return '$montant/mês para o cônjuge sobrevivente casado';
  }

  @override
  String get concubinageProtectionSurvivorZero =>
      'CHF 0/mês para o concubino sobrevivente sem diligências';

  @override
  String get concubinageDecisionMatrixTitle => 'Casamento vs Concubinato';

  @override
  String get concubinageDecisionMatrixSubtitle =>
      'Comparação dos direitos e obrigações';

  @override
  String get concubinageDecisionMatrixColumnMarriage => 'Casamento';

  @override
  String get concubinageDecisionMatrixColumnConcubinage => 'Concubinato';

  @override
  String get concubinageDecisionMatrixConclusionTitle => 'Conclusão neutra';

  @override
  String get concubinageDecisionMatrixConclusionDesc =>
      'A escolha depende da tua situação pessoal. Consulta um notário para uma análise completa.';

  @override
  String get landingHiddenAmount => 'CHF ····';

  @override
  String get landingHiddenSubtitle => 'O teu primeiro número em 30 segundos';

  @override
  String get renteVsCapitalV2Title => 'Renda ou capital.';

  @override
  String get renteVsCapitalV2Subtitle =>
      'O mesmo dinheiro. Duas vidas diferentes.';

  @override
  String get renteVsCapitalChoiceRenteSubtitle =>
      'Mais estável, menos flexível';

  @override
  String get renteVsCapitalChoiceCapitalSubtitle => 'Mais livre, mais exigente';

  @override
  String get renteVsCapitalChoiceMixteSubtitle => 'Um equilíbrio a construir';

  @override
  String get renteVsCapitalConsequenceRenteEyebrow => 'Se escolheres a renda';

  @override
  String get renteVsCapitalConsequenceCapitalEyebrow =>
      'Se escolheres o capital';

  @override
  String get renteVsCapitalConsequenceMixteEyebrow =>
      'Se escolheres a opção mista';

  @override
  String get renteVsCapitalConsequenceRenteNarrative =>
      'Um rendimento fixo todos os meses, sem te preocupares com os mercados. Em troca, o teu capital já não te pertence.';

  @override
  String get renteVsCapitalConsequenceCapitalNarrative =>
      'Geres o teu dinheiro livremente, mas pode esgotar-se. Cada ano conta.';

  @override
  String get renteVsCapitalConsequenceMixteNarrative =>
      'A parte obrigatória como renda para a segurança, a suplementar como capital para a flexibilidade.';

  @override
  String get renteVsCapitalConsequenceMixteRenteLabel => 'Renda (obrigatória)';

  @override
  String get renteVsCapitalConsequenceMixteCapitalLabel =>
      'Capital (suplementar)';

  @override
  String get renteVsCapitalSignalRevenu => 'Rendimento mensal';

  @override
  String get renteVsCapitalSignalFiscalite => 'Fiscalidade acumulada';

  @override
  String get renteVsCapitalSignalTransmission => 'Transmissão';

  @override
  String get renteVsCapitalConfidenceNoticeLow =>
      'Sem certificado LPP, isto continua a ser uma estimativa aproximada.';

  @override
  String get renteVsCapitalConfidenceNoticeHigh =>
      'Dados completos — resultados fiáveis.';

  @override
  String get renteVsCapitalConfidenceCta => 'Precisar os meus dados';

  @override
  String get renteVsCapitalFastEstimateTitle => 'Fazer uma primeira estimativa';

  @override
  String get renteVsCapitalCtaCompare => 'Comparar para mim';

  @override
  String get renteVsCapitalAdvancedDisclosure => 'Tenho o meu certificado LPP';

  @override
  String get renteVsCapitalPerMonthForLife => '/mês, vitalício';

  @override
  String get renteVsCapitalNetAfterTax => 'líquido de impostos';

  @override
  String get renteVsCapitalTransmissionRenteMarried => '60 % ao cônjuge';

  @override
  String get renteVsCapitalTransmissionRenteSingle => 'Nada aos herdeiros';

  @override
  String get renteVsCapitalTransmissionCapitalValue => '100 % aos herdeiros';

  @override
  String get quickStartAgeTitle => 'Quantos anos tens?';

  @override
  String get quickStartAgeSubtitle => 'Começamos por aqui.';

  @override
  String get quickStartRevenueTitle => 'O teu rendimento bruto anual?';

  @override
  String get quickStartRevenueSubtitle => 'Mesmo aproximado, basta.';

  @override
  String get quickStartCantonTitle => 'Onde vives?';

  @override
  String get quickStartCantonSubtitle => 'O teu cantão muda muita coisa.';

  @override
  String get quickStartNext => 'Seguinte';

  @override
  String get quickStartResultConfidence =>
      'Estimativa baseada em 3 dados. O coach vai precisar.';

  @override
  String get quickStartCtaCoach => 'Falar com o coach';

  @override
  String get quickStartCtaExplore => 'Explorar primeiro';

  @override
  String get lightningMenuTitle => 'O que queres explorar?';

  @override
  String get lightningMenuSubtitle => 'MINT calcula, tu decides.';

  @override
  String get lightningMenuRetirementTitle => 'A minha visão da reforma';

  @override
  String get lightningMenuRetirementSubtitle => 'Quanto vais manter na reforma';

  @override
  String get lightningMenuRetirementAction => 'Quanto na reforma?';

  @override
  String get lightningMenuBudgetTitle => 'O meu orçamento';

  @override
  String get lightningMenuBudgetSubtitle =>
      'Para onde vai o teu dinheiro este mês';

  @override
  String get lightningMenuBudgetAction => 'O meu orçamento este mês';

  @override
  String get lightningMenuRenteCapitalTitle => 'Renda ou capital?';

  @override
  String get lightningMenuRenteCapitalSubtitle => 'Comparar ambos os cenários';

  @override
  String get lightningMenuRenteCapitalAction => 'Renda ou capital?';

  @override
  String get lightningMenuScoreTitle => 'A minha pontuação fitness';

  @override
  String get lightningMenuScoreSubtitle => 'A tua saúde financeira de relance';

  @override
  String get lightningMenuScoreAction => 'A minha pontuação financeira';

  @override
  String get lightningMenuCoupleTitle => 'A nossa situação a dois';

  @override
  String get lightningMenuCoupleSubtitle => 'Previdência e património em casal';

  @override
  String get lightningMenuCoupleAction => 'A nossa previdência em casal';

  @override
  String get lightningMenuDebtTitle => 'Sair da dívida';

  @override
  String get lightningMenuDebtSubtitle =>
      'Um plano para reduzir os teus encargos';

  @override
  String get lightningMenuDebtAction => 'Como reduzir a minha dívida?';

  @override
  String get lightningMenuIndependantTitle => 'A minha rede de segurança';

  @override
  String get lightningMenuIndependantSubtitle =>
      'Cobertura e proteção como independente';

  @override
  String get lightningMenuIndependantAction =>
      'A minha cobertura como independente';

  @override
  String get lightningMenuRetirementPrepTitle => 'Preparar a minha reforma';

  @override
  String get lightningMenuRetirementPrepSubtitle =>
      'Os últimos anos contam a dobrar';

  @override
  String get lightningMenuRetirementPrepAction => 'O meu plano de reforma';

  @override
  String get trajectoryGoalSectionTitle => 'O teu objetivo';

  @override
  String get trajectoryGoalRetraite => 'Reforma aos 65 anos';

  @override
  String get trajectoryGoalAchatImmo => 'Compra imobiliária';

  @override
  String get trajectoryGoalIndependance => 'Independência financeira';

  @override
  String get trajectoryGoalDebtFree => 'Libertação das dívidas';

  @override
  String trajectoryGoalHorizon(int years) {
    return 'Horizonte: $years anos';
  }

  @override
  String trajectoryGoalTarget(String amount) {
    return 'Alvo: $amount';
  }

  @override
  String get trajectoryKnownSectionTitle => 'O que MINT sabe';

  @override
  String get trajectoryFieldAge => 'Idade';

  @override
  String get trajectoryFieldAgeUnit => 'anos';

  @override
  String get trajectoryFieldRevenu => 'Rendimento bruto';

  @override
  String get trajectoryFieldCanton => 'Cantão';

  @override
  String get trajectoryFieldLpp => 'Saldo LPP';

  @override
  String get trajectoryField3a => 'Poupança 3a';

  @override
  String get trajectoryFieldConjoint => 'Cônjuge';

  @override
  String get trajectoryFieldIncomplete => 'A completar';

  @override
  String get trajectoryFieldConjointYes => 'Sim';

  @override
  String get trajectoryFieldConjointNo => 'Não especificado';

  @override
  String get trajectoryDecisionsSectionTitle => 'As tuas decisões';

  @override
  String get trajectoryNextStepSectionTitle => 'Próximo passo';

  @override
  String get trajectoryNextStepBody => 'O coach acompanha-te nesta ação.';

  @override
  String get trajectoryConfidenceSectionTitle => 'Confiança';

  @override
  String get trajectoryConfidenceLowMessage =>
      'Os teus dados ainda são parciais — cada informação adicional refina a tua trajetória.';

  @override
  String get trajectoryConfidenceHighMessage =>
      'Perfil bem documentado — as tuas projeções são fiáveis.';

  @override
  String get trajectoryConfidenceCta => 'Melhorar a precisão';

  @override
  String get settingsSheetTitle => 'Definições';

  @override
  String get settingsConsentsTitle => 'Consentimentos';

  @override
  String get settingsConsentsSubtitle => 'Privacidade e partilha de dados';

  @override
  String get settingsSlmTitle => 'IA no dispositivo';

  @override
  String get settingsSlmSubtitle =>
      'Funciona no teu dispositivo, mesmo offline';

  @override
  String get settingsByokTitle => 'Chave IA pessoal';

  @override
  String get settingsByokSubtitle => 'Conecta o teu próprio modelo IA';

  @override
  String get settingsLangueTitle => 'Idioma';

  @override
  String get settingsLangueSubtitle => 'Escolher o idioma da app';

  @override
  String get settingsAboutTitle => 'Sobre';

  @override
  String get settingsAboutSubtitle => 'Versão, avisos legais, contacto';

  @override
  String get pulseLabelMonthlyGap => 'Lacuna mensal a preencher';

  @override
  String get pulseLabelRetirementFree => 'Margem livre na reforma';

  @override
  String get pulseLabelMonthlyFree => 'Margem livre mensal';
}
