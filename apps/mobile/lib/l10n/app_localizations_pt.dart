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
  String get advisorMiniMetricsAhaToStep3 => 'Passo 2 A-ha → Passo 3';

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
      'Ferramenta educativa — não constitui aconselhamento de seguros (LSFin).';

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
  String get askMintSuggestion1 => 'Como funciona o 3.º pilar na Suíça?';

  @override
  String get askMintSuggestion2 => 'Devo escolher a renda ou o capital LPP?';

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
  String get exploreTitle => 'Explorar';

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
  String get coachWelcome => 'Bem-vindo ao MINT';

  @override
  String coachHello(String firstName) {
    return 'Olá $firstName';
  }

  @override
  String get coachFitnessTitle => 'O teu Fitness Financeiro';

  @override
  String get coachFinancialForm => 'Forme financière';

  @override
  String get coachScoreComposite => 'Pontuação composta · 3 pilares';

  @override
  String get coachPillarBudget => 'Budget';

  @override
  String get coachPillarPrevoyance => 'Prévoyance';

  @override
  String get coachPillarPatrimoine => 'Patrimoine';

  @override
  String get coachCompletePrompt =>
      'Completa o teu diagnóstico para descobrir a tua pontuação';

  @override
  String get coachDiscoverScore => 'Descobrir a minha pontuação — 10 min';

  @override
  String get coachTrajectory => 'Ta trajectoire';

  @override
  String get coachTrajectoryPrompt =>
      'A tua trajetória financeira espera por ti';

  @override
  String get coachDidYouKnow => 'Le savais-tu ?';

  @override
  String get coachFact3a =>
      'O 3.º pilar pode poupar-te até CHF 2\'500 de impostos por ano, consoante o teu cantão e o teu rendimento. Um gesto simples com um efeito acumulado enorme.';

  @override
  String get coachFact3aLink => 'Simular a minha poupança 3a';

  @override
  String get coachFactAvs =>
      'Na Suíça, cada ano AVS em falta = −2.3% de renda vitalícia. É possível recuperar anos sob certas condições.';

  @override
  String get coachFactAvsLink => 'Verificar os meus anos AVS';

  @override
  String get coachFactLpp =>
      'O resgate LPP é uma das alavancas fiscais mais potentes para os/as assalariados/as na Suíça. Cada franco resgatado é dedutível do rendimento tributável.';

  @override
  String get coachFactLppLink => 'Explorar o resgate LPP';

  @override
  String get coachMotivation =>
      'Junta-te aos milhares de utilizadores que já fizeram o seu diagnóstico financeiro.';

  @override
  String get coachMotivationSub => 'e receber ações concretas.';

  @override
  String get coachLaunchDiagnostic => 'Iniciar o meu diagnóstico';

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
  String get coachPulseDisclaimer =>
      'Estimativas educativas — não constitui aconselhamento financeiro. Os rendimentos passados não pressupõem rendimentos futuros. Consulta um especialista. LSFin.';

  @override
  String get eduTheme3aTitle => 'Le 3e pilier (3a)';

  @override
  String get eduTheme3aQuestion =>
      'O que é o 3a e porque é que todos falam dele?';

  @override
  String get eduTheme3aAction => 'Estimar a minha poupança fiscal';

  @override
  String get eduTheme3aReminder =>
      'Dezembro → Último momento para contribuir este ano';

  @override
  String get eduThemeLppTitle => 'A caixa de pensões (LPP)';

  @override
  String get eduThemeLppQuestion => 'Tenho uma caixa de pensões?';

  @override
  String get eduThemeLppAction => 'Analisar o meu certificado LPP';

  @override
  String get eduThemeLppReminder => 'Pedir o meu certificado LPP ao empregador';

  @override
  String get eduThemeAvsTitle => 'Les lacunes AVS';

  @override
  String get eduThemeAvsQuestion => 'Tenho anos de contribuição em falta?';

  @override
  String get eduThemeAvsAction => 'Verificar o meu extrato de conta AVS';

  @override
  String get eduThemeAvsReminder => 'Encomendar o meu extrato em ahv-iv.ch';

  @override
  String get eduThemeEmergencyTitle => 'Le fonds d\'urgence';

  @override
  String get eduThemeEmergencyQuestion => 'Quanto deveria ter de reserva?';

  @override
  String get eduThemeEmergencyAction => 'Calcular o meu objetivo';

  @override
  String get eduThemeEmergencyReminder =>
      'Verificar as minhas poupanças de emergência trimestralmente';

  @override
  String get eduThemeDebtTitle => 'Les dettes';

  @override
  String get eduThemeDebtQuestion =>
      'Quanto me custa realmente a minha dívida?';

  @override
  String get eduThemeDebtAction => 'Calcular o custo total';

  @override
  String get eduThemeDebtReminder => 'Prioridade: reembolsar antes de investir';

  @override
  String get eduThemeMortgageTitle => 'L\'hypothèque';

  @override
  String get eduThemeMortgageQuestion => 'Fixo ou SARON, qual é a diferença?';

  @override
  String get eduThemeMortgageAction => 'Comparar as duas estratégias';

  @override
  String get eduThemeMortgageReminder =>
      'Antes da renovação: comparar com 3 meses de antecedência';

  @override
  String get eduThemeBudgetTitle => 'Le reste à vivre';

  @override
  String get eduThemeBudgetQuestion =>
      'Quanto me sobra depois das despesas fixas?';

  @override
  String get eduThemeBudgetAction => 'Estimar o meu rendimento disponível';

  @override
  String get eduThemeBudgetReminder => 'Rever o meu orçamento todos os meses';

  @override
  String get eduThemeLamalTitle => 'Les subsides LAMal';

  @override
  String get eduThemeLamalQuestion =>
      'Tenho direito a ajuda para os meus prémios?';

  @override
  String get eduThemeLamalAction => 'Verificar a minha elegibilidade';

  @override
  String get eduThemeLamalReminder => 'Os critérios mudam consoante o cantão';

  @override
  String get eduThemeFiscalTitle => 'La fiscalité suisse';

  @override
  String get eduThemeFiscalQuestion => 'Como funcionam os impostos na Suíça?';

  @override
  String get eduThemeFiscalAction => 'Simular a minha poupança 3a';

  @override
  String get eduThemeFiscalReminder =>
      'Prazo declaração fiscal: 31 de março (prorrogável)';

  @override
  String get eduHubTitle => 'J\'Y COMPRENDS RIEN';

  @override
  String get eduHubSubtitle =>
      'Sem pânico. Escolhe um tema, explicamos-te o essencial e damos-te uma ação concreta.';

  @override
  String get eduHubReadQuiz => 'Lire + quiz • 2 min';

  @override
  String get askMintSuggestDebt =>
      'Tenho dívidas — por onde começo para sair delas?';

  @override
  String askMintSuggestAge3a(String age) {
    return 'Tenho $age anos, deveria já contribuir para o 3.º pilar?';
  }

  @override
  String askMintSuggestAgeLpp(String age) {
    return 'Tenho $age anos, deveria fazer um resgate LPP?';
  }

  @override
  String askMintSuggestAgeRetirement(String age) {
    return 'Tenho $age anos, como preparo a minha reforma da melhor forma?';
  }

  @override
  String get askMintSuggestSelfEmployed =>
      'Sou independente — como me protejo sem LPP?';

  @override
  String get askMintSuggestUnemployed =>
      'Estou desempregado/a — qual o impacto na minha previdência?';

  @override
  String askMintSuggestCanton(String canton) {
    return 'Que deduções fiscais são possíveis no cantão de $canton?';
  }

  @override
  String get askMintSuggestIncome =>
      'Com o meu rendimento, quanto posso deduzir fiscalmente por ano?';

  @override
  String get askMintSuggestGeneric1 =>
      'Renda ou capital LPP — qual é a diferença?';

  @override
  String get askMintSuggestGeneric2 =>
      'Como otimizar os meus impostos este ano?';

  @override
  String get askMintSuggestGeneric3 => 'O que é o resgate LPP e vale a pena?';

  @override
  String get askMintSuggestGeneric4 => 'Como funciona a franquia LAMal?';

  @override
  String get askMintEmptyBody =>
      'Finanças suíças, decifração de leis, simuladores — explico-te tudo, com fontes legais.';

  @override
  String get askMintPrivacyBadge => 'Os teus dados ficam no teu dispositivo';

  @override
  String get askMintForYou => 'POUR TOI';

  @override
  String get byokRecommended => 'Recommandé';

  @override
  String byokGetKeyOn(String provider) {
    return 'Obter uma chave em $provider';
  }

  @override
  String get byokCopilotActivated => 'O teu copiloto financeiro está ativado';

  @override
  String get byokCopilotBody =>
      'Faz a tua primeira pergunta sobre finanças suíças — 3.º pilar, impostos, LPP, orçamento... Estou aqui.';

  @override
  String get byokTryNow => 'Essayer maintenant';

  @override
  String get trajectoryTitle => 'Ta trajectoire';

  @override
  String trajectorySubtitle(String years) {
    return '3 cenários · $years anos';
  }

  @override
  String get trajectoryOptimiste => 'Optimiste';

  @override
  String get trajectoryBase => 'Base';

  @override
  String get trajectoryPrudent => 'Prudent';

  @override
  String get trajectoryTauxRemplacement => 'Taxa de substituição estimada: ';

  @override
  String get trajectoryEmpty => 'Ainda não há projeção disponível';

  @override
  String get trajectoryEmptySub =>
      'Completa o teu perfil para ver a tua trajetória';

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
  String get agirThisMonth => 'Este mês';

  @override
  String get agirTimeline => 'Timeline';

  @override
  String get agirTimelineSub => 'Os teus próximos prazos';

  @override
  String get agirHistory => 'Historique';

  @override
  String get agirHistorySub => 'Tes check-ins passés';

  @override
  String agirCheckinDone(String month) {
    return 'Check-in $month efetuado';
  }

  @override
  String get agirDone => 'Fait';

  @override
  String agirCheckinCta(String month) {
    return 'Fazer o meu check-in $month';
  }

  @override
  String get agirNoCheckin => 'Ainda sem check-in';

  @override
  String get agirNoCheckinSub =>
      'Faz o teu primeiro check-in para começar a acompanhar a tua progressão.';

  @override
  String get agirTimeline3a => 'Último dia contribuição 3a';

  @override
  String get agirTimeline3aSub =>
      'Verifica que o teu teto foi atingido antes do final de dezembro.';

  @override
  String get agirTimeline3aCta => 'Vérifier mon 3a';

  @override
  String agirTimelineTax(String canton) {
    return 'Declaração de impostos $canton';
  }

  @override
  String get agirTimelineTaxSub =>
      'Lembra-te de reunir os teus certificados 3a e LPP.';

  @override
  String get agirTimelineTaxCta => 'Preparar os meus documentos';

  @override
  String get agirTimelineLamal => 'Franquia LAMal (mudar?)';

  @override
  String get agirTimelineLamalSub =>
      'Avalia se a tua franquia atual ainda é adequada.';

  @override
  String get agirTimelineLamalCta => 'Simular as franquias';

  @override
  String get agirTimelineRetireSub => 'O teu objetivo principal.';

  @override
  String get agirAuto => 'Auto';

  @override
  String get agirManuel => 'Manuel';

  @override
  String get agirDisclaimer =>
      'Ferramenta educativa — não constitui aconselhamento financeiro personalizado. Os prazos são indicativos e podem variar consoante o teu cantão e situação.';

  @override
  String checkinTitle(String month) {
    return 'CHECK-IN $month';
  }

  @override
  String checkinHeader(String month) {
    return 'Check-in $month';
  }

  @override
  String get checkinSubtitle => 'Confirma as tuas contribuições do mês';

  @override
  String get checkinPlannedSection => 'Versements planifiés';

  @override
  String get checkinEventsSection => 'Événements du mois';

  @override
  String get checkinExpenses => 'Despesas excecionais?';

  @override
  String get checkinExpensesHint => 'Ex.: 2000 (reparação automóvel)';

  @override
  String get checkinRevenues => 'Receitas excecionais?';

  @override
  String get checkinRevenuesHint => 'Ex.: 5000 (bónus anual)';

  @override
  String get checkinNoteSection => 'Nota do mês (opcional)';

  @override
  String get checkinNoteHint =>
      'Ex.: Mês complicado, despesa imprevista com o carro...';

  @override
  String get checkinSubmit => 'Valider le check-in';

  @override
  String get checkinInvalidAmount => 'Montant invalide';

  @override
  String checkinSuccessTitle(String month) {
    return 'Feito. Check-in $month concluído.';
  }

  @override
  String get checkinSeeTrajectory => 'Ver a minha trajetória atualizada';

  @override
  String get checkinImpactLabel => 'Impacto na tua trajetória';

  @override
  String checkinImpactCapital(String amount) {
    return 'Capital projetado +$amount este mês';
  }

  @override
  String checkinImpactTotal(String amount) {
    return 'Total contribuições: $amount';
  }

  @override
  String get checkinStreakLabel => 'Série en cours';

  @override
  String checkinStreakCount(String count) {
    return '$count meses consecutivos no objetivo!';
  }

  @override
  String get checkinCoachTip => 'Tip du coach';

  @override
  String get checkinAuto => 'Auto';

  @override
  String get checkinManuel => 'Manuel';

  @override
  String get checkinDisclaimer =>
      'Ferramenta educativa — não constitui aconselhamento financeiro personalizado. As projeções são estimativas baseadas nos dados declarados.';

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
  String get vaultHeaderTitle => 'O teu cofre financeiro';

  @override
  String get vaultHeaderSubtitle =>
      'Centraliza, compreende e age sobre os teus documentos';

  @override
  String vaultDocCount(String count) {
    return '$count documents';
  }

  @override
  String get vaultCategoryLpp => 'Prévoyance LPP';

  @override
  String get vaultCategorySalary => 'Certificado de salário';

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
  String get vaultGuidanceLeaseTitle =>
      'Contrato — Os teus direitos como inquilino';

  @override
  String get vaultGuidanceLeaseBody =>
      'Na Suíça, a renda pode ser contestada se exceder o rendimento admissível (CO art. 269). A taxa de referência hipotecária influencia diretamente os teus direitos.';

  @override
  String get vaultGuidanceLeaseSource => 'CO art. 269-270, OBLF art. 12-13';

  @override
  String get vaultGuidanceInsuranceTitle => 'Seguros — Auditoria de cobertura';

  @override
  String get vaultGuidanceInsuranceBody =>
      'A RC privada e o seguro do lar não são obrigatórios na Suíça, mas são fortemente recomendados. Verifica as tuas coberturas, sublimites e franquias.';

  @override
  String get vaultGuidanceInsuranceSource => 'LCA art. 69, CGA seguradoras';

  @override
  String get vaultGuidanceLamalTitle => 'LAMal — Otimização de franquia';

  @override
  String get vaultGuidanceLamalBody =>
      'Podes mudar de franquia LAMal todos os anos antes de 30 de novembro (franquia mais alta) ou 31 de dezembro (franquia mais baixa). Compara com base no teu consumo médico real.';

  @override
  String get vaultGuidanceLamalSource => 'LAMal art. 62, OAMal art. 93-94';

  @override
  String get vaultGuidanceSalaryTitle => 'Salário — Verificação do certificado';

  @override
  String get vaultGuidanceSalaryBody =>
      'O teu certificado de salário (Lohnausweis) é o documento-chave para a tua declaração fiscal. Verifica os montantes, as prestações acessórias e as despesas profissionais declaradas.';

  @override
  String get vaultGuidanceSalarySource => 'LIFD art. 127, OFS formulário 11';

  @override
  String get vaultUploadTitle => 'Que tipo de documento?';

  @override
  String get vaultUploadButton => 'Escolher um ficheiro PDF';

  @override
  String get vaultEmptyTitle => 'Aucun document';

  @override
  String get vaultEmptySubtitle =>
      'Adiciona o teu primeiro documento para alimentar as tuas simulações com dados reais.';

  @override
  String get vaultPremiumTitle => 'Coffre-fort Premium';

  @override
  String get vaultPremiumBody =>
      'Passa para o MINT Premium para armazenar um número ilimitado de documentos e desbloquear a análise avançada.';

  @override
  String get vaultPremiumCta => 'Découvrir Premium';

  @override
  String get vaultDocListTitle => 'Mes documents';

  @override
  String vaultConfidence(String confidence) {
    return 'Confiança: $confidence%';
  }

  @override
  String get vaultAnalyzing => 'Analyse en cours...';

  @override
  String get vaultDeleteTitle => 'Eliminar o documento?';

  @override
  String get vaultDeleteMessage => 'Esta ação é irreversível.';

  @override
  String get vaultDeleteButton => 'Supprimer';

  @override
  String get vaultPrivacy =>
      'Os teus documentos são analisados localmente e nunca são partilhados com terceiros.';

  @override
  String get vaultDisclaimer =>
      'O MINT é uma ferramenta educativa. As informações jurídicas apresentadas são a título indicativo e não substituem aconselhamento profissional.';

  @override
  String get soaTitle => 'Ton Plan Mint';

  @override
  String get soaScoreLabel => 'Pontuação de Saúde Financeira';

  @override
  String get soaPrioritiesTitle => 'As tuas 3 Ações Prioritárias';

  @override
  String get soaDiagnosticTitle => 'Diagnóstico por Círculo';

  @override
  String get soaTaxTitle => 'Simulation Fiscale';

  @override
  String get soaRetirementTitle => 'Projeção Reforma (65 anos)';

  @override
  String get soaLppTitle => 'Stratégie Rachat LPP';

  @override
  String get soaBudgetTitle => 'Ton Budget Calculé';

  @override
  String get soaTransparencyTitle => 'Transparência e Roteiro';

  @override
  String get soaDisclaimerText =>
      'Ferramenta educativa — não constitui aconselhamento financeiro nos termos da LSFin. As projeções baseiam-se nos dados declarados.';

  @override
  String get soaNextTitle => 'Et ensuite ?';

  @override
  String get soaNextSubtitle => 'Módulos adaptados ao teu perfil';

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
    return 'Atenção: Lacunas AVS detetadas ($gap anos)';
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
    return 'Poupança: CHF $amount';
  }

  @override
  String soaTotalSaving(String amount) {
    return 'Poupança fiscal total: CHF $amount';
  }

  @override
  String soaNature(String nature) {
    return 'Nature : $nature';
  }

  @override
  String get soaAssumptions => 'Hipóteses de Trabalho';

  @override
  String get soaConflicts => 'Conflitos de Interesses e Comissões';

  @override
  String get soaNoConflict =>
      'Nenhum conflito de interesses identificado para este relatório.';

  @override
  String get soaSafeModeLocked => 'Prioridade ao desendividamento';

  @override
  String get soaSafeModeMessage =>
      'As tuas ações prioritárias são substituídas por um plano de desendividamento.';

  @override
  String get soaLimitations => 'Limitations';

  @override
  String get soaProtectionSources => 'Fontes: LP art. 93, Diretivas CSIAS';

  @override
  String get soaPrevoyanceSources => 'Fontes: LPP art. 14, OPP3, LAVS';

  @override
  String get soaCroissanceSources => 'Fontes: LIFD art. 33';

  @override
  String get soaOptimisationSources => 'Fontes: CC art. 470, LIFD';

  @override
  String get soaAvailableMonth => 'Disponible / mois';

  @override
  String get soaRemainder => 'Reste à vivre';

  @override
  String get soaEstimatedTaxLabel => 'Impôts Estimés';

  @override
  String get soaSavingsRate => 'Taxa de poupança';

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
  String get soaHousing => 'Habitação';

  @override
  String get soaDebtRepayment => 'Remboursement dettes';

  @override
  String get soaAvailable => 'Disponible';

  @override
  String get soaImportant => 'IMPORTANT:';

  @override
  String get soaDisclaimer1 =>
      'Esta é uma ferramenta educativa, não constitui aconselhamento financeiro (LSFin).';

  @override
  String get soaDisclaimer2 =>
      'Os montantes baseiam-se nas informações declaradas.';

  @override
  String get soaDisclaimer3 =>
      '\'Disponível\' = Rendimentos - Habitação - Dívidas - Impostos - LAMal - Despesas fixas.';

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
      'Estás em dia este mês. Dá agora prioridade à ação de maior impacto.';

  @override
  String get agirCoachPulsePending =>
      'O teu check-in mensal é a próxima ação crítica para manter a tua trajetória de previdência.';

  @override
  String agirCoachPulseWhyNow(String reason) {
    return 'Porquê agora: $reason';
  }

  @override
  String get agirScenarioBriefTitle => 'Cenários de reforma em resumo';

  @override
  String agirScenarioBriefSummary(
      String years, String baseCapital, String replacement, String gapCapital) {
    return 'Em ~$years anos, o teu cenário Base visa $baseCapital (~$replacement% de taxa de substituição).';
  }

  @override
  String get agirScenarioBriefCta => 'Abrir a simulação completa';

  @override
  String get advisorMiniWeekOneCta => 'Lancer ma semaine 1';

  @override
  String get advisorMiniStartWithDashboard => 'Começar com o dashboard';

  @override
  String get advisorMiniCoachIntroChallenge =>
      'Objetivo: passar da análise à ação esta semana. Começamos agora com o essencial.';

  @override
  String get checkinScoreReasonStable =>
      'Pontuação estável este mês: mantém a regularidade das tuas ações.';

  @override
  String checkinScoreReasonPositiveContrib(String amount) {
    return 'Subida principal: contribuições confirmadas ($amount) este mês.';
  }

  @override
  String get checkinScoreReasonPositiveIncome =>
      'Subida principal: rendimento excecional adicionado este mês.';

  @override
  String get checkinScoreReasonPositiveGeneral =>
      'Subida principal: progressão global da tua disciplina financeira.';

  @override
  String checkinScoreReasonNegativeExpense(String amount) {
    return 'Descida principal: despesas excecionais este mês ($amount).';
  }

  @override
  String checkinScoreReasonNegativeContrib(String amount) {
    return 'Descida principal: redução das tuas contribuições planeadas ($amount/mês).';
  }

  @override
  String get checkinScoreReasonNegativeGeneral =>
      'Descida temporária este mês. Ajustaremos o plano no próximo check-in.';

  @override
  String get checkinImpactPending => 'Impacto em curso de cálculo';

  @override
  String get coachDataQualityTitle => 'Qualite des donnees';

  @override
  String coachDataQualityBody(String dataPoints, String percentage) {
    return 'Cálculo atual: $dataPoints dados introduzidos ($percentage%). Os campos não preenchidos são estimados — os teus resultados serão mais precisos com cada novo dado.';
  }

  @override
  String get coachShockTitle => 'Os teus números-chave';

  @override
  String get coachShockSubtitle =>
      'Montantes personalizados para esclarecer as tuas decisões';

  @override
  String get coachScenarioDecodedTitle => 'Os teus cenários decifrados';

  @override
  String get coachBadgeStatic => 'Coach';

  @override
  String get agirActionsRecommendedTitle => 'Actions recommandees';

  @override
  String get agirActionsRecommendedSubtitle => 'Triees par priorite';

  @override
  String get profileCoachKnowledgeTitle => 'O que o MINT sabe sobre ti';

  @override
  String get profileStateFull => 'Profil complet';

  @override
  String get profileStatePartial => 'Profil partiel';

  @override
  String get profileStateMissing => 'Profil non renseigne';

  @override
  String profileCoachKnowledgeSummary(String profileState, String precision,
      String checkins, String scorePart) {
    return '$profileState • Precisão $precision% • Check-ins: $checkins$scorePart';
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
  String get naissanceRanking26 => 'SUBSÍDIOS POR CANTÃO';

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
  String get waterfallNetFicheDePaie => 'Recibo líquido';

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
  String get waterfallTitle => 'Cascata orçamental';

  @override
  String get narrativeDefaultName => 'Tu';

  @override
  String narrativeCouplePositiveMargin(String margin) {
    return 'Juntos, têm uma margem de $margin CHF/mês.';
  }

  @override
  String narrativeCoupleTightBudget(String margin) {
    return 'Juntos, o vosso orçamento está apertado em $margin CHF/mês.';
  }

  @override
  String narrativeCoupleHighPatrimoine(String patrimoine) {
    return 'Com um património de $patrimoine CHF, têm margem de manobra.';
  }

  @override
  String narrativeHighHealth(String name) {
    return '$name, estás em boa saúde financeira. Continua assim.';
  }

  @override
  String narrativeHighHealthPatrimoine(String patrimoine) {
    return 'O teu património de $patrimoine CHF dá-te uma boa margem de manobra.';
  }

  @override
  String narrativeLowHealth(String name) {
    return '$name, concentra-te no essencial. Vamos estabilizar juntos.';
  }

  @override
  String narrativeLowHealthPatrimoine(String patrimoine) {
    return 'O teu património de $patrimoine CHF é um trunfo a proteger.';
  }

  @override
  String narrativeMediumHealth(String name) {
    return '$name, tens boas bases. Algumas ações podem fazer a diferença.';
  }

  @override
  String narrativeMediumHealthPatrimoine(String patrimoine) {
    return 'O teu património de $patrimoine CHF é um bom ponto de partida.';
  }

  @override
  String narrativeConfidenceLabel(String score) {
    return 'Confiança do perfil: $score%';
  }

  @override
  String patrimoineCoupleTitleCouple(String firstName, String conjointName) {
    return 'Património — $firstName & $conjointName';
  }

  @override
  String patrimoineCoupleTitleSolo(String firstName) {
    return 'Património — $firstName';
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
  String get patrimoineLtvAmortissement => 'Amortização recomendada';

  @override
  String get patrimoineLtvElevee => 'LTV elevado — amortizar';

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
  String get patrimoineBrut => 'Património bruto';

  @override
  String get patrimoineDettes => '−Dettes';

  @override
  String get patrimoineNetLabel => 'Patrimoine net';

  @override
  String patrimoineDont(String name, String amount) {
    return 'dos quais $name ~CHF $amount';
  }

  @override
  String get conjointProfilsLies => 'Profils liés';

  @override
  String get conjointProfilConjoint => 'Perfil do cônjuge';

  @override
  String conjointDeclaredStatus(String name) {
    return '$name não tem conta MINT. Os seus dados são estimados (🟡).';
  }

  @override
  String conjointInvitedStatus(String name) {
    return 'Convite enviado a $name. A aguardar resposta.';
  }

  @override
  String conjointLinkedStatus(String name) {
    return '✅ Perfis vinculados! Os dados de $name estão sincronizados.';
  }

  @override
  String conjointInviteLabel(String name) {
    return 'Convidar $name (5 perguntas, sem conta)';
  }

  @override
  String get conjointLierProfils => 'Vincular os nossos perfis';

  @override
  String get conjointRenvoyerInvitation => 'Reenviar convite';

  @override
  String get conjointRegimeLabel => 'Regime matrimonial: ';

  @override
  String get conjointRegimeParticipation => 'Participação nos adquiridos';

  @override
  String get conjointRegimeSeparation => 'Separação de bens';

  @override
  String get conjointRegimeCommunaute => 'Comunhão de bens';

  @override
  String get conjointRegimeDefault => '(predefinido CC art. 196)';

  @override
  String get conjointModifier => 'modifier';

  @override
  String get futurHorizonTitle => 'Horizonte de Reforma';

  @override
  String get futurCoupleLabel => 'Couple';

  @override
  String get futurTauxRemplacement => 'Taxa de substituição';

  @override
  String get futurAgeRetraite => 'Age retraite';

  @override
  String get futurConfiance => 'Confiance';

  @override
  String get futurRevenuMensuelProjection =>
      'Rendimento mensal projetado na reforma';

  @override
  String get futurRenteAvs => 'Rente AVS';

  @override
  String get futurRenteLpp => 'Pensão LPP estimada';

  @override
  String get futurPilier3aSwr => 'Pilar 3a (SWR 4%)';

  @override
  String futurCapitalLabel(String amount) {
    return 'Capital $amount';
  }

  @override
  String get futurLibrePassageSwr => 'Livre passagem (SWR 4%)';

  @override
  String get futurInvestissementsSwr => 'Investimentos (SWR 4%)';

  @override
  String get futurTotalCoupleProjecte => 'Total casal projetado';

  @override
  String get futurTotalMensuelProjecte => 'Total mensal projetado';

  @override
  String get futurCapitalRetraite => 'Capital na reforma';

  @override
  String get futurCapitalTotal => 'Capital total (3a + LP + investissements)';

  @override
  String get futurCapitalTaxHint =>
      'O levantamento de capital é tributado separadamente (LIFD art. 38). O SWR não é rendimento tributável.';

  @override
  String futurMargeIncertitude(String pct) {
    return 'Margem de incerteza (± $pct%)';
  }

  @override
  String futurFourchette(String low, String high) {
    return 'Intervalo: CHF $low – $high/mês';
  }

  @override
  String get futurCompleterProfil =>
      'Completa o teu perfil para refinar a projeção.';

  @override
  String get futurDisclaimer =>
      'Projeção educativa — não constitui aconselhamento (LSFin). SWR 4% = regra dos 4%, resultados não assegurados. Pensões AVS/LPP estimadas segundo LAVS art. 21-40, LPP art. 14-16.';

  @override
  String get futurExplorerDetails => 'Explorar detalhes';

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
  String get pulseTitle => 'Hoje';

  @override
  String pulseGreeting(String name) {
    return 'Olá $name';
  }

  @override
  String pulseGreetingCouple(String name1, String name2) {
    return 'Olá $name1 e $name2';
  }

  @override
  String get pulseWelcome => 'Vamos ver onde estás.';

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
  String pulseAmountPerMonth(String amount) {
    return '$amount/mês';
  }

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
  String get shellWelcomeBack => 'De volta. Os teus números estão atualizados.';

  @override
  String shellWelcomeBackDelta(Object delta) {
    return 'De volta! A sua precisu00e3o ganhou +$delta pts desde a u00faltima visita.';
  }

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
  String get simLppBuybackTitle => 'Otimização de Resgate LPP';

  @override
  String get simLppBuybackSubtitle => 'Efeito alavanca fiscal + Capitalização';

  @override
  String get simLppBuybackPotential => 'Potentiel de rachat';

  @override
  String get simLppBuybackYearsToRetirement => 'Anos até à reforma';

  @override
  String get simLppBuybackStaggering => 'Lissage (staggering)';

  @override
  String get simLppBuybackFundRate => 'Taxa da caixa LPP';

  @override
  String get simLppBuybackTaxableIncome => 'Revenu imposable';

  @override
  String get simLppBuybackUnitChf => 'CHF';

  @override
  String get simLppBuybackUnitYears => 'ans';

  @override
  String get simLppBuybackFinalCapital => 'Valor Final Capitalizado';

  @override
  String simLppBuybackRealReturn(String rate) {
    return 'Rendimento Real: $rate % / ano';
  }

  @override
  String get simLppBuybackTaxSavings => 'Économie Impôts';

  @override
  String get simLppBuybackNetEffort => 'Effort Net';

  @override
  String get simLppBuybackTotalGain => 'Ganho Total da operação';

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
      'O resgate LPP é uma das raras ferramentas de planeamento fiscal acessíveis a todos. Cada franco resgatado reduz diretamente o teu rendimento tributável.';

  @override
  String get simLppBuybackBonASavoirItem2 =>
      'Cada franco resgatado é dedutível do teu rendimento tributável (LIFD art. 33 al. 1 let. d). Quanto mais alto for o teu escalão marginal, maior o efeito de alavanca.';

  @override
  String get simLppBuybackBonASavoirItem3 =>
      'Atenção: qualquer levantamento EPL fica bloqueado durante 3 anos após um resgate (LPP art. 79b al. 3). Planeia os teus resgates em conformidade.';

  @override
  String simLppBuybackDisclaimer(
      String fundRate, int staggeringYears, String taxableIncome) {
    return 'Simulação incluindo o juro da caixa ($fundRate %) e a poupança fiscal distribuída ao longo de $staggeringYears anos para um rendimento tributável de CHF $taxableIncome. O rendimento real é calculado sobre o teu esforço líquido real.';
  }

  @override
  String get simRealInterestTitle => 'Simulador de Juro Real';

  @override
  String get simRealInterestSubtitle =>
      'Capital + Poupança fiscal reinvestida (Virtual)';

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
    return 'Hipóteses: Taxa marginal $rate %. Rendimentos de mercado: 2 % / 4 % / 6 %.';
  }

  @override
  String get simRealInterestEducTitle => 'Compreender o rendimento real';

  @override
  String get simRealInterestEducBullet1 =>
      'O rendimento real = rendimento nominal − inflação − comissões';

  @override
  String get simRealInterestEducBullet2 =>
      'Um investimento a 3 % com 1.5 % de inflação e 0.5 % de comissões rende na realidade apenas 1 % real por ano.';

  @override
  String get simRealInterestEducBullet3 =>
      'Em 30 anos, esta diferença pode representar dezenas de milhares de francos.';

  @override
  String get simBuybackTitle => 'Stratégie Rachat LPP';

  @override
  String get simBuybackSubtitle => 'Otimização por escalonamento (Staggering)';

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
    return 'Ganho estimado: + CHF $amount';
  }

  @override
  String get simBuybackSavingsLabel => 'Économie';

  @override
  String get simBuybackMarginalRateQuestion =>
      'O que é a taxa marginal de imposição?';

  @override
  String get simBuybackMarginalRateTitle => 'Taxa marginal de imposição';

  @override
  String get simBuybackMarginalRateExplanation =>
      'A taxa marginal é a percentagem de imposto sobre o teu último franco ganho. Quanto mais altos os teus rendimentos, mais alta a taxa marginal. Ao escalonar os teus resgates, ficas em escalões mais baixos todos os anos.';

  @override
  String get simBuybackMarginalRateTip =>
      'Ao escalonar os teus resgates, ficas em escalões de imposição mais baixos a cada ano — o ganho acumulado pode ser considerável.';

  @override
  String get simBuybackLockedTitle => 'Rachat LPP bloqué';

  @override
  String get simBuybackLockedMessage =>
      'O resgate LPP está desativado em modo proteção. Um resgate bloqueia a tua liquidez durante 3 anos (LPP art. 79b). Dá primeiro prioridade ao desendividamento.';

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
      'Atenção: Sem margem de manobra para as despesas variáveis.';

  @override
  String get ninetyDayGaugeTitle => 'Règle des 90 jours';

  @override
  String get ninetyDayGaugeSubtitle => 'Fronteiriços · Limiar fiscal';

  @override
  String get ninetyDayGaugeDaysOf90 => '/ 90 jours';

  @override
  String get ninetyDayGaugeStatusRed =>
      'Limiar ultrapassado — risco de tributação ordinária na Suíça';

  @override
  String ninetyDayGaugeStatusOrange(int remaining, String plural) {
    return 'Atenção: faltam $remaining dia$plural para o limiar';
  }

  @override
  String ninetyDayGaugeStatusGreen(int remaining, String plural) {
    return 'Zona segura — faltam $remaining dia$plural para o limiar';
  }

  @override
  String ninetyDayGaugeSemanticsLabel(int days, String status) {
    return 'Indicador da regra dos 90 dias. $days dias em 90. $status';
  }

  @override
  String get ninetyDayGaugeZoneSafe => 'Zone sûre';

  @override
  String get ninetyDayGaugeZoneAttention => 'Attention';

  @override
  String get ninetyDayGaugeZoneRisk => 'Risque fiscal';

  @override
  String get forfaitFiscalTitle => 'Forfait fiscal vs Ordinário';

  @override
  String get forfaitFiscalSubtitle => 'Comparação anual · Expatriados';

  @override
  String get forfaitFiscalSaving => 'Économie forfait';

  @override
  String get forfaitFiscalSurcharge => 'Surcoût forfait';

  @override
  String get forfaitFiscalPerYear => 'par année';

  @override
  String forfaitFiscalSemanticsLabel(
      String ordinary, String forfait, String savings) {
    return 'Comparação forfait fiscal. Tributação ordinária: $ordinary. Forfait fiscal: $forfait.';
  }

  @override
  String get forfaitFiscalOrdinaryLabel => 'Imposition\nordinaire';

  @override
  String get forfaitFiscalForfaitLabel => 'Forfait\nfiscal';

  @override
  String get forfaitFiscalBaseLine => 'Base forfaitaire';

  @override
  String get spendingMeterBudgetUnavailable => 'Orçamento não disponível';

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
  String get avsGuideHeaderTitle => 'Como obter o teu extrato AVS';

  @override
  String get avsGuideHeaderSubtitle =>
      'O extrato de conta individual (CI) contém os teus anos de contribuição, o rendimento médio (RAMD) e eventuais lacunas. É a chave para uma projeção AVS fiável.';

  @override
  String avsGuideConfidencePoints(int points) {
    return '+$points pontos de confiança';
  }

  @override
  String get avsGuideConfidenceSubtitle =>
      'Anos de contribuição, RAMD, lacunas';

  @override
  String get avsGuideStepsTitle => 'En 4 étapes';

  @override
  String get avsGuideStep1Title => 'Vai a www.ahv-iv.ch';

  @override
  String get avsGuideStep1Subtitle =>
      'Este é o site oficial do AVS/AI. Também podes solicitar o teu extrato diretamente à tua caixa de compensação.';

  @override
  String get avsGuideStep2Title =>
      'Inicia sessão com o teu eID ou cria uma conta';

  @override
  String get avsGuideStep2Subtitle =>
      'Precisarás do teu número AVS (756.XXXX.XXXX.XX, no teu cartão de seguro de saúde).';

  @override
  String get avsGuideStep3Title =>
      'Solicita o teu extrato de conta individual (CI)';

  @override
  String get avsGuideStep3Subtitle =>
      'Procura a secção «Extrato de conta» ou «Kontoauszug». É um documento oficial que resume todas as tuas contribuições.';

  @override
  String get avsGuideStep4Title => 'Receberás por correio ou PDF';

  @override
  String get avsGuideStep4Subtitle =>
      'Dependendo da tua caixa, o extrato chega em 5 a 10 dias úteis. Algumas caixas oferecem download imediato em PDF.';

  @override
  String get avsGuideOpenAhvButton => 'Abrir ahv-iv.ch';

  @override
  String get avsGuideScanButton => 'Já tenho o meu extrato → Digitalizar';

  @override
  String get avsGuideTestMode => 'MODE TEST';

  @override
  String get avsGuideTestDescription =>
      'Não tens o teu extrato AVS à mão? Testa o fluxo com um extrato de exemplo.';

  @override
  String get avsGuideTestButton => 'Usar um exemplo';

  @override
  String get avsGuideFreeNote =>
      'O extrato AVS é gratuito e está disponível em 5 a 10 dias úteis. Também podes dirigir-te à tua caixa de compensação cantonal.';

  @override
  String get avsGuidePrivacyNote =>
      'A imagem do teu extrato nunca é armazenada nem enviada. A extração é feita no teu dispositivo. Apenas os valores que confirmas são guardados no teu perfil.';

  @override
  String avsGuideSnackbarError(String url) {
    return 'Impossível abrir $url. Copia o endereço e abre-o no teu navegador.';
  }

  @override
  String get dataBlockDisclaimer =>
      'Ferramenta educativa simplificada. Não constitui aconselhamento financeiro (LSFin).';

  @override
  String get dataBlockIncomplete =>
      'Esta secção ainda está incompleta. Abre a secção dedicada para adicionar os dados em falta.';

  @override
  String get dataBlockComplete => 'Esta secção está completa.';

  @override
  String get dataBlockModeForm => 'Formulário';

  @override
  String get dataBlockModeCoach => 'Falar com o coach';

  @override
  String get dataBlockStatusComplete => 'Completo';

  @override
  String get dataBlockStatusPartial => 'Parcial';

  @override
  String get dataBlockStatusMissing => 'Em falta';

  @override
  String get dataBlockRevenuTitle => 'Rendimento';

  @override
  String get dataBlockRevenuDesc =>
      'O teu salário bruto é a base de todas as projeções: previdência, impostos, orçamento. Quanto mais preciso for, mais fiáveis serão os teus resultados.';

  @override
  String get dataBlockRevenuCta => 'Especificar o meu rendimento';

  @override
  String get dataBlockLppTitle => 'Previdência LPP';

  @override
  String get dataBlockLppDesc =>
      'O teu capital LPP (2.º pilar) representa frequentemente o maior capital da tua previdência. Um certificado de previdência fornece um valor exato em vez de uma estimativa.';

  @override
  String get dataBlockLppCta => 'Adicionar o meu certificado LPP';

  @override
  String get dataBlockAvsTitle => 'Extrato AVS';

  @override
  String get dataBlockAvsDesc =>
      'O extrato AVS confirma os teus anos de contribuição efetivos. Lacunas (estadia no estrangeiro, anos em falta) reduzem a tua renda AVS.';

  @override
  String get dataBlockAvsCta => 'Solicitar o meu extrato AVS';

  @override
  String get dataBlock3aTitle => 'Pilar 3a';

  @override
  String get dataBlock3aDesc =>
      'As tuas contas 3a complementam a tua previdência e oferecem uma vantagem fiscal. Introduz os saldos atuais para uma visão completa.';

  @override
  String get dataBlock3aCta => 'Simular o meu 3a';

  @override
  String get dataBlockPatrimoineTitle => 'Património';

  @override
  String get dataBlockPatrimoineDesc =>
      'Poupança livre, investimentos, imobiliário: estes dados completam a tua projeção e permitem calcular o teu Financial Resilience Index.';

  @override
  String get dataBlockPatrimoineCta => 'Registar o meu património';

  @override
  String get dataBlockFiscaliteTitle => 'Fiscalidade';

  @override
  String get dataBlockFiscaliteDesc =>
      'O teu município, rendimento tributável e património determinam a tua taxa marginal de imposto. Uma declaração fiscal ou avaliação dá uma taxa real em vez de estimada (coeficiente municipal 60%-130%).';

  @override
  String get dataBlockFiscaliteCta => 'Comparar a minha fiscalidade';

  @override
  String get dataBlockObjectifTitle => 'Objetivo de reforma';

  @override
  String get dataBlockObjectifDesc =>
      'Com que idade desejas parar de trabalhar? Um objetivo claro permite calcular o esforço de poupança necessário e as opções (antecipação, reforma parcial).';

  @override
  String get dataBlockObjectifCta => 'Ver a minha projeção';

  @override
  String get dataBlockMenageTitle => 'Composição do agregado familiar';

  @override
  String get dataBlockMenageDesc =>
      'Em casal, as projeções mudam: AVS limitado para casados (LAVS art. 35), renda de sobrevivência (LPP art. 19), otimização fiscal conjunta.';

  @override
  String get dataBlockMenageCta => 'Gerir o meu agregado familiar';

  @override
  String get dataBlockUnknownTitle => 'Dados';

  @override
  String get dataBlockUnknownDesc =>
      'Esta ligação de dados já não está atualizada. Usa a secção recomendada para completar o teu perfil.';

  @override
  String get dataBlockUnknownCta => 'Abrir o diagnóstico';

  @override
  String get dataBlockDefaultTitle => 'Dados';

  @override
  String get dataBlockDefaultDesc =>
      'Completa esta secção para melhorar a precisão das tuas projeções.';

  @override
  String get dataBlockDefaultCta => 'Completar';

  @override
  String get renteVsCapitalAppBarTitle => 'Pensão ou capital: a tua decisão';

  @override
  String get renteVsCapitalIntro =>
      'Na reforma, escolhes de uma vez por todas: um rendimento vitalício ou o teu capital em mão.';

  @override
  String get renteVsCapitalRenteLabel => 'Rente';

  @override
  String get renteVsCapitalRenteExplanation =>
      'A tua caixa de pensões paga-te um montante fixo todos os meses, enquanto viveres — mesmo que chegues aos 100 anos. Em troca, nunca recuperas o teu capital.';

  @override
  String get renteVsCapitalCapitalLabel => 'Capital';

  @override
  String get renteVsCapitalCapitalExplanation =>
      'Levantas todo o teu capital LPP de uma vez. Investe-lo e levantas o que precisas cada mês. Liberdade total, mas o risco de ficar sem nada é real.';

  @override
  String get renteVsCapitalMixteLabel => 'Mixte';

  @override
  String get renteVsCapitalMixteExplanation =>
      'A parte obrigatória em renda (taxa 6.8 %) + a sobreobrigatória em capital. Um compromisso entre segurança e flexibilidade.';

  @override
  String get renteVsCapitalEstimateMode => 'Estimar para mim';

  @override
  String get renteVsCapitalCertificateMode => 'Tenho o meu certificado';

  @override
  String get renteVsCapitalAge => 'Ton âge';

  @override
  String get renteVsCapitalSalary => 'O teu salário bruto anual (CHF)';

  @override
  String get renteVsCapitalLppTotal => 'O teu capital LPP atual (CHF)';

  @override
  String renteVsCapitalEstimatedCapital(int age, String amount) {
    return 'Capital estimado aos $age anos: ~$amount';
  }

  @override
  String renteVsCapitalEstimatedRente(String amount) {
    return 'Pensão estimada: ~$amount/ano';
  }

  @override
  String get renteVsCapitalProjectionSource =>
      'Projeção baseada na tua idade, salário e LPP atual';

  @override
  String get renteVsCapitalLppOblig =>
      'Capital LPP obrigatório (certificado LPP)';

  @override
  String get renteVsCapitalLppSurob =>
      'Capital LPP sobreobrigatório (certificado LPP)';

  @override
  String get renteVsCapitalRenteProposed =>
      'Renda anual proposta (certificado LPP)';

  @override
  String get renteVsCapitalTcOblig => 'Taxa conv. obrig. (%)';

  @override
  String get renteVsCapitalTcSurob => 'Taxa conv. supraobrig. (%)';

  @override
  String get renteVsCapitalMaxPrecision =>
      'Precisão máxima — resultados baseados nos teus dados reais.';

  @override
  String get renteVsCapitalCanton => 'Canton';

  @override
  String get renteVsCapitalMarried => 'Casado/a';

  @override
  String get renteVsCapitalRetirementAge => 'Reforma prevista aos';

  @override
  String renteVsCapitalAgeYears(int age) {
    return '$age ans';
  }

  @override
  String renteVsCapitalAccrocheTaxEpuise(String taxDelta, int age) {
    return 'Esta decisão pode custar-te $taxDelta de impostos a mais — ou deixar-te sem nada aos $age anos. Só podes tomá-la uma vez.';
  }

  @override
  String renteVsCapitalAccrocheTax(String taxDelta) {
    return 'Esta decisão pode alterar $taxDelta de impostos sobre a tua reforma. Só podes tomá-la uma vez.';
  }

  @override
  String renteVsCapitalAccrocheEpuise(int age) {
    return 'Com o capital, podes ficar sem dinheiro a partir dos $age anos. Com a renda, recebes um montante fixo vitalício. Só podes escolher uma vez.';
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
    return 'durante $duration';
  }

  @override
  String get renteVsCapitalMicroRente =>
      'A tua caixa paga-te este montante todos os meses, enquanto viveres.';

  @override
  String renteVsCapitalMicroCapital(String swr, String rendement) {
    return 'Levantas $swr % por ano de um capital investido a $rendement %.';
  }

  @override
  String renteVsCapitalSyntheseCapitalHigher(String delta) {
    return 'O capital dá-te $delta/mês a mais, mas pode esgotar-se.';
  }

  @override
  String renteVsCapitalSyntheseRenteHigher(String delta) {
    return 'A renda dá-te $delta/mês a mais, e nunca para.';
  }

  @override
  String get renteVsCapitalAvsEstimated => 'AVS estimée : ';

  @override
  String renteVsCapitalAvsAmount(String amount) {
    return '~$amount/mois';
  }

  @override
  String get renteVsCapitalAvsSupplementary =>
      ' suplementares em ambos os casos (LAVS art. 29)';

  @override
  String get renteVsCapitalLifeExpectancy => 'E se eu viver até aos...';

  @override
  String get renteVsCapitalLifeExpectancyRef =>
      'Esperança de vida suíça: homens 84 anos · mulheres 87 anos';

  @override
  String get renteVsCapitalChartTitle =>
      'Capital restante vs rendimentos acumulados da renda';

  @override
  String get renteVsCapitalChartSubtitle =>
      'Capital (verde): o que resta após os teus levantamentos. Renda (azul): total recebido desde o início. O cruzamento = a idade em que a renda rendeu mais.';

  @override
  String get renteVsCapitalChartAxisLabel => 'Âge';

  @override
  String renteVsCapitalBeyondHorizon(int age) {
    return 'Aos $age anos: para além do horizonte de simulação.';
  }

  @override
  String renteVsCapitalDeltaAtAge(int age) {
    return 'À $age ans : ';
  }

  @override
  String get renteVsCapitalDeltaAdvance => 'd\'avance';

  @override
  String get renteVsCapitalEducationalTitle => 'O que muda concretamente';

  @override
  String get renteVsCapitalFiscalTitle => 'Fiscalidade';

  @override
  String get renteVsCapitalFiscalLeftSubtitle => 'Tributado todos os anos';

  @override
  String get renteVsCapitalFiscalRightSubtitle => 'Tributado uma única vez';

  @override
  String get renteVsCapitalFiscalOver30years => 'sur 30 ans';

  @override
  String get renteVsCapitalFiscalAtRetrait => 'no levantamento (LIFD art. 38)';

  @override
  String renteVsCapitalFiscalCapitalSaves(String amount) {
    return 'Em 30 anos, o capital poupa-te ~$amount de impostos.';
  }

  @override
  String renteVsCapitalFiscalRenteSaves(String amount) {
    return 'Em 30 anos, a renda gera ~$amount menos de impostos.';
  }

  @override
  String get renteVsCapitalInflationTitle => 'Inflation';

  @override
  String get renteVsCapitalInflationToday => 'Aujourd\'hui';

  @override
  String get renteVsCapitalInflationIn20Years => 'Dans 20 ans';

  @override
  String get renteVsCapitalInflationPurchasingPower => 'poder de compra';

  @override
  String renteVsCapitalInflationBottomText(int percent) {
    return 'A tua renda LPP não é indexada. Compra $percent % a menos dentro de 20 anos.';
  }

  @override
  String get renteVsCapitalTransmissionTitle => 'Transmission';

  @override
  String get renteVsCapitalTransmissionLeftMarried => 'O teu cônjuge recebe';

  @override
  String get renteVsCapitalTransmissionLeftSingle => 'À ton décès';

  @override
  String renteVsCapitalTransmissionLeftValueMarried(String amount) {
    return '60% = $amount/mês';
  }

  @override
  String get renteVsCapitalTransmissionLeftValueSingle => 'Rien';

  @override
  String get renteVsCapitalTransmissionLeftDetailMarried => 'LPP art. 19';

  @override
  String get renteVsCapitalTransmissionLeftDetailSingle =>
      'para os teus herdeiros';

  @override
  String get renteVsCapitalTransmissionRightSubtitle =>
      'Os teus herdeiros recebem';

  @override
  String get renteVsCapitalTransmissionRightValue => '100 %';

  @override
  String get renteVsCapitalTransmissionRightDetail => 'do saldo restante';

  @override
  String get renteVsCapitalTransmissionBottomMarried =>
      'Com a renda, apenas o/a teu/tua cônjuge recebe 60 %. Nada para os filhos.';

  @override
  String get renteVsCapitalTransmissionBottomSingle =>
      'Com a pensão, nada vai para os teus entes queridos.';

  @override
  String get renteVsCapitalAffinerTitle => 'Refinar a tua simulação';

  @override
  String get renteVsCapitalAffinerSubtitle => 'Para quem quer aprofundar.';

  @override
  String get renteVsCapitalHypRendement => 'O que o teu capital rende por ano';

  @override
  String get renteVsCapitalHypSwr => 'Quanto levantas a cada ano';

  @override
  String get renteVsCapitalHypInflation => 'Inflation';

  @override
  String get renteVsCapitalTornadoToggle => 'Ver o diagrama de sensibilidade';

  @override
  String get renteVsCapitalImpactTitle => 'O que mais altera o resultado?';

  @override
  String get renteVsCapitalImpactSubtitle =>
      'Os parâmetros mais influentes na diferença entre as tuas opções.';

  @override
  String get renteVsCapitalHypothesesTitle => 'Hipóteses desta simulação';

  @override
  String get renteVsCapitalWarning => 'Avertissement';

  @override
  String renteVsCapitalSources(String sources) {
    return 'Fontes: $sources';
  }

  @override
  String get renteVsCapitalRachatLabel => 'Resgate LPP anual previsto (CHF)';

  @override
  String renteVsCapitalRachatMax(String amount) {
    return 'max $amount';
  }

  @override
  String get renteVsCapitalRachatHint => '0 (optionnel)';

  @override
  String get renteVsCapitalRachatTooltip =>
      'Se fizeres resgates LPP todos os anos, o seu valor futuro é adicionado ao capital na reforma. Bloqueio de 3 anos antes de EPL (LPP art. 79b).';

  @override
  String get renteVsCapitalEplLabel => 'Levantamento EPL para compra de imóvel';

  @override
  String get renteVsCapitalEplHint => 'Montante levantado (mín. 20\'000)';

  @override
  String get renteVsCapitalEplTooltip =>
      'O levantamento EPL reduz o teu capital LPP e portanto o teu capital ou pensão na reforma. Mínimo CHF 20\'000 (OPP2 art. 5). Bloqueia a recompra LPP durante 3 anos.';

  @override
  String get renteVsCapitalEplLegalRef =>
      'LPP art. 30c — OPP2 art. 5 (mín. CHF 20\'000)';

  @override
  String get renteVsCapitalProfileAutoFill =>
      'Valores pré-preenchidos a partir do teu perfil';

  @override
  String get frontalierAppBarTitle => 'Frontalier';

  @override
  String get frontalierTabImpots => 'Impôts';

  @override
  String get frontalierTab90Jours => '90 jours';

  @override
  String get frontalierTabCharges => 'Charges';

  @override
  String get frontalierCantonTravail => 'Cantão de trabalho';

  @override
  String get frontalierSalaireBrut => 'Salário bruto mensal';

  @override
  String get frontalierEtatCivil => 'État civil';

  @override
  String get frontalierCelibataire => 'Célibataire';

  @override
  String get frontalierMarie => 'Marié(e)';

  @override
  String get frontalierEnfantsCharge => 'Filhos a cargo';

  @override
  String get frontalierTauxEffectif => 'Taux effectif';

  @override
  String get frontalierTotalAnnuel => 'Total annuel';

  @override
  String get frontalierParMois => 'par mois';

  @override
  String get frontalierQuasiResidentTitle => 'Quase-residente (Genebra)';

  @override
  String get frontalierQuasiResidentDesc =>
      'Se mais de 90% dos teus rendimentos mundiais provêm da Suíça, podes solicitar a tributação ordinária com deduções (3a, despesas efetivas, etc.). Isto pode reduzir significativamente o teu imposto.';

  @override
  String get frontalierTessinTitle => 'Ticino — regime especial';

  @override
  String get frontalierEducationalTax =>
      'Na Suíça, os fronteiriços são tributados na fonte (tabela C). A taxa varia consoante o cantão, o estado civil e o número de filhos. Em Genebra, se mais de 90% dos teus rendimentos mundiais provêm da Suíça, podes solicitar o estatuto de quase-residente para beneficiar das deduções.';

  @override
  String get frontalierJoursBureau => 'Dias no escritório na Suíça';

  @override
  String get frontalierJoursHomeOffice => 'Dias de teletrabalho no estrangeiro';

  @override
  String get frontalierJaugeRisque => 'INDICADOR DE RISCO';

  @override
  String get frontalierJoursHomeOfficeLabel => 'dias de teletrabalho';

  @override
  String get frontalierRiskLow => 'Pas de risque';

  @override
  String get frontalierRiskMedium => 'Zona de atenção';

  @override
  String get frontalierRiskHigh => 'Risco fiscal — a tributação muda';

  @override
  String frontalierDaysRemaining(int days) {
    return 'Tens $days dias de margem restantes';
  }

  @override
  String get frontalierRecommandation => 'RECOMMANDATION';

  @override
  String get frontalierEducational90Days =>
      'Desde 2023, os acordos bilaterais entre a Suíça e os seus vizinhos fixam um limiar de tolerância para o teletrabalho dos fronteiriços. Para além de 90 dias de teletrabalho por ano, as contribuições sociais e a tributação podem transferir-se para o país de residência.';

  @override
  String get frontalierChargesCh => 'Charges CH';

  @override
  String frontalierChargesCountry(String country) {
    return 'Encargos $country';
  }

  @override
  String frontalierDuSalaire(String percent) {
    return '$percent% do salário';
  }

  @override
  String frontalierChargesChMoins(String amount) {
    return 'Encargos CH mais baixos: $amount/ano';
  }

  @override
  String frontalierChargesChPlus(String amount) {
    return 'Encargos CH mais altos: +$amount/ano';
  }

  @override
  String get frontalierAssuranceMaladie => 'SEGURO DE SAÚDE';

  @override
  String get frontalierLamalTitle => 'LAMal (suisse)';

  @override
  String get frontalierLamalDesc =>
      'Obrigatório se trabalhas na CH. Prémio individual (~CHF 300-500/mês).';

  @override
  String get frontalierCmuTitle => 'CMU/Segurança Social (França)';

  @override
  String get frontalierCmuDesc =>
      'Direito de opção possível para fronteiriços FR. Contribuição ~8% do rendimento fiscal.';

  @override
  String get frontalierAssurancePriveeTitle => 'Seguro privado (DE/IT/AT)';

  @override
  String get frontalierAssurancePriveeDesc =>
      'Na Alemanha, opção PKV para rendimentos elevados. IT/AT: regime obrigatório do país.';

  @override
  String get frontalierEducationalCharges =>
      'Como fronteiriço, contribuis para os seguros sociais suíços (AVS/AI/APG, AC, LPP). As taxas são geralmente mais baixas do que em França ou na Alemanha — mas o LAMal é por tua conta individualmente, o que pode compensar a vantagem.';

  @override
  String get frontalierPaysResidence => 'País de residência';

  @override
  String get frontalierLeSavaisTu => 'Le savais-tu ?';

  @override
  String get concubinageAppBarTitle => 'Casamento vs União de facto';

  @override
  String get concubinageTabComparateur => 'Comparação';

  @override
  String get concubinageTabChecklist => 'Checklist';

  @override
  String get concubinageRevenu1 => 'Rendimento 1';

  @override
  String get concubinageRevenu2 => 'Rendimento 2';

  @override
  String get concubinagePatrimoineTotal => 'Património total';

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
  String get concubinageImpots2Celibataires => 'Impostos como 2 solteiros';

  @override
  String get concubinageImpotsMaries => 'Impôts mariés';

  @override
  String get concubinagePenaliteMariage => 'Penalização por casamento';

  @override
  String get concubinageBonusMariage => 'Bonus mariage';

  @override
  String get concubinageImpotSuccession => 'IMPOSTO SOBRE SUCESSÕES';

  @override
  String get concubinagePatrimoineTransmis => 'Património transmitido';

  @override
  String get concubinageMarieExonere => 'CHF 0 (isento)';

  @override
  String concubinageConcubinTaux(String taux) {
    return 'Parceiro/a (~$taux%)';
  }

  @override
  String concubinageWarningSuccession(String impot, String patrimoine) {
    return 'Em união de facto, o teu parceiro pagaria $impot de imposto sucessório sobre um património de $patrimoine. Casado/a, estaria totalmente isento/a.';
  }

  @override
  String get concubinageNeutralTitle =>
      'Nenhuma opção é universalmente adequada';

  @override
  String get concubinageNeutralDesc =>
      'A escolha entre casamento e união de facto depende da tua situação: rendimentos, património, filhos, cantão, projeto de vida. O casamento oferece mais proteções legais automáticas, a união de facto mais flexibilidade. Um/a especialista pode ajudar-te a ver com mais clareza.';

  @override
  String get concubinageChecklistIntro =>
      'Em união de facto, nada é automático. Estas são as proteções essenciais para proteger o/a teu/tua parceiro/a.';

  @override
  String concubinageProtectionsCount(int count, int total) {
    return '$count/$total proteções em vigor';
  }

  @override
  String get concubinageChecklist1Title => 'Redigir um testamento';

  @override
  String get concubinageChecklist1Desc =>
      'Sem testamento, o/a teu/tua parceiro/a não herda nada — tudo vai para os teus pais ou irmãos. Um testamento manuscrito (escrito à mão, datado, assinado) é suficiente. Podes legar a quota disponível ao/à teu/tua parceiro/a.';

  @override
  String get concubinageChecklist2Title => 'Cláusula de beneficiário LPP';

  @override
  String get concubinageChecklist2Desc =>
      'Contacta a tua caixa de pensões para inscrever o/a teu/tua parceiro/a como beneficiário/a. Sem esta cláusula, o capital de falecimento LPP não lhe pertence. A maioria das caixas aceita o/a parceiro/a de facto sob certas condições (lar comum, etc.).';

  @override
  String get concubinageChecklist3Title => 'Acordo de união de facto';

  @override
  String get concubinageChecklist3Desc =>
      'Um contrato escrito que regula a partilha de despesas, a propriedade dos bens e o que acontece em caso de separação. Não é obrigatório, mas fortemente recomendado — sobretudo se comprarem um imóvel juntos.';

  @override
  String get concubinageChecklist4Title => 'Seguro de vida cruzado';

  @override
  String get concubinageChecklist4Desc =>
      'Um seguro de vida onde cada parceiro é beneficiário do outro permite compensar a ausência de renda AVS/LPP de sobrevivência. Compara ofertas — os prémios dependem da idade e do capital segurado.';

  @override
  String get concubinageChecklist5Title => 'Mandato de proteção futura';

  @override
  String get concubinageChecklist5Desc =>
      'Se ficares incapacitado/a (acidente, doença), o/a teu/tua parceiro/a não tem poder de representação. Um mandato de proteção futura (CC art. 360 ss.) confere-lhe esse direito.';

  @override
  String get concubinageChecklist6Title => 'Diretivas antecipadas';

  @override
  String get concubinageChecklist6Desc =>
      'Um documento que especifica os teus desejos médicos em caso de incapacidade. Podes designar o/a teu/tua parceiro/a como pessoa de confiança para decisões médicas (CC art. 370 ss.).';

  @override
  String get concubinageChecklist7Title =>
      'Conta conjunta para despesas comuns';

  @override
  String get concubinageChecklist7Desc =>
      'Uma conta conjunta simplifica a gestão das despesas partilhadas (renda, compras, contas). Definam claramente a contribuição de cada um. Em caso de separação, o saldo é dividido a 50/50 salvo acordo contrário.';

  @override
  String get concubinageChecklist8Title =>
      'Contrato de arrendamento conjunto ou individual';

  @override
  String get concubinageChecklist8Desc =>
      'Se estás no contrato com o/a teu/tua parceiro/a, são solidariamente responsáveis. Em caso de separação, ambos têm de dar aviso. Se apenas um/a é titular, o/a outro/a não tem direitos sobre a habitação.';

  @override
  String get concubinageDisclaimer =>
      'Informação simplificada para fins educativos — não constitui aconselhamento jurídico ou fiscal. As regras dependem do cantão, do município e da tua situação pessoal. Consulta um/a especialista jurídico/a para aconselhamento personalizado.';

  @override
  String get concubinageCriteriaImpots => 'Impôts';

  @override
  String get concubinageCriteriaPenaliteFiscale => 'Penalização fiscal';

  @override
  String get concubinageCriteriaBonusFiscal => 'Bonus fiscal';

  @override
  String get concubinageCriteriaAvantageux => 'Avantageux';

  @override
  String get concubinageCriteriaDesavantageux => 'Désavantageux';

  @override
  String get concubinageCriteriaHeritage => 'Héritage';

  @override
  String get concubinageCriteriaHeritageMarriage => 'Isento (CC art. 462)';

  @override
  String get concubinageCriteriaHeritageConcubinage => 'Impôt cantonal';

  @override
  String get concubinageCriteriaProtection => 'Proteção por falecimento';

  @override
  String get concubinageCriteriaProtectionMarriage => 'AVS + LPP sobrevivente';

  @override
  String get concubinageCriteriaProtectionConcubinage =>
      'Sem pensão automática';

  @override
  String get concubinageCriteriaFlexibilite => 'Flexibilité';

  @override
  String get concubinageCriteriaFlexibiliteMarriage => 'Procedimento judicial';

  @override
  String get concubinageCriteriaFlexibiliteConcubinage =>
      'Separação simplificada';

  @override
  String get concubinageCriteriaPension => 'Pension alim.';

  @override
  String get concubinageCriteriaPensionMarriage => 'Protegida pelo tribunal';

  @override
  String get concubinageCriteriaPensionConcubinage =>
      'Acordo prévio necessário';

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
  String get nudgeSalaryTitle => 'Dia de pagamento !';

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
    return 'Fazes $age anos este ano !';
  }

  @override
  String get nudgeBirthdayAction => 'Ver o meu painel';

  @override
  String get nudgeAnniversaryTitle => 'Já 1 ano juntos!';

  @override
  String get nudgeAnniversaryMessage =>
      'Usas o MINT há um ano. É o momento ideal para atualizar o teu perfil e medir os teus progressos.';

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
  String get recapTitle => 'O teu resumo semanal';

  @override
  String recapPeriod(String start, String end) {
    return 'De $start a $end';
  }

  @override
  String get recapBudgetTitle => 'Orçamento';

  @override
  String get recapBudgetSaved => 'Poupado esta semana';

  @override
  String get recapBudgetRate => 'Taxa de poupança';

  @override
  String get recapActionsTitle => 'Ações realizadas';

  @override
  String get recapActionsNone => 'Nenhuma ação esta semana';

  @override
  String get recapProgressTitle => 'Progresso';

  @override
  String recapProgressDelta(String delta) {
    return '$delta pts de confiança';
  }

  @override
  String get recapHighlightsTitle => 'Pontos de destaque';

  @override
  String get recapNextFocusTitle => 'A semana que vem';

  @override
  String get recapEmpty => 'Ainda sem dados esta semana';

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
  String get benchmarkOptInTitle => 'Ativar comparações cantonais';

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
    return 'Olá $name. Tudo fica no teu dispositivo — nada sai. O que queres saber ?';
  }

  @override
  String coachGreetingDefault(String name, String scoreSuffix) {
    return 'Olá $name. Estou a ver os teus números — diz-me o que te preocupa.$scoreSuffix';
  }

  @override
  String coachScoreSuffix(int score) {
    return ' A tua pontuação: $score/100 — vamos ver onde falha.';
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
  String get coachErrorBadRequest =>
      'Pedido inválido. Tenta reformular a tua pergunta.';

  @override
  String get coachErrorServiceUnavailable =>
      'Serviço temporariamente indisponível. Tenta novamente daqui a uns minutos.';

  @override
  String get coachErrorConnection =>
      'Erro de conexão. Verifica a tua ligação à internet ou a tua chave API.';

  @override
  String get coachSuggestSimulate3a => 'Quanto poupo se contribuir o máximo?';

  @override
  String get coachSuggestView3a => 'Quanto tenho nas minhas contas 3a?';

  @override
  String get coachSuggestSimulateLpp => 'Vale a pena resgatar o LPP?';

  @override
  String get coachSuggestUnderstandLpp => 'O que vou receber aos 65 anos?';

  @override
  String get coachSuggestTrajectory => 'É grave se eu não fizer nada?';

  @override
  String get coachSuggestScenarios => 'Renda ou capital — o que me convém?';

  @override
  String get coachSuggestDeductions => 'Quanto recupero de impostos este ano?';

  @override
  String get coachSuggestTaxImpact =>
      'Quantos impostos a menos com um resgate?';

  @override
  String get coachSuggestFitness =>
      'Estou no caminho certo para o meu objetivo?';

  @override
  String get coachSuggestRetirement =>
      'Vou ter o suficiente para viver reformado?';

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
  String get coachDisclaimer =>
      'Ferramenta educativa — as respostas não constituem aconselhamento financeiro (LSFin art. 3). Consulta um especialista para decisões importantes.';

  @override
  String get coachLoading => 'A ver os teus números…';

  @override
  String get coachSources => 'Fontes';

  @override
  String get coachInputHint => 'Uma pergunta sobre as tuas finanças?';

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
  String get tabMint => 'Mint';

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
  String get quickStartTitle => 'Tres perguntas, um primeiro numero.';

  @override
  String get quickStartSubtitle => 'O resto decides tu, quando quiseres.';

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
  String get quickStartNoIncome => 'Sem rendimento';

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
      'Estimativa educativa. Nao constitui aconselhamento financeiro (LSFin).';

  @override
  String get quickStartCta => 'Ver o meu resumo';

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
    return '$amount de capital a assegurar antes da partida';
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
  String get confidenceDashboardTitle => 'Precisão do teu perfil';

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
      'Cálculo teórico com rendimento constante. Os rendimentos passados não asseguram resultados futuros.';

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
  String get consentFinmaTitle => 'Funcionalidade em preparação';

  @override
  String get consentFinmaDesc =>
      'Consulta regulatória FINMA em curso. Os dados apresentados são de demonstração.';

  @override
  String get consentModeDemo => 'MODE DÉMO';

  @override
  String get consentActiveSection => 'CONSENTIMENTOS ATIVOS';

  @override
  String get consentAutorisations => 'Autorisations';

  @override
  String consentGrantedAtLabel(String date) {
    return 'Concedido a $date';
  }

  @override
  String consentExpiresAtLabel(String date) {
    return 'Expira a $date';
  }

  @override
  String get consentRevokedLabel => 'Consentimento revogado';

  @override
  String get consentNlpdTitle => 'Os teus direitos (nLPD)';

  @override
  String get consentNlpdSubtitle =>
      'Os teus direitos ao abrigo da nLPD (Lei Federal sobre a Proteção de Dados):';

  @override
  String get consentNlpdPoint1 =>
      '• Podes revogar o teu consentimento a qualquer momento';

  @override
  String get consentNlpdPoint2 =>
      '• Os teus dados nunca são partilhados com terceiros';

  @override
  String get consentNlpdPoint3 =>
      '• Acesso apenas de leitura — sem operações financeiras';

  @override
  String get consentNlpdPoint4 =>
      '• Duração máxima do consentimento: 90 dias (renovável)';

  @override
  String get consentStepBanque => 'Banque';

  @override
  String get consentStepAutorisations => 'Autorisations';

  @override
  String get consentStepConfirmation => 'Confirmation';

  @override
  String get consentSelectBankTitle => 'Selecionar um banco';

  @override
  String get consentSelectScopesTitle => 'Selecionar permissões';

  @override
  String consentSelectedBankLabel(String bank) {
    return 'Banco selecionado: $bank';
  }

  @override
  String get consentScopeAccountsDesc => 'Contas (lista das tuas contas)';

  @override
  String get consentScopeBalancesDesc => 'Saldos (saldo atual das tuas contas)';

  @override
  String get consentScopeTransactionsDesc =>
      'Transações (histórico de movimentos)';

  @override
  String get consentReadOnlyInfo =>
      'Acesso apenas de leitura. Não é possível efetuar operações financeiras.';

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
      'Ao confirmar, autorizas a MINT a aceder aos dados selecionados em modo de leitura durante 90 dias. Podes revogar este consentimento a qualquer momento.';

  @override
  String get consentAnnuler => 'Annuler';

  @override
  String get consentScopeComptes => 'Comptes';

  @override
  String get consentScopeSoldes => 'Saldos';

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
      'Esta funcionalidade está em desenvolvimento. Os dados apresentados são exemplos. A ativação do serviço Open Banking está sujeita a consulta regulatória prévia.';

  @override
  String get openBankingHubFinmaTitle => 'Funcionalidade em preparação';

  @override
  String get openBankingHubFinmaDesc =>
      'Consulta regulatória FINMA em curso. Os dados apresentados são de demonstração.';

  @override
  String get openBankingHubSubtitle => 'Conecta as tuas contas bancárias';

  @override
  String get openBankingHubConnectedAccounts => 'CONTAS CONECTADAS';

  @override
  String get openBankingHubApercu => 'PANORAMA FINANCEIRO';

  @override
  String get openBankingHubNavigation => 'NAVEGAÇÃO';

  @override
  String get openBankingHubViewTransactions => 'Ver transações';

  @override
  String get openBankingHubViewTransactionsDesc =>
      'Histórico detalhado por categoria';

  @override
  String get openBankingHubManageConsents => 'Gerir consentimentos';

  @override
  String get openBankingHubManageConsentsDesc =>
      'Direitos nLPD, revogação, permissões';

  @override
  String get openBankingHubSoldeTotal => 'Saldo total';

  @override
  String get openBankingHubComptesConnectes => '3 contas conectadas';

  @override
  String get openBankingHubRevenus => 'Receitas';

  @override
  String get openBankingHubDepenses => 'Despesas';

  @override
  String get openBankingHubEpargneNette => 'Poupança líquida';

  @override
  String get openBankingHubTop3Depenses => 'Top 3 despesas';

  @override
  String get openBankingHubAddBankLabel => 'Adicionar um banco';

  @override
  String openBankingHubSyncMinutes(int minutes) {
    return 'Há $minutes min';
  }

  @override
  String openBankingHubSyncHours(int hours) {
    return 'Há ${hours}h';
  }

  @override
  String openBankingHubSyncDays(int days) {
    return 'Há $days dias';
  }

  @override
  String get transactionListFinmaTitle => 'Funcionalidade em preparação';

  @override
  String get transactionListFinmaDesc =>
      'Consulta regulatória FINMA em curso. Os dados apresentados são de demonstração.';

  @override
  String get transactionListThisMonth => 'Este mês';

  @override
  String get transactionListLastMonth => 'Mês anterior';

  @override
  String get transactionListNoTransaction => 'Sem transações';

  @override
  String get transactionListRevenus => 'Receitas';

  @override
  String get transactionListDepenses => 'Despesas';

  @override
  String get transactionListEpargneNette => 'Poupança líquida';

  @override
  String get transactionListTauxEpargne => 'Taxa de poupança';

  @override
  String get transactionListModeDemo => 'MODO DEMO';

  @override
  String get lppVolontaireRevenuMax250k => 'CHF 250’000';

  @override
  String get lppVolontaireSalaireCoordLabel => 'Salário coordenado';

  @override
  String get lppVolontaireTauxBonifLabel => 'Taxa de bonificação';

  @override
  String get lppVolontaireCotisationLabel => 'Cotisation /an';

  @override
  String get lppVolontaireEconomieFiscaleLabel => 'Poupança fiscal /ano';

  @override
  String get lppVolontaireTrancheAgeLabel => 'Tranche d’âge';

  @override
  String get lppVolontaireCHF0 => 'CHF 0';

  @override
  String get lppVolontaireTaux10 => '10 %';

  @override
  String get lppVolontaireTaux45 => '45 %';

  @override
  String get pillar3aIndepPlafondApplicableLabel => 'Teto aplicável';

  @override
  String get pillar3aIndepEconomieFiscaleAnLabel => 'Poupança fiscal /ano';

  @override
  String get pillar3aIndepPlafondSalarieLabel => 'Teto para assalariado/a';

  @override
  String get pillar3aIndepEconomieSalarieLabel => 'Poupança como assalariado/a';

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
      'Simulação educativa. Não constitui aconselhamento financeiro (LSFin). Hipóteses modificáveis — resultados não assegurados.';

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
  String get mortgageJourneyTitle => 'Percurso compra imobiliária';

  @override
  String get mortgageJourneySubtitle =>
      '7 passos de «posso comprar?» a «assinei!»';

  @override
  String get mortgageJourneyPrevious => 'Anterior';

  @override
  String get mortgageJourneyNextStep => 'Próximo passo';

  @override
  String get mortgageJourneyComplete => '✅ Percurso completo!';

  @override
  String get clause3aTitle => 'A cláusula 3a esquecida';

  @override
  String get clause3aQuestion => 'Depositaste uma cláusula de beneficiário?';

  @override
  String get clause3aStepsTitle => 'Como depositar uma cláusula em 5 minutos:';

  @override
  String clause3aFeedbackOk(String partner) {
    return 'Bem! Verifica que a cláusula nomeia $partner — e que está atualizada após cada evento de vida.';
  }

  @override
  String get clause3aFeedbackNok =>
      'Ação prioritária: deposita a tua cláusula de beneficiário na tua fundação 3a — em 5 minutos.';

  @override
  String get fiscalSuperpowerTitle => 'O superpoder fiscal';

  @override
  String get fiscalSuperpowerSubtitle =>
      'O Estado devolve-te dinheiro por teres um filho.';

  @override
  String get fiscalSuperpowerTaxBenefits => 'As tuas vantagens fiscais';

  @override
  String get babyCostTitle => 'O custo da felicidade';

  @override
  String get babyCostBreakdownTitle => 'Desdobramento mensal';

  @override
  String get lifeEventSheetTitle => 'Está-me a acontecer algo';

  @override
  String get lifeEventSheetSubtitle =>
      'Escolhe um evento para ver o impacto financeiro';

  @override
  String get lifeEventSheetSectionFamille => 'Família';

  @override
  String get lifeEventSheetSectionPro => 'Profissional';

  @override
  String get lifeEventSheetSectionPatrimoine => 'Património';

  @override
  String get lifeEventSheetSectionMobilite => 'Mobilidade';

  @override
  String get lifeEventSheetSectionSante => 'Saúde';

  @override
  String get lifeEventSheetSectionCrise => 'Crise';

  @override
  String get lifeEventLabelMariage => 'Vou casar';

  @override
  String get lifeEventLabelDivorce => 'Vou divorciar';

  @override
  String get lifeEventLabelNaissance => 'Estou à espera de um filho';

  @override
  String get lifeEventLabelConcubinage => 'Vivemos juntos';

  @override
  String get lifeEventLabelDeces => 'Morte de uma pessoa próxima';

  @override
  String get lifeEventLabelPremierEmploi => 'Primeiro emprego';

  @override
  String get lifeEventLabelNouveauJob => 'Novo emprego';

  @override
  String get lifeEventLabelIndependant => 'Fico independente';

  @override
  String get lifeEventLabelPerteEmploi => 'Perda de emprego';

  @override
  String get lifeEventLabelRetraite => 'Vou reformar-me';

  @override
  String get lifeEventLabelAchatImmo => 'Compra imobiliária';

  @override
  String get lifeEventLabelVenteImmo => 'Venda imobiliária';

  @override
  String get lifeEventLabelHeritage => 'Recebo uma herança';

  @override
  String get lifeEventLabelDonation => 'Quero dar aos meus filhos';

  @override
  String get lifeEventLabelDemenagement => 'Mudança de cantão';

  @override
  String get lifeEventLabelExpatriation => 'Vou para o estrangeiro';

  @override
  String get lifeEventLabelInvalidite => 'Estou bem coberto/a?';

  @override
  String get lifeEventLabelDettes => 'Tenho dívidas';

  @override
  String get lifeEventPromptMariage =>
      'Vou casar — que impacto nos meus impostos, AVS e previdência?';

  @override
  String get lifeEventPromptDivorce =>
      'Vou divorciar — o que acontece com o LPP e os impostos?';

  @override
  String get lifeEventPromptNaissance =>
      'Estou à espera de um filho — que apoios e deduções estão disponíveis?';

  @override
  String get lifeEventPromptConcubinage =>
      'Não somos casados — como nos proteger mutuamente?';

  @override
  String get lifeEventPromptDeces =>
      'Morte de uma pessoa próxima — que diligências financeiras preciso de fazer?';

  @override
  String get lifeEventPromptPremierEmploi =>
      'É o meu primeiro emprego — o que preciso saber sobre a previdência e as contribuições?';

  @override
  String get lifeEventPromptNouveauJob =>
      'Mudo de emprego — como comparar ofertas e gerir o meu livre trânsito?';

  @override
  String get lifeEventPromptIndependant =>
      'Fico independente — que opções de previdência sem LPP?';

  @override
  String get lifeEventPromptPerteEmploi =>
      'Perdi o emprego — que subsídios de desemprego e durante quanto tempo?';

  @override
  String get lifeEventPromptRetraite =>
      'Quando me posso reformar e quanto receberei?';

  @override
  String get lifeEventPromptAchatImmo =>
      'Posso comprar um imóvel com o meu rendimento e entrada?';

  @override
  String get lifeEventPromptVenteImmo =>
      'Vendo o meu imóvel — que imposto sobre a mais-valia devo prever?';

  @override
  String get lifeEventPromptHeritage =>
      'Recebo uma herança — quais são as consequências fiscais?';

  @override
  String get lifeEventPromptDonation =>
      'Quero dar aos meus filhos — que impacto fiscal e que limites?';

  @override
  String get lifeEventPromptDemenagement =>
      'Mudo de cantão — que impacto fiscal devo antecipar?';

  @override
  String get lifeEventPromptExpatriation =>
      'Vou para o estrangeiro — o que faço com o AVS, LPP e pilar 3a?';

  @override
  String get lifeEventPromptInvalidite =>
      'Estou bem coberto/a em caso de invalidez ou acidente?';

  @override
  String get lifeEventPromptDettes =>
      'Tenho dívidas — como geri-las sem tocar na minha previdência?';

  @override
  String compoundDisclaimerInflation(String inflation) {
    return 'Pressupostos pedagógicos (inflação $inflation %). O desempenho passado não garante resultados futuros.';
  }

  @override
  String get interactive3aDisclaimer =>
      'Pressupostos pedagógicos. O desempenho passado não garante rendimentos futuros.';

  @override
  String get milestoneContinueBtn => 'Continuar';

  @override
  String get slmAutoPromptTitle => 'Coach IA no teu dispositivo';

  @override
  String get slmAutoPromptBody =>
      'O MINT pode instalar um modelo de IA diretamente no teu telefone para conselhos personalizados — 100 % privado, nenhum dado sai do teu dispositivo.';

  @override
  String get slmAutoInstalledMsg =>
      'Coach IA instalado ! Os teus conselhos serão personalizados.';

  @override
  String get slmInstallBtn => 'Instalar coach IA';

  @override
  String get slmLaterBtn => 'Mais tarde';

  @override
  String get rcDisclaimer =>
      'Ferramenta educativa — não constitui aconselhamento financeiro (LSFin art. 3).';

  @override
  String rcPillar3aTitle(String year) {
    return 'Contribuição 3a $year';
  }

  @override
  String get rcPillar3aSubtitle => 'Poupança fiscal estimada';

  @override
  String rcPillar3aExplanation(String plafond) {
    return 'Poupança fiscal estimada ao contribuir com o máximo de $plafond CHF';
  }

  @override
  String get rcPillar3aCtaLabel => 'Simular o meu 3a';

  @override
  String get rcLppBuybackTitle => 'Recompra LPP';

  @override
  String get rcLppBuybackSubtitle => 'Potencial de recompra disponível';

  @override
  String rcLppBuybackExplanation(String taxSaving, String rachatSimule) {
    return 'Recompra possível. Poupança fiscal estimada de $taxSaving CHF em $rachatSimule CHF';
  }

  @override
  String get rcLppBuybackCtaLabel => 'Simular uma recompra';

  @override
  String get rcReplacementRateTitle => 'Taxa de substituição';

  @override
  String rcReplacementRateSubtitle(String age) {
    return 'Projeção aos $age anos';
  }

  @override
  String rcReplacementRateExplanation(
      String totalMonthly, String currentMonthly) {
    return 'Rendimento estimado na reforma: $totalMonthly CHF/mês vs $currentMonthly CHF/mês atualmente';
  }

  @override
  String get rcReplacementRateCtaLabel => 'Explorar os meus cenários';

  @override
  String get rcReplacementRateAlerte =>
      'Taxa abaixo do limiar recomendado de 60 %. Explora as opções.';

  @override
  String get rcAvsGapTitle => 'Lacuna AVS';

  @override
  String rcAvsGapSubtitle(String lacunes) {
    return '$lacunes anos de contribuição em falta';
  }

  @override
  String get rcAvsGapExplanation =>
      'Redução estimada da tua pensão AVS anual devido a lacunas';

  @override
  String get rcAvsGapCtaLabel => 'Ver o meu extrato AVS';

  @override
  String get rcCoupleAlertTitle => 'Diferença de visibilidade do casal';

  @override
  String rcCoupleAlertSubtitle(String name, String score) {
    return '$name em $score %';
  }

  @override
  String rcCoupleAlertExplanation(String gap) {
    return 'Diferença de $gap pontos entre os dois perfis. Equilibrá-los melhora a projeção do casal.';
  }

  @override
  String get rcCoupleAlertCtaLabel => 'Enriquecer o perfil do casal';

  @override
  String get rcIndependantTitle => 'Previdência independente';

  @override
  String get rcIndependantSubtitle =>
      'Sem LPP, o teu 3a é a tua previdência principal';

  @override
  String rcIndependantExplanation(String max3a, String current3a) {
    return 'Limite 3a sem LPP: $max3a CHF/ano. Capital 3a atual: $current3a CHF';
  }

  @override
  String get rcIndependantCtaLabel => 'Explorar as minhas opções';

  @override
  String get rcTaxOptTitle => 'Otimização fiscal';

  @override
  String get rcTaxOptSubtitle => 'Deduções estimadas disponíveis';

  @override
  String rcTaxOptExplanation(String plafond3a) {
    return 'Poupança fiscal estimada via 3a ($plafond3a CHF) + recompra LPP';
  }

  @override
  String get rcTaxOptCtaLabel => 'Descobrir as minhas deduções';

  @override
  String get rcPatrimoineTitle => 'Património';

  @override
  String get rcPatrimoineSubtitleLow => 'Almofada de segurança insuficiente';

  @override
  String get rcPatrimoineSubtitleOk => 'Visão geral';

  @override
  String rcPatrimoineExplanationLow(String epargne, String coussinMin) {
    return 'Poupança líquida ($epargne CHF) abaixo de 3 meses de despesas ($coussinMin CHF)';
  }

  @override
  String rcPatrimoineExplanationOk(String epargne, String investissements) {
    return 'Poupança $epargne CHF + investimentos $investissements CHF';
  }

  @override
  String get rcPatrimoineCtaLabelLow => 'Analisar o meu orçamento';

  @override
  String get rcPatrimoineCtaLabelOk => 'Ver o meu património';

  @override
  String rcPatrimoineAlerte(String coussinMin) {
    return 'Almofada de segurança recomendada: $coussinMin CHF (3 meses de despesas)';
  }

  @override
  String get rcMortgageTitle => 'Hipoteca';

  @override
  String rcMortgageSubtitle(String ltv) {
    return 'Rácio LTV: $ltv %';
  }

  @override
  String rcMortgageExplanation(String propertyValue) {
    return 'Saldo hipotecário. Valor do imóvel: $propertyValue CHF';
  }

  @override
  String get rcMortgageCtaLabel => 'Simular capacidade';

  @override
  String get rcCtaDetail => 'Ver detalhes →';

  @override
  String get rcLibrePassageTitle => 'Livre passagem';

  @override
  String get rcLibrePassageSubtitle =>
      'O que fazer com o teu capital de livre passagem?';

  @override
  String get rcRenteVsCapitalTitle => 'Renda vs Capital';

  @override
  String get rcRenteVsCapitalSubtitle =>
      'Renda ou capital: calcular ambas as opções';

  @override
  String get rcFiscalComparatorTitle => 'Comparador cantonal';

  @override
  String get rcFiscalComparatorSubtitle =>
      'Quanto ganharías mudando de cantão?';

  @override
  String get rcStaggeredWithdrawalTitle => 'Levantamento 3a escalonado';

  @override
  String get rcStaggeredWithdrawalSubtitle =>
      'Escalonar os levantamentos para reduzir impostos';

  @override
  String get rcRealReturn3aTitle => 'Rendimento real 3a';

  @override
  String get rcRealReturn3aSubtitle =>
      'Rendimento após comissões, inflação e impostos';

  @override
  String get rcComparator3aTitle => 'Comparador 3a';

  @override
  String get rcComparator3aSubtitle => 'Comparar os prestadores de 3a';

  @override
  String get rcRentVsBuyTitle => 'Arrendar ou comprar';

  @override
  String get rcRentVsBuySubtitle => 'Comparar ambos os cenários a longo prazo';

  @override
  String get rcAmortizationTitle => 'Amortização';

  @override
  String get rcAmortizationSubtitle => 'Direta vs indireta — impacto fiscal';

  @override
  String get rcImputedRentalTitle => 'Valor locativo imputado';

  @override
  String get rcImputedRentalSubtitle => 'Compreender a tributação da habitação';

  @override
  String get rcSaronVsFixedTitle => 'SARON vs taxa fixa';

  @override
  String get rcSaronVsFixedSubtitle => 'Qual tipo de hipoteca escolher';

  @override
  String get rcEplTitle => 'Levantamento EPL';

  @override
  String get rcEplSubtitle => 'Usar o 2.º pilar para imóveis';

  @override
  String get rcHousingSaleTitle => 'Venda imobiliária';

  @override
  String get rcHousingSaleSubtitle =>
      'Imposto sobre ganhos imobiliários + reinvestimento';

  @override
  String get rcMariageTitle => 'Impacto do casamento';

  @override
  String get rcMariageSubtitle => 'Impostos, AVS, LPP, sucessão';

  @override
  String get rcDivorceTitle => 'Simulador de divórcio';

  @override
  String get rcDivorceSubtitle => 'Divisão LPP, pensão, impostos';

  @override
  String get rcNaissanceTitle => 'Impacto de um nascimento';

  @override
  String get rcNaissanceSubtitle => 'Abonos, deduções, orçamento';

  @override
  String get rcConcubinageTitle => 'Proteção da união de facto';

  @override
  String get rcConcubinageSubtitle => 'Direitos, riscos e soluções';

  @override
  String get rcSuccessionTitle => 'Sucessão';

  @override
  String get rcSuccessionSubtitle => 'Simular a transferência de património';

  @override
  String get rcDonationTitle => 'Doação';

  @override
  String get rcDonationSubtitle => 'Impacto fiscal de uma doação';

  @override
  String get rcUnemploymentTitle => 'Perda de emprego';

  @override
  String get rcUnemploymentSubtitle => 'Subsídios, duração, diligências';

  @override
  String get rcFirstJobTitle => 'Primeiro emprego';

  @override
  String get rcFirstJobSubtitle => 'Compreender tudo desde o início';

  @override
  String get rcExpatriationTitle => 'Expatriação';

  @override
  String get rcExpatriationSubtitle => 'Impacto no AVS, LPP, 3a e impostos';

  @override
  String get rcFrontalierTitle => 'Trabalhador fronteiriço';

  @override
  String get rcFrontalierSubtitle => 'Imposto na fonte e particularidades';

  @override
  String get rcJobComparisonTitle => 'Comparador de ofertas';

  @override
  String get rcJobComparisonSubtitle =>
      'Líquido + previdência: qual oferta vale realmente mais?';

  @override
  String get rcDividendeVsSalaireTitle => 'Dividendo vs Salário';

  @override
  String get rcDividendeVsSalaireSubtitle =>
      'Otimizar a remuneração em SARL/SA';

  @override
  String get rcLamalFranchiseTitle => 'Franquia LAMal';

  @override
  String get rcLamalFranchiseSubtitle => 'Que franquia escolher?';

  @override
  String get rcCoverageCheckTitle => 'Verificação de cobertura';

  @override
  String get rcCoverageCheckSubtitle => 'Verificar as tuas coberturas';

  @override
  String get rcDisabilityTitle => 'Invalidez — lacuna de rendimento';

  @override
  String get rcDisabilitySubtitle =>
      'Gap entre rendimento atual e rendas AI/LPP';

  @override
  String get rcGenderGapTitle => 'Diferença de género';

  @override
  String get rcGenderGapSubtitle => 'Impacto do part-time na reforma';

  @override
  String get rcBudgetTitle => 'Orçamento';

  @override
  String get rcBudgetSubtitle => 'Quanto te sobra no fim do mês?';

  @override
  String get rcDebtRatioTitle => 'Rácio de endividamento';

  @override
  String get rcDebtRatioSubtitle =>
      'A partir de que limiar as dívidas se tornam perigosas?';

  @override
  String get rcCompoundInterestTitle => 'Juro composto';

  @override
  String get rcCompoundInterestSubtitle =>
      'Simular o crescimento das poupanças';

  @override
  String get rcLeasingTitle => 'Simulador de leasing';

  @override
  String get rcLeasingSubtitle => 'Custo real de um leasing de automóvel';

  @override
  String get rcConsumerCreditTitle => 'Crédito ao consumo';

  @override
  String get rcConsumerCreditSubtitle => 'Custo total de um crédito ao consumo';

  @override
  String get rcAllocationAnnuelleTitle => 'Alocação anual';

  @override
  String get rcAllocationAnnuelleSubtitle =>
      'Onde colocar as poupanças este ano';

  @override
  String get rcSuggestedPrompt50PlusRetirement =>
      'Quando a reforma se torna viável?';

  @override
  String get rcSuggestedPromptRenteOuCapital =>
      'Renda ou capital: o que me dá mais liberdade?';

  @override
  String get rcSuggestedPromptRachatLpp =>
      'Quanto vale uma recompra LPP no meu caso?';

  @override
  String get rcSuggestedPromptAllegerImpots =>
      'Onde reduzir os meus impostos este ano?';

  @override
  String get rcSuggestedPromptVersement3a =>
      'Quanto contribuir para o 3a este ano?';

  @override
  String get nudgeSalaryBody =>
      'Pensaste na tua transferência para o pilar 3a este mês? Cada mês conta para a tua previdência.';

  @override
  String get nudgeTaxDeadlineTitle => 'Declaração fiscal';

  @override
  String get nudgeTaxDeadlineBody =>
      'Verifica o prazo de entrega da declaração fiscal no teu cantão. Reviste as deduções do 3a e da LPP?';

  @override
  String get nudge3aDeadlineTitle => 'Última linha reta para o teu 3a';

  @override
  String nudge3aDeadlineBody(String days, String limit, String year) {
    return 'Faltam $days dia(s) para contribuir até $limit CHF e reduzir os teus impostos de $year.';
  }

  @override
  String get nudgeBirthdayBody =>
      'Um marco que pode marcar a tua planificação previdenciária. Simulaste o impacto deste ano?';

  @override
  String get nudgeProfileTitle => 'O teu perfil merece ser enriquecido';

  @override
  String get nudgeProfileBody =>
      'Quanto mais completo for o teu perfil, mais relevantes são as análises do MINT. Bastam poucos dados.';

  @override
  String get nudgeInactiveTitle => 'Já passou algum tempo !';

  @override
  String get nudgeInactiveBody =>
      'A tua situação financeira evolui todas as semanas. Dedica 2 minutos a verificar o teu painel.';

  @override
  String get nudgeGoalProgressTitle => 'O teu objetivo está a avançar !';

  @override
  String nudgeGoalProgressBody(String progress) {
    return 'Atingiste $progress % do teu objetivo. Continua assim !';
  }

  @override
  String get nudgeAnniversaryBody =>
      'Usas o MINT há um ano. É o momento ideal para atualizar o teu perfil e medir o teu progresso.';

  @override
  String get nudgeLppBuybackTitle => 'Janela de recompra LPP';

  @override
  String nudgeLppBuybackBody(String year) {
    return 'O final de $year aproxima-se: última oportunidade para uma recompra LPP dedutível.';
  }

  @override
  String get nudgeNewYearTitle => 'Novo ano, novo começo !';

  @override
  String nudgeNewYearBody(String year) {
    return '$year: abre-se um novo envelope do pilar 3a. Bom momento para planear as tuas contribuições.';
  }

  @override
  String get rcSuggestedPromptCommencer3a => 'Porquê começar o 3a agora?';

  @override
  String get rcSuggestedPrompt2ePilier =>
      'O que faz concretamente o 2.º pilar?';

  @override
  String get rcSuggestedPromptIndependant =>
      'Independente: o que preciso de reconstruir?';

  @override
  String get rcSuggestedPromptCouple =>
      'Onde falha a nossa previdência de casal?';

  @override
  String get rcSuggestedPromptFatca => 'FATCA: o que muda para o meu 3a?';

  @override
  String get rcUnitPts => 'pts';

  @override
  String get routeSuggestionCta => 'Abrir';

  @override
  String get routeSuggestionPartialWarning => 'Estimativa — dados incompletos';

  @override
  String get routeSuggestionBlocked =>
      'Preciso de mais informações para te levar lá';

  @override
  String get routeReturnAcknowledge =>
      'Bem-vindo de volta! Se ajustaste dados, diz-me e recalculo.';

  @override
  String get routeReturnCompleted =>
      'Anotado. Os teus dados estão atualizados.';

  @override
  String get routeReturnAbandoned => 'Sem problema — voltamos quando quiseres.';

  @override
  String get routeReturnChanged =>
      'Os teus números mudaram. Recalculo a trajetória.';

  @override
  String get hypothesisEditorTitle => 'Hipóteses de simulação';

  @override
  String get hypothesisEditorSubtitle =>
      'Ajusta os parâmetros para ver o impacto nas projeções.';

  @override
  String get lifecyclePhaseDemarrage => 'Início';

  @override
  String get lifecyclePhaseDemarrageDesc =>
      'Primeiros passos na vida profissional: orçamento, 3a e bons hábitos financeiros.';

  @override
  String get lifecyclePhaseConstruction => 'Construção';

  @override
  String get lifecyclePhaseConstructionDesc =>
      'Aceleração de carreira, poupança, primeira habitação, planeamento familiar.';

  @override
  String get lifecyclePhaseAcceleration => 'Aceleração';

  @override
  String get lifecyclePhaseAccelerationDesc =>
      'Fase de rendimentos elevados: otimização LPP, fiscalidade e crescimento patrimonial.';

  @override
  String get lifecyclePhaseConsolidation => 'Consolidação';

  @override
  String get lifecyclePhaseConsolidationDesc =>
      'Preparação para a reforma, recompra LPP, início do planeamento sucessorial.';

  @override
  String get lifecyclePhaseTransition => 'Transição';

  @override
  String get lifecyclePhaseTransitionDesc =>
      'Decisões pré-reforma: renda ou capital, sequência de levantamentos.';

  @override
  String get lifecyclePhaseRetraite => 'Reforma';

  @override
  String get lifecyclePhaseRetraiteDesc =>
      'Vida na reforma: adaptação do orçamento e gestão do património.';

  @override
  String get lifecyclePhaseTransmission => 'Transmissão';

  @override
  String get lifecyclePhaseTransmissionDesc =>
      'Planeamento sucessorial, doações e transmissão do património.';

  @override
  String get challengeWeeklyTitle => 'Desafio da semana';

  @override
  String get challengeCompleted => 'Desafio concluído!';

  @override
  String challengeStreak(int count) {
    return '$count semanas consecutivas';
  }

  @override
  String get challengeBudget01Title =>
      'Verifica as tuas 3 maiores despesas da semana';

  @override
  String get challengeBudget01Desc =>
      'Imagina saber exatamente para onde vai cada franco: abre o teu orçamento e identifica as 3 categorias mais altas desta semana.';

  @override
  String get challengeBudget02Title =>
      'Calcula a tua taxa de poupança mensal real';

  @override
  String get challengeBudget02Desc =>
      'A tua taxa de poupança é o que sobra após todas as despesas. Verifica se supera os 10 % do teu rendimento líquido.';

  @override
  String get challengeBudget03Title =>
      'Compara o custo dos teus seguros com uma oferta alternativa';

  @override
  String get challengeBudget03Desc =>
      'Os prémios de seguro podem variar 30 % consoante o fornecedor. Verifica se poderias poupar ao mudar de caixa.';

  @override
  String get challengeBudget04Title =>
      'Analisa as tuas despesas fixas vs. variáveis';

  @override
  String get challengeBudget04Desc =>
      'Separa os custos fixos (renda, seguros) dos variáveis (saídas, lazer). É a base para otimizar o teu orçamento.';

  @override
  String get challengeBudget05Title => 'Verifica o teu rácio de endividamento';

  @override
  String get challengeBudget05Desc =>
      'O teu rácio de endividamento não deve ultrapassar 33 % do rendimento bruto. Calcula-o para saberes onde estás.';

  @override
  String get challengeBudget06Title => 'Simula o custo real do teu leasing';

  @override
  String get challengeBudget06Desc =>
      'Um leasing é mais do que a mensalidade: seguro, manutenção, valor residual. Calcula o custo total.';

  @override
  String get challengeBudget07Title =>
      'Avalia a tua almofada de segurança em meses';

  @override
  String get challengeBudget07Desc =>
      'Quantos meses conseguirias aguentar sem rendimento? O ideal são 3 a 6 meses de despesas.';

  @override
  String get challengeBudget08Title =>
      'Verifica se poderias reduzir o teu crédito ao consumo';

  @override
  String get challengeBudget08Desc =>
      'Um crédito ao consumo a 8-12 % é muito caro. Vê se podes acelerar o reembolso ou consolicá-lo.';

  @override
  String get challengeEpargne01Title => 'Poupa CHF 50 esta semana';

  @override
  String get challengeEpargne01Desc =>
      'Mesmo um pequeno valor conta: CHF 50 por semana são CHF 2\'600 por ano. O mais difícil é começar.';

  @override
  String get challengeEpargne02Title => 'Verifica o teu saldo 3a face ao teto';

  @override
  String get challengeEpargne02Desc =>
      'O teto 3a para empregados é de CHF 7\'258 por ano. Verifica quanto já depositaste este ano.';

  @override
  String get challengeEpargne03Title => 'Simula uma recompra LPP de CHF 5\'000';

  @override
  String get challengeEpargne03Desc =>
      'Uma recompra LPP é dedutível nos impostos. Simula o impacto de uma recompra de CHF 5\'000 na tua previdência e fiscalidade.';

  @override
  String get challengeEpargne04Title =>
      'Verifica se ainda podes contribuir para o 3a este ano';

  @override
  String get challengeEpargne04Desc =>
      'As contribuições 3a são anuais: se ainda não atingiste o máximo, pode restar tempo.';

  @override
  String get challengeEpargne05Title =>
      'Compara os rendimentos das tuas contas 3a';

  @override
  String get challengeEpargne05Desc =>
      'Nem todas as contas 3a são iguais. Compara os rendimentos das tuas contas com o simulador.';

  @override
  String get challengeEpargne06Title =>
      'Calcula o rendimento real do teu 3a após inflação';

  @override
  String get challengeEpargne06Desc =>
      'Um rendimento de 1 % com inflação de 1,5 % é um rendimento real negativo. Verifica a tua situação.';

  @override
  String get challengeEpargne07Title =>
      'Simula um levantamento faseado das tuas contas 3a';

  @override
  String get challengeEpargne07Desc =>
      'Levantar o 3a ao longo de vários anos pode reduzir os impostos. Simula a estratégia de levantamento faseado.';

  @override
  String get challengeEpargne08Title =>
      'Verifica se podes contribuir retroativamente para o 3a';

  @override
  String get challengeEpargne08Desc =>
      'Desde 2025, podes recuperar anos sem contribuições. Verifica se és elegível para o 3a retroativo.';

  @override
  String get challengeEpargne09Title =>
      'Verifica a tua conta de livre-trânsito se mudaste de empregador';

  @override
  String get challengeEpargne09Desc =>
      'Ao mudar de emprego, o teu capital LPP é transferido para uma conta de livre-trânsito. Verifica que nada foi esquecido.';

  @override
  String get challengePrevoyance01Title =>
      'Solicita o teu extrato de conta AVS';

  @override
  String get challengePrevoyance01Desc =>
      'O teu extrato AVS mostra os teus anos de contribuição e a pensão estimada. Solicita-o gratuitamente em avs.ch.';

  @override
  String get challengePrevoyance02Title =>
      'Verifica a tua cobertura de invalidez';

  @override
  String get challengePrevoyance02Desc =>
      'Em caso de invalidez, a tua pensão AI + LPP cobre as tuas despesas? Verifica a eventual lacuna.';

  @override
  String get challengePrevoyance03Title =>
      'Compara renda vs. capital para o teu LPP';

  @override
  String get challengePrevoyance03Desc =>
      'Renda vitalicia ou capital? Cada opção tem vantagens fiscais e de flexibilidade. Compara os cenários.';

  @override
  String get challengePrevoyance04Title => 'Consulta a tua projeção de reforma';

  @override
  String get challengePrevoyance04Desc =>
      'Imagina a tua reforma: AVS + LPP + 3a — quanto terás realmente? Verifica se estás na trajetória certa.';

  @override
  String get challengePrevoyance05Title =>
      'Otimiza a tua sequência de decumulação';

  @override
  String get challengePrevoyance05Desc =>
      'A ordem em que retiras dos pilares tem um impacto fiscal importante. Simula diferentes sequências.';

  @override
  String get challengePrevoyance06Title => 'Verifica as tuas lacunas AVS';

  @override
  String get challengePrevoyance06Desc =>
      'Cada ano sem contribuições AVS reduz a pensão. Verifica se tens lacunas a colmatar.';

  @override
  String get challengePrevoyance07Title => 'Planeia a tua sucessão';

  @override
  String get challengePrevoyance07Desc =>
      'Quem herda o quê no direito suíço? Verifica as quotas legítimas e se é necessário um testamento.';

  @override
  String get challengePrevoyance08Title =>
      'Verifica a tua cobertura em caso de desemprego';

  @override
  String get challengePrevoyance08Desc =>
      'Perder o emprego é stressante. Saber quanto receberias e durante quanto tempo pode tranquilizar-te. Simula a tua situação.';

  @override
  String get challengePrevoyance09Title =>
      'Verifica a cobertura de invalidez como independente';

  @override
  String get challengePrevoyance09Desc =>
      'Como independente, a tua cobertura AI pode ser insuficiente. Verifica se seria útil um seguro de subsistência diário complementar.';

  @override
  String get challengeFiscalite01Title => 'Estima a tua poupança fiscal do 3a';

  @override
  String get challengeFiscalite01Desc =>
      'Cada franco depositado no 3a é dedutível. Calcula quanto poupes em impostos este ano.';

  @override
  String get challengeFiscalite02Title =>
      'Verifica se uma recompra LPP seria dedutível este ano';

  @override
  String get challengeFiscalite02Desc =>
      'As recompras LPP são dedutíveis do rendimento tributável. Verifica o teu potencial de recompra e a poupança fiscal.';

  @override
  String get challengeFiscalite03Title =>
      'Simula o imposto sobre um levantamento de capital';

  @override
  String get challengeFiscalite03Desc =>
      'Os levantamentos de capital (LPP/3a) são tributados separadamente a uma taxa reduzida. Simula o imposto para diferentes montantes.';

  @override
  String get challengeFiscalite04Title =>
      'Compara salário vs. dividendo se és independente';

  @override
  String get challengeFiscalite04Desc =>
      'O mix salário/dividendo depende do teu rendimento e cantão. Simula ambos os cenários.';

  @override
  String get challengeFiscalite05Title =>
      'Verifica o valor locativo imputado do teu imóvel';

  @override
  String get challengeFiscalite05Desc =>
      'Se és proprietário, o valor locativo imputado é adicionado ao rendimento tributável. Verifica se está correto.';

  @override
  String get challengeFiscalite06Title => 'Calcula a tua carga fiscal total';

  @override
  String get challengeFiscalite06Desc =>
      'Imposto federal + cantonal + municipal: calcula a tua carga fiscal total em percentagem do rendimento.';

  @override
  String get challengeFiscalite07Title => 'Verifica a tua conformidade FATCA';

  @override
  String get challengeFiscalite07Desc =>
      'Como cidadão americano, as tuas contas suíças estão sujeitas a FATCA. Verifica que a tua situação está em ordem.';

  @override
  String get challengeFiscalite08Title => 'Verifica a tua retenção na fonte';

  @override
  String get challengeFiscalite08Desc =>
      'Como trabalhador fronteiriço, pagas impostos na fonte. Verifica se a taxa aplicada corresponde à tua situação.';

  @override
  String get challengePatrimoine01Title =>
      'Calcula a tua capacidade de empréstimo hipotecário';

  @override
  String get challengePatrimoine01Desc =>
      'Com a regra do terço, verifica quanto poderias pedir emprestado para uma compra imobiliária.';

  @override
  String get challengePatrimoine02Title =>
      'Simula SARON vs. taxa fixa para a tua hipoteca';

  @override
  String get challengePatrimoine02Desc =>
      'SARON (variável) ou taxa fixa? Simula ambos os cenários a 10 anos para ver a diferença.';

  @override
  String get challengePatrimoine03Title => 'Compara arrendar vs. comprar';

  @override
  String get challengePatrimoine03Desc =>
      'Comprar nem sempre é melhor do que arrendar. Compara ambas as opções a 20 anos com o simulador.';

  @override
  String get challengePatrimoine04Title =>
      'Simula um levantamento antecipado LPP para habitacao';

  @override
  String get challengePatrimoine04Desc =>
      'Podes usar o 2.º pilar para financiar a tua habitação. Simula o impacto na tua reforma.';

  @override
  String get challengePatrimoine05Title =>
      'Consulta o teu balanço patrimonial completo';

  @override
  String get challengePatrimoine05Desc =>
      'Ativos, passivos, património líquido: faça um balanço da tua situação financeira global. Um momento importante para ganhar perspetiva.';

  @override
  String get challengePatrimoine06Title =>
      'Verifica a tua alocação anual de poupança';

  @override
  String get challengePatrimoine06Desc =>
      'Entre 3a, recompra LPP e amortização hipotecária, como distribuir a poupança este ano? Cada escolha tem um impacto fiscal diferente.';

  @override
  String get challengePatrimoine07Title =>
      'Simula o impacto da amortização hipotecária';

  @override
  String get challengePatrimoine07Desc =>
      'Amortização direta ou indireta via 3a? Simula ambas as opções e o seu impacto fiscal.';

  @override
  String get challengePatrimoine08Title =>
      'Simula o efeito dos juros compostos a 20 anos';

  @override
  String get challengePatrimoine08Desc =>
      'Mesmo um pequeno rendimento cria um efeito bola de neve. Simula o crescimento da tua poupança a 20 anos.';

  @override
  String get challengeEducation01Title => 'Lê o artigo sobre a 13.ª pensão AVS';

  @override
  String get challengeEducation01Desc =>
      'Desde 2026, a 13.ª pensão AVS aumenta a tua pensão anual. Descobre o que muda concretamente para ti.';

  @override
  String get challengeEducation02Title =>
      'Entende a diferença entre a taxa de conversão mínima e a supraobrigatória';

  @override
  String get challengeEducation02Desc =>
      'A taxa de conversão LPP de 6,8 % aplica-se apenas ao mínimo. A tua caixa pode ter uma taxa diferente para a parte supraobrigatória.';

  @override
  String get challengeEducation03Title => 'Descobre como funciona o 1.º pilar';

  @override
  String get challengeEducation03Desc =>
      'O AVS é um sistema de repartio: os ativos financiam os reformados. Entende as bases da tua futura pensão.';

  @override
  String get challengeEducation04Title => 'Entende o sistema de 3 pilares';

  @override
  String get challengeEducation04Desc =>
      'AVS + LPP + 3a: cada pilar tem o seu papel. Entende como se complementam para a tua reforma.';

  @override
  String get challengeEducation05Title =>
      'Explora o conceito de taxa de substituição';

  @override
  String get challengeEducation05Desc =>
      'A taxa de substituição mede a relação entre a tua pensão e o último salário. O objetivo habitual é 60-80 %.';

  @override
  String get challengeEducation06Title =>
      'Entende os bónus LPP por escalao etário';

  @override
  String get challengeEducation06Desc =>
      'Os bónus LPP aumentam com a idade: 7 %, 10 %, 15 %, 18 %. Verifica em que escalao estás.';

  @override
  String get challengeEducation07Title =>
      'Descobre as consequências financeiras da coabitação';

  @override
  String get challengeEducation07Desc =>
      'Em concubinário não tens os mesmos direitos sucessórios que um casal casado. Verifica as proteções necessárias.';

  @override
  String get challengeEducation08Title =>
      'Entende o impacto do gender gap na reforma';

  @override
  String get challengeEducation08Desc =>
      'As mulheres recebem em média 37 % menos de pensão. Entende as causas e as soluções possíveis.';

  @override
  String get challengeArchetypeEu01Title =>
      'Verifica os teus anos de contribuição na UE para o AVS';

  @override
  String get challengeArchetypeEu01Desc =>
      'Graças aos acordos bilaterais, os teus anos cotizados na UE contam para a tua pensão AVS suíça. Pede um certificado E205 para verificar a totalização.';

  @override
  String get challengeArchetypeNonEu01Title =>
      'Verifica se uma convenção de segurança social abrange o teu país';

  @override
  String get challengeArchetypeNonEu01Desc =>
      'Sem acordo bilateral, as tuas contribuições estrangeiras não contam para o AVS. Verifica se o teu país de origem tem um acordo com a Suíça.';

  @override
  String get challengeArchetypeReturning01Title =>
      'Verifica o teu potencial de recompra LPP após regressar à Suíça';

  @override
  String get challengeArchetypeReturning01Desc =>
      'De volta à Suíça após uma estadia no estrangeiro? Podes ter um potencial de recompra LPP importante, dedutível fiscalmente. Simula o montante.';

  @override
  String get voiceMicLabel => 'Falar ao microfone';

  @override
  String get voiceMicListening => 'A ouvir…';

  @override
  String get voiceMicProcessing => 'A processar…';

  @override
  String get voiceSpeakerLabel => 'Ouvir a resposta';

  @override
  String get voiceSpeakerStop => 'Parar a leitura';

  @override
  String get voiceUnavailable =>
      'Funções de voz não disponíveis neste dispositivo';

  @override
  String get voicePermissionNeeded =>
      'Permite o acesso ao microfone para usar a voz';

  @override
  String get voiceNoSpeech => 'Não ouvi nada. Tenta de novo.';

  @override
  String get voiceError => 'Erro de voz. Usa o teclado.';

  @override
  String get benchmarkTitle => 'Perfis semelhantes no teu cantão';

  @override
  String get benchmarkSubtitle => 'Dados agregados e anonimizados (OFS)';

  @override
  String get benchmarkOptInBody =>
      'Compara a tua situação com as medianas do teu cantão. Dados anonimizados, nunca um ranking.';

  @override
  String get benchmarkOptInButton => 'Ativar';

  @override
  String get benchmarkOptOutButton => 'Desativar';

  @override
  String get benchmarkDisclaimer =>
      'Dados agregados OFS — ferramenta educativa, não um ranking. Não constitui aconselhamento (LSFin art. 3).';

  @override
  String benchmarkInsightIncome(String canton, String amount) {
    return 'O rendimento mediano no cantão de $canton é de CHF $amount/ano';
  }

  @override
  String benchmarkInsightSavings(String rate) {
    return 'Um perfil semelhante poupa cerca de $rate% do seu rendimento';
  }

  @override
  String benchmarkInsightTax(String canton, String level) {
    return 'A carga fiscal em $canton é $level em relação à média suíça';
  }

  @override
  String benchmarkInsightHousing(String amount) {
    return 'A renda mediana para um apartamento de 4 quartos é CHF $amount/mês';
  }

  @override
  String benchmarkInsight3a(String rate) {
    return 'Cerca de $rate% dos trabalhadores contribuem para o 3.º pilar';
  }

  @override
  String benchmarkInsightLpp(String rate) {
    return 'A taxa de cobertura LPP é de $rate%';
  }

  @override
  String get benchmarkTaxLevelBelow => 'inferior';

  @override
  String get benchmarkTaxLevelAverage => 'comparável';

  @override
  String get benchmarkTaxLevelAbove => 'superior';

  @override
  String get benchmarkNoDataCanton => 'Dados não disponíveis para este cantão';

  @override
  String get llmFailoverActive => 'Failover automático ativado';

  @override
  String get llmProviderClaude => 'Claude (Anthropic)';

  @override
  String get llmProviderOpenai => 'GPT-4o (OpenAI)';

  @override
  String get llmProviderMistral => 'Mistral';

  @override
  String get llmProviderLocal => 'Modelo local';

  @override
  String get llmCircuitOpen => 'Serviço temporariamente indisponível';

  @override
  String get llmAllProvidersDown =>
      'Todos os serviços de IA estão indisponíveis. Modo offline ativado.';

  @override
  String get llmQualityGood => 'Qualidade da resposta: boa';

  @override
  String get llmQualityDegraded => 'Qualidade da resposta: degradada';

  @override
  String get gamificationCommunityTitle => 'Desafio do mês';

  @override
  String get gamificationSeasonalTitle => 'Eventos sazonais';

  @override
  String get gamificationMilestonesTitle => 'As tuas conquistas';

  @override
  String get gamificationOptInPrompt => 'Participar nos desafios da comunidade';

  @override
  String get communityChallenge01Title =>
      'Prepara a tua declaração de impostos';

  @override
  String get communityChallenge01Desc =>
      'Janeiro é o momento certo para reunir os teus documentos fiscais. Contacta o teu cantão para saber o prazo e os documentos necessários.';

  @override
  String get communityChallenge02Title => 'Identifica as tuas deduções fiscais';

  @override
  String get communityChallenge02Desc =>
      'Despesas profissionais, juros hipotecários, doações : lista todas as deduções a que tens direito antes de submeter a tua declaração.';

  @override
  String get communityChallenge03Title =>
      'Verifica a tua contribuição para o 3.º pilar antes do prazo';

  @override
  String get communityChallenge03Desc =>
      'Alguns cantões permitem completar a contribuição do ano anterior para o pilar 3a até março. Verifica as regras do teu cantão.';

  @override
  String get communityChallenge04Title =>
      'Consulta o teu certificado de previdência LPP';

  @override
  String get communityChallenge04Desc =>
      'O teu certificado anual LPP chegou. Dedica 10 minutos a compreender o teu capital, a taxa de conversão e o potencial de recompra.';

  @override
  String get communityChallenge05Title => 'Simula uma recompra LPP';

  @override
  String get communityChallenge05Desc =>
      'Uma recompra LPP melhora a tua reforma E reduz os teus impostos. Calcula quanto poderias recomprar e o impacto fiscal no teu cantão.';

  @override
  String get communityChallenge06Title => 'Faz a tua revisão semestral';

  @override
  String get communityChallenge06Desc =>
      'Passaram 6 meses : revê os teus objetivos financeiros, verifica se estás no caminho certo e ajusta se necessário.';

  @override
  String get communityChallenge07Title =>
      'Define o teu objetivo de poupança estival';

  @override
  String get communityChallenge07Desc =>
      'O verão pode afetar o teu orçamento. Define um objetivo de poupança para julho e acompanha o teu progresso até ao final de agosto.';

  @override
  String get communityChallenge08Title =>
      'Constitui ou reforça o teu fundo de emergência';

  @override
  String get communityChallenge08Desc =>
      'Um fundo de emergência de 3 a 6 meses de despesas fixas protege-te dos imprevistos. Verifica onde estás e planeia as contribuições em falta.';

  @override
  String get communityChallenge09Title =>
      'Programa a tua contribuição de outono para o 3.º pilar';

  @override
  String get communityChallenge09Desc =>
      'Setembro é ideal para programar a próxima contribuição para o pilar 3a. Distribuir as contribuições ao longo do ano reduz o stress do prazo de dezembro.';

  @override
  String get communityChallenge10Title => 'Celebra o mês da previdência';

  @override
  String get communityChallenge10Desc =>
      'Outubro é o mês oficial da previdência na Suíça. Consulta a tua projeção de reforma e identifica uma ação concreta para melhorar a tua situação.';

  @override
  String get communityChallenge11Title =>
      'Planeia as tuas últimas otimizações de fim de ano';

  @override
  String get communityChallenge11Desc =>
      'Restam poucas semanas para agir: contribuição 3a, doação, declaração de despesas. Identifica o que ainda podes fazer antes de 31 de dezembro.';

  @override
  String get communityChallenge12Title =>
      'Faz a tua contribuição para o 3.º pilar antes de 31 de dezembro';

  @override
  String get communityChallenge12Desc =>
      'O prazo do 3a aproxima-se. Contribui até CHF 7’258 (trabalhador por conta de outrem com LPP) antes de 31 de dezembro para beneficiar da dedução fiscal deste ano.';

  @override
  String get seasonalTaxSeasonTitle => 'Época fiscal';

  @override
  String get seasonalTaxSeasonDesc =>
      'Fevereiro–março: é o momento de preparar a tua declaração de impostos. Reúne os teus justificativos e identifica as tuas deduções.';

  @override
  String get seasonal3aCountdownTitle => 'Contagem decrescente 3.º pilar';

  @override
  String get seasonal3aCountdownDesc =>
      'O prazo de 31 de dezembro para contribuições ao pilar 3a está a aproximar-se. Verifica o teu saldo e planeia a contribuição para maximizar a dedução fiscal.';

  @override
  String get seasonalNewYearResolutionsTitle => 'Resoluções financeiras';

  @override
  String get seasonalNewYearResolutionsDesc =>
      'Novo ano, novos objetivos financeiros. Define 1 ou 2 ações concretas que vais implementar este ano.';

  @override
  String get seasonalMidYearReviewTitle => 'Revisão semestral';

  @override
  String get seasonalMidYearReviewDesc =>
      'Atingiste a marca dos 6 meses. Toma um momento para verificar o teu progresso em direção aos objetivos e ajustar se necessário.';

  @override
  String get seasonalRetirementMonthTitle => 'Mês da previdência';

  @override
  String get seasonalRetirementMonthDesc =>
      'Outubro é o mês nacional da previdência na Suíça. É o momento de verificar a tua projeção de reforma e a tua taxa de substituição.';

  @override
  String get milestoneEngagementFirstWeekTitle => 'Primeira semana';

  @override
  String get milestoneEngagementFirstWeekDesc =>
      'Usas o MINT há 7 dias. Construir hábitos começa aqui.';

  @override
  String get milestoneEngagementOneMonthTitle => 'Um mês fiel';

  @override
  String get milestoneEngagementOneMonthDesc =>
      '30 dias com MINT. A tua curiosidade financeira está presente.';

  @override
  String get milestoneEngagementCitoyenTitle => 'Cidadão MINT';

  @override
  String get milestoneEngagementCitoyenDesc =>
      '90 dias: fazes parte das pessoas que tomam o seu futuro financeiro nas próprias mãos.';

  @override
  String get milestoneEngagementFideleTitle => 'Fiel 6 meses';

  @override
  String get milestoneEngagementFideleDesc =>
      '180 dias de acompanhamento financeiro. A tua regularidade constrói uma visão clara da tua situação.';

  @override
  String get milestoneEngagementVeteranTitle => 'Veterano MINT';

  @override
  String get milestoneEngagementVeteranDesc =>
      '365 dias com MINT. Um ano completo de consciência financeira.';

  @override
  String get milestoneKnowledgeCurieuxTitle => 'Curioso';

  @override
  String get milestoneKnowledgeCurieuxDesc =>
      'Exploraste 5 conceitos financeiros. O conhecimento é o ponto de partida de cada decisão informada.';

  @override
  String get milestoneKnowledgeEclaireTitle => 'Informado';

  @override
  String get milestoneKnowledgeEclaireDesc =>
      '20 conceitos lidos. Estás a construir uma sólida compreensão do sistema financeiro suíço.';

  @override
  String get milestoneKnowledgeExpertTitle => 'Especialista';

  @override
  String get milestoneKnowledgeExpertDesc =>
      '50 conceitos explorados. Dominas os fundamentos da previdência suíça.';

  @override
  String get milestoneKnowledgeStrategisteTitle => 'Estratega';

  @override
  String get milestoneKnowledgeStrategisteDesc =>
      '100 conceitos. Tens uma visão estratégica a longo prazo das tuas finanças.';

  @override
  String get milestoneKnowledgeMaitreTitle => 'Mestre';

  @override
  String get milestoneKnowledgeMaitreDesc =>
      '200 conceitos lidos. A tua cultura financeira é um ativo concreto para as tuas decisões de vida.';

  @override
  String get milestoneActionPremierPasTitle => 'Primeiro passo';

  @override
  String get milestoneActionPremierPasDesc =>
      'Realizaste a tua primeira ação financeira concreta. Cada grande mudança começa por um primeiro passo.';

  @override
  String get milestoneActionActeurTitle => 'Ator';

  @override
  String get milestoneActionActeurDesc =>
      '5 ações financeiras realizadas. Passas da reflexão à ação.';

  @override
  String get milestoneActionMaitreDestinTitle => 'Dono do teu destino';

  @override
  String get milestoneActionMaitreDestinDesc =>
      '20 ações concretas. Geres ativamente a tua situação financeira.';

  @override
  String get milestoneActionBatisseurTitle => 'Construtor';

  @override
  String get milestoneActionBatisseurDesc =>
      '50 ações financeiras. Constróis pacientemente uma base sólida.';

  @override
  String get milestoneActionArchitecteTitle => 'Arquiteto';

  @override
  String get milestoneActionArchitecteDesc =>
      '100 ações. És o arquiteto da tua liberdade financeira.';

  @override
  String get milestoneConsistencyFlammeNaissanteTitle => 'Chama nascente';

  @override
  String get milestoneConsistencyFlammeNaissanteDesc =>
      '2 semanas consecutivas. A tua regularidade está a tomar forma.';

  @override
  String get milestoneConsistencyFlammeViveTitle => 'Chama viva';

  @override
  String get milestoneConsistencyFlammeViveDesc =>
      '4 semanas sem interrupção. A tua disciplina financeira está em marcha.';

  @override
  String get milestoneConsistencyFlammeEtermelleTitle => 'Chama eterna';

  @override
  String get milestoneConsistencyFlammeEtermelleDesc =>
      '12 semanas consecutivas. A tua constância tornou-se um hábito.';

  @override
  String get milestoneConsistencyConfianceTitle => 'Perfil de confiança';

  @override
  String get milestoneConsistencyConfianceDesc =>
      'O teu perfil atingiu um nível de confiança de 70 %. Os teus dados permitem cálculos fiáveis.';

  @override
  String get milestoneConsistencyChallengesTitle => '6 desafios concluídos';

  @override
  String get milestoneConsistencyChallengesDesc =>
      'Completaste 6 desafios mensais. Seis meses de compromisso financeiro concreto.';

  @override
  String get rcSalaryLabel => 'O teu rendimento';

  @override
  String get rcAgeLabel => 'A tua idade';

  @override
  String get rcCantonLabel => 'O teu cantão';

  @override
  String get rcCivilStatusLabel => 'O teu estado civil';

  @override
  String get rcEmploymentStatusLabel => 'O teu estatuto profissional';

  @override
  String get rcLppLabel => 'Os teus dados LPP';

  @override
  String get expertTitle => 'Consultar um·a especialista';

  @override
  String get expertSubtitle =>
      'MINT prepara o teu dossier para uma consulta eficiente';

  @override
  String get expertDisclaimer =>
      'MINT facilita a ligação — não substitui aconselhamento personalizado (LSFin art. 3)';

  @override
  String get expertSpecRetirement => 'Reforma';

  @override
  String get expertSpecSuccession => 'Sucessão';

  @override
  String get expertSpecExpatriation => 'Expatriação';

  @override
  String get expertSpecDivorce => 'Divórcio';

  @override
  String get expertSpecSelfEmployment => 'Independente';

  @override
  String get expertSpecRealEstate => 'Imobiliário';

  @override
  String get expertSpecTax => 'Fiscalidade';

  @override
  String get expertSpecDebt => 'Gestão de dívidas';

  @override
  String get expertDossierTitle => 'O teu dossier preparado';

  @override
  String expertDossierIncomplete(int count) {
    return 'Perfil incompleto — $count dados em falta';
  }

  @override
  String get expertRequestSession => 'Solicitar uma consulta';

  @override
  String get expertSessionRequested => 'Pedido enviado';

  @override
  String get expertMissingData =>
      'Valor estimado — a confirmar com o·a especialista';

  @override
  String get expertDossierSectionSituation => 'Situação pessoal';

  @override
  String get expertDossierSectionPrevoyance => 'Previdência';

  @override
  String get expertDossierSectionPatrimoine => 'Património';

  @override
  String get expertDossierSectionFinancement => 'Financiamento';

  @override
  String get expertDossierSectionDeductions => 'Deduções fiscais';

  @override
  String get expertDossierSectionBudget => 'Orçamento e dívidas';

  @override
  String get expertItemAge => 'Idade';

  @override
  String get expertItemSalaryRange => 'Rendimento bruto anual';

  @override
  String get expertItemCoupleStatus => 'Situação familiar';

  @override
  String get expertItemConjointAge => 'Idade do·a cônjuge';

  @override
  String get expertItemLppBalance => 'Saldo LPP';

  @override
  String get expertItem3aStatus => 'Pilar 3a';

  @override
  String get expertItem3aBalance => 'Capital 3a';

  @override
  String get expertItemLppBuybackPotential => 'Resgate LPP possível';

  @override
  String get expertItemAvsYears => 'Anos de contribuição AVS';

  @override
  String get expertItemReplacementRate => 'Taxa de substituição estimada';

  @override
  String get expertItemFamilyStatus => 'Estado civil';

  @override
  String get expertItemChildren => 'Filhos';

  @override
  String get expertItemPatrimoineRange => 'Património estimado';

  @override
  String get expertItemPropertyStatus => 'Habitação';

  @override
  String get expertItemPropertyValue => 'Valor imobiliário';

  @override
  String get expertItemNationality => 'Nacionalidade';

  @override
  String get expertItemArchetype => 'Perfil fiscal';

  @override
  String get expertItemYearsInCh => 'Anos na Suíça';

  @override
  String get expertItemResidencePermit => 'Autorização de residência';

  @override
  String get expertItemAvsStatus => 'Estado AVS';

  @override
  String get expertItemAvsGaps => 'Lacunas AVS';

  @override
  String get expertItemCivilStatus => 'Estado civil';

  @override
  String get expertItemConjointLpp => 'LPP do·a cônjuge';

  @override
  String get expertItemEmploymentStatus => 'Situação profissional';

  @override
  String get expertItemLppCoverage => 'Cobertura LPP';

  @override
  String get expertItemCanton => 'Cantão';

  @override
  String get expertItemCurrentHousing => 'Habitação atual';

  @override
  String get expertItemEquityEstimate => 'Fundos próprios disponíveis';

  @override
  String get expertItemLppEpl => 'EPL possível';

  @override
  String get expertItemMortgageBalance => 'Hipoteca em curso';

  @override
  String get expertItemDebtRatio => 'Rácio de endividamento';

  @override
  String get expertItemChargesVsIncome => 'Encargos vs rendimento';

  @override
  String get expertItemDebtType => 'Tipos de dívida';

  @override
  String get expertValueUnknown => 'Não indicado';

  @override
  String get expertValueNone => 'Nenhum·a';

  @override
  String get expertValueOwner => 'Proprietário·a';

  @override
  String get expertValueTenant => 'Inquilino·a';

  @override
  String get expertValueSingle => 'Solteiro·a';

  @override
  String get expertValueMarried => 'Casado·a';

  @override
  String get expertValueDivorced => 'Divorciado·a';

  @override
  String get expertValueWidowed => 'Viúvo·a';

  @override
  String get expertValueConcubinage => 'Em coabitação';

  @override
  String get expertValue3aActive => 'Ativo';

  @override
  String get expertValue3aInactive => 'Inativo';

  @override
  String get expertValueLppYes => 'Coberto·a';

  @override
  String get expertValueLppNo => 'Não coberto·a';

  @override
  String get expertValueLppEplPossible => 'Possível (a verificar)';

  @override
  String get expertValueDebtNone => 'Sem dívidas';

  @override
  String get expertValueDebtLow => 'Baixo (< 50 % do rendimento anual)';

  @override
  String get expertValueDebtMedium => 'Moderado (50–100 % do rendimento anual)';

  @override
  String get expertValueDebtHigh => 'Alto (> 100 % do rendimento anual)';

  @override
  String get expertValueChargesNone => 'Sem encargos de dívida';

  @override
  String get expertValueSalarie => 'Assalariado·a';

  @override
  String get expertValueIndependant => 'Independente';

  @override
  String get expertValueChomage => 'Desempregado·a';

  @override
  String get expertValueRetraite => 'Reformado·a';

  @override
  String get expertDebtTypeConso => 'Crédito ao consumo';

  @override
  String get expertDebtTypeLeasing => 'Leasing';

  @override
  String get expertDebtTypeHypo => 'Hipoteca';

  @override
  String get expertDebtTypeAutre => 'Outras dívidas';

  @override
  String get expertArchetypeSwissNative => 'Residente suíço·a';

  @override
  String get expertArchetypeExpatEu => 'Expat UE/EFTA';

  @override
  String get expertArchetypeExpatNonEu => 'Expat não-UE';

  @override
  String get expertArchetypeExpatUs => 'Residente US (FATCA)';

  @override
  String get expertArchetypeIndepWithLpp => 'Independente com LPP';

  @override
  String get expertArchetypeIndepNoLpp => 'Independente sem LPP';

  @override
  String get expertArchetypeCrossBorder => 'Trabalhador·a fronteiriço·a';

  @override
  String get expertArchetypeReturningSwiss => 'Suíço·a de regresso';

  @override
  String get expertMissingLppBalance => 'Saldo LPP não indicado';

  @override
  String get expertMissingAvsYears => 'Anos AVS não indicados';

  @override
  String get expertMissingLppBuyback => 'Lacuna de resgate LPP desconhecida';

  @override
  String get expertMissing3a => 'Capital 3a não indicado';

  @override
  String get expertMissingConjoint => 'Dados do·a cônjuge em falta';

  @override
  String get expertMissingPatrimoine => 'Património não indicado';

  @override
  String get expertMissingHousing => 'Situação habitacional desconhecida';

  @override
  String get expertMissingChildren => 'Número de filhos não indicado';

  @override
  String get expertMissingNationality => 'Nacionalidade não indicada';

  @override
  String get expertMissingArrivalAge => 'Idade de chegada à Suíça não indicada';

  @override
  String get expertMissingPermit => 'Autorização de residência não indicada';

  @override
  String get expertMissingConjointLpp => 'LPP do·a cônjuge não indicada';

  @override
  String get expertMissingIndependantStatus =>
      'Estatuto de independente não confirmado';

  @override
  String get expertMissingLppCoverage => 'Cobertura LPP não indicada';

  @override
  String get expertMissingCanton => 'Cantão não indicado';

  @override
  String get expertMissingEquity => 'Fundos próprios não indicados';

  @override
  String get expertMissingHousingStatus => 'Estado habitacional não indicado';

  @override
  String get expertMissingDebtDetail => 'Detalhe de dívidas em falta';

  @override
  String get expertMissingMensualites =>
      'Prestações mensais de dívidas não indicadas';

  @override
  String get agentFormTitle => 'Formulário pré-preenchido';

  @override
  String get agentFormDisclaimer =>
      'Verifica cada campo antes de enviar. MINT não submete nada em teu nome.';

  @override
  String get agentFormValidateAll => 'Confirmo que verifiquei';

  @override
  String get agentFormEstimated => 'Estimado — a confirmar';

  @override
  String get agentLetterTitle => 'Carta preparada';

  @override
  String get agentLetterDisclaimer =>
      'Adapta e envia tu mesmo. MINT não transmite nada.';

  @override
  String get agentLetterPensionSubject => 'Pedido de extrato de previdência';

  @override
  String get agentLetterTransferSubject =>
      'Pedido de transferência de livre passagem';

  @override
  String get agentLetterAvsSubject => 'Pedido de extrato de conta AVS';

  @override
  String get agentLetterPlaceholderName => '[O teu nome completo]';

  @override
  String get agentLetterPlaceholderAddress => '[O teu endereço]';

  @override
  String get agentLetterPlaceholderSsn => '[O teu número AVS]';

  @override
  String get agentLetterPlaceholderDate => '[Data]';

  @override
  String get agentTaxFormTitle => 'Declaração fiscal — pré-preenchimento';

  @override
  String get agent3aFormTitle => 'Certificado 3.º pilar';

  @override
  String get agentLppFormTitle => 'Formulário de resgate LPP';

  @override
  String agentFieldSource(String source) {
    return 'Fonte : $source';
  }

  @override
  String get agentValidationRequired =>
      'Validação necessária antes de qualquer utilização';

  @override
  String get agentOutputDisclaimer =>
      'Ferramenta educativa — não constitui conselho financeiro, fiscal ou jurídico. Verifica cada informação. Em conformidade com LSFin.';

  @override
  String get agentNoAction =>
      'MINT não submete, transmite nem executa nada automaticamente.';

  @override
  String get agentSpecialistLabel => 'um·a especialista habilitado·a';

  @override
  String get agentLppBuybackTitle => 'Pedido de resgate LPP';

  @override
  String get agentPensionFundSubject => 'Pedido de certificado de previdência';

  @override
  String get agentLppTransferSubject =>
      'Pedido de transferência de previdência (livre passagem)';

  @override
  String get agentFormCantonFallback => '[cantão]';

  @override
  String get agentFormRevenuBrut => 'Rendimento bruto estimado';

  @override
  String get agentFormCanton => 'Cantão de residência';

  @override
  String get agentFormSituationFamiliale => 'Situação familiar';

  @override
  String get agentFormNbEnfants => 'Número de filhos';

  @override
  String get agentFormDeduction3a => 'Dedução 3a possível';

  @override
  String get agentFormRachatLppDeductible => 'Resgate LPP dedutível estimado';

  @override
  String get agentFormStatutProfessionnel => 'Situação profissional';

  @override
  String get agentFormBeneficiaireNom => 'Nome do/da beneficiário·a';

  @override
  String get agentFormNumeroCompte3a => 'Número de conta 3a';

  @override
  String agentFormMontantVersement(String plafond, String year) {
    return '~$plafond CHF (limite $year)';
  }

  @override
  String get agentFormMontantVersementLabel => 'Montante do pagamento anual';

  @override
  String get agentFormTypeContrat => 'Tipo de contrato';

  @override
  String get agentFormTypeContratSalarie => 'Trabalhador·a com LPP';

  @override
  String get agentFormTypeContratIndependant => 'Independente sem LPP';

  @override
  String get agentFormToComplete => '[A completar]';

  @override
  String get agentFormTitulaireNom => 'Nome do/da titular';

  @override
  String get agentFormNumeroPolice => 'Número de apólice';

  @override
  String get agentFormAvoirLpp => 'Ter LPP atual';

  @override
  String get agentFormRachatMax => 'Resgate máximo disponível';

  @override
  String get agentFormRachatsDeja => 'Resgates já efetuados';

  @override
  String get agentFormMontantRachatSouhaite => 'Montante do resgate pretendido';

  @override
  String get agentFormToCompleteAupres => '[A completar junto da caixa]';

  @override
  String agentFormToCompleteMax(String max) {
    return '[A preencher — máx. $max CHF]';
  }

  @override
  String get agentFormCivilCelibataire => 'Solteiro·a';

  @override
  String get agentFormCivilMarie => 'Casado·a';

  @override
  String get agentFormCivilDivorce => 'Divorciado·a';

  @override
  String get agentFormCivilVeuf => 'Viúvo·a';

  @override
  String get agentFormCivilConcubinage => 'União de facto';

  @override
  String get agentFormEmplSalarie => 'Trabalhador·a por conta de outrem';

  @override
  String get agentFormEmplIndependant => 'Trabalhador·a independente';

  @override
  String get agentFormEmplChomage => 'À procura de emprego';

  @override
  String get agentFormEmplRetraite => 'Reformado·a';

  @override
  String get agentLetterCaisseFallback => '[Nome da caixa de pensões]';

  @override
  String get agentLetterPostalCity => '[Código postal e cidade]';

  @override
  String get agentLetterCaisseAddress => '[Endereço da caixa]';

  @override
  String get agentLetterPoliceNumber => '[Número de apólice : A completar]';

  @override
  String get agentLetterCaisseCurrentName => '[Caixa de pensões atual]';

  @override
  String get agentLetterCaisseCurrentAddress => '[Endereço da caixa atual]';

  @override
  String get agentLetterToComplete => '[A completar]';

  @override
  String get agentLetterAvsOrg => 'Caixa de compensação AVS competente';

  @override
  String get agentLetterAvsAddress => '[Endereço]';

  @override
  String agentLetterPensionFundBody(
      String name,
      String address,
      String postalCity,
      String caisse,
      String caisseAddress,
      String date,
      String dateFormatted,
      String subject,
      String year,
      String policeNumber) {
    return '$name\n$address\n$postalCity\n\n$caisse\n$caisseAddress\n$postalCity\n\n$date, $dateFormatted\n\nAssunto: $subject\n\nExmo./Exma. Senhor/a,\n\nVenho por este meio submeter os seguintes pedidos relativos ao meu processo de previdência profissional:\n\n1. Certificado de previdência atualizado $year (ter de velhice, prestações cobertas, taxa de conversão aplicável)\n\n2. Confirmação da minha capacidade de resgate (montante máximo nos termos do art. 79b LPP)\n\n3. Simulação de reforma antecipada (projeção do ter e da renda aos 63 e 64 anos, se aplicável)\n\nAgradeço antecipadamente a vossa diligência e fico à disposição para qualquer informação adicional.\n\nCom os melhores cumprimentos,\n\n$name\n$policeNumber';
  }

  @override
  String agentLetterLppTransferBody(
      String name,
      String address,
      String postalCity,
      String caisseSource,
      String caisseCurrentAddress,
      String date,
      String dateFormatted,
      String subject,
      String toComplete) {
    return '$name\n$address\n$postalCity\n\n$caisseSource\n$caisseCurrentAddress\n$postalCity\n\n$date, $dateFormatted\n\nAssunto: $subject\n\nExmo./Exma. Senhor/a,\n\nEm virtude da cessação do meu contrato de trabalho / da minha saída da Suíça (riscar o que não se aplica), solicito que procedam à transferência do meu ter de livre passagem.\n\nMontante a transferir: a totalidade do ter de livre passagem à data de saída.\n\nInstituição de destino:\nNome: $toComplete\nIBAN ou número de conta: $toComplete\nEndereço: $toComplete\n\nData de saída: $toComplete\n\nAgradeço a vossa diligência e solicito confirmação da boa execução desta transferência.\n\nCom os melhores cumprimentos,\n\n$name';
  }

  @override
  String agentLetterAvsExtractBody(
      String name,
      String ssn,
      String address,
      String postalCity,
      String avsOrg,
      String avsAddress,
      String date,
      String dateFormatted,
      String subject) {
    return '$name\n$ssn\n$address\n$postalCity\n\n$avsOrg\n$avsAddress\n$postalCity\n\n$date, $dateFormatted\n\nAssunto: $subject\n\nExmo./Exma. Senhor/a,\n\nSolicito que me enviem um extrato da minha conta individual AVS (CI) para verificar o estado das minhas contribuições e identificar eventuais lacunas.\n\nAgradeço antecipadamente a vossa diligência.\n\nCom os melhores cumprimentos,\n\n$name';
  }

  @override
  String get seasonalEventCta => 'Falar com o coach';

  @override
  String get communityChallengeCta => 'Aceitar o desafio';

  @override
  String get dossierExpertSectionTitle => 'Consultar um·a especialista';

  @override
  String get expertPrepareDossierCta => 'Preparar o meu dossier';

  @override
  String get dossierAgentSectionTitle => 'Documentos preparados';

  @override
  String get agentFormsTaxCta => 'Preparar a minha declaração';

  @override
  String get agentFormsTaxSubtitle => 'Pré-preenchido a partir do teu perfil';

  @override
  String get agentFormsAvsCta => 'Solicitar o meu extrato AVS';

  @override
  String get agentFormsAvsSubtitle => 'Modelo de carta pronto a enviar';

  @override
  String get agentFormsLppCta => 'Solicitar transferência LPP';

  @override
  String get agentFormsLppSubtitle =>
      'Carta de transferência de livre passagem';

  @override
  String get notifThreeATitle => 'Prazo 3a';

  @override
  String get notifThreeA92Days => 'Restam 92 dias para depositar no teu 3a.';

  @override
  String notifThreeA61Days(String saving) {
    return 'Restam 61 dias. Poupança estimada: CHF $saving.';
  }

  @override
  String notifThreeALastMonth(String saving) {
    return 'Último mês para o teu 3a. CHF $saving de poupança em jogo.';
  }

  @override
  String get notifThreeA11Days => '11 dias. Último lembrete 3a.';

  @override
  String notifNewYearTitle(String year) {
    return 'Novos limites $year';
  }

  @override
  String notifNewYearBody(String year) {
    return 'Novos limites $year. A tua poupança potencial mudou.';
  }

  @override
  String get notifCheckInTitle => 'Check-in mensal';

  @override
  String get notifCheckInBody => 'O teu check-in mensal está disponível.';

  @override
  String get notifTaxTitle => 'Declaração fiscal';

  @override
  String get notifTax44Days =>
      'Declaração fiscal em 44 dias. Começa a reunir os teus documentos.';

  @override
  String get notifTax16Days =>
      'Declaração fiscal em 16 dias. Começa a preenchê-la.';

  @override
  String get notifTaxLastWeek =>
      'Declaração antes de 31 de março. Última semana.';

  @override
  String get notifFriTitle => 'Pontuação de solidez';

  @override
  String notifFriCheckIn(String delta) {
    return 'Desde o teu último check-in: $delta pontos.';
  }

  @override
  String notifFriImproved(String delta) {
    return 'A tua solidez melhorou $delta pontos.';
  }

  @override
  String get notifProfileUpdatedTitle => 'Perfil atualizado';

  @override
  String get notifProfileUpdatedBody =>
      'O teu perfil foi atualizado. Novas projeções disponíveis.';

  @override
  String get notifOffTrackTitle => 'Estás a afastar-te do teu plano';

  @override
  String notifOffTrackBody(String adherence, String total, String impact) {
    return 'Adesão a $adherence% em $total ações. Estimativa linear (sem rendimento/impostos): ~CHF $impact.';
  }

  @override
  String get agentTaskTaxDeclarationTitle =>
      'Pré-preenchimento da declaração fiscal';

  @override
  String get agentTaskTaxDeclarationDesc =>
      'Estimativa dos principais campos da tua declaração fiscal baseada no teu perfil MINT. Todos os montantes são aproximados.';

  @override
  String get agentTaskThreeAFormTitle => 'Pré-preenchimento do formulário 3a';

  @override
  String get agentTaskThreeAFormDesc =>
      'Informações básicas para uma contribuição para o pilar 3. O limite é calculado com base na tua situação profissional.';

  @override
  String get agentTaskCaisseLetterTitle => 'Carta ao fundo de pensões';

  @override
  String get agentTaskCaisseLetterDesc =>
      'Modelo de carta formal para solicitar um certificado LPP, confirmação de recompra e simulação de reforma antecipada.';

  @override
  String get agentTaskFiscalDossierTitle => 'Preparação do dossier fiscal';

  @override
  String get agentTaskFiscalDossierDesc =>
      'Resumo educativo da tua situação fiscal estimada com deduções possíveis e perguntas para um·a especialista.';

  @override
  String get agentTaskAvsExtractTitle => 'Pedido de extrato AVS';

  @override
  String get agentTaskAvsExtractDesc =>
      'Modelo de carta para solicitar um extrato de conta individual (CI) à tua caixa de compensação AVS.';

  @override
  String get agentTaskLppCertificateTitle => 'Pedido de certificado LPP';

  @override
  String get agentTaskLppCertificateDesc =>
      'Modelo de carta para solicitar um certificado de previdência profissional atualizado ao teu fundo de pensões.';

  @override
  String get agentTaskDisclaimer =>
      'Esta ferramenta é puramente educativa e não constitui aconselhamento financeiro, fiscal ou jurídico. Os montantes mostrados são estimativas indicativas. Consulta um·a especialista qualificado·a antes de qualquer decisão. Em conformidade com a LSFin.';

  @override
  String get agentTaskValidationPromptDefault =>
      'Verifica cuidadosamente cada informação antes de usar. Todos os campos são estimativas a confirmar.';

  @override
  String get agentTaskValidationPromptLetter =>
      'Verifica as informações e preenche os campos entre colchetes antes de enviar esta carta.';

  @override
  String get agentTaskValidationPromptRequest =>
      'Verifica as informações e preenche os campos entre colchetes antes de enviar este pedido.';

  @override
  String agentFieldRevenuBrutValue(String range) {
    return '~$range CHF/ano';
  }

  @override
  String agentFieldRachatLppValue(String range) {
    return '~$range CHF';
  }

  @override
  String get agentFieldAnneRef => 'Ano de referência';

  @override
  String get agentFieldCaissePension => 'Fundo de pensões';

  @override
  String get agentFieldAddressPerso => 'Morada pessoal';

  @override
  String get agentFieldAddresseCaisse => 'Morada do fundo de pensões';

  @override
  String get agentFieldNumeroPolice => 'Número de apólice';

  @override
  String get agentFieldNumeroAvs => 'Número AVS';

  @override
  String get agentFieldAddresseCaisseAvs => 'Morada da caixa AVS';

  @override
  String get agentFiscalDossierRevenu => 'Rendimento bruto estimado';

  @override
  String get agentFiscalDossierPlafond3a => 'Limite 3a aplicável';

  @override
  String get agentFiscalDossierRachat => 'Recompra LPP disponível';

  @override
  String get agentFiscalDossierCapital3a => 'Capital 3a acumulado';

  @override
  String get proactiveLifecycleChange =>
      'Acabaste de entrar numa nova fase de vida. Vemos o que muda para ti ?';

  @override
  String get proactiveWeeklyRecap =>
      'O teu resumo semanal está pronto. Queres vê-lo ?';

  @override
  String proactiveGoalMilestone(String progress) {
    return 'O teu objetivo ultrapassou os $progress %. Muito bem !';
  }

  @override
  String proactiveSeasonalReminder(String event) {
    return 'É a época de $event. Uma boa altura para…';
  }

  @override
  String proactiveInactivityReturn(String days) {
    return 'Fico feliz em te ver ! Já passaram $days dias. Fazemos o ponto da situação ?';
  }

  @override
  String proactiveConfidenceUp(String delta) {
    return 'A tua confiança melhorou $delta pts desde a última vez.';
  }

  @override
  String get proactiveNewCap => 'Tenho uma nova prioridade para ti.';

  @override
  String get dossierToolsSection => 'Ferramentas';

  @override
  String get dossierToolsCta => 'Ver todas as ferramentas';

  @override
  String get pulseNarrativeBudgetGoal => 'a tua margem mensal livre:';

  @override
  String get pulseNarrativeHousingGoal =>
      'a tua capacidade de compra estimada:';

  @override
  String get pulseNarrativeRetirementGoal => 'a tua taxa de substituição:';

  @override
  String get pulseLabelBudgetFree => 'Orçamento livre este mês';

  @override
  String get pulseLabelPurchasingCapacity => 'Capacidade de compra estimada';

  @override
  String capSequenceProgress(int completed, int total) {
    return '$completed/$total passos';
  }

  @override
  String get capSequenceComplete => 'Plano concluído!';

  @override
  String get capSequenceCurrentStep => 'Próximo passo';

  @override
  String get capStepRetirement01Title => 'Conhecer o teu salário bruto';

  @override
  String get capStepRetirement01Desc =>
      'A base de todos os cálculos de reforma.';

  @override
  String get capStepRetirement02Title => 'Estimar a tua renda AVS';

  @override
  String get capStepRetirement02Desc =>
      'Os teus anos contribuídos determinam o 1.º pilar.';

  @override
  String get capStepRetirement03Title => 'Verificar o teu capital LPP';

  @override
  String get capStepRetirement03Desc =>
      'O certificado LPP revela o teu capital do 2.º pilar.';

  @override
  String get capStepRetirement04Title => 'Calcular a tua taxa de substituição';

  @override
  String get capStepRetirement04Desc =>
      'Quanto do teu salário receberes na reforma.';

  @override
  String get capStepRetirement05Title => 'Simular uma contribuição 3a';

  @override
  String get capStepRetirement05Desc =>
      'Deduzir até CHF 7.258 e reforçar a reforma.';

  @override
  String get capStepRetirement06Title => 'Avaliar uma recompra LPP';

  @override
  String get capStepRetirement06Desc => 'Cobrir lacunas e reduzir impostos.';

  @override
  String get capStepRetirement07Title => 'Comparar renda vs capital';

  @override
  String get capStepRetirement07Desc =>
      'Renda mensal ou levantamento do capital?';

  @override
  String get capStepRetirement08Title => 'Planear o levantamento';

  @override
  String get capStepRetirement08Desc =>
      'A ordem de levantamento afeta a fatura fiscal.';

  @override
  String get capStepRetirement09Title => 'Otimizar fiscalmente';

  @override
  String get capStepRetirement09Desc =>
      '3a, recompra, timing: reduzir a tributação do capital.';

  @override
  String get capStepRetirement10Title => 'Consultar um·a especialista';

  @override
  String get capStepRetirement10Desc =>
      'Revisão especializada da tua situação completa.';

  @override
  String get capStepBudget01Title => 'Conhecer os teus rendimentos';

  @override
  String get capStepBudget01Desc =>
      'O ponto de partida de qualquer análise orçamental.';

  @override
  String get capStepBudget02Title => 'Listar as tuas despesas fixas';

  @override
  String get capStepBudget02Desc =>
      'Renda, seguro de saúde, transportes: os inevitáveis.';

  @override
  String get capStepBudget03Title => 'Calcular a tua margem livre';

  @override
  String get capStepBudget03Desc =>
      'O que sobra após as despesas — o teu espaço de manobra.';

  @override
  String get capStepBudget04Title => 'Identificar poupanças possíveis';

  @override
  String get capStepBudget04Desc => 'Pequenos ajustes, grande impacto mensal.';

  @override
  String get capStepBudget05Title => 'Construir uma poupança de precaução';

  @override
  String get capStepBudget05Desc =>
      '3 meses de despesas líquidas: a tua rede de segurança.';

  @override
  String get capStepBudget06Title => 'Planear o 3a';

  @override
  String get capStepBudget06Desc =>
      'Cada franco depositado reduz impostos e prepara a reforma.';

  @override
  String get capStepHousing01Title => 'Conhecer os teus rendimentos';

  @override
  String get capStepHousing01Desc =>
      'A base do cálculo da capacidade de compra.';

  @override
  String get capStepHousing02Title => 'Avaliar os teus fundos próprios';

  @override
  String get capStepHousing02Desc =>
      'Poupanças, 3a e LPP: reunir o aporte necessário.';

  @override
  String get capStepHousing03Title => 'Calcular a tua capacidade de compra';

  @override
  String get capStepHousing03Desc => 'Até que preço podes comprar?';

  @override
  String get capStepHousing04Title => 'Simular a hipoteca';

  @override
  String get capStepHousing04Desc =>
      'Prestação mensal, amortização, taxa teórica.';

  @override
  String get capStepHousing05Title => 'Avaliar o EPL (2.º pilar)';

  @override
  String get capStepHousing05Desc =>
      'Levantamento antecipado LPP para financiar o aporte.';

  @override
  String get capStepHousing06Title => 'Comparar arrendamento vs compra';

  @override
  String get capStepHousing06Desc => 'O cálculo que vai além das intuições.';

  @override
  String get capStepHousing07Title => 'Consultar um·a especialista';

  @override
  String get capStepHousing07Desc =>
      'Notário, corretor, consultor: quando envolver quem.';

  @override
  String get goalSelectorTitle => 'Qual é o teu objetivo principal?';

  @override
  String get goalSelectorAuto => 'Deixar o MINT decidir';

  @override
  String get goalSelectorAutoDesc =>
      'O MINT adapta-se automaticamente ao teu perfil';

  @override
  String get goalRetirementTitle => 'A minha reforma';

  @override
  String get goalRetirementDesc => 'Planear a transição para a reforma';

  @override
  String get goalBudgetTitle => 'O meu orçamento';

  @override
  String get goalBudgetDesc => 'Controlar as despesas e poupar';

  @override
  String get goalHousingTitle => 'Comprar um imóvel';

  @override
  String get goalHousingDesc => 'Avaliar a minha capacidade e planear a compra';

  @override
  String get goalTaxTitle => 'Pagar menos impostos';

  @override
  String get goalTaxDesc => 'Otimizar as deduções (3a, resgate LPP)';

  @override
  String get goalDebtTitle => 'Gerir as dívidas';

  @override
  String get goalDebtDesc => 'Recuperar margem e reembolsar';

  @override
  String get goalBirthTitle => 'Preparar um nascimento';

  @override
  String get goalBirthDesc => 'Antecipar os custos e adaptar o orçamento';

  @override
  String get goalIndependentTitle => 'Tornar-me independente';

  @override
  String get goalIndependentDesc => 'Previdência, fiscalidade e cobertura';

  @override
  String pulseGoalChip(String goal) {
    return 'Objetivo: $goal';
  }

  @override
  String get dossierProfileSection => 'O meu perfil';

  @override
  String get dossierPlanSection => 'O meu plano';

  @override
  String get dossierDataSection => 'Os meus dados';

  @override
  String get dossierConfidenceLabel => 'Fiabilidade do dossier';

  @override
  String get dossierCompleteCta => 'Completar o meu perfil';

  @override
  String get dossierChooseGoalCta => 'Escolher um objetivo';

  @override
  String get dossierScanLppCta => 'Digitalizar o meu certificado LPP';

  @override
  String get dossierDataRevenu => 'Rendimento';

  @override
  String get dossierDataLpp => '2.º pilar';

  @override
  String get dossierData3a => '3.º pilar';

  @override
  String get dossierDataBudget => 'Margem mensal';

  @override
  String get dossierDataUnknown => 'Não indicado';

  @override
  String dossierPlanProgress(int done, int total) {
    return '$done / $total etapas';
  }

  @override
  String get dossierPlanChangeGoal => 'Mudar objetivo';

  @override
  String get dossierPlanCurrentStep => 'Etapa atual';

  @override
  String get dossierPlanNextStep => 'Próxima etapa';

  @override
  String dossierConfidencePct(int pct) {
    return '$pct %';
  }

  @override
  String memoryRefTopic(int days, String topic) {
    return 'Há $days dias, falaste-me de $topic.';
  }

  @override
  String memoryRefGoal(String goal) {
    return 'Tinhas definido o objetivo: $goal. Fazemos o ponto da situação?';
  }

  @override
  String memoryRefScreenVisit(String screen) {
    return 'Da última vez, utilizaste $screen.';
  }

  @override
  String get memoryRefRecentInsights => 'O que recordo das nossas conversás:';

  @override
  String openerBudgetDeficit(String deficit) {
    return 'CHF $deficit/mês de défice. Vemos onde está a apertar?';
  }

  @override
  String opener3aDeadline(String days, String plafond) {
    return 'Restam $days dias para depositar até $plafond CHF no teu 3a.';
  }

  @override
  String openerGapWarning(String rate, String gap) {
    return 'A tua taxa de substituição: $rate %. Na reforma, faltar-te-iam CHF $gap/mês.';
  }

  @override
  String openerSavingsOpportunity(String plafond) {
    return 'O teu 3a: CHF 0 este ano. $plafond CHF de poupança fiscal em jogo.';
  }

  @override
  String openerProgressCelebration(String delta) {
    return 'A tua fiabilidade ganhou $delta pontos. Os teus números são mais precisos.';
  }

  @override
  String openerPlanProgress(String n, String total, String next) {
    return 'Etapa $n/$total concluída. Próxima: $next.';
  }

  @override
  String get semanticsBackButton => 'Voltar';

  @override
  String get semanticsDecrement => 'Diminuir';

  @override
  String get semanticsIncrement => 'Aumentar';

  @override
  String get frontalierDisclaimer =>
      'Estimativas simplificadas para fins educativos — não constitui aconselhamento fiscal ou jurídico. Os montantes dependem de muitos fatores. Consulta um especialista fiscal para uma análise personalizada. LSFin.';

  @override
  String get firstJobPayslipAvsLabel => 'AVS/AI/APG';

  @override
  String get firstJobPayslipAvsExplanation =>
      'Contribuição do trabalhador: 5.3% do salário bruto. O teu empregador também paga 5.3% adicional.';

  @override
  String get firstJobPayslipLppLabel => 'LPP (2.º pilar)';

  @override
  String get firstJobPayslipLppExplanation =>
      'Poupança para reforma obrigatória a partir dos 25 anos. A taxa exata depende da tua caixa e idade.';

  @override
  String get firstJobPayslipImpotLabel => 'Imposto na fonte (estimativa)';

  @override
  String get firstJobPayslipImpotExplanation =>
      'Deduzido diretamente do salário se fores tributado na fonte. A taxa varia por cantão, estado civil e rendimento.';

  @override
  String get firstJobChecklistDeadline1 => 'Antes de sair';

  @override
  String get firstJobChecklistAction1 =>
      'Solicita o teu certificado LPP ao empregador atual.';

  @override
  String get firstJobChecklistConsequence1 =>
      'Sem certificado, não podes verificar se o montante transferido está correto.';

  @override
  String get firstJobChecklistDeadline2 => '30 dias';

  @override
  String get firstJobChecklistAction2 =>
      'Verifica que o teu capital LPP foi transferido para a caixa do novo empregador.';

  @override
  String get firstJobChecklistConsequence2 =>
      'Sem transferência, o teu capital vai para a fundação supletiva a uma taxa de 0.05%.';

  @override
  String get firstJobChecklistDeadline3 => '1 mês';

  @override
  String get firstJobChecklistAction3 =>
      'Informa o teu seguro de saúde LAMal da mudança de empregador se tiveras cobertura coletiva.';

  @override
  String get firstJobChecklistDeadline4 => 'A partir do primeiro salário';

  @override
  String get firstJobChecklistAction4 =>
      'Continua as tuas contribuições ao pilar 3a — a interrupção custa-te deduções fiscais.';

  @override
  String get firstJobBudgetBesoins => 'Necessidades';

  @override
  String get firstJobBudgetLoyer => 'Renda';

  @override
  String get firstJobBudgetTransport => 'Transporte';

  @override
  String get firstJobBudgetAlimentation => 'Alimentação';

  @override
  String get firstJobBudgetEnvies => 'Desejos';

  @override
  String get firstJobBudgetLoisirs => 'Lazer';

  @override
  String get firstJobBudgetRestaurants => 'Restaurantes';

  @override
  String get firstJobBudgetVoyages => 'Viagens';

  @override
  String get firstJobBudgetShopping => 'Compras';

  @override
  String get firstJobBudgetEpargne => 'Poupança & 3a';

  @override
  String get firstJobBudgetPilier3a => 'Pilar 3a';

  @override
  String get firstJobBudgetEpargneCourt => 'Poupança';

  @override
  String get firstJobBudgetFondsUrgence => 'Fundo de emergência';

  @override
  String firstJobBudgetChiffreChoc(String annual, String future) {
    return 'Se poupares $annual CHF/ano a partir de agora, terás ~$future CHF aos 65.';
  }

  @override
  String get firstJobScenarioMySalary => 'O meu salário';

  @override
  String get firstJobScenarioDefault => 'Padrão';

  @override
  String get firstJobScenarioMedianCH => 'Mediana CH';

  @override
  String get firstJobScenarioBoosted => '+20%';

  @override
  String firstJobScenarioSemantics(String label) {
    return 'Cenário salarial: $label';
  }

  @override
  String get pulseRetirementIncome => 'Rendimento aposentadoria estimado';

  @override
  String get pulseCapImpact => 'Alavanca identificada';

  @override
  String get dossierAddConjointCta => 'Adicionar meu·minha parceiro·a';

  @override
  String get dossierDataAvs => '1º pilar';

  @override
  String get dossierDataFiscalite => 'Fiscalidade';

  @override
  String get pulseRetirementIncomeEstimated =>
      'Aposentadoria estimada (mínimo LPP)';

  @override
  String get dossierScanLppPrecision =>
      'Digitalize o certificado para projeções mais precisas';

  @override
  String get pulsePlanTitle => 'Meu plano';

  @override
  String pulsePlanProgress(int completed, int total) {
    return '$completed/$total';
  }

  @override
  String pulsePlanNextStep(String stepName) {
    return 'Próximo passo: $stepName';
  }

  @override
  String get dossierCoachingTitle => 'Acompanhamento';

  @override
  String get dossierCoachingSubtitle => 'Frequência de lembretes e sugestões';

  @override
  String get coachingSheetSubtitle =>
      'Escolha com que frequência o MINT te acompanha';

  @override
  String get coachingIntensityDiscret => 'Discreto';

  @override
  String get coachingIntensityCalme => 'Calmo';

  @override
  String get coachingIntensityEquilibre => 'Equilibrado';

  @override
  String get coachingIntensityAttentif => 'Atento';

  @override
  String get coachingIntensityProactif => 'Proativo';

  @override
  String get coachingDescDiscret =>
      'MINT te deixa em paz. Lembretes raros, apenas prazos críticos.';

  @override
  String get coachingDescCalme =>
      'MINT intervém ocasionalmente. Um lembrete a cada 3 dias no máximo.';

  @override
  String get coachingDescEquilibre =>
      'MINT te guia diariamente. Um lembrete por dia, sugestões contextuais.';

  @override
  String get coachingDescAttentif =>
      'MINT está atento em cada sessão. Sugestões frequentes e memória rica.';

  @override
  String get coachingDescProactif =>
      'MINT te acompanha ativamente. Lembretes em cada visita, memória completa.';

  @override
  String coachingEngagementStats(Object engaged, Object total) {
    return '$engaged interações de $total sugestões';
  }

  @override
  String get landingHiddenAmount => 'Valor oculto';

  @override
  String get landingHiddenSubtitle => 'Crie uma conta para ver seus números';

  @override
  String get friBarTitle => 'Resiliência financeira';

  @override
  String get friBarLiquidity => 'Liquidez';

  @override
  String get friBarFlexibility => 'Flexibilidade';

  @override
  String get friBarResilience => 'Resiliência';

  @override
  String get friBarStability => 'Estabilidade';

  @override
  String get deuxViesTitle => 'As vossas duas vidas';

  @override
  String deuxViesGap(String amount, String name) {
    return 'Diferença de $amount/mês a favor de $name';
  }

  @override
  String deuxViesLever(String lever, String impact) {
    return '$lever fecharia $impact da diferença';
  }

  @override
  String get deuxViesDisclaimer =>
      'Ferramenta educativa. Não é aconselhamento financeiro (LSFin).';

  @override
  String get expertTierScreenTitle => 'Consultar um·a especialista';

  @override
  String get expertTierFinancialPlanner => 'Planeador·a financeiro·a';

  @override
  String get expertTierFinancialPlannerDesc =>
      'Reforma, previdência, estratégia de levantamento, planeamento patrimonial global';

  @override
  String get expertTierTaxSpecialist => 'Especialista fiscal';

  @override
  String get expertTierTaxSpecialistDesc =>
      'Otimização fiscal, recompra LPP, declaração, planeamento intercantonal';

  @override
  String get expertTierNotary => 'Notário·a';

  @override
  String get expertTierNotaryDesc =>
      'Sucessão, testamento, doação, regime matrimonial, pacto sucessório';

  @override
  String get expertTierPrice => 'CHF 129 / sessão';

  @override
  String get expertTierSelectCta => 'Preparar o meu dossier';

  @override
  String get expertTierDossierPreviewTitle => 'Prévia do teu dossier';

  @override
  String get expertTierDossierGenerating => 'A preparar o dossier…';

  @override
  String get expertTierDossierReady => 'Dossier pronto';

  @override
  String get expertTierRequestCta => 'Pedir uma consulta';

  @override
  String get expertTierComingSoonTitle => 'Em breve';

  @override
  String get expertTierComingSoon =>
      'A marcação de consultas chega em breve. O teu dossier está pronto — poderás transmiti-lo assim que o serviço abrir.';

  @override
  String expertTierCompleteness(String percent) {
    return 'Perfil completo a $percent %';
  }

  @override
  String get expertTierEstimated => 'Estimado';

  @override
  String get expertTierMissingDataTitle => 'Dados a completar';

  @override
  String get expertTierDisclaimerBanner =>
      'MINT prepara o dossier, o·a especialista dá o conselho';

  @override
  String get expertTierBack => 'Escolher outro·a especialista';

  @override
  String get expertTierOk => 'Entendido';

  @override
  String get docCardTitle => 'Documento pré-preenchido';

  @override
  String get docCardFiscalDeclaration => 'Declaração fiscal';

  @override
  String get docCardPensionFundLetter => 'Carta ao fundo de pensão';

  @override
  String get docCardLppBuybackRequest => 'Pedido de resgate LPP';

  @override
  String get docCardDisclaimer => 'Verifica cada campo. MINT nunca envia nada.';

  @override
  String get docCardViewDocument => 'Ver documento';

  @override
  String get docCardValidationFailed => 'A validação do documento falhou.';

  @override
  String get docCardGenerating => 'A gerar documento…';

  @override
  String docCardFieldCount(int count) {
    return '$count campos pré-preenchidos';
  }

  @override
  String get docCardReadOnly => 'Somente leitura — completar manualmente';

  @override
  String get sourceBadgeEstimated => 'Estimado';

  @override
  String get sourceBadgeDeclared => 'Declarado';

  @override
  String get sourceBadgeCertified => 'Certificado';

  @override
  String get monteCarloTitle => 'As tuas chances de viver confortavelmente';

  @override
  String monteCarloSubtitle(int count) {
    return '$count cenários simulados';
  }

  @override
  String get monteCarloHeroPhrase =>
      'de probabilidade de que o teu capital dure até aos 90 anos';

  @override
  String get monteCarloLegendWideBand => 'Faixa ampla';

  @override
  String get monteCarloLegendProbableBand => 'Faixa provável';

  @override
  String get monteCarloLegendMedian => 'Cenário central';

  @override
  String get monteCarloLegendCurrentIncome => 'O que ganhas hoje';

  @override
  String monteCarloMedianAtAge(int age) {
    return 'Cenário central aos $age anos';
  }

  @override
  String get monteCarloProbableRange => 'Faixa provável';

  @override
  String get monteCarloSuccessLabel =>
      'Probabilidade de que o teu\ncapital dure até aos 90 anos';

  @override
  String get monteCarloDisclaimer =>
      'Os rendimentos passados não são indicadores de rendimentos futuros. Simulação educativa (LSFin).';

  @override
  String get dossierIdentiteSection => 'Identidade';

  @override
  String get dossierDocumentsSection => 'Documentos';

  @override
  String get dossierCoupleSection => 'Casal';

  @override
  String get dossierPreferencesSection => 'Preferências';

  @override
  String dossierUpdatedAgo(int days) {
    return 'Atualizado há $days dias';
  }

  @override
  String dossierUpdatedOn(String date) {
    return 'Atualizado em $date';
  }

  @override
  String get dossierUpdatedToday => 'Atualizado hoje';

  @override
  String get dossierUpdatedYesterday => 'Atualizado ontem';

  @override
  String get exploreHubOtherTopics => 'Outros temas';

  @override
  String get bankImportSummaryHeader => 'RESUMO';

  @override
  String get bankImportTransactionsHeader => 'TRANSAÇÕES';

  @override
  String bankImportMoreTransactions(int count) {
    return '... e mais $count transações';
  }

  @override
  String get bankImportGenericError => 'Ocorreu um erro ao analisar o extrato.';

  @override
  String get helpResourcesAppBarTitle => 'AJUDA EM CASO DE DÍVIDA';

  @override
  String get helpResourcesIntroTitle => 'Não estás sozinho';

  @override
  String get helpResourcesIntroBody =>
      'Na Suíça, muitos serviços profissionais oferecem acompanhamento gratuito e confidencial para pessoas em dificuldades financeiras. Pedir ajuda é um ato de coragem.';

  @override
  String get helpResourcesIntroNote =>
      'Todos os links levam a sites externos. A MINT não transmite dados a estes serviços.';

  @override
  String get helpResourcesDettesName => 'Dettes Conseils Suisse';

  @override
  String get helpResourcesDettesDesc =>
      'Federação dos serviços de aconselhamento de dívidas na Suíça.';

  @override
  String get helpResourcesCaritasName => 'Caritas — Aconselhamento de dívidas';

  @override
  String get helpResourcesCaritasDesc =>
      'Serviço de ajuda da Caritas Suíça para pessoas endividadas.';

  @override
  String get helpResourcesFreeLabel => 'GRÁTIS';

  @override
  String get helpResourcesCantonalHeader => 'SERVIÇO CANTONAL';

  @override
  String get helpResourcesCantonLabel => 'O teu cantão';

  @override
  String get helpResourcesNoService =>
      'Nenhum serviço cantonal registado para este cantão.';

  @override
  String get helpResourcesPrivacyTitle => 'Proteção de dados (nLPD)';

  @override
  String get helpResourcesPrivacyBody =>
      'A MINT não transmite dados pessoais aos serviços acima referidos.';

  @override
  String get helpResourcesDisclaimer =>
      'A MINT fornece estes links para fins informativos e educativos.';

  @override
  String get successionUrgenceAction1 =>
      'Declarar o óbito no registo civil em 2 dias';

  @override
  String get successionUrgenceAction2 =>
      'Informar o empregador e seguradoras (LAMal, LPP)';

  @override
  String get successionUrgenceAction3 =>
      'Bloquear contas bancárias conjuntas se necessário';

  @override
  String get successionUrgenceAction4 =>
      'Contactar o notário se a pessoa tinha testamento';

  @override
  String get successionDemarchesAction1 =>
      'Solicitar pensões de sobreviventes AVS (LAVS art. 23)';

  @override
  String get successionDemarchesAction2 =>
      'Contactar a caixa LPP para o capital de falecimento';

  @override
  String get successionDemarchesAction3 =>
      'Cancelar assinaturas e contratos em nome do falecido';

  @override
  String get successionDemarchesAction4 =>
      'Fazer inventário de ativos e dívidas';

  @override
  String get successionDemarchesAction5 =>
      'Solicitar certificados de herdeiros ao notário';

  @override
  String get successionLegaleAction1 =>
      'Abrir o procedimento de sucessão com o notário';

  @override
  String get successionLegaleAction2 =>
      'Partilhar bens conforme testamento ou lei (CC art. 537)';

  @override
  String get successionLegaleAction3 =>
      'Apresentar declaração fiscal do ano do falecimento';

  @override
  String get successionLegaleAction4 =>
      'Atualizar beneficiários dos teus próprios contratos';

  @override
  String get disabilityGapAct1Label => 'ATO 1 · Empregador';

  @override
  String get disabilityGapAct1Detail =>
      '80 % do teu salário pago pelo empregador';

  @override
  String get disabilityGapAct1Duration => 'Semanas 1-26';

  @override
  String get disabilityGapAct2LabelIjm => 'ATO 2 · IJM (seguro de doença)';

  @override
  String get disabilityGapAct2LabelNoIjm => 'ATO 2 · Sem IJM';

  @override
  String get disabilityGapAct2SubIjm =>
      'Seguro coletivo — 80% durante 720 dias máx.';

  @override
  String get disabilityGapAct2SubNoIjm =>
      'Sem IJM, passas diretamente à AI após o empregador';

  @override
  String get disabilityGapAct2Duration => 'Até 24 meses';

  @override
  String get disabilityGapAct2DetailIjm => '80% do salário segurado';

  @override
  String get disabilityGapAct2DetailNoIjm =>
      'Sem cobertura — prazo AI em curso';

  @override
  String get disabilityGapAct3Label => 'ATO 3 · AI + LPP (definitivo)';

  @override
  String get disabilityGapAct3Duration => 'Após 24 meses';

  @override
  String disabilityGapAct3Detail(
      String aiAmount, String lppAmount, String totalAmount) {
    return 'AI $aiAmount + LPP $lppAmount = $totalAmount CHF/mês';
  }

  @override
  String get disabilityGapIjmCoverage =>
      '80% durante 720 dias — seguro coletivo';

  @override
  String get disabilityGapNoIjmCoverage =>
      'Nenhuma IJM subscrita — risco máximo';

  @override
  String disabilityGapAiDetail(String amount) {
    return 'Máx. $amount CHF/mês — ~14 meses de espera';
  }

  @override
  String get disabilityGapLppCovered =>
      'Pensão de invalidez ≈ 40% salário coordenado (LPP art. 23)';

  @override
  String get disabilityGapLppNotCovered =>
      'Salário abaixo do limiar LPP — sem cobertura 2º pilar';

  @override
  String get disabilityGapSavingsLabel => 'Reserva de emergência';

  @override
  String disabilityGapSavingsDetail(String months) {
    return '$months meses de despesas cobertos';
  }

  @override
  String get disabilityGapApgLabel => 'APG / IJM (perda de rendimento)';

  @override
  String get disabilityGapAiLabel => 'AI (seguro de invalidez)';

  @override
  String get disabilityGapLppLabel => 'LPP invalidez (2º pilar)';

  @override
  String get disabilityGapSources =>
      '• LAI art. 28-29\n• LPP art. 23-26\n• CO art. 324a\n• LPGA art. 19';

  @override
  String disabilityGapAgeLabel(int age) {
    return '$age anos';
  }

  @override
  String get documentDetailExplanationObligatoire =>
      'Montante acumulado na parte obrigatória LPP';

  @override
  String get documentDetailExplanationSurobligatoire =>
      'Parte além do mínimo legal';

  @override
  String get documentDetailExplanationTotal =>
      'Total do teu capital de velhice';

  @override
  String get documentDetailExplanationSalaireAssure =>
      'Salário sobre o qual as contribuições são calculadas';

  @override
  String get documentDetailExplanationSalaireAvs =>
      'Salário determinante para o AVS';

  @override
  String get documentDetailExplanationDeduction =>
      'Montante deduzido para coordenar com o AVS';

  @override
  String get documentDetailExplanationTauxOblig => 'Mínimo legal: 6.8%';

  @override
  String get documentDetailExplanationTauxSurob =>
      'Definido pela tua caixa de pensões';

  @override
  String get documentDetailExplanationTauxEnv => 'Taxa média ponderada';

  @override
  String get documentDetailExplanationInvalidite =>
      'Pensão em caso de incapacidade de trabalho';

  @override
  String get documentDetailExplanationDeces =>
      'Montante pago aos beneficiários em caso de falecimento';

  @override
  String get documentDetailExplanationConjoint =>
      'Pensão paga ao cônjuge sobrevivente';

  @override
  String get documentDetailExplanationEnfant => 'Pensão paga por filho';

  @override
  String get documentDetailExplanationRachat =>
      'Montante que pode ser resgatado para otimizar a tua previdência';

  @override
  String get documentDetailExplanationEmploye => 'A tua contribuição anual';

  @override
  String get documentDetailExplanationEmployeur =>
      'Contribuição do teu empregador';

  @override
  String get disabilitySelfEmployedAlertLabel => '🚨  ALERTA INDEPENDENTE';

  @override
  String get disabilitySelfEmployedTitle =>
      'A tua rede de segurança não existe';

  @override
  String get disabilitySelfEmployedAppBarTitle => 'Invalidez — Independente';

  @override
  String get disabilitySelfEmployedRevenueTitle =>
      'O teu rendimento mensal líquido';

  @override
  String get disabilitySelfEmployedRevenueHint =>
      'Ajusta para ver o impacto na tua situação real';

  @override
  String get disabilitySelfEmployedRevenueLabel => 'Rendimento líquido/mês';

  @override
  String get disabilitySelfEmployedInsuranceQuestion =>
      'Já tens seguro de perda de rendimento?';

  @override
  String get disabilitySelfEmployedYes => 'Sim';

  @override
  String get disabilitySelfEmployedNo => 'Não / Não sei';

  @override
  String get disabilitySelfEmployedApgTip =>
      'Uma APG individual a partir de CHF 45/mês pode cobrir 80% do teu rendimento durante 720 dias.';

  @override
  String get disabilitySelfEmployedDisclaimer =>
      'Ferramenta educativa — não constitui aconselhamento de seguros.';

  @override
  String get disabilitySelfEmployedSources =>
      '• LAMal art. 67-77\n• CO art. 324a\n• LAI art. 28\n• LAVS art. 2 al. 3';

  @override
  String get confidenceDashboardLevelExcellent => 'Excelente';

  @override
  String get confidenceDashboardLevelGood => 'Boa';

  @override
  String get confidenceDashboardLevelFair => 'Razoável';

  @override
  String get confidenceDashboardLevelImprove => 'A melhorar';

  @override
  String get confidenceDashboardLevelInsufficient => 'Insuficiente';

  @override
  String get confidenceDashboardBreakdownTitle => 'Detalhe por eixo';

  @override
  String get confidenceDashboardFeaturesTitle =>
      'Funcionalidades desbloqueadas';

  @override
  String confidenceDashboardRequired(String percent) {
    return '$percent % necessário';
  }

  @override
  String get confidenceDashboardEnrichTitle => 'Melhora a tua precisão';

  @override
  String get confidenceDashboardSourcesTitle => 'Fontes';

  @override
  String get cockpitDetailEmptyState =>
      'Completa o teu perfil para aceder ao cockpit detalhado.';

  @override
  String get cockpitDetailEnrichProfile => 'Enriquecer o meu perfil';

  @override
  String get cockpitDetailDisclaimer =>
      'Ferramenta educativa simplificada. Não constitui aconselhamento financeiro (LSFin).';

  @override
  String get toolBudgetSnapshotHint =>
      'Aqui está uma visão do teu orçamento atual.';

  @override
  String get toolScoreGaugeHint =>
      'Aqui está a tua pontuação de confiança financeira.';

  @override
  String get coachFactCardTitle => 'Sabias que?';

  @override
  String firstJobPrimePerMonth(String amount) {
    return '$amount/mês';
  }

  @override
  String firstJobCoutMaxPerYear(String amount) {
    return 'Máx. $amount/ano';
  }

  @override
  String get jobChangeChecklistSemantics =>
      'Lista de verificação novo emprego LPP livre passagem ações urgentes';

  @override
  String get jobChangeChecklistTitle =>
      'Lista de verificação mudança de emprego';

  @override
  String get jobChangeChecklistSubtitle =>
      'Tens 30 dias para verificar que o teu LPP foi transferido.';

  @override
  String jobChangeChecklistProgress(int completed, int total) {
    return '$completed / $total ações concluídas';
  }

  @override
  String get jobChangeChecklistAlertTitle =>
      'Pede SEMPRE o certificado LPP antes de assinar';

  @override
  String get jobChangeChecklistAlertBody =>
      'Sem transferência do livre passagem nos prazos, o teu capital LPP pode acabar na Fundação supletiva a 0.05 %.';

  @override
  String get jobChangeChecklistDisclaimer =>
      'Ferramenta educativa · não constitui aconselhamento financeiro nos termos da LSFin. Fonte: LPP art. 3 (livre passagem), OLP art. 1-3.';

  @override
  String get circleLabelEmergencyFund => 'Fundo de emergência';

  @override
  String get circleLabelDettes => 'Dívidas';

  @override
  String get circleLabelRevenu => 'Rendimento';

  @override
  String get circleLabelAssurancesObligatoires => 'Seguros obrigatórios';

  @override
  String get circleLabelTroisaOptimisation => '3a - Otimização';

  @override
  String get circleLabelTroisaVersement => '3a - Contribuição';

  @override
  String get circleLabelLppRachat => 'LPP - Resgate';

  @override
  String get circleLabelAvs => 'AVS';

  @override
  String get circleLabelInvestissements => 'Investimentos';

  @override
  String get circleLabelPatrimoineImmobilier => 'Patrimônio imobiliário';

  @override
  String get circleNameProtection => 'Proteção & Segurança';

  @override
  String get circleNamePrevoyance => 'Previdência Fiscal';

  @override
  String get circleNameCroissance => 'Crescimento';

  @override
  String get circleNameOptimisation => 'Otimização & Transferência';

  @override
  String get nudgeSalaryDayTitle => 'Dia de pagamento!';

  @override
  String get nudgeSalaryDayMessage =>
      'Pensaste na tua transferência 3a este mês? Cada mês conta para a tua previdência.';

  @override
  String get nudgeSalaryDayAction => 'Ver o meu 3a';

  @override
  String get nudgeTaxDeadlineMessage =>
      'Verifica o prazo da declaração fiscal no teu cantão. Verificaste as tuas deduções 3a e LPP?';

  @override
  String get nudgeTaxDeadlineAction => 'Simular os meus impostos';

  @override
  String get nudgeThreeADeadlineTitle => 'Última reta para o teu 3a';

  @override
  String get nudgeThreeADeadlineMessageLastDay =>
      'Hoje é o último dia para contribuir para o teu 3a!';

  @override
  String get nudgeThreeADeadlineAction => 'Calcular a minha poupança';

  @override
  String get nudgeBirthdayDashboardAction => 'Ver o meu painel';

  @override
  String get nudgeLppBonifStartTitle => 'Início das contribuições LPP';

  @override
  String get nudgeLppBonifChangeTitle => 'Mudança de escalão LPP';

  @override
  String get nudgeLppBonifAction => 'Explorar o resgate';

  @override
  String get nudgeWeeklyCheckInTitle => 'Já passou algum tempo!';

  @override
  String get nudgeWeeklyCheckInMessage =>
      'A tua situação financeira evolui a cada semana. Dedica 2 minutos para verificar o teu painel.';

  @override
  String get nudgeWeeklyCheckInAction => 'Ver o meu Pulse';

  @override
  String get nudgeStreakRiskTitle => 'A tua série está em perigo!';

  @override
  String get nudgeStreakRiskAction => 'Continuar a minha série';

  @override
  String get nudgeGoalApproachingTitle => 'O teu objetivo está a aproximar-se';

  @override
  String get nudgeGoalApproachingAction => 'Falar com o coach';

  @override
  String get nudgeFhsDroppedTitle => 'A tua pontuação de saúde desceu';

  @override
  String get nudgeFhsDroppedAction => 'Perceber a descida';

  @override
  String get ragErrorInvalidKey => 'A chave API é inválida ou expirou.';

  @override
  String get ragErrorRateLimit =>
      'Limite de pedidos atingido. Tenta novamente dentro de momentos.';

  @override
  String get ragErrorBadRequest => 'Pedido inválido.';

  @override
  String get ragErrorServiceUnavailable =>
      'Serviço temporariamente indisponível. Tenta mais tarde.';

  @override
  String get ragErrorStatus => 'Impossível verificar o estado do sistema RAG.';

  @override
  String get ragErrorVisionBadRequest => 'Pedido de visão inválido.';

  @override
  String get ragErrorImageTooLarge =>
      'A imagem excede o limite de tamanho de 20 MB.';

  @override
  String get ragErrorRateLimitShort => 'Limite de pedidos atingido.';

  @override
  String get paywallTitle => 'Desbloqueia o MINT Coach';

  @override
  String get paywallSubtitle => 'O teu coach financeiro pessoal';

  @override
  String get paywallTrialBadge => 'Teste gratuito 14 dias';

  @override
  String paywallSubscriptionActivated(String tier) {
    return 'Subscrição $tier ativada com sucesso.';
  }

  @override
  String get paywallTrialActivated =>
      'Teste gratuito ativado! Aproveita o MINT Coach durante 14 dias.';

  @override
  String get paywallRestoreButton => 'Restaurar uma compra';

  @override
  String get paywallRestoreSuccess => 'Subscrição restaurada com sucesso!';

  @override
  String get paywallRestoreNoPurchase => 'Nenhuma compra anterior encontrada.';

  @override
  String get paywallDisclaimer =>
      'Ferramenta educativa — não constitui aconselhamento financeiro. LSFin. Podes cancelar a qualquer momento nas definições da tua conta.';

  @override
  String get paywallClose => 'Fechar';

  @override
  String paywallSelectTier(String name) {
    return 'Selecionar $name';
  }

  @override
  String paywallChooseTier(String tier) {
    return 'Escolher $tier';
  }

  @override
  String get paywallStartTrial => 'Iniciar teste gratuito';

  @override
  String get paywallPricePerMonth => '/mês';

  @override
  String get paywallFeatureTop => 'Top';

  @override
  String get arbitrageOptionFullRente => '100 % Renda';

  @override
  String get arbitrageOptionFullCapital => '100 % Capital';

  @override
  String get arbitrageOptionMixed =>
      'Misto (renda obrig. + capital sobreobrig.)';

  @override
  String get arbitrageOptionAmortIndirect => 'Amortização indireta';

  @override
  String get arbitrageOptionInvestLibre => 'Investimento livre';

  @override
  String get tornadoLabelRendementCapital => 'Rendimento do teu capital';

  @override
  String get tornadoLabelTauxRetrait => 'Levantamento anual do capital';

  @override
  String get tornadoLabelConversionOblig => 'Conversão LPP obrigatória';

  @override
  String get tornadoLabelConversionSurob => 'Conversão LPP sobreobrig.';

  @override
  String get tornadoLabelRendementMarche => 'Rendimento dos teus investimentos';

  @override
  String get tornadoLabelTauxMarginal => 'A tua taxa de imposto';

  @override
  String get tornadoLabelRendement3a => 'Rendimento do teu 3º pilar';

  @override
  String get tornadoLabelRendementLpp => 'Rendimento do teu fundo LPP';

  @override
  String get tornadoLabelTauxHypothecaire => 'Taxa hipotecária';

  @override
  String get tornadoLabelAppreciationImmo => 'Valorização imobiliária';

  @override
  String get tornadoLabelLoyerMensuel => 'Renda mensal';

  @override
  String get tornadoLabelTauxImpotCapital => 'Taxa de imposto sobre o capital';

  @override
  String get tornadoLabelAgeRetraite => 'Idade de reforma';

  @override
  String get tornadoLabelCapitalTotal => 'Capital total';

  @override
  String get tornadoLabelAnneesAvantRetraite => 'Anos antes da reforma';

  @override
  String get tornadoLabelBas => 'Baixo';

  @override
  String get tornadoLabelHaut => 'Alto';

  @override
  String get educationalLearnMoreStressCheck =>
      'O teu stress financeiro, explicado claramente';

  @override
  String get educationalLearnMoreLpp => 'Entender o 2º pilar (LPP)';

  @override
  String get educationalLearnMoreTroisA => 'O 3º pilar em detalhe';

  @override
  String get educationalLearnMoreMortgage => 'Tipos de hipoteca na Suíça';

  @override
  String get educationalLearnMoreCredit => 'Crédito ao consumo';

  @override
  String get educationalLearnMoreLeasing => 'Leasing vs compra';

  @override
  String get educationalLearnMoreEmergency =>
      'Porque ter um fundo de emergência?';

  @override
  String get educationalLearnMoreCivilStatus =>
      'Estado civil e finanças na Suíça';

  @override
  String get educationalLearnMoreEmployment =>
      'Estatuto profissional e previdência';

  @override
  String get educationalLearnMoreHousing => 'Arrendar ou ser proprietário?';

  @override
  String get educationalLearnMoreCanton => 'Fiscalidade cantonal na Suíça';

  @override
  String get educationalLearnMoreLppBuyback => 'Resgate LPP, como funciona?';

  @override
  String get educationalLearnMoreTroisaCount => 'Estratégia multi-conta 3a';

  @override
  String get educationalLearnMoreInvestments =>
      'Investimentos e fiscalidade suíça';

  @override
  String get educationalLearnMoreRealEstate =>
      'Financiar uma compra imobiliária';

  @override
  String get capMissingPieceHeadline => 'Falta uma peça';

  @override
  String capMissingPieceWhyNow(String label) {
    return '$label — sem este dado, a tua projeção fica imprecisa.';
  }

  @override
  String capMissingPieceExpectedImpact(String impact) {
    return '+$impact pontos de confiança';
  }

  @override
  String capMissingPieceConfidenceLabel(String score) {
    return 'confiança $score %';
  }

  @override
  String get capDebtHeadline => 'A tua dívida pesa';

  @override
  String get capDebtWhyNow =>
      'Pagar primeiro a taxa mais alta liberta margem todos os meses.';

  @override
  String get capDebtCtaLabel => 'Ver o meu plano';

  @override
  String get capDebtExpectedImpact => 'margem a recuperar';

  @override
  String get capIndepNoLppHeadline => 'O teu 2.º pilar : CHF 0';

  @override
  String get capIndepNoLppWhyNow =>
      'Sem LPP, a tua reforma = AVS sozinha. Uma rede voluntária muda a trajetória.';

  @override
  String get capIndepNoLppCtaLabel => 'Construir a minha rede';

  @override
  String get capIndepNoLppExpectedImpact => 'reforma reforçada';

  @override
  String get capDisabilityGapHeadline => 'A tua rede de invalidez : apenas AI';

  @override
  String get capDisabilityGapWhyNow =>
      'Sem LPP, a tua cobertura de invalidez limita-se à AI. A lacuna pode surpreender.';

  @override
  String get capDisabilityGapCtaLabel => 'Ver a lacuna';

  @override
  String get capDisabilityGapExpectedImpact => 'perceber a lacuna ~70 %';

  @override
  String get cap3aHeadline => 'Este ano ainda conta';

  @override
  String get cap3aWhyNow =>
      'Um depósito 3a pode ainda reduzir os impostos e reforçar a reforma.';

  @override
  String get cap3aCtaLabel => 'Simular o meu 3a';

  @override
  String get capLppBuybackHeadline => 'Resgate LPP disponível';

  @override
  String capLppBuybackWhyNow(String amount) {
    return 'Podes resgatar até $amount e deduzir nos impostos.';
  }

  @override
  String get capLppBuybackCtaLabel => 'Simular um resgate';

  @override
  String get capLppBuybackExpectedImpact => 'dedução fiscal';

  @override
  String get capBudgetDeficitHeadline => 'A tua margem a recuperar';

  @override
  String get capBudgetDeficitWhyNow =>
      'O teu orçamento está apertado. Ajustar uma rubrica pode dar fôlego.';

  @override
  String get capBudgetDeficitCtaLabel => 'Ajustar o meu orçamento';

  @override
  String get capBudgetDeficitExpectedImpact => 'margem mensal';

  @override
  String get capReplacementRateHeadline => 'A tua reforma ainda está curta';

  @override
  String capReplacementRateWhyNow(String rate) {
    return '$rate % de taxa de substituição. Um resgate ou 3a muda a trajetória.';
  }

  @override
  String get capReplacementRateCtaLabel => 'Explorar os meus cenários';

  @override
  String get capReplacementRateExpectedImpact => '+4 a +7 pontos';

  @override
  String get capCoverageCheckSeniorHeadline =>
      'Invalidez depois dos 50 : um ponto cego ?';

  @override
  String get capCoverageCheckHeadline =>
      'A tua cobertura merece uma verificação';

  @override
  String get capCoverageCheckSeniorWhyNow =>
      'Depois dos 50, a lacuna entre rendimento e prestações AI + LPP pode ultrapassar 40 %. O teu IJM cobre o resto ?';

  @override
  String get capCoverageCheckWhyNow =>
      'IJM, AI, LPP invalidez — verifica que a tua rede aguenta.';

  @override
  String get capCoverageCheckCtaLabel => 'Verificar';

  @override
  String get capChomageHeadline => 'Proteger os próximos 90 dias';

  @override
  String get capChomageWhyNow =>
      'Desempregado : três urgências — os teus direitos AC, o impacto no LPP e ajustar o orçamento.';

  @override
  String get capChomageCtaLabel => 'Ver os meus direitos';

  @override
  String get capChomageExpectedImpact => 'estabilização imediata';

  @override
  String get capDivorceUrgencyHeadline => 'Divórcio : clarificar o que muda';

  @override
  String get capDivorceUrgencyWhyNow =>
      'Divisão LPP, pensão alimentícia, habitação — os impactos financeiros merecem uma avaliação clara.';

  @override
  String get capDivorceUrgencyCtaLabel => 'Simular o impacto';

  @override
  String get capDivorceUrgencyExpectedImpact => 'esclarecimento LPP + impostos';

  @override
  String get capLeMarriageHeadline => 'Casamento à vista';

  @override
  String get capLeMarriageWhyNow => 'Impostos, AVS, LPP, sucessão — tudo muda.';

  @override
  String get capLeMarriageCtaLabel => 'Ver o impacto';

  @override
  String get capLeDivorceHeadline => 'Divórcio em curso';

  @override
  String get capLeDivorceWhyNow => 'Divisão LPP, pensão, impostos — antecipa.';

  @override
  String get capLeDivorceCtaLabel => 'Simular';

  @override
  String get capLeBirthHeadline => 'Nascimento previsto';

  @override
  String get capLeBirthWhyNow => 'Subsídios, deduções, orçamento — prepara-te.';

  @override
  String get capLeBirthCtaLabel => 'Ver o impacto';

  @override
  String get capLeHousingPurchaseHeadline => 'Compra imobiliária';

  @override
  String get capLeHousingPurchaseWhyNow =>
      'EPL, 3a, hipoteca — tudo se decide agora.';

  @override
  String get capLeHousingPurchaseCtaLabel => 'Simular a minha capacidade';

  @override
  String get capLeJobLossHeadline => 'Perda de emprego';

  @override
  String get capLeJobLossWhyNow =>
      'Desemprego, LPP, orçamento — as 3 urgências.';

  @override
  String get capLeJobLossCtaLabel => 'Ver os meus direitos';

  @override
  String get capLeSelfEmploymentHeadline => 'Passagem à autonomia';

  @override
  String get capLeSelfEmploymentWhyNow =>
      'LPP voluntário, máx. 3a, IJM — reconstrói a tua rede.';

  @override
  String get capLeSelfEmploymentCtaLabel => 'Verificar a minha cobertura';

  @override
  String get capLeRetirementHeadline => 'Reforma no horizonte';

  @override
  String get capLeRetirementWhyNow =>
      'Capital ou renda, levantamento, timing — é o momento.';

  @override
  String get capLeRetirementCtaLabel => 'Explorar as minhas opções';

  @override
  String get capLeConcubinageHeadline => 'Vida em comum';

  @override
  String get capLeConcubinageWhyNow =>
      'Sem limite AVS 150 %, sem divisão LPP automática — antecipa.';

  @override
  String get capLeConcubinageCtaLabel => 'Ver as diferenças';

  @override
  String get capLeDeathOfRelativeHeadline => 'Perda de um ente querido';

  @override
  String get capLeDeathOfRelativeWhyNow =>
      'Sucessão, rendas de sobrevivência, prazos — o que é urgente.';

  @override
  String get capLeDeathOfRelativeCtaLabel => 'Ver os procedimentos';

  @override
  String get capLeNewJobHeadline => 'Novo posto';

  @override
  String get capLeNewJobWhyNow =>
      'LPP, livre passagem, 3a — três coisas a verificar.';

  @override
  String get capLeNewJobCtaLabel => 'Comparar';

  @override
  String get capLeHousingSaleHeadline => 'Venda imobiliária';

  @override
  String get capLeHousingSaleWhyNow =>
      'Mais-valia, reembolso EPL, reinvestimento — planeia.';

  @override
  String get capLeHousingSaleCtaLabel => 'Ver o impacto';

  @override
  String get capLeInheritanceHeadline => 'Herça recebida';

  @override
  String get capLeInheritanceWhyNow =>
      'Impostos, integração no património, resgate LPP — pondera.';

  @override
  String get capLeInheritanceCtaLabel => 'Ver as minhas opções';

  @override
  String get capLeDonationHeadline => 'Doação planeada';

  @override
  String get capLeDonationWhyNow =>
      'Adiantamento da herça, fiscalidade, relatório — antecipa.';

  @override
  String get capLeDonationCtaLabel => 'Ver o impacto';

  @override
  String get capLeDisabilityHeadline => 'Risco de invalidez';

  @override
  String get capLeDisabilityWhyNow =>
      'AI, LPP invalidez, IJM — verifica a tua rede.';

  @override
  String get capLeDisabilityCtaLabel => 'Verificar a minha cobertura';

  @override
  String get capLeCantonMoveHeadline => 'Mudança de cantão';

  @override
  String get capLeCantonMoveWhyNow =>
      'Impostos, LAMal, encargos — o impacto pode surpreender.';

  @override
  String get capLeCantonMoveCtaLabel => 'Comparar cantões';

  @override
  String get capLeCountryMoveHeadline => 'Saída da Suíça';

  @override
  String get capLeCountryMoveWhyNow =>
      'Livre passagem, AVS, 3a — o que te segue, o que fica.';

  @override
  String get capLeCountryMoveCtaLabel => 'Ver as consequências';

  @override
  String get capLeDebtCrisisHeadline => 'Situação de dívida';

  @override
  String get capLeDebtCrisisWhyNow =>
      'Priorizar, reestruturar, proteger o essencial — passo a passo.';

  @override
  String get capLeDebtCrisisCtaLabel => 'Ver o meu plano';

  @override
  String get capCouple3aHeadline => 'A dois, mais uma alavanca';

  @override
  String get capCouple3aWhyNow =>
      'O vosso agregado pode deduzir 2 × 7’258 CHF contribuindo cada um para o 3a. A conta do teu parceiro ainda não está registada.';

  @override
  String get capCouple3aCtaLabel => 'Simular o 3a de casal';

  @override
  String get capCouple3aExpectedImpact => 'até 14’516 CHF em deduções';

  @override
  String get capCoupleLppBuybackHeadline =>
      'Resgate LPP : a alavanca do parceiro';

  @override
  String capCoupleLppBuybackWhyNow(String amount) {
    return 'O teu parceiro tem um resgate possível de $amount. Priorizar a taxa marginal mais alta maximiza a dedução.';
  }

  @override
  String get capCoupleLppBuybackCtaLabel => 'Comparar resgates';

  @override
  String get capCoupleLppBuybackExpectedImpact =>
      'otimização fiscal do agregado';

  @override
  String get capCoupleAvsCapHeadline => 'AVS de casal : o teto dos 150 %';

  @override
  String get capCoupleAvsCapWhyNow =>
      'Casados, as vossas rendas AVS acumuladas são limitadas a 150 % da renda máxima (LAVS art. 35). A diferença pode chegar a ~10’000 CHF/ano.';

  @override
  String get capCoupleAvsCapCtaLabel => 'Ver o impacto AVS';

  @override
  String get capCoupleAvsCapExpectedImpact => 'perceber o delta ~10k/ano';

  @override
  String get capHonestyDebtHeadline =>
      'A tua situação merece um olhar especializado';

  @override
  String get capHonestyDebtWhyNow =>
      'As alavancas clássicas não chegam aqui. Um especialista em dívidas pode ajudar-te a construir um plano realista.';

  @override
  String get capHonestryCrossBorderHeadline => 'Façamos um balanço juntos';

  @override
  String get capHonestryCrossBorderWhyNow =>
      'No teu horizonte, as alavancas do 2.º pilar são limitadas. Um especialista transfronteiço pode identificar caminhos que o MINT ainda não cobre.';

  @override
  String get capHonestyNoLppHeadline => 'A tua base está lá';

  @override
  String get capHonestyNoLppWhyNow =>
      'As alavancas clássicas não mudam muito o quadro aqui. Um especialista pode ajudar-te a ver mais longe.';

  @override
  String get capHonestyCtaLabel => 'Falar com o coach';

  @override
  String get capHonestyExpectedImpact => 'esclarecimento';

  @override
  String get capHonestyDebtCoachPrompt =>
      'A minha dívida ultrapassa largamente o meu rendimento anual. Os simuladores já não bastam. Encaminha-me para um especialista em desendividamento.';

  @override
  String get capHonestyCrossBorderCoachPrompt =>
      'Sou fronteiriço/a perto da reforma sem LPP. Que opções realistas existem? Encaminha-me para um especialista.';

  @override
  String get capHonestyNoLppCoachPrompt =>
      'Aproximo-me da reforma com pouco 2.º pilar. Ajuda-me a perceber o que adquiri e encaminha-me para um especialista.';

  @override
  String capAcquiredAvsWithRente(String rente, String years) {
    return 'AVS : ~$rente CHF/mês ($years anos contribuídos)';
  }

  @override
  String capAcquiredAvsYearsOnly(String years) {
    return 'AVS : $years anos contribuídos';
  }

  @override
  String get capAcquiredAvsInProgress => 'AVS : direitos em curso';

  @override
  String capAcquiredLpp(String amount) {
    return 'LPP : $amount acumulado';
  }

  @override
  String capAcquired3a(String amount) {
    return '3a : $amount poupados';
  }

  @override
  String get capFallbackHeadline => 'Completa o teu perfil';

  @override
  String get capFallbackWhyNow =>
      'Quanto mais o MINT te conhece, mais precisas são as alavancas.';

  @override
  String get capFallbackCtaLabel => 'Enriquecer';

  @override
  String get pulseIndepLppTitle => 'CHF 0';

  @override
  String get pulseIndepLppSubtitle => 'Este é o teu 2.º pilar hoje.';

  @override
  String get pulseIndepLppDetail =>
      'Sem LPP, a tua reforma = AVS sozinha : ~CHF 1’934/mês.';

  @override
  String get pulseIndepLppCta => 'Construir a minha rede';

  @override
  String get pulseDebtSubtitle => 'de dívida a reembolsar.';

  @override
  String get pulseDebtCta => 'Ver o meu plano';

  @override
  String get pulseComprSalaireSubtitle =>
      'desaparecem do teu salário antes de chegar.';

  @override
  String get pulseComprSalaireDetail =>
      'AVS, LPP, AC, impostos — descobre para onde vai cada franco.';

  @override
  String get pulseComprSalaireCta => 'Perceber o meu recibo';

  @override
  String get pulseComprSystemeTitle => '3 pilares';

  @override
  String get pulseComprSystemeSubtitle => 'O sistema suíço em 1 minuto.';

  @override
  String get pulseComprSystemeDetail =>
      'AVS (Estado) + LPP (empregador) + 3a (tu) = a tua reforma.';

  @override
  String get pulseComprSystemeCta => 'Descobrir';

  @override
  String get pulseComprSituationTitle => 'A tua visibilidade financeira';

  @override
  String get pulseComprSituationSubtitle =>
      'O que sabes realmente da tua situação ?';

  @override
  String get pulseComprSituationDetail =>
      'Completa o teu perfil para afinar a tua pontuação.';

  @override
  String get pulseComprSituationCta => 'Ver a minha pontuação';

  @override
  String get pulseProtRetraiteCapRenteTitle => 'Capital ou Renda ?';

  @override
  String get pulseProtRetraiteCapRenteSubtitle => 'A escolha que muda tudo.';

  @override
  String get pulseProtRetraiteCapRenteDetail =>
      'Compara as duas opções com os teus números reais.';

  @override
  String get pulseProtRetraiteCapRenteCta => 'Comparar';

  @override
  String get pulseProtRetraiteSubtitle => 'conservado na reforma.';

  @override
  String get pulseProtRetraiteDetail => 'Mediana suíça : 60 %. Onde estás ?';

  @override
  String get pulseProtRetraiteCta => 'Ver a minha projeção';

  @override
  String get pulseProtFamilleSubtitle => 'A vossa reforma a dois.';

  @override
  String get pulseProtFamilleDetail =>
      'Antecipa a lacuna quando só um está reformado.';

  @override
  String get pulseProtFamilleCta => 'Ver a timeline';

  @override
  String get pulseProtUrgenceDebtSubtitle => 'a reembolsar.';

  @override
  String get pulseProtUrgenceDebtDetail => 'Começa pela taxa mais alta.';

  @override
  String get pulseProtUrgenceDebtCta => 'O meu plano de reembolso';

  @override
  String get pulseProtUrgenceTitle => 'A tua rede de segurança';

  @override
  String get pulseProtUrgenceSubtitle =>
      'O que acontece se já não puderes trabalhar ?';

  @override
  String get pulseProtUrgenceDetail =>
      'IJM, AI, LPP invalidez — verifica a tua cobertura.';

  @override
  String get pulseProtUrgenceCta => 'Verificar';

  @override
  String get pulseOptFiscalSubtitle => 'deixados ao fisco cada ano.';

  @override
  String get pulseOptFiscalDetail =>
      '3a + resgate LPP = as tuas alavancas mais poderosas.';

  @override
  String get pulseOptFiscalCta => 'Recuperar';

  @override
  String get pulseOptPatrimoineSubtitle => 'O teu património total.';

  @override
  String get pulseOptPatrimoineDetail => 'Poupança + LPP + 3a + investimentos.';

  @override
  String get pulseOptPatrimoineCtaLabel => 'Detalhe';

  @override
  String get pulseOptCapRenteTitle => 'Capital ou Renda ?';

  @override
  String get pulseOptCapRenteSubtitle =>
      'A diferença pode ultrapassar CHF 200’000.';

  @override
  String get pulseOptCapRenteDetail =>
      'Tributado uma vez (capital) vs cada ano (renda).';

  @override
  String get pulseOptCapRenteCta => 'Comparar';

  @override
  String get pulseNavExpatGapsSubtitle =>
      'de contribuições em falta no teu AVS.';

  @override
  String get pulseNavExpatGapsDetail =>
      'Cada ano em falta = -2.3 % de renda vitalicia.';

  @override
  String get pulseNavExpatGapsCta => 'Analisar as minhas lacunas';

  @override
  String get pulseNavExpatTitle => 'Novo na Suíça ?';

  @override
  String get pulseNavExpatSubtitle =>
      'Os teus direitos, as tuas lacunas, as armadilhas a evitar.';

  @override
  String get pulseNavExpatDetail =>
      'AVS, LPP, 3a — tudo o que conta desde a chegada.';

  @override
  String get pulseNavExpatCta => 'Descobrir';

  @override
  String get pulseNavAchatTitle => 'Comprar um imóvel';

  @override
  String get pulseNavAchatSubtitle => 'Calcula a tua capacidade de compra.';

  @override
  String get pulseNavAchatDetail =>
      'O teu 3a e LPP = o teu principal adiantamento.';

  @override
  String get pulseNavAchatCta => 'Simular';

  @override
  String get pulseNavAchatCapSubtitle => 'O imóvel que podes almejar.';

  @override
  String get pulseNavAchatCapCta => 'Simular a minha compra';

  @override
  String get pulseNavIndependantTitle => 'Autónomo·a ?';

  @override
  String get pulseNavIndependantSubtitle => 'Sem empregador, a tua rede = tu.';

  @override
  String get pulseNavIndependantDetail =>
      'LPP voluntário, máx. 3a 36’288/ano, IJM obrigatório.';

  @override
  String get pulseNavIndependantCta => 'Verificar a minha cobertura';

  @override
  String get pulseNavEvenementTitle => 'Uma mudança de vida ?';

  @override
  String get pulseNavEvenementSubtitle =>
      'Cada evento tem um impacto financeiro.';

  @override
  String get pulseNavEvenementDetail =>
      'Casamento, nascimento, divórcio, herça, mudança...';

  @override
  String get pulseNavEvenementCta => 'Explorar';

  @override
  String get reengagementTitleNewYear => 'Novos limites do 3a';

  @override
  String get reengagementTitleTaxPrep => 'Declaração fiscal';

  @override
  String get reengagementTitleTaxDeadline => 'Prazo fiscal';

  @override
  String get reengagementTitleThreeA => 'Prazo do 3a';

  @override
  String get reengagementTitleThreeAFinal => 'Último mês para o 3a';

  @override
  String get reengagementTitleQuarterlyFri => 'Pontuação de solidez';

  @override
  String get assurancesAlerteDelai =>
      'Lembrete : as alterações de franquia devem ser feitas antes do dia 30 de novembro de cada ano para o ano seguinte.';

  @override
  String get assurancesDisclaimerLamal =>
      'Esta análise é indicativa. Os prêmios variam conforme o segurador, a região e o modelo de seguro. Consulte a sua caixa de saúde para obter valores exatos. Fonte : LAMal art. 62-64, OAMal.';

  @override
  String get assurancesDisclaimerCoverage =>
      'Esta análise é indicativa e não constitui aconselhamento personalizado em seguros. Os prêmios variam conforme o segurador e o seu perfil. Consulte um·a especialista para uma avaliação completa.';

  @override
  String get recommendationsDisclaimer =>
      'Sugestões pedagógicas baseadas no seu perfil — ferramenta educativa que não constitui aconselhamento financeiro personalizado no sentido da LSFin. Consulte um·a especialista para uma análise adaptada à sua situação.';

  @override
  String get recommendationsTitleEmergencyFund =>
      'Constituir um fundo de emergência';

  @override
  String get recommendationsTitlePillar3a => 'Otimizar com o pilar 3a';

  @override
  String get recommendationsTitleLppBuyback => 'Simular uma compra LPP';

  @override
  String get recommendationsTitleCompoundInterest => 'O poder do tempo';

  @override
  String get recommendationsTitleStartDiagnostic => 'Inicia o teu diagnóstico';

  @override
  String get cantonalBenchmarkDisclaimer =>
      'Estes dados são ordens de grandeza derivadas de estatísticas federais anonimizadas (OFS). Não constituem aconselhamento financeiro. Nenhum dado pessoal é comparado com outros utilizadores. Ferramenta educativa : não constitui aconselhamento no sentido da LSFin.';

  @override
  String get scenarioLabelPrudent => 'Cenário prudente';

  @override
  String get scenarioLabelReference => 'Cenário de referência';

  @override
  String get scenarioLabelFavorable => 'Cenário favorável';

  @override
  String get scenarioDisclaimer =>
      'Ferramenta educativa — não constitui aconselhamento financeiro no sentido da LSFin. As projeções baseiam-se em hipóteses de rendimento e não predizem resultados futuros. Consulte um·a especialista para um plano personalizado.';

  @override
  String get bayesianDisclaimer =>
      'Estimativas bayesianas baseadas em estatísticas suíças (OFS/BFS). Estes valores são aproximações pedagógicas, não certezas. Não constitui aconselhamento financeiro no sentido da LSFin.';

  @override
  String get consentLabelByok => 'Personalização com IA';

  @override
  String get consentLabelSnapshot => 'Histórico de progresso';

  @override
  String get consentLabelNotifications => 'Lembretes personalizados';

  @override
  String get consentDashboardDisclaimer =>
      'Os seus dados pertencem-lhe. Cada parâmetro é revogável a qualquer momento (nLPD art. 6).';

  @override
  String get wizardValidationRequired => 'Esta questão é obrigatória';

  @override
  String get wizardAnswerNotProvided => 'Não fornecido';

  @override
  String get arbitrageTitleRenteVsCapital => 'Renda vs Capital';

  @override
  String get arbitrageMissingLpp =>
      'Adicione o seu saldo LPP para ver esta comparação';

  @override
  String get arbitrageTitleCalendrierRetraits => 'Calendário de levantamentos';

  @override
  String get arbitrageMissingLppAnd3a =>
      'Adicione o seu saldo LPP e 3a para ver o calendário';

  @override
  String get arbitrageTitleRachatVsMarche => 'Resgate LPP vs Mercado';

  @override
  String get arbitrageMissingLppCertificat =>
      'Digitalize o seu certificado LPP para conhecer a sua margem de resgate';

  @override
  String get reportTitleBilanFlash => 'O seu Balanço Flash';

  @override
  String get reportLabelSanteFinanciere => 'Saúde Financeira';

  @override
  String get retirementProjectionDisclaimer =>
      'Projeção educativa baseada nas tarifas AVS/LPP 2025. Não constitui aconselhamento financeiro ou previdenciário. Os valores são estimativas que podem variar consoante alterações legislativas e a situação pessoal. Consulte um especialista para um plano personalizado. LSFin.';

  @override
  String get retirementIncomeLabelPillar3a => '3º pilar';

  @override
  String get retirementIncomeLabelPatrimoine => 'Património livre';

  @override
  String get retirementPhaseLabelBothRetired => 'Ambos reformados';

  @override
  String get retirementPhaseLabelRetraite => 'Reforma';

  @override
  String get forecasterDisclaimer =>
      'Projeções educativas baseadas em pressupostos de rendimento. Não constitui aconselhamento financeiro. Os rendimentos passados não predizem os futuros. Consulte um especialista para um plano personalizado. LSFin.';

  @override
  String get forecasterEtSiDisclaimer =>
      'Simulação «E se...» apenas para fins educativos. Pressupostos de rendimento ajustados manualmente. Não constitui aconselhamento financeiro (LSFin). Os rendimentos passados não predizem os futuros.';

  @override
  String get lppRachatDisclaimerEchelonne =>
      'Simulação educativa baseada em taxas fiscais cantonais estimadas. O resgate LPP está sujeito à aprovação do fundo de pensões. A dedução anual está limitada ao rendimento tributável. Bloqueio EPL de 3 anos após cada resgate (LPP art. 79b al. 3). Consulte o seu fundo de pensões e um especialista antes de qualquer decisão.';

  @override
  String get lppLibrePassageDisclaimer =>
      'Esta informação é educativa e não constitui aconselhamento jurídico ou financeiro personalizado. As regras dependem do seu fundo de pensões e situação. Base legal: LFLP, OLP. Consulte um especialista em previdência profissional.';

  @override
  String get lppEplDisclaimer =>
      'Simulação educativa de caráter indicativo. O valor exato levanável depende do regulamento do seu fundo de pensões e do saldo aos 50 anos. O imposto varia consoante o cantão e a situação pessoal. Base legal: art. 30c LPP, OEPL. Consulte o seu fundo de pensões e um especialista antes de qualquer decisão.';

  @override
  String get lppChecklistTitleDecompte => 'Solicitar extrato de saída';

  @override
  String get lppChecklistDescDecompte =>
      'Solicite um extrato detalhado ao fundo de pensões com a repartição obrigatória/suplementar.';

  @override
  String get lppChecklistTitleTransfert30j => 'Transferir o saldo em 30 dias';

  @override
  String get lppChecklistDescTransfert30j =>
      'O saldo deve ser transferido para o novo fundo de pensões. Fornecer os dados do novo fundo ao anterior.';

  @override
  String get lppChecklistAlertTransfertTitle =>
      'Prazo de transferência próximo';

  @override
  String get lppChecklistAlertTransfertMsg =>
      'O saldo deve ser transferido em 30 dias. Contacte o seu antigo fundo de pensões rapidamente.';

  @override
  String get lppChecklistTitleOuvrirLP => 'Abrir uma conta de livre passage';

  @override
  String get lppChecklistDescOuvrirLP =>
      'Sem novo empregador, o saldo deve ser depositado em uma ou duas contas de livre passage (máx. 2 por lei).';

  @override
  String get lppChecklistTitleChoisirLP =>
      'Escolher entre conta bancária e apólice de livre passage';

  @override
  String get lppChecklistDescChoisirLP =>
      'A conta bancária oferece mais flexibilidade. A apólice de seguro pode incluir cobertura de risco.';

  @override
  String get lppChecklistTitleVerifierDestination =>
      'Verificar as regras de levantamento consoante o país de destino';

  @override
  String get lppChecklistDescVerifierDestination =>
      'UE/EFTA: apenas a parte suplementar pode ser levantada em dinheiro. A parte obrigatória permanece na Suíça. Fora da UE/EFTA: levantamento total possível.';

  @override
  String get lppChecklistTitleAnnoncerDepart =>
      'Notificar o fundo de pensões da saída';

  @override
  String get lppChecklistDescAnnoncerDepart =>
      'Informe o seu fundo nos 30 dias seguintes à saída.';

  @override
  String get lppChecklistAlertTransfert6mTitle =>
      'Transferência a efetuar em 6 meses';

  @override
  String get lppChecklistAlertTransfert6mMsg =>
      'Após deixar a Suíça, tem 6 meses para transferir o saldo ou abrir uma conta de livre passage.';

  @override
  String get lppChecklistTitleChomage => 'Verificar os direitos ao desemprego';

  @override
  String get lppChecklistDescChomage =>
      'Em caso de desemprego, a previdência profissional continua através da instituição supletiva (Fundação LPP).';

  @override
  String get lppChecklistTitleAvoirs => 'Procurar saldos esquecidos';

  @override
  String get lppChecklistDescAvoirs =>
      'Utilize a Central do 2º Pilar (sfbvg.ch) para procurar eventuais saldos de livre passage esquecidos.';

  @override
  String get lppChecklistTitleCouverture =>
      'Verificar a cobertura de risco transitória';

  @override
  String get lppChecklistDescCouverture =>
      'Durante o período de livre passage, a cobertura em caso de morte e invalidez pode ser reduzida. Verifique os seus contratos.';

  @override
  String get pillar3aStaggeredDisclaimer =>
      'Simulação educativa de caráter indicativo. O imposto sobre o levantamento de capital depende do cantão, município, situação pessoal e do total levantado no ano fiscal. As taxas utilizadas são médias cantonais simplificadas. Base legal: OPP3, LIFD art. 38. Consulte um especialista antes de qualquer decisão.';

  @override
  String get pillar3aRealReturnDisclaimer =>
      'Simulação educativa baseada em pressupostos de rendimento constante. Os rendimentos passados não predizem os futuros. Comissões e rendimentos variam consoante o prestador. A poupança fiscal depende da taxa marginal real. Base legal: OPP3, LIFD art. 33 al. 1 let. e. Consulte um especialista antes de qualquer decisão.';

  @override
  String get pillar3aProviderDisclaimer =>
      'Os rendimentos passados não predizem os futuros. Comissões e rendimentos médios baseiam-se em dados históricos simplificados para fins educativos. A escolha de um prestador 3a depende da situação pessoal, perfil de risco e horizonte de investimento. A MINT não é um intermediário financeiro e não presta aconselhamento de investimento. Consulte um especialista.';

  @override
  String get reportDisclaimerBase1 =>
      'Ferramenta educativa — não constitui aconselhamento financeiro na aceção da LSFin.';

  @override
  String get reportDisclaimerBase2 =>
      'Os valores são estimativas baseadas nos dados declarados.';

  @override
  String get reportDisclaimerBase3 =>
      'Os resultados passados não predizem os resultados futuros.';

  @override
  String get reportDisclaimerFiscal =>
      'A estimativa fiscal é aproximada e não substitui uma declaração de impostos.';

  @override
  String get reportDisclaimerRetraite =>
      'A projeção de reforma é indicativa e depende de alterações legislativas (reformas AVS/LPP).';

  @override
  String get reportDisclaimerRachatLpp =>
      'O resgate LPP está sujeito a um bloqueio de 3 anos para levantamentos EPL (LPP art. 79b al. 3).';

  @override
  String get reportActionTitle3aFirst => 'Abre a tua primeira conta 3a';

  @override
  String get reportActionDesc3aFirst =>
      'Deduz até CHF 7’258/ano do rendimento tributável. Poupança imediata.';

  @override
  String get reportActionTitle3aSecond => 'Abre uma 2ª conta 3a fintech';

  @override
  String get reportActionDesc3aSecond =>
      'Otimiza a fiscalidade no levantamento e diversifica os investimentos.';

  @override
  String get reportActionTitleAvsCheck => 'Verifica a tua conta AVS';

  @override
  String get reportActionDescAvsCheck =>
      'Evita perder até CHF 38’000 de pensão ao longo da vida.';

  @override
  String get reportActionTitleDette => 'Reembolsa as tuas dívidas de consumo';

  @override
  String get reportActionDescDette =>
      'É o investimento mais rentável: poupes 6-10 % ao ano em juros.';

  @override
  String get reportActionTitleUrgence => 'Constitui o teu fundo de emergência';

  @override
  String get reportActionDescUrgence =>
      'Aponta a 3 meses de despesas numa conta poupança separada.';

  @override
  String get reportRoadmapPhaseImmediat => 'Imediato';

  @override
  String get reportRoadmapTimeframeImmediat => 'Este mês';

  @override
  String get reportRoadmapPhaseCourtTerme => 'Curto Prazo';

  @override
  String get reportRoadmapTimeframeCourtTerme => '3-6 meses';

  @override
  String get visibilityNarrativeHigh =>
      'Tens uma visão clara da tua situação. Mantém os teus dados atualizados.';

  @override
  String visibilityNarrativeMediumHigh(String axisLabel) {
    return 'Boa visibilidade! Refina a tua $axisLabel para ir mais longe.';
  }

  @override
  String visibilityNarrativeMedium(String axisLabel) {
    return 'Estás a começar a ver com mais clareza. Concentra-te na tua $axisLabel.';
  }

  @override
  String visibilityNarrativeLow(String hint) {
    return 'Cada informação conta. Começa por $hint.';
  }

  @override
  String get visibilityAxisLabelLiquidite => 'Liquidez';

  @override
  String get visibilityAxisLabelFiscalite => 'Fiscalidade';

  @override
  String get visibilityAxisLabelRetraite => 'Reforma';

  @override
  String get visibilityAxisLabelSecurite => 'Segurança';

  @override
  String get visibilityHintAddSalaire => 'Adiciona o teu salário para começar';

  @override
  String get visibilityHintAddEpargne =>
      'Indica as tuas poupanças e investimentos';

  @override
  String get visibilityHintLiquiditeComplete =>
      'Os teus dados de liquidez estão completos';

  @override
  String get visibilityHintAddAgeCanton =>
      'Indica a tua idade e cantão de residência';

  @override
  String get visibilityHintScanFiscal => 'Digitaliza a tua declaração fiscal';

  @override
  String get visibilityHintFiscaliteComplete =>
      'Os teus dados fiscais estão completos';

  @override
  String get visibilityHintAddLpp => 'Adiciona o teu certificado LPP';

  @override
  String get visibilityHintCommandeAvs => 'Solicita o teu extrato AVS';

  @override
  String get visibilityHintAdd3a => 'Indica as tuas contas 3a';

  @override
  String get visibilityHintRetraiteComplete =>
      'Os teus dados de reforma estão completos';

  @override
  String get visibilityHintAddFamille => 'Indica a tua situação familiar';

  @override
  String get visibilityHintAddStatutPro => 'Completa o teu estado profissional';

  @override
  String get visibilityHintSecuriteComplete =>
      'Os teus dados de segurança estão completos';

  @override
  String get exploreHubRetraiteIntro =>
      'Cada ano que passa muda as tuas opções. Eis onde estás.';

  @override
  String get exploreHubFamilleIntro =>
      'Casamento, nascimento, separação: cada marco tem um impacto financeiro.';

  @override
  String get exploreHubTravailIntro =>
      'O teu estado profissional determina os teus direitos. Verifica-os.';

  @override
  String get exploreHubLogementIntro =>
      'Comprar, alugar, mudar: os números antes da decisão.';

  @override
  String get exploreHubFiscaliteIntro =>
      'Cada franco deduzido é um franco ganho. Encontra as tuas alavancas.';

  @override
  String get exploreHubPatrimoineIntro =>
      'O que transmites merece tanta atenção quanto o que ganhas.';

  @override
  String get exploreHubSanteIntro =>
      'A tua cobertura protege-te — ou custa demasiado. Verifica.';

  @override
  String get exploreTalkToMint => 'Falar com o MINT';

  @override
  String get dossierSettingsTitle => 'Definições';

  @override
  String get dossierEnrichmentHint => 'Para melhorar a precisão:';

  @override
  String get pulseBudgetATitle => 'Hoje';

  @override
  String get pulseBudgetBTitle => 'Na reforma';

  @override
  String get pulseBudgetRevenu => 'Rendimento';

  @override
  String get pulseBudgetCharges => 'Encargos';

  @override
  String get pulseBudgetLibre => 'Livre';

  @override
  String get pulseBudgetRetirementNet => 'Líquido reforma';

  @override
  String get pulseBudgetGap => 'Diferença';

  @override
  String get sim3aTaxRateChipsLabel => 'Taxa marginal de imposto';

  @override
  String get sim3aReturnChipsLabel => 'Rendimento esperado';

  @override
  String get sim3aYearsAutoLabel => 'Anos até à reforma';

  @override
  String get sim3aContributionFieldLabel => 'Contribuição anual';

  @override
  String get sim3aProfilePreFilled => 'Preenchido a partir do teu perfil';

  @override
  String sim3aProfileEstimatedRate(String rate, String canton) {
    return 'A tua taxa marginal estimada: $rate% ($canton)';
  }

  @override
  String sim3aYearsReadOnly(int years) {
    return '$years anos (calculado a partir da tua idade)';
  }

  @override
  String get renteVsCapitalRetirementAgeChips => 'Idade de reforma';

  @override
  String get renteVsCapitalLifeExpectancyChips => 'Esperança de vida';

  @override
  String get budgetEnvelopeFieldHint => 'Montante em CHF';

  @override
  String get budgetEnvelopeFieldFuture => 'Poupança futura (CHF/mês)';

  @override
  String get budgetEnvelopeFieldVariables => 'Despesas variáveis (CHF/mês)';

  @override
  String get retroactive3aYearsChipsLabel => 'Anos a recuperar';

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
  String get lightningMenuPayslipTitle => 'Compreender o meu recibo de salário';

  @override
  String get lightningMenuPayslipSubtitle =>
      'Bruto, líquido, deduções: tudo claro';

  @override
  String get lightningMenuPayslipAction => 'Explica-me o meu recibo de salário';

  @override
  String get lightningMenuThreePillarsTitle => 'O que são os 3 pilares?';

  @override
  String get lightningMenuThreePillarsSubtitle =>
      'O sistema suíço em 2 minutos';

  @override
  String get lightningMenuThreePillarsAction =>
      'O que são os 3 pilares suíços?';

  @override
  String get lightningMenuScanDocTitle => 'Digitalizar um documento';

  @override
  String get lightningMenuScanDocSubtitle =>
      'Certificado LPP, recibo, impostos';

  @override
  String get lightningMenuFirstBudgetTitle => 'O meu primeiro orçamento';

  @override
  String get lightningMenuFirstBudgetSubtitle =>
      'Saber para onde vai o teu dinheiro cada mês';

  @override
  String get lightningMenuFirstBudgetAction =>
      'Ajuda-me a fazer o meu orçamento';

  @override
  String get lightningMenuTaxReliefTitle => 'Onde reduzir impostos';

  @override
  String get lightningMenuTaxReliefSubtitle => 'Deduções e alavancas fiscais';

  @override
  String get lightningMenuTaxReliefAction => 'Como pagar menos impostos?';

  @override
  String get lightningMenuCompleteProfileTitle => 'Completar o perfil';

  @override
  String get lightningMenuCompleteProfileSubtitle =>
      'Quanto mais preciso, mais justo é o MINT';

  @override
  String get lightningMenuLppBuybackTitle => 'Resgatar LPP';

  @override
  String get lightningMenuLppBuybackSubtitle =>
      'Uma alavanca fiscal muitas vezes subestimada';

  @override
  String get lightningMenuLppBuybackAction => 'Vale a pena um resgate LPP?';

  @override
  String get lightningMenuLivingBudgetTitle => 'O meu orçamento vivo';

  @override
  String get lightningMenuLivingBudgetSubtitle =>
      'O teu equilíbrio este mês, atualizado';

  @override
  String get lightningMenuLivingBudgetAction => 'Onde estou?';

  @override
  String get budgetSnapshotTitle => 'O teu orçamento vivo';

  @override
  String get budgetSnapshotPresentLabel => 'Livre hoje';

  @override
  String get budgetSnapshotRetirementLabel => 'Livre na reforma';

  @override
  String get budgetSnapshotGapLabel => 'Lacuna';

  @override
  String get budgetSnapshotConfidenceLabel => 'Fiabilidade';

  @override
  String get budgetSnapshotConfidenceLow => 'Adiciona dados para refinar.';

  @override
  String get budgetSnapshotConfidenceOk => 'Estimativa credível.';

  @override
  String get budgetSnapshotLeverLabel => 'Alavanca';

  @override
  String get budgetSnapshotFreeLabel => 'O teu livre mensal';

  @override
  String get onboardingSmartTitle =>
      'Descobre a tua situação de reforma em 30 segundos';

  @override
  String get onboardingSmartSubtitle =>
      'Algumas informações bastam para uma primeira visão personalizada.';

  @override
  String get onboardingSmartFirstNameLabel => 'Como te chamas?';

  @override
  String get onboardingSmartFirstNameHint => 'O teu nome (opcional)';

  @override
  String get onboardingSmartAgeDirectInput => 'Entrada direta';

  @override
  String get onboardingSmartSeeResult => 'Ver o meu resultado';

  @override
  String get onboardingSmartDisclaimer =>
      'Ferramenta educativa — não constitui aconselhamento financeiro (LSFin). As estimativas baseiam-se nas tabelas de 2025 e podem variar.';

  @override
  String get onboardingSmartAgePickerHint => 'Escolhe a tua idade';

  @override
  String get onboardingSmartCountryOrigin => 'O teu país de origem';

  @override
  String get onboardingSmartCantonTitle => 'Escolhe o teu cantão';

  @override
  String get onboardingSmartCantonNotFound => 'Nenhum cantão encontrado';

  @override
  String get onboardingSmartSalaryLabel => 'O teu salário bruto anual';

  @override
  String get onboardingSmartAgeLabel => 'A tua idade';

  @override
  String get onboardingSmartEmploymentLabel => 'A tua situação profissional';

  @override
  String get onboardingSmartNationalityLabel => 'A tua nacionalidade';

  @override
  String get onboardingSmartCantonLabel => 'O teu cantão';

  @override
  String get onboardingAgeInvalid => 'A idade deve estar entre 18 e 75';

  @override
  String get onboardingSmartCantonSearch => 'Pesquisar (ex. VD, Vaud)';

  @override
  String get onboardingSmartSalaryPerYear => 'CHF/ano';

  @override
  String get greetingMorning => 'Bom dia';

  @override
  String get greetingAfternoon => 'Boa tarde';

  @override
  String get greetingEvening => 'Boa noite';

  @override
  String get authShowPassword => 'Mostrar palavra-passe';

  @override
  String get authHidePassword => 'Ocultar palavra-passe';

  @override
  String get exploreHubRetraiteIntro55plus =>
      'A reforma aproxima-se: cada decisão conta a dobrar. Eis onde estás.';

  @override
  String get exploreHubRetraiteIntro40plus =>
      'Cada ano que passa muda as tuas opções. Eis onde estás.';

  @override
  String get exploreHubRetraiteIntroYoung =>
      'É longe, mas é agora que importa. Eis porquê.';

  @override
  String get exploreHubTravailIntro55plus =>
      'Fim de carreira, reforma antecipada, transição: os teus direitos mudam.';

  @override
  String get exploreHubTravailIntro40plus =>
      'O teu estatuto profissional determina os teus direitos. Verifica-os.';

  @override
  String get exploreHubTravailIntroYoung =>
      'Primeiro emprego, independente, fronteiriço: cada estatuto tem as suas regras.';

  @override
  String get exploreHubLogementIntro55plus =>
      'Ficar, vender, transmitir: os números antes da decisão.';

  @override
  String get exploreHubLogementIntro40plus =>
      'Comprar, alugar, mudar: os números antes da decisão.';

  @override
  String get exploreHubLogementIntroYoung =>
      'Primeira compra ou aluguer: compreender as regras do jogo.';

  @override
  String get archetypeSwissNative => 'Residente suíço/a';

  @override
  String get archetypeExpatEu => 'Expat UE/EFTA';

  @override
  String get archetypeExpatNonEu => 'Expat fora da UE';

  @override
  String get archetypeExpatUs => 'Residente nos EUA (FATCA)';

  @override
  String get archetypeIndependentWithLpp => 'Independente com LPP';

  @override
  String get archetypeIndependentNoLpp => 'Independente sem LPP';

  @override
  String get archetypeCrossBorder => 'Fronteiriço/a';

  @override
  String get archetypeReturningSwiss => 'Suíço/a de regresso';

  @override
  String get employmentSalarie => 'Assalariado/a';

  @override
  String get employmentIndependant => 'Independente';

  @override
  String get employmentSansEmploi => 'Sem emprego';

  @override
  String get employmentRetraite => 'Reformado/a';

  @override
  String get nationalitySuisse => 'Suíça';

  @override
  String get nationalityEuAele => 'UE/EFTA';

  @override
  String get nationalityAutre => 'Outro';

  @override
  String get stepStressTitle => 'O que mais te preocupa?';

  @override
  String get stepStressSubtitle =>
      'Escolhe um tema — vamos personalizar a tua experiência.';

  @override
  String get stepStressRetirement => 'A minha reforma';

  @override
  String get stepStressRetirementSub => 'Terei o suficiente para viver?';

  @override
  String get stepStressTaxes => 'Os meus impostos';

  @override
  String get stepStressTaxesSub => 'Estou a pagar demais?';

  @override
  String get stepStressBudget => 'O meu orçamento';

  @override
  String get stepStressBudgetSub => 'Para onde vai o meu dinheiro?';

  @override
  String get stepStressWealth => 'O meu património';

  @override
  String get stepStressWealthSub => 'Como fazê-lo crescer?';

  @override
  String get stepStressCouple => 'Em casal';

  @override
  String get stepStressCoupleSub => 'Otimizar a dois';

  @override
  String get stepStressCurious => 'Apenas curioso';

  @override
  String get stepStressCuriousSub => 'Quero compreender a minha situação';

  @override
  String get stepStressDisclaimer =>
      'Ferramenta educativa — não constitui aconselhamento financeiro (LSFin).';

  @override
  String get stepNextTitle => 'O teu primeiro balanço está pronto';

  @override
  String stepNextConfidence(int pct) {
    return 'Precisão atual: $pct %. Quanto mais completares o teu perfil, mais fiáveis serão as projeções.';
  }

  @override
  String get stepNextEnrich => 'Refinar o meu perfil';

  @override
  String get stepNextDashboard => 'Ver o meu dashboard';

  @override
  String get stepNextCheckin => 'Fazer o meu primeiro check-in';

  @override
  String get stepNextDisclaimer =>
      'Ferramenta educativa simplificada. Não constitui aconselhamento financeiro (LSFin). Fontes: LAVS art. 34, LPP art. 14-16, OPP3 art. 7.';

  @override
  String get stepTopActionsTitle => 'As tuas 3 ações prioritárias';

  @override
  String get stepTopActionsSubtitle =>
      'Com base na tua situação, aqui é por onde começar.';

  @override
  String get stepTopActionsEmpty =>
      'Completa o teu perfil para receber ações personalizadas.';

  @override
  String get stepTopActionsContinue => 'Continuar';

  @override
  String get stepTopActionsBack => 'Voltar';

  @override
  String stepTopActionsImpact(String amount) {
    return 'Impacto estimado: $amount';
  }

  @override
  String get stepTopActionsDisclaimer =>
      'Sugestões educativas. Não constitui aconselhamento financeiro (LSFin). Consulta um especialista para um plano personalizado.';

  @override
  String stepChocConfidenceInfo(int count) {
    return 'Estimativa baseada em $count informações. Quanto mais precisares, mais fiável.';
  }

  @override
  String stepChocConfidenceLabel(int pct) {
    return 'Precisão: $pct %';
  }

  @override
  String get stepChocLiteracyTitle => 'Para personalizar os teus conselhos';

  @override
  String get stepChocLiteracySubtitle =>
      '3 perguntas rápidas — sem resposta certa ou errada.';

  @override
  String get stepChocLiteracyLpp => 'Conheço o montante do meu capital LPP';

  @override
  String get stepChocLiteracyConversion => 'Sei o que é a taxa de conversão';

  @override
  String get stepChocLiteracy3a => 'Já contribuí para uma conta 3a';

  @override
  String get stepChocYes => 'Sim';

  @override
  String get stepChocNo => 'Não';

  @override
  String get stepChocAction => 'O que posso fazer?';

  @override
  String get stepChocEnrich => 'Refinar o meu perfil';

  @override
  String get stepChocDashboard => 'Ver o meu dashboard';

  @override
  String get stepChocDisclaimer =>
      'Ferramenta educativa simplificada. Não constitui aconselhamento financeiro (LSFin). Fontes: LAVS art. 34, LPP art. 14-16, OPP3 art. 7.';

  @override
  String get stepChocPedagogicalCaveat =>
      'Estimativa ilustrativa baseada em dados parciais. Enriqueça o seu perfil para valores mais precisos.';

  @override
  String get stepJitTitle => 'Compreender em 30 segundos';

  @override
  String get stepJitSi => 'SE';

  @override
  String get stepJitAlors => 'ENTÃO';

  @override
  String get stepJitAction => 'O que posso fazer?';

  @override
  String get stepJitBack => 'Voltar';

  @override
  String get stepJitDisclaimer =>
      'Ferramenta educativa simplificada. Não constitui aconselhamento financeiro (LSFin).';

  @override
  String get stepJitLiquidityCond =>
      'as tuas poupanças de emergência cobrem menos de 2 meses de despesas';

  @override
  String get stepJitLiquidityCons =>
      'um imprevisto (perda de emprego, reparação urgente) pode colocar-te em dificuldade financeira rapidamente.';

  @override
  String get stepJitLiquidityInsight =>
      'Os especialistas recomendam 3 a 6 meses de despesas fixas em reserva. Mesmo CHF 100/mês numa conta poupança faz uma diferença significativa em 12 meses.';

  @override
  String get stepJitLiquiditySource =>
      'Recomendação de consultoria orçamental Suíça';

  @override
  String get stepJitRetirementCond =>
      'a tua taxa de substituição na reforma está abaixo de 60 %';

  @override
  String get stepJitRetirementCons =>
      'o teu nível de vida pode diminuir significativamente quando parares de trabalhar.';

  @override
  String get stepJitRetirementInsight =>
      'Na Suíça, o AVS e a LPP cobrem em média 60 % do último salário. O 3º pilar e a poupança livre preenchem o restante. Quanto mais cedo começares, menor o esforço mensal.';

  @override
  String get stepJitRetirementSource => 'LAVS art. 34 / LPP art. 14';

  @override
  String get stepJitTax3aCond =>
      'não contribuís o máximo para o teu 3º pilar todos os anos';

  @override
  String get stepJitTax3aCons =>
      'estás a perder uma poupança fiscal e um capital de reforma adicional.';

  @override
  String get stepJitTax3aInsight =>
      'Cada franco contribuído para o 3a é dedutível do rendimento tributável. Em 20 anos, a diferença entre contribuir 0 e o máximo (CHF 7\'258) pode ultrapassar CHF 200\'000.';

  @override
  String get stepJitTax3aSource => 'OPP3 art. 7 / LIFD art. 33';

  @override
  String get stepJitIncomeCond =>
      'a tua projeção de rendimento na reforma está estimada';

  @override
  String get stepJitIncomeCons =>
      'conhecer este montante permite-te planear e ajustar a tua estratégia de previdência agora.';

  @override
  String get stepJitIncomeInsight =>
      'O sistema suíço de 3 pilares (AVS + LPP + 3a) cobre em média 60 % do último salário. Cada pilar tem as suas regras e alavancas de otimização específicas.';

  @override
  String get stepJitIncomeSource => 'LAVS art. 34 / LPP art. 14 / OPP3 art. 7';

  @override
  String get stepJitDefaultCond =>
      'ainda não tens um plano financeiro estruturado';

  @override
  String get stepJitDefaultCons =>
      'arriscas perder oportunidades de otimização fiscal e de previdência.';

  @override
  String get stepJitDefaultInsight =>
      'Um balanço financeiro anual permite identificar as alavancas mais impactantes: 3a, resgate LPP, franquia LAMal, amortização indireta.';

  @override
  String get stepJitDefaultSource => 'Recomendação educativa MINT';

  @override
  String get stepOcrTitle => 'Enriquece o teu perfil em 30 segundos';

  @override
  String get stepOcrSkip => 'Continuar sem documento';

  @override
  String get stepOcrIntro =>
      'Digitaliza um ou mais documentos para que o MINT calcule a tua situação com mais precisão.';

  @override
  String get stepOcrLppTitle => 'A tua carta de reforma LPP';

  @override
  String get stepOcrLppSubtitle =>
      'Capital, taxa de conversão, lacuna de resgate';

  @override
  String get stepOcrLppBoost => '+27 pts de precisão';

  @override
  String get stepOcrAvsTitle => 'O teu extrato AVS';

  @override
  String get stepOcrAvsSubtitle => 'Anos de contribuição, lacunas, RAMD';

  @override
  String get stepOcrAvsBoost => '+22 pts de precisão';

  @override
  String get stepOcrTaxTitle => 'A tua declaração fiscal';

  @override
  String get stepOcrTaxSubtitle =>
      'Rendimento tributável, património, taxa marginal';

  @override
  String get stepOcrTaxBoost => '+17 pts de precisão';

  @override
  String get stepOcr3aTitle => 'A tua conta 3a';

  @override
  String get stepOcr3aSubtitle => 'Saldo, contribuições acumuladas, rendimento';

  @override
  String get stepOcr3aBoost => '+7 pts de precisão';

  @override
  String get stepOcrScanned => 'Digitalizado';

  @override
  String stepOcrContinueWith(int count, String plural) {
    return 'Continuar ($count documento$plural digitalizado$plural)';
  }

  @override
  String get stepOcrContinueWithout => 'Continuar sem documento';

  @override
  String get stepOcrDisclaimer =>
      'Ferramenta educativa — não constitui aconselhamento financeiro (LSFin). Documentos processados no teu dispositivo, nenhum dado enviado (LPD art. 6).';

  @override
  String get stepOcrLpdBanner =>
      'Os teus documentos são processados no teu dispositivo. Nada é enviado para a Internet.';

  @override
  String get stepOcrLpdTitle => 'Processamento privado no teu dispositivo';

  @override
  String get stepOcrLpdBody =>
      'Este documento é analisado diretamente no teu telefone.\nNenhum dado é enviado pela Internet.\nAs informações extraídas são eliminadas após o processamento.';

  @override
  String get stepOcrLpdLegal =>
      'Base legal: LPD art. 6 — minimização de dados.';

  @override
  String get stepOcrLpdScan => 'Digitalizar este documento';

  @override
  String get stepOcrLpdCancel => 'Cancelar';

  @override
  String stepOcrSnackSuccess(int count, String plural) {
    return '$count campo$plural extraído$plural com sucesso';
  }

  @override
  String get stepOcrSnackEmpty =>
      'Documento processado — nenhum campo reconhecido automaticamente';

  @override
  String stepOcrSnackError(String error) {
    return 'Erro de processamento: $error';
  }

  @override
  String get stepOcrSnackWebOnly =>
      'Digitalização de imagem não disponível na web. Usa a app móvel ou importa um ficheiro .txt.';

  @override
  String stepQuestionsAgeYears(int age) {
    return '$age anos';
  }

  @override
  String get stepQuestionsCountryUs => 'Estados Unidos';

  @override
  String get stepQuestionsCountryGb => 'Reino Unido';

  @override
  String get stepQuestionsCountryCa => 'Canadá';

  @override
  String get stepQuestionsCountryIn => 'Índia';

  @override
  String get stepQuestionsCountryCn => 'China';

  @override
  String get stepQuestionsCountryBr => 'Brasil';

  @override
  String get stepQuestionsCountryAu => 'Austrália';

  @override
  String get stepQuestionsCountryJp => 'Japão';

  @override
  String get householdAcceptCodeHint => 'CODE';

  @override
  String get friInsufficientData =>
      'Completa o teu perfil para ver a tua pontuação';

  @override
  String projectionUncertaintyBand(String low, String high) {
    return 'CHF $low — $high / mês';
  }

  @override
  String get portfolioAppBarTitle => 'O meu património';

  @override
  String get portfolioValeurTotaleNette => 'Valor total líquido';

  @override
  String get portfolioRepartitionEnveloppe => 'Distribuição por envelope';

  @override
  String get portfolioLibrePlacement => 'Livre (Conta de investimento)';

  @override
  String get portfolioLiePilier3a => 'Vinculado (Pilar 3a)';

  @override
  String get portfolioReserveFondsUrgence => 'Reservado (Fundo de emergência)';

  @override
  String get portfolioSafeModeLocked => 'Prioridade ao desendividamento';

  @override
  String get portfolioSafeModeBody =>
      'Os conselhos de alocação estão desativados em modo de proteção. A tua prioridade é reduzir as dívidas antes de reequilibrar o patrimônio.';

  @override
  String get byokShowKey => 'Mostrar chave';

  @override
  String get byokHideKey => 'Ocultar chave';

  @override
  String get themeDetailEssentiel60s => 'O essencial em 60 segundos';

  @override
  String get themeDetailTesteConnaissances => 'Testa os teus conhecimentos';

  @override
  String get themeDetailSavaisTu => 'Sabias que?';

  @override
  String get themeDetailSourcesLegales => 'Fontes legais';

  @override
  String get themeDetailRappel => 'Lembrete';

  @override
  String get themeDetailBienVu => 'Bem visto!';

  @override
  String get themeDetailPasToutAFait => 'Não é bem assim...';

  @override
  String get emergencyFundTitle => 'A tua rede de segurança';

  @override
  String get emergencyFundSubtitle => 'Calcula o teu fundo de emergência ideal';

  @override
  String get emergencyFundDisclaimer =>
      'O objetivo de 3-6 meses é uma recomendação geral. A tua situação pessoal pode exigir um montante diferente.';

  @override
  String get emergencyFundHyp1 =>
      'Encargos fixos = renda + seguros + assinaturas + créditos';

  @override
  String get emergencyFundHyp2 =>
      'Objetivo recomendado: 3 meses (mínimo) a 6 meses (conforto)';

  @override
  String get emergencyFundHyp3 =>
      'Colocação sugerida: conta poupança acessível, não investida';

  @override
  String get emergencyFundChargesLabel => 'Os teus encargos fixos mensais';

  @override
  String get emergencyFundChargesDesc =>
      'Renda + seguros + assinaturas + créditos';

  @override
  String get emergencyFundObjectifLabel => 'Objetivo em meses de segurança';

  @override
  String emergencyFundMoisUnit(int count) {
    return '$count meses';
  }

  @override
  String get emergencyFundMinimum => 'Mínimo';

  @override
  String get emergencyFundConfort => 'Conforto';

  @override
  String get emergencyFundObjectifTitle =>
      'O teu objetivo de fundo de emergência';

  @override
  String get emergencyFundProgression => 'O teu progresso';

  @override
  String emergencyFundManque(String amount) {
    return 'Faltam-te $amount';
  }

  @override
  String get emergencyFundAtteint => 'Objetivo atingido!';

  @override
  String get emergencyFundExplication =>
      'Este fundo protege-te de imprevistos (perda de emprego, doença, reparações) sem tocar nos teus investimentos.';

  @override
  String get lifeEventSuggestionsHeader => 'E depois?';

  @override
  String get lifeEventSuggestionsSubheader => 'Módulos adaptados ao teu perfil';

  @override
  String get lifeEventSuggestionsSimuler => 'Simular';

  @override
  String get lifeEventSugMariage => 'Casamento';

  @override
  String get lifeEventSugMariageReason =>
      'Descobre o impacto fiscal e na previdência';

  @override
  String get lifeEventSugConcubinage => 'União de facto';

  @override
  String get lifeEventSugConcubinageReason =>
      'Atenção: sem proteção legal automática';

  @override
  String get lifeEventSugNaissance => 'Nascimento';

  @override
  String get lifeEventSugNaissanceReason =>
      'Simula o impacto financeiro de um filho';

  @override
  String get lifeEventSugSuccession => 'Planeamento sucessório';

  @override
  String get lifeEventSugSuccessionReason =>
      'Quotas hereditárias e porção disponível (CC art. 470)';

  @override
  String get lifeEventSugDonation => 'Doação entre vivos';

  @override
  String get lifeEventSugDonationReason =>
      'Antecipa a tua sucessão e otimiza a fiscalidade';

  @override
  String get lifeEventSugPremierEmploi => 'Primeiro emprego';

  @override
  String get lifeEventSugPremierEmploiReason =>
      'Lança as bases: AVS, LPP, 3a e orçamento';

  @override
  String get lifeEventSugChangementEmploi => 'Mudança de emprego';

  @override
  String get lifeEventSugChangementEmploiReason =>
      'Compara a tua LPP antes de assinar um novo contrato';

  @override
  String get lifeEventSugOutilsIndependant => 'Ferramentas independente';

  @override
  String get lifeEventSugOutilsIndependantReason =>
      'AVS, LPP voluntária, 3a alargado e dividendo vs salário';

  @override
  String get lifeEventSugRetraite => 'Planeamento reforma';

  @override
  String get lifeEventSugRetraiteReason =>
      'Renda vs capital, escalonamento 3a, lacuna AVS';

  @override
  String get lifeEventSugAchatImmo => 'Compra imobiliária';

  @override
  String get lifeEventSugAchatImmoReason =>
      'Simula a tua capacidade de empréstimo e o contributo EPL';

  @override
  String get lifeEventSugDemenagement => 'Mudança cantonal';

  @override
  String get lifeEventSugDemenagementReason =>
      'O teu cantão está entre os mais tributados — compara os 26';

  @override
  String get lifeEventSugInvalidite => 'Invalidez';

  @override
  String get lifeEventSugInvaliditeReason =>
      'Verifica a tua cobertura AI + LPP em caso de acidente';

  @override
  String get indepProtAvs => 'Duplica a tua contribuição';

  @override
  String get indepProtLpp => 'Desaparece — escolha voluntária';

  @override
  String get indepProtLaa => 'Desaparece — acidente fora do trabalho';

  @override
  String get indepProtIjm => 'Desaparece — doença CHF 0';

  @override
  String get indepProtApg => 'Desaparece — licença parental';

  @override
  String get indepLppProInvalidite => 'Cobertura de invalidez incluída';

  @override
  String get indepLppProDeductible => 'Contribuições dedutíveis';

  @override
  String get indepLppProRente => 'Renda prevista na reforma';

  @override
  String get indepLppConCotisations => 'Contribuições obrigatórias elevadas';

  @override
  String get indepLppConFlexible => 'Menos flexível';

  @override
  String get indepGrand3aSub =>
      '20% do rendimento líquido, máx. CHF 36\'288/ano';

  @override
  String get indepGrand3aProFlexibilite => 'Flexibilidade total';

  @override
  String get indepGrand3aProDeduction => 'Dedução fiscal máxima';

  @override
  String get indepGrand3aProCapital => 'Capital disponível aos 60 anos';

  @override
  String get indepGrand3aConInvalidite => 'Sem cobertura de invalidez';

  @override
  String get indepGrand3aConRente => 'Sem renda prevista';

  @override
  String get indepLayerImpots => 'Impostos (estimativa)';

  @override
  String get indepLayerChargesSociales => 'Encargos sociais AVS/AI';

  @override
  String get indepLayerFraisPro => 'Despesas profissionais';

  @override
  String get indepLayerJoursNonFact => 'Dias não faturáveis';

  @override
  String get indepFiscal3a => 'Pilar 3a grande contribuição';

  @override
  String get indepFiscal3aNote =>
      'Máx. 20% do rendimento líquido, teto CHF 36\'288/ano sem LPP';

  @override
  String get indepFiscalFraisPro => 'Despesas profissionais efetivas';

  @override
  String get indepFiscalFraisProNote =>
      'Renda escritório, material, formação — dedutíveis ao custo';

  @override
  String get indepFiscalPrimesLpp => 'Prémios seguro doença (LPP vol.)';

  @override
  String get indepChargeAvs => 'AVS / AI / APG';

  @override
  String get indepChargeLpp => 'LPP (2.° pilar)';

  @override
  String get indepChargeLppNote => 'Facultativo para independente (LPP art. 4)';

  @override
  String get indepChargeAc => 'Desemprego (AC)';

  @override
  String get indepChargeAcNote => 'Sem AC para independente (LACI art. 2)';

  @override
  String get indepChargePro => 'Contribuições profissionais (IJM/LAA)';

  @override
  String get indepChargeProNote => 'Inteiramente a cargo do independente';

  @override
  String get indepPlanInscriptionAvs => 'Inscrição caixa AVS independentes';

  @override
  String get indepPlanInscriptionAvsConseq =>
      'Multas retroativas se prazo ultrapassado';

  @override
  String get indepPlanLaa => 'Seguro acidentes LAA (se sem LPP)';

  @override
  String get indepPlanLaaConseq => 'Sem cobertura acidente profissional';

  @override
  String get indepPlanOuvrir3a => 'Abrir conta 3a (dedução até CHF 36\'288)';

  @override
  String get indepPlanIjm => 'Avaliar IJM (indemnização diária doença)';

  @override
  String get indepPlanIjmConseq =>
      'Perda de rendimento desde o dia 3 em caso de doença';

  @override
  String get indepPlanFraisPro =>
      'Despesas profissionais dedutíveis — manter registo';

  @override
  String get indepPlanAcomptes =>
      'Adiantamentos fiscais cantonais — evitar juros';

  @override
  String get donationTypeEspeces => 'Dinheiro / Liquidez';

  @override
  String get donationTypeImmobilier => 'Imobiliário';

  @override
  String get donationTypeTitres => 'Títulos / Valores mobiliários';

  @override
  String get donationRegimeParticipation => 'Participação nos adquiridos';

  @override
  String get donationRegimeCommunaute => 'Comunhão de bens';

  @override
  String get donationRegimeSeparation => 'Separação de bens';

  @override
  String donationReserveBarLabel(String pct) {
    return 'Reserva $pct%';
  }

  @override
  String donationDisponibleBarLabel(String pct) {
    return 'Disponível $pct%';
  }

  @override
  String get donationDisclaimerFallback =>
      'Esta ferramenta educativa fornece estimativas indicativas e não constitui aconselhamento jurídico, fiscal ou notarial personalizado. Consulta um especialista (notário) para a tua situação.';

  @override
  String get widgetRetirementTitle => 'O teu resumo de reforma';

  @override
  String get widgetRetirementToday => 'Hoje';

  @override
  String get widgetRetirementFuture => 'Na reforma';

  @override
  String get widgetBudgetTitle => 'O teu orçamento';

  @override
  String get widgetBudgetIncome => 'Receitas';

  @override
  String get widgetBudgetExpenses => 'Despesas';

  @override
  String get widgetPillarTitle => 'Os teus 3 pilares';

  @override
  String get widgetPillarAvsLpp => 'AVS + LPP';

  @override
  String get widgetPillar3a => '3º pilar';

  @override
  String get widgetPillarNotDeclared => 'Não declarado';

  @override
  String get widgetBudgetLabel => 'Orçamento';

  @override
  String get widgetInputLppLabel => 'Saldo LPP (CHF)';

  @override
  String get widgetInput3aLabel => 'Poupança pilar 3a (CHF)';

  @override
  String get widgetScoreFallback => 'Pontuação';

  @override
  String get widgetInputSalaryFallback => 'Salário';

  @override
  String get scoreGaugeLevelExcellent => 'Excelente';

  @override
  String get scoreGaugeLevelGood => 'Bom';

  @override
  String get scoreGaugeLevelAttention => 'Atenção';

  @override
  String get scoreGaugeLevelCritical => 'Crítico';

  @override
  String get scoreGaugeTitle => 'Forma financeira';

  @override
  String get scoreGaugeSubtitle => 'Pontuação composta · 3 pilares';

  @override
  String get scoreGaugeGainTitle => 'O que te fez subir';

  @override
  String get scoreGaugeNextTitle => 'Para subir mais';

  @override
  String get scoreGaugeDisclaimer =>
      'Estimativas educativas — não constitui aconselhamento financeiro.';

  @override
  String scoreGaugeSemanticsLabel(String score, String level, String budget,
      String prevoyance, String patrimoine) {
    return 'Pontuação de forma financeira. $score de 100. Nível $level. Orçamento $budget, Previdência $prevoyance, Património $patrimoine.';
  }

  @override
  String get scoreGaugeSectionBudget => 'Orçamento';

  @override
  String get scoreGaugeSectionPrevoyance => 'Previdência';

  @override
  String get scoreGaugeSectionPatrimoine => 'Património';

  @override
  String get byokErrorSaveFailed => 'Erro ao guardar a chave.';

  @override
  String get byokErrorNotConfigured =>
      'Configura primeiro um fornecedor e uma chave.';

  @override
  String get byokErrorConnection =>
      'Erro de conexão. Verifica a tua conexão à internet.';

  @override
  String get authErrorNetwork =>
      'Serviço indisponível. Verifica a tua rede e tenta novamente.';

  @override
  String get authErrorEmailUsed =>
      'Este e-mail já está em uso. Inicia sessão ou redefine a tua palavra-passe.';

  @override
  String get authErrorIncorrect => 'E-mail ou palavra-passe incorretos.';

  @override
  String get authErrorRegistration =>
      'Registo indisponível. Usa o modo local e tenta mais tarde.';

  @override
  String get authErrorService =>
      'Serviço de conta indisponível neste ambiente. Usa o modo local.';

  @override
  String get authErrorInvalid => 'As informações inseridas são inválidas.';

  @override
  String get authErrorExpired => 'Este link expirou. Solicita um novo.';

  @override
  String get authErrorNotVerified =>
      'O teu e-mail ainda não foi verificado. Verifica o teu e-mail e tenta novamente.';

  @override
  String get authErrorGeneric =>
      'Ação indisponível de momento. Tenta daqui a pouco.';

  @override
  String ageYears(int age) {
    return '$age anos';
  }

  @override
  String get coachMintLabel => 'Coach MINT';

  @override
  String get consentNoActiveConsents => 'Sem consentimentos ativos';

  @override
  String get sequenceHousingGoal => 'Compra de imóvel';

  @override
  String get sequence3aGoal => 'Otimização pilar 3a';

  @override
  String get sequenceRetirementGoal => 'Preparação para reforma';

  @override
  String get sequenceTensionGoal => 'Resolver tensu00e3o financeira';

  @override
  String get sequenceTensionStep1 => 'Diagnu00f3stico de du00edvida';

  @override
  String get sequenceTensionStep2 => 'Oru00e7amento real';

  @override
  String get sequenceTensionStep3 => 'Plano de pagamento';

  @override
  String get sequenceTensionStep4 => 'Resumo';

  @override
  String get summaryCapaciteAchat => 'Capacidade de compra';

  @override
  String get summaryFondsPropres => 'Fundos próprios necessários';

  @override
  String get summaryRetraitEpl => 'Levantamento EPL previsto';

  @override
  String get summaryImpactRente => 'Impacto na sua pensão';

  @override
  String get summaryImpotRetrait => 'Imposto sobre levantamento';

  @override
  String get summaryMontantNet => 'Montante líquido após impostos';

  @override
  String get summaryVersementAnnuel => 'Contribuição anual';

  @override
  String get summaryEconomieFiscale => 'Poupança fiscal anual';

  @override
  String get summaryGainEchelonnement => 'Ganho com levantamentos escalonados';

  @override
  String get summaryTauxRemplacement => 'Taxa de substituição';

  @override
  String get summaryEcartMensuel => 'Diferença mensal estimada';

  @override
  String get summaryEconomieRachat => 'Poupança com recompra escalonada';

  @override
  String get summaryRatioEndettement => 'Rácio de endividamento';

  @override
  String get summaryMargeMensuelle => 'Margem mensal';

  @override
  String get summaryRevenuNet => 'Rendimento líquido mensal';

  @override
  String get summaryChargesFixes => 'Encargos fixos totais';

  @override
  String get summaryHorizonLiberation => 'Horizonte de libertação';

  @override
  String get summaryVersementMensuel => 'Pagamento mensal';

  @override
  String get summaryDonneesLpp => 'Dados do certificado LPP';

  @override
  String get summaryEstimationSansCertificat => 'Estimativa sem certificado';

  @override
  String get summaryChoixRenteCapital => 'Escolha renda/capital';

  @override
  String get sequenceAllStepsComplete => 'Todas as etapas concluídas';

  @override
  String sequenceStepLabel(int current, int total) {
    return 'Etapa $current/$total';
  }

  @override
  String get sequenceQuitConfirm => 'Percurso encerrado.';

  @override
  String sequenceStepCompleted(String progress) {
    return 'Etapa $progress concluída. Pronto para a próxima?';
  }

  @override
  String get sequenceCompleted =>
      'Percurso completo! Todas as etapas estão concluídas.';

  @override
  String get sequencePaused => 'Percurso em pausa. Pode retomar quando quiser.';

  @override
  String get sequenceStepSkipped => 'Vamos pular esta etapa por enquanto.';

  @override
  String get sequenceStepRetry =>
      'Sem problema. Vamos tentar esta etapa novamente.';

  @override
  String get sequenceReEvaluate =>
      'Os seus dados mudaram. Recalculando as etapas afetadas.';

  @override
  String shellWelcomeBackDeltaPts(Object delta) {
    return 'De volta! A sua precisão ganhou +$delta pts desde a última visita.';
  }

  @override
  String get chatPickPhoto => 'Tirar uma foto';

  @override
  String get chatPickGallery => 'Escolher uma imagem';

  @override
  String get chatPickFile => 'Ficheiro (PDF, DOCX)';

  @override
  String get chatFileTooLarge => 'Ficheiro demasiado grande (máx. 5 MB)';

  @override
  String get chatDocSent => 'Documento enviado para análise';

  @override
  String get chatDocAnalysisIntro =>
      'Analisei o teu documento. Eis o que encontrei:';

  @override
  String get chatDocUpdatePrompt =>
      'Queres que atualize o teu perfil com estes dados?';

  @override
  String get chatDocExtractionFailed =>
      'Não consegui extrair dados deste documento. Tenta com uma foto mais nítida.';

  @override
  String get chatDocError => 'Erro ao analisar o documento. Tenta novamente.';

  @override
  String get chatDocAttachTooltip => 'Digitalizar um documento';

  @override
  String get seasonalLamalTitle => 'Novos prémios LAMal';

  @override
  String get seasonalLamalDesc =>
      'Os prémios 2027 foram publicados. Verifica se a tua franquia ainda é adequada à tua situação.';

  @override
  String get extractionWhoseDocument => 'De quem é este documento?';

  @override
  String get extractionWhoseDocumentBody =>
      'Tens um perfil de casal. Este documento é teu ou do teu parceiro?';

  @override
  String get extractionDocMine => 'É meu';

  @override
  String get extractionDocPartner => 'É do meu parceiro';

  @override
  String capCoachPromptMissingData(Object category) {
    return 'Ajuda-me understand why $category is important for my situation.';
  }

  @override
  String get capCoachPromptDebt =>
      'Ajuda-me prioritize my debt repayment. Where should I start?';

  @override
  String get capCoachPromptIndepNoLpp =>
      'I\'m self-employed without LPP. What pension options do I have?';

  @override
  String get capCoachPrompt3a =>
      'Como much can I save with a 3a contribution this year?';

  @override
  String get capCoachPromptRachat =>
      'Ajuda-me understand if a LPP buyback makes sense for me.';

  @override
  String get capCoachPromptBudgetDeficit =>
      'My budget is in deficit. Como can I find some breathing room?';

  @override
  String capCoachPromptReplacement(Object rate) {
    return 'My replacement rate is $rate%. Is that enough for retirement?';
  }

  @override
  String get capCoachPromptUnemployment =>
      'I\'m unemployed. What are my financial options?';

  @override
  String get capCoachPromptDivorce =>
      'I\'m divorced. Como can I protect my financial situation?';

  @override
  String get capCoachPromptCoupleOptim =>
      'Como can we optimize our pension planning as a couple?';

  @override
  String get capCoachPromptCouple =>
      'We\'re a couple. Como should we coordinate our finances?';

  @override
  String get capCoachPromptMarried =>
      'We\'re both working and married. Como can we optimize?';

  @override
  String get sequencePreretraiteGoal => 'Prepare my retirement';

  @override
  String get sequencePreretraiteStep1 => 'Retirement projection';

  @override
  String get sequencePreretraiteStep2 => '3a review';

  @override
  String get sequencePreretraiteStep3 => 'Annuity or capital';

  @override
  String get sequencePreretraiteStep4 => 'Levantamento 3a escalonado';

  @override
  String get sequencePreretraiteStep5 => 'Mortgage';

  @override
  String get sequencePreretraiteStep6 => 'LPP buyback';

  @override
  String get sequencePreretraiteStep7 => 'LAMal franchise';

  @override
  String get sequencePreretraiteStep8 => 'Succession';

  @override
  String get sequencePreretraiteStep9 => 'Retirement budget';

  @override
  String get sequencePreretraiteStep10 => 'Withdrawal plan';

  @override
  String get sequencePreretraiteStep11 => 'Summary';

  @override
  String proactiveContractDeadline(Object days, Object label) {
    return 'Lembrete: $label vence em $days dias. Planeia com antecedência.';
  }

  @override
  String get sequenceCoupleGoal => 'Coordinate finances together';

  @override
  String get sequenceCoupleStep1 => 'Marriage or partnership';

  @override
  String get sequenceCoupleStep2 => 'Couple profile';

  @override
  String get sequenceCoupleStep3 => '3a together';

  @override
  String get sequenceCoupleStep4 => 'Couple taxation';

  @override
  String get sequenceCoupleStep5 => 'Summary';

  @override
  String get sequenceNaissanceGoal => 'Prepare for baby financially';

  @override
  String get sequenceNaissanceStep1 => 'Birth impact';

  @override
  String get sequenceNaissanceStep2 => 'Family budget';

  @override
  String get sequenceNaissanceStep3 => '3a parent';

  @override
  String get sequenceNaissanceStep4 => 'Summary';

  @override
  String get sequencePremiersPasGoal => 'Understand my first salary';

  @override
  String get sequencePremiersPasStep1 => 'First job';

  @override
  String get sequencePremiersPasStep2 => 'My first budget';

  @override
  String get sequencePremiersPasStep3 => 'Discover 3a';

  @override
  String get sequenceDensificationGoal => 'Protect and consolidate';

  @override
  String get sequenceDensificationStep1 => 'Retirement projection';

  @override
  String get sequenceDensificationStep2 => 'Disability protection';

  @override
  String get sequenceDensificationStep3 => 'LPP buyback';

  @override
  String get sequenceDensificationStep4 => 'Summary';

  @override
  String get sequenceRetraiteActiveGoal => 'Manage my retirement';

  @override
  String get sequenceRetraiteActiveStep1 => 'Retirement budget';

  @override
  String get sequenceRetraiteActiveStep2 => 'Succession';

  @override
  String get sequenceRetraiteActiveStep3 => 'LAMal franchise';

  @override
  String get sequenceRetraiteActiveStep4 => 'Summary';

  @override
  String get sequenceReadyNextStep => 'Pronto para o próximo passo';

  @override
  String get sequenceQuitButton => 'Abandonar o percurso';

  @override
  String get notifChannelDescription =>
      'Lembretes de check-in, prazos 3a e notificações de coaching';

  @override
  String get notifWeeklyRecapTitle => 'O teu resumo semanal';

  @override
  String get notifWeeklyRecapBody =>
      'Orçamento, progresso, próximo passo — tudo pronto.';

  @override
  String get notifCheckinTitle => 'Check-in mensal';

  @override
  String get notifCheckinBody =>
      'Confirma as tuas contribuições do mês em 2 min';

  @override
  String get notifDeadline3aTitle => 'Prazo 3a';

  @override
  String notifDeadline3aBody3Months(String remaining) {
    return 'Restam 3 meses para contribuir para o teu 3a (CHF $remaining de margem)';
  }

  @override
  String notifDeadline3aBody46Days(String remaining) {
    return 'Restam 46 dias para maximizar o teu 3a (CHF $remaining de margem)';
  }

  @override
  String get notifDeadline3aBody16Days =>
      'Restam 16 dias para contribuir para o teu 3a';

  @override
  String get notifDeadline3aBodyLastDays =>
      'Últimos dias! Contribui para o teu 3a antes de 31 de dezembro';

  @override
  String get notifTaxDeadlineTitle => 'Declaração fiscal';

  @override
  String get notifTaxDeadlineBody44Days =>
      'Declaração fiscal em 44 dias — reúne os teus documentos';

  @override
  String get notifTaxDeadlineBody16Days =>
      'Declaração fiscal em 16 dias — começa a preenchê-la';

  @override
  String get notifTaxDeadlineBodyLastWeek =>
      'Declaração fiscal até 31 de março — última semana!';

  @override
  String get notifStreakProtectionTitle => 'Protege a tua série';

  @override
  String notifStreakProtectionBody(String streak) {
    return 'Estás com $streak meses consecutivos — não quebres a tua série!';
  }

  @override
  String recapActiveWeek(String days) {
    return 'Esta semana, estiveste ativo $days dia(s) no MINT.';
  }

  @override
  String get recapQuietWeek => 'Esta semana foi calma no MINT.';

  @override
  String recapSavings(String amount) {
    return 'A tua poupança estimada é de CHF $amount.';
  }

  @override
  String recapConfidenceUp(String delta) {
    return 'A tua confiança melhorou +$delta pts.';
  }

  @override
  String recapNextFocus(String focus) {
    return 'Na próxima semana, concentra-te em $focus.';
  }

  @override
  String get loadingGeneric => 'A carregar…';

  @override
  String get commonConfirm => 'Confirmar';

  @override
  String get b2bHubTitle => 'A minha empresa';

  @override
  String get b2bHubInvalidCode => 'Código inválido ou expirado';

  @override
  String get b2bHubLeaveTitle => 'Sair da organização?';

  @override
  String get b2bHubLeaveBody =>
      'Os módulos reservados à tua empresa deixarão de estar acessíveis.';

  @override
  String get b2bHubNarrativeHeadline => 'Previdência empresarial';

  @override
  String get b2bHubNarrativeBody =>
      'Se o teu empregador utiliza o MINT, introduz o código de convite para aceder aos módulos de previdência reservados aos colaboradores.';

  @override
  String get b2bHubInviteCodeLabel => 'Código de convite';

  @override
  String get b2bHubJoinButton => 'Aderir';

  @override
  String get b2bHubJoinSemantics => 'Aderir à organização';

  @override
  String get b2bHubNoCodeHint =>
      'Sem código? Pergunta ao teu departamento de RH.';

  @override
  String b2bHubEmployeeCount(String count) {
    return '$count colaboradores';
  }

  @override
  String get b2bHubModulesTitle => 'Os teus módulos';

  @override
  String get b2bHubLeaveButton => 'Sair da organização';

  @override
  String get b2bModuleEducation => 'Educação financeira';

  @override
  String get b2bModuleEducationSubtitle =>
      'Artigos, conceitos e questionários adaptados à tua situação';

  @override
  String get b2bModuleWellness => 'Bem-estar financeiro';

  @override
  String get b2bModuleWellnessSubtitle =>
      'Pontuação de saúde financeira e recomendações';

  @override
  String get b2bModule3a => 'Pilar 3a empresarial';

  @override
  String get b2bModule3aSubtitle => 'Otimização e simulação do terceiro pilar';

  @override
  String get b2bModuleLpp => 'Previdência profissional (LPP)';

  @override
  String get b2bModuleLppSubtitle =>
      'Análise detalhada da tua caixa de pensões';

  @override
  String get pensionFundTitle => 'Dados certificados';

  @override
  String get pensionFundConnectionError => 'Ligação indisponível de momento';

  @override
  String get pensionFundDisconnectTitle => 'Desligar a caixa?';

  @override
  String get pensionFundDisconnectBody =>
      'As tuas projeções voltarão ao modo «estimado» em vez de «certificado».';

  @override
  String get pensionFundDisconnectButton => 'Desligar';

  @override
  String get pensionFundNarrativeHeadline => 'Importação automática';

  @override
  String get pensionFundNarrativeBody =>
      'Liga a tua caixa de pensões para substituir as estimativas pelos teus dados reais. Apenas leitura — o MINT não altera nada.';

  @override
  String get pensionFundAvailableTitle => 'Caixas disponíveis';

  @override
  String pensionFundConnectedStatus(String name) {
    return '$name, ligado';
  }

  @override
  String pensionFundDisconnectedStatus(String name) {
    return '$name, não ligado';
  }

  @override
  String pensionFundSyncDate(String date) {
    return 'Sincro $date';
  }

  @override
  String get pensionFundReconnectionNeeded => 'Reconexão necessária';

  @override
  String get pensionFundAvailable => 'Disponível';

  @override
  String get pensionFundDisconnectTooltip => 'Desligar';

  @override
  String get pensionFundConnectButton => 'Ligar';

  @override
  String get pensionFundDisclaimer =>
      'O MINT é uma ferramenta educativa em modo de leitura (LSFin art. 3). Nenhuma transação é efetuada nas tuas contas. Podes desligar-te a qualquer momento.';

  @override
  String get semanticsBudgetStartButton => 'Começar a inserir o orçamento';

  @override
  String get semanticsBenchmarkToggle => 'Ativar comparações cantonais';

  @override
  String semanticsBenchmarkMetric(
      String label, String status, String low, String high) {
    return '$label: $status. Intervalo típico de $low a $high';
  }

  @override
  String semanticsRecapPeriod(String start, String end) {
    return 'Resumo de $start a $end';
  }

  @override
  String semanticsRecapSection(String title, String content) {
    return '$title: $content';
  }

  @override
  String semanticsRepaymentFreeIn(int months) {
    return 'Livre de dívidas em $months meses';
  }

  @override
  String semanticsRepaymentDeleteDebt(String name) {
    return 'Eliminar dívida $name';
  }

  @override
  String semanticsRepaymentBudget(String amount) {
    return 'Orçamento mensal: $amount francos. Toca para editar';
  }

  @override
  String get semanticsRepaymentValidate => 'Confirmar valor';

  @override
  String semanticsRepaymentStrategy(String title, int months, String interest) {
    return '$title: $months meses, juros $interest francos';
  }

  @override
  String semanticsAvsDifference(String amount) {
    return 'Diferença anual: $amount francos';
  }

  @override
  String semanticsMetricLabelValue(String label, String value) {
    return '$label: $value';
  }

  @override
  String semanticsAvsTauxEffectif(String rate) {
    return 'Taxa efetiva: $rate por cento';
  }

  @override
  String semanticsDividendeSaving(String amount) {
    return 'Poupança: $amount francos por ano';
  }

  @override
  String get semanticsDividendeAdjust =>
      'Ajusta o split para encontrar poupanças';

  @override
  String get semanticsDividendeRequalification =>
      'Alerta: risco de requalificação fiscal se a parte salarial for inferior a 60 por cento';

  @override
  String semanticsLppCapitalisation(String amount) {
    return 'Capitalização anual: $amount francos';
  }

  @override
  String semanticsLppGain(String amount) {
    return 'Ganho com LPP voluntária: $amount francos';
  }

  @override
  String get semantics3aLppToggle => 'Afiliado LPP';

  @override
  String semantics3aEconomieFiscale(String amount) {
    return 'Poupança fiscal: $amount francos';
  }

  @override
  String semantics3aAvantageSalarie(String amount) {
    return 'Vantagem sobre assalariado: $amount francos';
  }

  @override
  String get semanticsCoachTabLabel => 'Aba Coach MINT';

  @override
  String semanticsRealReturnGain(String amount) {
    return 'Ganho comparado à poupança: $amount francos';
  }

  @override
  String get capNoCapHeadline => 'Estás no bom caminho';

  @override
  String get capNoCapWhyNow =>
      'Continua a explorar o MINT para aprofundar a tua situação.';

  @override
  String get narrativeEplHeadline =>
      'Levantamento EPL: vantagens e bloqueio de 3 anos';

  @override
  String get narrativeEplBody =>
      'O art. 30c LPP permite retirar o 2º pilar para financiar habitação própria. Atenção: se fez recompras, aplica-se um bloqueio de 3 anos (LPP art. 79b par. 3).';

  @override
  String get narrativeEplBadge => '2º pilar — EPL';

  @override
  String get narrativeRachatHeadline => 'Escalonar para poupar';

  @override
  String get narrativeRachatBody =>
      'Distribuir uma recompra LPP por vários anos permite deduzir cada parcela do rendimento tributável (LPP art. 79b). A progressividade fiscal torna esta estratégia frequentemente mais vantajosa do que um pagamento único.';

  @override
  String get narrativeRachatBadge => '2º pilar';

  @override
  String get rachatEchelonneEyebrow => 'Recompra LPP escalonada';

  @override
  String rachatEchelonneNarrativeSavings(int horizon) {
    return 'Escalonar a recompra em $horizon anos reduz a tua carga fiscal total.';
  }

  @override
  String get rachatEchelonneNarrativeNoSavings =>
      'Na tua situação, a recompra em bloco é mais vantajosa.';

  @override
  String get narrativeLibrePassageHeadline =>
      'Livre passagem: 6 meses para agir';

  @override
  String get narrativeLibrePassageBody =>
      'Ao mudar de emprego, tens 6 meses para transferir o teu capital LPP (LFLP art. 3). Após esse prazo, o capital é automaticamente depositado numa conta de livre passagem. Escolhe o veículo certo desde o início.';

  @override
  String get narrativeLibrePassageBadge => 'Livre passagem';

  @override
  String get narrativeAmortizationHeadline => 'Direto ou indireto?';

  @override
  String get narrativeAmortizationBody =>
      'A amortização direta reduz a tua dívida todos os anos. A indireta deposita num 3a, dedutível fiscalmente (OPP3). Dependendo da tua taxa marginal, a indireta pode custar-te menos no total.';

  @override
  String get narrativeAmortizationBadge => 'Amortização';

  @override
  String get amortizationEyebrow => 'Amortização direta vs indireta';

  @override
  String get amortizationSavingsLabel => 'de poupança com a indireta';

  @override
  String get amortizationDifferenceLabel =>
      'de diferença entre as duas estratégias';

  @override
  String get narrativeSaronHeadline => 'SARON ou taxa fixa?';

  @override
  String get narrativeSaronBody =>
      'O SARON segue o mercado monetário e pode mudar a cada trimestre. Uma taxa fixa bloqueia os teus juros durante todo o prazo. Dependendo da tua tolerância ao risco, a diferença pode jogar a teu favor… ou não.';

  @override
  String get narrativeSaronBadge => 'Hipoteca';

  @override
  String get saronEyebrow => 'SARON vs Taxa fixa';

  @override
  String get saronSavingsLabel => 'de poupança potencial com SARON';

  @override
  String get saronCostLabel => 'de custo adicional com SARON';

  @override
  String get narrativeRealReturnHeadline => 'Rendimento real após inflação';

  @override
  String get narrativeRealReturnBody =>
      'O rendimento apresentado não diz tudo. Após comissões de gestão e inflação, o ganho real pode diferir. A poupança fiscal do 3a (LIFD art. 33) melhora consideravelmente o rendimento efetivo.';

  @override
  String get narrativeRealReturnBadge => '3º pilar';

  @override
  String get narrativeRetroactive3aHeadline => 'Recuperar até 10 anos de 3a';

  @override
  String get narrativeRetroactive3aBody =>
      'A partir de 2026, a OPP3 art. 7 permite pagar retroativamente os anos de contribuição 3a em falta. Cada pagamento é dedutível do rendimento tributável (LIFD art. 33).';

  @override
  String get narrativeRetroactive3aBadge => '3º pilar';

  @override
  String get retroactive3aSavingsLabel =>
      'de poupança fiscal com a recuperação 3a';

  @override
  String get narrativeFirstJobHeadline => 'O teu primeiro salário explicado';

  @override
  String get narrativeFirstJobBody =>
      'Entre AVS (LAVS art. 5), LPP (art. 16), imposto na fonte e LAMal, o teu líquido representa cerca de 75-80 % do bruto. Compreender estas deduções é o primeiro passo para uma boa gestão.';

  @override
  String get narrativeFirstJobBadge => 'Primeiro emprego';

  @override
  String get narrativeMarriageHeadline => 'Impacto financeiro do casamento';

  @override
  String get narrativeMarriageBody =>
      'O casamento modifica a tua tributação (LIFD art. 9), o teu regime matrimonial (CC art. 181) e os teus direitos de sobrevivência (LAVS art. 23, LPP art. 19). Dependendo dos vossos rendimentos respetivos, o impacto fiscal pode ser positivo ou negativo.';

  @override
  String get narrativeMarriageBadge => 'Casamento';

  @override
  String get narrativeBirthHeadline => 'Custos e apoios ao nascimento';

  @override
  String get narrativeBirthBody =>
      'A licença de maternidade (LAPG art. 16b–d) cobre 14 semanas a 80 % do salário. Os abonos de família variam por cantão (LAFam art. 3). Este simulador estima o impacto global no teu orçamento.';

  @override
  String get narrativeBirthBadge => 'Nascimento';

  @override
  String get narrativeCoverageHeadline => 'Verifica a tua cobertura';

  @override
  String get narrativeCoverageBody =>
      'LAMal, IJM, RC privada, seguro do lar… Cada seguro cobre um risco diferente. Este balanço identifica as lacunas conforme a tua situação e o teu cantão.';

  @override
  String get narrativeCoverageBadge => 'Seguros';

  @override
  String get narrativeDisabilityHeadline =>
      'Compreende a tua lacuna de invalidez';

  @override
  String get narrativeDisabilityBody =>
      'Em caso de invalidez, o teu rendimento passa por 3 fases: empregador (CO art. 324a), IJM, depois AI + LPP (LAI art. 28, LPP art. 23-26). A queda pode atingir 40-60 % do teu salário atual.';

  @override
  String get narrativeDisabilityBadge => 'Invalidez';

  @override
  String get narrativeUnemploymentHeadline => 'Os teus direitos de desemprego';

  @override
  String get narrativeUnemploymentBody =>
      'A LACI prevê uma indemnização de 70-80 % do ganho segurado (art. 22). A duração depende dos teus meses de contribuição e da tua idade (art. 27). Este simulador estima os teus direitos com base na tua situação atual.';

  @override
  String get narrativeUnemploymentBadge => 'Desemprego';

  @override
  String get imputedRentalEyebrow => 'Valor de aluguer imputado';

  @override
  String get imputedRentalSavingsLabel => 'de poupança fiscal líquida';

  @override
  String get imputedRentalTaxLabel => 'de imposto adicional';

  @override
  String get semanticsBack => 'Voltar';

  @override
  String get semanticsDecrease => 'Diminuir';

  @override
  String get semanticsIncrease => 'Aumentar';

  @override
  String get realReturnPrimaryLabel =>
      'rendimento real após impostos e inflação';

  @override
  String get realReturnNarrative =>
      'Graças à dedução fiscal, o teu 3a rende muito mais do que uma conta poupança clássica.';

  @override
  String get retroactive3aEmptyTitle => 'Recuperação 3a';

  @override
  String get retroactive3aEmptySubtitle =>
      'Insere o teu rendimento para calcular a tua poupança fiscal';

  @override
  String get retroactive3aEmptyCta => 'Adicionar o meu rendimento';

  @override
  String get onboardingPermitTypeLabel => 'O teu tipo de autorização';

  @override
  String get onboardingPermitC => 'Autorização C (estabelecimento)';

  @override
  String get onboardingPermitB => 'Autorização B (residência)';

  @override
  String get onboardingPermitG => 'Autorização G (fronteiriço)';

  @override
  String get onboardingPermitL => 'Autorização L (curta duração)';

  @override
  String get onboardingPermitOther => 'Outro';

  @override
  String get onboardingIjmWarningTitle => 'Proteção doença: a verificar';

  @override
  String get onboardingIjmWarningBody =>
      'Como trabalhador independente, não tens subsídio diário de doença (IJM) por defeito. Sem cobertura, uma doença poderia interromper os teus rendimentos sem compensação. Tens também 6 meses para te inscreveres voluntariamente num fundo de pensões (LPP art. 4).';

  @override
  String get rachatLppNotApplicableAfterRetirement =>
      'A recompra LPP já não é aplicável após a reforma. Esta simulação destina-se a trabalhadores ativos que pretendem colmatar uma lacuna de previdência.';

  @override
  String get apiErrorOffline =>
      'Sem ligação à internet. Verifica a tua rede e tenta novamente.';

  @override
  String get apiErrorTimeout =>
      'O servidor está a demorar demasiado a responder. Tenta novamente.';

  @override
  String get apiErrorSessionExpired =>
      'Sessão expirada — inicia sessão novamente.';

  @override
  String get apiErrorServer =>
      'Erro do servidor. Tenta novamente dentro de momentos.';

  @override
  String get pensionFundConnectComingSoon =>
      'Disponível em breve — a aguardar acordos-piloto';

  @override
  String get greetingNight => 'Boa noite';

  @override
  String get onboardingCalculationError =>
      'Erro de cálculo. Verifica os teus dados e tenta novamente.';

  @override
  String get onboardingRetirementAgeWarning =>
      'Reforma antes dos 55? Verifica a tua idade ou situação profissional.';

  @override
  String indicativeBannerTitle(String pct) {
    return 'Resultado indicativo ($pct % de fiabilidade)';
  }

  @override
  String get indicativeBannerBody =>
      'Precisa os teus dados para projeções personalizadas.';

  @override
  String get indicativeBannerCta => 'Precisar';

  @override
  String get exploreHubTitle => 'Explorar';

  @override
  String get safeModeTitle => 'Foco Prioritário';

  @override
  String get safeModeMessage =>
      'Para a tua segurança financeira, desativamos as otimizações avançadas enquanto um sinal de dívida estiver ativo.';

  @override
  String get safeModeCta => 'Ver o meu plano de redução de dívida';
}
