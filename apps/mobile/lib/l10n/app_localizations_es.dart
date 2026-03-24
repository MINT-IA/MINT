// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class SEs extends S {
  SEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'MINT';

  @override
  String get landingHero => 'Financial OS.';

  @override
  String get landingSubtitle => 'Tu copiloto financiero suizo.';

  @override
  String get landingBetaBadge => 'Beta Privada';

  @override
  String get landingHeroPrefix => 'El primero';

  @override
  String get landingSubtitleLong =>
      'La inteligencia de un CFO, en tu bolsillo.\nCero tonterias. Puro consejo.';

  @override
  String get landingFeature1Title => 'Diagnostico Instantaneo';

  @override
  String get landingFeature1Desc => 'Analisis 360° en 5 minutos.';

  @override
  String get landingFeature2Title => '100% Privado & Local';

  @override
  String get landingFeature2Desc => 'Tus datos se quedan en tu dispositivo.';

  @override
  String get landingFeature3Title => 'Estrategia Neutra';

  @override
  String get landingFeature3Desc => 'Cero comision. Cero conflicto.';

  @override
  String get landingDiagnosticSubtitle => 'Balance 360° • 5 minutos';

  @override
  String get landingResumeDiagnostic => 'Retomar mi diagnostico';

  @override
  String get startDiagnostic => 'Iniciar mi diagnostico';

  @override
  String get tabNow => 'AHORA';

  @override
  String get tabExplore => 'Explorar';

  @override
  String get tabTrack => 'SEGUIR';

  @override
  String get budgetTitle => 'Dominar mi Presupuesto';

  @override
  String get simulatorsTitle => 'Simuladores de Viaje';

  @override
  String get recommendations => 'Tus Recomendaciones';

  @override
  String get disclaimer =>
      'Los resultados presentados son estimaciones a titulo indicativo. No constituyen asesoramiento financiero personalizado.';

  @override
  String get onboardingSkip => 'Saltar';

  @override
  String onboardingProgress(String step, String total) {
    return 'Paso $step de $total';
  }

  @override
  String get onboardingStep1Title => 'Hola, soy tu mentor.';

  @override
  String get onboardingStep1Subtitle =>
      'Empecemos por conocernos. ?Cual es tu situacion actual?';

  @override
  String get onboardingHouseholdSingle => 'Solo/a';

  @override
  String get onboardingHouseholdSingleDesc => 'Gestiono mis finanzas solo/a';

  @override
  String get onboardingHouseholdCouple => 'En pareja';

  @override
  String get onboardingHouseholdCoupleDesc =>
      'Compartimos nuestros objetivos financieros';

  @override
  String get onboardingHouseholdFamily => 'Familia';

  @override
  String get onboardingHouseholdFamilyDesc => 'Con hijos a cargo';

  @override
  String get onboardingHouseholdSingleParent => 'Padre/madre solo/a';

  @override
  String get onboardingHouseholdSingleParentDesc =>
      'Gestiono solo/a con hijos a cargo';

  @override
  String get onboardingStep2Title => 'Muy bien.';

  @override
  String get onboardingStep2Subtitle =>
      '?Que viaje financiero quieres emprender primero?';

  @override
  String get onboardingGoalHouse => 'Ser propietario';

  @override
  String get onboardingGoalHouseDesc => 'Preparar mi entrada y mi hipoteca';

  @override
  String get onboardingGoalRetire => 'Serenidad en la Jubilacion';

  @override
  String get onboardingGoalRetireDesc => 'Maximizar mi futuro a largo plazo';

  @override
  String get onboardingGoalInvest => 'Invertir & Crecer';

  @override
  String get onboardingGoalInvestDesc =>
      'Hacer crecer mis ahorros de forma inteligente';

  @override
  String get onboardingGoalTaxOptim => 'Optimizacion Fiscal';

  @override
  String get onboardingGoalTaxOptimDesc => 'Reducir mis impuestos legalmente';

  @override
  String get onboardingStep3Title => 'Casi listo.';

  @override
  String get onboardingStep3Subtitle =>
      'Estos detalles nos permiten personalizar tus calculos segun la ley suiza.';

  @override
  String get onboardingCantonLabel => 'Canton de residencia';

  @override
  String get onboardingCantonHint => 'Selecciona tu canton';

  @override
  String get onboardingBirthYearLabel => 'Ano de nacimiento (opcional)';

  @override
  String get onboardingBirthYearHint => 'Ej: 1990';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingStep4Title => '?Listo para empezar?';

  @override
  String get onboardingStep4Subtitle =>
      'Mint es un entorno seguro. Estos son nuestros compromisos contigo.';

  @override
  String get onboardingTrustTransparency => 'Transparencia total';

  @override
  String get onboardingTrustTransparencyDesc =>
      'Todas las hipotesis son visibles.';

  @override
  String get onboardingTrustPrivacy => 'Privacidad';

  @override
  String get onboardingTrustPrivacyDesc =>
      'Calculos locales, sin almacenamiento de datos sensibles.';

  @override
  String get onboardingTrustSecurity => 'Seguridad';

  @override
  String get onboardingTrustSecurityDesc => 'Sin acceso directo a tu dinero.';

  @override
  String get onboardingEnterSpace => 'Entrar en mi espacio';

  @override
  String get advisorMiniStep1Title => 'Cual es tu prioridad?';

  @override
  String get advisorMiniStep1Subtitle =>
      'MINT se adapta a lo que mas te importa ahora';

  @override
  String get advisorMiniFirstNameLabel => 'Nombre (opcional)';

  @override
  String get advisorMiniFirstNameHint => 'Nombre';

  @override
  String get advisorMiniStressBudget => 'Controlar mi presupuesto';

  @override
  String get advisorMiniStressDebt => 'Reducir mis deudas';

  @override
  String get advisorMiniStressTax => 'Optimizar mis impuestos';

  @override
  String get advisorMiniStressRetirement => 'Asegurar mi jubilacion';

  @override
  String advisorMiniResumeDiagnostic(String progress) {
    return 'Retomar mi diagnostico ($progress%)';
  }

  @override
  String get advisorMiniFullDiagnostic => 'Diagnostico completo (10 min)';

  @override
  String get advisorMiniStep2Title => 'Lo esencial';

  @override
  String get advisorMiniStep2Subtitle =>
      'Edad y canton lo cambian todo en Suiza';

  @override
  String get advisorMiniBirthYearLabel => 'Ano de nacimiento';

  @override
  String get advisorMiniBirthYearInvalid => 'Ano invalido';

  @override
  String advisorMiniBirthYearRange(String maxYear) {
    return 'Entre 1940 y $maxYear';
  }

  @override
  String get advisorMiniCantonLabel => 'Canton de residencia';

  @override
  String get advisorMiniCantonHint => 'Seleccionar';

  @override
  String get advisorMiniStep3Title => 'Tus ingresos';

  @override
  String get advisorMiniStep3Subtitle => 'Para calcular tu potencial de ahorro';

  @override
  String get advisorMiniIncomeLabel => 'Ingreso neto mensual (CHF)';

  @override
  String get advisorMiniHousingTitle => 'Vivienda';

  @override
  String get advisorMiniHousingTenant => 'Inquilino/a';

  @override
  String get advisorMiniHousingOwner => 'Propietario/a';

  @override
  String get advisorMiniHousingHosted => 'Alojado/a / sin alquiler';

  @override
  String get advisorMiniHousingCostTenant => 'Alquiler / gastos vivienda / mes';

  @override
  String get advisorMiniHousingCostOwner => 'Costes vivienda / hipoteca / mes';

  @override
  String get advisorMiniDebtPaymentsLabel => 'Cuotas de deuda / leasing / mes';

  @override
  String get advisorMiniPatrimonyTitle => 'Patrimonio (opcional)';

  @override
  String get advisorMiniCashSavingsLabel => 'Liquidez / ahorro disponible';

  @override
  String get advisorMiniInvestmentsTotalLabel =>
      'Inversiones (acciones, ETF, fondos)';

  @override
  String get advisorMiniPillar3aTotalLabel => 'Total 3a aproximado';

  @override
  String get advisorMiniCivilStatusLabel => 'Estado civil de la pareja';

  @override
  String get advisorMiniCivilStatusMarried => 'Casado/a';

  @override
  String get advisorMiniCivilStatusConcubinage => 'En concubinato';

  @override
  String get advisorMiniPartnerIncomeLabel =>
      'Ingreso neto mensual de la pareja';

  @override
  String get advisorMiniPartnerBirthYearLabel =>
      'Ano de nacimiento de la pareja';

  @override
  String get advisorMiniPartnerFirstNameLabel =>
      'Nombre de la pareja (opcional)';

  @override
  String get advisorMiniPartnerFirstNameHint => 'Nombre';

  @override
  String get advisorMiniPartnerStatusHint => 'Pareja';

  @override
  String get advisorMiniPartnerStatusInactive => 'Sin actividad';

  @override
  String get advisorMiniPartnerRequiredTitle =>
      'Informacion de pareja requerida';

  @override
  String get advisorMiniPartnerRequiredBody =>
      'Anade estado civil, ingreso, ano de nacimiento y estado de la pareja para una proyeccion del hogar fiable.';

  @override
  String get advisorMiniPartnerProfileTitle => 'Perfil de la pareja';

  @override
  String get advisorReadinessLabel => 'Completitud del perfil';

  @override
  String get advisorReadinessLevel => 'Nivel';

  @override
  String get advisorReadinessSufficient =>
      'Base suficiente para un plan inicial.';

  @override
  String get advisorReadinessToComplete => 'Por completar';

  @override
  String get advisorMiniCoachIntroTitle => 'Tu coach MINT';

  @override
  String get advisorMiniCoachIntroControl =>
      'Ahora tienes un plan concreto. Avanzamos con 3 prioridades en 7 dias y luego ajustamos con tu coach.';

  @override
  String get advisorMiniWelcomeTitle => '¡Bienvenido/a!';

  @override
  String get advisorMiniWelcomeBody =>
      'Tu espacio financiero está listo. Descubre lo que tu coach ha preparado.';

  @override
  String get advisorMiniCoachIntroWarmth =>
      'Vamos juntos. Cada semana, te ayudo a avanzar en un punto concreto.';

  @override
  String get advisorMiniCoachPriorityBaseline =>
      'Confirmar tu puntuacion y trayectoria inicial';

  @override
  String get advisorMiniCoachPriorityCouple =>
      'Alinear la estrategia del hogar para evitar puntos ciegos en pareja';

  @override
  String get advisorMiniCoachPrioritySingleParent =>
      'Priorizar la proteccion del hogar y el fondo de emergencia';

  @override
  String get advisorMiniCoachPriorityBudget =>
      'Estabilizar primero el presupuesto y los gastos fijos';

  @override
  String get advisorMiniCoachPriorityTax =>
      'Identificar optimizaciones fiscales prioritarias';

  @override
  String get advisorMiniCoachPriorityRetirement =>
      'Reforzar la trayectoria de jubilacion con acciones concretas';

  @override
  String get advisorMiniCoachPriorityRealEstate =>
      'Verificar la sostenibilidad del proyecto inmobiliario';

  @override
  String get advisorMiniCoachPriorityDebtFree =>
      'Acelerar el desendeudamiento sin romper la liquidez';

  @override
  String get advisorMiniCoachPriorityWealth =>
      'Construir un plan solido de acumulacion de patrimonio';

  @override
  String get advisorMiniCoachPriorityPension =>
      'Optimizar 3a/LPP y el nivel de ingresos en jubilacion';

  @override
  String get advisorMiniQuickPickLabel => 'Seleccion rapida';

  @override
  String get advisorMiniQuickPickIncomeLabel => 'Importes frecuentes';

  @override
  String get advisorMiniFixedCostsTitle => 'Costes fijos (opcional)';

  @override
  String get advisorMiniFixedCostsHint =>
      'Incluir: internet/movil, seguros hogar/RC/auto, transporte, suscripciones y gastos recurrentes.';

  @override
  String get advisorMiniFixedCostsSubtitle =>
      'Añade impuestos, LAMal y otros costes fijos para un presupuesto realista desde el inicio.';

  @override
  String get advisorMiniPrefillEstimates => 'Rellenar estimaciones';

  @override
  String get advisorMiniPrefillHint =>
      'Estimado según tu cantón — ajusta si es diferente.';

  @override
  String advisorMiniPrefillTaxCouple(String canton) {
    return 'Prellenado según tu ingreso arriba (cantón $canton, pareja)';
  }

  @override
  String advisorMiniPrefillTaxSingle(String canton) {
    return 'Prellenado según tu ingreso arriba (cantón $canton)';
  }

  @override
  String advisorMiniPrefillLamalFamily(String adults, String children) {
    return 'LAMal estimada para $adults adulto(s) + $children niño(s)';
  }

  @override
  String advisorMiniPrefillLamalCouple(String adults) {
    return 'LAMal estimada para $adults adultos';
  }

  @override
  String get advisorMiniPrefillLamalSingle => 'LAMal estimada para 1 adulto';

  @override
  String get advisorMiniPrefillAdjust => 'Ajusta si es diferente.';

  @override
  String get advisorMiniTaxProvisionLabel => 'Provision de impuestos / mes';

  @override
  String get advisorMiniLamalLabel => 'Primas LAMal / mes';

  @override
  String get advisorMiniOtherFixedLabel => 'Otros costes fijos / mes';

  @override
  String get advisorMiniStep2AhaTitle => 'Tu canton en resumen';

  @override
  String advisorMiniStep2AhaHorizon(String years) {
    return 'Horizonte de jubilacion: ~$years anos';
  }

  @override
  String advisorMiniStep2AhaTaxQualitative(String canton, String pressure) {
    return 'Fiscalidad en $canton: $pressure respecto a la media suiza';
  }

  @override
  String get advisorMiniStep2AhaPressureLow => 'baja';

  @override
  String get advisorMiniStep2AhaPressureMedium => 'moderada';

  @override
  String get advisorMiniStep2AhaPressureHigh => 'elevada';

  @override
  String get advisorMiniStep2AhaPressureVeryHigh => 'muy elevada';

  @override
  String get advisorMiniStep2AhaPressureLabel => 'Presion fiscal';

  @override
  String get advisorMiniStep2AhaQualitativeHint =>
      'Se refinara con tu ingreso en el siguiente paso.';

  @override
  String get advisorMiniStep2AhaDisclaimer =>
      'Orden de magnitud educativo basado en datos cantonales de referencia de MINT.';

  @override
  String get advisorMiniProjectionDisclaimer =>
      'Herramienta educativa — no constituye asesoramiento financiero (LAVS/LPP).';

  @override
  String get advisorMiniExitTitle => '¿Salir ahora?';

  @override
  String get advisorMiniExitBodyControl =>
      'Tu progreso se ha guardado. Puedes continuar más tarde.';

  @override
  String get advisorMiniExitBodyChallenge =>
      'Solo unos segundos más y obtienes tu trayectoria personalizada.';

  @override
  String get advisorMiniExitStay => 'Continuar';

  @override
  String get advisorMiniExitLeave => 'Salir';

  @override
  String get advisorMiniMetricsTitle => 'Metricas onboarding';

  @override
  String get advisorMiniMetricsSubtitle =>
      'Seguimiento local de variantes control/challenge';

  @override
  String get advisorMiniMetricsControl => 'Control';

  @override
  String get advisorMiniMetricsChallenge => 'Challenge';

  @override
  String get advisorMiniMetricsStarts => 'Starts';

  @override
  String get advisorMiniMetricsCompletionRate => 'Tasa de completion';

  @override
  String get advisorMiniMetricsExitStayRate =>
      'Tasa de stay tras prompt de salida';

  @override
  String get advisorMiniMetricsAhaToStep3 => 'Step2 A-ha -> Step3';

  @override
  String get advisorMiniMetricsQuickPicks => 'Quick picks';

  @override
  String get advisorMiniMetricsAvgStepTime => 'Tiempo medio por paso';

  @override
  String get advisorMiniMetricsReset => 'Reset metrics';

  @override
  String advisorMiniEtaLabel(String seconds) {
    return 'Tiempo restante estimado: ${seconds}s';
  }

  @override
  String get advisorMiniEtaConfidenceHigh => 'Confianza alta';

  @override
  String get advisorMiniEtaConfidenceLow => 'Confianza media';

  @override
  String get advisorMiniEmploymentLabel => 'Situacion profesional';

  @override
  String get advisorMiniHouseholdLabel => 'Tu hogar';

  @override
  String get advisorMiniHouseholdSubtitle =>
      'Ajustamos impuestos y costes fijos segun tu situacion';

  @override
  String get advisorMiniReadyTitle => 'Validado';

  @override
  String get advisorMiniReadyLabel => 'Lo que MINT ha entendido';

  @override
  String get advisorMiniReadyStep1 =>
      'Prioridad registrada. Personalizamos tu trayectoria.';

  @override
  String get advisorMiniReadyStep2 =>
      'Base fiscal lista. Contexto cantonal calibrado.';

  @override
  String get advisorMiniReadyStep3 =>
      'Perfil minimo listo. Proyeccion indicativa disponible.';

  @override
  String advisorMiniReadyStress(String label) {
    return 'Prioridad: $label';
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
    return 'Ingreso neto: CHF $income/mes';
  }

  @override
  String advisorMiniReadyFixed(String count) {
    return 'Costes fijos captados: $count/3';
  }

  @override
  String get advisorMiniEmploymentEmployee => 'Asalariado/a';

  @override
  String get advisorMiniEmploymentSelfEmployed => 'Autonomo/a';

  @override
  String get advisorMiniEmploymentStudent => 'Estudiante / Aprendiz';

  @override
  String get advisorMiniEmploymentUnemployed => 'Sin empleo';

  @override
  String get advisorMiniSeeProjection => 'Ver mi proyeccion';

  @override
  String get advisorMiniPreferFullDiagnostic =>
      'Prefiero el diagnostico completo (10 min)';

  @override
  String advisorMiniQuickInsight(String low, String high, String horizon) {
    return 'Estimacion rapida: un ahorro regular entre CHF $low y CHF $high/mes ya puede cambiar tu trayectoria. $horizon';
  }

  @override
  String advisorMiniHorizon(String years) {
    return 'Horizonte de jubilacion: ~$years anos.';
  }

  @override
  String get advisorMiniStep4Title => 'Tu objetivo';

  @override
  String get advisorMiniStep4Subtitle =>
      'MINT personaliza tu plan segun tu prioridad principal';

  @override
  String get advisorMiniGoalRetirement => 'Preparar mi jubilacion';

  @override
  String get advisorMiniGoalRealEstate => 'Comprar una vivienda';

  @override
  String get advisorMiniGoalDebtFree => 'Reducir mis deudas';

  @override
  String get advisorMiniGoalIndependence =>
      'Construir mi independencia financiera';

  @override
  String get advisorMiniActivateDashboard => 'Activar mi dashboard';

  @override
  String get advisorMiniAdjustLater =>
      'Despues podras ajustar todo desde Dashboard y Agir.';

  @override
  String advisorMiniPreviewTitle(String goal) {
    return 'Vista previa de trayectoria: $goal';
  }

  @override
  String advisorMiniPreviewSubtitle(String years) {
    return 'Proyeccion indicativa en ~$years anos';
  }

  @override
  String get advisorMiniPreviewPrudent => 'Prudente';

  @override
  String get advisorMiniPreviewBase => 'Base';

  @override
  String get advisorMiniPreviewOptimistic => 'Optimista';

  @override
  String get homeSafeModeActive => 'MODO PROTECCION ACTIVADO';

  @override
  String get homeHide => 'Ocultar';

  @override
  String get homeSafeModeMessage =>
      'Hemos detectado senales de tension. MINT te aconseja estabilizar tu presupuesto antes de invertir.';

  @override
  String get homeSafeModeResources => 'Recursos & Ayuda gratuita';

  @override
  String get homeMentorAdvisor => 'Mentor Advisor';

  @override
  String get homeMentorDescription =>
      'Inicia tu sesion personalizada para obtener un diagnostico completo de tu situacion financiera.';

  @override
  String get homeStartSession => 'Iniciar mi sesion';

  @override
  String get homeSimulator3a => 'Jubilacion 3a';

  @override
  String get homeSimulatorGrowth => 'Crecimiento';

  @override
  String get homeSimulatorLeasing => 'Leasing';

  @override
  String get homeSimulatorCredit => 'Credito al Consumo';

  @override
  String get homeReportV2Title => '🧪 NUEVO: Informe V2 (Demo)';

  @override
  String get homeReportV2Subtitle =>
      'Score por circulo, comparador 3a, estrategia LPP';

  @override
  String get profileTitle => 'MI PERFIL MENTOR';

  @override
  String get profilePrecisionIndex => 'Indice de Precision';

  @override
  String get profilePrecisionMessage =>
      'Cuanto mas completo tu perfil, mas potente tu informe \"Statement of Advice\".';

  @override
  String get profileFactFindTitle => 'Detalles FactFind';

  @override
  String get profileSectionIdentity => 'Identidad & Hogar';

  @override
  String get profileSectionIncome => 'Ingresos & Ahorro';

  @override
  String get profileSectionPension => 'Prevision (LPP)';

  @override
  String get profileSectionProperty => 'Inmuebles & Deudas';

  @override
  String get profileStatusComplete => 'Completo';

  @override
  String get profileStatusPartial => 'Parcial (Neto)';

  @override
  String get profileStatusMissing => 'Faltante';

  @override
  String get profileReward15 => '+15% de precision';

  @override
  String get profileReward10 => '+10% de precision';

  @override
  String get profileSecurityTitle => 'Seguridad & Datos';

  @override
  String get profileConsentControl => 'Control de Comparticiones';

  @override
  String get profileConsentManage => 'Gestionar mis accesos bLink';

  @override
  String get profileAccountTitle => 'Cuenta';

  @override
  String get profileUser => 'Usuario';

  @override
  String get profileDeleteData => 'Eliminar mis datos locales';

  @override
  String get rentVsCapitalTitle => 'Renta vs Capital';

  @override
  String get rentVsCapitalDescription =>
      'Compara la renta vitalicia y el retiro de capital de tu 2º pilar';

  @override
  String get rentVsCapitalSubtitle => 'Simula tu 2º pilar • LPP';

  @override
  String get rentVsCapitalAvoirOblig => 'Haber obligatorio';

  @override
  String get rentVsCapitalAvoirSurob => 'Haber supraobligatorio';

  @override
  String get rentVsCapitalTauxConversion =>
      'Tasa de conversion supraobligatoria';

  @override
  String get rentVsCapitalAgeRetraite => 'Edad de jubilacion';

  @override
  String get rentVsCapitalCanton => 'Canton';

  @override
  String get rentVsCapitalStatutCivil => 'Estado civil';

  @override
  String get rentVsCapitalSingle => 'Soltero/a';

  @override
  String get rentVsCapitalMarried => 'Casado/a';

  @override
  String get rentVsCapitalRenteViagere => 'Renta vitalicia';

  @override
  String get rentVsCapitalCapitalNet => 'Capital neto';

  @override
  String get rentVsCapitalBreakEven => 'Break-even';

  @override
  String get rentVsCapitalCapitalA85 => 'Capital a los 85 anos';

  @override
  String get rentVsCapitalJamais => 'Nunca';

  @override
  String get rentVsCapitalPrudent => 'Prudente (1%)';

  @override
  String get rentVsCapitalCentral => 'Central (3%)';

  @override
  String get rentVsCapitalOptimiste => 'Optimista (5%)';

  @override
  String get rentVsCapitalTauxConversionExpl =>
      'La tasa de conversion determina el importe de tu renta anual en funcion de tu haber de vejez. La tasa legal minima es del 6,8% para la parte obligatoria (LPP art. 14). Para la parte supraobligatoria, cada caja de pensiones fija su propia tasa, generalmente entre el 3% y el 6%.';

  @override
  String get rentVsCapitalChoixExpl =>
      'La renta ofrece un ingreso regular vitalicio, pero cesa al fallecer (eventualmente con una renta de sobreviviente reducida). El capital ofrece mas flexibilidad, pero conlleva un riesgo de agotamiento si los rendimientos son bajos o la longevidad elevada.';

  @override
  String get rentVsCapitalDisclaimer =>
      'Los resultados presentados son estimaciones a titulo indicativo. No constituyen asesoramiento financiero personalizado. Consulta tu caja de pensiones y un asesor cualificado antes de cualquier decision.';

  @override
  String get disabilityGapTitle => 'Mi red de seguridad';

  @override
  String get disabilityGapSubtitle => '¿Qué pasa si ya no puedo trabajar?';

  @override
  String get disabilityGapRevenu => 'Ingreso mensual neto';

  @override
  String get disabilityGapCanton => 'Canton';

  @override
  String get disabilityGapStatut => 'Estatuto profesional';

  @override
  String get disabilityGapSalarie => 'Asalariado';

  @override
  String get disabilityGapIndependant => 'Independiente';

  @override
  String get disabilityGapAnciennete => 'Anos de servicio';

  @override
  String get disabilityGapIjm => 'IJM colectiva via mi empleador';

  @override
  String get disabilityGapDegre => 'Grado de invalidez';

  @override
  String get disabilityGapPhase1 => 'Fase 1 — Empleador';

  @override
  String get disabilityGapPhase2 => 'Fase 2 — IJM';

  @override
  String get disabilityGapPhase3 => 'Fase 3 — AI + LPP';

  @override
  String get disabilityGapRevenuActuel => 'Ingreso actual';

  @override
  String get disabilityGapGapMensuel => 'Brecha mensual maxima';

  @override
  String get disabilityGapRiskCritical => 'Riesgo critico';

  @override
  String get disabilityGapRiskHigh => 'Riesgo elevado';

  @override
  String get disabilityGapRiskMedium => 'Riesgo moderado';

  @override
  String get disabilityGapRiskLow => 'Riesgo bajo';

  @override
  String get disabilityGapDisclaimer =>
      'Herramienta educativa — no constituye asesoramiento de seguros (LSFin). Tu cobertura real depende de tu contrato laboral y caja de pensión.';

  @override
  String get disabilityGapIjmExpl =>
      'La IJM (indemnizacion diaria por enfermedad) es un seguro que cubre el 80% de tu salario durante max. 720 dias en caso de enfermedad. El empleador no esta obligado a suscribirla, pero muchos lo hacen a traves de un seguro colectivo. Sin IJM, tras el periodo legal de mantenimiento del salario, no recibes nada hasta la eventual renta AI.';

  @override
  String get disabilityGapCo324aExpl =>
      'Segun el art. 324a CO, el empleador debe pagar el salario durante un periodo limitado en caso de enfermedad. Esta duracion depende de los anos de servicio y de la escala cantonal aplicable (bernesa, zuriquesa o basilea). Tras este periodo, solo la IJM (si existe) toma el relevo.';

  @override
  String get authLogin => 'Iniciar sesion';

  @override
  String get authRegister => 'Crear cuenta';

  @override
  String get authEmail => 'Direccion de correo electronico';

  @override
  String get authPassword => 'Contrasena';

  @override
  String get authConfirmPassword => 'Confirmar contrasena';

  @override
  String get authDisplayName => 'Nombre visible (opcional)';

  @override
  String get authCreateAccount => 'Crear mi cuenta';

  @override
  String get authAlreadyAccount => '?Ya registrado?';

  @override
  String get authNoAccount => '?Aun no tienes cuenta?';

  @override
  String get authLogout => 'Cerrar sesion';

  @override
  String get authLoginTitle => 'Inicio de sesion';

  @override
  String get authRegisterTitle => 'Crea tu cuenta';

  @override
  String get authPasswordHint => 'Minimo 8 caracteres';

  @override
  String get authError => 'Error de inicio de sesion';

  @override
  String get authEmailInvalid => 'Direccion de correo electronico invalida';

  @override
  String get authPasswordTooShort =>
      'La contrasena debe tener al menos 8 caracteres';

  @override
  String get authPasswordMismatch => 'Las contrasenas no coinciden';

  @override
  String get authForgotTitle => 'Restablecer contrasena';

  @override
  String get authForgotSteps =>
      '1) Solicita un enlace  2) Pega el token  3) Elige una nueva contrasena';

  @override
  String get authForgotSendLink => 'Enviar enlace de restablecimiento';

  @override
  String get authForgotResetTokenLabel => 'Token de restablecimiento';

  @override
  String get authForgotNewPasswordLabel => 'Nueva contrasena';

  @override
  String get authForgotSubmitNewPassword => 'Confirmar nueva contrasena';

  @override
  String get authForgotRequestAccepted =>
      'Si existe una cuenta, se ha enviado un enlace de restablecimiento.';

  @override
  String get authForgotResetSuccess =>
      'Contrasena actualizada. Ya puedes iniciar sesion.';

  @override
  String get authVerifyTitle => 'Verificar mi correo';

  @override
  String get authVerifyInstructions =>
      'Solicita un nuevo enlace y pega el token de verificacion.';

  @override
  String get authVerifySendLink => 'Enviar enlace de verificacion';

  @override
  String get authVerifyTokenLabel => 'Token de verificacion';

  @override
  String get authVerifySubmit => 'Confirmar verificacion';

  @override
  String get authVerifyRequestAccepted =>
      'Enlace de verificacion enviado (si la cuenta existe).';

  @override
  String get authVerifySuccess =>
      'Correo verificado. Ya puedes iniciar sesion.';

  @override
  String get authTokenRequired => 'Token obligatorio.';

  @override
  String get authEmailInvalidPrompt =>
      'Introduce una direccion de correo valida.';

  @override
  String get authDebugTokenLabel => 'Token debug (tests)';

  @override
  String get adminObsTitle => 'Admin observability';

  @override
  String get adminObsExportCsv => 'Exportar CSV de cohortes';

  @override
  String get adminObsCsvCopied => 'CSV de cohortes copiado al portapapeles';

  @override
  String get adminObsExportFailed => 'No se puede exportar';

  @override
  String get adminObsWindowLabel => 'Ventana';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonDays => 'dias';

  @override
  String get analyticsConsentTitle => 'Estadisticas anonimas';

  @override
  String get analyticsConsentMessage =>
      'MINT utiliza estadisticas anonimas para mejorar la experiencia. No se recogen datos personales.';

  @override
  String get analyticsAccept => 'Aceptar';

  @override
  String get analyticsRefuse => 'Rechazar';

  @override
  String get askMintTitle => 'Ask MINT';

  @override
  String get askMintSubtitle => 'Haz tus preguntas sobre finanzas suizas';

  @override
  String get askMintConfigureTitle => 'Configura tu IA';

  @override
  String get askMintConfigureBody =>
      'Para hacer preguntas sobre finanzas suizas, conecta tu propia clave API (Claude, OpenAI o Mistral). Tu clave se cifra localmente y nunca se almacena en nuestros servidores.';

  @override
  String get askMintConfigureButton => 'Configurar mi clave API';

  @override
  String get askMintEmptyTitle => 'Hazme una pregunta';

  @override
  String get askMintEmptySubtitle =>
      'Puedo ayudarte con finanzas suizas: 3er pilar, LPP, impuestos, presupuesto...';

  @override
  String get askMintSuggestedTitle => 'SUGERENCIAS';

  @override
  String get askMintSuggestion1 =>
      'Comment fonctionne le 3e pilier en Suisse ?';

  @override
  String get askMintSuggestion2 =>
      'Dois-je choisir la rente ou le capital LPP ?';

  @override
  String get askMintSuggestion3 => '?Como puedo optimizar mis impuestos?';

  @override
  String get askMintSuggestion4 => '?Que es el rescate LPP?';

  @override
  String get askMintInputHint => 'Haz tu pregunta sobre finanzas suizas...';

  @override
  String get askMintSourcesTitle => 'Fuentes';

  @override
  String get askMintErrorInvalidKey =>
      'Tu clave API parece invalida o caducada. Verificala en los ajustes.';

  @override
  String get askMintErrorRateLimit =>
      'Limite de solicitudes alcanzado. Espera un momento antes de intentarlo de nuevo.';

  @override
  String get askMintErrorGeneric =>
      'Se produjo un error. Verifica tu conexion e intentalo de nuevo.';

  @override
  String get askMintDisclaimer =>
      'Las respuestas son generadas por IA y no constituyen asesoramiento financiero personalizado.';

  @override
  String get byokTitle => 'Inteligencia Artificial';

  @override
  String get byokSubtitle =>
      'Conecta tu propio LLM para respuestas personalizadas';

  @override
  String get byokProviderLabel => 'Proveedor';

  @override
  String get byokApiKeyLabel => 'Clave API';

  @override
  String get byokTestButton => 'Probar la clave';

  @override
  String get byokTesting => 'Prueba en curso...';

  @override
  String get byokSaveButton => 'Guardar';

  @override
  String get byokSaved => 'Clave guardada con exito';

  @override
  String get byokTestSuccess => '!Conexion exitosa! Tu IA esta lista.';

  @override
  String get byokPrivacyTitle => 'Tu clave, tus datos';

  @override
  String get byokPrivacyBody =>
      'Tu clave API se almacena cifrada en tu dispositivo. Se transmite de forma segura (HTTPS) a nuestro servidor para comunicarse con el proveedor de IA, y se elimina inmediatamente — nunca se almacena en el servidor.';

  @override
  String get byokPrivacyShort =>
      'Clave cifrada localmente, nunca almacenada en nuestros servidores';

  @override
  String get byokClearButton => 'Eliminar la clave guardada';

  @override
  String get byokClearTitle => '?Eliminar la clave?';

  @override
  String get byokClearMessage =>
      'Esto eliminara tu clave API almacenada localmente. Puedes configurar una nueva en cualquier momento.';

  @override
  String get byokClearCancel => 'Cancelar';

  @override
  String get byokClearConfirm => 'Eliminar';

  @override
  String get byokLearnTitle => 'Acerca de BYOK';

  @override
  String get byokLearnHeading => '?Que es BYOK (Bring Your Own Key)?';

  @override
  String get byokLearnBody =>
      'BYOK te permite usar tu propia clave API de un proveedor de IA (Claude, OpenAI, Mistral) para obtener respuestas personalizadas sobre finanzas suizas.\n\nVentajas:\n• Control total sobre tus datos\n• Sin costes ocultos de MINT\n• Solo pagas lo que consumes\n• Clave encriptada en tu dispositivo';

  @override
  String get profileAiTitle => 'Inteligencia Artificial';

  @override
  String get profileAiByok => 'Ask MINT (BYOK)';

  @override
  String get profileAiConfigured => 'Configurado';

  @override
  String get profileAiNotConfigured => 'No configurado';

  @override
  String get documentsTitle => 'Mis documentos';

  @override
  String get documentsSubtitle =>
      'Subida y analisis de tus documentos financieros';

  @override
  String get documentsUploadTitle => 'Sube tu certificado LPP';

  @override
  String get documentsUploadBody =>
      'MINT extrae automaticamente tus datos de prevision profesional';

  @override
  String get documentsUploadButton => 'Elegir un archivo PDF';

  @override
  String get documentsAnalyzing => 'Analisis en curso...';

  @override
  String documentsConfidence(String confidence) {
    return 'Confianza: $confidence%';
  }

  @override
  String documentsFieldsFound(String found, String total) {
    return '$found campos extraidos de $total';
  }

  @override
  String get documentsConfirmButton => 'Confirmar y actualizar mi perfil';

  @override
  String get documentsDeleteButton => 'Eliminar este documento';

  @override
  String get documentsDeleteTitle => '?Eliminar el documento?';

  @override
  String get documentsDeleteMessage => 'Esta accion es irreversible.';

  @override
  String get documentsPrivacy =>
      'Tus documentos se analizan localmente y nunca se comparten con terceros. Puedes eliminarlos en cualquier momento.';

  @override
  String get documentsEmpty => 'Ningun documento';

  @override
  String get documentsLppCertificate => 'Certificado LPP';

  @override
  String get documentsUnknown => 'Documento desconocido';

  @override
  String get documentsCategoryEpargne => 'Ahorro';

  @override
  String get documentsCategorySalaire => 'Salario';

  @override
  String get documentsCategoryTaux => 'Tasa de conversion';

  @override
  String get documentsCategoryRisque => 'Cobertura de riesgo';

  @override
  String get documentsCategoryRachat => 'Rescate';

  @override
  String get documentsCategoryCotisations => 'Cotizaciones';

  @override
  String get documentsFieldAvoirObligatoire => 'Haber de vejez obligatorio';

  @override
  String get documentsFieldAvoirSurobligatoire =>
      'Haber de vejez supraobligatorio';

  @override
  String get documentsFieldAvoirTotal => 'Haber de vejez total';

  @override
  String get documentsFieldSalaireAssure => 'Salario asegurado';

  @override
  String get documentsFieldSalaireAvs => 'Salario AVS';

  @override
  String get documentsFieldDeductionCoordination => 'Deduccion de coordinacion';

  @override
  String get documentsFieldTauxObligatoire => 'Tasa de conversion obligatoria';

  @override
  String get documentsFieldTauxSurobligatoire =>
      'Tasa de conversion supraobligatoria';

  @override
  String get documentsFieldTauxEnveloppe => 'Tasa de conversion envolvente';

  @override
  String get documentsFieldRenteInvalidite => 'Renta anual de invalidez';

  @override
  String get documentsFieldCapitalDeces => 'Capital de fallecimiento';

  @override
  String get documentsFieldRenteConjoint => 'Renta anual del conyuge';

  @override
  String get documentsFieldRenteEnfant => 'Renta anual por hijo';

  @override
  String get documentsFieldRachatMax => 'Rescate maximo posible';

  @override
  String get documentsFieldCotisationEmploye => 'Cotizacion anual del empleado';

  @override
  String get documentsFieldCotisationEmployeur =>
      'Cotizacion anual del empleador';

  @override
  String get documentsWarningsTitle => 'Puntos de atencion';

  @override
  String get profileDocuments => 'Mis documentos';

  @override
  String profileDocumentsCount(String count) {
    return '$count documento(s)';
  }

  @override
  String get bankImportTitle => 'Importar mis extractos';

  @override
  String get bankImportSubtitle => 'Analisis automatico de tus transacciones';

  @override
  String get bankImportUploadTitle => 'Importa tu extracto bancario';

  @override
  String get bankImportUploadBody =>
      'CSV o PDF — UBS, PostFinance, Raiffeisen, ZKB y otros bancos suizos';

  @override
  String get bankImportUploadButton => 'Elegir un archivo';

  @override
  String get bankImportAnalyzing => 'Analisis de transacciones...';

  @override
  String bankImportBankDetected(String bank) {
    return '$bank detectado';
  }

  @override
  String bankImportPeriod(String start, String end) {
    return 'Periodo: $start - $end';
  }

  @override
  String bankImportTransactionCount(String count) {
    return '$count transacciones';
  }

  @override
  String get bankImportIncome => 'Ingresos';

  @override
  String get bankImportExpenses => 'Gastos';

  @override
  String get bankImportCategories => 'Reparto por categoria';

  @override
  String get bankImportRecurring => 'Cargos recurrentes detectados';

  @override
  String bankImportPerMonth(String amount) {
    return '$amount/mes';
  }

  @override
  String get bankImportBudgetPreview => 'Tu presupuesto estimado';

  @override
  String get bankImportMonthlyIncome => 'Ingreso mensual';

  @override
  String get bankImportFixedCharges => 'Cargos fijos';

  @override
  String get bankImportVariable => 'Gastos variables';

  @override
  String get bankImportSavingsRate => 'Tasa de ahorro';

  @override
  String get bankImportButton => 'Importar a mi presupuesto';

  @override
  String get bankImportPrivacy =>
      'Tus extractos se analizan localmente. Las transacciones nunca se almacenan en nuestros servidores.';

  @override
  String get bankImportSuccess => 'Presupuesto actualizado con exito';

  @override
  String get bankImportCategoryLogement => 'Vivienda';

  @override
  String get bankImportCategoryAlimentation => 'Alimentacion';

  @override
  String get bankImportCategoryTransport => 'Transporte';

  @override
  String get bankImportCategoryAssurance => 'Seguro';

  @override
  String get bankImportCategoryTelecom => 'Telecom';

  @override
  String get bankImportCategoryImpots => 'Impuestos';

  @override
  String get bankImportCategorySante => 'Salud';

  @override
  String get bankImportCategoryLoisirs => 'Ocio';

  @override
  String get bankImportCategoryEpargne => 'Ahorro';

  @override
  String get bankImportCategorySalaire => 'Salario';

  @override
  String get bankImportCategoryRestaurant => 'Restaurante';

  @override
  String get bankImportCategoryDivers => 'Varios';

  @override
  String get jobCompareTitle => 'Comparar dos empleos';

  @override
  String get jobCompareSubtitle => 'Descubre el salario invisible';

  @override
  String get jobCompareIntro =>
      'El salario bruto no lo dice todo. Compara el salario invisible (previsión, seguros) entre dos puestos.';

  @override
  String get jobCompareCurrentJob => 'EMPLEO ACTUAL';

  @override
  String get jobCompareNewJob => 'EMPLEO PREVISTO';

  @override
  String get jobCompareSalaireBrut => 'Salario bruto anual';

  @override
  String get jobCompareAge => 'Tu edad';

  @override
  String get jobComparePartEmployeur => 'Parte empleador LPP';

  @override
  String get jobCompareTauxConversion => 'Tasa de conversion';

  @override
  String get jobCompareAvoirVieillesse => 'Haber de vejez actual';

  @override
  String get jobCompareCouvertureInvalidite => 'Cobertura de invalidez';

  @override
  String get jobCompareCapitalDeces => 'Capital de fallecimiento';

  @override
  String get jobCompareRachatMax => 'Rescate maximo';

  @override
  String get jobCompareIjm => 'IJM colectiva incluida';

  @override
  String get jobCompareButton => 'Comparar';

  @override
  String get jobCompareResults => 'Resultados';

  @override
  String get jobCompareAxis => 'Eje';

  @override
  String get jobCompareActuel => 'Actual';

  @override
  String get jobCompareNouveau => 'Nuevo';

  @override
  String get jobCompareDelta => 'Diferencia';

  @override
  String get jobCompareSalaireNet => 'Salario neto';

  @override
  String get jobCompareCotisLpp => 'Cotizaciones LPP';

  @override
  String get jobCompareCapitalRetraite => 'Capital de jubilacion';

  @override
  String get jobCompareRenteMois => 'Renta/mes';

  @override
  String get jobCompareCouvertureDeces => 'Cobertura de fallecimiento';

  @override
  String get jobCompareInvalidite => 'Cobertura de invalidez';

  @override
  String get jobCompareRachat => 'Rescate max';

  @override
  String get jobCompareLifetimeImpact => 'Impacto en toda la jubilacion';

  @override
  String get jobCompareAlerts => 'Puntos de atencion';

  @override
  String get jobCompareChecklist => 'Antes de firmar';

  @override
  String get jobCompareChecklistReglement =>
      'Pedir el reglamento de la caja de pensiones';

  @override
  String get jobCompareChecklistTaux =>
      'Verificar la tasa de conversion supraobligatoria';

  @override
  String get jobCompareChecklistPart => 'Comparar la parte del empleador';

  @override
  String get jobCompareChecklistCoordination =>
      'Verificar la deduccion de coordinacion';

  @override
  String get jobCompareChecklistIjm =>
      'Preguntar si la IJM colectiva esta incluida';

  @override
  String get jobCompareChecklistRachat =>
      'Verificar el plazo de espera para rescate';

  @override
  String get jobCompareChecklistRisque =>
      'Calcular el impacto en las prestaciones de riesgo';

  @override
  String get jobCompareChecklistLibrePassage =>
      'Verificar el libre paso: transferencia en 30 dias max';

  @override
  String get jobCompareEducational =>
      'El salario invisible representa el 10-30% de tu remuneracion total.';

  @override
  String get jobCompareVerdictBetter => 'El nuevo puesto es globalmente mejor';

  @override
  String get jobCompareVerdictWorse =>
      'El puesto actual ofrece mejor proteccion';

  @override
  String get jobCompareVerdictComparable => 'Los dos puestos son comparables';

  @override
  String get jobCompareDetailedComparison => 'Comparacion detallada';

  @override
  String get jobCompareDetailedSubtitle => '7 ejes de previsión';

  @override
  String get jobCompareReduce => 'Reducir';

  @override
  String get jobCompareShowDetails => 'Ver detalles';

  @override
  String get jobCompareChecklistSubtitle => 'Lista de verificación';

  @override
  String get jobCompareLifetimeTitle => 'Impacto en toda la jubilacion';

  @override
  String get jobCompareDisclaimer =>
      'Los resultados presentados son estimaciones indicativas. No constituyen asesoramiento financiero personalizado. Consulta tu caja de pensiones y un·a especialista cualificado·a antes de cualquier decisión.';

  @override
  String get divorceTitle => 'Impacto financiero de un divorcio';

  @override
  String get divorceSubtitle => 'Anticipar las consecuencias financieras';

  @override
  String get divorceIntro =>
      'Un divorcio tiene consecuencias financieras a menudo subestimadas: division del patrimonio, de la prevision (LPP/3a), impacto fiscal y pension alimenticia.';

  @override
  String get divorceSituationFamiliale => 'SITUACIÓN FAMILIAR';

  @override
  String get divorceSituationSubtitle =>
      'Duración del matrimonio, hijos, régimen';

  @override
  String get divorceDureeMariage => 'Duración del matrimonio';

  @override
  String get divorceNombreEnfants => 'Numero de hijos';

  @override
  String get divorceRegimeMatrimonial => 'Régimen matrimonial';

  @override
  String get divorceRegimeAcquets =>
      'Participacion en los gananciales (por defecto)';

  @override
  String get divorceRegimeCommunaute => 'Comunidad de bienes';

  @override
  String get divorceRegimeSeparation => 'Separacion de bienes';

  @override
  String get divorceRevenus => 'INGRESOS';

  @override
  String get divorceRevenusSubtitle => 'Ingreso anual de cada cónyuge';

  @override
  String get divorceConjoint1Revenu => 'Cónyuge 1 — ingreso anual';

  @override
  String get divorceConjoint2Revenu => 'Cónyuge 2 — ingreso anual';

  @override
  String get divorcePrevoyance => 'PREVISIÓN';

  @override
  String get divorcePrevoyanceSubtitle =>
      'LPP y 3a acumulados durante el matrimonio';

  @override
  String get divorceLppConjoint1 => 'LPP Cónyuge 1 (durante el matrimonio)';

  @override
  String get divorceLppConjoint2 => 'LPP Cónyuge 2 (durante el matrimonio)';

  @override
  String get divorce3aConjoint1 => '3a Cónyuge 1';

  @override
  String get divorce3aConjoint2 => '3a Cónyuge 2';

  @override
  String get divorcePatrimoine => 'PATRIMONIO';

  @override
  String get divorcePatrimoineSubtitle => 'Fortuna y deudas comunes';

  @override
  String get divorceFortuneCommune => 'Patrimonio comun';

  @override
  String get divorceDettesCommunes => 'Deudas comunes';

  @override
  String get divorceSimuler => 'Simular';

  @override
  String get divorcePartageLpp => 'REPARTO LPP';

  @override
  String get divorceTotalLpp => 'Total LPP (durante el matrimonio)';

  @override
  String get divorcePartConjoint1 => 'Parte Cónyuge 1';

  @override
  String get divorcePartConjoint2 => 'Parte Cónyuge 2';

  @override
  String get divorceTransfert => 'Transferencia';

  @override
  String get divorceImpactFiscal => 'IMPACTO FISCAL';

  @override
  String get divorceImpotMarie => 'Impuesto estimado (casado)';

  @override
  String get divorceImpotConjoint1 => 'Impuesto Cónyuge 1 (individual)';

  @override
  String get divorceImpotConjoint2 => 'Impuesto Cónyuge 2 (individual)';

  @override
  String get divorceTotalApresDivorce => 'Total después del divorcio';

  @override
  String get divorceDifference => 'Diferencia';

  @override
  String get divorcePartagePatrimoine => 'REPARTO DEL PATRIMONIO';

  @override
  String get divorceFortuneNette => 'Fortuna neta';

  @override
  String get divorcePensionAlimentaire => 'PENSIÓN ALIMENTICIA (ESTIMACIÓN)';

  @override
  String get divorcePensionAlimentaireNote =>
      'Estimacion basada en la diferencia de ingresos y el numero de hijos.';

  @override
  String get divorcePointsAttention => 'PUNTOS DE ATENCIÓN';

  @override
  String get divorceActions => 'Acciones a emprender';

  @override
  String get divorceActionsSubtitle => 'Checklist de preparación';

  @override
  String get divorceEduAcquets =>
      '?Que es la participacion en los gananciales?';

  @override
  String get divorceEduAcquetsBody =>
      'La participacion en los gananciales es el regimen matrimonial por defecto en Suiza (CC art. 181 ss). Los gananciales se dividen por partes iguales en caso de divorcio.';

  @override
  String get divorceEduLpp => '?Como funciona la division LPP?';

  @override
  String get divorceEduLppBody =>
      'Los haberes LPP acumulados durante el matrimonio se dividen por partes iguales (CC art. 122).';

  @override
  String get divorceDisclaimer =>
      'Los resultados presentados son estimaciones indicativas y no constituyen asesoramiento jurídico o financiero personalizado. Cada situación es única. Consulte a un(a) abogado(a) especializado(a) en derecho de familia y a un·a especialista en finanzas antes de tomar cualquier decisión.';

  @override
  String get successionTitle => 'Sucesión y transmisión';

  @override
  String get successionSubtitle => 'Nuevo derecho sucesorio 2023';

  @override
  String get successionIntro =>
      'El nuevo derecho sucesorio (2023) ha ampliado la cuota disponible. Tienes ahora mas libertad para favorecer a ciertos herederos.';

  @override
  String get successionSituationPersonnelle => 'Situacion personal';

  @override
  String get successionSituationSubtitle => 'Estado civil, herederos';

  @override
  String get successionStatutCivil => 'Estado civil';

  @override
  String get successionCivilMarie => 'Casado/a';

  @override
  String get successionCivilCelibataire => 'Soltero/a';

  @override
  String get successionCivilDivorce => 'Divorciado/a';

  @override
  String get successionCivilVeuf => 'Viudo/a';

  @override
  String get successionCivilConcubinage => 'Union de hecho';

  @override
  String get successionNombreEnfants => 'Numero de hijos';

  @override
  String get successionParentsVivants => 'Padres vivos';

  @override
  String get successionFratrie => 'Hermanos/Hermanas';

  @override
  String get successionConcubin => 'Companero/a';

  @override
  String get successionFortune => 'Patrimonio';

  @override
  String get successionFortuneSubtitle => 'Patrimonio total, 3a, LPP';

  @override
  String get successionFortuneTotale => 'Patrimonio total';

  @override
  String get successionAvoirs3a => 'Haberes 3er pilar';

  @override
  String get successionCapitalDecesLpp => 'Capital de fallecimiento LPP';

  @override
  String get successionCanton => 'Canton';

  @override
  String get successionTestament => 'Testamento';

  @override
  String get successionTestamentSubtitle => 'CC art. 498–504';

  @override
  String get successionHasTestament => 'Tengo un testamento';

  @override
  String get successionQuotiteBeneficiaire =>
      '?Quien recibe la cuota disponible?';

  @override
  String get successionBeneficiaireConjoint => 'Conyuge';

  @override
  String get successionBeneficiaireEnfants => 'Hijos';

  @override
  String get successionBeneficiaireConcubin => 'Companero/a';

  @override
  String get successionBeneficiaireTiers => 'Terceros / Obra benefica';

  @override
  String get successionSimuler => 'Simular';

  @override
  String get successionRepartitionLegale => 'Reparto legal';

  @override
  String get successionRepartitionTestament => 'Reparto con testamento';

  @override
  String get successionReservesHereditaires => 'Reservas hereditarias (2023)';

  @override
  String get successionReservesNote =>
      'Importes protegidos por ley (intocables)';

  @override
  String get successionQuotiteDisponible => 'Cuota disponible';

  @override
  String get successionQuotiteNote =>
      'Este importe puede ser libremente asignado por testamento.';

  @override
  String get successionFiscalite => 'Fiscalidad sucesoria';

  @override
  String get successionExonere => 'Exento';

  @override
  String get successionTotalImpot => 'Total impuesto sucesorio';

  @override
  String get succession3aOpp3 => 'Beneficiarios 3a (OPP3 art. 2)';

  @override
  String get succession3aNote =>
      'El 3er pilar NO sigue tu testamento. El orden de beneficiarios esta fijado por ley.';

  @override
  String get successionPointsAttention => 'Puntos de atencion';

  @override
  String get successionChecklist => 'Proteccion de mis seres queridos';

  @override
  String get successionChecklistSubtitle => 'Acciones a emprender';

  @override
  String get successionEduQuotite => '?Que es la cuota disponible?';

  @override
  String get successionEduQuotiteBody =>
      'La cuota disponible es la parte de tu sucesion que puedes asignar libremente por testamento. Desde 2023, la reserva de los descendientes es de 1/2.';

  @override
  String get successionEdu3a => 'El 3a y la sucesion: !atencion!';

  @override
  String get successionEdu3aBody =>
      'El 3er pilar se paga directamente segun la OPP3, no segun tu testamento.';

  @override
  String get successionEduConcubin => 'Los companeros y la sucesion';

  @override
  String get successionEduConcubinBody =>
      'Los companeros no tienen derechos sucesorios legales. Sin testamento, no reciben nada.';

  @override
  String get successionDisclaimer =>
      'Información educativa, no asesoramiento jurídico (LSFin/CC).';

  @override
  String get lifeEventsSection => 'Eventos de vida';

  @override
  String get lifeEventDivorce => 'Divorcio';

  @override
  String get lifeEventSuccession => 'Sucesion';

  @override
  String get coachingTitle => 'Coaching proactivo';

  @override
  String get coachingSubtitle => 'Tus sugerencias personalizadas';

  @override
  String get coachingIntro =>
      'Sugerencias personalizadas basadas en tu perfil. Cuanto mas completo el perfil, mas pertinentes los consejos.';

  @override
  String get coachingFilterAll => 'Todos';

  @override
  String get coachingFilterHigh => 'Alta prioridad';

  @override
  String get coachingFilterFiscal => 'Fiscalidad';

  @override
  String get coachingFilterPrevoyance => 'Prevision';

  @override
  String get coachingFilterBudget => 'Presupuesto';

  @override
  String get coachingFilterRetraite => 'Jubilacion';

  @override
  String get coachingNoTips =>
      'Tu perfil está completo. Nada que señalar por ahora.';

  @override
  String coachingImpact(String amount) {
    return 'Impacto estimado: $amount';
  }

  @override
  String get coachingSource => 'Fuente';

  @override
  String coachingTipCount(String count) {
    return '$count consejos';
  }

  @override
  String get coachingPriorityHigh => 'Alta prioridad';

  @override
  String get coachingPriorityMedium => 'Prioridad media';

  @override
  String get coachingPriorityLow => 'Informacion';

  @override
  String get coaching3aDeadlineTitle =>
      'Aportacion 3a antes del 31 de diciembre';

  @override
  String coaching3aDeadlineMessage(
      String remaining, String plafond, String impact) {
    return 'Te queda $remaining de margen en tu techo 3a ($plafond). Una aportacion antes del 31 de diciembre podria reducir tu carga fiscal en unos $impact.';
  }

  @override
  String get coaching3aDeadlineAction => 'Simular mi 3a';

  @override
  String get coaching3aMissingTitle => 'No tienes 3er pilar';

  @override
  String coaching3aMissingMessage(
      String plafond, String impact, String canton) {
    return 'Abrir un 3er pilar te permitiria deducir hasta $plafond de tu renta imponible cada ano. El ahorro fiscal estimado es de $impact por ano en el canton de $canton.';
  }

  @override
  String get coaching3aMissingAction => 'Descubrir el 3er pilar';

  @override
  String get coaching3aNotMaxedTitle => 'Techo 3a no alcanzado';

  @override
  String coaching3aNotMaxedMessage(
      String current, String plafond, String remaining, String impact) {
    return 'Tu aportacion 3a actual es de $current sobre un techo de $plafond. Aportar el resto de $remaining podria representar un ahorro fiscal de unos $impact.';
  }

  @override
  String get coaching3aNotMaxedAction => 'Simular mi 3a';

  @override
  String get coachingLppBuybackTitle => 'Rescate LPP posible';

  @override
  String coachingLppBuybackMessage(String gap, String impact) {
    return 'Tienes una brecha de prevision de $gap. Un rescate voluntario podria ahorrarte unos $impact de impuestos mejorando tu jubilacion.';
  }

  @override
  String get coachingLppBuybackAction => 'Simular un rescate LPP';

  @override
  String get coachingTaxDeadlineTitle => 'Declaracion de impuestos a presentar';

  @override
  String coachingTaxDeadlineMessage(String canton, String days) {
    return 'El plazo para tu declaracion fiscal en el canton de $canton es el 31 de marzo. Quedan $days dias.';
  }

  @override
  String get coachingTaxDeadlineAction => 'Ver mi checklist fiscal';

  @override
  String coachingRetirementTitle(String years) {
    return 'Jubilacion en $years anos';
  }

  @override
  String coachingRetirementMessage(String years) {
    return 'A $years anos de la jubilacion, es importante verificar tu estrategia de prevision. ?Has optimizado tus rescates LPP? ?Tus cuentas 3a estan diversificadas?';
  }

  @override
  String get coachingRetirementAction => 'Planificar mi jubilacion';

  @override
  String get coachingEmergencyTitle => 'Reserva de emergencia insuficiente';

  @override
  String coachingEmergencyMessage(String months, String deficit) {
    return 'Tu ahorro disponible cubre $months meses de cargos fijos. Los expertos recomiendan al menos 3 meses. Te faltan unos $deficit.';
  }

  @override
  String get coachingEmergencyAction => 'Ver mi presupuesto';

  @override
  String coachingDebtTitle(String ratio) {
    return 'Tasa de endeudamiento elevada ($ratio%)';
  }

  @override
  String coachingDebtMessage(String ratio) {
    return 'Tu tasa de endeudamiento estimada es del $ratio%, por encima del umbral del 33% recomendado por los bancos suizos.';
  }

  @override
  String get coachingDebtAction => 'Analizar mis deudas';

  @override
  String get coachingPartTimeTitle => 'Tiempo parcial: brecha de prevision';

  @override
  String coachingPartTimeMessage(String rate) {
    return 'Al $rate% de actividad, tu prevision profesional esta reducida. La deduccion de coordinacion penaliza aun mas a los trabajadores a tiempo parcial.';
  }

  @override
  String get coachingPartTimeAction => 'Simular mi prevision';

  @override
  String get coachingIndependantTitle => 'Independiente: sin LPP obligatoria';

  @override
  String get coachingIndependantMessage =>
      'Como independiente, no estas sujeto a la LPP obligatoria. Tu prevision se basa en el AVS y el 3er pilar. Maximiza tus aportaciones 3a.';

  @override
  String get coachingIndependantAction => 'Explorar mis opciones';

  @override
  String get coachingBudgetMissingTitle => 'Aun sin presupuesto';

  @override
  String get coachingBudgetMissingMessage =>
      'Un presupuesto estructurado es la base de cualquier estrategia financiera. Permite identificar tu capacidad real de ahorro.';

  @override
  String get coachingBudgetMissingAction => 'Crear mi presupuesto';

  @override
  String get coachingAge25Title => '25 anos: abrir el 3er pilar';

  @override
  String get coachingAge25Message =>
      'A los 25 anos es el momento ideal para abrir un 3er pilar. Gracias al interes compuesto, cada ano cuenta.';

  @override
  String get coachingAge35Title => '35 anos: revision de prevision';

  @override
  String get coachingAge35Message =>
      'A los 35 anos, verifica que tu prevision va por buen camino. ?Tienes un 3a? ?Tu LPP es suficiente?';

  @override
  String get coachingAge45Title => '45 anos: optimizar la estrategia';

  @override
  String get coachingAge45Message =>
      'A los 45 anos, quedan 20 anos para la jubilacion. Es el momento de optimizar: maximizar el 3a, considerar rescates LPP.';

  @override
  String get coachingAge50Title => '50 anos: preparar la jubilacion';

  @override
  String get coachingAge50Message =>
      'A los 50 anos, la jubilacion se acerca. Verifica tu haber LPP y planifica los ultimos rescates.';

  @override
  String get coachingAge55Title => '55 anos: ultima recta';

  @override
  String get coachingAge55Message =>
      'A los 55 anos, la planificacion fiscal del retiro se vuelve crucial. Escalonar los retiros 3a puede suponer un ahorro significativo.';

  @override
  String get coachingAge58Title => '58 anos: jubilacion anticipada posible';

  @override
  String get coachingAge58Message =>
      'A partir de los 58 anos, un retiro anticipado del 2º pilar es posible. Atencion: la renta sera reducida.';

  @override
  String get coachingAge63Title => '63 anos: ultimos ajustes';

  @override
  String get coachingAge63Message =>
      'A 2 anos de la jubilacion legal: finalizar la estrategia. Ultimo rescate LPP, eleccion renta/capital.';

  @override
  String get coachingDisclaimer =>
      'Las sugerencias presentadas son pistas de reflexion basadas en estimaciones simplificadas. No constituyen asesoramiento financiero personalizado. Consulta a un profesional cualificado antes de cualquier decision.';

  @override
  String get coachingDemoMode =>
      'Modo demo: perfil ejemplo (35 anos, VD, CHF 85\'000). Completa tu diagnostico para consejos personalizados.';

  @override
  String get coachingNowCardTitle => 'Coaching proactivo';

  @override
  String get coachingNowCardSubtitle =>
      'Consejos personalizados basados en tu perfil';

  @override
  String get coachingCategoryFiscalite => 'Fiscalidad';

  @override
  String get coachingCategoryPrevoyance => 'Prevision';

  @override
  String get coachingCategoryBudget => 'Presupuesto';

  @override
  String get coachingCategoryRetraite => 'Jubilacion';

  @override
  String get segmentsSection => 'Segmentos';

  @override
  String get segmentsGenderGapTitle => 'Gender gap prevision';

  @override
  String get segmentsGenderGapSubtitle =>
      'Impacto del tiempo parcial en la jubilacion';

  @override
  String get segmentsGenderGapAppBar => 'GENDER GAP PREVISION';

  @override
  String get segmentsGenderGapHeader => 'Brecha de prevision';

  @override
  String get segmentsGenderGapHeaderSub =>
      'Impacto del tiempo parcial en la jubilacion';

  @override
  String get segmentsGenderGapIntro =>
      'La deduccion de coordinacion (CHF 25\'725) no se prorratiza para el tiempo parcial, lo que penaliza aun mas a las personas que trabajan a tiempo reducido. Mueve el cursor para ver el impacto.';

  @override
  String get segmentsGenderGapTauxLabel => 'Tasa de actividad';

  @override
  String get segmentsGenderGapParams => 'Parametros';

  @override
  String get segmentsGenderGapRevenuLabel => 'Ingreso anual bruto (100%)';

  @override
  String get segmentsGenderGapAgeLabel => 'Edad';

  @override
  String get segmentsGenderGapAvoirLabel => 'Haber LPP actual';

  @override
  String get segmentsGenderGapAnneesCotisLabel => 'Anos de cotizacion';

  @override
  String get segmentsGenderGapCantonLabel => 'Canton';

  @override
  String get segmentsGenderGapRenteTitle => 'Renta LPP estimada';

  @override
  String segmentsGenderGapRenteSub(String years) {
    return 'Proyeccion a $years anos (edad 65)';
  }

  @override
  String get segmentsGenderGapAt100 => 'Al 100%';

  @override
  String segmentsGenderGapAtCurrent(String rate) {
    return 'Al $rate%';
  }

  @override
  String get segmentsGenderGapLacuneAnnuelle => 'Brecha anual';

  @override
  String get segmentsGenderGapLacuneTotale => 'Brecha total (~20 anos)';

  @override
  String get segmentsGenderGapCoordinationTitle =>
      'Entender la deduccion de coordinacion';

  @override
  String get segmentsGenderGapCoordinationBody =>
      'La deduccion de coordinacion es un importe fijo de CHF 25\'725 sustraido de tu salario bruto para calcular el salario coordinado (base LPP). Este importe es el mismo tanto si trabajas al 100% como al 50%.';

  @override
  String get segmentsGenderGapSalaireBrut100 => 'Salario bruto al 100%';

  @override
  String get segmentsGenderGapSalaireCoord100 => 'Salario coordinado al 100%';

  @override
  String segmentsGenderGapSalaireBrutCurrent(String rate) {
    return 'Salario bruto al $rate%';
  }

  @override
  String segmentsGenderGapSalaireCoordCurrent(String rate) {
    return 'Salario coordinado al $rate%';
  }

  @override
  String get segmentsGenderGapDeductionFixe =>
      'Deduccion de coordinacion (fija)';

  @override
  String get segmentsGenderGapOfsTitle => 'Estadistica OFS';

  @override
  String get segmentsGenderGapOfsStat =>
      'En Suiza, las mujeres reciben de media un 37% menos de renta que los hombres (OFS 2024)';

  @override
  String get segmentsGenderGapRecTitle => 'RECOMENDACIONES';

  @override
  String get segmentsGenderGapRecRachat => 'Rescate LPP voluntario';

  @override
  String get segmentsGenderGapRecRachatDesc =>
      'Un rescate voluntario permite colmar parcialmente la brecha de prevision beneficiandose de una deduccion fiscal.';

  @override
  String get segmentsGenderGapRec3a => '3er pilar maximizado';

  @override
  String get segmentsGenderGapRec3aDesc =>
      'Aporta el techo anual de CHF 7\'258 (asalariados) para compensar parcialmente la brecha LPP.';

  @override
  String get segmentsGenderGapRecCoord =>
      'Verificar la proporcionalidad de la coordinacion';

  @override
  String get segmentsGenderGapRecCoordDesc =>
      'Algunas cajas de pensiones prorratean la deduccion de coordinacion en funcion de la tasa de actividad.';

  @override
  String get segmentsGenderGapRecTaux =>
      'Explorar un aumento de la tasa de actividad';

  @override
  String get segmentsGenderGapRecTauxDesc =>
      'Incluso un aumento de 10 a 20 puntos puede reducir significativamente la brecha.';

  @override
  String get segmentsGenderGapDisclaimer =>
      'Los resultados presentados son estimaciones simplificadas a titulo indicativo. No constituyen asesoramiento financiero personalizado. Consulta tu caja de pensiones y un profesional cualificado.';

  @override
  String get segmentsGenderGapSources => 'Fuentes';

  @override
  String get segmentsFrontalierTitle => 'Fronterizo';

  @override
  String get segmentsFrontalierSubtitle => 'Derechos y obligaciones por pais';

  @override
  String get segmentsFrontalierAppBar => 'RECORRIDO FRONTERIZO';

  @override
  String get segmentsFrontalierHeader => 'Trabajador fronterizo';

  @override
  String get segmentsFrontalierHeaderSub => 'Derechos y obligaciones por pais';

  @override
  String get segmentsFrontalierIntro =>
      'Las reglas fiscales, de prevision y de seguro varian segun tu pais de residencia y tu canton de trabajo.';

  @override
  String get segmentsFrontalierPaysLabel => 'Pais de residencia';

  @override
  String get segmentsFrontalierCantonLabel => 'Canton de trabajo';

  @override
  String get segmentsFrontalierRulesTitle => 'REGLAS APLICABLES';

  @override
  String get segmentsFrontalierCatFiscal => 'Regimen fiscal';

  @override
  String get segmentsFrontalierCat3a => '3er pilar';

  @override
  String get segmentsFrontalierCatLpp => 'LPP / Libre paso';

  @override
  String get segmentsFrontalierCatAvs => 'AVS / Coordinacion';

  @override
  String get segmentsFrontalierQuasiResidentTitle =>
      'Estatuto de casi-residente (GE)';

  @override
  String get segmentsFrontalierQuasiResidentDesc =>
      'El estatuto de casi-residente es accesible si al menos el 90% de los ingresos del hogar provienen de Suiza.';

  @override
  String get segmentsFrontalierQuasiResidentCondition =>
      'Condicion: >= 90% de los ingresos del hogar provenientes de Suiza';

  @override
  String get segmentsFrontalierChecklist => 'Checklist fronterizo';

  @override
  String get segmentsFrontalierPaysFR => 'Francia';

  @override
  String get segmentsFrontalierPaysDE => 'Alemania';

  @override
  String get segmentsFrontalierPaysIT => 'Italia';

  @override
  String get segmentsFrontalierPaysAT => 'Austria';

  @override
  String get segmentsFrontalierPaysLI => 'Liechtenstein';

  @override
  String get segmentsFrontalierAttention => 'Atencion';

  @override
  String get segmentsFrontalierDisclaimer =>
      'Las informaciones presentadas son generales y pueden variar segun tu situacion personal. Consulta a un fiduciario especializado en situaciones transfronterizas.';

  @override
  String get segmentsFrontalierSources => 'Fuentes';

  @override
  String get segmentsIndependantTitle => 'Independiente';

  @override
  String get segmentsIndependantSubtitle => 'Cobertura y proteccion social';

  @override
  String get segmentsIndependantAppBar => 'RECORRIDO INDEPENDIENTE';

  @override
  String get segmentsIndependantHeader => 'Independiente';

  @override
  String get segmentsIndependantHeaderSub =>
      'Analisis de cobertura y proteccion';

  @override
  String get segmentsIndependantIntro =>
      'Como independiente, no tienes LPP obligatoria, ni IJM, ni LAA. Tu proteccion depende de tus diligencias personales.';

  @override
  String get segmentsIndependantRevenuLabel => 'Ingreso neto anual';

  @override
  String get segmentsIndependantCoverageTitle => 'Mi cobertura actual';

  @override
  String get segmentsIndependantLpp => 'LPP (afiliacion voluntaria)';

  @override
  String get segmentsIndependantIjm =>
      'IJM (indemnizacion diaria por enfermedad)';

  @override
  String get segmentsIndependantLaa => 'LAA (seguro de accidentes)';

  @override
  String get segmentsIndependant3a => '3er pilar (3a)';

  @override
  String get segmentsIndependantAnalyseTitle => 'ANALISIS DE COBERTURA';

  @override
  String get segmentsIndependantCouvert => 'Cubierto';

  @override
  String get segmentsIndependantNonCouvert => 'NO CUBIERTO';

  @override
  String get segmentsIndependantCritique => 'NO CUBIERTO — Critico';

  @override
  String get segmentsIndependantProtectionTitle =>
      'Coste de la proteccion completa';

  @override
  String get segmentsIndependantProtectionSub => 'Estimacion mensual';

  @override
  String get segmentsIndependantAvs => 'AVS / AI / APG';

  @override
  String get segmentsIndependantIjmEst => 'IJM (estimacion)';

  @override
  String get segmentsIndependantLaaEst => 'LAA (estimacion)';

  @override
  String get segmentsIndependant3aMax => '3er pilar (max)';

  @override
  String get segmentsIndependantTotalMensuel => 'Total mensual';

  @override
  String get segmentsIndependantAvsTitle => 'Cotizacion AVS independiente';

  @override
  String segmentsIndependantAvsDesc(String amount) {
    return 'Tu cotizacion AVS estimada: $amount/ano (tasa degresiva para ingresos inferiores a CHF 58\'800).';
  }

  @override
  String get segmentsIndependant3aTitle => '3er pilar — techo independiente';

  @override
  String get segmentsIndependant3aWithLpp =>
      'Con LPP voluntaria: techo 3a estandar de CHF 7\'258/ano.';

  @override
  String get segmentsIndependant3aWithoutLpp =>
      'Sin LPP: techo 3a \'grande\' del 20% del ingreso neto, max CHF 36\'288/ano.';

  @override
  String get segmentsIndependantRecTitle => 'RECOMENDACIONES';

  @override
  String get segmentsIndependantDisclaimer =>
      'Los importes presentados son estimaciones indicativas. Consulta a un fiduciario o asegurador antes de cualquier decision.';

  @override
  String get segmentsIndependantSources => 'Fuentes';

  @override
  String get segmentsIndependantAlertIjm =>
      'CRITICO: No tienes seguro IJM. En caso de enfermedad, no tendras ningun ingreso de reemplazo.';

  @override
  String get segmentsIndependantAlertLaa =>
      'IMPORTANTE: Sin seguro de accidentes individual (LAA), los gastos medicos en caso de accidente no estan cubiertos.';

  @override
  String get segmentsIndependantAlertLpp =>
      'Tu prevision se basa unicamente en el AVS y el 3er pilar.';

  @override
  String get segmentsIndependantAlert3a =>
      'No aprovechas el 3er pilar. Techo independiente: CHF 36\'288/ano.';

  @override
  String get segmentsDemoMode =>
      'Modo demo: perfil ejemplo. Completa tu diagnostico para resultados personalizados.';

  @override
  String get assurancesLamalTitle => 'Optimizador de franquicia LAMal';

  @override
  String get assurancesLamalSubtitle =>
      'Encuentra la franquicia ideal segun tus gastos de salud';

  @override
  String get assurancesLamalPrimeMensuelle => 'Prima mensual (franquicia 300)';

  @override
  String get assurancesLamalDepensesSante =>
      'Gastos de salud anuales estimados';

  @override
  String get assurancesLamalAdulte => 'Adulto';

  @override
  String get assurancesLamalEnfant => 'Nino/a';

  @override
  String get assurancesLamalFranchise => 'Franquicia';

  @override
  String get assurancesLamalPrimeAnnuelle => 'Prima anual';

  @override
  String get assurancesLamalCoutTotal => 'Coste total';

  @override
  String get assurancesLamalEconomie => 'Ahorro vs 300';

  @override
  String get assurancesLamalOptimale => 'Franquicia recomendada';

  @override
  String get assurancesLamalBreakEven => 'Umbral de rentabilidad';

  @override
  String get assurancesLamalDelaiRappel =>
      'Recordatorio: cambio posible antes del 30 de noviembre';

  @override
  String get assurancesLamalQuotePart => 'Cuota-parte (10%, max 700 CHF)';

  @override
  String get assurancesCoverageTitle => 'Revision de cobertura';

  @override
  String get assurancesCoverageSubtitle => 'Evalua tu proteccion de seguros';

  @override
  String get assurancesCoverageScore => 'Score de cobertura';

  @override
  String get assurancesCoverageLacunes => 'Brechas identificadas';

  @override
  String get assurancesCoverageStatut => 'Estatuto profesional';

  @override
  String get assurancesCoverageSalarie => 'Asalariado';

  @override
  String get assurancesCoverageIndependant => 'Independiente';

  @override
  String get assurancesCoverageSansEmploi => 'Sin empleo';

  @override
  String get assurancesCoverageHypotheque => 'Hipoteca en curso';

  @override
  String get assurancesCoverageFamille => 'Personas a cargo';

  @override
  String get assurancesCoverageLocataire => 'Inquilino';

  @override
  String get assurancesCoverageVoyages => 'Viajes frecuentes';

  @override
  String get assurancesCoverageIjm => 'IJM colectiva (empleador)';

  @override
  String get assurancesCoverageLaa => 'LAA (seguro de accidentes)';

  @override
  String get assurancesCoverageRc => 'RC privada';

  @override
  String get assurancesCoverageMenage => 'Seguro de hogar';

  @override
  String get assurancesCoverageJuridique => 'Proteccion juridica';

  @override
  String get assurancesCoverageVoyage => 'Seguro de viaje';

  @override
  String get assurancesCoverageDeces => 'Seguro de fallecimiento';

  @override
  String get assurancesCoverageCouvert => 'Cubierto';

  @override
  String get assurancesCoverageNonCouvert => 'No cubierto';

  @override
  String get assurancesCoverageAVerifier => 'A verificar';

  @override
  String get assurancesCoverageCritique => 'Critico';

  @override
  String get assurancesCoverageHaute => 'Alta';

  @override
  String get assurancesCoverageMoyenne => 'Media';

  @override
  String get assurancesCoverageBasse => 'Baja';

  @override
  String get assurancesDemoMode => 'MODO DEMO';

  @override
  String get assurancesDisclaimer =>
      'Este analisis es indicativo. Las primas varian segun la aseguradora, la region y el modelo de seguro. Consulta tu caja de salud para cifras exactas.';

  @override
  String get assurancesSection => 'Seguros';

  @override
  String get assurancesLamalTile => 'Franquicia LAMal';

  @override
  String get assurancesLamalTileSub => 'Encuentra la franquicia ideal';

  @override
  String get assurancesCoverageTile => 'Revision de cobertura';

  @override
  String get assurancesCoverageTileSub => 'Evalua tu proteccion de seguros';

  @override
  String get openBankingTitle => 'Open Banking';

  @override
  String get openBankingSubtitle => 'Conecta tus cuentas bancarias';

  @override
  String get openBankingFinmaGate =>
      'Funcionalidad en preparacion — consulta regulatoria FINMA en curso';

  @override
  String get openBankingDemoData =>
      'Los datos mostrados son ejemplos de demostracion';

  @override
  String get openBankingTotalBalance => 'Saldo total';

  @override
  String get openBankingAccounts => 'Cuentas conectadas';

  @override
  String get openBankingAddBank => 'Anadir un banco';

  @override
  String get openBankingAddBankDisabled => 'Disponible tras consulta FINMA';

  @override
  String get openBankingTransactions => 'Transacciones';

  @override
  String get openBankingNoTransactions => 'Ninguna transaccion';

  @override
  String get openBankingIncome => 'Ingresos';

  @override
  String get openBankingExpenses => 'Gastos';

  @override
  String get openBankingNetSavings => 'Ahorro neto';

  @override
  String get openBankingSavingsRate => 'Tasa de ahorro';

  @override
  String get openBankingConsents => 'Consentimientos';

  @override
  String get openBankingConsentActive => 'Activo';

  @override
  String get openBankingConsentExpiring => 'Caduca pronto';

  @override
  String get openBankingConsentExpired => 'Caducado';

  @override
  String get openBankingConsentRevoke => 'Revocar';

  @override
  String get openBankingConsentRevoked => 'Revocado';

  @override
  String get openBankingConsentScopes => 'Autorizaciones';

  @override
  String get openBankingConsentScopeAccounts => 'Cuentas';

  @override
  String get openBankingConsentScopeBalances => 'Saldos';

  @override
  String get openBankingConsentScopeTransactions => 'Transacciones';

  @override
  String get openBankingConsentDuration => 'Duracion maxima: 90 dias';

  @override
  String get openBankingNlpdTitle => 'Tus derechos (nLPD)';

  @override
  String get openBankingNlpdRevoke =>
      'Puedes revocar tu consentimiento en cualquier momento';

  @override
  String get openBankingNlpdNoSharing =>
      'Tus datos nunca se comparten con terceros';

  @override
  String get openBankingNlpdReadOnly =>
      'Acceso de solo lectura — ninguna operacion financiera';

  @override
  String get openBankingNlpdDuration =>
      'Duracion maxima de consentimiento: 90 dias';

  @override
  String get openBankingSelectBank => 'Elegir un banco';

  @override
  String get openBankingSelectScopes => 'Elegir las autorizaciones';

  @override
  String get openBankingConfirm => 'Confirmar';

  @override
  String get openBankingCancel => 'Cancelar';

  @override
  String get openBankingBack => 'Volver';

  @override
  String get openBankingNext => 'Siguiente';

  @override
  String get openBankingCategoryAll => 'Todas';

  @override
  String get openBankingCategoryAlimentation => 'Alimentacion';

  @override
  String get openBankingCategoryTransport => 'Transporte';

  @override
  String get openBankingCategoryLogement => 'Vivienda';

  @override
  String get openBankingCategoryTelecom => 'Telecom';

  @override
  String get openBankingCategoryAssurances => 'Seguros';

  @override
  String get openBankingCategoryEnergie => 'Energia';

  @override
  String get openBankingCategorySante => 'Salud';

  @override
  String get openBankingCategoryLoisirs => 'Ocio';

  @override
  String get openBankingCategoryImpots => 'Impuestos';

  @override
  String get openBankingCategoryEpargne => 'Ahorro';

  @override
  String get openBankingCategoryDivers => 'Varios';

  @override
  String get openBankingCategoryRevenu => 'Ingreso';

  @override
  String get openBankingLastSync => 'Ultima sincronizacion';

  @override
  String get openBankingIbanMasked => 'IBAN enmascarado';

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
      'Esta funcionalidad esta en desarrollo. Los datos mostrados son ejemplos. La activacion del servicio Open Banking esta sujeta a una consulta regulatoria previa.';

  @override
  String get openBankingBlink => 'Impulsado por bLink (SIX)';

  @override
  String get openBankingFinancialOverview => 'Vision general financiera';

  @override
  String get openBankingTopExpenses => 'Top 3 gastos';

  @override
  String get openBankingViewTransactions => 'Ver transacciones';

  @override
  String get openBankingManageConsents => 'Gestionar consentimientos';

  @override
  String get openBankingMonthlySummary => 'Resumen mensual';

  @override
  String get openBankingAddConsent => 'Anadir consentimiento';

  @override
  String get openBankingConsentGrantedOn => 'Concedido el';

  @override
  String get openBankingConsentExpiresOn => 'Caduca el';

  @override
  String get openBankingConsentRevokedConfirm => 'Consentimiento revocado';

  @override
  String get openBankingScopeAccountsDesc => 'Cuentas (lista de tus cuentas)';

  @override
  String get openBankingScopeBalancesDesc =>
      'Saldos (saldo actual de tus cuentas)';

  @override
  String get openBankingScopeTransactionsDesc =>
      'Transacciones (historial de movimientos)';

  @override
  String get openBankingReadOnlyInfo =>
      'Acceso de solo lectura. No se puede realizar ninguna operacion financiera.';

  @override
  String get openBankingConsentConfirmText =>
      'Al confirmar, autorizas a MINT a acceder a los datos seleccionados en modo lectura durante 90 dias. Puedes revocar este consentimiento en cualquier momento.';

  @override
  String get openBankingSection => 'Open Banking';

  @override
  String get openBankingTile => 'Open Banking';

  @override
  String get openBankingTileSub => 'Conecta tus cuentas bancarias';

  @override
  String get lppDeepSection => 'LPP EN PROFUNDIDAD';

  @override
  String get lppDeepRachatTitle => 'Rescate escalonado';

  @override
  String get lppDeepRachatSubtitle =>
      'Optimiza tus rescates LPP a lo largo de varios anos';

  @override
  String get lppDeepRachatAppBar => 'RESCATE LPP ESCALONADO';

  @override
  String get lppDeepRachatIntroTitle => '?Por que escalonar los rescates?';

  @override
  String get lppDeepRachatIntroBody =>
      'Al ser el impuesto suizo progresivo, repartir un rescate LPP en varios anos permite quedarse en tramos marginales mas elevados cada ano, maximizando asi el ahorro fiscal total.';

  @override
  String get lppDeepRachatParams => 'Parametros';

  @override
  String get lppDeepRachatAvoirActuel => 'Haber LPP actual';

  @override
  String get lppDeepRachatMax => 'Rescate maximo';

  @override
  String get lppDeepRachatRevenu => 'Renta imponible';

  @override
  String get lppDeepRachatTauxMarginal => 'Tipo marginal estimado';

  @override
  String get lppDeepRachatHorizon => 'Horizonte (anos)';

  @override
  String get lppDeepRachatComparaison => 'Comparacion';

  @override
  String get lppDeepRachatBloc => 'TODO EN 1 AÑO';

  @override
  String get lppDeepRachatBlocSub => 'Rescate en bloque';

  @override
  String lppDeepRachatEchelonne(String years) {
    return 'ESCALONADO EN $years ANOS';
  }

  @override
  String get lppDeepRachatEchelonneSub => 'Rescate repartido';

  @override
  String get lppDeepRachatEconomie => 'Ahorro fiscal';

  @override
  String lppDeepRachatEconomieDelta(String amount) {
    return 'Al escalonar, ahorras CHF $amount mas de impuestos.';
  }

  @override
  String get lppDeepRachatPlanAnnuel => 'Plan anual';

  @override
  String get lppDeepRachatAnnee => 'Ano';

  @override
  String get lppDeepRachatMontant => 'Rescate';

  @override
  String get lppDeepRachatEcoFiscale => 'Ahorro';

  @override
  String get lppDeepRachatCoutNet => 'Coste neto';

  @override
  String get lppDeepRachatTotal => 'Total';

  @override
  String get lppDeepRachatBlocageEpl => 'LPP art. 79b al. 3 — Bloqueo EPL';

  @override
  String get lppDeepRachatBlocageEplBody =>
      'Tras cada rescate, cualquier retiro EPL (fomento de la propiedad de vivienda) queda bloqueado durante 3 anos. Planifica en consecuencia si una compra inmobiliaria esta prevista.';

  @override
  String get lppDeepRachatDisclaimer =>
      'Simulacion pedagogica basada en una progresividad estimada. El rescate LPP esta sujeto a aceptacion por la caja de pensiones. Consulta tu caja de pensiones y un especialista en prevision antes de cualquier decision.';

  @override
  String get lppDeepLibrePassageTitle => 'Libre paso';

  @override
  String get lppDeepLibrePassageSubtitle =>
      'Checklist en caso de cambio de empleo o partida';

  @override
  String get lppDeepLibrePassageAppBar => 'LIBRE PASO';

  @override
  String get lppDeepLibrePassageSituation => 'Situacion';

  @override
  String get lppDeepLibrePassageChangement => 'Cambio de empleo';

  @override
  String get lppDeepLibrePassageDepart => 'Partida de Suiza';

  @override
  String get lppDeepLibrePassageCessation => 'Cese de actividad';

  @override
  String get lppDeepLibrePassageNewEmployer => 'Nuevo empleador';

  @override
  String get lppDeepLibrePassageNewEmployerSub =>
      '?Ya tienes un nuevo empleador?';

  @override
  String get lppDeepLibrePassageAlertes => 'Alertas';

  @override
  String get lppDeepLibrePassageChecklist => 'Checklist';

  @override
  String get lppDeepLibrePassageRecommandations => 'Recomendaciones';

  @override
  String get lppDeepLibrePassageUrgenceCritique => 'Critico';

  @override
  String get lppDeepLibrePassageUrgenceHaute => 'Alta';

  @override
  String get lppDeepLibrePassageUrgenceMoyenne => 'Media';

  @override
  String get lppDeepLibrePassageCentrale => 'Central del 2º pilar (sfbvg.ch)';

  @override
  String get lppDeepLibrePassageCentraleSub =>
      'Busca haberes de libre paso olvidados';

  @override
  String get lppDeepLibrePassagePrivacy =>
      'Tus datos se quedan en tu dispositivo. Ninguna informacion se transmite a terceros. Conforme con la nLPD.';

  @override
  String get lppDeepLibrePassageDisclaimer =>
      'Estas informaciones son pedagogicas y no constituyen asesoramiento juridico o financiero personalizado. Las reglas dependen de tu caja de pensiones y de tu situacion. Base legal: LFLP, OLP.';

  @override
  String get lppDeepEplTitle => 'Retiro EPL';

  @override
  String get lppDeepEplSubtitle => 'Financiar una vivienda con tu 2º pilar';

  @override
  String get lppDeepEplAppBar => 'RETIRO EPL';

  @override
  String get lppDeepEplIntroTitle => 'Retiro EPL — Propiedad de vivienda';

  @override
  String get lppDeepEplIntroBody =>
      'El EPL permite utilizar tu haber LPP para financiar la compra de una vivienda, amortizar una hipoteca o financiar renovaciones. Importe minimo: CHF 20\'000.';

  @override
  String get lppDeepEplParams => 'Parametros';

  @override
  String get lppDeepEplAvoirTotal => 'Haber LPP total';

  @override
  String get lppDeepEplAge => 'Edad';

  @override
  String get lppDeepEplMontantSouhaite => 'Importe deseado';

  @override
  String get lppDeepEplRachatsRecents => 'Rescates LPP recientes';

  @override
  String get lppDeepEplRachatsRecentsSub =>
      '?Has realizado un rescate LPP en los ultimos 3 anos?';

  @override
  String get lppDeepEplAnneesSDepuisRachat => 'Anos desde el rescate';

  @override
  String get lppDeepEplResultat => 'Resultado';

  @override
  String get lppDeepEplMontantMaxRetirable => 'Importe maximo retirable';

  @override
  String get lppDeepEplMontantApplicable => 'Importe aplicable';

  @override
  String get lppDeepEplRetraitImpossible =>
      'El retiro no es posible con la configuracion actual.';

  @override
  String get lppDeepEplImpactPrestations => 'Impacto en las prestaciones';

  @override
  String get lppDeepEplReductionInvalidite =>
      'Reduccion de la renta de invalidez (estimacion anual)';

  @override
  String get lppDeepEplReductionDeces =>
      'Reduccion del capital de fallecimiento (estimacion)';

  @override
  String get lppDeepEplImpactNote =>
      'El retiro EPL reduce proporcionalmente tus prestaciones de riesgo. Verifica con tu caja de pensiones los importes exactos.';

  @override
  String get lppDeepEplEstimationFiscale => 'Estimacion fiscal';

  @override
  String get lppDeepEplMontantRetire => 'Importe retirado';

  @override
  String get lppDeepEplImpotEstime => 'Impuesto estimado sobre el retiro';

  @override
  String get lppDeepEplMontantNet => 'Importe neto tras impuestos';

  @override
  String get lppDeepEplTaxNote =>
      'El retiro en capital se grava a una tasa reducida (aproximadamente 1/5 del baremo ordinario). La tasa exacta depende del canton y de la situacion personal.';

  @override
  String get lppDeepEplPointsAttention => 'Puntos de atencion';

  @override
  String get lppDeepEplDisclaimer =>
      'Simulacion pedagogica a titulo indicativo. El importe retirable exacto depende del reglamento de tu caja de pensiones. El impuesto varia segun el canton y la situacion personal. Base legal: art. 30c LPP, OEPL.';

  @override
  String get exploreTitle => 'Explorar';

  @override
  String get explorePillarComprendreTitle => 'Quiero entender';

  @override
  String get explorePillarComprendreSub =>
      'Lo esencial de las finanzas suizas, sin jerga. Quiz incluido.';

  @override
  String get explorePillarComprendreCta => 'Explorar los 9 temas';

  @override
  String get explorePillarCalculerTitle => 'Quiero calcular';

  @override
  String get explorePillarCalculerSub =>
      'Simula, compara, optimiza. 49 herramientas a tu disposicion.';

  @override
  String get explorePillarCalculerCta => 'Ver todas las herramientas';

  @override
  String get explorePillarLifeTitle => 'Me esta pasando algo';

  @override
  String get explorePillarLifeSub =>
      'Matrimonio, nacimiento, divorcio, mudanza... te acompanamos.';

  @override
  String get exploreGoalBudget => 'Dominar mi presupuesto';

  @override
  String get exploreGoalBudgetSub => 'Gestionar mis gastos → 3 min';

  @override
  String get exploreGoalProperty => 'Ser propietario';

  @override
  String get exploreGoalPropertySub => 'Simular mi compra → 5 min';

  @override
  String get exploreGoalTax => 'Pagar menos impuestos';

  @override
  String get exploreGoalTaxSub => 'Optimizar mi 3a → 3 min';

  @override
  String get exploreGoalRetirement => 'Preparar mi jubilacion';

  @override
  String get exploreGoalRetirementSub => 'Ver mi plan → 10 min';

  @override
  String get exploreEventMarriage => 'Matrimonio';

  @override
  String get exploreEventMarriageSub => 'Impacto fiscal y LPP';

  @override
  String get exploreEventBirth => 'Nacimiento';

  @override
  String get exploreEventBirthSub => 'Asignaciones y deducciones';

  @override
  String get exploreEventConcubinage => 'Concubinato';

  @override
  String get exploreEventConcubinageSub => 'Proteger tu pareja';

  @override
  String get exploreEventDivorce => 'Divorcio';

  @override
  String get exploreEventDivorceSub => 'Reparto LPP y AVS';

  @override
  String get exploreEventSuccession => 'Sucesion';

  @override
  String get exploreEventSuccessionSub => 'Derechos y planificacion';

  @override
  String get exploreEventHouseSale => 'Venta inmobiliaria';

  @override
  String get exploreEventHouseSaleSub => 'Impuesto plusvalia';

  @override
  String get exploreEventDonation => 'Donacion';

  @override
  String get exploreEventDonationSub => 'Fiscalidad y limites';

  @override
  String get exploreEventExpat => 'Expatriacion';

  @override
  String get exploreEventExpatSub => 'Salida o llegada';

  @override
  String get exploreDocUploadLpp => 'Certificados y documentos';

  @override
  String get exploreDocUploadLppSub => 'Certificado LPP, extractos AVS →';

  @override
  String get exploreAskMintTitle => 'Ask MINT';

  @override
  String get exploreAskMintConfigured =>
      'Haz tus preguntas sobre finanzas suizas →';

  @override
  String get exploreAskMintNotConfigured => 'Configura tu IA para empezar →';

  @override
  String get exploreLearn3a => 'Que es el pilar 3a?';

  @override
  String get exploreLearnLpp => 'LPP: Como funciona';

  @override
  String get exploreLearnFiscal => 'Fiscalidad suiza 101';

  @override
  String get coachWelcome => 'Bienvenue sur MINT';

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
      'Complète ton diagnostic pour découvrir ton score';

  @override
  String get coachDiscoverScore => 'Découvrir mon score — 10 min';

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
  String get coachPulseDisclaimer =>
      'Estimaciones educativas — no constituye asesoramiento financiero. Los rendimientos pasados no presuponen rendimientos futuros. Consulta a un especialista. LSFin.';

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
      'Pas de panique. Choisis un sujet, on t\'explique l\'essentiel et on te donne une action simple.';

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
  String get trajectoryEmpty => 'Pas encore de projection disponible';

  @override
  String get trajectoryEmptySub =>
      'Complète ton profil pour voir ta trajectoire';

  @override
  String get trajectoryDisclaimer =>
      'Estimaciones educativas — no constituye asesoramiento financiero.';

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
    return 'Listo. Check-in $month completado.';
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
  String get checkinAddContribution => 'Añadir un aporte';

  @override
  String get checkinCategoryLabel => 'Categoría';

  @override
  String get checkinCat3a => 'Pilar 3a';

  @override
  String get checkinCatLpp => 'Recompra LPP';

  @override
  String get checkinCatInvest => 'Inversión';

  @override
  String get checkinCatEpargne => 'Ahorro libre';

  @override
  String get checkinLabelField => 'Nombre';

  @override
  String get checkinLabelHint => 'Ej: 3a VIAC, Ahorro vacaciones...';

  @override
  String get checkinAmountField => 'Monto mensual';

  @override
  String get checkinAutoToggle => 'Orden permanente (automático)';

  @override
  String get checkinAddConfirm => 'Añadir';

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
      '¡Perfil completo! Tu coach tiene todos los datos para consejos fiables.';

  @override
  String get profileAnnualRefreshTitle => 'Actualización anual';

  @override
  String get profileAnnualRefreshBody =>
      'Tus datos tienen más de 10 meses. Un chequeo rápido (2 min) mejora tu plan.';

  @override
  String get profileAnnualRefreshCta => 'Iniciar chequeo';

  @override
  String get profileDangerZoneTitle => 'Zona de peligro';

  @override
  String get profileDangerZoneSubtitle =>
      'Restablece tu historial financiero local sin eliminar tu cuenta.';

  @override
  String get profileResetDialogTitle => '¿Restablecer mi situación?';

  @override
  String get profileResetDialogBody =>
      'Esta acción elimina tu diagnóstico, tus check-ins, tu puntuación y tu presupuesto local.';

  @override
  String get profileResetDialogConfirmLabel => 'Escribe RESET para confirmar:';

  @override
  String get profileResetDialogInvalid => 'Palabra clave no válida.';

  @override
  String get profileResetDialogAction => 'Restablecer';

  @override
  String get profileResetSuccess => 'Historial financiero local restablecido.';

  @override
  String get profileResetScopeNote =>
      'Conserva la conexión y la clave BYOK. Los documentos del backend no se eliminan.';

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
  String get coachShockTitle => 'Tus cifras clave';

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
  String get coachNarrativeModeConcise => 'Corto';

  @override
  String get coachNarrativeModeDetailed => 'Detallado';

  @override
  String get advisorMiniMetricsWinnerLive => 'Ganador en vivo';

  @override
  String get advisorMiniMetricsUplift => 'Mejora challenge vs control';

  @override
  String get advisorMiniMetricsSignal => 'Senal';

  @override
  String get advisorMiniMetricsSignalInsufficient =>
      'Esperar >=10 inicios por variante';

  @override
  String get profileCoachMonthlyTitle => 'Resumen coach del mes';

  @override
  String get profileCoachMonthlyTrendInsufficient =>
      'Aun no hay suficientes check-ins para una tendencia mensual.';

  @override
  String profileCoachMonthlyTrendUp(String delta) {
    return '+$delta puntos este mes, buena dinamica.';
  }

  @override
  String profileCoachMonthlyTrendDown(String delta) {
    return '-$delta puntos este mes, ajustamos tus prioridades.';
  }

  @override
  String get profileCoachMonthlyTrendFlat =>
      'Puntuacion estable este mes, mantén el ritmo.';

  @override
  String profileCoachMonthlyByokPrefix(String trend) {
    return 'Lectura coach IA: $trend';
  }

  @override
  String get profileCoachMonthlyActionComplete =>
      'Siguiente paso: completa tu diagnostico para afinar las recomendaciones.';

  @override
  String get profileCoachMonthlyActionCheckin =>
      'Siguiente paso: haz tu check-in mensual para recalibrar el plan.';

  @override
  String get profileCoachMonthlyActionAgir =>
      'Siguiente paso: ejecuta una accion prioritaria en Agir.';

  @override
  String get profileGuidanceTitle => 'Seccion recomendada';

  @override
  String profileGuidanceBody(String section) {
    return 'Completa ahora $section para mejorar la fiabilidad de tu plan.';
  }

  @override
  String profileGuidanceCta(String section) {
    return 'Completar $section';
  }

  @override
  String get advisorMiniMetricsLiveTitle => 'Calidad onboarding en vivo';

  @override
  String get advisorMiniMetricsLiveStep => 'Paso actual';

  @override
  String get advisorMiniMetricsLiveQuality => 'Puntuacion de calidad';

  @override
  String get advisorMiniMetricsLiveNext => 'Seccion recomendada';

  @override
  String get coachPersonaPriorityCouple => 'Prioridad pareja';

  @override
  String get coachPersonaPriorityFamily => 'Prioridad familia';

  @override
  String get coachPersonaPrioritySingleParent => 'Prioridad padre/madre solo';

  @override
  String get coachPersonaPrioritySingle => 'Prioridad personal';

  @override
  String get coachWizardSectionIdentity => 'Identidad y hogar';

  @override
  String get coachWizardSectionIncome => 'Ingresos y hogar';

  @override
  String get coachWizardSectionPension => 'Prevision';

  @override
  String get coachWizardSectionProperty => 'Inmobiliario y deudas';

  @override
  String coachPersonaGuidanceCouple(String section) {
    return 'Para estabilizar tus proyecciones del hogar, completa ahora $section.';
  }

  @override
  String coachPersonaGuidanceSingleParent(String section) {
    return 'Tu plan depende de la proteccion del hogar. Completa ahora $section.';
  }

  @override
  String coachPersonaGuidanceSingle(String section) {
    return 'Para personalizar tu plan coach, completa ahora $section.';
  }

  @override
  String coachEnrichTargetTitle(String current, String target) {
    return 'Pasar de $current% a $target% de precision';
  }

  @override
  String get coachEnrichBodyIdentity =>
      'Anade bases de identidad/hogar para activar calculos fiables desde hoy.';

  @override
  String get coachEnrichBodyIncome =>
      'Completa ingresos y estructura del hogar para recomendaciones realmente personalizadas.';

  @override
  String get coachEnrichBodyPension =>
      'Anade AVS/LPP/3a para una proyeccion de retiro accionable.';

  @override
  String get coachEnrichBodyProperty =>
      'Anade inmobiliario y deudas para calibrar presupuesto y riesgo real.';

  @override
  String get coachEnrichBodyDefault =>
      'El diagnostico completo tarda 10 minutos y desbloquea tu trayectoria personalizada.';

  @override
  String get coachEnrichActionIdentity => 'Completar Identidad y hogar';

  @override
  String get coachEnrichActionIncome => 'Completar Ingresos y hogar';

  @override
  String get coachEnrichActionPension => 'Completar Prevision';

  @override
  String get coachEnrichActionProperty => 'Completar Inmobiliario y deudas';

  @override
  String get coachEnrichActionDefault => 'Completar mi diagnostico';

  @override
  String coachAgirPartialTitle(String quality) {
    return 'Plan en construccion ($quality%)';
  }

  @override
  String coachAgirPartialBody(String section) {
    return 'Para activar tus acciones prioritarias, completa ahora $section.';
  }

  @override
  String coachAgirPartialAction(String section) {
    return 'Completar $section';
  }

  @override
  String get landingTagline => 'Tu coach financiero suizo';

  @override
  String get landingRegister => 'Registrarse';

  @override
  String get landingHeroRetirementNow1 => 'Tu jubilación,';

  @override
  String get landingHeroRetirementNow2 => 'es ahora.';

  @override
  String landingHeroCountdown1(String years) {
    return 'En $years años,';
  }

  @override
  String get landingHeroCountdown1Single => 'En 1 año,';

  @override
  String get landingHeroCountdown2 => 'comienza tu jubilación.';

  @override
  String get landingHeroSubtitle =>
      'La mayoría de los suizos descubren su brecha de jubilación demasiado tarde.';

  @override
  String get landingSliderAge => 'Tu edad';

  @override
  String landingSliderAgeSuffix(String age) {
    return '$age años';
  }

  @override
  String get landingSliderSalary => 'Tu salario bruto';

  @override
  String landingSliderSalarySuffix(String amount) {
    return '$amount CHF/año';
  }

  @override
  String get landingToday => 'Hoy';

  @override
  String get landingChfPerMonth => 'CHF/mes';

  @override
  String get landingAtRetirement => 'En la jubilación*';

  @override
  String landingDropPurchasingPower(String percent) {
    return '-$percent% de poder adquisitivo';
  }

  @override
  String landingLppCapNotice(String amount) {
    return 'Por encima de $amount CHF/año, la pensión obligatoria está limitada.';
  }

  @override
  String landingHookHigh(String amount) {
    return 'Una brecha de $amount/mes es significativa. MINT te ayuda a entender dónde actuar.';
  }

  @override
  String get landingHookMedium =>
      'Tu brecha es manejable. MINT te muestra las palancas concretas (rescate LPP, 3a, jubilación anticipada).';

  @override
  String get landingHookLow =>
      'Estás en buena posición. MINT te muestra cómo mantener el rumbo y optimizar tus pilares.';

  @override
  String get landingWhyMint => '¿Por qué MINT?';

  @override
  String get landingFeaturePillarsTitle => 'Todos tus pilares, un solo panel';

  @override
  String get landingFeaturePillarsSubtitle =>
      'AVS, LPP y 3a calculados según tu situación real — no promedios suizos.';

  @override
  String get landingFeatureCoachTitle => 'Coach adaptado a tu etapa de vida';

  @override
  String get landingFeatureCoachSubtitle =>
      '25 o 60 años, fronterizo o independiente — los consejos cambian según quién eres.';

  @override
  String get landingFeaturePrivacyTitle =>
      '100% privado, datos en tu dispositivo';

  @override
  String get landingFeaturePrivacySubtitle =>
      'Sin compartir, sin publicidad. Tu perfil queda local salvo que crees una cuenta.';

  @override
  String get landingTrustSwiss => 'Hecho en Suiza';

  @override
  String get landingTrustPrivate => '100% privado';

  @override
  String get landingTrustNoCommitment => 'Sin compromiso';

  @override
  String get landingCtaTitle => 'Tu plan en 30 segundos';

  @override
  String get landingCtaSubtitle => '3 preguntas • Gratis • Sin compromiso';

  @override
  String get landingLegalFooter =>
      '*Estimación indicativa (1.° + 2.° pilar), basada en el salario actual como aproximación de carrera. No constituye asesoramiento financiero según la LSFin. Tus datos permanecen en tu dispositivo.';

  @override
  String get onboardingConsentTitle => 'Guardado local de respuestas';

  @override
  String get onboardingConsentBody =>
      'Tus respuestas pueden guardarse localmente en tu dispositivo para continuar más tarde. Ningún dato se envía sin tu consentimiento.';

  @override
  String get onboardingConsentAllow => 'Autorizar';

  @override
  String get onboardingConsentContinueWithout => 'Continuar sin guardar';

  @override
  String get profileBilanTitle => 'Mi resumen financiero';

  @override
  String get profileBilanSubtitleComplete =>
      'Ingresos, previsión, patrimonio, deudas';

  @override
  String get profileBilanSubtitleIncomplete =>
      'Completa tu perfil para ver tus cifras';

  @override
  String get profileFamilyTitle => 'Familia';

  @override
  String get profileHouseholdTitle => 'Nuestro hogar';

  @override
  String get profileHouseholdStatus => 'Pareja+';

  @override
  String get profileAiSlmTitle => 'IA en el dispositivo (SLM)';

  @override
  String get profileAiSlmReady => 'Modelo listo';

  @override
  String get profileAiSlmNotInstalled => 'Modelo no instalado';

  @override
  String get profileLanguageTitle => 'Idioma';

  @override
  String get profileAdminObservability => 'Admin observability';

  @override
  String get profileAdminAnalytics => 'Analytics beta testers';

  @override
  String get profileDeleteCloudAccount => 'Eliminar mi cuenta en la nube';

  @override
  String get profileDeleteCloudTitle => '¿Eliminar la cuenta?';

  @override
  String get profileDeleteCloudBody =>
      'Esta acción elimina tu cuenta en la nube y los datos asociados. Tus datos locales permanecen en este dispositivo.';

  @override
  String get profileDeleteCloudConfirm => 'Eliminar';

  @override
  String get profileDeleteCloudSuccess => 'Cuenta eliminada con éxito.';

  @override
  String get profileDeleteCloudError =>
      'Eliminación no posible por el momento. Inténtalo de nuevo más tarde.';

  @override
  String get dashboardDefaultUserName => 'Tú';

  @override
  String get dashboardDefaultConjointName => 'Pareja';

  @override
  String get dashboardGoalRetirement => 'Jubilación';

  @override
  String dashboardAppBarWithName(String firstName) {
    return 'Jubilación · $firstName';
  }

  @override
  String get dashboardAppBarDefault => 'Mi panel';

  @override
  String get dashboardMyData => 'Mis datos';

  @override
  String get dashboardQuickStartTitle =>
      'Descubre tu proyección en 30 segundos';

  @override
  String get dashboardQuickStartBody =>
      '4 datos bastan para estimar tu ingreso de jubilación. Puedes afinar con documentos y detalles.';

  @override
  String get dashboardQuickStartCta => 'Comenzar';

  @override
  String get dashboardEnrichScanTitle => 'Escanea tu certificado LPP';

  @override
  String get dashboardEnrichScanImpact => '+20 pts de precisión';

  @override
  String get dashboardEnrichCoachTitle => 'Habla con el Coach';

  @override
  String get dashboardEnrichCoachImpact => 'Resuelve tus dudas';

  @override
  String get dashboardEnrichSimTitle => 'Simula un escenario';

  @override
  String get dashboardEnrichSimImpact => '3a, LPP, hipoteca...';

  @override
  String get dashboardNextSteps => 'Próximos pasos';

  @override
  String get dashboardEduTitle => 'El sistema de jubilación suizo';

  @override
  String get dashboardEduAvs => '1er pilar — AVS';

  @override
  String get dashboardEduAvsDesc =>
      'Base obligatoria para todos. Financiado por tus cotizaciones (LAVS art. 21).';

  @override
  String get dashboardEduLpp => '2do pilar — LPP';

  @override
  String get dashboardEduLppDesc =>
      'Previsión profesional a través de tu caja de pensiones (LPP art. 14).';

  @override
  String get dashboardEdu3a => '3er pilar — 3a';

  @override
  String get dashboardEdu3aDesc =>
      'Ahorro voluntario con deducción fiscal (OPP3 art. 7).';

  @override
  String get dashboardDisclaimer =>
      'Herramienta educativa simplificada. No constituye asesoramiento financiero (LSFin). Fuentes: LAVS art. 21-29, LPP art. 14, OPP3 art. 7.';

  @override
  String get dashboardCockpitLink => 'Cockpit detallado';

  @override
  String dashboardImpactEstimate(String amount) {
    return 'Impacto estimado: CHF $amount';
  }

  @override
  String get dashboardMetricMonthlyIncome => 'Ingreso mensual';

  @override
  String get dashboardMetricChfMonth => 'CHF/mes';

  @override
  String get dashboardMetricReplacementRate => 'Tasa de reemplazo';

  @override
  String get dashboardMetricRetirementDuration =>
      'Duración estimada de jubilación';

  @override
  String get dashboardMetricYears => 'años';

  @override
  String get dashboardMetricLifeExpectancy =>
      'Esperanza de vida estimada: 85 años';

  @override
  String get dashboardMetricMonthlyGap => 'Brecha mensual';

  @override
  String get dashboardMetricVsTarget => 'Vs objetivo 70% del salario bruto';

  @override
  String get dashboardNextActionLabel => 'Mejorar tu precisión';

  @override
  String get dashboardNextActionDetail =>
      'Escanea tu certificado LPP para afinar tus proyecciones.';

  @override
  String get dashboardWeatherSunny => 'Mercados favorables, ahorro maximizado.';

  @override
  String get dashboardWeatherPartlyCloudy =>
      'Trayectoria actual, algunos ajustes.';

  @override
  String get dashboardWeatherRainy => 'Choques de mercado o lagunas AVS/LPP.';

  @override
  String get dashboardAgeBandYoungTitle => 'Tu palanca principal: el 3a';

  @override
  String get dashboardAgeBandYoungSubtitle =>
      'Cada franco invertido ahora trabaja 40 años. Abrir tu 3a lleva 15 minutos.';

  @override
  String get dashboardAgeBandYoungCta => 'Simular mi 3a';

  @override
  String get dashboardAgeBandStabTitle => '3a + protección familiar';

  @override
  String get dashboardAgeBandStabSubtitle =>
      'Vivienda, cobertura fallecimiento/invalidez: ahora es cuando se construye la arquitectura.';

  @override
  String get dashboardAgeBandStabCta => 'Ver simuladores';

  @override
  String get dashboardAgeBandPeakTitle => 'Recompra LPP + optimización fiscal';

  @override
  String get dashboardAgeBandPeakSubtitle =>
      'Tus ingresos están en su punto máximo — es la ventana para reducir la brecha de jubilación.';

  @override
  String get dashboardAgeBandPeakCta => 'Simular una recompra';

  @override
  String get dashboardAgeBandPreRetTitle =>
      'Tu brecha de jubilación en CHF/mes';

  @override
  String get dashboardAgeBandPreRetSubtitle =>
      'Renta vs capital, jubilación anticipada, recompra escalonada: las decisiones se acercan.';

  @override
  String get dashboardAgeBandPreRetCta => 'Renta vs Capital';

  @override
  String get dashboardAgeBandRetWithdrawTitle => 'Orden de retiro 3a';

  @override
  String get dashboardAgeBandRetWithdrawSubtitle =>
      'Escalonar tus retiros 3a en 3–5 años reduce significativamente el impuesto según el cantón.';

  @override
  String get dashboardAgeBandRetWithdrawCta => 'Planificar mis retiros';

  @override
  String get dashboardAgeBandRetSuccessionTitle => 'Sucesión y transmisión';

  @override
  String get dashboardAgeBandRetSuccessionSubtitle =>
      'Testamento, donación en vida, beneficiarios LPP: proteger a quienes amas.';

  @override
  String get dashboardAgeBandRetSuccessionCta => 'Explorar';

  @override
  String get agirResetTooltip => 'Reiniciar';

  @override
  String get agirResetHistoryLabel => 'Reiniciar mi historial del coach';

  @override
  String get agirResetDiagnosticLabel => 'Rehacer mi diagnóstico';

  @override
  String get agirResetHistoryTitle => '¿Reiniciar tu historial del coach?';

  @override
  String get agirResetHistoryMessage =>
      'Esto elimina tus check-ins, tu historial de puntuación y el progreso de los simuladores.';

  @override
  String get agirResetHistoryCta => 'Reiniciar';

  @override
  String get agirResetDiagnosticTitle => '¿Rehacer tu diagnóstico?';

  @override
  String get agirResetDiagnosticMessage =>
      'Esto elimina tu diagnóstico actual y tus respuestas del mini-onboarding.';

  @override
  String get agirResetDiagnosticCta => 'Rehacer';

  @override
  String get agirHistoryResetSnackbar => 'Historial del coach reiniciado.';

  @override
  String get agirSwipeDone => 'Hecho';

  @override
  String get agirSwipeSnooze => 'Posponer 30d';

  @override
  String agirSwipeDoneSnackbar(String title) {
    return '$title — marcado como hecho';
  }

  @override
  String agirSwipeSnoozeSnackbar(String title) {
    return '$title — pospuesto 30 días';
  }

  @override
  String get agirDependencyDebt => 'Después: reembolso de deuda';

  @override
  String get agirEmptyTitle => 'Tu plan de acción te espera';

  @override
  String get agirEmptyBody =>
      'Completa tu diagnóstico para obtener un plan mensual personalizado basado en tu situación real.';

  @override
  String get agirEmptyLaunchCta => 'Lanzar mi diagnóstico — 10 min';

  @override
  String get agirNoContribTitle => 'Ninguna contribución planificada';

  @override
  String get agirNoContribBody =>
      'Haz tu primer check-in para configurar tus contribuciones mensuales.';

  @override
  String get agirNoContribCta => 'Configurar mis contribuciones';

  @override
  String get agirProgressTitle => 'Progreso anual';

  @override
  String agirProgressSubtitle(String year) {
    return 'Planificado vs pagado en $year';
  }

  @override
  String get agirConfirmLabel => 'Por confirmar';

  @override
  String agirVersesLabel(String amount) {
    return '$amount pagados';
  }

  @override
  String agirObjectifLabel(String amount) {
    return 'Objetivo: $amount';
  }

  @override
  String get agirPriorityImmediate => 'Prioridad inmediata';

  @override
  String get agirPriorityTrimestre => 'Este trimestre';

  @override
  String get agirPriorityAnnee => 'Este año';

  @override
  String get agirPriorityLongTerme => 'Largo plazo';

  @override
  String get agirTimelineCheckinTitle => 'Check-in mensual';

  @override
  String get agirTimelineCheckinDone =>
      'Hecho — contribuciones confirmadas para este mes.';

  @override
  String get agirTimelineCheckinPending =>
      'Confirma tus contribuciones del mes en 2 min.';

  @override
  String get agirTimelineCheckinCta => 'Hacer mi check-in';

  @override
  String agirTimelineRetirementTitle(String name) {
    return 'Jubilación $name (65 años)';
  }

  @override
  String get agirTimelineThisMonth => 'Este mes';

  @override
  String agirTimelineInMonths(String months) {
    return 'en $months meses';
  }

  @override
  String agirTimelineInYears(String years) {
    return 'en $years años';
  }

  @override
  String get agirTimelineInOneYear => 'en 1 año';

  @override
  String get agirPerYear => '/año';

  @override
  String get agirCoachPulseWhyDefault =>
      'Empieza con una acción simple para activar tu dinámica.';

  @override
  String get checkinScoreTitle => 'Tu puntuación financiera';

  @override
  String checkinScorePositive(String delta) {
    return '+$delta pts — ¡tus acciones dan frutos!';
  }

  @override
  String checkinScoreNegative(String delta) {
    return '$delta pts — sigue, cada mes cuenta';
  }

  @override
  String get budgetEmptyTitle => 'Tu presupuesto se construye automáticamente';

  @override
  String get budgetEmptyBody =>
      'Completa tu diagnóstico para desbloquear tu plan mensual con tus ingresos y gastos reales.';

  @override
  String get budgetEmptyAction => 'Hacer mi diagnóstico';

  @override
  String get budgetMonthlyTitle => 'Presupuesto mensual';

  @override
  String get budgetAvailableThisMonth => 'Disponible este mes';

  @override
  String get budgetNetIncome => 'Ingreso neto';

  @override
  String get budgetHousing => 'Vivienda';

  @override
  String get budgetDebtRepayment => 'Pago de deudas';

  @override
  String get budgetDebts => 'Deudas';

  @override
  String get budgetTaxProvision => 'Provisión impuestos';

  @override
  String get budgetHealthInsurance => 'Seguro médico (LAMal)';

  @override
  String get budgetOtherFixed => 'Otros gastos fijos';

  @override
  String get budgetNotProvided => '(no indicado)';

  @override
  String get budgetQualityEstimated => 'estimado';

  @override
  String get budgetQualityEntered => 'ingresado';

  @override
  String get budgetQualityMissing => 'faltante';

  @override
  String get budgetAvailable => 'Disponible';

  @override
  String get budgetMissingDataBanner =>
      'Algunos gastos aún faltan. Completa tu diagnóstico para hacer este presupuesto más fiable.';

  @override
  String get budgetEstimatedDataBanner =>
      'Este presupuesto incluye estimaciones (impuestos/LAMal). Ingresa tus montos reales para una proyección más fiable.';

  @override
  String get budgetCompleteData => 'Completar mis datos →';

  @override
  String get budgetEnvelopeFuture => '🔒 Futuro (Ahorro, Proyectos)';

  @override
  String get budgetEnvelopeVariables => '🛍️ Variables (Vivir)';

  @override
  String get budgetNeeds => 'Necesidades';

  @override
  String get budgetLife => 'Vida';

  @override
  String get budgetFuture => 'Futuro';

  @override
  String get budgetVariables => 'Variables';

  @override
  String get budgetExampleRent => 'Alquiler';

  @override
  String get budgetExampleLamal => 'LAMal';

  @override
  String get budgetExampleTaxes => 'impuestos';

  @override
  String get budgetExampleDebts => 'deudas';

  @override
  String get budgetExampleFood => 'Alimentación';

  @override
  String get budgetExampleTransport => 'transporte';

  @override
  String get budgetExampleLeisure => 'ocio';

  @override
  String get budgetExampleSavings => 'Ahorro';

  @override
  String get budgetExampleProjects => 'proyectos';

  @override
  String budgetChiffreChoc503020(String monthly, String total) {
    return 'Ahorrando CHF $monthly/mes, acumulas CHF $total en 10 años.';
  }

  @override
  String get budgetEmergencyFund => 'Fondo de emergencia';

  @override
  String get budgetEmergencyGoalReached => 'Objetivo alcanzado';

  @override
  String get budgetEmergencyOnTrack => 'Buen camino';

  @override
  String get budgetEmergencyToReinforce => 'A reforzar';

  @override
  String budgetEmergencyMonthsCovered(String months) {
    return '$months meses cubiertos';
  }

  @override
  String budgetEmergencyTarget(String target) {
    return 'Objetivo: $target meses';
  }

  @override
  String get budgetEmergencyComplete =>
      'Estás protegido contra imprevistos. Sigue así.';

  @override
  String budgetEmergencyIncomplete(String target) {
    return 'Ahorra al menos $target meses de gastos para protegerte contra imprevistos (pérdida de empleo, reparaciones...).';
  }

  @override
  String get budgetDisclaimerTitle => 'IMPORTANTE:';

  @override
  String get budgetDisclaimerEducational =>
      '• Esta es una herramienta educativa, no un consejo financiero (LSFin).';

  @override
  String get budgetDisclaimerDeclarative =>
      '• Los montos se basan en la información declarada.';

  @override
  String get budgetDisclaimerFormula =>
      '• \'Disponible\' = Ingresos - Vivienda - Deudas - Impuestos - LAMal - Gastos fijos.';

  @override
  String get toolsAllTools => 'Todas las herramientas';

  @override
  String get toolsSearchHint => 'Buscar una herramienta...';

  @override
  String toolsToolCount(String count) {
    return '$count herramientas';
  }

  @override
  String toolsCategoryCount(String count) {
    return '$count categorías';
  }

  @override
  String get toolsClear => 'Borrar';

  @override
  String get toolsNoResults => 'Ninguna herramienta encontrada';

  @override
  String get toolsNoResultsHint => 'Prueba con otras palabras clave';

  @override
  String get toolsCatPrevoyance => 'Previsión';

  @override
  String get toolsRetirementPlanner => 'Planificador de jubilación';

  @override
  String get toolsRetirementPlannerDesc =>
      'Simula tu jubilación AVS + LPP + 3a';

  @override
  String get toolsSimulator3a => 'Simulador 3a';

  @override
  String get toolsSimulator3aDesc => 'Calcula tu ahorro fiscal anual';

  @override
  String get toolsComparator3a => 'Comparador 3a';

  @override
  String get toolsComparator3aDesc => 'Compara proveedores (banco vs seguro)';

  @override
  String get toolsRealReturn3a => 'Rendimiento real 3a';

  @override
  String get toolsRealReturn3aDesc =>
      'Rendimiento neto después de comisiones e inflación';

  @override
  String get toolsStaggeredWithdrawal3a => 'Retiro escalonado 3a';

  @override
  String get toolsStaggeredWithdrawal3aDesc =>
      'Optimiza el retiro en varios años';

  @override
  String get toolsRenteVsCapital => 'Renta vs Capital';

  @override
  String get toolsRenteVsCapitalDesc => 'Compara renta LPP y retiro de capital';

  @override
  String get toolsRachatLpp => 'Recompra escalonada LPP';

  @override
  String get toolsRachatLppDesc => 'Optimiza tus recompras LPP en varios años';

  @override
  String get toolsLibrePassage => 'Libre paso';

  @override
  String get toolsLibrePassageDesc => 'Checklist cambio de empleo o salida';

  @override
  String get toolsDisabilityGap => 'Red de seguridad';

  @override
  String get toolsDisabilityGapDesc =>
      'Simula tu brecha invalidez/fallecimiento';

  @override
  String get toolsGenderGap => 'Brecha de género previsión';

  @override
  String get toolsGenderGapDesc =>
      'Impacto del tiempo parcial en tu jubilación';

  @override
  String get toolsCatFamily => 'Familia';

  @override
  String get toolsMarriage => 'Matrimonio & fiscalidad';

  @override
  String get toolsMarriageDesc =>
      'Penalidad/bonus del matrimonio + regímenes + sobreviviente';

  @override
  String get toolsBirth => 'Nacimiento & familia';

  @override
  String get toolsBirthDesc =>
      'Licencia parental, asignaciones, impacto fiscal';

  @override
  String get toolsConcubinage => 'Matrimonio vs Concubinato';

  @override
  String get toolsConcubinageDesc => 'Comparador + checklist de protección';

  @override
  String get toolsDivorce => 'Simulador de divorcio';

  @override
  String get toolsDivorceDesc => 'Impacto financiero del divorcio en la LPP';

  @override
  String get toolsSuccession => 'Simulador de sucesión';

  @override
  String get toolsSuccessionDesc => 'Calcula las partes legales e impuestos';

  @override
  String get toolsCatEmployment => 'Empleo';

  @override
  String get toolsFirstJob => 'Primer empleo';

  @override
  String get toolsFirstJobDesc => 'Entiende tu nómina y tus derechos';

  @override
  String get toolsUnemployment => 'Simulador de desempleo';

  @override
  String get toolsUnemploymentDesc => 'Calcula tus indemnizaciones y duración';

  @override
  String get toolsJobComparison => 'Comparador de empleo';

  @override
  String get toolsJobComparisonDesc =>
      'Compara dos ofertas (neto + LPP + ventajas)';

  @override
  String get toolsSelfEmployed => 'Independiente';

  @override
  String get toolsSelfEmployedDesc => 'Cobertura social y protección';

  @override
  String get toolsAvsContributions => 'Cotizaciones AVS indep.';

  @override
  String get toolsAvsContributionsDesc => 'Calcula tus cotizaciones AVS/AI/APG';

  @override
  String get toolsIjm => 'Seguro IJM';

  @override
  String get toolsIjmDesc => 'Indemnización diaria por enfermedad';

  @override
  String get tools3aSelfEmployed => '3a independiente';

  @override
  String get tools3aSelfEmployedDesc => 'Techo mayor para independientes';

  @override
  String get toolsDividendVsSalary => 'Dividendo vs Salario';

  @override
  String get toolsDividendVsSalaryDesc => 'Optimiza tu remuneración en SA/Sàrl';

  @override
  String get toolsLppVoluntary => 'LPP voluntaria';

  @override
  String get toolsLppVoluntaryDesc =>
      'Previsión facultativa para independientes';

  @override
  String get toolsCrossBorder => 'Fronterizo';

  @override
  String get toolsCrossBorderDesc =>
      'Impuesto en la fuente, 90 días, cargas sociales';

  @override
  String get toolsExpatriation => 'Expatriación';

  @override
  String get toolsExpatriationDesc => 'Forfait fiscal, salida, lagunas AVS';

  @override
  String get toolsCatRealEstate => 'Inmobiliario';

  @override
  String get toolsAffordability => 'Capacidad de compra';

  @override
  String get toolsAffordabilityDesc =>
      'Calcula el precio máximo que puedes comprar';

  @override
  String get toolsAmortization => 'Plan de amortización';

  @override
  String get toolsAmortizationDesc => 'Calendario de reembolso hipotecario';

  @override
  String get toolsSaronVsFixed => 'SARON vs Fijo';

  @override
  String get toolsSaronVsFixedDesc => 'Compara los tipos de hipoteca';

  @override
  String get toolsImputedRental => 'Valor locativo';

  @override
  String get toolsImputedRentalDesc => 'Estima el valor locativo imputado';

  @override
  String get toolsEplCombined => 'EPL combinado';

  @override
  String get toolsEplCombinedDesc => 'Retiro anticipado LPP + 3a para vivienda';

  @override
  String get toolsEplLpp => 'Retiro EPL (LPP)';

  @override
  String get toolsEplLppDesc => 'Financiar vivienda con tu 2.° pilar';

  @override
  String get toolsCatTax => 'Fiscalidad';

  @override
  String get toolsFiscalComparator => 'Comparador fiscal';

  @override
  String get toolsFiscalComparatorDesc =>
      'Compara tu carga fiscal entre cantones';

  @override
  String get toolsCompoundInterest => 'Interés compuesto';

  @override
  String get toolsCompoundInterestDesc =>
      'Visualiza el crecimiento de tu ahorro';

  @override
  String get toolsCatHealth => 'Salud';

  @override
  String get toolsLamalDeductible => 'Franquicia LAMal';

  @override
  String get toolsLamalDeductibleDesc =>
      'Encuentra la franquicia ideal para ti';

  @override
  String get toolsCoverageCheckup => 'Check-up cobertura';

  @override
  String get toolsCoverageCheckupDesc => 'Evalúa tu protección aseguradora';

  @override
  String get toolsCatBudgetDebt => 'Presupuesto & Deudas';

  @override
  String get toolsBudget => 'Presupuesto';

  @override
  String get toolsBudgetDesc => 'Planifica y sigue tus gastos mensuales';

  @override
  String get toolsDebtCheck => 'Check deuda';

  @override
  String get toolsDebtCheckDesc => 'Evalúa tu riesgo de sobreendeudamiento';

  @override
  String get toolsDebtRatio => 'Ratio de endeudamiento';

  @override
  String get toolsDebtRatioDesc => 'Diagnóstico visual de tu situación';

  @override
  String get toolsRepaymentPlan => 'Plan de reembolso';

  @override
  String get toolsRepaymentPlanDesc => 'Estrategia adaptada para reembolsar';

  @override
  String get toolsDebtHelp => 'Ayuda y recursos';

  @override
  String get toolsDebtHelpDesc => 'Contactos y organismos de apoyo';

  @override
  String get toolsConsumerCredit => 'Crédito consumo';

  @override
  String get toolsConsumerCreditDesc => 'Simula el costo real de un crédito';

  @override
  String get toolsLeasing => 'Calculadora leasing';

  @override
  String get toolsLeasingDesc => 'Costo real y alternativas al leasing';

  @override
  String get toolsCatBankDocs => 'Banco & Documentos';

  @override
  String get toolsOpenBanking => 'Open Banking';

  @override
  String get toolsOpenBankingDesc => 'Conecta tus cuentas bancarias';

  @override
  String get toolsBankImport => 'Importación bancaria';

  @override
  String get toolsBankImportDesc => 'Importa tus extractos CSV/PDF';

  @override
  String get toolsDocuments => 'Mis documentos';

  @override
  String get toolsDocumentsDesc => 'Certificados LPP y documentos importantes';

  @override
  String get toolsPortfolio => 'Portfolio';

  @override
  String get toolsPortfolioDesc => 'Vista general de tu situación';

  @override
  String get toolsTimeline => 'Timeline';

  @override
  String get toolsTimelineDesc =>
      'Tus fechas límite y recordatorios importantes';

  @override
  String get toolsConsent => 'Consentimientos';

  @override
  String get toolsConsentDesc => 'Gestiona tus autorizaciones de datos';

  @override
  String get vaultPremiumBadge => 'Premium';

  @override
  String get vaultExtractedFields => 'Campos extraídos';

  @override
  String get vaultCancelButton => 'Cancelar';

  @override
  String get vaultOkButton => 'OK';

  @override
  String get naissanceTitle => 'Nacimiento y familia';

  @override
  String get naissanceTabConge => 'Permiso';

  @override
  String get naissanceTabAllocations => 'Asignaciones';

  @override
  String get naissanceTabImpact => 'Impacto';

  @override
  String get naissanceTabChecklist => 'Checklist';

  @override
  String get naissanceLeaveType => 'Tipo de permiso';

  @override
  String get naissanceMother => 'Madre';

  @override
  String get naissanceFather => 'Padre';

  @override
  String get naissanceMonthlySalary => 'Salario mensual bruto';

  @override
  String naissanceCongeLabel(String type) {
    return 'PERMISO $type';
  }

  @override
  String naissanceWeeks(int count) {
    return '$count semanas';
  }

  @override
  String get naissanceApgPerDay => 'APG por día';

  @override
  String get naissanceTotalApg => 'Total APG';

  @override
  String naissanceCappedAt(String amount) {
    return 'Limitado a CHF $amount/día';
  }

  @override
  String get naissanceDailyDetail => 'DETALLE DIARIO';

  @override
  String get naissanceSalaryPerDay => 'Salario/día';

  @override
  String get naissanceApgDay => 'APG/día';

  @override
  String get naissanceDiffPerDay => 'Diferencia/día';

  @override
  String get naissanceNoLoss => 'Sin pérdida';

  @override
  String naissanceTotalLossEstimated(String amount) {
    return 'Pérdida total estimada durante el permiso: $amount';
  }

  @override
  String naissanceChiffreChocText(String type, String amount, int weeks) {
    return 'Tu permiso de $type representa $amount de APG en $weeks semanas';
  }

  @override
  String get naissanceMaternite => 'maternidad';

  @override
  String get naissancePaternite => 'paternidad';

  @override
  String get naissanceCongeEducational =>
      'Suiza introdujo el permiso de paternidad recién en 2021. Con 2 semanas, sigue siendo uno de los más cortos de Europa. El permiso de maternidad (14 semanas) existe desde 2005.';

  @override
  String get naissanceCanton => 'Cantón';

  @override
  String get naissanceNbEnfants => 'Número de hijos';

  @override
  String get naissanceRanking26 => 'SUBSIDIOS POR CANTÓN';

  @override
  String naissanceBestCanton(String canton) {
    return '¡$canton ofrece una de las asignaciones familiares más ventajosas de Suiza!';
  }

  @override
  String naissanceAllocDiff(String bestCanton, String canton, String amount) {
    return 'Viviendo en $bestCanton en lugar de $canton, recibirías $amount más al año en asignaciones familiares.';
  }

  @override
  String get naissanceRevenuAnnuel => 'Ingreso anual bruto';

  @override
  String get naissanceFraisGarde => 'Costes de guardería mensuales/hijo';

  @override
  String get naissanceTaxSavings => 'Ahorros fiscales';

  @override
  String get naissanceDeductionPerChild => 'Deducción por hijo';

  @override
  String get naissanceDeductionChildcare => 'Deducción de guardería';

  @override
  String get naissanceEstimatedTaxSaving => 'Ahorro fiscal estimado';

  @override
  String get naissanceAllowanceIncome => 'Ingresos de asignaciones';

  @override
  String get naissanceAnnualAllowances => 'Asignaciones anuales';

  @override
  String get naissanceCareerImpact => 'Impacto laboral (LPP)';

  @override
  String get naissanceEstimatedInterruption => 'Interrupción estimada';

  @override
  String naissanceMonths(int count) {
    return '$count meses';
  }

  @override
  String get naissanceLppLossEstimated => 'Pérdida LPP estimada';

  @override
  String get naissanceLppLessContributions =>
      'Menos cotizaciones LPP = menos capital para la jubilación';

  @override
  String get naissanceNetAnnualImpact => 'Impacto neto anual estimado';

  @override
  String get naissanceNetFormula =>
      'Ahorros fiscales + asignaciones - coste estimado';

  @override
  String get naissanceWaterfallRevenu => 'Ingreso bruto anual';

  @override
  String get naissanceWaterfallAlloc => 'Asignaciones familiares';

  @override
  String get naissanceWaterfallCosts => 'Costes base (est.)';

  @override
  String get naissanceWaterfallChildcare => 'Costes de guardería anuales';

  @override
  String get naissanceWaterfallAfter => 'Después de hijo(s)';

  @override
  String get naissanceChildCostEducational =>
      'Un hijo cuesta en promedio CHF 1\'500/mes en Suiza (alimentación, ropa, actividades, seguro). Pero las asignaciones y deducciones fiscales reducen significativamente el impacto neto.';

  @override
  String get naissanceChecklistIntro =>
      'La llegada de un hijo implica muchos trámites administrativos y financieros. Aquí están los pasos que no debes olvidar.';

  @override
  String naissanceStepsCompleted(int done, int total) {
    return '$done/$total trámites completados';
  }

  @override
  String get naissanceDidYouKnow => '¿Lo sabías?';

  @override
  String get naissanceDisclaimer =>
      'Estimaciones simplificadas con fines educativos — no constituye asesoramiento en previsión ni fiscal. Los importes dependen de muchos factores (cantón, municipio, situación familiar, etc.). Consulta a un·a especialista para un cálculo personalizado.';

  @override
  String get mariageTitle => 'Matrimonio y fiscalidad';

  @override
  String get mariageTabImpots => 'Impuestos';

  @override
  String get mariageTabRegime => 'Régimen';

  @override
  String get mariageTabProtection => 'Protección';

  @override
  String get mariageRevenu1 => 'Ingreso 1';

  @override
  String get mariageRevenu2 => 'Ingreso 2';

  @override
  String get mariageCanton => 'Cantón';

  @override
  String get mariageEnfants => 'Hijos';

  @override
  String get mariageFiscalComparison => 'COMPARACIÓN FISCAL';

  @override
  String get mariageTwoCelibataires => '2 solteros';

  @override
  String get mariageMaries => 'Casados';

  @override
  String mariagePenaltyAmount(String amount) {
    return 'Penalización +$amount/año';
  }

  @override
  String mariageBonusAmount(String amount) {
    return 'Bonificación -$amount/año';
  }

  @override
  String get mariageDeductions => 'DEDUCCIONES MATRIMONIO';

  @override
  String get mariageDeductionCouple => 'Deducción pareja casada';

  @override
  String get mariageDeductionInsurance => 'Deducción seguro (casada)';

  @override
  String get mariageDeductionDualIncome => 'Deducción doble ingreso';

  @override
  String get mariageDeductionChildren => 'Deducción hijos';

  @override
  String get mariageTotalDeductions => 'Total deducciones';

  @override
  String get mariageEducationalPenalty =>
      '¿Sabías que la penalización por matrimonio afecta a ~700\'000 parejas en Suiza? El Tribunal Federal declaró esta situación inconstitucional en 1984, pero aún no se ha corregido.';

  @override
  String get mariageRegimeMatrimonial => 'RÉGIMEN MATRIMONIAL';

  @override
  String get mariageParticipation => 'Participación en los bienes gananciales';

  @override
  String get mariageParticipationSub => 'Régimen por defecto (CC art. 181)';

  @override
  String get mariageParticipationDesc =>
      'Cada uno conserva sus bienes propios. Los bienes gananciales (ganancias durante el matrimonio) se reparten 50/50 en caso de disolución.';

  @override
  String get mariageSeparation => 'Separación de bienes';

  @override
  String get mariageSeparationSub => 'CC art. 247';

  @override
  String get mariageSeparationDesc =>
      'Cada uno conserva la totalidad de sus bienes e ingresos. Sin reparto automático.';

  @override
  String get mariageCommunaute => 'Comunidad de bienes';

  @override
  String get mariageCommunauteSub => 'CC art. 221';

  @override
  String get mariageCommunauteDesc =>
      'Todo se pone en común: bienes propios y gananciales. Reparto igualitario total en caso de disolución.';

  @override
  String get mariagePatrimoine1 => 'Patrimonio Persona 1';

  @override
  String get mariagePatrimoine2 => 'Patrimonio Persona 2';

  @override
  String get mariageChiffreChocDefault =>
      'En el régimen por defecto, esta parte de tus bienes gananciales pasaría a tu cónyuge en caso de disolución';

  @override
  String get mariageChiffreChocCommunaute =>
      'En comunidad de bienes, este importe se compartiría con tu cónyuge';

  @override
  String get mariageProtectionIntro =>
      '¿Qué pasa si uno de los dos fallece? Compara la protección legal entre casados y concubinos.';

  @override
  String get mariageLppRenteLabel => 'Renta LPP mensual del fallecido';

  @override
  String get mariageAvsSurvivor => 'Renta AVS de sobreviviente';

  @override
  String get mariageAvsSurvivorSub => '80% de la renta máxima del fallecido';

  @override
  String get mariageAvsSurvivorFootnote => 'LAVS art. 35 — solo para casados';

  @override
  String get mariageLppSurvivor => 'Renta LPP de sobreviviente';

  @override
  String get mariageLppSurvivorSub => '60% de la renta asegurada del fallecido';

  @override
  String get mariageLppSurvivorFootnote =>
      'LPP art. 19 — casados (concubinos: cláusula necesaria)';

  @override
  String get mariageSurvivorMonthly =>
      'Ingreso mensual del sobreviviente casado';

  @override
  String get mariageVsConcubin => 'CASADO VS CONCUBINO';

  @override
  String get mariageRenteAvsSurvivor => 'Renta AVS sobreviviente';

  @override
  String get mariageRenteLppSurvivor => 'Renta LPP sobreviviente';

  @override
  String get mariageHeritageExonere => 'Herencia exenta';

  @override
  String get mariagePensionAlimentaire => 'Pensión alimenticia';

  @override
  String get mariageConcubinWarning =>
      'En concubinato, el compañero sobreviviente no tiene derechos por defecto — ni renta AVS, ni herencia exenta. Todo debe preverse por contrato.';

  @override
  String get mariageProtectionsEssentielles => 'PROTECCIONES ESENCIALES';

  @override
  String get mariageChecklistIntro =>
      'El matrimonio tiene consecuencias financieras y jurídicas. Aquí están los pasos esenciales que anticipar para prepararte bien.';

  @override
  String get mariageDisclaimer =>
      'Estimaciones simplificadas con fines educativos — no constituye asesoramiento fiscal ni jurídico. Los importes dependen de muchos factores (deducciones, municipio, patrimonio, etc.). Consulta a un·a especialista fiscal para un cálculo personalizado.';

  @override
  String get divorceAppBarTitle => 'Divorcio — Impacto financiero';

  @override
  String get divorceHeaderTitle => 'Impacto financiero de un divorcio';

  @override
  String get divorceHeaderSubtitle => 'Anticipa las consecuencias financieras';

  @override
  String get divorceIntroText =>
      'Un divorcio tiene consecuencias financieras a menudo subestimadas: reparto del patrimonio, de la previsión (LPP/3a), impacto fiscal y pensión alimenticia. Esta herramienta te ayuda a ver más claro.';

  @override
  String divorceYears(int count) {
    return '$count años';
  }

  @override
  String get divorceNbEnfants => 'Número de hijos';

  @override
  String get divorceParticipationDefault =>
      'Participación en los gananciales (defecto)';

  @override
  String get divorceCommunaute => 'Comunidad de bienes';

  @override
  String get divorceSeparation => 'Separación de bienes';

  @override
  String get divorceFortune => 'Fortuna común';

  @override
  String get divorceDettes => 'Deudas comunes';

  @override
  String get divorcePensionDescription =>
      'Estimación basada en la diferencia de ingresos y el número de hijos. El importe real depende de muchos factores (custodia, necesidades, nivel de vida).';

  @override
  String get divorceActionsTitle => 'Acciones a tomar';

  @override
  String get divorceComprendre => 'COMPRENDER';

  @override
  String get divorceEduParticipationTitle =>
      '¿Qué es la participación en los bienes gananciales?';

  @override
  String get divorceEduParticipationContent =>
      'La participación en los bienes gananciales es el régimen matrimonial por defecto en Suiza (CC art. 181 ss). Cada cónyuge conserva sus bienes propios (adquiridos antes del matrimonio o por sucesión/donación). Los bienes gananciales (adquiridos durante el matrimonio) se reparten por partes iguales en caso de divorcio. Es el régimen más común en Suiza.';

  @override
  String get divorceEduLppTitle => '¿Cómo funciona el reparto LPP?';

  @override
  String get divorceEduLppContent =>
      'Desde el 1 de enero de 2017 (CC art. 122), los haberes de previsión profesional (2° pilar) acumulados durante el matrimonio se reparten por partes iguales en caso de divorcio. El reparto se hace directamente entre las dos cajas de pensiones, sin pasar por las cuentas personales de los cónyuges. Es un derecho imperativo al que los cónyuges solo pueden renunciar bajo condiciones estrictas.';

  @override
  String get successionAppBarTitle => 'Sucesión — Planificación';

  @override
  String get successionHeaderTitle => 'Planificar mi sucesión';

  @override
  String get successionHeaderSubtitle => 'Nuevo derecho sucesorio 2023';

  @override
  String get successionIntroText =>
      'El nuevo derecho sucesorio (2023) ha ampliado la porción disponible. Ahora tienes más libertad para favorecer a ciertos herederos. Esta herramienta te muestra la distribución legal y el impacto de un testamento.';

  @override
  String get donationAppBarTitle => 'Donación — Simulador';

  @override
  String get donationHeaderTitle => 'Simular una donación';

  @override
  String get donationHeaderSubtitle =>
      'Fiscalidad, reserva hereditaria, impacto';

  @override
  String get housingSaleAppBarTitle => 'Venta inmobiliaria';

  @override
  String get housingSaleHeaderTitle => 'Simula tu venta inmobiliaria';

  @override
  String get housingSaleHeaderSubtitle =>
      'Impuesto sobre ganancias, EPL, producto neto';

  @override
  String get housingSaleCalculer => 'Calcular';

  @override
  String get lifeEventComprendre => 'COMPRENDER';

  @override
  String get lifeEventPointsAttention => 'PUNTOS DE ATENCIÓN';

  @override
  String get lifeEventActionsTitle => 'Acciones a tomar';

  @override
  String get lifeEventChecklistSubtitle => 'Checklist de preparación';

  @override
  String get lifeEventDidYouKnow => '¿Lo sabías?';

  @override
  String get unemploymentTitle => 'Pérdida de empleo';

  @override
  String get unemploymentHeaderDesc =>
      'Estima tus derechos al desempleo (LACI). El cálculo depende de tu salario asegurado, tu edad y el período de cotización de los últimos 2 años.';

  @override
  String get unemploymentGainSliderTitle => 'Salario asegurado mensual';

  @override
  String get unemploymentAgeSliderTitle => 'Tu edad';

  @override
  String unemploymentAgeValue(int age) {
    return '$age años';
  }

  @override
  String get unemploymentAgeMin => '18 años';

  @override
  String get unemploymentAgeMax => '65 años';

  @override
  String get unemploymentContribTitle => 'Meses de cotización (últimos 2 años)';

  @override
  String unemploymentContribValue(int months) {
    return '$months meses';
  }

  @override
  String get unemploymentContribMax => '24 meses';

  @override
  String get unemploymentSituationTitle => 'Situación personal';

  @override
  String get unemploymentSituationSubtitle =>
      'Influye en la tasa de indemnización (70% u 80%)';

  @override
  String get unemploymentChildrenToggle => 'Obligación de manutención (hijos)';

  @override
  String get unemploymentDisabilityToggle => 'Discapacidad reconocida';

  @override
  String get unemploymentNotEligible => 'No elegible';

  @override
  String get unemploymentCompensationRate => 'Tasa de indemnización';

  @override
  String get unemploymentRateEnhanced =>
      'Tasa aumentada (80%): obligación de manutención, discapacidad o salario < CHF 3\'797';

  @override
  String get unemploymentRateStandard =>
      'Tasa estándar (70%): aplicable en otras situaciones';

  @override
  String get unemploymentDailyBenefit => 'Indemnización /día';

  @override
  String get unemploymentMonthlyBenefit => 'Indemnización /mes';

  @override
  String get unemploymentInsuredEarnings => 'Salario asegurado retenido';

  @override
  String get unemploymentWaitingPeriod => 'Período de carencia';

  @override
  String unemploymentWaitingDays(int days) {
    return '$days días';
  }

  @override
  String get unemploymentDurationHeader => 'DURACIÓN DE LAS PRESTACIONES';

  @override
  String get unemploymentDailyBenefits => 'indemnizaciones diarias';

  @override
  String get unemploymentCoverageMonths => 'meses de cobertura';

  @override
  String get unemploymentYouTag => 'TÚ';

  @override
  String get unemploymentChecklistHeader => 'CHECKLIST';

  @override
  String get unemploymentCheckItem1 =>
      'Inscribirse en la ORP desde el primer día sin empleo';

  @override
  String get unemploymentCheckItem2 =>
      'Depositar el expediente en la caja de desempleo';

  @override
  String get unemploymentCheckItem3 =>
      'Adaptar el presupuesto al nuevo ingreso';

  @override
  String get unemploymentCheckItem4 =>
      'Transferir el haber LPP a una cuenta de libre paso';

  @override
  String get unemploymentCheckItem5 =>
      'Verificar los derechos a una reducción de prima LAMal';

  @override
  String get unemploymentCheckItem6 =>
      'Actualizar el presupuesto MINT con el nuevo ingreso';

  @override
  String get unemploymentGoodToKnow => 'BUENO SABER';

  @override
  String get unemploymentEduFastTitle => 'Inscripción rápida';

  @override
  String get unemploymentEduFastBody =>
      'Inscríbete en la ORP lo antes posible. Cada día de retraso puede suponer una suspensión de tus indemnizaciones.';

  @override
  String get unemploymentEdu3aTitle => '3.er pilar en pausa';

  @override
  String get unemploymentEdu3aBody =>
      'Sin ingresos laborales, ya no puedes cotizar al 3a. Las indemnizaciones de desempleo no se consideran ingresos laborales a efectos del 3.er pilar.';

  @override
  String get unemploymentEduLppTitle => 'LPP y desempleo';

  @override
  String get unemploymentEduLppBody =>
      'Durante el desempleo, solo los riesgos de muerte e invalidez están cubiertos por el LPP. El ahorro para la jubilación se detiene. Transfiere tu capital a una cuenta de libre paso.';

  @override
  String get unemploymentEduLamalTitle => 'Reducción de prima LAMal';

  @override
  String get unemploymentEduLamalBody =>
      'Con un ingreso más bajo, podrías tener derecho a subsidios LAMal. Haz la solicitud en tu cantón.';

  @override
  String get unemploymentTsunamiTitle => 'Tu tsunami financiero en 3 olas';

  @override
  String get unemploymentDisclaimer =>
      'Estimaciones educativas — no constituye asesoramiento según la LSFin — LACI/LPP/OPP3. Los montos presentados son aproximados y dependen de tu situación personal. Consulta a un·a especialista o la ORP de tu cantón.';

  @override
  String get firstJobTitle => 'Primer empleo';

  @override
  String get firstJobHeaderDesc =>
      '¡Comprende tu nómina! Te mostramos a dónde van tus cotizaciones, lo que paga tu empleador además, y los primeros reflejos financieros a adoptar.';

  @override
  String get firstJobSalaryTitle => 'Salario bruto mensual';

  @override
  String get firstJobActivityRate => 'Tasa de actividad';

  @override
  String get firstJob3aHeader => 'PILAR 3A — ABRIR AHORA';

  @override
  String get firstJob3aAnnualCap => 'Tope anual';

  @override
  String get firstJob3aMonthlySuggestion => 'Sugerencia /mes';

  @override
  String get firstJob3aWarningTitle => 'ATENCIÓN — SEGURO DE VIDA 3A';

  @override
  String get firstJobLamalHeader => 'COMPARACIÓN FRANQUICIAS LAMAL';

  @override
  String get firstJobChecklistHeader => 'PRIMEROS REFLEJOS';

  @override
  String get firstJobEduLppTitle => 'LPP desde los 25 años';

  @override
  String get firstJobEduLppBody =>
      'La cotización LPP (2.º pilar) comienza a los 25 años para el ahorro de jubilación. Antes de los 25, solo los riesgos de muerte e invalidez están cubiertos.';

  @override
  String get firstJobEdu13Title => '13.º salario';

  @override
  String get firstJobEdu13Body =>
      'Si tu contrato prevé un 13.º salario, este también está sujeto a las deducciones sociales. Tu salario mensual bruto es entonces el salario anual dividido por 13.';

  @override
  String get firstJobEduBudgetTitle => 'Regla del 50/30/20';

  @override
  String get firstJobEduBudgetBody =>
      'Un buen reflejo para tu primer salario: 50% para gastos fijos, 30% para ocio, 20% para ahorro y previsión (3a incluido).';

  @override
  String get firstJobEduTaxTitle => 'Declaración fiscal';

  @override
  String get firstJobEduTaxBody =>
      'Desde tu primer empleo, tendrás que rellenar una declaración fiscal. Guarda todas tus certificaciones (salario, 3a, gastos profesionales).';

  @override
  String get firstJobAnalysisHeader =>
      'Análisis MINT — La película de tu salario';

  @override
  String get firstJobProfileBadge => 'Tu perfil';

  @override
  String get firstJobIllustrativeBadge => 'Ilustrativo';

  @override
  String get firstJobDisclaimer =>
      'Estimaciones educativas — no constituye asesoramiento — LACI/LPP/OPP3. Los montos son aproximados y no tienen en cuenta todas las especificidades cantonales. Consulta priminfo.admin.ch para las primas LAMal exactas. Consulta a un·a especialista en previsión.';

  @override
  String get independantAppBarTitle => 'CAMINO INDEPENDIENTE';

  @override
  String get independantTitle => 'Independiente';

  @override
  String get independantSubtitle => 'Análisis de cobertura y protección';

  @override
  String get independantIntroDesc =>
      'Como independiente, no tienes LPP obligatorio, ni IJM, ni LAA. Tu protección social depende enteramente de tus gestiones personales. Identifica tus lagunas.';

  @override
  String get independantRevenueTitle => 'Ingreso neto anual';

  @override
  String independantAgeLabel(int age) {
    return 'Edad: $age años';
  }

  @override
  String get independantCoverageTitle => 'Mi cobertura actual';

  @override
  String get independantToggleLpp => 'LPP (afiliación voluntaria)';

  @override
  String get independantToggleIjm =>
      'IJM (indemnización diaria por enfermedad)';

  @override
  String get independantToggleLaa => 'LAA (seguro de accidentes)';

  @override
  String get independantToggle3a => '3.er pilar (3a)';

  @override
  String get independantCoverageAnalysis => 'ANÁLISIS DE COBERTURA';

  @override
  String get independantProtectionCostTitle =>
      'Coste de mi protección completa';

  @override
  String get independantProtectionCostSubtitle => 'Estimación mensual';

  @override
  String get independantTotalMonthly => 'Total mensual';

  @override
  String get independantAvsTitle => 'Cotización AVS independiente';

  @override
  String get independant3aTitle => '3.er pilar — tope independiente';

  @override
  String get independantRecommendationsHeader => 'RECOMENDACIONES';

  @override
  String get independantAnalysisHeader =>
      'Análisis MINT — Tu kit de independiente';

  @override
  String get independantSourcesTitle => 'Fuentes';

  @override
  String get independantSourcesBody =>
      'LPP art. 4 (sin obligación para independientes) / LPP art. 44 (afiliación voluntaria) / OPP3 art. 7 (3a grande: 20% del ingreso neto, máx. 36\'288) / LAVS art. 8 (cotizaciones independientes) / LAA art. 4 / LAMal';

  @override
  String get independantDisclaimer =>
      'Los montos presentados son estimaciones indicativas. Las cotizaciones reales dependen de tu situación personal y de las ofertas de seguros disponibles. Consulta a un fiduciario o asegurador antes de cualquier decisión.';

  @override
  String get jobCompareAgeTitle => 'Tu edad';

  @override
  String get jobCompareAgeSubtitle =>
      'Utilizado para proyectar el capital de jubilación';

  @override
  String get jobCompareSalaryLabel => 'Salario bruto anual';

  @override
  String get jobCompareEmployerShare => 'Parte empleador LPP';

  @override
  String get jobCompareConversionRate => 'Tasa de conversión';

  @override
  String get jobCompareRetirementAssets => 'Capital de vejez actual';

  @override
  String get jobCompareDisabilityCoverage => 'Cobertura de invalidez';

  @override
  String get jobCompareDeathCapital => 'Capital por defunción';

  @override
  String get jobCompareMaxBuyback => 'Recompra máxima';

  @override
  String get jobCompareVerdictLabel => 'VEREDICTO';

  @override
  String get jobCompareDetailedTitle => 'Comparación detallada';

  @override
  String get jobCompareRetirementImpact => 'IMPACTO EN TODA LA JUBILACIÓN';

  @override
  String get jobCompareAttentionPoints => 'PUNTOS DE ATENCIÓN';

  @override
  String get jobCompareChecklistTitle => 'Antes de firmar';

  @override
  String get jobCompareUnderstandHeader => 'COMPRENDER';

  @override
  String get jobCompareEduInvisibleTitle => '¿Qué es el salario invisible?';

  @override
  String get jobCompareEduInvisibleBody =>
      'El \"salario invisible\" representa el 10-30% de tu remuneración total. Incluye la parte del empleador a la caja de pensiones (LPP), los seguros (IJM, accidente) y a veces ventajas complementarias. Dos puestos con el mismo salario bruto pueden ofrecer protecciones muy diferentes.';

  @override
  String get jobCompareEduCertTitle =>
      '¿Cómo leer mi certificado de previsión?';

  @override
  String get jobCompareEduCertBody =>
      'Tu certificado de previsión (LPP) contiene toda la información necesaria: salario asegurado, deducción de coordinación, tasa de cotización, capital de vejez, tasa de conversión, prestaciones de riesgo (invalidez y muerte) y posible recompra. Pídelo a tu RH o caja de pensiones.';

  @override
  String get jobCompareAxisLabel => 'Eje';

  @override
  String get jobCompareCurrentLabel => 'Actual';

  @override
  String get jobCompareNewLabel => 'Nuevo';

  @override
  String get disabilityGapParamsTitle => 'Tus parámetros';

  @override
  String get disabilityGapParamsSubtitle => 'Ajusta según tu situación';

  @override
  String get disabilityGapIncomeLabel => 'Ingreso mensual neto';

  @override
  String get disabilityGapCantonLabel => 'Cantón';

  @override
  String get disabilityGapStatusLabel => 'Estatus profesional';

  @override
  String get disabilityGapEmployee => 'Asalariado';

  @override
  String get disabilityGapSelfEmployed => 'Indep.';

  @override
  String get disabilityGapSeniorityLabel => 'Años de antigüedad';

  @override
  String get disabilityGapIjmLabel => 'IJM colectiva a través de mi empleador';

  @override
  String get disabilityGapDegreeLabel => 'Grado de invalidez';

  @override
  String get disabilityGapChartTitle => 'Evolución de tu cobertura';

  @override
  String get disabilityGapChartSubtitle => 'Las 3 fases de protección';

  @override
  String get disabilityGapCurrentIncome => 'Ingreso actual';

  @override
  String get disabilityGapMaxGap => 'BRECHA MENSUAL MÁXIMA';

  @override
  String get disabilityGapPhaseDetail => 'DETALLE DE LAS FASES';

  @override
  String get disabilityGapPhase1Title => 'Fase 1: Empleador';

  @override
  String get disabilityGapPhase2Title => 'Fase 2: IJM';

  @override
  String get disabilityGapPhase3Title => 'Fase 3: AI + LPP';

  @override
  String get disabilityGapDurationLabel => 'Duración:';

  @override
  String get disabilityGapCoverageLabel => 'Cobertura:';

  @override
  String get disabilityGapLegalLabel => 'Fuente legal:';

  @override
  String get disabilityGapIfYouAre => 'SI ERES...';

  @override
  String get disabilityGapEduTitle => 'COMPRENDER';

  @override
  String get disabilityGapEduIjmTitle => 'IJM vs AI: ¿cuál es la diferencia?';

  @override
  String get disabilityGapEduIjmBody =>
      'La IJM (indemnización diaria por enfermedad) es un seguro que cubre el 80% de tu salario durante máx. 720 días en caso de enfermedad. El empleador no está obligado a suscribirla, pero muchos lo hacen a través de un seguro colectivo. Sin IJM, tras el período legal de mantenimiento del salario, no recibes nada hasta la eventual renta AI.';

  @override
  String get disabilityGapEduCoTitle =>
      'La obligación de tu empleador (CO art. 324a)';

  @override
  String get disabilityGapEduCoBody =>
      'Según el art. 324a CO, el empleador debe pagar el salario durante un período limitado en caso de enfermedad. Esta duración depende de los años de servicio y de la escala cantonal aplicable (bernesa, zuriquesa o basilea). Después de este período, solo la IJM (si existe) toma el relevo.';

  @override
  String get successionIntroDesc =>
      'El nuevo derecho sucesorio (2023) ha ampliado la cuota disponible. Ahora tienes más libertad para favorecer a ciertos herederos. Esta herramienta te muestra la distribución legal y el impacto de un testamento.';

  @override
  String get successionSimulateButton => 'Simular';

  @override
  String get successionLegalDistribution => 'DISTRIBUCIÓN LEGAL';

  @override
  String get successionTestamentDistribution => 'DISTRIBUCIÓN CON TESTAMENTO';

  @override
  String get successionReservesTitle => 'Reservas hereditarias';

  @override
  String get successionReservesSubtitle => 'CC art. 470–471';

  @override
  String get successionQuotiteTitle => 'Porción disponible';

  @override
  String get successionQuotiteDesc =>
      'Este monto puede ser libremente atribuido por testamento a la persona de tu elección.';

  @override
  String get successionBeneficiaries3aTitle => 'BENEFICIARIOS 3a (OPP3 ART. 2)';

  @override
  String get successionBeneficiaries3aDesc =>
      'El 3.er pilar NO sigue tu testamento. El orden de beneficiarios está fijado por ley:';

  @override
  String get successionChecklistTitle => 'Checklist protección patrimonial';

  @override
  String get successionTotalTax => 'Total impuesto sucesorio';

  @override
  String get successionTestamentSwitch => 'Tengo un testamento';

  @override
  String get successionBeneficiaryQuestion =>
      '¿Quién recibe la cuota disponible?';

  @override
  String get successionCivilStatusLabel => 'Estado civil';

  @override
  String get successionFortuneLabel => 'Fortuna total';

  @override
  String get successionAvoirs3aLabel => 'Haberes 3a';

  @override
  String get successionDeathCapitalLabel => 'Capital de defunción LPP';

  @override
  String get successionChildrenLabel => 'Número de hijos';

  @override
  String get successionParentsAlive => 'Padres vivos';

  @override
  String get successionSiblings => 'Hermanos (hermanos/hermanas)';

  @override
  String get mariageProtectionItem1 =>
      'Redactar un testamento (cláusula de usufructo)';

  @override
  String get mariageProtectionItem2 =>
      'Cláusula de beneficiario LPP (preguntar a tu fondo de pensiones)';

  @override
  String get mariageProtectionItem3 =>
      'Seguro de vida cruzado (protección de la pareja)';

  @override
  String get mariageProtectionItem4 => 'Mandato por incapacidad';

  @override
  String get mariageProtectionItem5 => 'Directivas anticipadas del paciente';

  @override
  String get mariageChecklistItem1Title =>
      'Simular el impacto fiscal del matrimonio';

  @override
  String get mariageChecklistItem1Desc =>
      'Antes de casarte, compara la carga fiscal en pareja (casados vs solteros). Si los ingresos son similares y altos, la penalización por matrimonio puede representar varios miles de francos al año.';

  @override
  String get mariageChecklistItem2Title => 'Elegir el régimen matrimonial';

  @override
  String get mariageChecklistItem2Desc =>
      'Por defecto, es la participación en las ganancias (CC art. 181). Si quieres otro régimen (separación de bienes, comunidad de bienes), debes firmar un contrato matrimonial ante notario ANTES o durante el matrimonio.';

  @override
  String get mariageChecklistItem3Title =>
      'Actualizar las cláusulas de beneficiarios LPP y 3a';

  @override
  String get mariageChecklistItem3Desc =>
      'El matrimonio cambia el orden de beneficiarios. Tu cónyuge se convierte automáticamente en beneficiario de la pensión de supervivencia LPP (LPP art. 19). Verifica también los beneficiarios de tu 3er pilar.';

  @override
  String get mariageChecklistItem4Title =>
      'Informar a tu empleador y seguro de salud';

  @override
  String get mariageChecklistItem4Desc =>
      'Tu empleador debe actualizar tus datos (estado civil, deducciones). Tu seguro de salud debe ser informado — las primas no cambian, pero los subsidios se recalculan según los ingresos del hogar.';

  @override
  String get mariageChecklistItem5Title =>
      'Preparar la primera declaración conjunta';

  @override
  String get mariageChecklistItem5Desc =>
      'Desde el año del matrimonio, se presenta una sola declaración fiscal conjunta. Reúne los justificantes de ambos (certificados de salario, 3a, LPP, etc.). El cambio a declaración conjunta puede modificar tu tramo impositivo.';

  @override
  String get mariageChecklistItem6Title => 'Verificar las rentas AVS de pareja';

  @override
  String get mariageChecklistItem6Desc =>
      'La renta AVS máxima para una pareja está limitada al 150% de la renta individual máxima (LAVS art. 35). Si tienes derecho a la renta máxima con tu cónyuge, el tope puede reducir tu total.';

  @override
  String get mariageChecklistItem7Title => 'Adaptar el testamento';

  @override
  String get mariageChecklistItem7Desc =>
      'El matrimonio modifica el orden de sucesión. El cónyuge se convierte en heredero legal con derechos importantes (CC art. 462). Si tenías un testamento a favor de un tercero, quizás deba revisarse.';

  @override
  String mariageChecklistProgress(int done, int total) {
    return '$done/$total pasos completados';
  }

  @override
  String get mariageRepartitionDissolution => 'REPARTO EN CASO DE DISOLUCIÓN';

  @override
  String get mariagePersonne1Recoit => 'Persona 1 recibe';

  @override
  String get mariagePersonne2Recoit => 'Persona 2 recibe';

  @override
  String get mariagePersonne1Garde => 'Persona 1 conserva';

  @override
  String get mariagePersonne2Garde => 'Persona 2 conserva';

  @override
  String get successionSituationTitle => 'SITUACIÓN PERSONAL';

  @override
  String get successionSituationSubtitle2 => 'Estado civil, herederos';

  @override
  String get successionFortuneTitle => 'PATRIMONIO';

  @override
  String get successionFortuneSubtitle2 => 'Patrimonio total, 3a, LPP';

  @override
  String get successionTestamentTitle => 'Testamento';

  @override
  String get successionTestamentSubtitle2 => 'Voluntades testamentarias';

  @override
  String successionQuotitePct(String pct) {
    return 'es decir, $pct% de la sucesión';
  }

  @override
  String get successionExonereLabel => 'Exento';

  @override
  String successionFiscaliteCanton(String canton) {
    return 'FISCALIDAD SUCESORIA ($canton)';
  }

  @override
  String get successionEduQuotiteBody2 =>
      'La cuota disponible es la parte de tu sucesión que puedes asignar libremente por testamento. Desde el 1 de enero de 2023, la legítima de los descendientes se redujo de 3/4 a 1/2. Los padres ya no tienen legítima. Esto te da más libertad.';

  @override
  String get successionEdu3aBody2 =>
      'El 3.er pilar (3a) NO forma parte de la masa hereditaria ordinaria. Se paga directamente a los beneficiarios según el orden fijado por la OPP3 (art. 2): cónyuge/pareja registrada, luego descendientes, padres, hermanos. El concubino puede ser designado beneficiario, pero solo mediante una cláusula explícita depositada en la fundación.';

  @override
  String get successionEduConcubinBody2 =>
      'En derecho suizo, los concubinos NO tienen derechos sucesorios legales. Sin testamento, un concubino no recibe nada. Además, el impuesto sucesorio para concubinos es generalmente mucho más alto que para cónyuges (a menudo 20-25% en lugar de 0%). Para proteger a tu pareja, es esencial redactar un testamento, verificar las cláusulas de beneficiarios 3a/LPP y considerar seguros de vida.';

  @override
  String get successionDisclaimerText =>
      'Los resultados presentados son estimaciones indicativas y no constituyen un asesoramiento jurídico o notarial personalizado. El derecho sucesorio tiene muchas sutilezas. Consulte a un notario o abogado especializado antes de tomar cualquier decisión.';

  @override
  String get donationIntroText =>
      'Las donaciones en Suiza están sujetas a un impuesto cantonal que varía según el parentesco y el cantón. Desde 2023, la legítima se ha reducido, dándote más libertad. Esta herramienta te ayuda a estimar el impuesto y verificar la compatibilidad con los derechos de los herederos.';

  @override
  String get donationSectionTitle => 'DONACIÓN';

  @override
  String get donationSectionSubtitle => 'Monto, beneficiario, tipo';

  @override
  String get donationMontantLabel => 'Monto de la donación';

  @override
  String get donationLienParente => 'Parentesco';

  @override
  String get donationTypeDonation => 'Tipo de donación';

  @override
  String get donationValeurImmobiliere => 'Valor inmobiliario';

  @override
  String get donationAvancementHoirie => 'Anticipo de herencia';

  @override
  String get donationContexteSuccessoral => 'CONTEXTO SUCESORIO';

  @override
  String get donationContexteSubtitle =>
      'Familia, patrimonio, régimen matrimonial';

  @override
  String get donationAgeLabel => 'Edad del donante';

  @override
  String get donationNbEnfants => 'Número de hijos';

  @override
  String get donationFortuneTotale => 'Patrimonio total del donante';

  @override
  String get donationRegimeMatrimonial => 'Régimen matrimonial';

  @override
  String get donationCalculer => 'Calcular';

  @override
  String get donationImpotTitle => 'IMPUESTO SOBRE LA DONACIÓN';

  @override
  String get donationExoneree => 'Exenta';

  @override
  String donationTauxCanton(String taux, String canton) {
    return 'Tasa: $taux% (cantón $canton)';
  }

  @override
  String get donationMontantRow => 'Monto de la donación';

  @override
  String get donationLienRow => 'Parentesco';

  @override
  String get donationReserveTitle => 'LEGÍTIMA (2023)';

  @override
  String get donationReserveProtege => 'monto protegido por la ley (intocable)';

  @override
  String get donationReserveNote =>
      'Desde 2023, los padres ya no tienen legítima. La legítima de los descendientes es del 50% de su parte legal (CC art. 471).';

  @override
  String get donationQuotiteTitle => 'CUOTA DISPONIBLE';

  @override
  String get donationQuotiteDesc => 'monto que puedes donar libremente';

  @override
  String donationDepassement(String amount) {
    return 'Exceso de $amount — riesgo de acción de reducción';
  }

  @override
  String get donationImpactTitle => 'IMPACTO EN LA SUCESIÓN';

  @override
  String get donationAvancementNote =>
      'Anticipo de herencia: la donación se imputará a la masa hereditaria.';

  @override
  String get donationHorsPartNote =>
      'Donación fuera de parte: se imputa solo a la cuota disponible.';

  @override
  String get donationEduQuotiteTitle => '¿Qué es la cuota disponible?';

  @override
  String get donationEduQuotiteBody =>
      'La cuota disponible es la parte de tu patrimonio que puedes donar o legar libremente sin afectar las legítimas. Desde el 1 de enero de 2023, la legítima de los descendientes se redujo de 3/4 a 1/2 de su parte legal, y los padres ya no tienen legítima. Esto te da más libertad para hacer donaciones.';

  @override
  String get donationEduAvancementTitle =>
      'Anticipo de herencia vs donación fuera de parte';

  @override
  String get donationEduAvancementBody =>
      'Un anticipo de herencia es un adelanto sobre la parte hereditaria del beneficiario. Se imputará a la masa hereditaria al fallecimiento. Una donación fuera de parte (o preciput) se imputa solo a la cuota disponible y no se reporta. La elección entre ambos tiene un impacto importante en el equilibrio entre herederos.';

  @override
  String get donationEduConcubinTitle => 'Donaciones y concubinos';

  @override
  String get donationEduConcubinBody =>
      'Los concubinos no tienen derechos sucesorios legales en Suiza. Una donación es la forma más directa de favorecerlos. Sin embargo, el impuesto cantonal sobre donaciones entre concubinos es generalmente alto (18-25% según el cantón). Schwyz es la excepción: sin impuesto sobre donaciones. Considerar un testamento complementario para protección completa.';

  @override
  String get donationDisclaimer =>
      'Esta herramienta educativa proporciona estimaciones indicativas y no constituye asesoramiento jurídico, fiscal o notarial personalizado en el sentido de la LSFin. Consulta a un especialista (notario) para tu situación.';

  @override
  String get donationCanton => 'Cantón';

  @override
  String get housingSaleIntroText =>
      'Vender una propiedad en Suiza implica un impuesto sobre las ganancias inmobiliarias (LHID art. 12), el posible reembolso de fondos de previsión utilizados (EPL) y gastos de transacción. Esta herramienta te ayuda a estimar el producto neto de tu venta.';

  @override
  String get housingSaleBienTitle => 'PROPIEDAD';

  @override
  String get housingSaleBienSubtitle => 'Precio de compra, venta, inversiones';

  @override
  String get housingSalePrixAchat => 'Precio de compra';

  @override
  String get housingSalePrixVente => 'Precio de venta';

  @override
  String get housingSaleAnneeAchat => 'Año de compra';

  @override
  String get housingSaleInvestissements => 'Inversiones valorizantes';

  @override
  String get housingSaleFraisAcquisition =>
      'Gastos de adquisición (notario, etc.)';

  @override
  String get housingSaleResidencePrincipale => 'Residencia principal';

  @override
  String get housingSaleFinancementTitle => 'FINANCIACIÓN';

  @override
  String get housingSaleFinancementSubtitle => 'Hipoteca restante';

  @override
  String get housingSaleHypotheque => 'Hipoteca restante';

  @override
  String get housingSaleEplTitle => 'EPL — PREVISIÓN UTILIZADA';

  @override
  String get housingSaleEplSubtitle => 'LPP y 3a utilizados para la compra';

  @override
  String get housingSaleEplLpp => 'EPL LPP utilizado';

  @override
  String get housingSaleEpl3a => 'EPL 3a utilizado';

  @override
  String get housingSaleRemploiTitle => 'REINVERSIÓN';

  @override
  String get housingSaleRemploiSubtitle =>
      'Proyecto de compra de un nuevo bien';

  @override
  String get housingSaleProjetRemploi => 'Proyecto de reinversión (recompra)';

  @override
  String get housingSalePrixNouveauBien => 'Precio del nuevo bien';

  @override
  String get housingSalePlusValueTitle => 'PLUSVALÍA INMOBILIARIA';

  @override
  String get housingSalePlusValueBrute => 'Plusvalía bruta';

  @override
  String get housingSalePlusValueImposable => 'Plusvalía imponible';

  @override
  String get housingSaleDureeDetention => 'Duración de tenencia';

  @override
  String housingSaleYearsCount(int count) {
    return '$count años';
  }

  @override
  String housingSaleImpotGainsCanton(String canton) {
    return 'IMPUESTO SOBRE GANANCIAS ($canton)';
  }

  @override
  String get housingSaleTauxImposition => 'Tasa impositiva';

  @override
  String get housingSaleImpotGains => 'Impuesto sobre ganancias';

  @override
  String get housingSaleReportRemploi => 'Aplazamiento (reinversión)';

  @override
  String get housingSaleImpotEffectif => 'Impuesto efectivo';

  @override
  String get housingSaleReportTitle => 'APLAZAMIENTO FISCAL (REINVERSIÓN)';

  @override
  String get housingSaleReportDesc =>
      'de plusvalía diferida (no gravada ahora)';

  @override
  String get housingSaleReportNote =>
      'El aplazamiento se integrará en la reventa del nuevo bien (LHID art. 12 al. 3).';

  @override
  String get housingSaleEplRepaymentTitle => 'REEMBOLSO EPL';

  @override
  String get housingSaleRemboursementLpp => 'Reembolso LPP';

  @override
  String get housingSaleRemboursement3a => 'Reembolso 3a';

  @override
  String get housingSaleEplNote =>
      'Obligación legal: los fondos de previsión utilizados para la compra deben reembolsarse al vender la residencia principal (LPP art. 30d).';

  @override
  String get housingSaleProduitNetTitle => 'PRODUCTO NETO DE LA VENTA';

  @override
  String get housingSaleImpotPlusValue => 'Impuesto plusvalía';

  @override
  String get housingSaleRemboursementEplLpp => 'Reembolso EPL LPP';

  @override
  String get housingSaleRemboursementEpl3a => 'Reembolso EPL 3a';

  @override
  String get housingSaleEduImpotTitle =>
      '¿Cómo funciona el impuesto sobre las ganancias inmobiliarias?';

  @override
  String get housingSaleEduImpotBody =>
      'En Suiza, toda ganancia de la venta de una propiedad está sujeta a un impuesto cantonal específico (LHID art. 12). La tasa disminuye con la duración de tenencia. Después de 20-25 años según el cantón, la ganancia puede estar total o parcialmente exenta. Las inversiones valorizantes y los gastos de adquisición son deducibles.';

  @override
  String get housingSaleEduRemploiTitle => '¿Qué es la reinversión?';

  @override
  String get housingSaleEduRemploiBody =>
      'La reinversión permite aplazar la imposición de la plusvalía si compras una nueva residencia principal en un plazo razonable (generalmente 2 años). Si el nuevo bien cuesta igual o más, el aplazamiento es total. De lo contrario, es proporcional. El impuesto se deberá al revender el nuevo bien.';

  @override
  String get housingSaleEduEplTitle => 'EPL: ¿qué pasa en la venta?';

  @override
  String get housingSaleEduEplBody =>
      'Si utilizaste fondos de previsión (EPL) para la compra de tu residencia principal, debes reembolsarlos al vender (LPP art. 30d). Este reembolso es obligatorio y se realiza a tu fondo de pensiones (LPP) y/o tu fundación 3a. El monto está inscrito en el registro de la propiedad y no puede evitarse.';

  @override
  String get housingSaleDisclaimer =>
      'Esta herramienta educativa proporciona estimaciones indicativas y no constituye asesoramiento fiscal, jurídico o inmobiliario personalizado en el sentido de la LSFin. Consulta a un especialista para tu situación personal.';

  @override
  String get housingSaleCanton => 'Cantón';

  @override
  String get jobCompareDeltaLabel => 'Delta';

  @override
  String jobCompareRetirementBody(
      String betterJob, String annualDelta, String monthlyDelta) {
    return '$betterJob vale $annualDelta/año más en renta vitalicia, es decir $monthlyDelta/mes DE POR VIDA tras la jubilación.';
  }

  @override
  String jobCompareLifetime20Years(String amount) {
    return 'En 20 años de jubilación: $amount';
  }

  @override
  String jobCompareAxesFavorable(String favorable, String total) {
    return '$favorable ejes favorables de $total';
  }

  @override
  String get jobCompareCurrentJobWidget => 'Empleo actual';

  @override
  String get jobCompareNewJobWidget => 'Empleo previsto';

  @override
  String get jobCompareAxisSalary => 'Salario bruto';

  @override
  String get jobCompareAxisLpp => 'Cotización LPP';

  @override
  String get jobCompareAxisDistance => 'Distancia';

  @override
  String get jobCompareAxisVacation => 'Vacaciones';

  @override
  String get jobCompareAxisWeeklyHours => 'Horas semanales';

  @override
  String get jobCompareChecklistSub => 'Lista de verificación';

  @override
  String get independantJourJTitle => 'El Día D — El gran cambio';

  @override
  String get independantJourJSubtitle =>
      'Lo que cambia en 1 día cuando te haces autónomo/a';

  @override
  String get independantJourJEmployee => 'Asalariado/a';

  @override
  String get independantJourJSelfEmployed => 'Autónomo/a';

  @override
  String independantJourJChiffreChoc(String amount) {
    return 'Pierdes ~$amount/mes de protección invisible.\nNo dejaste un empleo. Dejaste un sistema de protección.';
  }

  @override
  String independantAvsBody(String amount) {
    return 'Tu cotización AVS estimada: $amount/año (tasa decreciente para ingresos inferiores a CHF 58’800, luego ~10.6% por encima).';
  }

  @override
  String get independantAvsSource =>
      'Fuente: LAVS art. 8 / Tablas de cotización AVS';

  @override
  String get independant3aWithLpp =>
      'Con LPP voluntaria: techo 3a estándar de CHF 7’258/año.';

  @override
  String independant3aWithoutLpp(String amount) {
    return 'Sin LPP: techo 3a \"grande\" del 20% del ingreso neto, máx. $amount/año (techo legal CHF 36’288).';
  }

  @override
  String get independant3aSource => 'Fuente: OPP3 art. 7';

  @override
  String get independantPerMonth => '/mes';

  @override
  String get independantPerYear => '/ año';

  @override
  String get independantCostAvs => 'AVS / AI / APG';

  @override
  String get independantCostIjm => 'IJM (estimación)';

  @override
  String get independantCostLaa => 'LAA (estimación)';

  @override
  String get independantCost3a => 'Pilar 3a (máx.)';

  @override
  String disabilityGapSeniorityYears(String years) {
    return '$years años';
  }

  @override
  String disabilityGapPhase1Duration(String weeks) {
    return '$weeks semanas';
  }

  @override
  String get disabilityGapPhase1Full => '100% del salario';

  @override
  String get disabilityGapNoCoverage => 'Sin cobertura';

  @override
  String get disabilityGapNone => 'Ninguna';

  @override
  String get disabilityGapPhase2Duration => 'Hasta 24 meses';

  @override
  String disabilityGapPhase2Coverage(String amount) {
    return '80% del salario ($amount CHF/mes)';
  }

  @override
  String get disabilityGapCollectiveInsurance => 'Seguro colectivo';

  @override
  String get disabilityGapNotSubscribed => 'No suscrito';

  @override
  String get disabilityGapPhase3Duration => 'Después de 24 meses';

  @override
  String get disabilityGapActionSelfIjm => 'Suscribe un IJM individual';

  @override
  String get disabilityGapActionSelfIjmSub =>
      'Prioridad absoluta para autónomos';

  @override
  String get disabilityGapActionCheckHr =>
      'Verifica con tu RRHH tu cobertura de enfermedad';

  @override
  String get disabilityGapActionCheckHrSub =>
      'Pregunta si existe un IJM colectivo';

  @override
  String get disabilityGapActionConditions =>
      'Pide las condiciones exactas de tu IJM';

  @override
  String get disabilityGapActionConditionsSub =>
      'Plazo de espera, duración, tasa de cobertura';

  @override
  String get successionMarried => 'Casado/a';

  @override
  String get successionSingle => 'Soltero/a';

  @override
  String get successionDivorced => 'Divorciado/a';

  @override
  String get successionWidowed => 'Viudo/a';

  @override
  String get successionConcubinage => 'Concubinato';

  @override
  String get successionConjoint => 'Cónyuge';

  @override
  String get successionChildren => 'Hijos';

  @override
  String get successionThirdParty => 'Terceros / Obra';

  @override
  String get successionQuotiteFreedom =>
      'Este monto puede ser libremente asignado por testamento a la persona de tu elección.';

  @override
  String get successionFiscalTitle => 'FISCALIDAD SUCESORIA';

  @override
  String get successionExempt => 'Exento';

  @override
  String get successionEduQuotiteTitle => '¿Qué es la cuota disponible?';

  @override
  String get successionEdu3aTitle => 'El 3a y la sucesión: ¡atención!';

  @override
  String get successionEduConcubinTitle => 'Los concubinos y la sucesión';

  @override
  String get successionCantonLabel => 'Cantón';

  @override
  String get debtCheckTitle => 'Chequeo de Salud Financiera';

  @override
  String get debtCheckExportTooltip => 'Exportar mi informe';

  @override
  String get debtCheckSectionDaily => 'Gestión diaria';

  @override
  String get debtCheckOverdraftQuestion =>
      '¿Estás regularmente en descubierto?';

  @override
  String get debtCheckOverdraftSub =>
      'Tu cuenta se pone en negativo antes de fin de mes.';

  @override
  String get debtCheckMultipleCreditsQuestion =>
      '¿Tienes varios créditos en curso?';

  @override
  String get debtCheckMultipleCreditsSub =>
      'Leasing, préstamos, créditos pequeños, tarjetas de crédito...';

  @override
  String get debtCheckSectionObligations => 'Obligaciones';

  @override
  String get debtCheckLatePaymentsQuestion => '¿Tienes pagos atrasados?';

  @override
  String get debtCheckLatePaymentsSub =>
      'Facturas, impuestos o alquileres pagados con retraso.';

  @override
  String get debtCheckCollectionQuestion => '¿Has recibido embargos?';

  @override
  String get debtCheckCollectionSub => 'Mandamientos de pago o embargos.';

  @override
  String get debtCheckSectionBehaviors => 'Comportamientos';

  @override
  String get debtCheckImpulsiveQuestion => '¿Compras impulsivas frecuentes?';

  @override
  String get debtCheckImpulsiveSub => 'Gastos no planificados que lamentas.';

  @override
  String get debtCheckGamblingQuestion => '¿Apuestas dinero regularmente?';

  @override
  String get debtCheckGamblingSub =>
      'Casinos, apuestas deportivas o loterías frecuentes.';

  @override
  String get debtCheckAnalyzeButton => 'Analizar mi situación';

  @override
  String get debtCheckMentorTitle => 'Palabra del Mentor';

  @override
  String get debtCheckMentorBody =>
      'Este chequeo de 60 segundos nos permite detectar señales de alerta antes de que se vuelvan críticas.';

  @override
  String get debtCheckYes => 'SÍ';

  @override
  String get debtCheckNo => 'NO';

  @override
  String get debtCheckRiskLow => 'Riesgo Controlado';

  @override
  String get debtCheckRiskMedium => 'Puntos de Atención';

  @override
  String get debtCheckRiskHigh => 'Alerta Crítica';

  @override
  String get debtCheckRiskUnknown => 'Indeterminado';

  @override
  String debtCheckFactorsDetected(int count) {
    return '$count factor(es) detectado(s)';
  }

  @override
  String get debtCheckRecommendationsTitle => 'RECOMENDACIONES DEL MENTOR';

  @override
  String get debtCheckValidateButton => 'Validar mi chequeo';

  @override
  String get debtCheckRedoButton => 'Repetir el chequeo';

  @override
  String get debtCheckHonestyQuote =>
      'La honestidad con uno mismo es el primer paso hacia la serenidad.';

  @override
  String get debtCheckGamblingSupportTitle => 'Apoyo para Juegos y Apuestas';

  @override
  String get debtCheckGamblingSupportBody =>
      'Hay apoyo profesional y anónimo disponible de forma gratuita.';

  @override
  String get debtCheckGamblingSupportCta => 'SOS Juego - Ayuda en línea';

  @override
  String get debtCheckPrivacyNote =>
      'Mint respeta tu privacidad. Ningún dato se almacena ni se transmite.';

  @override
  String scoreRevealGreeting(String name) {
    return 'Aquí está tu puntuación, $name.';
  }

  @override
  String get scoreRevealTitle => 'Tu diagnóstico\nestá listo.';

  @override
  String get scoreRevealBudget => 'Presupuesto';

  @override
  String get scoreRevealPrevoyance => 'Previsión';

  @override
  String get scoreRevealPatrimoine => 'Patrimonio';

  @override
  String get scoreRevealLevelExcellent => 'Excelente';

  @override
  String get scoreRevealLevelGood => 'Bueno';

  @override
  String get scoreRevealLevelWarning => 'Atención';

  @override
  String get scoreRevealLevelCritical => 'Crítico';

  @override
  String get scoreRevealCoachLabel => 'TU COACH';

  @override
  String get scoreRevealCtaDashboard => 'Ver mi panel';

  @override
  String get scoreRevealCtaReport => 'Ver informe detallado';

  @override
  String get scoreRevealDisclaimer =>
      'Herramienta educativa — no constituye asesoramiento financiero (LSFin).';

  @override
  String get affordabilityTitle => 'Capacidad de compra';

  @override
  String get affordabilitySource =>
      'Fuente: directiva ASB sobre crédito hipotecario, práctica bancaria suiza.';

  @override
  String get affordabilityIndicators => 'Indicadores';

  @override
  String get affordabilityChargesRatio => 'Ratio gastos / ingresos';

  @override
  String get affordabilityEquityRatio => 'Capital propio / precio';

  @override
  String get affordabilityOk => 'OK';

  @override
  String get affordabilityExceeded => 'Excedido';

  @override
  String get affordabilityParameters => 'Tus hipótesis';

  @override
  String get affordabilityCanton => 'Cantón';

  @override
  String get affordabilityGrossIncome => 'Ingreso bruto anual';

  @override
  String get affordabilityTargetPrice => 'Precio de compra objetivo';

  @override
  String get affordabilityAvailableSavings => 'Ahorro disponible';

  @override
  String get affordabilityPillar3a => 'Activos pilar 3a';

  @override
  String get affordabilityPillarLpp => 'Activos LPP';

  @override
  String get affordabilityCalculationDetail => 'Detalle del cálculo';

  @override
  String get affordabilityEquityRequired => 'Capital propio requerido (20%)';

  @override
  String get affordabilitySavingsLabel => 'Ahorro';

  @override
  String get affordabilityLppMax10 => 'Activos LPP (máx 10% del precio)';

  @override
  String get affordabilityTotalEquity => 'Capital propio total';

  @override
  String affordabilityMortgagePercent(String percent) {
    return 'Hipoteca ($percent%)';
  }

  @override
  String get affordabilityMonthlyCharges => 'Gastos mensuales teóricos';

  @override
  String get affordabilityCalculationNote =>
      'Cálculo teórico: hipoteca x (5% interés imputado + 1% amortización) + precio x 1% gastos accesorios. Máx 33% del ingreso bruto.';

  @override
  String get amortizationSource =>
      'Fuente: OPP3 (pilar 3a), práctica hipotecaria suiza. Tope 3a asalariado 2026: CHF 7\'258.';

  @override
  String get amortizationIntroTitle => 'Amortización: ¿directa o indirecta?';

  @override
  String get amortizationIntroBody =>
      'En Suiza, la amortización indirecta es una particularidad única: en lugar de reembolsar directamente la deuda, aportas a un pilar 3a pignorado. Te beneficias de una doble deducción fiscal (intereses + aportación 3a) y tu capital permanece invertido.';

  @override
  String get amortizationDirect => 'Directa';

  @override
  String get amortizationDirectDesc =>
      'Reembolsas la deuda cada año. Los intereses disminuyen progresivamente.';

  @override
  String get amortizationIndirect => 'Indirecta';

  @override
  String get amortizationIndirectDesc =>
      'Aportas a un 3a pignorado. Doble deducción fiscal.';

  @override
  String amortizationEvolutionTitle(int years) {
    return 'Evolución en $years años';
  }

  @override
  String get amortizationLegendDebtDirect => 'Deuda (directa)';

  @override
  String get amortizationLegendDebtIndirect => 'Deuda (indirecta)';

  @override
  String get amortizationLegendCapital3a => 'Capital 3a';

  @override
  String get amortizationParameters => 'Parámetros';

  @override
  String get amortizationMortgageAmount => 'Monto hipotecario';

  @override
  String get amortizationInterestRate => 'Tasa de interés';

  @override
  String get amortizationDuration => 'Duración';

  @override
  String get amortizationMarginalRate => 'Tasa marginal estimada';

  @override
  String get amortizationDetailedComparison => 'Comparación detallada';

  @override
  String get amortizationDirectTitle => 'Amortización directa';

  @override
  String get amortizationTotalInterest => 'Total intereses pagados';

  @override
  String get amortizationNetCost => 'Costo neto total';

  @override
  String get amortizationIndirectTitle => 'Amortización indirecta';

  @override
  String get amortizationCapital3aAccumulated => 'Capital 3a acumulado';

  @override
  String get fiscalComparatorTitle => 'Comparador fiscal';

  @override
  String get fiscalTabMyTax => 'Mi impuesto';

  @override
  String get fiscalTab26Cantons => '26 cantones';

  @override
  String get fiscalTabMove => 'Mudanza';

  @override
  String get fiscalGrossAnnualIncome => 'Ingreso bruto anual';

  @override
  String get fiscalCanton => 'Cantón';

  @override
  String get fiscalCivilStatus => 'Estado civil';

  @override
  String get fiscalSingle => 'Soltero/a';

  @override
  String get fiscalMarried => 'Casado/a';

  @override
  String get fiscalChildren => 'Hijos';

  @override
  String get fiscalNetWealth => 'Patrimonio neto';

  @override
  String get fiscalChurchMember => 'Miembro de una iglesia';

  @override
  String get fiscalChurchTax => 'Impuesto eclesiástico';

  @override
  String get fiscalEffectiveRate => 'Tasa efectiva estimada';

  @override
  String fiscalBelowAverage(String rate) {
    return 'Inferior al promedio suizo (~$rate%)';
  }

  @override
  String fiscalAboveAverage(String rate) {
    return 'Superior al promedio suizo (~$rate%)';
  }

  @override
  String get fiscalBreakdownTitle => 'DESGLOSE FISCAL';

  @override
  String get fiscalFederalTax => 'Impuesto federal';

  @override
  String get fiscalCantonalCommunalTax => 'Impuesto cantonal + comunal';

  @override
  String get fiscalWealthTax => 'Impuesto sobre el patrimonio';

  @override
  String get fiscalTotalBurden => 'Carga fiscal total';

  @override
  String get fiscalNationalPosition => 'POSICIÓN NACIONAL';

  @override
  String get fiscalRanks => 'se clasifica';

  @override
  String get fiscalCantons => 'cantones';

  @override
  String get fiscalCheapest => 'El más barato';

  @override
  String get fiscalMostExpensive => 'El más caro';

  @override
  String get fiscalGapBetweenCantons =>
      'diferencia entre el cantón más barato y el más caro';

  @override
  String get fiscalMoveIntro =>
      'Simula el impacto fiscal de una mudanza entre dos cantones. Los parámetros de ingresos y situación familiar se comparten con la pestaña \"Mi impuesto\".';

  @override
  String get fiscalCurrentCanton => 'Cantón actual';

  @override
  String get fiscalDestinationCanton => 'Cantón de destino';

  @override
  String get fiscalIncomeTaxLabel => 'Impuesto sobre la renta';

  @override
  String get fiscalEstimateNote => 'Estimado según tarifa cantonal';

  @override
  String get fiscalEstimatedRent => 'Alquiler estimado';

  @override
  String get fiscalRentNote => 'Varía según municipio y superficie';

  @override
  String get fiscalMovingCosts => 'Costes de mudanza';

  @override
  String get fiscalMovingCostsNote => 'Amortizado en 24 meses';

  @override
  String get fiscalWealthTaxTitle => 'IMPUESTO SOBRE EL PATRIMONIO';

  @override
  String fiscalNetWealthAmount(String amount) {
    return 'Patrimonio neto: $amount';
  }

  @override
  String fiscalWealthSaving(String amount) {
    return 'Ahorro patrimonio: $amount/año';
  }

  @override
  String fiscalWealthSurcharge(String amount) {
    return 'Recargo patrimonio: $amount/año';
  }

  @override
  String get fiscalWealthEquivalent => 'Impuesto patrimonial equivalente';

  @override
  String get fiscalChecklist1 => 'Declarar tu partida en tu municipio actual';

  @override
  String get fiscalChecklist2 => 'Registrarte en el nuevo municipio en 14 días';

  @override
  String get fiscalChecklist3 =>
      'Actualizar la dirección en tu seguro de salud';

  @override
  String get fiscalChecklist4 =>
      'Adaptar la declaración de impuestos (prorata temporis)';

  @override
  String get fiscalChecklist5 => 'Verificar subsidios LAMal en el nuevo cantón';

  @override
  String get fiscalChecklist6 =>
      'Transferir registros (vehículo, escuelas, etc.)';

  @override
  String get fiscalChecklistTitle => 'CHECKLIST DE MUDANZA';

  @override
  String get fiscalGoodToKnow => 'BUENO SABERLO';

  @override
  String get fiscalEduDateTitle => 'Fecha de referencia: 31 de diciembre';

  @override
  String get fiscalEduDateBody =>
      'Se te cobra impuestos en el cantón donde residías el 31 de diciembre del año fiscal. ¡Una mudanza el 30 de diciembre cuenta para todo el año!';

  @override
  String get fiscalEduProrataTitle => 'Prorata temporis';

  @override
  String get fiscalEduProrataBody =>
      'El impuesto federal es siempre el mismo. Solo cambian los impuestos cantonales y comunales. El prorrateo se aplica en el año de la mudanza.';

  @override
  String get fiscalEduRentTitle => 'Alquileres y costo de vida';

  @override
  String get fiscalEduRentBody =>
      'No olvides que los ahorros fiscales pueden compensarse con diferencias de alquiler y costo de vida. Compara el presupuesto global, no solo los impuestos.';

  @override
  String get fiscalCommune => 'Municipio';

  @override
  String get fiscalCapitalDefault => 'Capital (por defecto)';

  @override
  String get fiscalDisclaimer =>
      'Estimaciones simplificadas con fines educativos — no constituye asesoramiento fiscal. Las tasas efectivas dependen de muchos factores (deducciones, patrimonio, municipio, etc.). Consulta a un especialista fiscal para un cálculo personalizado.';

  @override
  String get expatTitle => 'Expatriación';

  @override
  String get expatTabForfait => 'Forfait';

  @override
  String get expatTabDeparture => 'Partida';

  @override
  String get expatTabAvs => 'AVS';

  @override
  String get expatForfaitEducation =>
      'El forfait fiscal (imposición según el gasto) permite a las personas de nacionalidad extranjera no ser gravadas sobre su renta mundial, sino sobre la base de sus gastos de vida. Aproximadamente 5\'000 personas se benefician de ello en Suiza.';

  @override
  String get expatHighlightSchwyz => 'Fiscalidad más ventajosa de Suiza';

  @override
  String get expatHighlightZug => 'Hub internacional, acceso a Zúrich';

  @override
  String get expatCanton => 'Cantón';

  @override
  String get expatLivingExpenses => 'Gastos de vida anuales';

  @override
  String get expatActualIncome => 'Ingreso real anual';

  @override
  String get expatTaxComparison => 'COMPARACIÓN FISCAL';

  @override
  String get expatForfaitFiscal => 'Forfait fiscal';

  @override
  String get expatOrdinaryTaxation => 'Imposición ordinaria';

  @override
  String get expatOnActualIncome => 'Sobre ingreso real';

  @override
  String get expatAbolishedCantons => 'Cantones que abolieron el forfait';

  @override
  String expatAbolishedNote(String names) {
    return '$names — el forfait fiscal ya no está disponible en estos cantones.';
  }

  @override
  String get expatDepartureDate => 'Fecha de partida';

  @override
  String get expatCurrentCanton => 'Cantón actual';

  @override
  String get expatPillar3aBalance => 'Saldo pilar 3a';

  @override
  String get expatLppBalance => 'Saldo LPP (activos de jubilación)';

  @override
  String get expatNoExitTax => 'Sin impuesto de salida en Suiza';

  @override
  String get expatRecommendedTimeline => 'CRONOLOGÍA RECOMENDADA';

  @override
  String get expatDepartureChecklist => 'CHECKLIST DE PARTIDA';

  @override
  String get expatAvsEducation =>
      'Para recibir una pensión AVS completa (máx CHF 2\'520/mes), se necesitan 44 años de cotización sin lagunas. Cada año faltante reduce la pensión en aproximadamente un 2.3%. Si vives en el extranjero, puedes cotizar voluntariamente al AVS para evitar lagunas.';

  @override
  String get expatYearsInSwitzerland => 'Años en Suiza';

  @override
  String get expatYearsAbroad => 'Años en el extranjero';

  @override
  String get expatAvsCompleteness => 'COMPLETITUD AVS';

  @override
  String get expatOfPension => 'de pensión';

  @override
  String get expatEstimatedPension => 'Pensión estimada';

  @override
  String get expatAvsComplete =>
      'Confirmado: tienes tus 44 años completos de cotización. Tu pensión AVS no debería reducirse.';

  @override
  String get expatPensionImpact => 'IMPACTO EN TU PENSIÓN';

  @override
  String get expatMissingYears => 'Años faltantes';

  @override
  String get expatEstimatedReduction => 'Reducción estimada';

  @override
  String get expatMonthlyLoss => 'Pérdida mensual';

  @override
  String get expatAnnualLoss => 'Pérdida anual';

  @override
  String get expatVoluntaryContribution => 'COTIZACIÓN VOLUNTARIA';

  @override
  String get expatVoluntaryAvsTitle => 'AVS voluntario desde el extranjero';

  @override
  String get expatMinContribution => 'Cotización mínima';

  @override
  String get expatMaxContribution => 'Cotización máxima';

  @override
  String get expatVoluntaryAvsBody =>
      'Puedes cotizar voluntariamente al AVS si vives en el extranjero. Plazo de inscripción: 1 año después de salir de Suiza. Condición: haber cotizado al menos 5 años consecutivos antes de la partida.';

  @override
  String get expatRecommendation => 'RECOMENDADA';

  @override
  String get expatDidYouKnow => '¿Sabías que?';

  @override
  String get mariageTimelinePartner1 => 'Persona 1';

  @override
  String get mariageTimelinePartner2 => 'Persona 2';

  @override
  String get mariageTimelineCoachTip =>
      'Cada fase de la vida requiere adaptar tu contrato matrimonial y tu previsión.';

  @override
  String get mariageTimelineAct1Title => 'Ambos trabajáis';

  @override
  String get mariageTimelineAct1Period => '0-10 años de vida en común';

  @override
  String get mariageTimelineAct1Insight =>
      'Fase de construcción: 3a, LPP, ahorro conjunto. Aprovechad los dos ingresos.';

  @override
  String get mariageTimelineAct2Title => 'Fase de ahorro intensivo';

  @override
  String get mariageTimelineAct2Period => '10-25 años';

  @override
  String get mariageTimelineAct2Insight =>
      'Rescate LPP, 3a máximo, preparación jubilación. Vuestro capital se duplica.';

  @override
  String get mariageTimelineAct3Title => 'Jubilación en pareja';

  @override
  String get mariageTimelineAct3Period => '25+ años';

  @override
  String get mariageTimelineAct3Insight =>
      'Atención: tope AVS pareja (150% renta máxima). Planificar renta vs capital.';

  @override
  String get naissanceChecklistItem1Title =>
      'Inscribir al bebé en el seguro de salud (3 meses)';

  @override
  String get naissanceChecklistItem1Desc =>
      'Tienes 3 meses tras el nacimiento para inscribir a tu hijo en una aseguradora. Si lo haces en ese plazo, la cobertura es retroactiva desde el nacimiento. Pasado ese plazo, hay riesgo de interrupción de cobertura. Compara las primas infantiles entre aseguradoras — las diferencias pueden ser significativas.';

  @override
  String get naissanceChecklistItem2Title =>
      'Solicitar las asignaciones familiares';

  @override
  String get naissanceChecklistItem2Desc =>
      'Solicítalo a través de tu empleador (o de tu caja de asignaciones si eres autónomo/a). Las asignaciones se pagan desde el mes de nacimiento. El importe depende del cantón (CHF 200 a CHF 305/mes por hijo).';

  @override
  String get naissanceChecklistItem3Title =>
      'Declarar el nacimiento en el registro civil';

  @override
  String get naissanceChecklistItem3Desc =>
      'El hospital generalmente transmite el aviso al registro civil. Verifica que el acta de nacimiento esté correctamente emitida. La necesitarás para todos los trámites administrativos.';

  @override
  String get naissanceChecklistItem4Title =>
      'Organizar el permiso parental (APG)';

  @override
  String get naissanceChecklistItem4Desc =>
      'Permiso de maternidad: 14 semanas al 80% del salario (máx. CHF 220/día). Permiso de paternidad: 2 semanas (10 días), a tomar en 6 meses. La inscripción APG se hace a través del empleador o directamente en la caja de compensación.';

  @override
  String get naissanceChecklistItem5Title => 'Actualizar la declaración fiscal';

  @override
  String get naissanceChecklistItem5Desc =>
      'Un hijo adicional te da derecho a una deducción fiscal de CHF 6\'700/año (LIFD art. 35). Si tienes gastos de guardería, puedes deducir hasta CHF 25\'500/año. Recuerda adaptar tus pagos anticipados de impuestos para el año en curso.';

  @override
  String get naissanceChecklistItem6Title => 'Adaptar el presupuesto familiar';

  @override
  String get naissanceChecklistItem6Desc =>
      'Un hijo cuesta en promedio CHF 1\'200 a CHF 1\'500/mes en Suiza (alimentación, ropa, actividades, seguro, pañales, etc.). Reevalúa tu presupuesto con el módulo Presupuesto de MINT.';

  @override
  String get naissanceChecklistItem7Title =>
      'Verificar la previsión (LPP y 3a)';

  @override
  String get naissanceChecklistItem7Desc =>
      'Si reduces tu jornada laboral, tus cotizaciones LPP disminuyen. Cada año a tiempo parcial significa menos capital en la jubilación. Considera compensar contribuyendo el máximo al 3er pilar (CHF 7\'258/año).';

  @override
  String get naissanceChecklistItem8Title =>
      'Redactar o actualizar el testamento';

  @override
  String get naissanceChecklistItem8Desc =>
      'La llegada de un hijo modifica el orden sucesorio. Los hijos son herederos forzosos (CC art. 471). Si tienes un testamento, verifica que respete las reservas legales.';

  @override
  String get naissanceChecklistItem9Title =>
      'Contratar un seguro de riesgo de fallecimiento/invalidez';

  @override
  String get naissanceChecklistItem9Desc =>
      'Con un hijo a cargo, la protección financiera en caso de fallecimiento o invalidez se vuelve aún más importante. Verifica tu cobertura actual (LPP, seguro de vida) y completa si es necesario.';

  @override
  String get naissanceBabyCostCreche => 'Guardería / cuidado';

  @override
  String get naissanceBabyCostCrecheNote =>
      'Tarifa media subvencionada — varía mucho según el cantón';

  @override
  String get naissanceBabyCostAlimentation => 'Alimentación';

  @override
  String get naissanceBabyCostVetements => 'Ropa y equipamiento';

  @override
  String get naissanceBabyCostLamal => 'Seguro de salud infantil';

  @override
  String get naissanceBabyCostLamalNote =>
      'Prima media infantil — sin franquicia hasta los 18 años';

  @override
  String get naissanceBabyCostActivites => 'Actividades y ocio';

  @override
  String get naissanceBabyCostDivers => 'Diversos (juguetes, higiene…)';

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
      'Projection éducative — ne constitue pas un conseil (LSFin). SWR 4% = règle des 4%, résultats non assurés. Rentes AVS/LPP estimées selon LAVS art. 21-40, LPP art. 14-16.';

  @override
  String get futurExplorerDetails => 'Explorer les détails';

  @override
  String get financialSummaryTitle => 'RESUMEN FINANCIERO';

  @override
  String get financialSummaryNoProfile => 'Ningún perfil registrado';

  @override
  String get financialSummaryStartDiagnostic => 'Comenzar el diagnóstico';

  @override
  String get financialSummaryRestartDiagnostic => 'Reiniciar el diagnóstico';

  @override
  String get financialSummaryNarrativeFiscalite =>
      'La optimización fiscal es tu primera palanca: 3a, rescate LPP, deducciones.';

  @override
  String get financialSummaryNarrativePrevoyance =>
      'Tu previsión determina tu comodidad en la jubilación. Cada año cuenta.';

  @override
  String get financialSummaryNarrativeAvs =>
      'El AVS es la base de tu jubilación. Verifica tus lagunas de cotización.';

  @override
  String get financialSummaryLegendSaisi => 'Ingresado';

  @override
  String get financialSummaryLegendEstime => 'Estimado';

  @override
  String get financialSummaryLegendCertifie => 'Certificado';

  @override
  String get financialSummarySalaireBrutMensuel => 'Salario bruto mensual';

  @override
  String get financialSummary13emeSalaire => '13.º salario';

  @override
  String financialSummaryNemeMois(String n) {
    return '$n.º mes';
  }

  @override
  String financialSummaryBonusEstime(String pct) {
    return 'Bonus estimado ($pct%)';
  }

  @override
  String financialSummaryConjointBrutMensuel(String name) {
    return '$name — bruto mensual';
  }

  @override
  String get financialSummaryDefaultConjoint => 'Cónyuge';

  @override
  String get financialSummaryRevenuBrutAnnuel => 'Ingreso bruto anual';

  @override
  String get financialSummaryRevenuBrutAnnuelCouple =>
      'Ingreso bruto anual (pareja)';

  @override
  String get financialSummarySoitLisseSur12Mois => 'distribuido en 12 meses';

  @override
  String get financialSummaryDeductionsSalariales => 'Deducciones salariales';

  @override
  String get financialSummaryChargesSociales => 'Cargas sociales (AVS/AI/AC)';

  @override
  String get financialSummaryCotisationLpp => 'Cotización LPP empleado·a';

  @override
  String get financialSummaryNetFicheDePaie => 'Neto nómina';

  @override
  String get financialSummaryNetFicheDePaieHint =>
      'Lo que llega a tu cuenta cada mes';

  @override
  String get financialSummaryFiscalite => 'Fiscalidad';

  @override
  String get financialSummaryImpotEstime => 'Impuesto estimado (ICC + IFD)';

  @override
  String get financialSummaryTauxMarginalEstime => 'Tasa marginal estimada';

  @override
  String financialSummary13emeEtBonusHint(String label, String montant) {
    return '$label: ~$montant neto/año (no incluido en el mensual)';
  }

  @override
  String get financialSummaryRevenusEtFiscalite => 'Ingresos y Fiscalidad';

  @override
  String get financialSummaryDisponibleApresImpot =>
      'Disponible después de impuestos';

  @override
  String get financialSummaryFootnoteRevenus =>
      'Estimación simplificada. La AANP y la IJM varían según el empleador y no están incluidas. La LPP empleado refleja el mínimo legal (50/50) — tu caja puede aplicar otro reparto.';

  @override
  String get financialSummaryScanFicheSalaire => 'Escanear mi nómina';

  @override
  String get financialSummaryModifierRevenu => 'Modificar ingresos';

  @override
  String get financialSummaryEditSalaireBrut => 'Salario bruto mensual (CHF)';

  @override
  String get financialSummaryAvs1erPilier => 'AVS (1er pilar)';

  @override
  String get financialSummaryAnneesCotisees => 'Años cotizados';

  @override
  String financialSummaryAnneesUnit(String n) {
    return '$n años';
  }

  @override
  String get financialSummaryLacunes => 'Lagunas';

  @override
  String get financialSummaryRenteEstimee => 'Renta estimada';

  @override
  String get financialSummaryLpp2ePilier => 'LPP (2.º pilar)';

  @override
  String get financialSummaryAvoirTotal => 'Activos totales';

  @override
  String get financialSummaryObligatoire => 'Obligatorio';

  @override
  String get financialSummarySurobligatoire => 'Supraobligatorio';

  @override
  String get financialSummaryTauxConversion => 'Tasa de conversión';

  @override
  String get financialSummaryRachatPossible => 'Rescate posible';

  @override
  String get financialSummaryRachatPlanifie => 'Rescate planificado';

  @override
  String get financialSummaryCaisse => 'Caja';

  @override
  String get financialSummary3a3ePilier => '3a (3er pilar)';

  @override
  String financialSummaryNComptes(String n) {
    return '$n cuenta(s)';
  }

  @override
  String get financialSummaryLibrePassage => 'Libre paso';

  @override
  String financialSummaryCompteN(String n) {
    return 'Cuenta $n';
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
      '⚠️ FATCA — Solo una minoría de proveedores acepta (ej. Raiffeisen)';

  @override
  String get financialSummaryPrevoyanceTitle => 'Previsión';

  @override
  String get financialSummaryScanCertificatLpp =>
      'Escanear certificado LPP / AVS';

  @override
  String get financialSummaryModifierPrevoyance => 'Modificar previsión';

  @override
  String get financialSummaryEditAvoirLpp => 'Activos LPP totales (CHF)';

  @override
  String get financialSummaryEditNombre3a => 'Número de cuentas 3a';

  @override
  String get financialSummaryEditTotal3a => 'Ahorro total 3a (CHF)';

  @override
  String get financialSummaryEditRachatLpp =>
      'Rescate LPP mensual previsto (CHF/mes)';

  @override
  String get financialSummaryLiquidites => 'Liquidez';

  @override
  String get financialSummaryEpargneLiquide => 'Ahorro líquido';

  @override
  String get financialSummaryInvestissements => 'Inversiones';

  @override
  String get financialSummaryImmobilier => 'Inmobiliario';

  @override
  String get financialSummaryValeurEstimee => 'Valor estimado';

  @override
  String get financialSummaryHypothequeRestante => 'Hipoteca restante';

  @override
  String get financialSummaryValeurNetteImmobiliere =>
      'Valor neto inmobiliario';

  @override
  String financialSummaryLtvAmortissement(String pct) {
    return 'Ratio LTV: $pct% — amortización 2.º rango obligatoria';
  }

  @override
  String financialSummaryLtvBonneVoie(String pct) {
    return 'Ratio LTV: $pct% — buen camino';
  }

  @override
  String financialSummaryLtvExcellent(String pct) {
    return 'Ratio LTV: $pct% — excelente';
  }

  @override
  String get financialSummaryPrevoyanceCapital => 'Previsión (capital)';

  @override
  String get financialSummaryAvoirLppTotal => 'Activos LPP totales';

  @override
  String financialSummaryCapital3a(String n, String s) {
    return 'Capital 3a ($n cuenta$s)';
  }

  @override
  String get financialSummaryPatrimoineBrut => 'Patrimonio bruto';

  @override
  String get financialSummaryDettesTotales => 'Deudas totales';

  @override
  String get financialSummaryPatrimoine => 'Patrimonio';

  @override
  String get financialSummaryPatrimoineTotalBloque =>
      'Patrimonio total (incl. previsión bloqueada)';

  @override
  String get financialSummaryModifierPatrimoine => 'Modificar patrimonio';

  @override
  String get financialSummaryEditEpargneLiquide => 'Ahorro líquido (CHF)';

  @override
  String get financialSummaryEditInvestissements => 'Inversiones (CHF)';

  @override
  String get financialSummaryEditValeurImmobiliere =>
      'Valor inmobiliario (CHF)';

  @override
  String get financialSummaryLoyerCharges => 'Alquiler / cargos';

  @override
  String get financialSummaryAssuranceMaladie => 'Seguro médico';

  @override
  String get financialSummaryElectriciteEnergie => 'Electricidad / energía';

  @override
  String get financialSummaryTransport => 'Transporte';

  @override
  String get financialSummaryTelecom => 'Telecomunicaciones';

  @override
  String get financialSummaryFraisMedicaux => 'Gastos médicos';

  @override
  String get financialSummaryAutresFraisFixes => 'Otros gastos fijos';

  @override
  String get financialSummaryAucuneDepense => 'Ningún gasto registrado';

  @override
  String get financialSummaryDepensesFixes => 'Gastos fijos';

  @override
  String get financialSummaryTotalMensuel => 'Total mensual';

  @override
  String get financialSummaryModifierDepenses => 'Modificar gastos';

  @override
  String get financialSummaryEditLoyerCharges => 'Alquiler / cargos (CHF/mes)';

  @override
  String get financialSummaryEditAssuranceMaladie => 'Seguro médico (CHF/mes)';

  @override
  String get financialSummaryEditElectricite =>
      'Electricidad / energía (CHF/mes)';

  @override
  String get financialSummaryEditTransport => 'Transporte (CHF/mes)';

  @override
  String get financialSummaryEditTelecom => 'Telecomunicaciones (CHF/mes)';

  @override
  String get financialSummaryEditFraisMedicaux => 'Gastos médicos (CHF/mes)';

  @override
  String get financialSummaryEditAutresFraisFixes =>
      'Otros gastos fijos (CHF/mes)';

  @override
  String get financialSummaryModifierDettes => 'Modificar deudas';

  @override
  String get financialSummaryEditHypotheque => 'Hipoteca (CHF)';

  @override
  String get financialSummaryEditCreditConsommation =>
      'Crédito al consumo (CHF)';

  @override
  String get financialSummaryEditLeasing => 'Leasing (CHF)';

  @override
  String get financialSummaryEditAutresDettes => 'Otras deudas (CHF)';

  @override
  String get financialSummaryDettes => 'Deudas';

  @override
  String get financialSummaryAucuneDetteDeclaree =>
      'Ninguna deuda declarada — ';

  @override
  String get financialSummaryDetteStructurelle => 'Deuda estructural';

  @override
  String get financialSummaryHypotheque1erRang => 'Hipoteca 1er rango';

  @override
  String get financialSummaryHypotheque2emeRang => 'Hipoteca 2.º rango';

  @override
  String get financialSummaryHypotheque => 'Hipoteca';

  @override
  String get financialSummaryChargeMensuelle => 'Carga mensual';

  @override
  String financialSummaryEcheance(String date, String years) {
    return 'Vencimiento: $date (~$years años)';
  }

  @override
  String financialSummaryInteretsDeductibles(String montant) {
    return 'Intereses deducibles (LIFD art. 33): $montant/año';
  }

  @override
  String get financialSummaryDetteConsommation => 'Deuda de consumo';

  @override
  String get financialSummaryCreditConsommation => 'Crédito al consumo';

  @override
  String get financialSummaryMensualite => 'Mensualidad';

  @override
  String get financialSummaryLeasing => 'Leasing';

  @override
  String get financialSummaryAutresDettes => 'Otras deudas';

  @override
  String financialSummaryConseilRemboursement(String taux) {
    return 'Paga primero la deuda al $taux% antes de invertir. Cada CHF reembolsado = $taux% de rendimiento efectivo.';
  }

  @override
  String get financialSummaryTotalDettes => 'Deudas totales';

  @override
  String get financialSummaryScannerDocument => 'Escanear un documento';

  @override
  String get financialSummaryCascadeBudgetaire => 'Cascada presupuestaria';

  @override
  String get financialSummaryToi => 'Tú';

  @override
  String get financialSummaryConjointeDefault => 'Cónyuge';

  @override
  String get financialSummaryDisclaimer =>
      'Herramienta educativa — no constituye asesoramiento financiero (LSFin, LAVS, LPP, LIFD). Los valores estimados (~) se calculan a partir de promedios suizos. Escanea tus certificados para mejorar la precisión.';

  @override
  String get financialSummaryEnregistrer => 'Guardar';

  @override
  String get financialSummaryCheckSalaireBrut => 'Salario bruto';

  @override
  String get financialSummaryCheckCanton => 'Cantón';

  @override
  String get financialSummaryCheckAvoirLpp => 'Activos LPP';

  @override
  String get financialSummaryCheckEpargne3a => 'Ahorro 3a';

  @override
  String get financialSummaryCheckEpargneLiquide => 'Ahorro líquido';

  @override
  String get financialSummaryCheckLoyerHypotheque => 'Alquiler / hipoteca';

  @override
  String get financialSummaryCheckAssuranceMaladie => 'Seguro médico';

  @override
  String get financialSummaryWhatIf3aQuestion =>
      '¿Y si maximizaras tu 3a cada año?';

  @override
  String get financialSummaryWhatIf3aExplanation =>
      'A tu tasa marginal, cada franco en 3a te ahorra ~30% de impuestos.';

  @override
  String get financialSummaryWhatIf3aAction => 'Simular';

  @override
  String get financialSummaryWhatIfLppQuestion =>
      '¿Y si tu caja LPP pasara del 1% al 3%?';

  @override
  String get financialSummaryWhatIfLppExplanation =>
      'Un mejor rendimiento LPP aumenta tu capital de jubilación sin esfuerzo.';

  @override
  String get financialSummaryWhatIfLppAction => 'Comparar';

  @override
  String get financialSummaryWhatIfAchatQuestion =>
      '¿Y si compraras en lugar de alquilar?';

  @override
  String get financialSummaryWhatIfAchatExplanation =>
      'La amortización indirecta por el 2.º pilar puede reducir tus impuestos y crear patrimonio.';

  @override
  String get financialSummaryWhatIfAchatAction => 'Explorar';

  @override
  String get dataQualityTitle => 'Calidad de datos';

  @override
  String dataQualityMissingCount(String count) {
    return '$count información(es) por agregar';
  }

  @override
  String get dataQualityComplete => 'Perfil completo';

  @override
  String get dataQualityKnownSection => 'Datos conocidos';

  @override
  String get dataQualityMissingSection => 'Datos faltantes';

  @override
  String get dataQualityCompleteness => 'Completitud';

  @override
  String get dataQualityAccuracy => 'Exactitud';

  @override
  String get dataQualityFreshness => 'Frescura';

  @override
  String get dataQualityCombined => 'Puntuación combinada';

  @override
  String get dataQualityEnrich => 'Enriquecer mi perfil';

  @override
  String dataQualityEnrichWithImpact(String impact) {
    return 'Enriquecer mi perfil ($impact)';
  }

  @override
  String get confidenceLabelSalaire => 'Salario bruto';

  @override
  String get confidenceLabelAgeCanton => 'Edad / Cantón';

  @override
  String get confidenceLabelAge => 'Edad';

  @override
  String get confidenceLabelCanton => 'Cantón';

  @override
  String get confidenceLabelMenage => 'Situación del hogar';

  @override
  String get confidenceLabelAvoirLpp => 'Activos LPP';

  @override
  String get confidenceLabelTauxConversion => 'Tasa de conversión';

  @override
  String get confidenceLabelAnneesAvs => 'Años AVS';

  @override
  String get confidenceLabelEpargne3a => 'Ahorro 3a';

  @override
  String get confidenceLabelPatrimoine => 'Patrimonio';

  @override
  String get confidencePromptFreshnessPrefix => 'Actualiza: ';

  @override
  String confidencePromptFreshnessStale(String months) {
    return 'Datos de hace $months meses — reescanea tu certificado';
  }

  @override
  String get confidencePromptFreshnessConfirm =>
      'Confirma que este valor sigue siendo actual';

  @override
  String get confidencePromptAccuracyPrefix => 'Confirma: ';

  @override
  String get confidencePromptAccuracyEstimated => 'Ingresa tu valor real';

  @override
  String get confidencePromptAccuracyCertificate =>
      'Escanea tu certificado para confirmar';

  @override
  String get pulseTitle => 'Hoy';

  @override
  String pulseGreeting(String name) {
    return 'Hola $name';
  }

  @override
  String pulseGreetingCouple(String name1, String name2) {
    return 'Hola $name1 y $name2';
  }

  @override
  String get pulseWelcome => 'Veamos dónde estás.';

  @override
  String get pulseEmptyTitle => '¡Empieza completando tu perfil!';

  @override
  String get pulseEmptySubtitle =>
      'Unas pocas preguntas bastan para obtener tu primera estimación de visibilidad financiera.';

  @override
  String get pulseEmptyCtaStart => 'Empezar';

  @override
  String get pulseVisibilityTitle => 'Visibilidad financiera';

  @override
  String get pulsePrioritiesTitle => 'Tus prioridades';

  @override
  String get pulsePrioritiesSubtitle =>
      'Acciones personalizadas según tu perfil';

  @override
  String get pulseComprendreTitle => 'Comprender';

  @override
  String get pulseComprendreSubtitle => 'Explora tus simuladores';

  @override
  String get pulseComprendreRenteCapital => '¿Renta o capital?';

  @override
  String get pulseComprendreRenteCapitalSub =>
      'Compara las dos opciones de retiro';

  @override
  String get pulseComprendreRachatLpp => 'Simular una recompra LPP';

  @override
  String get pulseComprendreRachatLppSub =>
      'Descubre el impacto fiscal de una recompra';

  @override
  String get pulseComprendre3a => 'Explorar mi 3a';

  @override
  String get pulseComprendre3aSub => 'Descubre tu ahorro fiscal anual';

  @override
  String get pulseComprendre_budget => 'Mi presupuesto mensual';

  @override
  String get pulseComprendre_budgetSub => 'Visualiza tus ingresos y gastos';

  @override
  String get pulseComprendreAchat => '¿Comprar un inmueble?';

  @override
  String get pulseComprendreAchatSub => 'Estima tu capacidad de endeudamiento';

  @override
  String get pulseDisclaimer =>
      'Herramienta educativa. No constituye asesoramiento financiero personalizado. LSFin art. 3';

  @override
  String get pulseKeyFigRetraite => 'Jubilación estimada';

  @override
  String pulseKeyFigRetraitePct(String pct) {
    return '$pct % del ingreso';
  }

  @override
  String get pulseKeyFigBudgetLibre => 'Presupuesto libre';

  @override
  String get pulseKeyFigPatrimoine => 'Patrimonio';

  @override
  String pulseAmountPerMonth(String amount) {
    return '$amount/mes';
  }

  @override
  String pulseCoupleRetraite(String montant) {
    return 'Jubilación pareja: $montant';
  }

  @override
  String pulseCoupleAlertWeak(String name, String score) {
    return 'El perfil de $name está al $score % de visibilidad';
  }

  @override
  String get pulseAxisLiquidite => 'Liquidez';

  @override
  String get pulseAxisFiscalite => 'Fiscalidad';

  @override
  String get pulseAxisRetraite => 'Jubilación';

  @override
  String get pulseAxisSecurite => 'Seguridad';

  @override
  String get pulseHintAddSalary => 'Añade tu salario para empezar';

  @override
  String get pulseHintAddSavings => 'Introduce tus ahorros e inversiones';

  @override
  String get pulseHintLiquiditeComplete =>
      'Tus datos de liquidez están completos';

  @override
  String get pulseHintAddAgeCanton => 'Indica tu edad y cantón de residencia';

  @override
  String get pulseHintScanTax => 'Escanea tu declaración fiscal';

  @override
  String get pulseHintFiscaliteComplete => 'Tus datos fiscales están completos';

  @override
  String get pulseHintAddLpp => 'Añade tu certificado LPP';

  @override
  String get pulseHintExtractAvs => 'Solicita tu extracto AVS';

  @override
  String get pulseHintAdd3a => 'Introduce tus cuentas 3a';

  @override
  String get pulseHintRetraiteComplete =>
      'Tus datos de jubilación están completos';

  @override
  String get pulseHintAddFamily => 'Indica tu situación familiar';

  @override
  String get pulseHintAddStatus => 'Completa tu estatus profesional';

  @override
  String get pulseHintSecuriteComplete =>
      'Tus datos de seguridad están completos';

  @override
  String get pulseNarrativeExcellent =>
      'Tienes una visión clara de tu situación. Sigue manteniendo tus datos al día.';

  @override
  String pulseNarrativeGood(String axis) {
    return '¡Buena visibilidad! Afina tu $axis para ir más lejos.';
  }

  @override
  String pulseNarrativeModerate(String axis) {
    return 'Empiezas a ver más claro. Concéntrate en tu $axis.';
  }

  @override
  String pulseNarrativeWeak(String hint) {
    return 'Cada información cuenta. Empieza por $hint.';
  }

  @override
  String get pulseNoCheckinMsg =>
      'Sin check-in este mes. Registra tus pagos para seguir tu progreso.';

  @override
  String get pulseCheckinBtn => 'Check-in';

  @override
  String pulseBriefingTitle(String trend) {
    return 'Balance del mes — $trend';
  }

  @override
  String get pulseFriLiquidite => 'Liquidez';

  @override
  String get pulseFriFiscalite => 'Optimización fiscal';

  @override
  String get pulseFriRetraite => 'Jubilación';

  @override
  String get pulseFriRisque => 'Riesgos estructurales';

  @override
  String get pulseFriTitle => 'Solidez financiera';

  @override
  String pulseFriWeakest(String axis) {
    return 'Punto más frágil: $axis';
  }

  @override
  String get lppBuybackAdvTitle => 'Optimización de recompra LPP';

  @override
  String get lppBuybackAdvSubtitle =>
      'Apalancamiento fiscal + efecto de capitalización';

  @override
  String get lppBuybackAdvPotential => 'Potencial de recompra';

  @override
  String get lppBuybackAdvYears => 'Años hasta la jubilación';

  @override
  String get lppBuybackAdvStaggering => 'Escalonamiento';

  @override
  String get lppBuybackAdvFundRate => 'Tasa del fondo LPP';

  @override
  String get lppBuybackAdvIncome => 'Ingreso imponible';

  @override
  String get lppBuybackAdvFinalCapital => 'Valor final capitalizado';

  @override
  String lppBuybackAdvRealReturn(String pct) {
    return 'Rendimiento real: $pct % / año';
  }

  @override
  String get lppBuybackAdvTaxSaving => 'Ahorro fiscal';

  @override
  String get lppBuybackAdvNetEffort => 'Esfuerzo neto';

  @override
  String get lppBuybackAdvTotalGain => 'Ganancia total de la operación';

  @override
  String get lppBuybackAdvCapitalMinusEffort => 'Capital - Esfuerzo neto';

  @override
  String get lppBuybackAdvFundRateLabel => 'Tasa LPP aplicada';

  @override
  String get lppBuybackAdvLeverageEffect => 'Efecto de apalancamiento fiscal';

  @override
  String get lppBuybackAdvBonASavoir => 'Bueno saberlo';

  @override
  String get lppBuybackAdvBon1 =>
      'La recompra LPP es una de las pocas herramientas de planificación fiscal accesibles a todos los empleados en Suiza.';

  @override
  String get lppBuybackAdvBon2 =>
      'Cada franco recomprado es deducible de tu ingreso imponible (LIFD art. 33 al. 1 let. d).';

  @override
  String get lppBuybackAdvBon3 =>
      'Atención: todo retiro EPL está bloqueado durante 3 años después de una recompra (LPP art. 79b al. 3).';

  @override
  String get lppBuybackAdvDisclaimer =>
      'Simulación incluyendo el interés del fondo y el ahorro fiscal suavizado. El rendimiento real se calcula sobre tu esfuerzo neto real.';

  @override
  String get householdTitle => 'Nuestra Familia';

  @override
  String get householdDiscoverCouplePlus => 'Descubrir Couple+';

  @override
  String get householdLoginPrompt => 'Inicia sesión para gestionar tu hogar';

  @override
  String get householdLogin => 'Iniciar sesión';

  @override
  String get householdRetry => 'Reintentar';

  @override
  String get householdInvitePartner => 'Invitar a mi pareja';

  @override
  String get householdRemoveMemberTitle => '¿Eliminar este miembro?';

  @override
  String get householdRemoveMemberContent =>
      'Esta acción es irreversible. Se aplica un período de espera de 30 días antes de poder invitar a una nueva pareja.';

  @override
  String get householdCancel => 'Cancelar';

  @override
  String get householdRemove => 'Eliminar';

  @override
  String get householdSendInvitation => 'Enviar invitación';

  @override
  String get householdCodeCopied => 'Código copiado';

  @override
  String get householdMessageCopied => 'Mensaje copiado';

  @override
  String get householdCopy => 'Copiar';

  @override
  String get householdShare => 'Compartir';

  @override
  String get householdHaveCode => 'Tengo un código de invitación';

  @override
  String get householdCouplePlusTitle => 'Couple+';

  @override
  String get householdUpsellDescription =>
      'Optimiza tu jubilación en pareja con una suscripción Couple+. Proyecciones compartidas, retiros escalonados y coaching de pareja.';

  @override
  String get householdEmptyDescription =>
      'Optimiza tu jubilación en pareja. Retiros escalonados, proyecciones de pareja y calendario fiscal común.';

  @override
  String get householdHeaderTitle => 'Hogar Couple+';

  @override
  String get householdMembersTitle => 'Miembros';

  @override
  String get householdOwnerBadge => 'Propietario';

  @override
  String get householdPendingStatus => 'Invitación pendiente';

  @override
  String get householdActiveStatus => 'Activo';

  @override
  String get householdRemoveTooltip => 'Eliminar del hogar';

  @override
  String get householdInviteSectionTitle => 'Invitar a una pareja';

  @override
  String get householdInviteInfo =>
      'Tu pareja recibirá un código de invitación válido por 72 horas.';

  @override
  String get householdEmailLabel => 'Email de la pareja';

  @override
  String get householdEmailHint => 'pareja@email.ch';

  @override
  String get householdInviteSentTitle => 'Invitación enviada';

  @override
  String get householdValidFor => 'Válido 72 horas';

  @override
  String householdShareMessage(String code) {
    return 'Únete a mi hogar MINT con el código: $code\n\nAbre la app MINT > Familia > Tengo un código';
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
    return '$count miembro$_temp0 activo$_temp1';
  }

  @override
  String get householdPartnerDefault => 'Pareja';

  @override
  String get documentScanCancel => 'Cancelar';

  @override
  String get documentScanAnalyze => 'Analizar';

  @override
  String get documentScanTakePhoto => 'Tomar una foto';

  @override
  String get documentScanPasteOcr => 'Pegar texto OCR';

  @override
  String get documentScanCreateAccount => 'Crear una cuenta';

  @override
  String get documentScanRetakePhoto => 'Tomar otra foto';

  @override
  String get documentScanExtracting => 'Extrayendo...';

  @override
  String get documentScanImportFile => 'Importar un archivo';

  @override
  String get documentScanOcrTitle => 'Texto OCR';

  @override
  String get documentScanPdfAuthTitle => 'Inicio de sesión requerido para PDF';

  @override
  String get documentScanPdfAuthContent =>
      'El análisis automático de PDF pasa por el backend y requiere una cuenta conectada. Sin cuenta, puedes escanear una foto.';

  @override
  String get documentScanOcrHint =>
      'Pega el texto OCR extraído de tu PDF para continuar.';

  @override
  String get documentScanOcrRetryHint =>
      'Pega el texto OCR si la foto sigue siendo ilegible.';

  @override
  String get profileFamilySection => 'Familia';

  @override
  String get profileAnalyticsBeta => 'Analytics beta testers';

  @override
  String get profileDeleteAccountTitle => '¿Eliminar cuenta?';

  @override
  String get profileDeleteAccountContent =>
      'Esta acción elimina tu cuenta en la nube y los datos asociados. Tus datos locales permanecen en este dispositivo.';

  @override
  String get profileDeleteCancel => 'Cancelar';

  @override
  String get profileDeleteConfirm => 'Eliminar';

  @override
  String get consentAllRevoked =>
      'Todos los consentimientos opcionales han sido revocados.';

  @override
  String get consentClose => 'Cerrar';

  @override
  String get consentExportData => 'Exportar mis datos (nLPD art. 28)';

  @override
  String get consentRevokeAll => 'REVOCAR TODOS LOS CONSENTIMIENTOS OPCIONALES';

  @override
  String get consentControlCenter => 'CENTRO DE CONTROL DE DATOS';

  @override
  String get consentSecurityMessage =>
      'Tus datos permanecen en tu dispositivo. Mantienes el control total sobre el acceso de terceros.';

  @override
  String get consentRequired => 'Requerido';

  @override
  String get consentRequiredTitle => 'Consentimientos requeridos';

  @override
  String get consentOptionalTitle => 'Consentimientos opcionales';

  @override
  String get consentExportTitle => 'Exportar tus datos';

  @override
  String consentRetentionDays(int days) {
    return 'Conservación: $days días';
  }

  @override
  String get consentLegalSources => 'Fuentes legales';

  @override
  String get pillar3aPaymentPerYear => 'Pago/año:';

  @override
  String get pillar3aDuration => 'Duración:';

  @override
  String get pillar3aOpenViac => 'Abrir mi cuenta VIAC';

  @override
  String get pillar3aFees => 'Comisiones';

  @override
  String get pillar3aReturn => 'Rendimiento';

  @override
  String get pillar3aAt65 => 'A los 65';

  @override
  String get pillar3aComparator => 'Comparador 3a';

  @override
  String pillar3aProjection(int years) {
    return 'Proyección sobre $years años';
  }

  @override
  String get pillar3aScenarioTitle => 'Escenario: Aportación máxima anual';

  @override
  String pillar3aDurationYears(int years) {
    return '$years años (hasta los 65)';
  }

  @override
  String get pillar3aViacGainLabel => 'Con VIAC en lugar de un banco:';

  @override
  String get pillar3aMoreAtRetirement => '¡más en la jubilación!';

  @override
  String get pillar3aDisclaimer =>
      'Hipótesis pedagógicas basadas en rendimientos históricos medios. Los rendimientos pasados no constituyen una garantía de resultados futuros.';

  @override
  String get pillar3aCapitalEvolution => 'Evolución de tu capital 3a';

  @override
  String get pillar3aYearLabel => 'Año';

  @override
  String get pillar3aBank15 => 'Banco 1.5%';

  @override
  String get pillar3aViac45 => 'VIAC 4.5%';

  @override
  String pillar3aYearN(int n) {
    return 'Año $n';
  }

  @override
  String get pillar3aCompoundTip =>
      '¡Los últimos años representan +50% de la ganancia total gracias al interés compuesto!';

  @override
  String get pillar3aRecommended => 'RECOMENDADO';

  @override
  String pillar3aVsBank(String amount) {
    return '$amount vs Banco';
  }

  @override
  String get wizardCollapse => 'Reducir';

  @override
  String get wizardUnderstandTopic => 'Entender este tema';

  @override
  String get wizardSeeSimulation => 'Ver simulación interactiva';

  @override
  String get wizardNext => 'Siguiente';

  @override
  String get wizardExplanation => 'Explicación';

  @override
  String wizardValidateCount(int count) {
    return 'Validar ($count)';
  }

  @override
  String get wizardInvalidNumber => 'Introduce un número válido';

  @override
  String wizardMinValue(String value) {
    return 'Mínimo: $value';
  }

  @override
  String wizardMaxValue(String value) {
    return 'Máximo: $value';
  }

  @override
  String get wizardFieldRequired => 'Este campo es obligatorio';

  @override
  String get slmCancelDownload => 'Cancelar descarga';

  @override
  String get slmCancel => 'Cancelar';

  @override
  String get slmDownload => 'Descargar';

  @override
  String get slmDelete => 'Eliminar';

  @override
  String get slmIaOnDevice => 'IA en el dispositivo';

  @override
  String get slmPrivacyMessage =>
      'El modelo funciona 100% en tu dispositivo. Ningún dato sale de tu teléfono.';

  @override
  String get slmDownloadModelTitle => '¿Descargar el modelo?';

  @override
  String get slmDeleteModelTitle => '¿Eliminar el modelo?';

  @override
  String slmDeleteModelContent(String size) {
    return 'Esto liberará $size de espacio. Puedes volver a descargarlo en cualquier momento.';
  }

  @override
  String get slmDeleteModelButton => 'Eliminar modelo';

  @override
  String get slmStartingDownload => 'Iniciando descarga...';

  @override
  String get slmRetryDownload => 'Reintentar descarga';

  @override
  String get slmDownloadUnavailable => 'Descarga no disponible en esta versión';

  @override
  String get slmEngineStatus => 'Estado del motor';

  @override
  String get slmHowItWorks => '¿Cómo funciona?';

  @override
  String get landingPunchline1 => 'El sistema financiero suizo es poderoso.';

  @override
  String get landingPunchline2 => 'Si lo comprendes.';

  @override
  String get landingCtaComprendre => 'Comprender';

  @override
  String get landingJargon1 => 'Deducción de coordinación';

  @override
  String get landingClear1 => 'Lo que te quitan';

  @override
  String get landingJargon2 => 'Valor locativo';

  @override
  String get landingClear2 => 'El impuesto sobre tu casa';

  @override
  String get landingJargon3 => 'Tasa marginal';

  @override
  String get landingClear3 => 'Lo que realmente pagas';

  @override
  String get landingJargon4 => 'Brecha de previsión';

  @override
  String get landingClear4 => 'Lo que te faltará';

  @override
  String get landingJargon5 => 'Impuesto de transferencia';

  @override
  String get landingClear5 => 'El impuesto cuando compras';

  @override
  String get landingWhyNobody => 'Lo que no entiendes te sale caro. Cada año.';

  @override
  String get landingMintDoesIt => 'MINT lo hace.';

  @override
  String get landingCtaCommencer => 'Empezar';

  @override
  String get landingLegalFooterShort =>
      'Herramienta educativa. No constituye asesoramiento financiero (LSFin). Datos en tu dispositivo.';

  @override
  String pulseDigitalTwinPct(String pct) {
    return 'Gemelo digital: $pct%';
  }

  @override
  String get pulseDigitalTwinHint =>
      'Cuanto más completo sea tu perfil, más fiables serán tus proyecciones.';

  @override
  String get pulseActionsThisMonth => 'Pendiente este mes';

  @override
  String get pulseHeroChangeBtn => 'Cambiar';

  @override
  String get pulseCoachInsightTitle => 'Análisis del coach';

  @override
  String get pulseRefineProfile => 'Perfeccionar mi perfil';

  @override
  String get pulseWhatIf3aQuestion => '¿Y si aportaras el máximo al 3a?';

  @override
  String pulseWhatIf3aImpact(String amount) {
    return '−CHF $amount/año de impuestos';
  }

  @override
  String get pulseWhatIfLppQuestion => '¿Y si hicieras una compra LPP?';

  @override
  String pulseWhatIfLppImpact(String amount) {
    return 'Hasta −CHF $amount de impuestos';
  }

  @override
  String get pulseWhatIfEarlyQuestion => '¿Y si te jubilaras 1 año antes?';

  @override
  String pulseWhatIfEarlyImpact(String amount) {
    return '−CHF $amount/mes de pensión';
  }

  @override
  String get pulseActionSignalSingular => '1 acción pendiente';

  @override
  String pulseActionSignalPlural(String count) {
    return '$count acciones pendientes';
  }

  @override
  String get agirTopActionCta => 'Empezar';

  @override
  String agirOtherActions(String count) {
    return '$count otras acciones';
  }

  @override
  String get exploreSuggestionLabel => 'Sugerencia para ti';

  @override
  String get exploreSuggestion3aTitle => 'Pilar 3a: tu primera palanca fiscal';

  @override
  String get exploreSuggestion3aSub =>
      'Descubre cuánto puedes ahorrar en impuestos';

  @override
  String get exploreSuggestionLppTitle => 'Recompra LPP: ¿una oportunidad?';

  @override
  String get exploreSuggestionLppSub =>
      'Simula el impacto en tu jubilación e impuestos';

  @override
  String get exploreSuggestionRetirementTitle => 'Tu jubilación se acerca';

  @override
  String get exploreSuggestionRetirementSub =>
      '¿Renta, capital o mixto? Compara las opciones';

  @override
  String get exploreSuggestionBudgetTitle => 'Empieza con tu presupuesto';

  @override
  String get exploreSuggestionBudgetSub =>
      '3 minutos para ver a dónde va tu dinero';

  @override
  String get pulseReadinessTitle => 'Forma financiera';

  @override
  String get pulseReadinessGood => 'Buena preparación';

  @override
  String get pulseReadinessProgress => 'En progreso';

  @override
  String get pulseReadinessWeak => 'A reforzar';

  @override
  String pulseReadinessRetireIn(int years) {
    return 'Jubilación en $years años';
  }

  @override
  String pulseReadinessYearsToAct(int years) {
    return 'Aún $years años para actuar';
  }

  @override
  String get pulseReadinessActNow => 'Lo esencial ocurre ahora';

  @override
  String get pulseReadinessRetired => 'Ya jubilado/a';

  @override
  String get pulseCompleteProfile => 'Completa tu perfil';

  @override
  String get profileSectionMyFile => 'Mi expediente';

  @override
  String get profileSectionSettings => 'Ajustes';

  @override
  String get profileCompletionLabel => 'Tu expediente';

  @override
  String get agirBudgetNet => 'Neto';

  @override
  String get agirBudgetFixed => 'Fijos';

  @override
  String get agirBudgetAvailable => 'Disponible';

  @override
  String get agirBudgetSaved => 'Aportado';

  @override
  String get agirBudgetRemaining => 'Resto';

  @override
  String get agirBudgetWarning =>
      'Tus aportaciones superan tu presupuesto disponible';

  @override
  String get enrichmentCtaScan => 'Escanear un documento';

  @override
  String enrichmentCtaMissing(int count) {
    return '$count campo(s) por completar';
  }

  @override
  String get heroGapTitle => 'En la jubilación, te faltará';

  @override
  String get heroGapCovered => 'Estás bien cubierto/a';

  @override
  String get heroGapPerMonth => '/mes';

  @override
  String get heroGapToday => 'Hoy';

  @override
  String get heroGapRetirement => 'Jubilación';

  @override
  String get heroGapConfidence => 'Confianza';

  @override
  String get heroGapScanCta => 'Escanear certificado LPP';

  @override
  String heroGapBoost(int percent) {
    return '+$percent % precisión';
  }

  @override
  String get heroGapMetaphor5k =>
      'Es como pasar de un piso de 5 habitaciones a un estudio';

  @override
  String get heroGapMetaphor3k =>
      'Es como renunciar a tu coche y tus vacaciones';

  @override
  String get heroGapMetaphor1k => 'Es como dejar de ir a restaurantes';

  @override
  String get heroGapMetaphorSmall => 'Es un café al día de diferencia';

  @override
  String get drawerCeQueTuAs => 'Lo que tienes';

  @override
  String get drawerCeQueTuAsSubtitle => 'Patrimonio neto';

  @override
  String get drawerCeQueTuDois => 'Lo que debes';

  @override
  String get drawerCeQueTuDoisSubtitle => 'Deuda total';

  @override
  String get drawerCeQueTuAuras => 'Lo que tendrás';

  @override
  String get drawerCeQueTuAurasSubtitle => 'Ingreso de jubilación proyectado';

  @override
  String get shellWelcomeBack => 'De vuelta. Tus números están al día.';

  @override
  String get shellRecommendationsUpdated => 'Recomendaciones actualizadas';

  @override
  String get pulseEnrichirTitle => 'Escanea tu certificado LPP';

  @override
  String pulseEnrichirSubtitle(String points) {
    return 'Confianza → +$points puntos';
  }

  @override
  String get pulseEnrichirCta => 'Escanear →';

  @override
  String get tabMoi => 'Yo';

  @override
  String get coupleSwitchSolo => 'Solo';

  @override
  String get coupleSwitchDuo => 'Duo';

  @override
  String get identityStatusSalarie => 'Asalariado';

  @override
  String get identityStatusIndependant => 'Independiente';

  @override
  String get identityStatusChomage => 'En búsqueda';

  @override
  String get identityStatusRetraite => 'Jubilado';

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
  String get pcWidgetTitle => 'Prestaciones complementarias (PC)';

  @override
  String get pcWidgetSubtitle => 'Lista de verificación de elegibilidad local';

  @override
  String get pcWidgetRevenus => 'Ingresos';

  @override
  String get pcWidgetFortune => 'Patrimonio';

  @override
  String get pcWidgetLoyer => 'Alquiler';

  @override
  String get pcWidgetEligible =>
      'Tu situación sugiere un derecho potencial a las PC.';

  @override
  String get pcWidgetNotEligible =>
      'Tus ingresos parecen suficientes según las escalas estándar.';

  @override
  String pcWidgetFindOffice(String canton) {
    return 'Encontrar la oficina PC ($canton)';
  }

  @override
  String get letterGenTitle => 'Secretaría Automática';

  @override
  String get letterGenSubtitle =>
      'Genera plantillas de cartas listas para usar.';

  @override
  String get letterGenBuybackTitle => 'Solicitud de Rescate LPP';

  @override
  String get letterGenBuybackSubtitle =>
      'Para conocer tu potencial de rescate.';

  @override
  String get letterGenTaxTitle => 'Certificado Fiscal';

  @override
  String get letterGenTaxSubtitle => 'Para tu declaración de impuestos.';

  @override
  String get letterGenDisclaimer =>
      'Estos documentos son plantillas para completar. No constituyen asesoramiento legal.';

  @override
  String get precisionPromptTitle => 'Precisión disponible';

  @override
  String get precisionPromptPreciser => 'Precisar';

  @override
  String get precisionPromptContinuer => 'Continuar';

  @override
  String get earlyRetirementHeader => '¿Y si me jubilo a los…?';

  @override
  String earlyRetirementAgeDisplay(int age) {
    return '$age años';
  }

  @override
  String get earlyRetirementZoneRisky =>
      'Arriesgado — sacrificio financiero importante';

  @override
  String get earlyRetirementZoneFeasible => 'Factible — con compromisos';

  @override
  String get earlyRetirementZoneStandard => 'Estándar — sin penalización';

  @override
  String get earlyRetirementZoneBonus =>
      'Bonus — ganas más, pero disfrutas menos tiempo';

  @override
  String earlyRetirementResultLine(int age, String amount) {
    return 'A los $age : $amount/mes';
  }

  @override
  String earlyRetirementNarrativeEarly(
      String amount, int years, String plural) {
    return 'Pierdes $amount/mes de por vida. Pero ganas $years año$plural de libertad.';
  }

  @override
  String earlyRetirementNarrativeLate(String amount, int years, String plural) {
    return 'Ganas $amount/mes más. $years año$plural de trabajo adicional.';
  }

  @override
  String earlyRetirementLifetimeImpact(String amount) {
    return 'Impacto estimado en 25 años : $amount';
  }

  @override
  String get earlyRetirementDisclaimer =>
      'Estimaciones educativas — no constituye asesoramiento financiero (LSFin).';

  @override
  String earlyRetirementSemanticsLabel(int age) {
    return 'Simulador de edad de jubilación. Edad seleccionada : $age años.';
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
      'L\'extrait de compte individuel (CI) contient tes années de cotisation, ton revenu moyen (RAMD) et tes éventuelles lacunes. C\'est la clé pour une projection AVS fiable.';

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
  String get avsGuideStep1Subtitle =>
      'C\'est le site officiel de l\'AVS/AI. Tu peux aussi demander ton extrait directement à ta caisse de compensation.';

  @override
  String get avsGuideStep2Title =>
      'Connecte-toi avec ton eID ou crée un compte';

  @override
  String get avsGuideStep2Subtitle =>
      'Tu auras besoin de ton numéro AVS (756.XXXX.XXXX.XX, sur ta carte d\'assurance-maladie).';

  @override
  String get avsGuideStep3Title =>
      'Demande ton extrait de compte individuel (CI)';

  @override
  String get avsGuideStep3Subtitle =>
      'Cherche la section \"Extrait de compte\" ou \"Kontoauszug\". C\'est un document officiel qui récapitule toutes tes cotisations.';

  @override
  String get avsGuideStep4Title => 'Tu le recevras par courrier ou PDF';

  @override
  String get avsGuideStep4Subtitle =>
      'Selon ta caisse, l\'extrait arrive en 5 à 10 jours ouvrables. Certaines caisses proposent un téléchargement PDF immédiat.';

  @override
  String get avsGuideOpenAhvButton => 'Ouvrir ahv-iv.ch';

  @override
  String get avsGuideScanButton => 'J\'ai déjà mon extrait → Scanner';

  @override
  String get avsGuideTestMode => 'MODE TEST';

  @override
  String get avsGuideTestDescription =>
      'Pas d\'extrait AVS sous la main ? Teste le flux avec un exemple d\'extrait.';

  @override
  String get avsGuideTestButton => 'Utiliser un exemple';

  @override
  String get avsGuideFreeNote =>
      'L\'extrait AVS est gratuit et disponible en 5 à 10 jours ouvrables. Tu peux aussi te rendre à ta caisse de compensation cantonale.';

  @override
  String get avsGuidePrivacyNote =>
      'L\'image de ton extrait n\'est jamais stockée ni envoyée. L\'extraction se fait sur ton appareil. Seules les valeurs que tu confirmes sont conservées dans ton profil.';

  @override
  String avsGuideSnackbarError(String url) {
    return 'Impossible d\'ouvrir $url. Copie l\'adresse et ouvre-la dans ton navigateur.';
  }

  @override
  String get dataBlockDisclaimer =>
      'Outil éducatif simplifié. Ne constitue pas un conseil financier (LSFin).';

  @override
  String get dataBlockIncomplete =>
      'Ce bloc est encore incomplet. Ouvre la section dédiée pour ajouter les données manquantes.';

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
  String get dataBlockRevenuDesc =>
      'Ton salaire brut est la base de toutes les projections.';

  @override
  String get dataBlockRevenuCta => 'Préciser mon revenu';

  @override
  String get dataBlockLppTitle => 'Prévoyance LPP';

  @override
  String get dataBlockLppDesc =>
      'Ton avoir LPP (2e pilier) représente souvent le plus gros capital de ta prévoyance.';

  @override
  String get dataBlockLppCta => 'Ajouter mon certificat LPP';

  @override
  String get dataBlockAvsTitle => 'Extrait AVS';

  @override
  String get dataBlockAvsDesc =>
      'L\'extrait AVS confirme tes années de cotisation effectives.';

  @override
  String get dataBlockAvsCta => 'Commander mon extrait AVS';

  @override
  String get dataBlock3aTitle => '3e pilier (3a)';

  @override
  String get dataBlock3aDesc =>
      'Tes comptes 3a s\'ajoutent à ta prévoyance et offrent un avantage fiscal.';

  @override
  String get dataBlock3aCta => 'Simuler mon 3a';

  @override
  String get dataBlockPatrimoineTitle => 'Patrimoine';

  @override
  String get dataBlockPatrimoineDesc =>
      'Épargne libre, investissements, immobilier.';

  @override
  String get dataBlockPatrimoineCta => 'Renseigner mon patrimoine';

  @override
  String get dataBlockFiscaliteTitle => 'Fiscalité';

  @override
  String get dataBlockFiscaliteDesc =>
      'Ta commune, ton revenu imposable et ta fortune déterminent ton taux marginal d\'imposition.';

  @override
  String get dataBlockFiscaliteCta => 'Comparer ma fiscalité';

  @override
  String get dataBlockObjectifTitle => 'Objectif retraite';

  @override
  String get dataBlockObjectifDesc =>
      'À quel âge souhaites-tu arrêter de travailler ?';

  @override
  String get dataBlockObjectifCta => 'Voir ma projection';

  @override
  String get dataBlockMenageTitle => 'Composition du ménage';

  @override
  String get dataBlockMenageDesc => 'En couple, les projections changent.';

  @override
  String get dataBlockMenageCta => 'Gérer mon ménage';

  @override
  String get dataBlockUnknownTitle => 'Données';

  @override
  String get dataBlockUnknownDesc => 'Ce lien de données n’est plus à jour.';

  @override
  String get dataBlockUnknownCta => 'Ouvrir le diagnostic';

  @override
  String get dataBlockDefaultTitle => 'Données';

  @override
  String get dataBlockDefaultDesc =>
      'Complète ce bloc pour améliorer la précision de tes projections.';

  @override
  String get dataBlockDefaultCta => 'Compléter';

  @override
  String get renteVsCapitalAppBarTitle => 'Rente ou capital : ta décision';

  @override
  String get renteVsCapitalIntro =>
      'À la retraite, tu choisis une fois pour toutes.';

  @override
  String get renteVsCapitalRenteLabel => 'Rente';

  @override
  String get renteVsCapitalRenteExplanation =>
      'Ta caisse de pension te verse un montant fixe chaque mois.';

  @override
  String get renteVsCapitalCapitalLabel => 'Capital';

  @override
  String get renteVsCapitalCapitalExplanation =>
      'Tu récupères tout ton avoir LPP d\'un coup.';

  @override
  String get renteVsCapitalMixteLabel => 'Mixte';

  @override
  String get renteVsCapitalMixteExplanation =>
      'La partie obligatoire en rente + le surobligatoire en capital.';

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
      'Projection basée sur ton âge, salaire et LPP actuel';

  @override
  String get renteVsCapitalLppOblig => 'Avoir LPP obligatoire (certificat LPP)';

  @override
  String get renteVsCapitalLppSurob =>
      'Avoir LPP surobligatoire (certificat LPP)';

  @override
  String get renteVsCapitalRenteProposed =>
      'Rente annuelle proposée (certificat LPP)';

  @override
  String get renteVsCapitalTcOblig => 'Taux conv. oblig. (%)';

  @override
  String get renteVsCapitalTcSurob => 'Taux conv. surob. (%)';

  @override
  String get renteVsCapitalMaxPrecision =>
      'Précision maximale — résultats basés sur tes vrais chiffres.';

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
    return 'Cette décision peut te coûter $taxDelta d\'impôts en trop — ou te laisser sans rien à $age ans. Tu ne peux la prendre qu\'une seule fois.';
  }

  @override
  String renteVsCapitalAccrocheTax(String taxDelta) {
    return 'Cette décision peut changer $taxDelta d\'impôts sur ta retraite. Tu ne peux la prendre qu\'une seule fois.';
  }

  @override
  String renteVsCapitalAccrocheEpuise(int age) {
    return 'Avec le capital, tu pourrais manquer d\'argent dès $age ans.';
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
  String get renteVsCapitalMicroRente =>
      'Ta caisse te verse ce montant chaque mois, tant que tu vis.';

  @override
  String renteVsCapitalMicroCapital(String swr, String rendement) {
    return 'Tu retires $swr % par an d\'un capital placé à $rendement %.';
  }

  @override
  String renteVsCapitalSyntheseCapitalHigher(String delta) {
    return 'Le capital te donne $delta/mois de plus, mais pourrait s\'épuiser.';
  }

  @override
  String renteVsCapitalSyntheseRenteHigher(String delta) {
    return 'La rente te donne $delta/mois de plus, et ne s\'arrête jamais.';
  }

  @override
  String get renteVsCapitalAvsEstimated => 'AVS estimée : ';

  @override
  String renteVsCapitalAvsAmount(String amount) {
    return '~$amount/mois';
  }

  @override
  String get renteVsCapitalAvsSupplementary =>
      ' supplémentaires dans les deux cas (LAVS art. 29)';

  @override
  String get renteVsCapitalLifeExpectancy => 'Et si je vis jusqu\'à...';

  @override
  String get renteVsCapitalLifeExpectancyRef =>
      'Espérance de vie suisse : hommes 84 ans · femmes 87 ans';

  @override
  String get renteVsCapitalChartTitle =>
      'Capital restant vs revenus cumulés de la rente';

  @override
  String get renteVsCapitalChartSubtitle =>
      'Capital (vert) : ce qu\'il reste après tes retraits.';

  @override
  String get renteVsCapitalChartAxisLabel => 'Âge';

  @override
  String renteVsCapitalBeyondHorizon(int age) {
    return 'À $age ans : au-delà de l\'horizon de simulation.';
  }

  @override
  String renteVsCapitalDeltaAtAge(int age) {
    return 'À $age ans : ';
  }

  @override
  String get renteVsCapitalDeltaAdvance => 'd\'avance';

  @override
  String get renteVsCapitalEducationalTitle => 'Ce que ça change concrètement';

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
    return 'Sur 30 ans, le capital te fait économiser ~$amount d\'impôts.';
  }

  @override
  String renteVsCapitalFiscalRenteSaves(String amount) {
    return 'Sur 30 ans, la rente génère ~$amount d\'impôts en moins.';
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
    return 'Ta rente LPP n\'est pas indexée. Elle achète $percent % de moins dans 20 ans.';
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
      'Avec la rente, seul·e ton conjoint·e reçoit 60 %. Rien pour les enfants.';

  @override
  String get renteVsCapitalTransmissionBottomSingle =>
      'Avec la rente, rien ne revient à tes proches.';

  @override
  String get renteVsCapitalAffinerTitle => 'Affiner ta simulation';

  @override
  String get renteVsCapitalAffinerSubtitle => 'Pour ceux qui veulent creuser.';

  @override
  String get renteVsCapitalHypRendement => 'Ce que ton capital rapporte par an';

  @override
  String get renteVsCapitalHypSwr => 'Combien tu retires chaque année';

  @override
  String get renteVsCapitalHypInflation => 'Inflation';

  @override
  String get renteVsCapitalTornadoToggle => 'Voir le diagramme de sensibilité';

  @override
  String get renteVsCapitalImpactTitle =>
      'Qu\'est-ce qui change le plus le résultat ?';

  @override
  String get renteVsCapitalImpactSubtitle =>
      'Les paramètres les plus influents sur l\'écart entre tes options.';

  @override
  String get renteVsCapitalHypothesesTitle => 'Hypothèses de cette simulation';

  @override
  String get renteVsCapitalWarning => 'Avertissement';

  @override
  String renteVsCapitalSources(String sources) {
    return 'Sources : $sources';
  }

  @override
  String get renteVsCapitalRachatLabel => 'Rachat LPP annuel prévu (CHF)';

  @override
  String renteVsCapitalRachatMax(String amount) {
    return 'max $amount';
  }

  @override
  String get renteVsCapitalRachatHint => '0 (optionnel)';

  @override
  String get renteVsCapitalRachatTooltip =>
      'Si tu fais des rachats LPP chaque année, leur valeur futur est ajoutée au capital à la retraite.';

  @override
  String get renteVsCapitalEplLabel => 'Retrait EPL pour achat immobilier';

  @override
  String get renteVsCapitalEplHint => 'Montant retiré (min 20\'000)';

  @override
  String get renteVsCapitalEplTooltip => 'Le retrait EPL réduit ton avoir LPP.';

  @override
  String get renteVsCapitalEplLegalRef =>
      'LPP art. 30c — OPP2 art. 5 (min CHF 20\'000)';

  @override
  String get renteVsCapitalProfileAutoFill =>
      'Valeurs pré-remplies depuis ton profil';

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
      'Si plus de 90% de tes revenus mondiaux proviennent de Suisse.';

  @override
  String get frontalierTessinTitle => 'Tessin — régime spécial';

  @override
  String get frontalierEducationalTax =>
      'En Suisse, les frontaliers sont imposés à la source (barème C).';

  @override
  String get frontalierJoursBureau => 'Jours au bureau en Suisse';

  @override
  String get frontalierJoursHomeOffice => 'Jours en home office à l\'étranger';

  @override
  String get frontalierJaugeRisque => 'JAUGE DE RISQUE';

  @override
  String get frontalierJoursHomeOfficeLabel => 'jours de home office';

  @override
  String get frontalierRiskLow => 'Pas de risque';

  @override
  String get frontalierRiskMedium => 'Zone d\'attention';

  @override
  String get frontalierRiskHigh => 'Risque fiscal — l\'imposition bascule';

  @override
  String frontalierDaysRemaining(int days) {
    return 'Il te reste $days jours de marge';
  }

  @override
  String get frontalierRecommandation => 'RECOMMANDATION';

  @override
  String get frontalierEducational90Days =>
      'Depuis 2023, les accords amiables entre la Suisse et ses voisins fixent un seuil de tolérance pour le télétravail des frontaliers.';

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
  String get frontalierLamalDesc => 'Obligatoire si tu travailles en CH.';

  @override
  String get frontalierCmuTitle => 'CMU/Sécu (France)';

  @override
  String get frontalierCmuDesc =>
      'Droit d\'option possible pour les frontaliers FR.';

  @override
  String get frontalierAssurancePriveeTitle => 'Assurance privée (DE/IT/AT)';

  @override
  String get frontalierAssurancePriveeDesc =>
      'En Allemagne, option PKV pour hauts revenus.';

  @override
  String get frontalierEducationalCharges =>
      'En tant que frontalier, tu cotises aux assurances sociales suisses.';

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
    return 'En concubinage, ton partenaire paierait $impot d\'impôt successoral sur un patrimoine de $patrimoine.';
  }

  @override
  String get concubinageNeutralTitle =>
      'Aucune option n\'est universellement adaptée';

  @override
  String get concubinageNeutralDesc =>
      'Le choix entre mariage et concubinage dépend de ta situation.';

  @override
  String get concubinageChecklistIntro =>
      'En concubinage, rien n\'est automatique.';

  @override
  String concubinageProtectionsCount(int count, int total) {
    return '$count/$total protections en place';
  }

  @override
  String get concubinageChecklist1Title => 'Rédiger un testament';

  @override
  String get concubinageChecklist1Desc =>
      'Sans testament, ton partenaire n\'hérite de rien.';

  @override
  String get concubinageChecklist2Title => 'Clause bénéficiaire LPP';

  @override
  String get concubinageChecklist2Desc =>
      'Contacte ta caisse de pension pour inscrire ton/ta partenaire.';

  @override
  String get concubinageChecklist3Title => 'Convention de concubinage';

  @override
  String get concubinageChecklist3Desc =>
      'Un contrat écrit qui règle le partage des frais.';

  @override
  String get concubinageChecklist4Title => 'Assurance-vie croisée';

  @override
  String get concubinageChecklist4Desc =>
      'Une assurance-vie où chacun est bénéficiaire de l\'autre.';

  @override
  String get concubinageChecklist5Title => 'Mandat pour cause d\'inaptitude';

  @override
  String get concubinageChecklist5Desc =>
      'Si tu deviens incapable de discernement.';

  @override
  String get concubinageChecklist6Title => 'Directives anticipées';

  @override
  String get concubinageChecklist6Desc =>
      'Un document qui précise tes volontés médicales.';

  @override
  String get concubinageChecklist7Title =>
      'Compte joint pour les dépenses communes';

  @override
  String get concubinageChecklist7Desc =>
      'Un compte commun simplifie la gestion des dépenses partagées.';

  @override
  String get concubinageChecklist8Title => 'Bail commun ou individuel';

  @override
  String get concubinageChecklist8Desc =>
      'Si tu es sur le bail avec ton/ta partenaire.';

  @override
  String get concubinageDisclaimer =>
      'Informations simplifiées à but éducatif.';

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
  String get frontalierJoursSuffix => 'días';

  @override
  String get conversationHistoryTitle => 'Historial';

  @override
  String get conversationNew => 'Nueva conversación';

  @override
  String get conversationEmptyTitle => 'Sin conversaciones';

  @override
  String get conversationEmptySubtitle => 'Empieza a hablar con tu coach';

  @override
  String get conversationStartFirst => 'Iniciar conversación';

  @override
  String get conversationErrorTitle => 'Error de carga';

  @override
  String get conversationRetry => 'Reintentar';

  @override
  String get conversationDeleteTitle => '¿Eliminar esta conversación?';

  @override
  String get conversationDeleteConfirm => 'Esta acción es irreversible.';

  @override
  String get conversationDeleteCancel => 'Cancelar';

  @override
  String get conversationDeleteAction => 'Eliminar';

  @override
  String get conversationDateNow => 'Ahora';

  @override
  String get conversationDateYesterday => 'Ayer';

  @override
  String conversationDateMinutesAgo(String minutes) {
    return 'Hace $minutes min';
  }

  @override
  String conversationDateHoursAgo(String hours) {
    return 'Hace ${hours}h';
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
        '1': 'enero',
        '2': 'febrero',
        '3': 'marzo',
        '4': 'abril',
        '5': 'mayo',
        '6': 'junio',
        '7': 'julio',
        '8': 'agosto',
        '9': 'septiembre',
        '10': 'octubre',
        '11': 'noviembre',
        '12': 'diciembre',
        'other': 'mes',
      },
    );
    return '$_temp0';
  }

  @override
  String get achievementsTitle => 'Mis logros';

  @override
  String get achievementsEmptyProfile =>
      'Completa tu perfil para desbloquear logros.';

  @override
  String get achievementsDaysSingular => 'día';

  @override
  String get achievementsDaysPlural => 'días!';

  @override
  String achievementsRecord(int count) {
    return 'Récord: $count días';
  }

  @override
  String achievementsTotalDays(int count) {
    return '$count días en total';
  }

  @override
  String get achievementsEngageCta =>
      '¡Realiza una acción hoy para mantener tu racha!';

  @override
  String get achievementsEngagedToday => 'Participación registrada hoy';

  @override
  String get achievementsBadgesTitle => 'Insignias';

  @override
  String get achievementsBadgesSubtitle =>
      'Regularidad de tus check-ins mensuales';

  @override
  String achievementsBadgeMonths(int count) {
    return '$count meses';
  }

  @override
  String get achievementsMilestonesTitle => 'Hitos';

  @override
  String get achievementsMilestonesSubtitle => 'Tus hitos financieros';

  @override
  String get achievementsDisclaimer =>
      'Tus logros son personales — MINT nunca los compara con otros.';

  @override
  String get achievementsDayMon => 'L';

  @override
  String get achievementsDayTue => 'M';

  @override
  String get achievementsDayWed => 'X';

  @override
  String get achievementsDayThu => 'J';

  @override
  String get achievementsDayFri => 'V';

  @override
  String get achievementsDaySat => 'S';

  @override
  String get achievementsDaySun => 'D';

  @override
  String get achievementsBadgeFirstStepLabel => 'Primer paso';

  @override
  String get achievementsBadgeFirstStepDesc =>
      'Completaste tu primer check-in.';

  @override
  String get achievementsBadgeRegulierLabel => 'Regular';

  @override
  String get achievementsBadgeRegulierDesc =>
      '3 meses consecutivos de check-in.';

  @override
  String get achievementsBadgeConstantLabel => 'Constante';

  @override
  String get achievementsBadgeConstantDesc => '6 meses sin interrupción.';

  @override
  String get achievementsBadgeDisciplineLabel => 'Disciplinado/a';

  @override
  String get achievementsBadgeDisciplineDesc =>
      '12 meses consecutivos — un año completo.';

  @override
  String get achievementsCatPatrimoine => 'Patrimonio';

  @override
  String get achievementsCatPrevoyance => 'Previsión';

  @override
  String get achievementsCatSecurite => 'Seguridad';

  @override
  String get achievementsCatScoreFri => 'Puntuación FRI';

  @override
  String get achievementsCatEngagement => 'Compromiso';

  @override
  String get achievementsFriAbove50Label => 'FRI 50+';

  @override
  String get achievementsFriAbove50Desc =>
      'Alcanzar una puntuación de solidez de 50/100';

  @override
  String get achievementsFriAbove70Label => 'FRI 70+';

  @override
  String get achievementsFriAbove70Desc =>
      'Alcanzar una puntuación de solidez de 70/100';

  @override
  String get achievementsFriAbove85Label => 'FRI 85+';

  @override
  String get achievementsFriAbove85Desc => 'Zona de excelencia — 85/100';

  @override
  String get achievementsFriImproved10Label => 'Progreso +10';

  @override
  String get achievementsFriImproved10Desc => 'Ganar 10 puntos FRI en un mes';

  @override
  String get achievementsStreak6MonthsLabel => 'Racha 6 meses';

  @override
  String get achievementsStreak6MonthsDesc =>
      '6 meses consecutivos de check-in';

  @override
  String get achievementsStreak12MonthsLabel => 'Racha 12 meses';

  @override
  String get achievementsStreak12MonthsDesc =>
      '12 meses consecutivos — un año completo';

  @override
  String get achievementsFirstArbitrageLabel => 'Primera comparación';

  @override
  String get achievementsFirstArbitrageDesc =>
      'Completar tu primera simulación de comparación';

  @override
  String get nudgeSalaryTitle => '¡Día de cobro !';

  @override
  String get nudgeSalaryMessage =>
      '¿Has pensado en tu transferencia 3a este mes? Cada mes cuenta para tu previsión.';

  @override
  String get nudgeSalaryAction => 'Ver mi 3a';

  @override
  String get nudgeTaxTitle => 'Declaración fiscal';

  @override
  String get nudgeTaxMessage =>
      'Verifica la fecha límite de declaración fiscal en tu cantón. ¿Has revisado tus deducciones 3a y LPP?';

  @override
  String get nudgeTaxAction => 'Simular mis impuestos';

  @override
  String get nudge3aTitle => 'Recta final para tu 3a';

  @override
  String get nudge3aMessageLastDay => '¡Es el último día para aportar a tu 3a!';

  @override
  String nudge3aMessage(String days, String limit, String year) {
    return 'Quedan $days día(s) para aportar hasta $limit CHF y reducir tus impuestos $year.';
  }

  @override
  String get nudge3aAction => 'Calcular mi ahorro';

  @override
  String nudgeBirthdayTitle(String age) {
    return '¡Cumples $age años este año !';
  }

  @override
  String get nudgeBirthdayAction => 'Ver mi panel';

  @override
  String get nudgeAnniversaryTitle => '¡Ya 1 año juntos!';

  @override
  String get nudgeAnniversaryMessage =>
      'Llevas un año usando MINT. Es el momento ideal para actualizar tu perfil y medir tus avances.';

  @override
  String get nudgeAnniversaryAction => 'Actualizar mi perfil';

  @override
  String get nudgeLppStartTitle => 'Inicio de cotizaciones LPP';

  @override
  String get nudgeLppChangeTitle => 'Cambio de tramo LPP';

  @override
  String nudgeLppStartMessage(String rate) {
    return 'Tus cotizaciones LPP de vejez comienzan este año ($rate %). Es el inicio de tu previsión profesional.';
  }

  @override
  String nudgeLppChangeMessage(String age, String rate) {
    return 'A los $age años, tu bonificación de vejez sube a $rate %. Podría ser buen momento para considerar un rescate LPP.';
  }

  @override
  String get nudgeLppAction => 'Explorar el rescate';

  @override
  String get nudgeWeeklyTitle => '¡Hace tiempo que no pasas!';

  @override
  String get nudgeWeeklyMessage =>
      'Tu situación financiera evoluciona cada semana. Tómate 2 minutos para revisar tu panel.';

  @override
  String get nudgeWeeklyAction => 'Ver mi Pulse';

  @override
  String get nudgeStreakTitle => '¡Tu racha está en peligro!';

  @override
  String nudgeStreakMessage(String count) {
    return 'Tienes una racha de $count días. Una pequeña acción hoy basta para mantenerla.';
  }

  @override
  String get nudgeStreakAction => 'Continuar mi racha';

  @override
  String get nudgeGoalTitle => 'Tu objetivo se acerca';

  @override
  String nudgeGoalMessage(String desc, String days) {
    return '«$desc» — quedan $days día(s). ¿Has avanzado en este tema?';
  }

  @override
  String get nudgeGoalAction => 'Hablar con el coach';

  @override
  String get nudgeFhsTitle => 'Tu puntuación de salud ha bajado';

  @override
  String nudgeFhsMessage(String drop) {
    return 'Tu Financial Health Score ha perdido $drop puntos. Veamos qué podría explicar este cambio.';
  }

  @override
  String get nudgeFhsAction => 'Entender la bajada';

  @override
  String get recapEngagement => 'Compromiso';

  @override
  String get recapBudget => 'Presupuesto';

  @override
  String get recapGoals => 'Objetivos';

  @override
  String get recapFhs => 'Puntuación financiera';

  @override
  String get recapOnTrack => 'Presupuesto en orden esta semana.';

  @override
  String get recapOverBudget =>
      'Presupuesto superado esta semana — revisa las partidas principales.';

  @override
  String get recapUnderBudget =>
      'Has gastado menos de lo previsto — ¡buen control!';

  @override
  String get recapNoData =>
      'No hay suficientes datos de presupuesto esta semana.';

  @override
  String recapDaysActive(String count) {
    return '$count día(s) activo(s) esta semana.';
  }

  @override
  String recapGoalsActive(String count) {
    return '$count objetivo(s) en curso.';
  }

  @override
  String recapFhsUp(String delta) {
    return 'Puntuación subió +$delta puntos.';
  }

  @override
  String recapFhsDown(String delta) {
    return 'Puntuación bajó $delta puntos.';
  }

  @override
  String get recapFhsStable => 'Puntuación estable esta semana.';

  @override
  String get recapTitle => 'Tu resumen semanal';

  @override
  String recapPeriod(String start, String end) {
    return 'Del $start al $end';
  }

  @override
  String get recapBudgetTitle => 'Presupuesto';

  @override
  String get recapBudgetSaved => 'Ahorrado esta semana';

  @override
  String get recapBudgetRate => 'Tasa de ahorro';

  @override
  String get recapActionsTitle => 'Acciones realizadas';

  @override
  String get recapActionsNone => 'Ninguna acción esta semana';

  @override
  String get recapProgressTitle => 'Progreso';

  @override
  String recapProgressDelta(String delta) {
    return '$delta pts de confianza';
  }

  @override
  String get recapHighlightsTitle => 'Puntos destacados';

  @override
  String get recapNextFocusTitle => 'La semana que viene';

  @override
  String get recapEmpty => 'Aún no hay datos esta semana';

  @override
  String get decesProcheTitre => 'Fallecimiento de un familiar';

  @override
  String get decesProcheMoisRepudiation =>
      'meses para aceptar o repudiar la sucesión (CC art. 567)';

  @override
  String get decesProche48hTitre => 'Urgente: primeras 48 horas';

  @override
  String get decesProche48hActe =>
      'Obtener el certificado de defunción del registro civil';

  @override
  String get decesProche48hBanque =>
      'Informar al banco — las cuentas se bloquean tras la notificación';

  @override
  String get decesProche48hAssurance =>
      'Contactar las aseguradoras (vida, salud, hogar)';

  @override
  String get decesProche48hEmployeur =>
      'Notificar al empleador del fallecido por el saldo salarial';

  @override
  String get decesProcheSituation => 'Tu situación';

  @override
  String get decesProcheLienParente => 'Parentesco con el fallecido';

  @override
  String get decesProcheLienConjoint => 'Cónyuge';

  @override
  String get decesProcheLienParent => 'Padre/Madre';

  @override
  String get decesProcheLienEnfant => 'Hijo/a';

  @override
  String get decesProcheFortune => 'Patrimonio estimado del fallecido';

  @override
  String get decesProcheCanton => 'Cantón';

  @override
  String get decesProchTestament => 'Existe un testamento';

  @override
  String get decesProchTimelineTitre => 'Cronología de la sucesión';

  @override
  String get decesProchTimeline1Titre => 'Certificado de defunción y bloqueo';

  @override
  String get decesProchTimeline1Desc =>
      'El registro civil emite el certificado. Las cuentas bancarias se bloquean.';

  @override
  String get decesProchTimeline2Titre => 'Inventario y notario';

  @override
  String get decesProchTimeline2Desc =>
      'El notario abre la sucesión y establece el inventario de bienes.';

  @override
  String get decesProchTimeline3Titre => 'Plazo de repudiación';

  @override
  String get decesProchTimeline3Desc =>
      '3 meses para aceptar o repudiar (CC art. 567). Pasado este plazo, la sucesión se acepta.';

  @override
  String get decesProchTimeline4Titre => 'Reparto e impuestos';

  @override
  String get decesProchTimeline4Desc =>
      'Declaración de sucesión y pago del impuesto cantonal (si aplica).';

  @override
  String get decesProchebeneficiairesTitre => 'Beneficiarios LPP y 3a';

  @override
  String get decesProchebeneficiairesLpp => 'Capital LPP del fallecido';

  @override
  String get decesProchebeneficiaires3a => 'Capital 3a del fallecido';

  @override
  String get decesProchebeneficiairesNote =>
      'El orden de beneficiarios LPP lo fija el reglamento de la caja (OPP2 art. 48). El 3a sigue la OPP3 art. 2.';

  @override
  String get decesProchImpactFiscalTitre => 'Impacto fiscal';

  @override
  String decesProchImpactFiscalExempt(String canton) {
    return 'En $canton, el cónyuge sobreviviente está exento del impuesto de sucesión.';
  }

  @override
  String decesProchImpactFiscalTaxe(String canton) {
    return 'En $canton, los herederos están sujetos al impuesto cantonal de sucesión. La tasa varía según el grado de parentesco.';
  }

  @override
  String get decesProchActionsTitre => 'Próximos pasos';

  @override
  String get decesProchAction1 =>
      'Reunir documentos: certificado de defunción, testamento, certificados LPP y 3a';

  @override
  String get decesProchAction2 =>
      'Consultar un notario para el inventario sucesorio';

  @override
  String get decesProchAction3 =>
      'Verificar los beneficiarios LPP y 3a con las cajas';

  @override
  String get decesProchDisclaimer =>
      'Herramienta educativa — no constituye asesoramiento legal o fiscal (LSFin). Cada sucesión es única: consulta a un notario o especialista. Fuentes: CC art. 457-640, OPP2 art. 48, OPP3 art. 2.';

  @override
  String get demenagementTitre => 'Mudanza cantonal';

  @override
  String get demenagementChiffreChocSousTitre =>
      'ahorro (o sobrecosto) anual estimado';

  @override
  String demenagementChiffreChocDetail(String depart, String arrivee) {
    return 'Al mudarte de $depart a $arrivee (impuestos + seguro de salud)';
  }

  @override
  String get demenagementSituation => 'Tu situación';

  @override
  String get demenagementCantonDepart => 'Cantón actual';

  @override
  String get demenagementCantonArrivee => 'Cantón de destino';

  @override
  String get demenagementRevenu => 'Ingreso bruto anual';

  @override
  String get demenagementCelibataire => 'Soltero/a';

  @override
  String get demenagementMarie => 'Casado/a';

  @override
  String get demenagementFiscalTitre => 'Comparación fiscal';

  @override
  String get demenagementEconomieFiscale => 'Ahorro fiscal estimado';

  @override
  String get demenagementLamalTitre => 'Primas de seguro de salud';

  @override
  String get demenagementChecklistTitre => 'Checklist de mudanza';

  @override
  String get demenagementChecklist1 =>
      'Notificar la partida al municipio de origen (8 días antes)';

  @override
  String get demenagementChecklist2 =>
      'Registrarse en el nuevo municipio (dentro de 8 días)';

  @override
  String get demenagementChecklist3 =>
      'Cambiar de seguro de salud o actualizar la región de prima';

  @override
  String get demenagementChecklist4 =>
      'Adaptar la declaración fiscal (imposición al 31.12)';

  @override
  String get demenagementChecklist5 =>
      'Verificar las asignaciones familiares cantonales';

  @override
  String get demenagementDisclaimer =>
      'Herramienta educativa — no constituye asesoramiento fiscal (LSFin). Las cifras son estimaciones basadas en índices cantonales simplificados. Consulta a un especialista. Fuentes: LIFD, LAMal, baremos cantonales 2025.';

  @override
  String get docScanAppBarTitle => 'ESCANEAR UN DOCUMENTO';

  @override
  String get docScanHeaderTitle => 'Mejora la precisión de tu perfil';

  @override
  String get docScanHeaderSubtitle =>
      'Fotografía un documento financiero y extraemos las cifras por ti. Verificas cada valor antes de confirmar.';

  @override
  String get docScanDocumentType => 'Tipo de documento';

  @override
  String docScanConfidencePoints(int points) {
    return '+$points puntos de confianza';
  }

  @override
  String get docScanFromGallery => 'Desde la galería';

  @override
  String get docScanPasteOcrText => 'Pegar texto OCR';

  @override
  String get docScanUseExample => 'Usar un ejemplo de prueba';

  @override
  String get docScanPrivacyNote =>
      'La imagen se analiza localmente (OCR en el dispositivo). Si usas el análisis Vision IA, la imagen se envía a tu proveedor IA mediante tu propia clave API. Solo los valores confirmados se conservan en tu perfil.';

  @override
  String get docScanCameraError =>
      'No se pudo abrir la cámara. Usa la galería.';

  @override
  String get docScanEmptyTextFile => 'El archivo de texto está vacío.';

  @override
  String get docScanFileUnreadableTitle => 'Archivo no utilizable';

  @override
  String get docScanFileUnreadableMessage =>
      'No pudimos leer este archivo directamente desde tu dispositivo. Toma una foto del documento o pega un texto OCR.';

  @override
  String docScanImportError(String error) {
    return 'No se pudo importar el archivo: $error';
  }

  @override
  String get docScanOcrNotDetectedTitle => 'Texto no detectado';

  @override
  String get docScanOcrNotDetectedMessage =>
      'No pudimos leer suficiente texto de la foto.';

  @override
  String get docScanPhotoAnalysisTitle => 'Análisis de foto no disponible';

  @override
  String get docScanPhotoAnalysisMessage =>
      'No pudimos extraer el texto automáticamente. Reintenta con una foto más nítida o pega el texto OCR.';

  @override
  String get docScanNoFieldRecognized =>
      'Ningún campo reconocido automáticamente';

  @override
  String get docScanNoFieldHint =>
      'Añade o corrige el texto OCR para mejorar el análisis, luego reintenta.';

  @override
  String docScanParsingError(String error) {
    return 'Parsing imposible para este documento: $error';
  }

  @override
  String get docScanOcrPasteHint => 'Pega aquí el texto OCR bruto…';

  @override
  String get docScanPdfDetected => 'PDF detectado';

  @override
  String get docScanPdfCannotRead =>
      'No se puede leer este PDF directamente en este dispositivo. Toma una foto del documento o pega un texto OCR.';

  @override
  String get docScanPdfAnalysisUnavailable => 'Análisis PDF no disponible';

  @override
  String get docScanPdfNotParsed =>
      'El PDF no pudo ser analizado automáticamente. Puedes tomar una foto (recomendado) o pegar un texto OCR.';

  @override
  String get docScanPdfNotAvailable =>
      'El parsing PDF no está disponible en este contexto. Toma una foto o pega un texto OCR.';

  @override
  String get docScanPdfOptimizedLpp =>
      'Por el momento, el parsing PDF automático está optimizado principalmente para certificados LPP. Toma una foto del documento.';

  @override
  String get docScanPdfTypeUnsupported =>
      'Tipo de documento no compatible con el parsing PDF.';

  @override
  String get docScanPdfNoData => 'No se extrajo ningún dato útil de este PDF.';

  @override
  String docScanPdfBackendError(String error) {
    return 'Error del backend durante el parsing PDF: $error';
  }

  @override
  String get docScanBackendDisclaimer =>
      'Datos extraídos automáticamente: verifica cada valor antes de confirmar.';

  @override
  String get docScanBackendDisclaimerShort =>
      'Verifica los montos antes de confirmar. Herramienta educativa (LSFin).';

  @override
  String get docScanVisionAnalyze => 'Analizar con Vision IA';

  @override
  String get docScanVisionDisclaimer =>
      'La imagen será enviada a tu proveedor IA mediante tu clave API.';

  @override
  String get docScanVisionNoFields =>
      'La IA no pudo extraer campos de este documento.';

  @override
  String get docScanVisionDefaultDisclaimer =>
      'Datos extraídos por IA: verifica cada valor. Herramienta educativa, no constituye un consejo (LSFin).';

  @override
  String get docScanVisionConfigError =>
      'Configura una clave API en los ajustes del Coach.';

  @override
  String docScanVisionError(String error) {
    return 'Error Vision IA: $error';
  }

  @override
  String get docScanLabelLppTotal => 'Total LPP';

  @override
  String get docScanLabelObligatoire => 'Parte obligatoria';

  @override
  String get docScanLabelSurobligatoire => 'Parte supraobligatoria';

  @override
  String get docScanLabelTauxConvOblig => 'Tasa de conversión obligatoria';

  @override
  String get docScanLabelTauxConvSuroblig =>
      'Tasa de conversión supraobligatoria';

  @override
  String get docScanLabelRachatMax => 'Rescate máximo';

  @override
  String get docScanLabelSalaireAssure => 'Salario asegurado';

  @override
  String get docScanLabelTauxRemuneration => 'Tasa de remuneración';

  @override
  String get docImpactTitle => 'Tu perfil es más preciso';

  @override
  String docImpactSubtitle(String docType) {
    return 'Los valores de tu $docType han sido integrados en tus proyecciones.';
  }

  @override
  String get docImpactConfidenceLabel => '% confianza';

  @override
  String docImpactDeltaPoints(int points) {
    return '+$points puntos de confianza';
  }

  @override
  String get docImpactChiffreChocTitle => 'Cifra clave recalculada';

  @override
  String docImpactLppRealAmount(String oblig) {
    return 'de activos LPP reales (de los cuales $oblig obligatorios)';
  }

  @override
  String docImpactRenteOblig(String amount) {
    return 'Renta obligatoria al 6.8%: CHF $amount/año';
  }

  @override
  String docImpactSurobligWithRate(String suroblig, String rate, String rente) {
    return 'Parte supraobligatoria (CHF $suroblig) al $rate% = CHF $rente/año';
  }

  @override
  String docImpactSurobligNoRate(String suroblig) {
    return 'Parte supraobligatoria (CHF $suroblig) = tasa de conversión libre de la caja';
  }

  @override
  String docImpactAvsYears(int years) {
    return '$years años de cotización';
  }

  @override
  String docImpactAvsCompletion(int maxYears, int pct) {
    return 'de $maxYears necesarios para una renta AVS completa ($pct%)';
  }

  @override
  String get docImpactGenericMessage =>
      'Tus proyecciones ahora se basan en valores reales.';

  @override
  String get docImpactFieldsUpdated => 'Campos actualizados';

  @override
  String get docImpactReturnDashboard => 'Volver al dashboard';

  @override
  String get docImpactDisclaimer =>
      'Herramienta educativa — no constituye consejo de previsión. Verifica siempre con tu certificado original (LSFin).';

  @override
  String get extractionReviewAppBar => 'VERIFICACIÓN';

  @override
  String get extractionReviewTitle => 'Verifica los valores extraídos';

  @override
  String extractionReviewSubtitle(int count, String reviewPart) {
    return '$count campos detectados$reviewPart. Puedes modificar cada valor antes de confirmar.';
  }

  @override
  String extractionReviewNeedsReview(int count) {
    return ' de los cuales $count a verificar';
  }

  @override
  String extractionReviewConfidence(int pct) {
    return 'Confianza de extracción: $pct%';
  }

  @override
  String extractionReviewSourcePrefix(String text) {
    return 'Leído: \"$text\"';
  }

  @override
  String get extractionReviewConfirmAll => 'Confirmar todo';

  @override
  String extractionReviewEditTitle(String label) {
    return 'Modificar: $label';
  }

  @override
  String extractionReviewCurrentValue(String value) {
    return 'Valor actual: $value';
  }

  @override
  String get extractionReviewNewValue => 'Nuevo valor';

  @override
  String get extractionReviewCancel => 'Cancelar';

  @override
  String get extractionReviewValidate => 'Validar';

  @override
  String get extractionReviewEditTooltip => 'Modificar';

  @override
  String get firstSalaryFilmTitle => 'La película de tu primer salario';

  @override
  String firstSalaryFilmSubtitle(String amount) {
    return 'CHF $amount bruto — 5 actos para entender todo.';
  }

  @override
  String get firstSalaryAct1Label => '1 · Bruto→Neto';

  @override
  String get firstSalaryAct2Label => '2 · Invisible';

  @override
  String get firstSalaryAct3Label => '3 · 3a';

  @override
  String get firstSalaryAct4Label => '4 · LAMal';

  @override
  String get firstSalaryAct5Label => '5 · Acción';

  @override
  String get firstSalaryAct1Title => 'La ducha fría';

  @override
  String firstSalaryAct1Quote(String amount) {
    return '$amount CHF desaparecen. Pero no se pierden — es tu futuro.';
  }

  @override
  String firstSalaryGross(String amount) {
    return 'Bruto: CHF $amount';
  }

  @override
  String firstSalaryNet(String amount) {
    return 'Neto: CHF $amount';
  }

  @override
  String firstSalaryNetPercent(int pct) {
    return '$pct% neto';
  }

  @override
  String get firstSalaryAct2Title => 'El dinero invisible';

  @override
  String firstSalaryAct2Quote(String amount) {
    return 'Tu salario real es CHF $amount. Tu empleador paga mucho más de lo que crees.';
  }

  @override
  String get firstSalaryVisibleNet => '🌊 Visible: tu salario neto';

  @override
  String get firstSalaryVisibleNetSub => 'Lo que recibes';

  @override
  String get firstSalaryCotisations => '💧 Tus cotizaciones';

  @override
  String get firstSalaryCotisationsSub => 'Deducidas de tu bruto';

  @override
  String get firstSalaryEmployerCotisations => '🏔️ Cotizaciones del empleador';

  @override
  String get firstSalaryEmployerCotisationsSub => 'Invisibles en tu nómina';

  @override
  String get firstSalaryTotalEmployerCost => 'Coste total empleador';

  @override
  String get firstSalaryAct3Title => 'El regalo fiscal 3a';

  @override
  String firstSalaryAct3Quote(String amount) {
    return 'CHF $amount/mes → potencialmente millonario. Empieza ahora.';
  }

  @override
  String get firstSalaryAt30 => 'A los 30';

  @override
  String get firstSalaryAt40 => 'A los 40';

  @override
  String get firstSalaryAt65 => 'A los 65';

  @override
  String get firstSalary3aInfo =>
      '💰 Tope 2026: CHF 7\'258/año · Deducción fiscal directa · OPP3 art. 7';

  @override
  String get firstSalaryAct4Title => 'La trampa LAMal';

  @override
  String get firstSalaryAct4Quote =>
      'La franquicia barata puede costarte caro si te enfermas.';

  @override
  String get firstSalaryFranchise300Advice =>
      'Recomendado si enfermedades crónicas';

  @override
  String get firstSalaryFranchise1500Advice => 'Buen compromiso · Recomendado';

  @override
  String get firstSalaryFranchise2500Advice =>
      'Ahorra en prima · Si tienes buena salud';

  @override
  String firstSalaryFranchiseLabel(String label) {
    return 'Franquicia $label';
  }

  @override
  String firstSalaryFranchisePrime(String amount) {
    return '−CHF $amount/mes prima';
  }

  @override
  String get firstSalaryLamalInfo =>
      '💡 LAMal art. 64 — Franquicia anual elegida, renovable cada año.';

  @override
  String get firstSalaryAct5Title => 'Tu checklist de inicio';

  @override
  String get firstSalaryAct5Quote =>
      '5 acciones. Eso es todo. Empieza esta semana.';

  @override
  String get firstSalaryWeek1 => 'Semana 1';

  @override
  String get firstSalaryWeek2 => 'Semana 2';

  @override
  String get firstSalaryBefore31Dec => 'Antes del 31.12';

  @override
  String get firstSalaryTask1 => 'Abrir una cuenta 3a (banco o fintech)';

  @override
  String get firstSalaryTask2 =>
      'Configurar una transferencia automática mensual';

  @override
  String get firstSalaryTask3 =>
      'Elegir tu franquicia LAMal (recomendado: CHF 1\'500)';

  @override
  String get firstSalaryTask4 => 'Verificar tu RC privada (aprox. CHF 100/año)';

  @override
  String get firstSalaryTask5 =>
      'Ingresar el máximo 3a antes del 31 de diciembre';

  @override
  String get firstSalaryBadgeTitle => 'Primer paso financiero';

  @override
  String get firstSalaryBadgeSubtitle =>
      'Ahora sabes lo que el 90% de la gente nunca sabe.';

  @override
  String get firstSalaryDisclaimer =>
      'Herramienta educativa · no constituye consejo financiero (LSFin). Fuente: LAVS art. 3, LPP art. 7, LACI art. 3, OPP3 art. 7 (3a 7\'258 CHF/año). Tasas de cotización indicativas 2026. Proyección 3a: rendimiento hipotético 4%/año.';

  @override
  String get benchmarkAppBarTitle => 'Referentes cantonales';

  @override
  String get benchmarkOptInTitle => 'Activar comparaciones cantonales';

  @override
  String get benchmarkOptInSubtitle =>
      'Compara tu situación con órdenes de magnitud de estadísticas federales (OFS).';

  @override
  String get benchmarkExplanationTitle => 'Referentes, no un ranking';

  @override
  String get benchmarkExplanationBody =>
      'Activa esta funcionalidad para situar tu situación financiera respecto a perfiles similares en tu cantón. Son órdenes de magnitud de estadísticas federales anonimizadas (OFS). Sin ranking, sin comparación social.';

  @override
  String get benchmarkNoProfile =>
      'Completa tu perfil para acceder a los referentes cantonales.';

  @override
  String benchmarkNoData(String canton, String ageGroup) {
    return 'No hay datos disponibles para el cantón $canton (grupo de edad $ageGroup).';
  }

  @override
  String benchmarkSimilarProfiles(String canton, String ageGroup) {
    return 'Perfiles similares: $canton, grupo de edad $ageGroup';
  }

  @override
  String benchmarkSourceLabel(String source) {
    return 'Fuente: $source';
  }

  @override
  String get benchmarkWithinRange =>
      'Tu situación está dentro del rango típico.';

  @override
  String get benchmarkAboveRange =>
      'Tu situación está por encima del rango típico.';

  @override
  String get benchmarkBelowRange =>
      'Tu situación está por debajo del rango típico.';

  @override
  String benchmarkTypicalRange(String low, String high) {
    return 'Rango típico: $low – $high';
  }

  @override
  String get tabPulse => 'Pulse';

  @override
  String get authGateDocScanTitle => 'Protege tus documentos';

  @override
  String get authGateDocScanMessage =>
      'Tus certificados contienen datos sensibles. Crea una cuenta para protegerlos con cifrado de extremo a extremo.';

  @override
  String get authGateSalaryTitle => 'Protege tus datos financieros';

  @override
  String get authGateSalaryMessage =>
      'Tu salario y tus datos financieros merecen una caja fuerte segura.';

  @override
  String get authGateCoachTitle => 'El coach necesita conocerte';

  @override
  String get authGateCoachMessage =>
      'Para darte respuestas personalizadas, el coach necesita una cuenta.';

  @override
  String get authGateGoalTitle => 'Sigue tu progreso';

  @override
  String get authGateGoalMessage =>
      'Para seguir tus objetivos a lo largo del tiempo, crea tu cuenta.';

  @override
  String get authGateSimTitle => 'Guarda tu simulación';

  @override
  String get authGateSimMessage =>
      'Para encontrar esta simulación más tarde, crea tu cuenta.';

  @override
  String get authGateByokTitle => 'Protege tu clave API';

  @override
  String get authGateByokMessage =>
      'Tu clave API será cifrada en tu espacio seguro.';

  @override
  String get authGateCoupleTitle => 'El modo pareja requiere una cuenta';

  @override
  String get authGateCoupleMessage =>
      'Para invitar a tu pareja, primero crea tu cuenta personal.';

  @override
  String get authGateProfileTitle => 'Enriquece tu perfil de forma segura';

  @override
  String get authGateProfileMessage =>
      'Cuanto más enriquezcas tu perfil, más precisas serán tus proyecciones. Protege tus datos.';

  @override
  String get authGateCreateAccount => 'Crear mi cuenta';

  @override
  String get authGateLogin => 'Ya tengo una cuenta';

  @override
  String get authGatePrivacyNote =>
      'Tus datos permanecen en tu dispositivo y están cifrados.';

  @override
  String get budgetTaxProvisionNotProvided =>
      'Provisión impuestos (no indicado)';

  @override
  String get budgetHealthInsuranceNotProvided =>
      'Seguro médico (LAMal) (no indicado)';

  @override
  String get budgetOtherFixedCosts => 'Otros gastos fijos';

  @override
  String get budgetOtherFixedCostsNotProvided =>
      'Otros gastos fijos (no indicado)';

  @override
  String get budgetQualityProvided => 'ingresado';

  @override
  String get budgetBannerMissing =>
      'Algunos gastos aún faltan. Completa tu diagnóstico para un presupuesto más fiable.';

  @override
  String get budgetBannerEstimated =>
      'Este presupuesto incluye estimaciones (impuestos/LAMal). Ingresa tus montos reales.';

  @override
  String get budgetCompleteMyData => 'Completar mis datos →';

  @override
  String get budgetEmergencyFundTitle => 'Fondo de emergencia';

  @override
  String get budgetGoalReached => 'Objetivo alcanzado';

  @override
  String get budgetOnTrack => 'Buen camino';

  @override
  String get budgetToReinforce => 'A reforzar';

  @override
  String budgetMonthsCovered(String months) {
    return '$months meses cubiertos';
  }

  @override
  String budgetTargetMonths(String target) {
    return 'Objetivo: $target meses';
  }

  @override
  String get budgetEmergencyProtected =>
      'Estás protegido contra imprevistos. Sigue así.';

  @override
  String budgetEmergencySaveMore(String target) {
    return 'Ahorra al menos $target meses de gastos para protegerte contra imprevistos.';
  }

  @override
  String get budgetExploreAlso => 'Explorar también';

  @override
  String get budgetDebtRatio => 'Ratio de endeudamiento';

  @override
  String get budgetDebtRatioSubtitle => 'Evaluar tu situación de deuda';

  @override
  String get budgetRepaymentPlan => 'Plan de reembolso';

  @override
  String get budgetRepaymentPlanSubtitle => 'Estrategia para salir de la deuda';

  @override
  String get budgetHelpResources => 'Recursos de ayuda';

  @override
  String get budgetHelpResourcesSubtitle => 'Dónde encontrar ayuda en Suiza';

  @override
  String get budgetCtaEvaluate => 'Evaluar';

  @override
  String get budgetCtaPlan => 'Planificar';

  @override
  String get budgetCtaDiscover => 'Descubrir';

  @override
  String get budgetDisclaimerImportant => 'IMPORTANTE:';

  @override
  String get budgetDisclaimerBased =>
      '• Los montos se basan en la información declarada.';

  @override
  String get refreshReturnToDashboard => 'Volver al panel';

  @override
  String get refreshOptionNone => 'Ninguno';

  @override
  String get refreshOptionPurchase => 'Compra';

  @override
  String get refreshOptionSale => 'Venta';

  @override
  String get refreshOptionRefinancing => 'Refinanciación';

  @override
  String get refreshOptionMarriage => 'Matrimonio';

  @override
  String get refreshOptionBirth => 'Nacimiento';

  @override
  String get refreshOptionDivorce => 'Divorcio';

  @override
  String get refreshOptionDeath => 'Fallecimiento';

  @override
  String get refreshProfileUpdated => '¡Perfil actualizado!';

  @override
  String refreshScoreUp(String delta) {
    return '¡Tu puntuación subió $delta puntos!';
  }

  @override
  String refreshScoreDown(String delta) {
    return 'Tu puntuación bajó $delta puntos — veamos juntos';
  }

  @override
  String get refreshScoreStable => 'Tu puntuación es estable — ¡sigue así!';

  @override
  String get refreshBefore => 'Antes';

  @override
  String get refreshAfter => 'Después';

  @override
  String get chiffreChocDisclaimer =>
      'Herramienta educativa — no constituye consejo financiero (LSFin). Fuentes: LAVS art. 34, LPP art. 14-16, OPP3 art. 7.';

  @override
  String get chiffreChocAction => '¿Qué puedo hacer?';

  @override
  String get chiffreChocEnrich => 'Afinar mi perfil';

  @override
  String chiffreChocConfidence(String count) {
    return 'Estimación basada en $count informaciones. Cuanto más precises, más fiable.';
  }

  @override
  String get chatErrorInvalidKey =>
      'Tu clave API parece inválida o expirada. Verifícala en los ajustes.';

  @override
  String get chatErrorRateLimit =>
      'Límite de solicitudes alcanzado. Inténtalo en unos instantes.';

  @override
  String get chatErrorTechnical => 'Error técnico. Inténtalo más tarde.';

  @override
  String get chatErrorConnection =>
      'Error de conexión. Verifica tu conexión a internet o tu clave API.';

  @override
  String get chatCoachMint => 'Coach MINT';

  @override
  String get chatEmptyStateMessage =>
      'Completa tu diagnóstico para hablar con tu coach';

  @override
  String get chatStartButton => 'Empezar';

  @override
  String get chatDisclaimer =>
      'Herramienta educativa — las respuestas no constituyen consejo financiero. LSFin.';

  @override
  String get chatTooltipHistory => 'Historial';

  @override
  String get chatTooltipExport => 'Exportar conversación';

  @override
  String get chatTooltipSettings => 'Ajustes IA';

  @override
  String get slmChooseModel => 'Elige tu modelo';

  @override
  String get slmTwoSizesAvailable =>
      'Dos tamaños disponibles según tu dispositivo';

  @override
  String get slmRecommended => 'Recomendado';

  @override
  String get slmDownloadFailedMessage =>
      'La descarga falló. Verifica tu conexión WiFi y el espacio disponible.';

  @override
  String get slmInitError =>
      'Error de inicialización del modelo. Verifica que tu dispositivo sea compatible.';

  @override
  String get slmInitializing => 'Inicializando...';

  @override
  String get slmInitEngine => 'Inicializar motor';

  @override
  String get disabilityYourSituation => 'Tu situación';

  @override
  String get disabilityGrossMonthly => 'Salario bruto mensual';

  @override
  String get disabilityYourAge => 'Tu edad';

  @override
  String get disabilityAvailableSavings => 'Ahorro disponible';

  @override
  String get disabilityHasIjm => 'Tengo un seguro IJM a través de mi empleador';

  @override
  String get disabilityExploreAlso => 'Explorar también';

  @override
  String get disabilityCoverageInsurance => 'Cobertura de seguro';

  @override
  String get disabilityCoverageSubtitle => 'IJM, AI, LPP — tu boletín de notas';

  @override
  String get disabilitySelfEmployed => 'Independiente';

  @override
  String get disabilitySelfEmployedSubtitle => 'Riesgos específicos sin LPP';

  @override
  String get disabilityCtaEvaluate => 'Evaluar';

  @override
  String get disabilityCtaAnalyze => 'Analizar';

  @override
  String get disabilityAppBarTitle => 'Si ya no puedo trabajar';

  @override
  String get disabilityStatLine1 => '1 de cada 5 personas';

  @override
  String get disabilityStatLine2 => 'será afectada antes de los 65 años';

  @override
  String get authRegisterSubtitle =>
      'Cuenta opcional: tus datos permanecen locales por defecto';

  @override
  String get authWhyCreateAccount => '¿Por qué crear una cuenta?';

  @override
  String get authBenefitProjections =>
      'Proyecciones AVS/LPP adaptadas a tu situación';

  @override
  String get authBenefitCoach => 'Coach personalizado con tu nombre';

  @override
  String get authBenefitSync =>
      'Copia de seguridad + sincronización multi-dispositivo';

  @override
  String get authFirstName => 'Nombre';

  @override
  String get authFirstNameRequired =>
      'El nombre es necesario para personalizar tu coach';

  @override
  String get authBirthYear => 'Año de nacimiento';

  @override
  String get authBirthYearRequired => 'Necesario para las proyecciones AVS/LPP';

  @override
  String get authPasswordRequirements =>
      'Usa al menos 8 caracteres para asegurar tu cuenta';

  @override
  String get authCguAccept => 'He leído y acepto los ';

  @override
  String get authCguLink => 'Términos y Condiciones';

  @override
  String get authCguAndPrivacy => ' y la ';

  @override
  String get authPrivacyLink => 'Política de privacidad';

  @override
  String get authConfirm18 =>
      'Confirmo que tengo 18 años cumplidos (T&C art. 4.1)';

  @override
  String get authConsentSection => 'Consentimientos opcionales';

  @override
  String get authConsentNotifications =>
      'Notificaciones de coaching (recordatorios 3a, plazos fiscales)';

  @override
  String get authConsentAnalytics =>
      'Datos anónimos para mejorar los benchmarks suizos';

  @override
  String get authPasswordWeak => 'Débil';

  @override
  String get authPasswordMedium => 'Medio';

  @override
  String get authPasswordStrong => 'Fuerte';

  @override
  String get authPasswordVeryStrong => 'Muy fuerte';

  @override
  String get authOrContinueWith => 'o continuar con';

  @override
  String get authPrivacyReassurance =>
      'Tus datos permanecen cifrados en tu dispositivo. Sin conexión bancaria.';

  @override
  String get authContinueLocal => 'Continuar en modo local';

  @override
  String get authBack => 'Volver';

  @override
  String coachGreetingSlm(String name) {
    return 'Hola $name. Todo se queda en tu dispositivo — nada sale. ¿Qué tienes en mente ?';
  }

  @override
  String coachGreetingDefault(String name, String scoreSuffix) {
    return 'Hola $name. Estoy mirando tus cifras — cuéntame qué te preocupa.$scoreSuffix';
  }

  @override
  String coachScoreSuffix(int score) {
    return ' Tu puntuación: $score/100 — veamos dónde falla.';
  }

  @override
  String get coachComplianceError =>
      'No pude formular una respuesta conforme. Reformula tu pregunta o explora los simuladores.';

  @override
  String get coachErrorInvalidKey =>
      'Tu clave API parece inválida o caducada. Verifícala en los ajustes.';

  @override
  String get coachErrorRateLimit =>
      'Límite de solicitudes alcanzado. Inténtalo de nuevo en un momento.';

  @override
  String get coachErrorGeneric => 'Error técnico. Inténtalo más tarde.';

  @override
  String get coachErrorBadRequest =>
      'Solicitud no válida. Intenta reformular tu pregunta.';

  @override
  String get coachErrorServiceUnavailable =>
      'Servicio temporalmente no disponible. Inténtalo en unos minutos.';

  @override
  String get coachErrorConnection =>
      'Error de conexión. Verifica tu conexión a internet o tu clave API.';

  @override
  String get coachSuggestSimulate3a => '¿Cuánto ahorro si aporto el máximo?';

  @override
  String get coachSuggestView3a => '¿Cuánto tengo en mis cuentas 3a?';

  @override
  String get coachSuggestSimulateLpp => '¿Me conviene hacer un rescate LPP?';

  @override
  String get coachSuggestUnderstandLpp =>
      '¿Qué voy a cobrar realmente a los 65?';

  @override
  String get coachSuggestTrajectory => '¿Qué pasa si no hago nada?';

  @override
  String get coachSuggestScenarios => 'Renta o capital — ¿qué me conviene?';

  @override
  String get coachSuggestDeductions =>
      '¿Cuánto recupero de impuestos este año?';

  @override
  String get coachSuggestTaxImpact =>
      '¿Cuántos impuestos menos con un rescate?';

  @override
  String get coachSuggestFitness => '¿Voy bien respecto a mi objetivo?';

  @override
  String get coachSuggestRetirement =>
      '¿Tendré suficiente para vivir jubilado?';

  @override
  String get coachEmptyStateMessage =>
      'Aún sin perfil. Tres preguntas, y hablamos.';

  @override
  String get coachEmptyStateButton => 'Hacer mi diagnóstico';

  @override
  String get coachTooltipHistory => 'Historial';

  @override
  String get coachTooltipExport => 'Exportar conversación';

  @override
  String get coachTooltipSettings => 'Ajustes de IA';

  @override
  String get coachTooltipLifeEvent => 'Evento de vida';

  @override
  String get coachTierSlm => 'IA en dispositivo';

  @override
  String get coachTierByok => 'IA nube (BYOK)';

  @override
  String get coachTierFallback => 'Modo sin conexión';

  @override
  String get coachBadgeSlm => 'En dispositivo';

  @override
  String get coachBadgeByok => 'Nube';

  @override
  String get coachBadgeFallback => 'Sin conexión';

  @override
  String get coachDisclaimer =>
      'Herramienta educativa — las respuestas no constituyen asesoramiento financiero (LSFin art. 3). Consulta a un especialista para decisiones importantes.';

  @override
  String get coachLoading => 'Mirando tus cifras…';

  @override
  String get coachSources => 'Fuentes';

  @override
  String get coachInputHint => '¿Una pregunta sobre tus finanzas?';

  @override
  String get coachTitle => 'Coach MINT';

  @override
  String get coachFallbackName => 'amigo/a';

  @override
  String get coachUserMessage => 'Tu mensaje';

  @override
  String get coachCoachMessage => 'Respuesta del coach';

  @override
  String get coachSendButton => 'Enviar';

  @override
  String get profileDefaultName => 'Usuario';

  @override
  String profileNameAge(String name, int age) {
    return '$name, $age años';
  }

  @override
  String get commonEdit => 'Editar';

  @override
  String get profileSlmTitle => 'IA en dispositivo (SLM)';

  @override
  String get profileSlmReady => 'Modelo listo';

  @override
  String get profileSlmNotInstalled => 'Modelo no instalado';

  @override
  String get profileDeleteAccountSuccess => 'Cuenta eliminada con éxito.';

  @override
  String get profileDeleteAccountError =>
      'Eliminación imposible por el momento. Inténtalo más tarde.';

  @override
  String get profileChangeLanguage => 'Cambiar idioma';

  @override
  String profileDocCount(int count) {
    return '$count documento(s)';
  }

  @override
  String get tabToday => 'Hoy';

  @override
  String get tabDossier => 'Expediente';

  @override
  String get affordabilityInsightRevenueTitle =>
      'Lo que te limita: tus ingresos, no tu capital propio';

  @override
  String affordabilityInsightRevenueBody(
      String chargesTheoriques, String chargesReelles) {
    return 'Los bancos suizos calculan con una tasa teórica del 5 % (directiva ASB), aunque la tasa real del mercado es mucho menor. Es una prueba de resistencia: verifican que podrías asumir los cargos si las tasas subieran. Tus cargos teóricos: $chargesTheoriques/mes. A tasa de mercado (~1,5 %): $chargesReelles/mes.';
  }

  @override
  String get affordabilityInsightEquityTitle =>
      'Lo que te limita: tu capital propio';

  @override
  String affordabilityInsightEquityBody(String manque) {
    return 'Te faltan aproximadamente CHF $manque de capital propio para alcanzar el mínimo del 20 % exigido por los bancos.';
  }

  @override
  String get affordabilityInsightOkTitle =>
      'Buena noticia: ambos criterios se cumplen';

  @override
  String get affordabilityInsightOkBody =>
      'Tus ingresos y capital propio te permiten acceder a esta propiedad. Compara los tipos de hipoteca y las estrategias de amortización.';

  @override
  String affordabilityInsightLppCap(String lppUtilise, String lppTotal) {
    return 'Tu 2.º pilar está limitado: solo CHF $lppUtilise de $lppTotal cuentan (máx. 10 % del precio, regla ASB).';
  }

  @override
  String get tabMint => 'Mint';

  @override
  String get pulseNarrativeRetirementClose =>
      'tu jubilación se acerca. Aquí está tu situación.';

  @override
  String pulseNarrativeYearsToAct(int yearsToRetire) {
    return 'tienes $yearsToRetire años para actuar. Cada año cuenta.';
  }

  @override
  String get pulseNarrativeTimeToBuild =>
      'tienes tiempo para construir. Aquí está tu situación.';

  @override
  String get pulseNarrativeDefault => 'aquí está tu situación financiera.';

  @override
  String get pulseLabelReplacementRate => 'Tasa de reemplazo en la jubilación';

  @override
  String get pulseLabelRetirementIncome => 'Ingreso estimado en la jubilación';

  @override
  String get pulseLabelFinancialScore => 'Puntuación de preparación financiera';

  @override
  String get exploreHubRetraiteTitle => 'Jubilación';

  @override
  String get exploreHubRetraiteSubtitle => 'AVS, LPP, 3a, proyecciones';

  @override
  String get exploreHubFamilleTitle => 'Familia';

  @override
  String get exploreHubFamilleSubtitle => 'Matrimonio, nacimiento, concubinato';

  @override
  String get exploreHubTravailTitle => 'Trabajo & Estatus';

  @override
  String get exploreHubTravailSubtitle => 'Empleo, autónomo, fronterizo';

  @override
  String get exploreHubLogementTitle => 'Vivienda';

  @override
  String get exploreHubLogementSubtitle => 'Hipoteca, compra, venta';

  @override
  String get exploreHubFiscaliteTitle => 'Fiscalidad';

  @override
  String get exploreHubFiscaliteSubtitle => 'Impuestos, comparador cantonal';

  @override
  String get exploreHubPatrimoineTitle => 'Patrimonio & Sucesión';

  @override
  String get exploreHubPatrimoineSubtitle => 'Donación, herencia, asignación';

  @override
  String get exploreHubSanteTitle => 'Salud & Protección';

  @override
  String get exploreHubSanteSubtitle => 'LAMal, invalidez, cobertura';

  @override
  String get dossierDocumentsTitle => 'Documentos';

  @override
  String get dossierDocumentsSubtitle => 'Certificados, extractos, escaneos';

  @override
  String get dossierCoupleTitle => 'Pareja';

  @override
  String get dossierCoupleSubtitle => 'Hogar, cónyuge, proyecciones dúo';

  @override
  String get dossierBilanTitle => 'Balance financiero';

  @override
  String get dossierBilanSubtitle => 'Vista general de tu patrimonio';

  @override
  String get dossierReglages => 'Ajustes';

  @override
  String get dossierConsentsTitle => 'Consentimientos';

  @override
  String get dossierConsentsSubtitle => 'Privacidad y uso compartido de datos';

  @override
  String get dossierAiTitle => 'IA & Coach';

  @override
  String get dossierAiSubtitle => 'Modelo local, clave API';

  @override
  String get dossierStartProfile => 'Comienza tu perfil';

  @override
  String dossierProfileCompleted(int percent) {
    return '$percent % completado';
  }

  @override
  String get exploreHubFeatured => 'Recorridos destacados';

  @override
  String get exploreHubSeeAll => 'Ver todo';

  @override
  String get exploreHubLearnMore => 'Entender este tema';

  @override
  String get retraiteHubFeaturedOverview => 'Resumen jubilación';

  @override
  String get retraiteHubFeaturedOverviewSub =>
      'Tu estimación personalizada en 3 minutos';

  @override
  String get retraiteHubFeaturedRenteCapital => 'Renta vs Capital';

  @override
  String get retraiteHubFeaturedRenteCapitalSub =>
      'Compara ambas opciones lado a lado';

  @override
  String get retraiteHubFeaturedRachat => 'Recompra LPP';

  @override
  String get retraiteHubFeaturedRachatSub =>
      'Simula el impacto fiscal de una recompra';

  @override
  String get retraiteHubToolPilier3a => 'Pilar 3a';

  @override
  String get retraiteHubTool3aComparateur => '3a Comparador';

  @override
  String get retraiteHubTool3aRendement => '3a Rendimiento real';

  @override
  String get retraiteHubTool3aRetrait => '3a Retiro escalonado';

  @override
  String get retraiteHubTool3aRetroactif => '3a Retroactivo';

  @override
  String get retraiteHubToolLibrePassage => 'Libre paso';

  @override
  String get retraiteHubToolDecaissement => 'Desembolso';

  @override
  String get retraiteHubToolEpl => 'EPL';

  @override
  String get familleHubFeaturedMariage => 'Matrimonio';

  @override
  String get familleHubFeaturedMariageSub =>
      'Impacto en tus impuestos, AVS y previsión';

  @override
  String get familleHubFeaturedNaissance => 'Nacimiento';

  @override
  String get familleHubFeaturedNaissanceSub =>
      'Asignaciones, licencia y ajustes financieros';

  @override
  String get familleHubFeaturedConcubinage => 'Concubinato';

  @override
  String get familleHubFeaturedConcubinageSub =>
      'Proteger tu pareja sin matrimonio';

  @override
  String get familleHubToolDivorce => 'Divorcio';

  @override
  String get familleHubToolDecesProche => 'Fallecimiento de un familiar';

  @override
  String get travailHubFeaturedPremierEmploi => 'Primer empleo';

  @override
  String get travailHubFeaturedPremierEmploiSub =>
      'Todo lo que necesitas saber para empezar bien';

  @override
  String get travailHubFeaturedChomage => 'Desempleo';

  @override
  String get travailHubFeaturedChomageSub =>
      'Tus derechos, indemnizaciones y trámites';

  @override
  String get travailHubFeaturedIndependant => 'Autónomo';

  @override
  String get travailHubFeaturedIndependantSub =>
      'Previsión y fiscalidad a medida';

  @override
  String get travailHubToolComparateurEmploi => 'Comparador de empleo';

  @override
  String get travailHubToolFrontalier => 'Fronterizo';

  @override
  String get travailHubToolExpatriation => 'Expatriación';

  @override
  String get travailHubToolGenderGap => 'Brecha de género';

  @override
  String get travailHubToolAvsIndependant => 'AVS autónomo';

  @override
  String get travailHubToolIjm => 'IJM';

  @override
  String get travailHubTool3aIndependant => '3a autónomo';

  @override
  String get travailHubToolDividendeSalaire => 'Dividendo vs Salario';

  @override
  String get travailHubToolLppVolontaire => 'LPP voluntario';

  @override
  String get logementHubFeaturedCapacite => 'Capacidad hipotecaria';

  @override
  String get logementHubFeaturedCapaciteSub => '¿Cuánto puedes pedir prestado?';

  @override
  String get logementHubFeaturedLocationPropriete => 'Alquiler vs Propiedad';

  @override
  String get logementHubFeaturedLocationProprieteSub =>
      'Compara ambos escenarios en 20 años';

  @override
  String get logementHubFeaturedVente => 'Venta inmobiliaria';

  @override
  String get logementHubFeaturedVenteSub =>
      'Impuesto sobre la ganancia y reinversión';

  @override
  String get logementHubToolAmortissement => 'Amortización';

  @override
  String get logementHubToolEplCombine => 'EPL combinado';

  @override
  String get logementHubToolValeurLocative => 'Valor locativo';

  @override
  String get logementHubToolSaronFixe => 'SARON vs Fijo';

  @override
  String get fiscaliteHubFeaturedComparateur => 'Comparador fiscal';

  @override
  String get fiscaliteHubFeaturedComparateurSub =>
      'Estima tu impuesto según diferentes escenarios';

  @override
  String get fiscaliteHubFeaturedDemenagement => 'Mudanza cantonal';

  @override
  String get fiscaliteHubFeaturedDemenagementSub =>
      'Compara la fiscalidad entre cantones';

  @override
  String get fiscaliteHubFeaturedAllocation => 'Asignación anual';

  @override
  String get fiscaliteHubFeaturedAllocationSub =>
      '¿Dónde colocar tus ahorros este año?';

  @override
  String get fiscaliteHubToolInteretsComposes => 'Interés compuesto';

  @override
  String get fiscaliteHubToolBilanArbitrage => 'Balance arbitraje';

  @override
  String get patrimoineHubFeaturedSuccession => 'Sucesión';

  @override
  String get patrimoineHubFeaturedSuccessionSub =>
      'Anticipa la transmisión de tu patrimonio';

  @override
  String get patrimoineHubFeaturedDonation => 'Donación';

  @override
  String get patrimoineHubFeaturedDonationSub =>
      'Fiscalidad e impacto en tu previsión';

  @override
  String get patrimoineHubFeaturedRenteCapital => 'Renta vs Capital';

  @override
  String get patrimoineHubFeaturedRenteCapitalSub =>
      'Compara ambas opciones lado a lado';

  @override
  String get patrimoineHubToolBilan => 'Balance financiero';

  @override
  String get patrimoineHubToolPortfolio => 'Portfolio';

  @override
  String get santeHubFeaturedFranchise => 'Franquicia LAMal';

  @override
  String get santeHubFeaturedFranchiseSub =>
      'Encuentra la franquicia que te cueste menos';

  @override
  String get santeHubFeaturedInvalidite => 'Invalidez';

  @override
  String get santeHubFeaturedInvaliditeSub =>
      'Estima tu cobertura en caso de incapacidad';

  @override
  String get santeHubFeaturedCheckup => 'Revisión de cobertura';

  @override
  String get santeHubFeaturedCheckupSub =>
      'Verifica que estés bien protegido/a';

  @override
  String get santeHubToolAssuranceInvalidite => 'Seguro de invalidez';

  @override
  String get santeHubToolInvaliditeIndependant => 'Invalidez autónomo';

  @override
  String get dossierSlmTitle => 'Modelo local (SLM)';

  @override
  String get dossierSlmSubtitle => 'IA integrada, funciona sin conexión';

  @override
  String get dossierByokTitle => 'Clave API (BYOK)';

  @override
  String get dossierByokSubtitle => 'Conecta tu propio modelo IA';

  @override
  String get budgetErrorRetry => 'El cálculo ha fallado. ¿Reintentar?';

  @override
  String get budgetChiffreChocCaption =>
      'Lo que queda después de todos tus gastos fijos';

  @override
  String get budgetMethodTitle => 'Entender este presupuesto';

  @override
  String get budgetMethodBody =>
      'Este presupuesto separa tus gastos fijos (alquiler, seguro médico, impuestos) de tu ingreso disponible. La regla 50/30/20 sugiere: 50 % para necesidades, 30 % para deseos, 20 % para ahorro. Es una guía, no una obligación.';

  @override
  String get budgetMethodSource =>
      'Fuente: método 50/30/20 (Elizabeth Warren, 2005)';

  @override
  String get budgetDisclaimerNote =>
      'Estimación educativa. No constituye asesoramiento financiero (LSFin art. 3).';

  @override
  String get chiffreChocIfYouAct => 'Si actúas';

  @override
  String get chiffreChocIfYouDontAct => 'Si no haces nada';

  @override
  String get chiffreChocAvantApresGapAct =>
      'Una recompra LPP o aportes al 3a pueden reducir esta brecha a la mitad.';

  @override
  String get chiffreChocAvantApresGapNoAct =>
      'La brecha crece cada año. En la jubilación, será tarde.';

  @override
  String get chiffreChocAvantApresLiquidityAct =>
      'Ahorrando 500 CHF/mes, reconstruyes 3 meses de reserva en 6 meses.';

  @override
  String get chiffreChocAvantApresLiquidityNoAct =>
      'Una emergencia sin reservas significa crédito al consumo.';

  @override
  String get chiffreChocAvantApresTaxAct =>
      'Cada año sin 3a es una deducción fiscal perdida.';

  @override
  String get chiffreChocAvantApresTaxNoAct =>
      'Sin 3a, pagas impuestos completos y no preparas tu jubilación.';

  @override
  String get chiffreChocAvantApresIncomeAct =>
      'Unos ajustes pueden mejorar tu proyección.';

  @override
  String get chiffreChocAvantApresIncomeNoAct =>
      'Tu situación se mantiene estable, pero sin margen de mejora.';

  @override
  String chiffreChocConfidenceSimple(String count) {
    return 'Basado en $count datos. Añade más para afinar.';
  }

  @override
  String get quickStartTitle => 'Tres preguntas, un primer número.';

  @override
  String get quickStartSubtitle => 'El resto lo decides tú, cuando quieras.';

  @override
  String get quickStartFirstName => 'Tu nombre';

  @override
  String get quickStartFirstNameHint => 'Opcional';

  @override
  String get quickStartAge => 'Tu edad';

  @override
  String quickStartAgeValue(String age) {
    return '$age años';
  }

  @override
  String get quickStartSalary => 'Tu ingreso bruto anual';

  @override
  String quickStartSalaryValue(String salary) {
    return '$salary/año';
  }

  @override
  String get quickStartNoIncome => 'Sin ingresos';

  @override
  String get quickStartCanton => 'Cantón';

  @override
  String get quickStartPreviewTitle => 'Vista previa jubilación';

  @override
  String get quickStartVerdictGood => 'Buen camino';

  @override
  String get quickStartVerdictWatch => 'A vigilar';

  @override
  String get quickStartVerdictGap => 'Brecha significativa';

  @override
  String get quickStartToday => 'Hoy';

  @override
  String get quickStartAtRetirement => 'En la jubilación';

  @override
  String get quickStartPerMonth => '/mes';

  @override
  String quickStartDropPct(String pct, String gap) {
    return '-$pct % de poder adquisitivo ($gap/mes)';
  }

  @override
  String get quickStartDisclaimer =>
      'Estimación educativa. No constituye asesoramiento financiero (LSFin).';

  @override
  String get quickStartCta => 'Ver mi resumen';

  @override
  String get quickStartSectionIdentity => 'Identidad & Hogar';

  @override
  String get quickStartSectionIncome => 'Ingresos & Ahorro';

  @override
  String get quickStartSectionPension => 'Previsión (LPP)';

  @override
  String get quickStartSectionProperty => 'Inmuebles & Deudas';

  @override
  String quickStartSectionGuidance(String label) {
    return 'Sección: $label — actualiza tus datos a continuación.';
  }

  @override
  String profileCompletionHint(int pct, String missing) {
    return '$pct % — falta $missing';
  }

  @override
  String get profileMissingLpp => 'tu LPP';

  @override
  String get profileMissingIncome => 'tus ingresos';

  @override
  String get profileMissingProperty => 'tu inmueble';

  @override
  String get profileMissingIdentity => 'tu identidad';

  @override
  String get profileMissingAnd => ' y ';

  @override
  String profileAnnualRefreshDays(int days) {
    return 'Última actualización hace $days días';
  }

  @override
  String get chiffreChocBack => 'Volver';

  @override
  String get chiffreChocShowComparison => 'Mostrar comparación';

  @override
  String get chiffreChocHideComparison => 'Ocultar comparación';

  @override
  String get dashboardNextActionsTitle => 'Tus próximas acciones';

  @override
  String get dashboardExploreAlsoTitle => 'Explorar más';

  @override
  String get dashboardImproveAccuracyTitle => 'Mejora tu precisión';

  @override
  String dashboardCurrentConfidence(int score) {
    return 'Confianza actual: $score%';
  }

  @override
  String dashboardPrecisionPtsGain(int pts) {
    return '+$pts puntos de precisión';
  }

  @override
  String get dashboardOnboardingHeroTitle => 'Tu jubilación de un vistazo';

  @override
  String get dashboardOnboardingCta => 'Empezar — 2 min';

  @override
  String get dashboardOnboardingConsent =>
      'Ningún dato almacenado sin tu consentimiento.';

  @override
  String get dashboardEducationTitle =>
      '¿Cómo funciona la jubilación en Suiza?';

  @override
  String get dashboardEducationSubtitle =>
      'AVS, LPP, 3a — lo básico en 5 minutos';

  @override
  String get dashboardCockpitTitle => 'Cockpit detallado';

  @override
  String get dashboardCockpitSubtitle => 'Desglose por pilar';

  @override
  String get dashboardCockpitCta => 'Abrir';

  @override
  String get dashboardRenteVsCapitalTitle => 'Renta vs Capital';

  @override
  String get dashboardRenteVsCapitalSubtitle =>
      'Explorar el punto de equilibrio';

  @override
  String get dashboardRenteVsCapitalCta => 'Simular';

  @override
  String get dashboardRachatLppTitle => 'Rescate LPP';

  @override
  String get dashboardRachatLppSubtitle => 'Simular el impacto fiscal';

  @override
  String get dashboardRachatLppCta => 'Calcular';

  @override
  String dashboardPrecisionGainPercent(int percent) {
    return 'Precisión +$percent%';
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
      'Vas por buen camino para mantener tu nivel de vida.';

  @override
  String get dashboardOneLinerLevers =>
      'Existen opciones para mejorar tu proyección.';

  @override
  String get dashboardOneLinerEveryAction =>
      'Cada acción cuenta — explora las opciones disponibles.';

  @override
  String get profileFamilyCouple => 'En pareja';

  @override
  String get profileFamilySingle => 'Solo/a';

  @override
  String get renteVsCapitalErrorRetry =>
      'El cálculo ha fallado. Inténtalo más tarde.';

  @override
  String get rachatEchelonneTitle => 'Rescate LPP escalonado';

  @override
  String get rachatEchelonneIntroTitle => '¿Por qué escalonar los rescates?';

  @override
  String get rachatEchelonneIntroBody =>
      'El impuesto suizo es progresivo: repartir un rescate LPP en varios años maximiza el ahorro fiscal total.';

  @override
  String get rachatEchelonneSavingsCaption => 'de ahorro adicional escalonando';

  @override
  String get rachatEchelonneBlocBetter =>
      'Rescate en bloque más ventajoso en este caso';

  @override
  String get rachatEchelonneSituationLpp => 'Situación LPP';

  @override
  String get rachatEchelonneAvoirActuel => 'Activos LPP actuales';

  @override
  String get rachatEchelonneRachatMax => 'Rescate máximo';

  @override
  String get rachatEchelonneSituationFiscale => 'Situación fiscal';

  @override
  String get rachatEchelonneCanton => 'Cantón';

  @override
  String get rachatEchelonneEtatCivil => 'Estado civil';

  @override
  String get rachatEchelonneCelibataire => 'Soltero/a';

  @override
  String get rachatEchelonneMarieE => 'Casado/a';

  @override
  String get rachatEchelonneRevenuImposable => 'Ingreso imponible';

  @override
  String get rachatEchelonneTauxMarginal => 'Tasa marginal estimada';

  @override
  String get rachatEchelonneTauxManuel => 'Valor ajustado manualmente';

  @override
  String get rachatEchelonneAjuster => 'Ajustar';

  @override
  String get rachatEchelonneAuto => 'Auto';

  @override
  String get rachatEchelonneStrategie => 'Estrategia';

  @override
  String get rachatEchelonneHorizon => 'Horizonte (años)';

  @override
  String get rachatEchelonneComparaison => 'Comparación';

  @override
  String get rachatEchelonneBlocTitle => 'Todo en 1 año';

  @override
  String get rachatEchelonneBlocSubtitle => 'Rescate en bloque';

  @override
  String get rachatEchelonneEchelonneSubtitle => 'Rescate repartido';

  @override
  String get rachatEchelonnePlusAdapte => 'El más adecuado';

  @override
  String get rachatEchelonneEconomieFiscale => 'Ahorro fiscal';

  @override
  String get rachatEchelonneImpactTranche => 'Impacto por tramo fiscal';

  @override
  String get rachatEchelonneImpactBlocExplain =>
      'En bloque, la deducción atraviesa varios tramos. Escalonando, cada deducción queda en el tramo más alto.';

  @override
  String get rachatEchelonneBloc => 'Bloque';

  @override
  String get rachatEchelonneEchelonne => 'Escalonado';

  @override
  String get rachatEchelonnePlanAnnuel => 'Plan anual';

  @override
  String get rachatEchelonneTotal => 'Total';

  @override
  String get rachatEchelonneRachat => 'Rescate';

  @override
  String get rachatEchelonneBlockageTitle => 'LPP art. 79b al. 3 — Bloqueo EPL';

  @override
  String get rachatEchelonneBlockageBody =>
      'Después de cada rescate, cualquier retiro EPL queda bloqueado durante 3 años.';

  @override
  String get rachatEchelonneTauxMarginalTitle => 'Tasa impositiva marginal';

  @override
  String get rachatEchelonneTauxMarginalBody =>
      'La tasa marginal es el porcentaje sobre tu último franco ganado.';

  @override
  String get rachatEchelonneTauxMarginalTip =>
      'Por eso escalonar los rescates es inteligente.';

  @override
  String get rachatEchelonneTauxMarginalSemantics =>
      'Información sobre la tasa marginal';

  @override
  String get staggered3aTitle => 'Retiro 3a escalonado';

  @override
  String get staggered3aEconomie => 'Ahorro estimado';

  @override
  String get staggered3aIntroTitle => '¿Por qué escalonar los retiros 3a?';

  @override
  String get staggered3aIntroBody =>
      'El impuesto sobre retiro de capital de previsión es progresivo. Al repartir en varias cuentas y años fiscales, reduces la tasa media.';

  @override
  String get staggered3aParametres => 'Parámetros';

  @override
  String get staggered3aAvoirTotal => 'Activos 3a totales';

  @override
  String get staggered3aNbComptes => 'Número de cuentas 3a';

  @override
  String get staggered3aCanton => 'Cantón';

  @override
  String get staggered3aRevenuImposable => 'Ingreso imponible';

  @override
  String get staggered3aAgeDebut => 'Edad inicio retiros';

  @override
  String get staggered3aAgeFin => 'Edad último retiro';

  @override
  String get staggered3aResultat => 'Resultado';

  @override
  String get staggered3aEnBloc => 'En bloque';

  @override
  String get staggered3aRetraitUnique => 'Retiro único';

  @override
  String get staggered3aEchelonneLabel => 'Escalonado';

  @override
  String get staggered3aImpotEstime => 'Impuesto estimado';

  @override
  String get staggered3aPlanAnnuel => 'Plan anual';

  @override
  String get staggered3aAge => 'Edad';

  @override
  String get staggered3aRetrait => 'Retiro';

  @override
  String get staggered3aImpot => 'Impuesto';

  @override
  String get staggered3aNet => 'Neto';

  @override
  String get staggered3aTotal => 'Total';

  @override
  String get staggered3aAns => 'años';

  @override
  String get optimDecaissementTitle => 'Orden de retiro 3a';

  @override
  String get optimDecaissementChiffre => '+CHF 3\'500';

  @override
  String get optimDecaissementChiffreExplication =>
      'Es el impuesto adicional al retirar 2 cuentas 3a el mismo año — según LIFD art. 38.';

  @override
  String get optimDecaissementPrincipe => 'El principio del escalonamiento';

  @override
  String get optimDecaissementInfo1Title => '1 cuenta 3a por año fiscal';

  @override
  String get optimDecaissementInfo1Body =>
      'El retiro del 3a se grava por separado (LIFD art. 38), pero la tasa aumenta con el monto.';

  @override
  String get optimDecaissementInfo2Title => 'Hasta 10 cuentas 3a simultáneas';

  @override
  String get optimDecaissementInfo2Body =>
      'Desde 2026, puedes tener varias cuentas 3a (revisión OPP3 2026).';

  @override
  String get optimDecaissementInfo3Title => 'La fiscalidad varía por cantón';

  @override
  String get optimDecaissementInfo3Body =>
      'Varios cantones ofrecen deducciones adicionales.';

  @override
  String get optimDecaissementIllustration => 'Ejemplo: CHF 150\'000 en 3a';

  @override
  String get optimDecaissementTableSpread => 'Distribución';

  @override
  String get optimDecaissementTableAmount => 'Monto/retiro';

  @override
  String get optimDecaissementTableTax => 'Impuesto est.*';

  @override
  String get optimDecaissementTableRow1Spread => '1 año';

  @override
  String get optimDecaissementTableRow1Amount => 'CHF 150\'000';

  @override
  String get optimDecaissementTableRow1Tax => '~CHF 12\'500';

  @override
  String get optimDecaissementTableRow2Spread => '3 años';

  @override
  String get optimDecaissementTableRow2Amount => 'CHF 50\'000/año';

  @override
  String get optimDecaissementTableRow2Tax => '~CHF 3\'200/año';

  @override
  String get optimDecaissementTableRow3Spread => '5 años';

  @override
  String get optimDecaissementTableRow3Amount => 'CHF 30\'000/año';

  @override
  String get optimDecaissementTableRow3Tax => '~CHF 1\'700/año';

  @override
  String get optimDecaissementTableFootnote =>
      '* Estimaciones indicativas basadas en tasa cantonal media (ZH).';

  @override
  String get optimDecaissementPlanTitle => 'Cómo planificar tu retiro';

  @override
  String get optimDecaissementStep1Title => 'Inventario de tus cuentas 3a';

  @override
  String get optimDecaissementStep1Body =>
      'Lista cada cuenta 3a con su saldo y entidad.';

  @override
  String get optimDecaissementStep2Title => 'Simula el impacto fiscal';

  @override
  String get optimDecaissementStep2Body =>
      'Compara: todo en 1 año vs. repartir en 3, 5 o 7 años.';

  @override
  String get optimDecaissementStep3Title => 'Coordina con tu jubilación LPP';

  @override
  String get optimDecaissementStep3Body =>
      'Esperar 1-2 años tras el retiro del capital LPP reduce la carga fiscal total.';

  @override
  String get optimDecaissementSpecialisteTitle => 'Consultar un/a especialista';

  @override
  String get optimDecaissementSpecialisteBody =>
      'Un/a especialista puede modelar tu plan de retiro.';

  @override
  String get optimDecaissementSources =>
      '• LIFD art. 38 — Imposición separada\n• OPP3 art. 3 — Condiciones de retiro\n• OPP3 art. 7 — Topes de deducción';

  @override
  String get optimDecaissementDisclaimer =>
      'Información educativa, no asesoramiento fiscal (LSFin).';

  @override
  String get successionAlertTitle =>
      'Sin testamento, tu concubino/a no hereda nada';

  @override
  String get successionAlertBody =>
      'El derecho sucesorio suizo (CC art. 457 ss) protege primero a descendientes, luego padres y cónyuge legal.';

  @override
  String get successionNotionsCles => 'Las nociones clave';

  @override
  String get successionReservesBody =>
      'Una parte de tu sucesión está reservada por ley a descendientes y cónyuge.';

  @override
  String get successionQuotiteSubtitle => 'CC art. 470 al. 2';

  @override
  String get successionQuotiteBody =>
      'Lo que queda después de las reservas es tu porción disponible — legable libremente.';

  @override
  String get successionTestamentBody =>
      'Dos formas: ológrafo (manuscrito) o notarial. Sin testamento = sucesión legal.';

  @override
  String get successionDonationTitle => 'Donación en vida';

  @override
  String get successionDonationSubtitle => 'CO art. 239 ss';

  @override
  String get successionDonationBody =>
      'Transmitir en vida permite anticipar la sucesión y reducir el impuesto sucesorio.';

  @override
  String get successionBeneficiairesTitle => 'Beneficiarios LPP y 3a';

  @override
  String get successionBeneficiairesSubtitle => 'LPP art. 20 · OPP3 art. 2';

  @override
  String get successionBeneficiairesBody =>
      'El capital LPP y el saldo 3a NO forman parte de la sucesión ordinaria.';

  @override
  String get successionDecesProche =>
      'En caso de fallecimiento de un ser querido';

  @override
  String get successionCheck1 => 'Verificar beneficiarios en cada cuenta 3a';

  @override
  String get successionCheck2 => 'Verificar beneficiario LPP en tu caja';

  @override
  String get successionCheck3 => 'Redactar o actualizar tu testamento';

  @override
  String get successionCheck4 =>
      'Verificar régimen matrimonial si casado/a (CC art. 181 ss)';

  @override
  String get successionCheck5 =>
      'Informar a tus seres queridos de la ubicación del testamento';

  @override
  String get successionSpecialisteTitle =>
      'Consultar un/a notario/a o especialista';

  @override
  String get successionSpecialisteBody =>
      'Un/a notario/a puede redactar o revisar tu testamento.';

  @override
  String get successionSources =>
      '• CC art. 457–640 — Derecho de sucesiones\n• CC art. 470–471 — Reservas hereditarias\n• CC art. 498–504 — Formas de testamento\n• LPP art. 20 — Beneficiarios LPP\n• OPP3 art. 2 — Beneficiarios 3a';

  @override
  String naissanceAllocForCanton(String canton, int count, String plural) {
    return 'Asignaciones familiares en $canton para $count hijo$plural';
  }

  @override
  String naissanceAllocContextNote(String canton, int count, String plural) {
    return '($canton, $count hijo$plural)';
  }

  @override
  String get affordabilityEmotionalPositif => 'Puedes permitírtelo';

  @override
  String get affordabilityEmotionalNegatif => 'Falta una pieza del puzzle';

  @override
  String get affordabilityExploreAlso => 'Explorar más';

  @override
  String get affordabilityRelatedAmortTitle =>
      'Amortización directa vs indirecta';

  @override
  String get affordabilityRelatedAmortSubtitle =>
      'Impacto fiscal de cada estrategia';

  @override
  String get affordabilityRelatedSaronTitle => 'SARON vs tipo fijo';

  @override
  String get affordabilityRelatedSaronSubtitle => 'Comparar tipos de hipoteca';

  @override
  String get affordabilityRelatedValeurTitle => 'Valor locativo';

  @override
  String get affordabilityRelatedValeurSubtitle =>
      'Entender la tributación de la vivienda';

  @override
  String get affordabilityRelatedEplTitle => 'EPL — Usar mi 2o pilar';

  @override
  String get affordabilityRelatedEplSubtitle =>
      'Retiro anticipado para la compra';

  @override
  String get affordabilityRelatedSimulate => 'Simular';

  @override
  String get affordabilityRelatedCompare => 'Comparar';

  @override
  String get affordabilityRelatedCalculate => 'Calcular';

  @override
  String get affordabilityAdvancedParams => 'Más hipótesis';

  @override
  String get demenagementTitreV2 => 'Mudarse de cantón, ¿cuánto ahorras?';

  @override
  String get demenagementCtaOptimal => 'Encontrar el cantón adecuado';

  @override
  String demenagementInsightPositif(String mois) {
    return 'Esta mudanza aumenta tu poder adquisitivo. El ahorro cubre unos $mois meses de alquiler medio.';
  }

  @override
  String get demenagementInsightNegatif =>
      'Esta mudanza cuesta más. Verifica que la calidad de vida compensa la diferencia.';

  @override
  String get demenagementBilanTotal =>
      'Balance total (impuestos + seguro médico)';

  @override
  String divorceTransfertAmount(String amount, String direction) {
    return 'Transferencia de $amount ($direction)';
  }

  @override
  String divorceFiscalDelta(String sign, String amount) {
    return 'Diferencia: $sign$amount/año';
  }

  @override
  String divorcePensionMois(String amount) {
    return '$amount/mes';
  }

  @override
  String divorcePensionAnnuel(String amount) {
    return 'es decir $amount/año';
  }

  @override
  String get divorceConjoint1Label => 'Cónyuge 1';

  @override
  String get divorceConjoint2Label => 'Cónyuge 2';

  @override
  String get divorceSplitC1 => 'C1';

  @override
  String get divorceSplitC2 => 'C2';

  @override
  String get unemploymentVague1Label => 'Ola 1 — Urgencia administrativa';

  @override
  String get unemploymentVague1Text =>
      'Inscríbete en la ORP dentro de los primeros 5 días. Si no: pérdida de prestaciones. Cada día de retraso = prestación perdida.';

  @override
  String get unemploymentVague2Label => 'Ola 2 — Presupuesto a ajustar';

  @override
  String get unemploymentVague2Text =>
      'Caída inmediata de ingresos. El seguro de desempleo no cubre festivos ni el periodo de espera (5–20 días). Revisa tu presupuesto desde el día 1.';

  @override
  String get unemploymentVague3Label => 'Ola 3 — Decisiones ocultas';

  @override
  String get unemploymentVague3Text =>
      'En 30 días: transferir tu LPP (sino institución supletoria). Antes del mes siguiente: suspender el 3a, revisar el seguro médico.';

  @override
  String get unemploymentBudgetLoyer => 'Alquiler';

  @override
  String get unemploymentBudgetLamal => 'Seguro médico';

  @override
  String get unemploymentBudgetTransport => 'Transporte';

  @override
  String get unemploymentBudgetLoisirs => 'Ocio';

  @override
  String get unemploymentBudgetEpargne3a => 'Ahorro 3a';

  @override
  String get unemploymentGainMin => 'CHF 0';

  @override
  String get unemploymentGainMax => 'CHF 12\'350';

  @override
  String get unemploymentBracket1 => '12–17 meses cotiz.';

  @override
  String get unemploymentBracket1Value => '200 prestaciones';

  @override
  String get unemploymentBracket2 => '18–21 meses cotiz.';

  @override
  String get unemploymentBracket2Value => '260 prestaciones';

  @override
  String unemploymentBracket3(int age) {
    return '>= 22 meses, < $age años';
  }

  @override
  String get unemploymentBracket3Value => '400 prestaciones';

  @override
  String unemploymentBracket4(int age) {
    return '>= 22 meses, >= $age años';
  }

  @override
  String get unemploymentBracket4Value => '520 prestaciones';

  @override
  String get allocAnnuelleTitle => '¿Dónde colocar tus CHF?';

  @override
  String get allocAnnuelleBudgetTitle => 'Tu presupuesto anual';

  @override
  String get allocAnnuelleMontantLabel => 'Importe disponible al año (CHF)';

  @override
  String get allocAnnuelleTauxMarginal => 'Tasa marginal de impuesto estimada';

  @override
  String get allocAnnuelleAnneesRetraite => 'Años hasta la jubilación';

  @override
  String allocAnnuelleAnneesValue(int years) {
    return '$years años';
  }

  @override
  String get allocAnnuelle3aMaxed => '3a ya al máximo';

  @override
  String get allocAnnuelleRachatLpp => 'Potencial de recompra LPP';

  @override
  String get allocAnnuelleRachatMontant => 'Importe de recompra posible (CHF)';

  @override
  String get allocAnnuelleProprietaire => 'Propietario de inmueble';

  @override
  String get allocAnnuelleComparer => 'Comparar estrategias';

  @override
  String get allocAnnuelleTrajectoires => 'Trayectorias comparadas';

  @override
  String get allocAnnuelleGraphHint =>
      'Toca el gráfico para ver los valores de cada año.';

  @override
  String get allocAnnuelleValeurTerminale => 'Valor terminal estimado';

  @override
  String allocAnnuelleApresAnnees(int years) {
    return 'Después de $years años';
  }

  @override
  String get allocAnnuelleHypotheses => 'Hipótesis utilizadas';

  @override
  String get allocAnnuelleRendementMarche => 'Rendimiento del mercado';

  @override
  String get allocAnnuelleRendementLpp => 'Rendimiento LPP';

  @override
  String get allocAnnuelleRendement3a => 'Rendimiento 3a';

  @override
  String get allocAnnuelleAvertissement => 'Aviso';

  @override
  String allocAnnuelleSources(String sources) {
    return 'Fuentes: $sources';
  }

  @override
  String get allocAnnuellePreRempli => 'Valores rellenados desde tu perfil';

  @override
  String get allocAnnuelleEncouragement =>
      'Cada franco bien invertido trabaja para ti. Compara las opciones y elige con conocimiento.';

  @override
  String get expatTab2EduInsert =>
      'Suiza no aplica un impuesto de salida (exit tax), a diferencia de EE. UU. o Francia. Tus plusvalías latentes no se gravan al salir. Es una ventaja importante para los expatriados.';

  @override
  String get expatTimelineToday => 'Hoy';

  @override
  String get expatTimelineTodayDesc => 'Empieza a planificar';

  @override
  String get expatTimelineTodayTiming => 'Ahora';

  @override
  String get expatTimeline2to3Months => '2-3 meses antes';

  @override
  String get expatTimeline2to3MonthsDesc =>
      'Notificar a la comuna, cancelar LAMal';

  @override
  String expatTimeline2to3MonthsTiming(int months) {
    return 'En ~$months meses';
  }

  @override
  String get expatTimeline1Month => '1 mes antes';

  @override
  String get expatTimeline1MonthDesc => 'Retirar 3a, transferir LPP';

  @override
  String expatTimeline1MonthTiming(int months) {
    return 'En ~$months meses';
  }

  @override
  String get expatTimelineDDay => 'Día D';

  @override
  String get expatTimelineDDayDesc => 'Salida efectiva';

  @override
  String expatTimelineDDayTiming(int days) {
    return 'En $days días';
  }

  @override
  String get expatTimeline30After => '30 días después';

  @override
  String get expatTimeline30AfterDesc => 'Declarar impuestos prorrateados';

  @override
  String get expatTimeline30AfterTiming => 'Después de la salida';

  @override
  String get expatTimelineUrgent => '¡Urgente!';

  @override
  String get expatTimelinePassed => 'Pasado';

  @override
  String expatSavingsBadge(String amount, String percent) {
    return 'Ahorro: $amount (-$percent%)';
  }

  @override
  String expatForfaitMoreCostly(String amount) {
    return 'Forfait más caro: +$amount';
  }

  @override
  String expatForfaitBase(String amount) {
    return 'Base: $amount';
  }

  @override
  String expatAvsReductionExplain(String percent) {
    return 'Cada año faltante reduce tu pensión en aproximadamente $percent%. La reducción es definitiva y se aplica de por vida.';
  }

  @override
  String expatAvsChiffreChoc(String amount) {
    return '-$amount/año en tu pensión AVS';
  }

  @override
  String expatDepartChiffreChoc(String amount) {
    return '$amount de capital a asegurar antes de la partida';
  }

  @override
  String get independantCoveredLabel => 'Cubierto';

  @override
  String get independantCriticalLabel => 'Sin cobertura — crítico';

  @override
  String get independantHighLabel => 'Sin cobertura';

  @override
  String get independantLowLabel => 'Sin cobertura';

  @override
  String fiscalIncomeInfoLabel(String income, String status, String children) {
    return 'Ingreso: $income | $status$children';
  }

  @override
  String get fiscalStatusMarried => 'Casado/a';

  @override
  String get fiscalStatusSingle => 'Soltero/a';

  @override
  String fiscalChildrenSuffix(int count) {
    return ' + $count hijo(s)';
  }

  @override
  String get fiscalPerMonth => '/mes';

  @override
  String get sim3aTitle => 'Tu 3.er pilar';

  @override
  String get sim3aExportTooltip => 'Exportar mi informe';

  @override
  String get sim3aCoachTitle => 'Consejo del Mentor';

  @override
  String get sim3aCoachBody =>
      'El 3a es una de las herramientas de optimización más eficaces de Suiza. El ahorro fiscal inmediato es una ventaja concreta.';

  @override
  String get sim3aParamsHeader => 'Tus parámetros';

  @override
  String get sim3aAnnualContribution => 'Aporte anual';

  @override
  String get sim3aAnnualContributionIndep => 'Aporte anual (autónomo sin LPP)';

  @override
  String get sim3aMarginalRate => 'Tasa marginal de imposición';

  @override
  String get sim3aYearsToRetirement => 'Años hasta la jubilación';

  @override
  String get sim3aExpectedReturn => 'Rendimiento anual esperado';

  @override
  String sim3aYearsSuffix(int count) {
    return '$count años';
  }

  @override
  String get sim3aAnnualTaxSaved => 'Ahorro fiscal anual';

  @override
  String get sim3aFinalCapital => 'Capital al vencimiento';

  @override
  String get sim3aCumulativeTaxSaved => 'Ahorro fiscal acumulado';

  @override
  String get sim3aStrategyHeader => 'Estrategia ganadora';

  @override
  String get sim3aStratBankTitle => 'Banco > Seguro';

  @override
  String get sim3aStratBankBody =>
      'Evita los contratos de seguro vinculados. Mantente flexible con un 3a bancario invertido.';

  @override
  String get sim3aStrat5AccountsTitle => 'La regla de las 5 cuentas';

  @override
  String get sim3aStrat5AccountsBody =>
      'Abre varias cuentas para retirar de forma escalonada y reducir la progresión fiscal.';

  @override
  String get sim3aStrat100ActionsTitle => '100 % Acciones';

  @override
  String get sim3aStrat100ActionsBody =>
      'Si tu jubilación está a más de 15 años, una estrategia de acciones podría maximizar tu capital.';

  @override
  String get sim3aExploreAlso => 'Explorar también';

  @override
  String get sim3aProviderComparator => 'Comparador de proveedores';

  @override
  String get sim3aProviderComparatorSub => 'VIAC, Finpension, frankly...';

  @override
  String get sim3aRealReturn => 'Rendimiento real';

  @override
  String get sim3aRealReturnSub => 'Después de gastos, inflación y fiscal';

  @override
  String get sim3aStaggeredWithdrawal => 'Retiro escalonado';

  @override
  String get sim3aStaggeredWithdrawalSub =>
      'Distribuir retiros para reducir impuestos';

  @override
  String get sim3aCtaCompare => 'Comparar';

  @override
  String get sim3aCtaCalculate => 'Calcular';

  @override
  String get sim3aCtaPlan => 'Planificar';

  @override
  String get sim3aDisclaimer =>
      'Estimación educativa. Los ahorros reales dependen de tu lugar de residencia y situación familiar. No constituye asesoramiento financiero (LSFin).';

  @override
  String get sim3aDebtLockedTitle => 'Prioridad al desendeudamiento';

  @override
  String get sim3aDebtLockedMessage =>
      'En modo protección, las recomendaciones de acción 3a están desactivadas. La prioridad es estabilizar tu situación financiera.';

  @override
  String get sim3aDebtStrategyTitle => 'Estrategia bloqueada';

  @override
  String get sim3aDebtStrategyMessage =>
      'Las estrategias de inversión 3a están desactivadas mientras tengas deudas activas. Pagar tus deudas es un rendimiento mayor que cualquier inversión.';

  @override
  String get realReturnTitle => 'Rendimiento real 3a';

  @override
  String get realReturnChiffreChocLabel =>
      'Tasa equivalente sobre esfuerzo neto';

  @override
  String realReturnVsNominal(String rate) {
    return 'vs $rate % tasa neta 3a (bruto − gastos)';
  }

  @override
  String realReturnEffortNet(String amount, String pts) {
    return 'Esfuerzo neto: $amount/año | Prima fiscal implícita: +$pts pts';
  }

  @override
  String get realReturnParams => 'Parámetros';

  @override
  String get realReturnAnnualPayment => 'Aporte anual';

  @override
  String get realReturnMarginalRate => 'Tasa marginal';

  @override
  String get realReturnGrossReturn => 'Rendimiento bruto';

  @override
  String get realReturnMgmtFees => 'Gastos de gestión';

  @override
  String get realReturnDuration => 'Duración de inversión';

  @override
  String realReturnYearsSuffix(int count) {
    return '$count años';
  }

  @override
  String get realReturnCompared => 'Rendimientos comparados';

  @override
  String get realReturnNominal3a => 'Rendimiento nominal 3a';

  @override
  String get realReturnRealWithFiscal => 'Rendimiento real (con fiscal)';

  @override
  String get realReturnEquivNote =>
      'Esta tasa es equivalente: no representa un rendimiento de mercado esperado.';

  @override
  String get realReturnSavingsAccount => 'Rendimiento cuenta de ahorro';

  @override
  String realReturnFinalCapital(int years) {
    return 'Capital final después de $years años';
  }

  @override
  String get realReturn3aFintech => '3a Fintech + fiscal';

  @override
  String get realReturnSavings15 => 'Cuenta de ahorro 1,5 %';

  @override
  String realReturnGainVsSavings(String amount) {
    return 'Ganancia vs ahorro: CHF $amount';
  }

  @override
  String get realReturnFiscalDetail => 'Detalle ahorro fiscal';

  @override
  String get realReturnTotalPayments => 'Total aportes';

  @override
  String get realReturnFinalCapital3a => 'Capital final 3a (sin fiscal)';

  @override
  String get realReturnCumulativeFiscal => 'Ahorro fiscal acumulado';

  @override
  String get realReturnTotalWithFiscal => 'Total con ventaja fiscal';

  @override
  String realReturnAhaMoment(String netAmount) {
    return 'Tu esfuerzo real: $netAmount/año. El fisco financia la diferencia — una palanca poco común en Suiza.';
  }

  @override
  String get realReturnPerYear => '/ año';

  @override
  String get genderGapAppBarTitle => 'Brecha de previsión';

  @override
  String get genderGapHeaderTitle => 'Brecha de previsión';

  @override
  String get genderGapHeaderSubtitle =>
      'Impacto del tiempo parcial en la jubilación';

  @override
  String get genderGapIntro =>
      'La deducción de coordinación (CHF 26\'460) no se prorratea para el tiempo parcial, lo que penaliza más a las personas que trabajan a tiempo reducido. Mueve el cursor para ver el impacto.';

  @override
  String get genderGapTauxActivite => 'Tasa de actividad';

  @override
  String get genderGapParametres => 'Parámetros';

  @override
  String get genderGapRevenuAnnuel => 'Ingreso anual bruto (100%)';

  @override
  String get genderGapAge => 'Edad';

  @override
  String genderGapAgeValue(String age) {
    return '$age años';
  }

  @override
  String get genderGapAvoirLpp => 'Capital LPP actual';

  @override
  String get genderGapAnneesCotisation => 'Años de cotización';

  @override
  String get genderGapCanton => 'Cantón';

  @override
  String get genderGapDemoMode =>
      'Modo demo: perfil de ejemplo. Completa tu diagnóstico para resultados personalizados.';

  @override
  String get genderGapRenteLppEstimee => 'Renta LPP estimada';

  @override
  String genderGapProjection(String annees) {
    return 'Proyección a $annees años (edad 65)';
  }

  @override
  String get genderGapAt100 => 'Al 100%';

  @override
  String genderGapAtTaux(String taux) {
    return 'Al $taux%';
  }

  @override
  String get genderGapPerYear => '/año';

  @override
  String get genderGapLacuneAnnuelle => 'Brecha anual';

  @override
  String get genderGapLacuneTotale => 'Brecha total (~20 años)';

  @override
  String get genderGapCoordinationTitle =>
      'Entender la deducción de coordinación';

  @override
  String get genderGapCoordinationBody =>
      'La deducción de coordinación es un monto fijo de CHF 26\'460 que se resta de tu salario bruto para calcular el salario coordinado (base LPP). Este monto es igual si trabajas al 100% o al 50%.';

  @override
  String get genderGapSalaireBrut100 => 'Salario bruto al 100%';

  @override
  String get genderGapSalaireCoordonne100 => 'Salario coordinado al 100%';

  @override
  String genderGapSalaireBrutTaux(String taux) {
    return 'Salario bruto al $taux%';
  }

  @override
  String genderGapSalaireCoordonneTaux(String taux) {
    return 'Salario coordinado al $taux%';
  }

  @override
  String get genderGapDeductionFixe => 'Deducción coordinación (fija)';

  @override
  String get genderGapSourceCoordination => 'Fuente: LPP art. 8, OPP2 art. 5';

  @override
  String get genderGapStatOfsTitle => 'Estadística OFS';

  @override
  String get genderGapRecommandations => 'Recomendaciones';

  @override
  String get genderGapDisclaimer =>
      'Los resultados mostrados son estimaciones simplificadas con fines informativos. No constituyen asesoramiento financiero personalizado. Consulta tu caja de pensiones y a un especialista cualificado antes de tomar decisiones.';

  @override
  String get genderGapSources => 'Fuentes';

  @override
  String get genderGapSourcesBody =>
      'LPP art. 8 (deducción de coordinación) / LPP art. 14 (tasa de conversión 6.8%) / OPP2 art. 5 / OPP3 art. 7 / LPP art. 79b (rescate voluntario) / OFS 2024 (estadísticas gender gap)';

  @override
  String get achievementsErrorMessage => 'La carga falló. ¿Reintentamos?';

  @override
  String get documentsEmptyVoice =>
      'Vacío por ahora. Escanea un certificado y todo se aclara.';

  @override
  String documentsConfidenceChoc(String count, String pct) {
    return '$count documentos = $pct% de confianza';
  }

  @override
  String get lamalFranchiseAppBarTitle => 'Franquicia LAMal';

  @override
  String get lamalFranchiseDemoMode => 'MODO DEMO';

  @override
  String get lamalFranchiseHeaderTitle => 'Tu franquicia LAMal';

  @override
  String get lamalFranchiseHeaderSubtitle =>
      'Encuentra la franquicia ideal según tus gastos de salud';

  @override
  String get lamalFranchiseIntro =>
      'Una franquicia alta reduce tu prima mensual, pero aumenta tus gastos en caso de enfermedad. Mueve los cursores para encontrar el equilibrio.';

  @override
  String get lamalFranchiseToggleAdulte => 'Adulto';

  @override
  String get lamalFranchiseToggleEnfant => 'Niño';

  @override
  String get lamalFranchisePrimeSliderLabel => 'Prima mensual (franquicia 300)';

  @override
  String get lamalFranchiseDepensesSliderLabel =>
      'Gastos de salud anuales estimados';

  @override
  String get lamalFranchiseComparisonHeader => 'COMPARACIÓN DE FRANQUICIAS';

  @override
  String get lamalFranchiseRecommandee => 'RECOMENDADA';

  @override
  String lamalFranchiseTotalPrefix(String amount) {
    return 'Total: $amount';
  }

  @override
  String get lamalFranchisePrimeAn => 'Prima/año';

  @override
  String get lamalFranchiseQuotePart => 'Copago';

  @override
  String get lamalFranchiseEconomie => 'Ahorro';

  @override
  String get lamalFranchiseBreakEvenTitle => 'Umbrales de rentabilidad';

  @override
  String lamalFranchiseBreakEvenItem(String seuil, String basse, String haute) {
    return 'Por encima de $seuil de gastos, la franquicia $basse es más ventajosa que $haute.';
  }

  @override
  String get lamalFranchiseRecommandationsHeader => 'RECOMENDACIONES';

  @override
  String get lamalFranchiseAlertText =>
      'Recordatorio: puedes cambiar tu franquicia antes del 30 de noviembre de cada año para el año siguiente.';

  @override
  String get lamalFranchiseDisclaimer =>
      'Estimación educativa. Las primas varían según la aseguradora, la región y el modelo. No constituye asesoramiento financiero (LSFin).';

  @override
  String get lamalFranchiseSourcesHeader => 'Fuentes';

  @override
  String get lamalFranchiseSourcesBody =>
      'LAMal art. 62-64 (franquicia y copago) / OAMal (ordenanza) / priminfo.admin.ch (comparador oficial) / LAMal art. 7 (libre elección del asegurador) / LAMal art. 41a (modelos alternativos)';

  @override
  String get lamalFranchisePrimeMin => 'CHF 200';

  @override
  String get lamalFranchisePrimeMax => 'CHF 600';

  @override
  String get lamalFranchiseDepensesMin => 'CHF 0';

  @override
  String get lamalFranchiseDepensesMax => 'CHF 10\'000';

  @override
  String get lamalFranchiseSelectAdulte => 'Seleccionar adulto';

  @override
  String get lamalFranchiseSelectEnfant => 'Seleccionar niño';

  @override
  String get firstJobCantonLabel => 'Cantón';

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
    return 'Ahorro fiscal estimado: ~$amount/año';
  }

  @override
  String firstJobFranchiseSavings(String amount) {
    return 'Franquicia 2\'500 vs 300: ahorro estimado de ~$amount/año en primas';
  }

  @override
  String get firstJobTopBadge => 'TOP';

  @override
  String get authLoginSubtitle => 'Accede a tu espacio financiero personal';

  @override
  String get authPasswordRequired => 'Contraseña requerida';

  @override
  String get authForgotPasswordLink => '¿Olvidaste tu contraseña?';

  @override
  String get authVerifyEmailLink => 'Verificar mi correo';

  @override
  String get authDateOfBirth => 'Fecha de nacimiento';

  @override
  String get authDateOfBirthHint => 'dd.mm.aaaa';

  @override
  String get authDateOfBirthRequired =>
      'Necesario para las proyecciones AVS/LPP';

  @override
  String get authDateOfBirthTooYoung =>
      'Debes tener al menos 18 años (CGU art. 4.1)';

  @override
  String get authDateOfBirthHelp => 'Fecha de nacimiento';

  @override
  String get authDateOfBirthCancel => 'Cancelar';

  @override
  String get authDateOfBirthConfirm => 'Validar';

  @override
  String get authPasswordHintFull =>
      '8+ caracteres, mayúscula, número, símbolo';

  @override
  String get authPasswordMinChars => 'Mínimo 8 caracteres';

  @override
  String get authPasswordNeedUppercase => 'Al menos una mayúscula requerida';

  @override
  String get authPasswordNeedDigit => 'Al menos un número requerido';

  @override
  String get authPasswordNeedSpecial =>
      'Al menos un carácter especial requerido (!@#\$...)';

  @override
  String get authConfirmRequired => 'Confirmación requerida';

  @override
  String get authPrivacyPolicyText => 'política de privacidad';

  @override
  String get slmStatusRunning => 'Listo — el coach usa IA on-device';

  @override
  String get slmStatusReady => 'Modelo descargado — inicialización requerida';

  @override
  String get slmStatusError =>
      'Error — dispositivo no compatible o memoria insuficiente';

  @override
  String get slmStatusDownloading => 'Descargando…';

  @override
  String get slmStatusNotDownloaded => 'Modelo no descargado';

  @override
  String get slmStatusModelReady => 'Modelo listo — inicia la inicialización';

  @override
  String slmSizeLabel(String size) {
    return 'Tamaño: $size';
  }

  @override
  String slmVersionLabel(String version) {
    return 'Versión: $version';
  }

  @override
  String slmWifiEstimate(int minutes) {
    return '~$minutes min en WiFi';
  }

  @override
  String slmDownloadButton(String size) {
    return 'Descargar ($size)';
  }

  @override
  String slmDownloadDialogBody(String size, int minutes, String hint) {
    return 'El modelo pesa $size. Asegúrate de estar conectado a WiFi.\n\n~$minutes min en WiFi. Compatible: $hint.';
  }

  @override
  String slmDownloadFailedSnack(String reason) {
    return 'Descarga fallida. $reason';
  }

  @override
  String get slmDownloadFailedDefault =>
      'Verifica tu WiFi y el espacio disponible.';

  @override
  String get slmDownloadNotAvailable =>
      'Esta versión no permite la descarga del modelo.';

  @override
  String slmInfoDownload(int minutes) {
    return 'Descarga el modelo una vez (~$minutes min en WiFi)';
  }

  @override
  String get slmInfoOnDevice => 'La IA funciona directamente en tu teléfono';

  @override
  String get slmInfoOffline => 'Funciona incluso sin conexión a internet';

  @override
  String get slmInfoPrivacy => 'Tus datos nunca salen de tu dispositivo';

  @override
  String get slmInfoSpeed =>
      'Respuestas en 2-4 segundos en un dispositivo reciente';

  @override
  String slmInfoSourceModel(String modelId) {
    return 'Fuente del modelo: $modelId';
  }

  @override
  String get slmInfoAuthConfigured => 'Autenticación HuggingFace: configurada';

  @override
  String get slmInfoAuthNotConfigured =>
      'Autenticación HuggingFace: no configurada (descarga imposible si la URL de Gemma es privada)';

  @override
  String slmInfoCompatibility(String hint, String size, int ram) {
    return 'Compatibilidad: $hint.\nEl modelo necesita $size de espacio y ~$ram GB de RAM.';
  }

  @override
  String get consentErrorMessage =>
      'Algo salió mal. Inténtalo de nuevo más tarde.';

  @override
  String get adminObsAuthBilling => 'Auth & Billing';

  @override
  String get adminObsOnboardingQuality => 'Calidad del onboarding';

  @override
  String get adminObsCohorts => 'Cohortes (variante x plataforma)';

  @override
  String get adminObsNoData => 'Sin datos';

  @override
  String get adminAnalyticsTitle => 'Analytics';

  @override
  String get adminAnalyticsLoadError => 'No se pudieron cargar los analytics';

  @override
  String get adminAnalyticsRetry => 'Reintentar';

  @override
  String get adminAnalyticsFunnel => 'Funnel de conversión';

  @override
  String get adminAnalyticsByScreen => 'Eventos por pantalla';

  @override
  String get adminAnalyticsByCategory => 'Eventos por categoría';

  @override
  String get adminAnalyticsNoFunnel => 'Aún no hay datos de funnel.';

  @override
  String get adminAnalyticsNoData => 'Aún no hay datos.';

  @override
  String get adminAnalyticsSessions => 'Sesiones';

  @override
  String get adminAnalyticsEvents => 'Eventos';

  @override
  String get amortizationAppBarTitle => 'Directa vs indirecta';

  @override
  String get eplCombinedAppBarTitle => 'EPL multi-fuentes';

  @override
  String get eplCombinedMinRequired => 'Mínimo requerido: 20 %';

  @override
  String get eplCombinedFundsBreakdown => 'Distribución de fondos propios';

  @override
  String get eplCombinedParameters => 'Parámetros';

  @override
  String get eplCombinedCanton => 'Cantón';

  @override
  String get eplCombinedTargetPrice => 'Precio de compra objetivo';

  @override
  String get eplCombinedCashSavings => 'Ahorro en efectivo';

  @override
  String get eplCombinedAvoir3a => 'Saldo pilar 3a';

  @override
  String get eplCombinedAvoirLpp => 'Saldo LPP';

  @override
  String get eplCombinedSourcesDetail => 'Detalle de fuentes';

  @override
  String get eplCombinedTotalEquity => 'Total fondos propios';

  @override
  String get eplCombinedEstimatedTaxes => 'Impuestos estimados (3a + LPP)';

  @override
  String get eplCombinedNetTotal => 'Monto neto total';

  @override
  String get eplCombinedRequiredEquity => 'Fondos propios requeridos (20 %)';

  @override
  String get eplCombinedEstimatedTax => 'Impuesto estimado';

  @override
  String get eplCombinedNet => 'Neto';

  @override
  String get eplCombinedRecommendedOrder => 'Orden recomendado';

  @override
  String get eplCombinedOrderCashTitle => 'Ahorro en efectivo';

  @override
  String get eplCombinedOrderCashReason =>
      'Sin impuestos, sin impacto en la previsión';

  @override
  String get eplCombinedOrder3aTitle => 'Retiro 3a';

  @override
  String get eplCombinedOrder3aReason =>
      'Impuesto reducido en el retiro, impacto limitado en la previsión de vejez';

  @override
  String get eplCombinedOrderLppTitle => 'Retiro LPP (EPL)';

  @override
  String get eplCombinedOrderLppReason =>
      'Impacto directo en prestaciones de riesgo (invalidez, fallecimiento). Usar como último recurso.';

  @override
  String get eplCombinedAttentionPoints => 'Puntos de atención';

  @override
  String get eplCombinedSource =>
      'Fuente: LPP art. 30c (EPL), OPP3, LIFD art. 38. Tasas cantonales estimadas con fines educativos.';

  @override
  String get eplCombinedPriceOfProperty => 'del precio';

  @override
  String get imputedRentalAppBarTitle => 'Valor locativo';

  @override
  String get imputedRentalIntroTitle => '¿Qué es el valor locativo?';

  @override
  String get imputedRentalIntroBody =>
      'En Suiza, los propietarios deben declarar un ingreso ficticio (valor locativo) correspondiente al alquiler que podrían obtener alquilando su propiedad. A cambio, pueden deducir los intereses hipotecarios y los costes de mantenimiento.';

  @override
  String get imputedRentalDecomposition => 'Desglose';

  @override
  String get imputedRentalBarLocative => 'Valor locativo';

  @override
  String get imputedRentalBarDeductions => 'Deducciones';

  @override
  String get imputedRentalAddedIncome => 'Ingreso imponible añadido';

  @override
  String get imputedRentalLocativeValue => 'Valor locativo';

  @override
  String get imputedRentalDeductionsLabel => 'Deducciones';

  @override
  String get imputedRentalMortgageInterest => 'Intereses hipotecarios';

  @override
  String get imputedRentalMaintenanceCosts => 'Costes de mantenimiento';

  @override
  String get imputedRentalBuildingInsurance =>
      'Seguro del edificio (estimación)';

  @override
  String get imputedRentalTotalDeductions => 'Total deducciones';

  @override
  String get imputedRentalNetImpact => 'Impacto neto en el ingreso imponible';

  @override
  String imputedRentalFiscalImpact(String rate) {
    return 'Impacto fiscal estimado (tasa marginal $rate %)';
  }

  @override
  String get imputedRentalParameters => 'Parámetros';

  @override
  String get imputedRentalCanton => 'Cantón';

  @override
  String get imputedRentalPropertyValue => 'Valor de mercado de la propiedad';

  @override
  String get imputedRentalAnnualInterest => 'Intereses hipotecarios anuales';

  @override
  String get imputedRentalEffectiveMaintenance =>
      'Costes de mantenimiento efectivos';

  @override
  String get imputedRentalOldProperty => 'Propiedad antigua (≥ 10 años)';

  @override
  String get imputedRentalForfaitOld =>
      'Forfait mantenimiento: 20 % del valor locativo';

  @override
  String get imputedRentalForfaitNew =>
      'Forfait mantenimiento: 10 % del valor locativo';

  @override
  String get imputedRentalMarginalRate => 'Tasa marginal estimada';

  @override
  String get imputedRentalSource =>
      'Fuente: LIFD art. 21 ap. 1 let. b, art. 32. Tasas cantonales estimadas con fines educativos.';

  @override
  String get saronVsFixedAppBarTitle => 'SARON vs fija';

  @override
  String saronVsFixedCumulativeCost(int years) {
    return 'Coste acumulado en $years años';
  }

  @override
  String get saronVsFixedLegendFixed => 'Fija';

  @override
  String get saronVsFixedLegendSaronStable => 'SARON estable';

  @override
  String get saronVsFixedLegendSaronRise => 'SARON al alza';

  @override
  String get saronVsFixedParameters => 'Parámetros';

  @override
  String get saronVsFixedMortgageAmount => 'Monto hipotecario';

  @override
  String get saronVsFixedDuration => 'Duración';

  @override
  String saronVsFixedYears(int years) {
    return '$years años';
  }

  @override
  String get saronVsFixedCostComparison => 'Comparación de costes';

  @override
  String saronVsFixedRate(String rate) {
    return 'Tasa: $rate';
  }

  @override
  String get saronVsFixedInsightText =>
      'El escenario SARON al alza simula +0,25 %/año los 3 primeros años. En realidad, la evolución depende de la política monetaria del BNS.';

  @override
  String get saronVsFixedSource =>
      'Fuente: tasas indicativas del mercado suizo 2026. No constituye asesoramiento hipotecario.';

  @override
  String get avsCotisationsTitle => 'Cotizaciones AVS';

  @override
  String get avsCotisationsHeaderInfo =>
      'Como independiente, pagas la totalidad de las cotizaciones AVS/AI/APG. Un empleado solo paga la mitad (5.3%), el empleador cubre el resto.';

  @override
  String get avsCotisationsRevenuLabel => 'Tu ingreso neto anual';

  @override
  String get avsCotisationsSliderMin => 'CHF 0';

  @override
  String get avsCotisationsSliderMax250k => 'CHF 250’000';

  @override
  String avsCotisationsChiffreChocCaption(String amount) {
    return 'Como independiente, pagas $amount/año más que un empleado';
  }

  @override
  String get avsCotisationsTauxEffectif => 'Tasa efectiva';

  @override
  String get avsCotisationsCotisationAn => 'Cotización /año';

  @override
  String get avsCotisationsCotisationMois => 'Cotización /mes';

  @override
  String get avsCotisationsTranche => 'Tramo';

  @override
  String get avsCotisationsComparaisonTitle => 'Comparación anual';

  @override
  String get avsCotisationsIndependant => 'Independiente';

  @override
  String get avsCotisationsSalarie => 'Empleado (parte empleado)';

  @override
  String avsCotisationsSurcout(String amount) {
    return 'Sobrecoste independiente: +$amount/año';
  }

  @override
  String get avsCotisationsBaremeTitle => 'Tu posición en la escala';

  @override
  String avsCotisationsTauxEffectifLabel(String taux) {
    return 'Tu tasa efectiva: $taux%';
  }

  @override
  String get avsCotisationsBonASavoir => 'Bueno saber';

  @override
  String get avsCotisationsEduDegressifTitle => 'Escala degresiva';

  @override
  String get avsCotisationsEduDegressifBody =>
      'La tasa baja para ingresos bajos (entre CHF 10’100 y CHF 60’500). Por encima, la tasa completa del 10.6% se aplica.';

  @override
  String get avsCotisationsEduDoubleChargeTitle => 'Doble carga';

  @override
  String get avsCotisationsEduDoubleChargeBody =>
      'Un empleado solo paga 5.3%; el empleador cubre la otra mitad. Como independiente, asumes la totalidad.';

  @override
  String get avsCotisationsEduMinTitle => 'Cotización mínima';

  @override
  String get avsCotisationsEduMinBody =>
      'Incluso con ingresos muy bajos, la cotización mínima es CHF 530/año.';

  @override
  String get avsCotisationsDisclaimer =>
      'Los montos son estimaciones basadas en la escala AVS/AI/APG vigente. Consulta tu caja de compensación para cifras exactas.';

  @override
  String get ijmTitle => 'Seguro IJM';

  @override
  String get ijmHeaderInfo =>
      'El seguro IJM compensa tu pérdida de ingresos por enfermedad. Como independiente, no hay protección por defecto.';

  @override
  String get ijmRevenuMensuel => 'Ingreso mensual';

  @override
  String get ijmSliderMinChf0 => 'CHF 0';

  @override
  String get ijmSliderMax20k => 'CHF 20’000';

  @override
  String get ijmTonAge => 'Tu edad';

  @override
  String get ijmAgeMin => '18 años';

  @override
  String get ijmAgeMax => '65 años';

  @override
  String get ijmDelaiCarence => 'Período de espera';

  @override
  String get ijmDelaiCarenceDesc => 'Período sin prestaciones';

  @override
  String get ijmJours => 'días';

  @override
  String ijmChiffreChocCaption(String amount, int jours) {
    return 'Sin seguro IJM, pierdes $amount durante el período de espera de $jours días';
  }

  @override
  String get ijmHighRiskTitle => 'Primas altas después de 50';

  @override
  String get ijmHighRiskBody =>
      'Las primas IJM aumentan con la edad. Después de 50, el coste puede ser 3-4 veces mayor.';

  @override
  String get ijmPrimeMois => 'Prima /mes';

  @override
  String get ijmPrimeAn => 'Prima /año';

  @override
  String get ijmIndemniteJour => 'Indemnización /día';

  @override
  String get ijmTrancheAge => 'Tramo de edad';

  @override
  String get ijmTimelineTitle => 'Línea de cobertura';

  @override
  String get ijmTimelineCouvert => 'Cubierto';

  @override
  String get ijmTimelineNoCoverage => 'Sin cobertura';

  @override
  String get ijmTimelineCoverageIjm => 'Cobertura IJM (80%)';

  @override
  String ijmTimelineSummary(int jours, String amount) {
    return 'Durante los primeros $jours días de enfermedad no tienes ingresos. Después recibes $amount/día (80% de tu ingreso mensual).';
  }

  @override
  String get ijmStrategies => 'Estrategias';

  @override
  String get ijmEduFondsTitle => 'Fondo de espera';

  @override
  String get ijmEduFondsBody =>
      'Reserva 3 meses de ingresos para cubrir el período de espera.';

  @override
  String get ijmEduComparerTitle => 'Comparar ofertas';

  @override
  String get ijmEduComparerBody =>
      'Las primas varían entre aseguradoras. Solicita varias cotizaciones.';

  @override
  String get ijmEduLamalTitle => 'Cobertura LAMal insuficiente';

  @override
  String get ijmEduLamalBody =>
      'La LAMal solo cubre gastos médicos, no la pérdida de ingresos.';

  @override
  String get ijmDisclaimer =>
      'Las primas son estimaciones basadas en promedios del mercado.';

  @override
  String ijmJoursCarenceLabel(int jours) {
    return '$jours días de espera';
  }

  @override
  String get pillar3aIndepTitle => '3er pilar independiente';

  @override
  String get pillar3aIndepHeaderInfo =>
      'Como independiente sin LPP, accedes al «gran 3a»: deduce hasta 20% del ingreso neto (máx CHF 36’288/año).';

  @override
  String get pillar3aIndepLppToggle => '¿Afiliado a LPP voluntaria?';

  @override
  String get pillar3aIndepPlafondPetit => 'Tope 3a: CHF 7’258 (pequeño 3a)';

  @override
  String get pillar3aIndepPlafondGrand =>
      'Tope 3a: 20% del ingreso, máx CHF 36’288 (gran 3a)';

  @override
  String get pillar3aIndepRevenuLabel => 'Ingreso neto anual';

  @override
  String get pillar3aIndepSliderMax300k => 'CHF 300’000';

  @override
  String get pillar3aIndepTauxLabel => 'Tasa marginal';

  @override
  String get pillar3aIndepChiffreChocCaption =>
      'de ahorro fiscal anual gracias al 3er pilar';

  @override
  String pillar3aIndepChiffreChocAvantageSalarie(String amount) {
    return 'Ahorras $amount/año más que un empleado gracias al gran 3a';
  }

  @override
  String get pillar3aIndepPlafondApplicable => 'Tope aplicable';

  @override
  String get pillar3aIndepEconomieFiscaleAn => 'Ahorro fiscal /año';

  @override
  String get pillar3aIndepPlafondSalarie => 'Tope empleado';

  @override
  String get pillar3aIndepEconomieSalarie => 'Ahorro empleado';

  @override
  String get pillar3aIndepPlafondsCompares => 'Topes comparados';

  @override
  String pillar3aIndepSuperPouvoir(int multiplier) {
    return '×$multiplier tu superpoder';
  }

  @override
  String get pillar3aIndepSalarie => 'Empleado';

  @override
  String get pillar3aIndepIndependantToi => 'Independiente (tú)';

  @override
  String get pillar3aIndepGrand3aMax => 'Gran 3a (máx legal)';

  @override
  String get pillar3aIndepEn20ans => 'En 20 años al 4%';

  @override
  String get pillar3aIndepVs => 'vs';

  @override
  String get pillar3aIndepToi => 'Tú';

  @override
  String pillar3aIndepDifference(String amount) {
    return 'Diferencia: +$amount';
  }

  @override
  String get pillar3aIndepBonASavoir => 'Bueno saber';

  @override
  String get pillar3aIndepEduComptesTitle => 'Abre varias cuentas 3a';

  @override
  String get pillar3aIndepEduComptesBody =>
      'La estrategia de cuentas múltiples (hasta 5) es recomendada para optimizar el retiro escalonado.';

  @override
  String get pillar3aIndepEduConditionTitle => 'Condición: sin LPP';

  @override
  String get pillar3aIndepEduConditionBody =>
      'El gran 3a solo está disponible sin LPP voluntaria. Con LPP, el tope baja a 7’258.';

  @override
  String get pillar3aIndepEduInvestirTitle => 'Invertir en vez de ahorrar';

  @override
  String get pillar3aIndepEduInvestirBody =>
      'Para un horizonte largo (>10 años), un 3a invertido en acciones puede ofrecer rendimientos superiores.';

  @override
  String get pillar3aIndepDisclaimer =>
      'Los ahorros fiscales se calculan según la tasa marginal indicada. Consulta un especialista.';

  @override
  String get dividendeVsSalaireTitle => 'Dividendo vs Salario';

  @override
  String get dividendeVsSalaireHeaderInfo =>
      'Si posees una SA o Sàrl, puedes pagarte salario y dividendos. El dividendo se grava al 50% y escapa las cotizaciones AVS.';

  @override
  String get dividendeVsSalaireBenefice => 'Beneficio total';

  @override
  String get dividendeVsSalaireSliderMax500k => 'CHF 500’000';

  @override
  String get dividendeVsSalairePartSalaire => 'Parte salario';

  @override
  String get dividendeVsSalaireTauxMarginal => 'Tasa marginal';

  @override
  String dividendeVsSalaireChiffreChocPositive(String amount) {
    return 'El split adaptado te ahorra $amount/año vs 100% salario';
  }

  @override
  String get dividendeVsSalaireChiffreChocNeutral =>
      'Ajusta el split para encontrar ahorros';

  @override
  String get dividendeVsSalaireRequalificationTitle =>
      'Riesgo de recalificación';

  @override
  String get dividendeVsSalaireRequalificationBody =>
      'Si la parte salarial es inferior al ~60% del beneficio, la administración fiscal puede recalificar dividendos como salario.';

  @override
  String get dividendeVsSalairePartSalaireLabel => 'Parte salario';

  @override
  String get dividendeVsSalairePartDividende => 'Parte dividendo';

  @override
  String dividendeVsSalairePctBenefice(int pct) {
    return '$pct% del beneficio';
  }

  @override
  String get dividendeVsSalaireChargeSalaire => 'Carga sobre salario';

  @override
  String get dividendeVsSalaireChargeDividende => 'Carga sobre dividendo';

  @override
  String get dividendeVsSalaireChargeTotalSplit => 'Carga total (split)';

  @override
  String get dividendeVsSalaireCharge100Salaire => 'Carga si 100% salario';

  @override
  String get dividendeVsSalaireChartTitle => 'Carga total por split';

  @override
  String get dividendeVsSalairePctSalaire0 => '0% salario';

  @override
  String get dividendeVsSalairePctSalaire100 => '100% salario';

  @override
  String get dividendeVsSalaireChargeTotale => 'Carga total';

  @override
  String get dividendeVsSalaireSplitAdapte => 'Split adaptado';

  @override
  String get dividendeVsSalairePositionActuelle => 'Posición actual';

  @override
  String get dividendeVsSalaireARetenir => 'A recordar';

  @override
  String get dividendeVsSalaireEduImpotTitle => 'Impuesto sobre beneficios';

  @override
  String get dividendeVsSalaireEduImpotBody =>
      'El beneficio distribuido como dividendo se grava primero a nivel de empresa, luego a nivel personal.';

  @override
  String get dividendeVsSalaireEduAvsTitle => 'AVS solo sobre salario';

  @override
  String get dividendeVsSalaireEduAvsBody =>
      'Las cotizaciones AVS (~12.5%) solo se aplican al salario. El dividendo escapa las cargas sociales.';

  @override
  String get dividendeVsSalaireEduCantonalTitle => 'Práctica cantonal';

  @override
  String get dividendeVsSalaireEduCantonalBody =>
      'Las autoridades fiscales vigilan distribuciones excesivas de dividendos.';

  @override
  String get dividendeVsSalaireDisclaimer =>
      'Simulación simplificada. Consulta un especialista para un análisis completo.';

  @override
  String get dividendeVsSalaireCantonalDisclaimer =>
      'El impacto fiscal depende de la práctica cantonal.';

  @override
  String get dividendeVsSalaireComplianceFooter =>
      'Herramienta educativa — no constituye asesoramiento financiero (LSFin).';

  @override
  String get dividendeVsSalaireSources =>
      'Fuentes: LIFD art. 18, 20, 33; CO art. 660';

  @override
  String get lppVolontaireTitle => 'LPP voluntaria';

  @override
  String get lppVolontaireHeaderInfo =>
      'Como independiente, puedes afiliarte voluntariamente a un fondo de pensiones (LPP). Las cotizaciones son deducibles.';

  @override
  String get lppVolontaireRevenuLabel => 'Ingreso neto anual';

  @override
  String get lppVolontaireSliderMax250k => 'CHF 250’000';

  @override
  String get lppVolontaireTonAge => 'Tu edad';

  @override
  String get lppVolontaireAgeMin => '25 años';

  @override
  String get lppVolontaireAgeMax => '65 años';

  @override
  String get lppVolontaireTauxMarginal => 'Tasa marginal';

  @override
  String lppVolontaireChiffreChocCaption(String amount) {
    return 'Sin LPP voluntaria, pierdes $amount/año de capitalización para la jubilación';
  }

  @override
  String get lppVolontaireSalaireCoordonne => 'Salario coordinado';

  @override
  String get lppVolontaireTauxBonification => 'Tasa bonificación';

  @override
  String get lppVolontaireCotisationAn => 'Cotización /año';

  @override
  String get lppVolontaireEconomieFiscaleAn => 'Ahorro fiscal /año';

  @override
  String get lppVolontaireTrancheAge => 'Tramo de edad';

  @override
  String get lppVolontaireProjectionTitle => 'Proyección jubilatoria anual';

  @override
  String get lppVolontaireSansLpp => 'Sin LPP (solo AVS)';

  @override
  String get lppVolontaireAvecLpp => 'Con LPP voluntaria';

  @override
  String lppVolontaireGapLabel(String amount) {
    return 'La LPP voluntaria podría añadir $amount/año a tu pensión';
  }

  @override
  String get lppVolontaireBonificationTitle => 'Tasa de bonificación por edad';

  @override
  String get lppVolontaireToi => 'TÚ';

  @override
  String get lppVolontaireBonASavoir => 'Bueno saber';

  @override
  String get lppVolontaireEduAffiliationTitle => 'Afiliación voluntaria';

  @override
  String get lppVolontaireEduAffiliationBody =>
      'Los independientes pueden afiliarse voluntariamente a la LPP.';

  @override
  String get lppVolontaireEduFiscalTitle => 'Doble ventaja fiscal';

  @override
  String get lppVolontaireEduFiscalBody =>
      'Las cotizaciones LPP voluntarias son deducibles del ingreso imponible.';

  @override
  String get lppVolontaireEduImpact3aTitle => 'Impacto en el 3a';

  @override
  String get lppVolontaireEduImpact3aBody =>
      'Si te afilias a una LPP voluntaria, tu tope 3a baja del gran 3a al pequeño 3a.';

  @override
  String get lppVolontaireDisclaimer =>
      'Las proyecciones son estimaciones. Consulta un especialista en previsión.';

  @override
  String lppVolontairePerAn(String amount) {
    return '$amount/año';
  }

  @override
  String get coverageCheckTitle => 'Check-up cobertura';

  @override
  String get coverageCheckAppBarTitle => 'Check-up cobertura';

  @override
  String get coverageCheckSubtitle => 'Evalúa tu protección aseguradora';

  @override
  String get coverageCheckDemoMode => 'MODO DEMO';

  @override
  String get coverageCheckTonProfil => 'Tu perfil';

  @override
  String get coverageCheckStatut => 'Estatus profesional';

  @override
  String get coverageCheckSalarie => 'Empleado';

  @override
  String get coverageCheckIndependant => 'Independiente';

  @override
  String get coverageCheckSansEmploi => 'Sin empleo';

  @override
  String get coverageCheckHypotheque => 'Hipoteca en curso';

  @override
  String get coverageCheckPersonnesCharge => 'Personas a cargo';

  @override
  String get coverageCheckLocataire => 'Inquilino';

  @override
  String get coverageCheckVoyages => 'Viajes frecuentes';

  @override
  String get coverageCheckCouvertureActuelle => 'Mi cobertura actual';

  @override
  String get coverageCheckIjm => 'IJM colectiva (empleador)';

  @override
  String get coverageCheckLaa => 'LAA (seguro accidentes)';

  @override
  String get coverageCheckRcPrivee => 'RC privada';

  @override
  String get coverageCheckMenage => 'Seguro hogar';

  @override
  String get coverageCheckProtJuridique => 'Protección jurídica';

  @override
  String get coverageCheckVoyage => 'Seguro viaje';

  @override
  String get coverageCheckDeces => 'Seguro fallecimiento';

  @override
  String get coverageCheckScore => 'Score de cobertura';

  @override
  String coverageCheckLacunes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lagunas críticas',
      one: '$count laguna crítica',
    );
    return '$_temp0';
  }

  @override
  String get coverageCheckAnalyseTitle => 'Análisis detallado';

  @override
  String get coverageCheckRecommandationsTitle => 'Recomendaciones';

  @override
  String get coverageCheckCouvert => 'Cubierto';

  @override
  String get coverageCheckNonCouvert => 'No cubierto';

  @override
  String get coverageCheckAVerifier => 'A verificar';

  @override
  String get coverageCheckCritique => 'Crítico';

  @override
  String get coverageCheckHaute => 'Alta';

  @override
  String get coverageCheckMoyenne => 'Media';

  @override
  String get coverageCheckBasse => 'Baja';

  @override
  String get coverageCheckDisclaimer =>
      'Este análisis es indicativo. Consulta un especialista en seguros.';

  @override
  String get coverageCheckSources => 'Fuentes';

  @override
  String get coverageCheckSourcesBody =>
      'CO art. 41 (RC) / CO art. 324a (IJM) / LAA art. 4 / LAMal art. 34 / LCA / Derecho cantonal';

  @override
  String get coverageCheckSlashHundred => '/ 100';

  @override
  String coverageCheckAnsLabel(int age) {
    return '$age años';
  }

  @override
  String get eplAppBarTitle => 'Retiro EPL';

  @override
  String get eplIntroTitle => 'Retiro EPL — Propiedad de vivienda';

  @override
  String get eplIntroBody =>
      'El EPL permite utilizar tu ahorro LPP para financiar la compra de una vivienda, amortizar una hipoteca o financiar renovaciones. Monto mínimo: CHF 20’000. Este retiro impacta directamente tus prestaciones de riesgo.';

  @override
  String get eplSectionParametres => 'Parámetros';

  @override
  String get eplLabelAvoirTotal => 'Ahorro LPP total';

  @override
  String get eplLabelAge => 'Edad';

  @override
  String eplLabelAgeFormat(int age) {
    return '$age años';
  }

  @override
  String get eplLabelMontantSouhaite => 'Monto deseado';

  @override
  String get eplLabelCanton => 'Cantón';

  @override
  String get eplLabelRachatsRecents => 'Compras LPP recientes';

  @override
  String get eplLabelRachatsQuestion =>
      '¿Has realizado una compra LPP en los últimos 3 años?';

  @override
  String get eplLabelAnneesSDepuisRachat => 'Años desde la compra';

  @override
  String eplLabelAnneesSDepuisRachatFormat(int years, String suffix) {
    return '$years año$suffix';
  }

  @override
  String get eplSectionResultat => 'Resultado';

  @override
  String get eplMontantMaxRetirable => 'Monto máximo retirable';

  @override
  String get eplMontantApplicable => 'Monto aplicable';

  @override
  String get eplRetraitImpossible =>
      'El retiro no es posible con la configuración actual.';

  @override
  String get eplSectionImpactPrestations => 'Impacto en las prestaciones';

  @override
  String get eplReductionInvalidite =>
      'Reducción renta invalidez (estimación anual)';

  @override
  String get eplReductionDeces =>
      'Reducción capital-fallecimiento (estimación)';

  @override
  String get eplImpactPrestationsNote =>
      'El retiro EPL reduce proporcionalmente tus prestaciones de riesgo. Consulta con tu caja de pensiones los montos exactos y las posibilidades de seguro complementario.';

  @override
  String get eplSectionImpactRente => 'Impacto en la renta';

  @override
  String get eplRenteSansEpl => 'Renta sin EPL';

  @override
  String get eplRenteAvecEpl => 'Renta con EPL';

  @override
  String get eplPerteMensuelle => 'Pérdida mensual';

  @override
  String get eplImpactRenteNote =>
      'Estimación educativa basada en un salario de CHF 100’000, rendimiento caja 2%, tasa de conversión 6.8%. El monto real depende de tu situación.';

  @override
  String get eplSectionFiscale => 'Estimación fiscal';

  @override
  String get eplMontantRetire => 'Monto retirado';

  @override
  String get eplImpotEstime => 'Impuesto estimado sobre el retiro';

  @override
  String get eplMontantNet => 'Monto neto después de impuestos';

  @override
  String get eplFiscaleNote =>
      'El retiro en capital se grava a una tasa reducida (aprox. 1/5 de la escala ordinaria). La tasa exacta depende del cantón, la comuna y la situación personal.';

  @override
  String get eplSectionPointsAttention => 'Puntos de atención';

  @override
  String get librePassageAppBarTitle => 'Libre paso';

  @override
  String get librePassageSectionSituation => 'Situación';

  @override
  String get librePassageChipChangementEmploi => 'Cambio de empleo';

  @override
  String get librePassageChipDepartSuisse => 'Salida de Suiza';

  @override
  String get librePassageChipCessationActivite => 'Cese de actividad';

  @override
  String get librePassageSectionProfil => 'Tu perfil';

  @override
  String get librePassageLabelAge => 'Tu edad';

  @override
  String librePassageLabelAgeFormat(int age) {
    return '$age años';
  }

  @override
  String get librePassageLabelAvoir => 'Ahorro de libre paso';

  @override
  String get librePassageLabelNouvelEmployeur => 'Nuevo empleador';

  @override
  String get librePassageLabelNouvelEmployeurQuestion =>
      '¿Ya tienes un nuevo empleador?';

  @override
  String get librePassageSectionAlertes => 'Alertas';

  @override
  String get librePassageSectionChecklist => 'Checklist';

  @override
  String get librePassageUrgenceCritique => 'Crítico';

  @override
  String get librePassageUrgenceHaute => 'Alta';

  @override
  String get librePassageUrgenceMoyenne => 'Media';

  @override
  String get librePassageSectionRecommandations => 'Recomendaciones';

  @override
  String get librePassageCentrale2eTitle => 'Central del 2° pilar (sfbvg.ch)';

  @override
  String get librePassageCentrale2eSubtitle =>
      'Buscar ahorros de libre paso olvidados';

  @override
  String get librePassagePrivacyNote =>
      'Tus datos permanecen en tu dispositivo. Ninguna información se transmite a terceros. Conforme a la nLPD.';

  @override
  String get providerComparatorAppBarTitle => 'Comparador 3a';

  @override
  String providerComparatorChiffreChocLabel(int duree) {
    return 'Diferencia en $duree años';
  }

  @override
  String get providerComparatorChiffreChocSubtitle =>
      'entre el proveedor más y menos rentable';

  @override
  String get providerComparatorSectionParametres => 'Parámetros';

  @override
  String get providerComparatorLabelAge => 'Edad';

  @override
  String providerComparatorLabelAgeFormat(int age) {
    return '$age años';
  }

  @override
  String get providerComparatorLabelVersement => 'Aporte anual';

  @override
  String get providerComparatorLabelDuree => 'Duración';

  @override
  String providerComparatorLabelDureeFormat(int duree) {
    return '$duree años';
  }

  @override
  String get providerComparatorLabelProfilRisque => 'Perfil de riesgo';

  @override
  String get providerComparatorProfilPrudent => 'Prudente';

  @override
  String get providerComparatorProfilEquilibre => 'Equilibrado';

  @override
  String get providerComparatorProfilDynamique => 'Dinámico';

  @override
  String get providerComparatorSectionComparaison => 'Comparación';

  @override
  String get providerComparatorRendement => 'Rendimiento';

  @override
  String get providerComparatorFrais => 'Costes';

  @override
  String get providerComparatorCapitalFinal => 'Capital final';

  @override
  String get providerComparatorWarningLabel => 'Atención';

  @override
  String providerComparatorDiffVsPremier(String amount) {
    return '-CHF $amount vs primero';
  }

  @override
  String get providerComparatorAssuranceTitle => 'Atención — Seguro 3a';

  @override
  String get providerComparatorAssuranceNote =>
      'Los seguros 3a combinan ahorro y cobertura de riesgo, pero las comisiones altas (a menudo > 1.5%) y la rigidez del contrato los hacen desfavorables para jóvenes ahorradores.';

  @override
  String documentDetailFieldsExtracted(int found, int total) {
    return '$found campos extraídos de $total';
  }

  @override
  String get documentDetailProfileUpdated => 'Perfil actualizado con éxito';

  @override
  String get documentDetailCancelButton => 'Cancelar';

  @override
  String get portfolioTitle => 'Mi patrimonio';

  @override
  String get portfolioNetWorth => 'Valor neto total';

  @override
  String get portfolioReadiness => 'Índice de preparación';

  @override
  String get portfolioEnvelopeTitle => 'Distribución por sobre';

  @override
  String get portfolioLibre => 'Libre (Cuenta inversión)';

  @override
  String get portfolioLie => 'Vinculado (Pilar 3a)';

  @override
  String get portfolioReserve => 'Reservado (Fondo de emergencia)';

  @override
  String get portfolioCoachAdvice =>
      'Tu asignación es saludable. Piensa en reequilibrar tu 3a pronto.';

  @override
  String get portfolioDebtWarning =>
      'Alerta de deudas: Tu prioridad absoluta es reducir las deudas antes de reinvertir.';

  @override
  String get portfolioSafeModeTitle => 'Prioridad: desendeudamiento';

  @override
  String get portfolioSafeModeMsg =>
      'Los consejos de asignación están desactivados en modo protección. Tu prioridad es reducir tus deudas.';

  @override
  String get portfolioRetirement => 'Preparación jubilación';

  @override
  String get portfolioProperty => 'Proyecto inmobiliario';

  @override
  String get portfolioFamily => 'Protección familiar';

  @override
  String get portfolioToday => 'hoy';

  @override
  String get timelineTitle => 'Mi recorrido';

  @override
  String get timelineHeader => 'Tu vida financiera,\npaso a paso.';

  @override
  String get timelineSubheader =>
      'Herramientas esenciales y eventos de vida — todo está aquí.';

  @override
  String get timelineSectionTitle => 'Eventos de vida';

  @override
  String get timelineSectionSubtitle =>
      'Selecciona un evento para simular su impacto financiero.';

  @override
  String get confidenceDashboardTitle => 'Precisión de tu perfil';

  @override
  String get confidenceDetailByAxis => 'Detalle por eje';

  @override
  String get confidenceFeatureGates => 'Funciones desbloqueadas';

  @override
  String get confidenceImprove => 'Mejora tu precisión';

  @override
  String confidenceRequired(int percent) {
    return '$percent % requerido';
  }

  @override
  String get confidenceLevelExcellent => 'Excelente';

  @override
  String get confidenceLevelGood => 'Buena';

  @override
  String get confidenceLevelOk => 'Correcta';

  @override
  String get confidenceLevelImprove => 'A mejorar';

  @override
  String get confidenceLevelInsufficient => 'Insuficiente';

  @override
  String get confidenceSources => 'Fuentes';

  @override
  String get cockpitDetailTitle => 'Cockpit detallado';

  @override
  String get cockpitEmptyMsg =>
      'Completa tu perfil para acceder al cockpit detallado.';

  @override
  String get cockpitEnrichCta => 'Enriquecer mi perfil';

  @override
  String get cockpitDisclaimer =>
      'Herramienta educativa simplificada. No constituye asesoramiento financiero (LSFin). Fuentes: LAVS art. 21-29, LPP art. 14, OPP3 art. 7.';

  @override
  String get annualRefreshTitle => 'Revisión anual';

  @override
  String get annualRefreshIntro =>
      'Unas preguntas rápidas para actualizar tu perfil.';

  @override
  String get annualRefreshSubmit => 'Actualizar mi perfil';

  @override
  String get annualRefreshResult => '¡Perfil actualizado!';

  @override
  String get annualRefreshDashboard => 'Volver al dashboard';

  @override
  String get annualRefreshDisclaimer =>
      'Esta herramienta es de carácter educativo y no constituye asesoramiento financiero en el sentido de la LSFin. Consulta a un·a especialista para obtener asesoramiento personalizado.';

  @override
  String get acceptInvitationTitle => 'Unirme a un hogar';

  @override
  String get acceptInvitationPrompt => 'Introduce el código de tu pareja';

  @override
  String get acceptInvitationCodeValidity =>
      'El código es válido durante 72 horas.';

  @override
  String get acceptInvitationJoin => 'Unirme al hogar';

  @override
  String get acceptInvitationSuccess => '¡Bienvenido al hogar!';

  @override
  String get acceptInvitationSuccessBody =>
      'Te uniste al hogar Couple+. Tus proyecciones de jubilación están vinculadas.';

  @override
  String get acceptInvitationViewHousehold => 'Ver mi hogar';

  @override
  String get financialReportTitle => 'Tu Plan Mint';

  @override
  String get financialReportBudget => 'Tu presupuesto';

  @override
  String get financialReportProtection => 'Tu protección';

  @override
  String get financialReportRetirement => 'Tu jubilación';

  @override
  String get financialReportTax => 'Tus impuestos';

  @override
  String get financialReportPriorities => 'Tus 3 acciones prioritarias';

  @override
  String get financialReportOptimize3a => 'Optimiza tu 3a';

  @override
  String get financialReportLppStrategy => 'Estrategia rescate LPP';

  @override
  String get financialReportTransparency => 'Transparencia y cumplimiento';

  @override
  String get financialReportLegalMention => 'Mención legal';

  @override
  String get financialReportDisclaimer =>
      'Herramienta educativa — no constituye asesoramiento financiero según la LSFin. Los importes son estimaciones basadas en datos declarados.';

  @override
  String get capKindComplete => 'Completar';

  @override
  String get capKindCorrect => 'Corregir';

  @override
  String get capKindOptimize => 'Optimizar';

  @override
  String get capKindSecure => 'Asegurar';

  @override
  String get capKindPrepare => 'Preparar';

  @override
  String get proofSheetSources => 'Fuentes';

  @override
  String get pulseFeedbackRecalculated => 'Impacto recalculado';

  @override
  String get pulseFeedbackAddedRecently => 'Añadido recientemente';

  @override
  String get debtRatioTitle => 'Diagnóstico de deuda';

  @override
  String get debtRatioSubLabel => 'Ratio deuda / ingresos';

  @override
  String get debtRatioRefineLabel => 'Refinar el diagnóstico';

  @override
  String get debtRatioMinVital => 'Mínimo vital (LP art. 93)';

  @override
  String get debtRatioRecommandations => 'Recomendaciones';

  @override
  String get debtRatioCtaRouge => 'Crea tu plan de reembolso';

  @override
  String get debtRatioCtaOrange => 'Optimiza tus reembolsos';

  @override
  String get debtRatioAidePro => 'Ayuda profesional';

  @override
  String get repaymentTitle => 'Plan de reembolso';

  @override
  String get repaymentLibereDans => 'Libre de deuda en';

  @override
  String get repaymentMesDettes => 'Mis deudas';

  @override
  String get repaymentBudgetLabel => 'Presupuesto de reembolso';

  @override
  String get repaymentComparaisonStrategies => 'Comparación de estrategias';

  @override
  String get repaymentStrategyNote =>
      'La elección depende de tu personalidad financiera, no solo del coste.';

  @override
  String get repaymentTimelineTitle => 'Cronología (Alud)';

  @override
  String get repaymentTimelineMois => 'Mes';

  @override
  String get repaymentTimelinePaiement => 'Pago';

  @override
  String get repaymentTimelineSolde => 'Saldo restante';

  @override
  String get retroactive3aTitle => 'Recuperación 3a';

  @override
  String get retroactive3aHeroTitle => 'Recuperación 3a — Novedad 2026';

  @override
  String get retroactive3aHeroSubtitle =>
      'Recupera hasta 10 años de cotizaciones perdidas';

  @override
  String get retroactive3aParametres => 'Parámetros';

  @override
  String get retroactive3aAnneesARattraper => 'Años a recuperar';

  @override
  String get retroactive3aTauxMarginal => 'Tasa marginal de imposición';

  @override
  String get retroactive3aAffilieLpp =>
      'Afiliado·a a una caja de pensiones (LPP)';

  @override
  String get retroactive3aPetit3a => 'Pequeño 3a : CHF 7’258/año';

  @override
  String get retroactive3aGrand3a =>
      'Gran 3a : 20 % de ingresos netos, máx. CHF 36’288/año';

  @override
  String get retroactive3aEconomiesFiscales => 'Ahorros fiscales estimados';

  @override
  String get retroactive3aDetailParAnnee => 'Desglose por año';

  @override
  String get retroactive3aHeaderAnnee => 'Año';

  @override
  String get retroactive3aHeaderPlafond => 'Límite';

  @override
  String get retroactive3aHeaderDeductible => 'Deducible';

  @override
  String get retroactive3aTotal => 'Total';

  @override
  String get retroactive3aAnneeCourante => 'Año en curso';

  @override
  String get retroactive3aImpactAvantApres => 'Impacto antes / después';

  @override
  String get retroactive3aSansRattrapage => 'Sin recuperación';

  @override
  String get retroactive3aAnneeCouranteSeule => 'Solo año en curso';

  @override
  String get retroactive3aAvecRattrapage => 'Con recuperación';

  @override
  String get retroactive3aEconomieFiscale => 'de ahorro fiscal';

  @override
  String get retroactive3aProchainesEtapes => 'Próximos pasos';

  @override
  String get retroactive3aOuvrirCompte => 'Abrir una cuenta 3a';

  @override
  String get retroactive3aOuvrirCompteSubtitle =>
      'Compara proveedores y abre una cuenta dedicada a la recuperación.';

  @override
  String get retroactive3aPrepDocuments => 'Preparar documentos';

  @override
  String get retroactive3aPrepDocumentsSubtitle =>
      'Certificado de salario, certificado de cotizaciones AVS, justificante de ausencia de 3a por cada año.';

  @override
  String get retroactive3aConsulterSpecialiste =>
      'Consultar a un·a especialista';

  @override
  String get retroactive3aConsulterSpecialisteSubtitle =>
      'Un·a experto·a fiscal puede confirmar tu tasa marginal y optimizar el calendario de pagos.';

  @override
  String get retroactive3aSources => 'Fuentes';

  @override
  String coverageCriticalGaps(Object count) {
    return 'laguna$count crítica$count';
  }

  @override
  String get coverageCriticalGapSingular => 'laguna crítica';

  @override
  String get coverageCriticalGapPlural => 'lagunas críticas';

  @override
  String get reportTonPlanMint => 'Tu Plan Mint';

  @override
  String get reportCommencer => 'Comenzar';

  @override
  String get reportOptimise3a => 'Optimiza tu 3a';

  @override
  String get reportActions => '🎯 Tus 3 Acciones Prioritarias';

  @override
  String get reportMentionLegale => 'Aviso legal';

  @override
  String get reportDisclaimerText =>
      'Herramienta educativa — no constituye asesoramiento financiero según la LSFin. Los montos son estimaciones.';

  @override
  String get compoundTitle => 'Interés Compuesto';

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
      'Cálculo teórico basado en un rendimiento constante. Los rendimientos pasados no constituyen una garantía de resultados futuros.';

  @override
  String get leasingTitle => 'Análisis Anti-Leasing';

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
  String get creditTitle => 'Crédito al Consumo';

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
  String get arbitrageBilanTitle => 'Resumen de Arbitraje';

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
      'Algunas preguntas rápidas para actualizar tu perfil.';

  @override
  String get annualRefreshQ1 => '¿Ha cambiado tu salario bruto mensual?';

  @override
  String get annualRefreshQ2 => 'Tu situación profesional';

  @override
  String get annualRefreshQ3 => 'Tu capital LPP actual';

  @override
  String get annualRefreshQ3Help =>
      'Consulta tu certificado de previsión (lo recibes cada enero)';

  @override
  String get annualRefreshQ4 => 'Tu saldo aproximado del 3a';

  @override
  String get annualRefreshQ4Help =>
      'Entra en tu app del 3a para ver el saldo exacto';

  @override
  String get annualRefreshQ5 => '¿Algún proyecto inmobiliario en vista?';

  @override
  String get annualRefreshQ6 => '¿Algún cambio familiar este año?';

  @override
  String get annualRefreshQ7 => 'Tu tolerancia al riesgo';

  @override
  String annualRefreshScoreUp(int delta) {
    return '¡Tu puntuación ha aumentado $delta puntos!';
  }

  @override
  String annualRefreshScoreDown(int delta) {
    return 'Tu puntuación ha bajado $delta puntos — revisemos juntos';
  }

  @override
  String get annualRefreshScoreStable =>
      'Tu puntuación es estable — ¡sigue así!';

  @override
  String get annualRefreshRetour => 'Volver al panel';

  @override
  String get annualRefreshAvant => 'Antes';

  @override
  String get annualRefreshApres => 'Después';

  @override
  String get annualRefreshMontantPositif => 'El importe debe ser positivo';

  @override
  String get annualRefreshMemeEmploi => 'Mismo empleo';

  @override
  String get annualRefreshNouvelEmploi => 'Nuevo empleo';

  @override
  String get annualRefreshIndependant => 'Autónomo·a';

  @override
  String get annualRefreshSansEmploi => 'Sin empleo';

  @override
  String get annualRefreshAucun => 'Ninguno';

  @override
  String get annualRefreshAchat => 'Compra';

  @override
  String get annualRefreshVente => 'Venta';

  @override
  String get annualRefreshRefinancement => 'Refinanciación';

  @override
  String get annualRefreshMariage => 'Matrimonio';

  @override
  String get annualRefreshNaissance => 'Nacimiento';

  @override
  String get annualRefreshDivorce => 'Divorcio';

  @override
  String get annualRefreshDeces => 'Fallecimiento';

  @override
  String get annualRefreshConservateur => 'Conservador';

  @override
  String get annualRefreshModere => 'Moderado';

  @override
  String get annualRefreshAgressif => 'Agresivo';

  @override
  String get themeInconnu => 'Tema desconocido';

  @override
  String get themeInconnuBody => 'Este tema no existe. Volviendo atrás.';

  @override
  String get acceptInvitationVoirMenage => 'Ver mi hogar';

  @override
  String get helpResourceSiteWeb => 'Sitio web';

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
  String get locationLouerOuAcheter => '¿Alquilar o comprar?';

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
  String get locationAvertissement => 'Advertencia';

  @override
  String reportBonjour(String name) {
    return '¡Hola $name!';
  }

  @override
  String reportProfileSummary(int age, String canton, String civilStatus) {
    return '$age años • $canton • $civilStatus';
  }

  @override
  String get reportStatusGood => '¡Tu base es sólida, sigue así!';

  @override
  String get reportStatusMedium => 'Algunos ajustes para estar tranquilo';

  @override
  String get reportStatusLow => 'Prioridad: estabiliza tu situación';

  @override
  String get reportReasonDebt => 'Deuda al consumo activa.';

  @override
  String get reportReasonLeasing => 'Leasing activo con carga mensual.';

  @override
  String reportReasonPayments(String amount) {
    return 'Pagos de deuda: CHF $amount / mes.';
  }

  @override
  String get reportReasonEmergency =>
      'Fondo de emergencia insuficiente (< 3 meses).';

  @override
  String get reportReasonFragility =>
      'Señal de fragilidad detectada: prioridad a la estabilidad presupuestaria.';

  @override
  String get reportBudgetTitle => 'Tu Presupuesto';

  @override
  String get reportBudgetKeyLabel => 'Disponible (tras gastos fijos)';

  @override
  String get reportBudgetAction => 'Configurar mis sobres';

  @override
  String get reportProtectionTitle => 'Tu Protección';

  @override
  String get reportProtectionKeyLabel =>
      'Fondo de emergencia (objetivo: 6 meses)';

  @override
  String get reportProtectionSource => 'Fuente: LP art. 93 — Mínimo vital';

  @override
  String get reportProtectionAction => 'Constituir mi fondo de emergencia';

  @override
  String get reportRetirementTitle => 'Tu Jubilación';

  @override
  String get reportRetirementKeyLabel => 'Ingreso estimado a los 65 años';

  @override
  String get reportRetirementSource => 'Fuentes: LPP art. 14, OPP3, LAVS';

  @override
  String get reportRetirement3aNone =>
      'Aún sin 3a — hasta CHF 7’258/año de deducción fiscal posible';

  @override
  String get reportRetirement3aOne =>
      '1 cuenta 3a — abre una 2.a para optimizar el retiro';

  @override
  String reportRetirement3aMulti(int count) {
    return '$count cuentas 3a — buena diversificación';
  }

  @override
  String reportRetirementLppText(String available, String savings) {
    return 'Rescate LPP disponible: CHF $available — ahorro fiscal estimado: CHF $savings';
  }

  @override
  String get reportTaxTitle => 'Tus Impuestos';

  @override
  String reportTaxKeyLabel(String rate) {
    return 'Impuestos estimados (tasa efectiva: $rate%)';
  }

  @override
  String get reportTaxAction => 'Comparar 26 cantones';

  @override
  String get reportTaxSource => 'Fuente: LIFD art. 33';

  @override
  String get reportTaxIncome => 'Renta imponible';

  @override
  String get reportTaxDeductions => 'Deducciones';

  @override
  String get reportTaxEstimated => 'Impuestos estimados';

  @override
  String reportTaxSavings(String amount) {
    return 'Ahorro posible con rescate LPP: CHF $amount/año';
  }

  @override
  String get reportSafeModePriority => 'Prioridad al desendeudamiento';

  @override
  String get reportSafeModeActions =>
      'Tus acciones prioritarias son reemplazadas por un plan de desendeudamiento. Estabiliza tu situación antes de explorar las recomendaciones.';

  @override
  String get reportSafeMode3a =>
      'El comparador 3a está desactivado mientras tengas deudas activas. Pagar las deudas es prioritario antes de cualquier ahorro 3a.';

  @override
  String get reportSafeModeLpp => 'Rescate LPP bloqueado';

  @override
  String get reportSafeModeLppMessage =>
      'El rescate LPP está desactivado en modo protección. Paga tus deudas antes de inmovilizar liquidez en la previsión.';

  @override
  String get reportLppTitle => '💰 Estrategia de Rescate LPP';

  @override
  String reportLppEconomie(String amount) {
    return 'Ahorro fiscal total: CHF $amount';
  }

  @override
  String reportLppYear(int year) {
    return 'Año $year';
  }

  @override
  String reportLppBuyback(String amount) {
    return 'Rescate: CHF $amount';
  }

  @override
  String reportLppSaving(String amount) {
    return 'Ahorro: CHF $amount';
  }

  @override
  String get reportLppHowTitle => '¿Cómo funciona?';

  @override
  String get reportLppHowBody =>
      'Entiende por qué escalonar tus rescates LPP te hace ahorrar miles de francos adicionales.';

  @override
  String get reportSoaTitle => 'Transparencia y conformidad';

  @override
  String get reportSoaNature => 'Naturaleza del servicio';

  @override
  String reportSoaEduPhases(int count) {
    return 'Educación financiera — $count fases identificadas';
  }

  @override
  String get reportSoaEduSimple => 'Educación financiera personalizada';

  @override
  String get reportSoaHypotheses => 'Hipótesis de trabajo';

  @override
  String get reportSoaHyp1 => 'Ingresos declarados estables durante el período';

  @override
  String get reportSoaHyp2 => 'Tasa de conversión LPP obligatoria: 6,8 %';

  @override
  String get reportSoaHyp3 => 'Límite 3a asalariado: CHF 7’258/año';

  @override
  String get reportSoaHyp4 => 'Renta AVS máxima: CHF 30’240/año';

  @override
  String get reportSoaConflicts => 'Conflictos de interés';

  @override
  String get reportSoaNoConflict =>
      'Ningún conflicto de interés identificado para este informe.';

  @override
  String get reportSoaNoCommission =>
      'MINT no percibe ninguna comisión sobre los productos mencionados.';

  @override
  String get reportSoaLimitations => 'Limitaciones';

  @override
  String get reportSoaLim1 => 'Basado únicamente en información declarativa';

  @override
  String get reportSoaLim2 =>
      'Estimación fiscal aproximada (tasas medias cantonales)';

  @override
  String get reportSoaLim3 =>
      'No tiene en cuenta los ingresos de patrimonio mobiliario';

  @override
  String get reportSoaLim4 =>
      'Las proyecciones no tienen en cuenta la inflación';

  @override
  String get checkinEvolution => 'Tu evolución';

  @override
  String get portfolioReadinessTitle => 'Índice de Preparación (Hitos)';

  @override
  String get portfolioPerennite => 'Sostenibilidad Jubilación';

  @override
  String get portfolioProjetImmo => 'Proyecto Inmobiliario';

  @override
  String get portfolioProtectionFamille => 'Protección Familiar';

  @override
  String get portfolioAllocationSaine =>
      'Tu asignación es saludable. Piensa en reequilibrar tu 3a pronto.';

  @override
  String get portfolioAlerteDettes =>
      'Alerta Deudas: Tu prioridad es el pago de deudas antes de cualquier reinversión.';

  @override
  String get dividendeSplitMin => '0% salario';

  @override
  String get dividendeSplitMax => '100% salario';

  @override
  String get disabilityInsAppBarTitle => 'Mi cobertura';

  @override
  String get disabilityInsTitle => 'Mi cobertura por invalidez';

  @override
  String get disabilityInsSubtitle =>
      'Informe de cobertura · Franquicia LAMal · AI/APG';

  @override
  String get disabilityInsRefineSituation => 'Afina tu situación';

  @override
  String get disabilityInsGrossSalary => 'Salario bruto mensual';

  @override
  String get disabilityInsSavings => 'Ahorro disponible';

  @override
  String get disabilityInsIjmEmployer =>
      'Seguro de pérdida de ganancias vía empleador';

  @override
  String get disabilityInsPrivateLossInsurance =>
      'Seguro privado de pérdida de ganancias';

  @override
  String get disabilityInsDisclaimer =>
      'Herramienta educativa — no constituye asesoramiento en seguros. Los importes de franquicia y primas son indicativos. Compara ofertas en comparaison.ch o a través de un·a corredor·a independiente.';

  @override
  String get disabilityInsSources =>
      '• LAMal art. 64-64a (franquicia)\n• OAMal art. 93 (primas)\n• LAI art. 28 (pensión de invalidez)\n• LPP art. 23-26 (invalidez 2° pilar)';

  @override
  String repaymentDiffStrategies(String amount) {
    return 'Diferencia entre las dos estrategias: CHF $amount';
  }

  @override
  String get repaymentAddDebtHint =>
      'Añade tus deudas para generar un plan de amortización.';

  @override
  String get repaymentAddDebtTooltip => 'Añadir una deuda';

  @override
  String get repaymentDebtNameHint => 'Nombre de la deuda';

  @override
  String get repaymentFieldAmount => 'Importe';

  @override
  String get repaymentFieldAmountLabel => 'Importe de la deuda';

  @override
  String get repaymentFieldRate => 'Tasa';

  @override
  String get repaymentFieldRateLabel => 'Tasa anual';

  @override
  String get repaymentFieldInstallment => 'Cuota mensual';

  @override
  String get repaymentFieldInstallmentLabel => 'Cuota mínima mensual';

  @override
  String get repaymentNewDebt => 'Nueva deuda';

  @override
  String get repaymentBudgetEditorLabel =>
      'Presupuesto mensual de amortización';

  @override
  String repaymentBudgetDisplay(String amount) {
    return 'CHF $amount / mes';
  }

  @override
  String get repaymentAvalancheTitle => 'AVALANCHA';

  @override
  String get repaymentAvalancheSubtitle => 'Tasa más alta primero';

  @override
  String get repaymentAvalanchePro => 'Menos intereses pagados';

  @override
  String get repaymentSnowballTitle => 'BOLA DE NIEVE';

  @override
  String get repaymentSnowballSubtitle => 'Saldo más pequeño primero';

  @override
  String get repaymentSnowballPro => 'Motivación con pequeñas victorias';

  @override
  String get repaymentRowLiberation => 'Fecha de liberación';

  @override
  String get repaymentRowInterets => 'Intereses totales';

  @override
  String repaymentDifference(String amount) {
    return 'Diferencia: CHF $amount';
  }

  @override
  String get repaymentValidate => 'Confirmar';

  @override
  String get repaymentEmptyState =>
      'Añade tus deudas y define tu presupuesto mensual de amortización para ver el plan.';

  @override
  String repaymentMinMax(String minVal, String maxVal) {
    return 'Mín $minVal · Máx $maxVal';
  }

  @override
  String repaymentInteretsDisplay(String amount) {
    return 'CHF $amount intereses';
  }

  @override
  String repaymentDurationDisplay(int months) {
    return '$months meses';
  }

  @override
  String get debtRatioLevelSain => 'SANO';

  @override
  String get debtRatioLevelAttention => 'ATENCIÓN';

  @override
  String get debtRatioLevelCritique => 'CRÍTICO';

  @override
  String get debtRatioRevenuNet => 'Renta neta';

  @override
  String get debtRatioChargesDette => 'Cargas de deuda';

  @override
  String get debtRatioLoyer => 'Alquiler';

  @override
  String get debtRatioAutresCharges => 'Otros gastos';

  @override
  String get debtRatioRefineSuffix => 'Alquiler, situación, hijos';

  @override
  String get debtRatioSituation => 'Situación';

  @override
  String get debtRatioSeul => 'Solo/a';

  @override
  String get debtRatioEnCouple => 'En pareja';

  @override
  String get debtRatioEnfants => 'Hijos';

  @override
  String get debtRatioMinimumVitalLabel => 'Mínimo vital';

  @override
  String get debtRatioMargeDisponible => 'Margen disponible';

  @override
  String get debtRatioMinVitalWarning =>
      'Tu margen residual está por debajo del mínimo vital. Contacta un servicio de ayuda profesional.';

  @override
  String get debtRatioCtaSemantics => 'Crear un plan de amortización';

  @override
  String get debtRatioCtaDescription =>
      'Compara avalancha y bola de nieve para amortizar más rápido.';

  @override
  String get debtRatioDetteConseilNom => 'Dettes Conseils Suisse';

  @override
  String get debtRatioDetteConseilDesc =>
      'Asesoramiento gratuito y confidencial';

  @override
  String get debtRatioCaritasNom => 'Caritas — Ayuda con deudas';

  @override
  String get debtRatioCaritasDesc =>
      'Ayuda para el saneamiento de deudas y negociación';

  @override
  String get debtRatioValidate => 'Confirmar';

  @override
  String debtRatioMinMaxDisplay(String minVal, String maxVal) {
    return 'Mín $minVal · Máx $maxVal';
  }

  @override
  String get timelineCatFamille => 'FAMILIA';

  @override
  String get timelineCatProfessionnel => 'PROFESIONAL';

  @override
  String get timelineCatPatrimoine => 'PATRIMONIO';

  @override
  String get timelineCatSante => 'SALUD';

  @override
  String get timelineCatMobilite => 'MOVILIDAD';

  @override
  String get timelineCatCrise => 'CRISIS';

  @override
  String get timelineSectionTitleUpper => 'EVENTOS DE VIDA';

  @override
  String get timelineEventMariageTitle => 'Matrimonio';

  @override
  String get timelineEventMariageSub =>
      'Impacto en LPP, AVS, impuestos y régimen matrimonial';

  @override
  String get timelineEventConcubinageTitle => 'Convivencia';

  @override
  String get timelineEventConcubitageSub =>
      'Previsión, sucesión y fiscalidad de la pareja no casada';

  @override
  String get timelineEventNaissanceTitle => 'Nacimiento';

  @override
  String get timelineEventNaissanceSub =>
      'Subsidios, deducciones fiscales y seguros';

  @override
  String get timelineEventDivorceTitle => 'Divorcio';

  @override
  String get timelineEventDivorceSub =>
      'División LPP, pensión y reorganización financiera';

  @override
  String get timelineEventSuccessionTitle => 'Sucesión';

  @override
  String get timelineEventSuccessionSub =>
      'Reservas hereditarias, reparto e impuestos (CC art. 457ss)';

  @override
  String get timelineEventPremierEmploiTitle => 'Primer empleo';

  @override
  String get timelineEventPremierEmploiSub =>
      'Primeros pasos : AVS, LPP, 3a y presupuesto';

  @override
  String get timelineEventChangementEmploiTitle => 'Cambio de empleo';

  @override
  String get timelineEventChangementEmploiSub =>
      'Comparación LPP, libre paso y negociación';

  @override
  String get timelineEventIndependantTitle => 'Autónomo';

  @override
  String get timelineEventIndependantSub =>
      'AVS, LPP voluntaria, 3a ampliado y dividendo vs salario';

  @override
  String get timelineEventPerteEmploiTitle => 'Pérdida de empleo';

  @override
  String get timelineEventPerteEmploiSub =>
      'Desempleo, período de espera y protección de previsión';

  @override
  String get timelineEventRetraiteTitle => 'Jubilación';

  @override
  String get timelineEventRetraiteSub =>
      'Renta vs capital, escalonamiento 3a, laguna AVS';

  @override
  String get timelineEventAchatImmoTitle => 'Compra inmobiliaria';

  @override
  String get timelineEventAchatImmoSub =>
      'Capacidad de préstamo, EPL e impuesto sobre valor locativo';

  @override
  String get timelineEventVenteImmoTitle => 'Venta inmobiliaria';

  @override
  String get timelineEventVenteImmoSub =>
      'Plusvalía, impuesto cantonal y reinversión';

  @override
  String get timelineEventHeritageTitle => 'Herencia';

  @override
  String get timelineEventHeritageSub =>
      'Estimación, impuesto cantonal y reparto sucesoral';

  @override
  String get timelineEventDonationTitle => 'Donación';

  @override
  String get timelineEventDonationSub =>
      'Impuesto cantonal, reservas y cuota disponible';

  @override
  String get timelineEventInvaliditeTitle => 'Invalidez';

  @override
  String get timelineEventInvaliditeSub =>
      'Laguna de cobertura AI + LPP y prevención';

  @override
  String get timelineEventDemenagementTitle => 'Mudanza cantonal';

  @override
  String get timelineEventDemenagementSub =>
      'Impacto fiscal del cambio de cantón (26 tarifas)';

  @override
  String get timelineEventExpatriationTitle => 'Expatriación / Fronterizo';

  @override
  String get timelineEventExpatriationSub =>
      'Doble imposición, 3a y cobertura social';

  @override
  String get timelineEventSurendettementTitle => 'Sobreendeudamiento';

  @override
  String get timelineEventSurendettementSub =>
      'Ratio de deuda, plan de pago y ayuda';

  @override
  String get timelineQuickCheckupTitle => 'Check-up financiero';

  @override
  String get timelineQuickCheckupSub => 'Iniciar el diagnóstico completo';

  @override
  String get timelineQuickBudgetTitle => 'Presupuesto';

  @override
  String get timelineQuickBudgetSub => 'Gestionar el flujo de caja mensual';

  @override
  String get timelineQuickPilier3aTitle => 'Pilar 3a';

  @override
  String get timelineQuickPilier3aSub => 'Optimizar la deducción fiscal';

  @override
  String get timelineQuickFiscaliteTitle => 'Fiscalidad';

  @override
  String get timelineQuickFiscaliteSub => 'Comparar 26 cantones';

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
  String get actionSuccessNext => 'Siguiente paso';

  @override
  String get actionSuccessDone => 'Entendido';

  @override
  String get dividendeBeneficeTotal => 'Beneficio total';

  @override
  String get dividendePartSalaire => 'Parte salarial';

  @override
  String get dividendeTauxMarginal => 'Tipo marginal de impuesto';

  @override
  String get successionUrgence => 'Urgencia inmediata';

  @override
  String get successionDemarches => 'Trámites administrativos';

  @override
  String get successionLegale => 'Sucesión legal';

  @override
  String get disabilityGapEmployerSub =>
      'CO art. 324a — 3 a 26 semanas según antigüedad';

  @override
  String get disabilityGapAiDelaySub =>
      'Plazo medio decisión AI: 14 meses · LAI art. 28 + LPP art. 23';

  @override
  String get indepCaisseLpp => 'Caja LPP voluntaria';

  @override
  String get indepCaisseLppSub => 'Cobertura pensión invalidez + jubilación';

  @override
  String get indepGrand3a => 'Gran 3a (sin LPP)';

  @override
  String get indepAdminUrgent => 'Administrativo urgente';

  @override
  String get indepPrevoyance => 'Previsión';

  @override
  String get indepOptiFiscale => 'Optimización fiscal';

  @override
  String get fhsLevelExcellent => 'Excelente';

  @override
  String get fhsLevelBon => 'Bueno';

  @override
  String get fhsLevelAmeliorer => 'A mejorar';

  @override
  String get fhsLevelCritique => 'Crítico';

  @override
  String fhsDeltaLabel(String delta) {
    return 'Tendencia: $delta vs ayer';
  }

  @override
  String fhsDeltaText(String delta) {
    return '$delta vs ayer';
  }

  @override
  String get fhsBreakdownLiquidite => 'Liquidez';

  @override
  String get fhsBreakdownFiscalite => 'Fiscalidad';

  @override
  String get fhsBreakdownRetraite => 'Jubilación';

  @override
  String get fhsBreakdownRisque => 'Riesgo';

  @override
  String avsGapLifetimeLoss(String amount) {
    return 'En 20 años de jubilación, eso son $amount menos — definitivamente.';
  }

  @override
  String get avsGapCalculation =>
      'Cálculo: pensión mensual × 13 meses/año (13.ª pensión AVS desde dic. 2026)';

  @override
  String get chiffreChocRenteCalculation =>
      '(cálculo: pensión mensual × 13 meses/año, 13.ª pensión incluida).';

  @override
  String get coachBriefingFallbackGreeting => 'Hola';

  @override
  String get coachBriefingBadgeLlm => 'Coach IA';

  @override
  String get coachBriefingBadge => 'Coach';

  @override
  String coachBriefingConfidenceLow(String score) {
    return 'Confianza $score % — Enriquecer';
  }

  @override
  String coachBriefingConfidence(String score) {
    return 'Confianza $score %';
  }

  @override
  String coachBriefingImpactEstimated(String amount) {
    return 'Impacto estimado : CHF $amount';
  }

  @override
  String get chiffreChocSectionDisclaimer =>
      'Simulación educativa. No constituye asesoramiento financiero (LSFin). Hipótesis modificables — resultados no asegurados.';

  @override
  String get concubinageTabProtection => 'Protección';

  @override
  String concubinageHeroChiffreChoc(String montant) {
    return 'CHF $montant de patrimonio expuesto';
  }

  @override
  String get concubinageHeroChiffreChocDesc =>
      'En concubinato, tu pareja no es heredero/a legal. Sin testamento, esta cantidad se pierde por completo.';

  @override
  String get concubinageEducationalAvs =>
      'En Suiza, el tope del 150 % en las pensiones AVS de pareja (LAVS art. 35) solo aplica a los casados. Los concubinos reciben cada uno su pensión individual completa — una ventaja real cuando ambos han cotizado al máximo.';

  @override
  String get concubinageEducationalLpp =>
      'La pensión LPP de superviviente (60 % de la pensión del fallecido, LPP art. 19) está reservada a los cónyuges. En concubinato, solo el reglamento de la caja puede prever un capital por fallecimiento — y hay que solicitarlo.';

  @override
  String get concubinageEducationalSuccession =>
      'Un cónyuge casado está exento del impuesto de sucesión en la mayoría de los cantones (CC art. 462). Un concubino paga impuesto a la tasa de terceros, a menudo entre el 20 % y el 40 %.';

  @override
  String get concubinageProtectionIntro =>
      'En concubinato, Suiza no protege como el matrimonio. Aquí está lo que cambia y lo que puedes anticipar.';

  @override
  String get concubinageProtectionAvsSurvivor => 'Pensión AVS de superviviente';

  @override
  String get concubinageProtectionAvsSurvivorMarried =>
      '80 % de la pensión del fallecido (LAVS art. 23)';

  @override
  String get concubinageProtectionAvsSurvivorConcubin =>
      'Ninguna pensión — CHF 0/mes';

  @override
  String get concubinageProtectionLppSurvivor => 'Pensión LPP de superviviente';

  @override
  String get concubinageProtectionLppSurvivorMarried =>
      '60 % de la pensión del fallecido (LPP art. 19)';

  @override
  String get concubinageProtectionLppSurvivorConcubin =>
      'Solo según reglamento de la caja';

  @override
  String get concubinageProtectionHeritage => 'Herencia legal';

  @override
  String get concubinageProtectionHeritageMarried => 'Exento (CC art. 462)';

  @override
  String get concubinageProtectionHeritageConcubin =>
      'Impuesto cantonal (20-40 %)';

  @override
  String get concubinageProtectionPension => 'Pensión alimenticia';

  @override
  String get concubinageProtectionPensionMarried => 'Protegida por el juez';

  @override
  String get concubinageProtectionPensionConcubin => 'Sin obligación legal';

  @override
  String get concubinageProtectionAvsPlafond => 'Tope AVS pareja';

  @override
  String get concubinageProtectionAvsPlafondMarried =>
      'Máx. 150 % (LAVS art. 35)';

  @override
  String get concubinageProtectionAvsPlafondConcubin => 'Sin tope — 2×100 %';

  @override
  String get concubinageProtectionMaried => 'Casado';

  @override
  String get concubinageProtectionConcubinLabel => 'Concubino';

  @override
  String get concubinageProtectionWarning =>
      'En concubinato, si tu pareja fallece, no recibes pensión AVS, ni pensión LPP automática, y no eres heredero/a legal. Cada protección debe anticiparse.';

  @override
  String get concubinageProtectionLppSlider =>
      'Pensión LPP mensual del/de la pareja';

  @override
  String concubinageProtectionSurvivorTotal(String montant) {
    return '$montant/mes para el cónyuge superviviente casado';
  }

  @override
  String get concubinageProtectionSurvivorZero =>
      'CHF 0/mes para el concubino superviviente sin trámites';

  @override
  String get concubinageDecisionMatrixTitle => 'Matrimonio vs Concubinato';

  @override
  String get concubinageDecisionMatrixSubtitle =>
      'Comparación de derechos y obligaciones';

  @override
  String get concubinageDecisionMatrixColumnMarriage => 'Matrimonio';

  @override
  String get concubinageDecisionMatrixColumnConcubinage => 'Concubinato';

  @override
  String get concubinageDecisionMatrixConclusionTitle => 'Conclusión neutral';

  @override
  String get concubinageDecisionMatrixConclusionDesc =>
      'La elección depende de tu situación personal. Consulta a un notario para un análisis completo.';

  @override
  String get mortgageJourneyTitle => 'Recorrido compra inmobiliaria';

  @override
  String get mortgageJourneySubtitle =>
      '7 pasos de «¿puedo comprarlo?» a «¡firmé!»';

  @override
  String get mortgageJourneyPrevious => 'Anterior';

  @override
  String get mortgageJourneyNextStep => 'Siguiente paso';

  @override
  String get mortgageJourneyComplete => '✅ ¡Recorrido completo!';

  @override
  String get clause3aTitle => 'La cláusula 3a olvidada';

  @override
  String get clause3aQuestion =>
      '¿Has presentado una cláusula de beneficiario?';

  @override
  String get clause3aStepsTitle => 'Cómo presentar una cláusula en 5 minutos:';

  @override
  String clause3aFeedbackOk(String partner) {
    return '¡Bien! Verifica que la cláusula nombre a $partner — y que esté al día tras cada evento vital.';
  }

  @override
  String get clause3aFeedbackNok =>
      'Acción prioritaria: presenta tu cláusula de beneficiario en tu fundación 3a — en 5 minutos.';

  @override
  String get fiscalSuperpowerTitle => 'El super-poder fiscal';

  @override
  String get fiscalSuperpowerSubtitle =>
      'El Estado te devuelve dinero por tener un hijo.';

  @override
  String get fiscalSuperpowerTaxBenefits => 'Tus ventajas fiscales';

  @override
  String get babyCostTitle => 'El costo de la felicidad';

  @override
  String get babyCostBreakdownTitle => 'Desglose mensual';

  @override
  String get lifeEventSheetTitle => 'Me está pasando algo';

  @override
  String get lifeEventSheetSubtitle =>
      'Elige un evento para ver el impacto financiero';

  @override
  String get lifeEventSheetSectionFamille => 'Familia';

  @override
  String get lifeEventSheetSectionPro => 'Profesional';

  @override
  String get lifeEventSheetSectionPatrimoine => 'Patrimonio';

  @override
  String get lifeEventSheetSectionMobilite => 'Movilidad';

  @override
  String get lifeEventSheetSectionSante => 'Salud';

  @override
  String get lifeEventSheetSectionCrise => 'Crisis';

  @override
  String get lifeEventLabelMariage => 'Me caso';

  @override
  String get lifeEventLabelDivorce => 'Me divorcio';

  @override
  String get lifeEventLabelNaissance => 'Espero un hijo';

  @override
  String get lifeEventLabelConcubinage => 'Vivimos juntos';

  @override
  String get lifeEventLabelDeces => 'Fallecimiento de un ser querido';

  @override
  String get lifeEventLabelPremierEmploi => 'Primer empleo';

  @override
  String get lifeEventLabelNouveauJob => 'Nuevo trabajo';

  @override
  String get lifeEventLabelIndependant => 'Me hago autónomo';

  @override
  String get lifeEventLabelPerteEmploi => 'Pérdida de empleo';

  @override
  String get lifeEventLabelRetraite => 'Me jubilo';

  @override
  String get lifeEventLabelAchatImmo => 'Compra inmobiliaria';

  @override
  String get lifeEventLabelVenteImmo => 'Venta inmobiliaria';

  @override
  String get lifeEventLabelHeritage => 'Recibo una herencia';

  @override
  String get lifeEventLabelDonation => 'Quiero donar a mis hijos';

  @override
  String get lifeEventLabelDemenagement => 'Cambio de cantón';

  @override
  String get lifeEventLabelExpatriation => 'Me voy al extranjero';

  @override
  String get lifeEventLabelInvalidite => '¿Estoy bien cubierto/a?';

  @override
  String get lifeEventLabelDettes => 'Tengo deudas';

  @override
  String get lifeEventPromptMariage =>
      'Me caso — ¿qué impacto en mis impuestos, AVS y previsión?';

  @override
  String get lifeEventPromptDivorce =>
      'Me divorcio — ¿qué pasa con el LPP y los impuestos?';

  @override
  String get lifeEventPromptNaissance =>
      'Espero un hijo — ¿qué ayudas y deducciones hay disponibles?';

  @override
  String get lifeEventPromptConcubinage =>
      'No estamos casados — ¿cómo protegernos mutuamente?';

  @override
  String get lifeEventPromptDeces =>
      'Fallecimiento de un ser querido — ¿qué trámites financieros debo hacer?';

  @override
  String get lifeEventPromptPremierEmploi =>
      'Es mi primer trabajo — ¿qué debo saber sobre mi previsión y cotizaciones?';

  @override
  String get lifeEventPromptNouveauJob =>
      'Cambio de trabajo — ¿cómo comparar ofertas y gestionar mi libre paso?';

  @override
  String get lifeEventPromptIndependant =>
      'Me hago autónomo — ¿qué opciones de previsión sin LPP?';

  @override
  String get lifeEventPromptPerteEmploi =>
      'He perdido mi trabajo — ¿qué prestaciones por desempleo y durante cuánto tiempo?';

  @override
  String get lifeEventPromptRetraite =>
      '¿Cuándo puedo jubilarme y cuánto cobraré?';

  @override
  String get lifeEventPromptAchatImmo =>
      '¿Puedo comprar un inmueble con mis ingresos y mi aporte?';

  @override
  String get lifeEventPromptVenteImmo =>
      'Vendo mi inmueble — ¿qué impuesto sobre la ganancia debo prever?';

  @override
  String get lifeEventPromptHeritage =>
      'Recibo una herencia — ¿cuáles son las consecuencias fiscales?';

  @override
  String get lifeEventPromptDonation =>
      'Quiero donar a mis hijos — ¿qué impacto fiscal y qué límites?';

  @override
  String get lifeEventPromptDemenagement =>
      'Cambio de cantón — ¿qué impacto fiscal debo anticipar?';

  @override
  String get lifeEventPromptExpatriation =>
      'Me voy al extranjero — ¿qué hago con mi AVS, LPP y pilar 3a?';

  @override
  String get lifeEventPromptInvalidite =>
      '¿Estoy bien cubierto/a en caso de invalidez o accidente?';

  @override
  String get lifeEventPromptDettes =>
      'Tengo deudas — ¿cómo gestionarlas sin tocar mi previsión?';

  @override
  String compoundDisclaimerInflation(String inflation) {
    return 'Supuestos pedagógicos (inflación $inflation %). Los rendimientos pasados no constituyen una garantía de resultados futuros.';
  }

  @override
  String get interactive3aDisclaimer =>
      'Supuestos pedagógicos. Los rendimientos pasados no constituyen una garantía de resultados futuros.';

  @override
  String get milestoneContinueBtn => 'Continuar';

  @override
  String get slmAutoPromptTitle => 'Coach IA en tu dispositivo';

  @override
  String get slmAutoPromptBody =>
      'MINT puede instalar un modelo de IA directamente en tu teléfono para consejos personalizados — 100 % privado, ningún dato sale de tu dispositivo.';

  @override
  String get slmAutoInstalledMsg =>
      '¡Coach IA instalado ! Tus consejos serán personalizados.';

  @override
  String get slmInstallBtn => 'Instalar coach IA';

  @override
  String get slmLaterBtn => 'Más tarde';

  @override
  String get rcDisclaimer =>
      'Herramienta educativa — no constituye asesoramiento financiero (LSFin art. 3).';

  @override
  String rcPillar3aTitle(String year) {
    return 'Aportación 3a $year';
  }

  @override
  String get rcPillar3aSubtitle => 'Ahorro fiscal estimado';

  @override
  String rcPillar3aExplanation(String plafond) {
    return 'Ahorro fiscal estimado si aportas el límite de $plafond CHF';
  }

  @override
  String get rcPillar3aCtaLabel => 'Simular mi 3a';

  @override
  String get rcLppBuybackTitle => 'Recompra LPP';

  @override
  String get rcLppBuybackSubtitle => 'Potencial de recompra disponible';

  @override
  String rcLppBuybackExplanation(String taxSaving, String rachatSimule) {
    return 'Recompra posible. Ahorro fiscal estimado de $taxSaving CHF sobre $rachatSimule CHF';
  }

  @override
  String get rcLppBuybackCtaLabel => 'Simular una recompra';

  @override
  String get rcReplacementRateTitle => 'Tasa de reemplazo';

  @override
  String rcReplacementRateSubtitle(String age) {
    return 'Proyección a los $age años';
  }

  @override
  String rcReplacementRateExplanation(
      String totalMonthly, String currentMonthly) {
    return 'Ingresos estimados en la jubilación: $totalMonthly CHF/mes vs $currentMonthly CHF/mes actualmente';
  }

  @override
  String get rcReplacementRateCtaLabel => 'Explorar mis escenarios';

  @override
  String get rcReplacementRateAlerte =>
      'Tasa inferior al umbral recomendado del 60 %. Explora las opciones.';

  @override
  String get rcAvsGapTitle => 'Laguna AVS';

  @override
  String rcAvsGapSubtitle(String lacunes) {
    return '$lacunes años de cotización faltantes';
  }

  @override
  String get rcAvsGapExplanation =>
      'Reducción estimada de tu pensión AVS anual debida a lagunas';

  @override
  String get rcAvsGapCtaLabel => 'Ver mi extracto AVS';

  @override
  String get rcCoupleAlertTitle => 'Brecha de visibilidad de pareja';

  @override
  String rcCoupleAlertSubtitle(String name, String score) {
    return '$name al $score %';
  }

  @override
  String rcCoupleAlertExplanation(String gap) {
    return 'Brecha de $gap puntos entre vuestros dos perfiles. Equilibrarlos mejora la proyección de pareja.';
  }

  @override
  String get rcCoupleAlertCtaLabel => 'Enriquecer el perfil de pareja';

  @override
  String get rcIndependantTitle => 'Previsión autónomo';

  @override
  String get rcIndependantSubtitle =>
      'Sin LPP, tu 3a es tu previsión principal';

  @override
  String rcIndependantExplanation(String max3a, String current3a) {
    return 'Límite 3a sin LPP: $max3a CHF/año. Capital 3a actual: $current3a CHF';
  }

  @override
  String get rcIndependantCtaLabel => 'Explorar mis opciones';

  @override
  String get rcTaxOptTitle => 'Optimización fiscal';

  @override
  String get rcTaxOptSubtitle => 'Deducciones estimadas disponibles';

  @override
  String rcTaxOptExplanation(String plafond3a) {
    return 'Ahorro fiscal estimado vía 3a ($plafond3a CHF) + recompra LPP';
  }

  @override
  String get rcTaxOptCtaLabel => 'Descubrir mis deducciones';

  @override
  String get rcPatrimoineTitle => 'Patrimonio';

  @override
  String get rcPatrimoineSubtitleLow => 'Colchón de seguridad insuficiente';

  @override
  String get rcPatrimoineSubtitleOk => 'Visión general';

  @override
  String rcPatrimoineExplanationLow(String epargne, String coussinMin) {
    return 'Ahorro líquido ($epargne CHF) inferior a 3 meses de gastos ($coussinMin CHF)';
  }

  @override
  String rcPatrimoineExplanationOk(String epargne, String investissements) {
    return 'Ahorro $epargne CHF + inversiones $investissements CHF';
  }

  @override
  String get rcPatrimoineCtaLabelLow => 'Analizar mi presupuesto';

  @override
  String get rcPatrimoineCtaLabelOk => 'Ver mi patrimonio';

  @override
  String rcPatrimoineAlerte(String coussinMin) {
    return 'Colchón de seguridad recomendado: $coussinMin CHF (3 meses de gastos)';
  }

  @override
  String get rcMortgageTitle => 'Hipoteca';

  @override
  String rcMortgageSubtitle(String ltv) {
    return 'Ratio LTV: $ltv %';
  }

  @override
  String rcMortgageExplanation(String propertyValue) {
    return 'Saldo hipotecario. Valor del inmueble: $propertyValue CHF';
  }

  @override
  String get rcMortgageCtaLabel => 'Simular capacidad';

  @override
  String get rcCtaDetail => 'Ver detalles →';

  @override
  String get rcLibrePassageTitle => 'Libre paso';

  @override
  String get rcLibrePassageSubtitle => '¿Qué hacer con tu haber de libre paso?';

  @override
  String get rcRenteVsCapitalTitle => 'Renta vs Capital';

  @override
  String get rcRenteVsCapitalSubtitle =>
      'Renta o capital: calcular ambas opciones';

  @override
  String get rcFiscalComparatorTitle => 'Comparador cantonal';

  @override
  String get rcFiscalComparatorSubtitle => '¿Cuánto ganarías mudándote?';

  @override
  String get rcStaggeredWithdrawalTitle => 'Retiro 3a escalonado';

  @override
  String get rcStaggeredWithdrawalSubtitle =>
      'Escalonar los retiros para reducir impuestos';

  @override
  String get rcRealReturn3aTitle => 'Rendimiento real 3a';

  @override
  String get rcRealReturn3aSubtitle =>
      'Rendimiento después de comisiones, inflación e impuestos';

  @override
  String get rcComparator3aTitle => 'Comparador 3a';

  @override
  String get rcComparator3aSubtitle => 'Compara los proveedores de 3a';

  @override
  String get rcRentVsBuyTitle => 'Alquilar o comprar';

  @override
  String get rcRentVsBuySubtitle => 'Compara ambos escenarios a largo plazo';

  @override
  String get rcAmortizationTitle => 'Amortización';

  @override
  String get rcAmortizationSubtitle => 'Directa vs indirecta — impacto fiscal';

  @override
  String get rcImputedRentalTitle => 'Valor de arrendamiento imputado';

  @override
  String get rcImputedRentalSubtitle =>
      'Comprender la tributación de la vivienda';

  @override
  String get rcSaronVsFixedTitle => 'SARON vs tipo fijo';

  @override
  String get rcSaronVsFixedSubtitle => 'Qué tipo de hipoteca elegir';

  @override
  String get rcEplTitle => 'Retiro EPL';

  @override
  String get rcEplSubtitle => 'Usar tu 2° pilar para inmuebles';

  @override
  String get rcHousingSaleTitle => 'Venta inmobiliaria';

  @override
  String get rcHousingSaleSubtitle =>
      'Impuesto sobre la ganancia + reinversión';

  @override
  String get rcMariageTitle => 'Impacto del matrimonio';

  @override
  String get rcMariageSubtitle => 'Impuestos, AVS, LPP, sucesión';

  @override
  String get rcDivorceTitle => 'Simulador de divorcio';

  @override
  String get rcDivorceSubtitle => 'División LPP, pensión, impuestos';

  @override
  String get rcNaissanceTitle => 'Impacto de un nacimiento';

  @override
  String get rcNaissanceSubtitle => 'Prestaciones, deducciones, presupuesto';

  @override
  String get rcConcubinageTitle => 'Protección de pareja de hecho';

  @override
  String get rcConcubinageSubtitle => 'Derechos, riesgos y soluciones';

  @override
  String get rcSuccessionTitle => 'Sucesión';

  @override
  String get rcSuccessionSubtitle => 'Simular la transmisión del patrimonio';

  @override
  String get rcDonationTitle => 'Donación';

  @override
  String get rcDonationSubtitle => 'Impacto fiscal de una donación';

  @override
  String get rcUnemploymentTitle => 'Pérdida de empleo';

  @override
  String get rcUnemploymentSubtitle => 'Prestaciones, duración, trámites';

  @override
  String get rcFirstJobTitle => 'Primer empleo';

  @override
  String get rcFirstJobSubtitle => 'Entender todo desde el principio';

  @override
  String get rcExpatriationTitle => 'Expatriación';

  @override
  String get rcExpatriationSubtitle => 'Impacto en AVS, LPP, 3a e impuestos';

  @override
  String get rcFrontalierTitle => 'Trabajador fronterizo';

  @override
  String get rcFrontalierSubtitle => 'Impuesto en origen y particularidades';

  @override
  String get rcJobComparisonTitle => 'Comparador de ofertas';

  @override
  String get rcJobComparisonSubtitle =>
      'Neto + previsión: ¿qué oferta vale realmente más?';

  @override
  String get rcDividendeVsSalaireTitle => 'Dividendo vs Salario';

  @override
  String get rcDividendeVsSalaireSubtitle =>
      'Optimizar la remuneración en SARL/SA';

  @override
  String get rcLamalFranchiseTitle => 'Franquicia LAMal';

  @override
  String get rcLamalFranchiseSubtitle => '¿Qué franquicia elegir?';

  @override
  String get rcCoverageCheckTitle => 'Verificación de cobertura';

  @override
  String get rcCoverageCheckSubtitle => 'Verificar tus coberturas';

  @override
  String get rcDisabilityTitle => 'Invalidez — laguna de ingresos';

  @override
  String get rcDisabilitySubtitle =>
      'Brecha entre ingresos actuales y rentas AI/LPP';

  @override
  String get rcGenderGapTitle => 'Brecha de género';

  @override
  String get rcGenderGapSubtitle =>
      'Impacto del trabajo a tiempo parcial en la jubilación';

  @override
  String get rcBudgetTitle => 'Presupuesto';

  @override
  String get rcBudgetSubtitle => '¿Cuánto te queda a fin de mes?';

  @override
  String get rcDebtRatioTitle => 'Ratio de endeudamiento';

  @override
  String get rcDebtRatioSubtitle =>
      '¿A partir de qué umbral las deudas se vuelven peligrosas?';

  @override
  String get rcCompoundInterestTitle => 'Interés compuesto';

  @override
  String get rcCompoundInterestSubtitle =>
      'Simular el crecimiento de tu ahorro';

  @override
  String get rcLeasingTitle => 'Simulador de leasing';

  @override
  String get rcLeasingSubtitle => 'Coste real de un leasing de coche';

  @override
  String get rcConsumerCreditTitle => 'Crédito al consumo';

  @override
  String get rcConsumerCreditSubtitle => 'Coste total de un crédito al consumo';

  @override
  String get rcAllocationAnnuelleTitle => 'Asignación anual';

  @override
  String get rcAllocationAnnuelleSubtitle =>
      'Dónde colocar tus ahorros este año';

  @override
  String get rcSuggestedPrompt50PlusRetirement =>
      '¿Cuándo es viable la jubilación?';

  @override
  String get rcSuggestedPromptRenteOuCapital =>
      'Renta o capital: ¿qué me da más libertad?';

  @override
  String get rcSuggestedPromptRachatLpp =>
      '¿Cuánto vale una recompra LPP en mi caso?';

  @override
  String get rcSuggestedPromptAllegerImpots =>
      '¿Dónde reducir mis impuestos este año?';

  @override
  String get rcSuggestedPromptVersement3a => '¿Cuánto aportar al 3a este año?';

  @override
  String get nudgeSalaryBody =>
      '¿Has pensado en tu aportación al pilar 3a este mes? Cada mes cuenta para tu previsión.';

  @override
  String get nudgeTaxDeadlineTitle => 'Declaración fiscal';

  @override
  String get nudgeTaxDeadlineBody =>
      'Verifica la fecha límite de declaración fiscal en tu cantón. ¿Has revisado tus deducciones del 3a y LPP?';

  @override
  String get nudge3aDeadlineTitle => 'Última oportunidad para tu 3a';

  @override
  String nudge3aDeadlineBody(String days, String limit, String year) {
    return 'Quedan $days día(s) para aportar hasta $limit CHF y reducir tus impuestos de $year.';
  }

  @override
  String get nudgeBirthdayBody =>
      'Un hito que podría marcar tu planificación de previsión. ¿Has simulado el impacto de este año?';

  @override
  String get nudgeProfileTitle => 'Tu perfil merece ser enriquecido';

  @override
  String get nudgeProfileBody =>
      'Cuanto más completo sea tu perfil, más relevantes son los análisis de MINT. Solo se necesitan pocos datos.';

  @override
  String get nudgeInactiveTitle => '¡Ha pasado un tiempo !';

  @override
  String get nudgeInactiveBody =>
      'Tu situación financiera evoluciona cada semana. Toma 2 minutos para revisar tu panel.';

  @override
  String get nudgeGoalProgressTitle => '¡Tu objetivo avanza !';

  @override
  String nudgeGoalProgressBody(String progress) {
    return 'Has alcanzado el $progress % de tu objetivo. ¡Sigue así !';
  }

  @override
  String get nudgeAnniversaryBody =>
      'Llevas un año usando MINT. Es el momento ideal para actualizar tu perfil y medir tus progresos.';

  @override
  String get nudgeLppBuybackTitle => 'Ventana de recompra LPP';

  @override
  String nudgeLppBuybackBody(String year) {
    return 'Se acerca el final de $year: es la última oportunidad para una recompra LPP deducible.';
  }

  @override
  String get nudgeNewYearTitle => '¡Nuevo año, nuevo comienzo !';

  @override
  String nudgeNewYearBody(String year) {
    return '$year: se abre un nuevo capítulo del pilar 3a. Buen momento para planificar tus aportaciones.';
  }

  @override
  String get rcSuggestedPromptCommencer3a => '¿Por qué empezar el 3a ahora?';

  @override
  String get rcSuggestedPrompt2ePilier =>
      '¿Qué hace concretamente el 2° pilar?';

  @override
  String get rcSuggestedPromptIndependant => 'Autónomo: ¿qué debo reconstruir?';

  @override
  String get rcSuggestedPromptCouple =>
      '¿En qué falla nuestra previsión de pareja?';

  @override
  String get rcSuggestedPromptFatca => 'FATCA: ¿qué cambia para mi 3a?';

  @override
  String get rcUnitPts => 'pts';

  @override
  String get routeSuggestionCta => 'Abrir';

  @override
  String get routeSuggestionPartialWarning => 'Estimación — datos incompletos';

  @override
  String get routeSuggestionBlocked => 'Me falta información para llevarte ahí';

  @override
  String get routeReturnAcknowledge =>
      '¡Has vuelto! Si has ajustado datos, cuéntame y recalculo.';

  @override
  String get routeReturnCompleted => 'Anotado. Tus datos están al día.';

  @override
  String get routeReturnAbandoned => 'Sin problema — volvemos cuando quieras.';

  @override
  String get routeReturnChanged =>
      'Tus cifras han cambiado. Recalculo la trayectoria.';

  @override
  String get hypothesisEditorTitle => 'Hipótesis de simulación';

  @override
  String get hypothesisEditorSubtitle =>
      'Ajusta los parámetros para ver el impacto en las proyecciones.';

  @override
  String get lifecyclePhaseDemarrage => 'Comienzo';

  @override
  String get lifecyclePhaseDemarrageDesc =>
      'Primeros pasos en la vida laboral: presupuesto, 3a y buenos hábitos.';

  @override
  String get lifecyclePhaseConstruction => 'Construcción';

  @override
  String get lifecyclePhaseConstructionDesc =>
      'Aceleración profesional, ahorro, primera vivienda, planificación familiar.';

  @override
  String get lifecyclePhaseAcceleration => 'Aceleración';

  @override
  String get lifecyclePhaseAccelerationDesc =>
      'Fase de ingresos altos: optimización LPP, fiscalidad y crecimiento patrimonial.';

  @override
  String get lifecyclePhaseConsolidation => 'Consolidación';

  @override
  String get lifecyclePhaseConsolidationDesc =>
      'Preparación de la jubilación, recompra LPP, inicio de planificación sucesoria.';

  @override
  String get lifecyclePhaseTransition => 'Transición';

  @override
  String get lifecyclePhaseTransitionDesc =>
      'Decisiones pre-jubilación: renta o capital, secuencia de retiros.';

  @override
  String get lifecyclePhaseRetraite => 'Jubilación';

  @override
  String get lifecyclePhaseRetraiteDesc =>
      'Vida en jubilación: adaptación del presupuesto y gestión del patrimonio.';

  @override
  String get lifecyclePhaseTransmission => 'Transmisión';

  @override
  String get lifecyclePhaseTransmissionDesc =>
      'Planificación sucesoria, donaciones y transmisión del patrimonio.';

  @override
  String get challengeWeeklyTitle => 'Reto de la semana';

  @override
  String get challengeCompleted => '¡Reto superado!';

  @override
  String challengeStreak(int count) {
    return '$count semanas consecutivas';
  }

  @override
  String get challengeBudget01Title =>
      'Revisa tus 3 mayores gastos de la semana';

  @override
  String get challengeBudget01Desc =>
      'Imagina saber exactamente adónde va cada franco: abre tu presupuesto e identifica las 3 partidas más altas de esta semana.';

  @override
  String get challengeBudget02Title => 'Calcula tu tasa de ahorro mensual real';

  @override
  String get challengeBudget02Desc =>
      'Tu tasa de ahorro es lo que queda tras todos los gastos. Comprueba si supera el 10 % de tus ingresos netos.';

  @override
  String get challengeBudget03Title =>
      'Compara el coste de tus seguros con una oferta alternativa';

  @override
  String get challengeBudget03Desc =>
      'Las primas de seguro pueden variar un 30 % según el proveedor. Comprueba si podrías ahorrar cambiando de caja.';

  @override
  String get challengeBudget04Title => 'Analiza tus gastos fijos vs. variables';

  @override
  String get challengeBudget04Desc =>
      'Separa los costes fijos (alquiler, seguros) de los variables (salidas, ocio). Es la base para optimizar tu presupuesto.';

  @override
  String get challengeBudget05Title => 'Comprueba tu ratio de endeudamiento';

  @override
  String get challengeBudget05Desc =>
      'Tu ratio de endeudamiento no debe superar el 33 % de los ingresos brutos. Calcúlalo para saber dónde estás.';

  @override
  String get challengeBudget06Title => 'Simula el coste real de tu leasing';

  @override
  String get challengeBudget06Desc =>
      'Un leasing es más que la cuota mensual: seguro, mantenimiento, valor residual. Calcula el coste total.';

  @override
  String get challengeBudget07Title =>
      'Evalúa tu colchón de seguridad en meses';

  @override
  String get challengeBudget07Desc =>
      'Combien de mois pourrais-tu tenir sans revenu? Lo ideal es 3 a 6 meses de gastos.';

  @override
  String get challengeBudget08Title =>
      'Comprueba si podrías reducir tu crédito al consumo';

  @override
  String get challengeBudget08Desc =>
      'Un crédito al consumo al 8-12 % es muy caro. Mira si puedes acelerar el reembolso o consolidarlo.';

  @override
  String get challengeEpargne01Title => 'Ahorra CHF 50 esta semana';

  @override
  String get challengeEpargne01Desc =>
      'Incluso una pequeña cantidad importa: CHF 50 por semana son CHF 2\'600 al año. Lo más difícil es empezar.';

  @override
  String get challengeEpargne02Title => 'Revisa tu saldo 3a vs. el techo';

  @override
  String get challengeEpargne02Desc =>
      'El techo del 3a para empleados es CHF 7\'258 al año. Comprueba cuánto has aportado ya este año.';

  @override
  String get challengeEpargne03Title => 'Simula una recompra LPP de CHF 5\'000';

  @override
  String get challengeEpargne03Desc =>
      'Una recompra LPP es deducible de impuestos. Simula el impacto de una recompra de CHF 5\'000 en tu previsión y fiscalidad.';

  @override
  String get challengeEpargne04Title =>
      'Comprueba si aún puedes aportar al 3a este año';

  @override
  String get challengeEpargne04Desc =>
      'Las aportaciones al 3a son anuales: si no has alcanzado el máximo, quizá quede tiempo.';

  @override
  String get challengeEpargne05Title =>
      'Compara los rendimientos de tus cuentas 3a';

  @override
  String get challengeEpargne05Desc =>
      'No todas las cuentas 3a son iguales. Compara los rendimientos de tus cuentas con el simulador.';

  @override
  String get challengeEpargne06Title =>
      'Calcula el rendimiento real de tu 3a tras la inflación';

  @override
  String get challengeEpargne06Desc =>
      'Un rendimiento del 1 % con una inflación del 1,5 % es un rendimiento real negativo. Comprueba tu situación.';

  @override
  String get challengeEpargne07Title =>
      'Simula un retiro escalonado de tus cuentas 3a';

  @override
  String get challengeEpargne07Desc =>
      'Retirar tu 3a en varios años puede reducir los impuestos. Simula la estrategia de retiro escalonado.';

  @override
  String get challengeEpargne08Title =>
      'Comprueba si puedes aportar al 3a de forma retroactiva';

  @override
  String get challengeEpargne08Desc =>
      'Desde 2025, puedes recuperar años sin aportaciones. Comprueba si eres elegible para el 3a retroactivo.';

  @override
  String get challengeEpargne09Title =>
      'Revisa tu libre paso si has cambiado de empleador';

  @override
  String get challengeEpargne09Desc =>
      'Al cambiar de empleo, tu capital LPP se transfiere a una cuenta de libre paso. Verifica que no se haya olvidado nada.';

  @override
  String get challengePrevoyance01Title => 'Solicita tu extracto de cuenta AVS';

  @override
  String get challengePrevoyance01Desc =>
      'Tu extracto AVS muestra tus años de cotización y tu pensión estimada. Solícitalo gratuitamente en avs.ch.';

  @override
  String get challengePrevoyance02Title => 'Revisa tu cobertura por invalidez';

  @override
  String get challengePrevoyance02Desc =>
      'En caso de invalidez, ¿tu pensión AI + LPP cubre tus gastos? Revisa el posible déficit.';

  @override
  String get challengePrevoyance03Title =>
      'Compara renta vs. capital para tu LPP';

  @override
  String get challengePrevoyance03Desc =>
      '¿Renta vitalicia o capital? Cada opción tiene ventajas fiscales y de flexibilidad. Compara los escenarios.';

  @override
  String get challengePrevoyance04Title =>
      'Consulta tu proyección de jubilación';

  @override
  String get challengePrevoyance04Desc =>
      'Imagina tu jubilación: AVS + LPP + 3a — ¿cuánto tendrás realmente? Comprueba si estás en la trayectoria correcta.';

  @override
  String get challengePrevoyance05Title =>
      'Optimiza tu secuencia de decumulación';

  @override
  String get challengePrevoyance05Desc =>
      'El orden en que retiras tus pilares tiene un impacto fiscal importante. Simula diferentes secuencias.';

  @override
  String get challengePrevoyance06Title => 'Revisa tus lagunas AVS';

  @override
  String get challengePrevoyance06Desc =>
      'Cada año sin cotizaciones AVS reduce tu pensión. Comprueba si tienes lagunas que cubrir.';

  @override
  String get challengePrevoyance07Title => 'Planifica tu sucesión';

  @override
  String get challengePrevoyance07Desc =>
      '¿Quién hereda qué en el derecho suizo? Revisa las porciones legítimas y si es necesario un testamento.';

  @override
  String get challengePrevoyance08Title =>
      'Revisa tu cobertura en caso de desempleo';

  @override
  String get challengePrevoyance08Desc =>
      'Perder el empleo es estresante. Saber cuánto cobrarías y durante cuánto tiempo puede tranquilizarte. Simula tu situación.';

  @override
  String get challengePrevoyance09Title =>
      'Revisa tu cobertura por invalidez como autónomo';

  @override
  String get challengePrevoyance09Desc =>
      'Como autónomo, tu cobertura AI puede ser insuficiente. Comprueba si sería útil un seguro de indemnización diaria complementario.';

  @override
  String get challengeFiscalite01Title => 'Estima tu ahorro fiscal del 3a';

  @override
  String get challengeFiscalite01Desc =>
      'Cada franco aportado al 3a es deducible. Calcula cuánto ahorras en impuestos este año.';

  @override
  String get challengeFiscalite02Title =>
      'Comprueba si una recompra LPP sería deducible este año';

  @override
  String get challengeFiscalite02Desc =>
      'Las recompras LPP son deducibles de la renta imponible. Comprueba tu potencial de recompra y el ahorro fiscal.';

  @override
  String get challengeFiscalite03Title =>
      'Simula el impuesto sobre un retiro de capital';

  @override
  String get challengeFiscalite03Desc =>
      'Los retiros de capital (LPP/3a) tributan por separado a un tipo reducido. Simula el impuesto para diferentes importes.';

  @override
  String get challengeFiscalite04Title =>
      'Compara salario vs. dividendo si eres autónomo';

  @override
  String get challengeFiscalite04Desc =>
      'La mezcla salario/dividendo depende de tus ingresos y cantón. Simula ambos escenarios.';

  @override
  String get challengeFiscalite05Title =>
      'Revisa el valor catastral de tu propiedad';

  @override
  String get challengeFiscalite05Desc =>
      'Si eres propietario, el valor catastral se añade a tu renta imponible. Comprueba si es correcto.';

  @override
  String get challengeFiscalite06Title => 'Calcula tu carga fiscal total';

  @override
  String get challengeFiscalite06Desc =>
      'Impuesto federal + cantonal + municipal: calcula tu carga fiscal total como porcentaje de tus ingresos.';

  @override
  String get challengeFiscalite07Title => 'Comprueba tu conformidad FATCA';

  @override
  String get challengeFiscalite07Desc =>
      'Como ciudadano estadounidense, tus cuentas suizas están sujetas a FATCA. Comprueba que tu situación esté en orden.';

  @override
  String get challengeFiscalite08Title => 'Revisa tu retención en la fuente';

  @override
  String get challengeFiscalite08Desc =>
      'Como trabajador fronterizo, tributas en la fuente. Comprueba que el tipo aplicado corresponde a tu situación.';

  @override
  String get challengePatrimoine01Title =>
      'Calcula tu capacidad de endeudamiento hipotecario';

  @override
  String get challengePatrimoine01Desc =>
      'Con la regla del 1/3, comprueba cuánto podrías pedir prestado para una compra inmobiliaria.';

  @override
  String get challengePatrimoine02Title =>
      'Simula SARON vs. tipo fijo para tu hipoteca';

  @override
  String get challengePatrimoine02Desc =>
      '¿SARON (variable) o tipo fijo? Simula ambos escenarios a 10 años para ver la diferencia.';

  @override
  String get challengePatrimoine03Title => 'Compara alquilar vs. comprar';

  @override
  String get challengePatrimoine03Desc =>
      'Comprar no siempre es mejor que alquilar. Compara ambas opciones a 20 años con el simulador.';

  @override
  String get challengePatrimoine04Title =>
      'Simula un adelanto LPP para vivienda';

  @override
  String get challengePatrimoine04Desc =>
      'Puedes usar tu 2.º pilar para financiar tu vivienda. Simula el impacto en tu jubilación.';

  @override
  String get challengePatrimoine05Title =>
      'Consulta tu balance patrimonial completo';

  @override
  String get challengePatrimoine05Desc =>
      'Activos, pasivos, patrimonio neto: haz un balance de tu situación financiera global. Un momento importante para ganar perspectiva.';

  @override
  String get challengePatrimoine06Title =>
      'Revisa tu asignación anual de ahorro';

  @override
  String get challengePatrimoine06Desc =>
      'Entre 3a, recompra LPP y amortización hipotecaria, ¿cómo distribuir tu ahorro este año? Cada elección tiene un impacto fiscal diferente.';

  @override
  String get challengePatrimoine07Title =>
      'Simula el impacto de la amortización hipotecaria';

  @override
  String get challengePatrimoine07Desc =>
      '¿Amortización directa o indirecta mediante 3a? Simula ambas opciones y su impacto fiscal.';

  @override
  String get challengePatrimoine08Title =>
      'Simula el efecto del interés compuesto a 20 años';

  @override
  String get challengePatrimoine08Desc =>
      'Incluso un pequeño rendimiento crea un efecto bola de nieve. Simula el crecimiento de tu ahorro a 20 años.';

  @override
  String get challengeEducation01Title =>
      'Lee el artículo sobre la 13.ª pensión AVS';

  @override
  String get challengeEducation01Desc =>
      'Desde 2026, la 13.ª pensión AVS aumenta tu pensión anual. Descubre lo que cambia concretamente para ti.';

  @override
  String get challengeEducation02Title =>
      'Entiende la diferencia entre el tipo de conversión mínimo y el supraobligatorio';

  @override
  String get challengeEducation02Desc =>
      'El tipo de conversión LPP del 6,8 % solo se aplica al mínimo. Tu caja puede tener un tipo diferente para la parte supraobligatoria.';

  @override
  String get challengeEducation03Title =>
      'Descubre cómo funciona el 1.er pilar';

  @override
  String get challengeEducation03Desc =>
      'El AVS es un sistema de reparto: los activos financian a los jubilados. Entiende las bases de tu futura pensión.';

  @override
  String get challengeEducation04Title => 'Entiende el sistema de 3 pilares';

  @override
  String get challengeEducation04Desc =>
      'AVS + LPP + 3a: cada pilar tiene su rol. Entiende cómo se complementan para tu jubilación.';

  @override
  String get challengeEducation05Title =>
      'Explora el concepto de tasa de sustitución';

  @override
  String get challengeEducation05Desc =>
      'La tasa de sustitución mide la relación entre tu pensión y tu último salario. El objetivo habitual es el 60-80 %.';

  @override
  String get challengeEducation06Title =>
      'Entiende las bonificaciones LPP por tramo de edad';

  @override
  String get challengeEducation06Desc =>
      'Las bonificaciones LPP aumentan con la edad: 7 %, 10 %, 15 %, 18 %. Comprueba en qué tramo estás.';

  @override
  String get challengeEducation07Title =>
      'Descubre las consecuencias financieras de la convivencia';

  @override
  String get challengeEducation07Desc =>
      'En concubinato no tienes los mismos derechos sucesorios que un matrimonio. Revisa las protecciones necesarias.';

  @override
  String get challengeEducation08Title =>
      'Entiende el impacto de la brecha de género en la jubilación';

  @override
  String get challengeEducation08Desc =>
      'Las mujeres reciben de media un 37 % menos de pensión. Entiende las causas y las posibles soluciones.';

  @override
  String get challengeArchetypeEu01Title =>
      'Comprueba tus años de cotización en la UE para el AVS';

  @override
  String get challengeArchetypeEu01Desc =>
      'Gracias a los acuerdos bilaterales, tus años cotizados en la UE cuentan para tu pensión AVS suiza. Solicita un certificado E205 para verificar la totalización.';

  @override
  String get challengeArchetypeNonEu01Title =>
      'Comprueba si un convenio de seguridad social cubre tu país';

  @override
  String get challengeArchetypeNonEu01Desc =>
      'Sin acuerdo bilateral, tus cotizaciones extranjeras no cuentan para el AVS. Comprueba si tu país de origen tiene un acuerdo con Suiza.';

  @override
  String get challengeArchetypeReturning01Title =>
      'Comprueba tu potencial de recompra LPP tras regresar a Suiza';

  @override
  String get challengeArchetypeReturning01Desc =>
      '¿De vuelta en Suiza tras una estancia en el extranjero? Podrías tener un potencial de recompra LPP importante, deducible fiscalmente. Simula el importe.';

  @override
  String get voiceMicLabel => 'Hablar al micrófono';

  @override
  String get voiceMicListening => 'Escuchando…';

  @override
  String get voiceMicProcessing => 'Procesando…';

  @override
  String get voiceSpeakerLabel => 'Escuchar la respuesta';

  @override
  String get voiceSpeakerStop => 'Detener la lectura';

  @override
  String get voiceUnavailable =>
      'Funciones de voz no disponibles en este dispositivo';

  @override
  String get voicePermissionNeeded =>
      'Permite el acceso al micrófono para usar la voz';

  @override
  String get voiceNoSpeech => 'No he escuchado nada. Inténtalo de nuevo.';

  @override
  String get voiceError => 'Error de voz. Usa el teclado.';

  @override
  String get benchmarkTitle => 'Perfiles similares en tu cantón';

  @override
  String get benchmarkSubtitle => 'Datos agregados y anonimizados (OFS)';

  @override
  String get benchmarkOptInBody =>
      'Compara tu situación con las medianas de tu cantón. Datos anonimizados, nunca un ranking.';

  @override
  String get benchmarkOptInButton => 'Activar';

  @override
  String get benchmarkOptOutButton => 'Desactivar';

  @override
  String get benchmarkDisclaimer =>
      'Datos agregados OFS — herramienta educativa, no un ranking. No constituye asesoramiento (LSFin art. 3).';

  @override
  String benchmarkInsightIncome(String canton, String amount) {
    return 'El ingreso mediano en el cantón de $canton es CHF $amount/año';
  }

  @override
  String benchmarkInsightSavings(String rate) {
    return 'Un perfil similar ahorra alrededor del $rate% de sus ingresos';
  }

  @override
  String benchmarkInsightTax(String canton, String level) {
    return 'La carga fiscal en $canton es $level en comparación con la media suiza';
  }

  @override
  String benchmarkInsightHousing(String amount) {
    return 'El alquiler mediano para un piso de 4 habitaciones es CHF $amount/mes';
  }

  @override
  String benchmarkInsight3a(String rate) {
    return 'Alrededor del $rate% de los activos contribuyen al 3er pilar';
  }

  @override
  String benchmarkInsightLpp(String rate) {
    return 'La tasa de cobertura LPP es del $rate%';
  }

  @override
  String get benchmarkTaxLevelBelow => 'inferior';

  @override
  String get benchmarkTaxLevelAverage => 'comparable';

  @override
  String get benchmarkTaxLevelAbove => 'superior';

  @override
  String get benchmarkNoDataCanton => 'Datos no disponibles para este cantón';

  @override
  String get llmFailoverActive => 'Conmutación automática activada';

  @override
  String get llmProviderClaude => 'Claude (Anthropic)';

  @override
  String get llmProviderOpenai => 'GPT-4o (OpenAI)';

  @override
  String get llmProviderMistral => 'Mistral';

  @override
  String get llmProviderLocal => 'Modelo local';

  @override
  String get llmCircuitOpen => 'Servicio temporalmente no disponible';

  @override
  String get llmAllProvidersDown =>
      'Todos los servicios de IA no están disponibles. Modo sin conexión activado.';

  @override
  String get llmQualityGood => 'Calidad de respuesta: buena';

  @override
  String get llmQualityDegraded => 'Calidad de respuesta: degradada';

  @override
  String get gamificationCommunityTitle => 'Desafío del mes';

  @override
  String get gamificationSeasonalTitle => 'Eventos estacionales';

  @override
  String get gamificationMilestonesTitle => 'Tus logros';

  @override
  String get gamificationOptInPrompt =>
      'Participar en los desafíos comunitarios';

  @override
  String get communityChallenge01Title => 'Prepara tu declaración de impuestos';

  @override
  String get communityChallenge01Desc =>
      'Enero es el momento adecuado para recopilar tus documentos fiscales. Contacta tu cantón para conocer el plazo y los documentos necesarios.';

  @override
  String get communityChallenge02Title => 'Identifica tus deducciones fiscales';

  @override
  String get communityChallenge02Desc =>
      'Gastos profesionales, intereses hipotecarios, donaciones : enumera todas las deducciones a las que tienes derecho antes de presentar tu declaración.';

  @override
  String get communityChallenge03Title =>
      'Verifica tu aportación al 3er pilar antes del plazo';

  @override
  String get communityChallenge03Desc =>
      'Algunos cantones permiten completar la aportación del año anterior al pilar 3a hasta marzo. Comprueba las normas de tu cantón.';

  @override
  String get communityChallenge04Title =>
      'Revisa tu certificado de previsión LPP';

  @override
  String get communityChallenge04Desc =>
      'Ha llegado tu certificado anual LPP. Dedica 10 minutos a entender tu capital, la tasa de conversión y el potencial de recompra.';

  @override
  String get communityChallenge05Title => 'Simula una recompra LPP';

  @override
  String get communityChallenge05Desc =>
      'Una recompra LPP mejora tu jubilación Y reduce tus impuestos. Calcula cuánto podrías recomprar y el impacto fiscal en tu cantón.';

  @override
  String get communityChallenge06Title => 'Haz tu revisión semestral';

  @override
  String get communityChallenge06Desc =>
      'Han pasado 6 meses : revisa tus objetivos financieros, comprueba si vas por buen camino y ajusta si es necesario.';

  @override
  String get communityChallenge07Title =>
      'Define tu objetivo de ahorro estival';

  @override
  String get communityChallenge07Desc =>
      'El verano puede afectar tu presupuesto. Define un objetivo de ahorro para julio y sigue tu progreso hasta fin de agosto.';

  @override
  String get communityChallenge08Title =>
      'Crea o refuerza tu fondo de emergencia';

  @override
  String get communityChallenge08Desc =>
      'Un fondo de emergencia de 3 a 6 meses de gastos fijos te protege de los imprevistos. Comprueba dónde estás y planifica las aportaciones pendientes.';

  @override
  String get communityChallenge09Title =>
      'Programa tu aportación al 3er pilar de otoño';

  @override
  String get communityChallenge09Desc =>
      'Septiembre es ideal para programar tu próxima aportación al pilar 3a. Distribuir las aportaciones a lo largo del año reduce el estrés del plazo de diciembre.';

  @override
  String get communityChallenge10Title => 'Celebra el mes de la previsión';

  @override
  String get communityChallenge10Desc =>
      'Octubre es el mes oficial de la previsión en Suiza. Consulta tu proyección de jubilación e identifica una acción concreta para mejorar tu situación.';

  @override
  String get communityChallenge11Title =>
      'Planifica tus últimas optimizaciones de fin de año';

  @override
  String get communityChallenge11Desc =>
      'Quedan pocas semanas para actuar: aportación 3a, donación benéfica, declaración de gastos. Identifica qué puedes hacer todavía antes del 31 de diciembre.';

  @override
  String get communityChallenge12Title =>
      'Realiza tu aportación al 3er pilar antes del 31 de diciembre';

  @override
  String get communityChallenge12Desc =>
      'Se acerca el plazo del 3a. Aporta hasta CHF 7’258 (asalariado con LPP) antes del 31 de diciembre para beneficiarte de la deducción fiscal de este año.';

  @override
  String get seasonalTaxSeasonTitle => 'Temporada fiscal';

  @override
  String get seasonalTaxSeasonDesc =>
      'Febrero–marzo: es el momento de preparar tu declaración de impuestos. Recopila tus justificantes e identifica tus deducciones.';

  @override
  String get seasonal3aCountdownTitle => 'Cuenta atrás 3er pilar';

  @override
  String get seasonal3aCountdownDesc =>
      'Se acerca el plazo del 31 de diciembre para las aportaciones al pilar 3a. Comprueba tu saldo y planifica tu aportación para maximizar la deducción fiscal.';

  @override
  String get seasonalNewYearResolutionsTitle => 'Resoluciones financieras';

  @override
  String get seasonalNewYearResolutionsDesc =>
      'Nuevo año, nuevos objetivos financieros. Define 1 o 2 acciones concretas que vas a poner en marcha este año.';

  @override
  String get seasonalMidYearReviewTitle => 'Revisión semestral';

  @override
  String get seasonalMidYearReviewDesc =>
      'Se ha alcanzado el hito de los 6 meses. Tómate un momento para comprobar tu progreso hacia tus objetivos y ajustar si es necesario.';

  @override
  String get seasonalRetirementMonthTitle => 'Mes de la previsión';

  @override
  String get seasonalRetirementMonthDesc =>
      'Octubre es el mes nacional de la previsión en Suiza. Es el momento de comprobar tu proyección de jubilación y tu tasa de sustitución.';

  @override
  String get milestoneEngagementFirstWeekTitle => 'Primera semana';

  @override
  String get milestoneEngagementFirstWeekDesc =>
      'Llevas 7 días usando MINT. Construir hábitos empieza aquí.';

  @override
  String get milestoneEngagementOneMonthTitle => 'Un mes fiel';

  @override
  String get milestoneEngagementOneMonthDesc =>
      '30 días con MINT. Tu curiosidad financiera está presente.';

  @override
  String get milestoneEngagementCitoyenTitle => 'Ciudadano MINT';

  @override
  String get milestoneEngagementCitoyenDesc =>
      '90 días: eres de las personas que toman su futuro financiero en sus manos.';

  @override
  String get milestoneEngagementFideleTitle => 'Fiel 6 meses';

  @override
  String get milestoneEngagementFideleDesc =>
      '180 días de seguimiento financiero. Tu regularidad construye una visión clara de tu situación.';

  @override
  String get milestoneEngagementVeteranTitle => 'Veterano MINT';

  @override
  String get milestoneEngagementVeteranDesc =>
      '365 días con MINT. Un año completo de conciencia financiera.';

  @override
  String get milestoneKnowledgeCurieuxTitle => 'Curioso';

  @override
  String get milestoneKnowledgeCurieuxDesc =>
      'Has explorado 5 conceptos financieros. El conocimiento es el punto de partida de toda decisión informada.';

  @override
  String get milestoneKnowledgeEclaireTitle => 'Informado';

  @override
  String get milestoneKnowledgeEclaireDesc =>
      '20 conceptos leídos. Estás construyendo una sólida comprensión del sistema financiero suizo.';

  @override
  String get milestoneKnowledgeExpertTitle => 'Experto';

  @override
  String get milestoneKnowledgeExpertDesc =>
      '50 conceptos explorados. Dominas los fundamentos de la previsión suiza.';

  @override
  String get milestoneKnowledgeStrategisteTitle => 'Estratega';

  @override
  String get milestoneKnowledgeStrategisteDesc =>
      '100 conceptos. Tienes una visión estratégica a largo plazo de tus finanzas.';

  @override
  String get milestoneKnowledgeMaitreTitle => 'Maestro';

  @override
  String get milestoneKnowledgeMaitreDesc =>
      '200 conceptos leídos. Tu cultura financiera es un activo real para tus decisiones de vida.';

  @override
  String get milestoneActionPremierPasTitle => 'Primer paso';

  @override
  String get milestoneActionPremierPasDesc =>
      'Has realizado tu primera acción financiera concreta. Todo gran cambio empieza por un primer paso.';

  @override
  String get milestoneActionActeurTitle => 'Actor';

  @override
  String get milestoneActionActeurDesc =>
      '5 acciones financieras completadas. Pasas del pensamiento a la acción.';

  @override
  String get milestoneActionMaitreDestinTitle => 'Dueño de tu destino';

  @override
  String get milestoneActionMaitreDestinDesc =>
      '20 acciones concretas. Gestionas activamente tu situación financiera.';

  @override
  String get milestoneActionBatisseurTitle => 'Constructor';

  @override
  String get milestoneActionBatisseurDesc =>
      '50 acciones financieras. Construyes pacientemente una base sólida.';

  @override
  String get milestoneActionArchitecteTitle => 'Arquitecto';

  @override
  String get milestoneActionArchitecteDesc =>
      '100 acciones. Eres el arquitecto de tu libertad financiera.';

  @override
  String get milestoneConsistencyFlammeNaissanteTitle => 'Llama naciente';

  @override
  String get milestoneConsistencyFlammeNaissanteDesc =>
      '2 semanas consecutivas. Tu regularidad toma forma.';

  @override
  String get milestoneConsistencyFlammeViveTitle => 'Llama viva';

  @override
  String get milestoneConsistencyFlammeViveDesc =>
      '4 semanas sin interrupción. Tu disciplina financiera está en marcha.';

  @override
  String get milestoneConsistencyFlammeEtermelleTitle => 'Llama eterna';

  @override
  String get milestoneConsistencyFlammeEtermelleDesc =>
      '12 semanas consecutivas. Tu constancia se ha convertido en hábito.';

  @override
  String get milestoneConsistencyConfianceTitle => 'Perfil de confianza';

  @override
  String get milestoneConsistencyConfianceDesc =>
      'Tu perfil ha alcanzado un nivel de confianza del 70 %. Tus datos permiten cálculos fiables.';

  @override
  String get milestoneConsistencyChallengesTitle => '6 desafíos completados';

  @override
  String get milestoneConsistencyChallengesDesc =>
      'Has completado 6 desafíos mensuales. Seis meses de compromiso financiero concreto.';

  @override
  String get rcSalaryLabel => 'Tu ingreso';

  @override
  String get rcAgeLabel => 'Tu edad';

  @override
  String get rcCantonLabel => 'Tu cantón';

  @override
  String get rcCivilStatusLabel => 'Tu estado civil';

  @override
  String get rcEmploymentStatusLabel => 'Tu situación laboral';

  @override
  String get rcLppLabel => 'Tus datos LPP';

  @override
  String get expertTitle => 'Consultar un·a especialista';

  @override
  String get expertSubtitle => 'MINT prepara tu dosier para una cita eficiente';

  @override
  String get expertDisclaimer =>
      'MINT facilita la conexión — no reemplaza el asesoramiento personalizado (LSFin art. 3)';

  @override
  String get expertSpecRetirement => 'Jubilación';

  @override
  String get expertSpecSuccession => 'Sucesión';

  @override
  String get expertSpecExpatriation => 'Expatriación';

  @override
  String get expertSpecDivorce => 'Divorcio';

  @override
  String get expertSpecSelfEmployment => 'Autónomo·a';

  @override
  String get expertSpecRealEstate => 'Inmobiliario';

  @override
  String get expertSpecTax => 'Fiscalidad';

  @override
  String get expertSpecDebt => 'Gestión de deudas';

  @override
  String get expertDossierTitle => 'Tu dosier preparado';

  @override
  String expertDossierIncomplete(int count) {
    return 'Perfil incompleto — $count datos faltantes';
  }

  @override
  String get expertRequestSession => 'Solicitar una cita';

  @override
  String get expertSessionRequested => 'Solicitud enviada';

  @override
  String get expertMissingData =>
      'Valor estimado — a confirmar con el·la especialista';

  @override
  String get expertDossierSectionSituation => 'Situación personal';

  @override
  String get expertDossierSectionPrevoyance => 'Previsión';

  @override
  String get expertDossierSectionPatrimoine => 'Patrimonio';

  @override
  String get expertDossierSectionFinancement => 'Financiación';

  @override
  String get expertDossierSectionDeductions => 'Deducciones fiscales';

  @override
  String get expertDossierSectionBudget => 'Presupuesto y deudas';

  @override
  String get expertItemAge => 'Edad';

  @override
  String get expertItemSalaryRange => 'Ingresos brutos anuales';

  @override
  String get expertItemCoupleStatus => 'Situación familiar';

  @override
  String get expertItemConjointAge => 'Edad del·de la cónyuge';

  @override
  String get expertItemLppBalance => 'Saldo LPP';

  @override
  String get expertItem3aStatus => 'Pilar 3a';

  @override
  String get expertItem3aBalance => 'Capital 3a';

  @override
  String get expertItemLppBuybackPotential => 'Recompra LPP posible';

  @override
  String get expertItemAvsYears => 'Años de cotización AVS';

  @override
  String get expertItemReplacementRate => 'Tasa de sustitución estimada';

  @override
  String get expertItemFamilyStatus => 'Estado civil';

  @override
  String get expertItemChildren => 'Hijos';

  @override
  String get expertItemPatrimoineRange => 'Patrimonio estimado';

  @override
  String get expertItemPropertyStatus => 'Vivienda';

  @override
  String get expertItemPropertyValue => 'Valor del inmueble';

  @override
  String get expertItemNationality => 'Nacionalidad';

  @override
  String get expertItemArchetype => 'Perfil fiscal';

  @override
  String get expertItemYearsInCh => 'Años en Suiza';

  @override
  String get expertItemResidencePermit => 'Permiso de residencia';

  @override
  String get expertItemAvsStatus => 'Estado AVS';

  @override
  String get expertItemAvsGaps => 'Lagunas AVS';

  @override
  String get expertItemCivilStatus => 'Estado civil';

  @override
  String get expertItemConjointLpp => 'LPP del·de la cónyuge';

  @override
  String get expertItemEmploymentStatus => 'Situación laboral';

  @override
  String get expertItemLppCoverage => 'Cobertura LPP';

  @override
  String get expertItemCanton => 'Cantón';

  @override
  String get expertItemCurrentHousing => 'Vivienda actual';

  @override
  String get expertItemEquityEstimate => 'Fondos propios disponibles';

  @override
  String get expertItemLppEpl => 'EPL posible';

  @override
  String get expertItemMortgageBalance => 'Hipoteca vigente';

  @override
  String get expertItemDebtRatio => 'Ratio de endeudamiento';

  @override
  String get expertItemChargesVsIncome => 'Cargas vs ingresos';

  @override
  String get expertItemDebtType => 'Tipos de deudas';

  @override
  String get expertValueUnknown => 'No indicado';

  @override
  String get expertValueNone => 'Ninguno·a';

  @override
  String get expertValueOwner => 'Propietario·a';

  @override
  String get expertValueTenant => 'Inquilino·a';

  @override
  String get expertValueSingle => 'Soltero·a';

  @override
  String get expertValueMarried => 'Casado·a';

  @override
  String get expertValueDivorced => 'Divorciado·a';

  @override
  String get expertValueWidowed => 'Viudo·a';

  @override
  String get expertValueConcubinage => 'Conviviente';

  @override
  String get expertValue3aActive => 'Activo';

  @override
  String get expertValue3aInactive => 'Inactivo';

  @override
  String get expertValueLppYes => 'Cubierto·a';

  @override
  String get expertValueLppNo => 'No cubierto·a';

  @override
  String get expertValueLppEplPossible => 'Posible (a verificar)';

  @override
  String get expertValueDebtNone => 'Sin deudas';

  @override
  String get expertValueDebtLow => 'Bajo (< 50 % de los ingresos anuales)';

  @override
  String get expertValueDebtMedium =>
      'Moderado (50–100 % de los ingresos anuales)';

  @override
  String get expertValueDebtHigh => 'Alto (> 100 % de los ingresos anuales)';

  @override
  String get expertValueChargesNone => 'Sin cargas de deuda';

  @override
  String get expertValueSalarie => 'Asalariado·a';

  @override
  String get expertValueIndependant => 'Autónomo·a';

  @override
  String get expertValueChomage => 'Desempleado·a';

  @override
  String get expertValueRetraite => 'Jubilado·a';

  @override
  String get expertDebtTypeConso => 'Crédito consumo';

  @override
  String get expertDebtTypeLeasing => 'Leasing';

  @override
  String get expertDebtTypeHypo => 'Hipoteca';

  @override
  String get expertDebtTypeAutre => 'Otras deudas';

  @override
  String get expertArchetypeSwissNative => 'Residente suizo·a';

  @override
  String get expertArchetypeExpatEu => 'Expat UE/AELC';

  @override
  String get expertArchetypeExpatNonEu => 'Expat no-UE';

  @override
  String get expertArchetypeExpatUs => 'Residente US (FATCA)';

  @override
  String get expertArchetypeIndepWithLpp => 'Autónomo·a con LPP';

  @override
  String get expertArchetypeIndepNoLpp => 'Autónomo·a sin LPP';

  @override
  String get expertArchetypeCrossBorder => 'Trabajador·a fronterizo·a';

  @override
  String get expertArchetypeReturningSwiss => 'Suizo·a de retorno';

  @override
  String get expertMissingLppBalance => 'Saldo LPP no indicado';

  @override
  String get expertMissingAvsYears => 'Años de cotización AVS no indicados';

  @override
  String get expertMissingLppBuyback => 'Laguna de recompra LPP desconocida';

  @override
  String get expertMissing3a => 'Capital 3a no indicado';

  @override
  String get expertMissingConjoint => 'Datos del·de la cónyuge faltantes';

  @override
  String get expertMissingPatrimoine => 'Patrimonio no indicado';

  @override
  String get expertMissingHousing => 'Situación de vivienda desconocida';

  @override
  String get expertMissingChildren => 'Número de hijos no indicado';

  @override
  String get expertMissingNationality => 'Nacionalidad no indicada';

  @override
  String get expertMissingArrivalAge => 'Edad de llegada a Suiza no indicada';

  @override
  String get expertMissingPermit => 'Permiso de residencia no indicado';

  @override
  String get expertMissingConjointLpp => 'LPP del·de la cónyuge no indicada';

  @override
  String get expertMissingIndependantStatus => 'Estado autónomo no confirmado';

  @override
  String get expertMissingLppCoverage => 'Cobertura LPP no indicada';

  @override
  String get expertMissingCanton => 'Cantón no indicado';

  @override
  String get expertMissingEquity => 'Fondos propios no indicados';

  @override
  String get expertMissingHousingStatus => 'Estado de vivienda no indicado';

  @override
  String get expertMissingDebtDetail => 'Detalle de deudas faltante';

  @override
  String get expertMissingMensualites =>
      'Pagos mensuales de deudas no indicados';

  @override
  String get agentFormTitle => 'Formulario pre-rellenado';

  @override
  String get agentFormDisclaimer =>
      'Verifica cada campo antes de enviar. MINT no envía nada en tu nombre.';

  @override
  String get agentFormValidateAll => 'Confirmo que he revisado';

  @override
  String get agentFormEstimated => 'Estimado — por confirmar';

  @override
  String get agentLetterTitle => 'Carta preparada';

  @override
  String get agentLetterDisclaimer =>
      'Adapta y envía tú mismo. MINT no transmite nada.';

  @override
  String get agentLetterPensionSubject => 'Solicitud de extracto de previsión';

  @override
  String get agentLetterTransferSubject =>
      'Solicitud de transferencia de libre paso';

  @override
  String get agentLetterAvsSubject => 'Solicitud de extracto de cuenta AVS';

  @override
  String get agentLetterPlaceholderName => '[Tu nombre completo]';

  @override
  String get agentLetterPlaceholderAddress => '[Tu dirección]';

  @override
  String get agentLetterPlaceholderSsn => '[Tu número AVS]';

  @override
  String get agentLetterPlaceholderDate => '[Fecha]';

  @override
  String get agentTaxFormTitle => 'Declaración de impuestos — pre-relleno';

  @override
  String get agent3aFormTitle => 'Certificado 3er pilar';

  @override
  String get agentLppFormTitle => 'Formulario de rescate LPP';

  @override
  String agentFieldSource(String source) {
    return 'Fuente : $source';
  }

  @override
  String get agentValidationRequired =>
      'Validación requerida antes de cualquier uso';

  @override
  String get agentOutputDisclaimer =>
      'Herramienta educativa — no constituye consejo financiero, fiscal o jurídico. Verifica cada información. Conforme a LSFin.';

  @override
  String get agentNoAction =>
      'MINT no envía, transmite ni ejecuta nada automáticamente.';

  @override
  String get agentSpecialistLabel => 'un especialista homologado';

  @override
  String get agentLppBuybackTitle => 'Solicitud de rescate LPP';

  @override
  String get agentPensionFundSubject => 'Solicitud de certificado de previsión';

  @override
  String get agentLppTransferSubject =>
      'Solicitud de transferencia de previsión (libre paso)';

  @override
  String get agentFormCantonFallback => '[cantón]';

  @override
  String get agentFormRevenuBrut => 'Renta bruta estimada';

  @override
  String get agentFormCanton => 'Cantón de residencia';

  @override
  String get agentFormSituationFamiliale => 'Situación familiar';

  @override
  String get agentFormNbEnfants => 'Número de hijos';

  @override
  String get agentFormDeduction3a => 'Deducción 3a posible';

  @override
  String get agentFormRachatLppDeductible => 'Rescate LPP deducible estimado';

  @override
  String get agentFormStatutProfessionnel => 'Situación profesional';

  @override
  String get agentFormBeneficiaireNom => 'Nombre del/de la beneficiario·a';

  @override
  String get agentFormNumeroCompte3a => 'Número de cuenta 3a';

  @override
  String agentFormMontantVersement(String plafond, String year) {
    return '~$plafond CHF (límite $year)';
  }

  @override
  String get agentFormMontantVersementLabel => 'Importe del pago anual';

  @override
  String get agentFormTypeContrat => 'Tipo de contrato';

  @override
  String get agentFormTypeContratSalarie => 'Empleado·a con LPP';

  @override
  String get agentFormTypeContratIndependant => 'Autónomo·a sin LPP';

  @override
  String get agentFormToComplete => '[Por completar]';

  @override
  String get agentFormTitulaireNom => 'Nombre del/de la titular';

  @override
  String get agentFormNumeroPolice => 'Número de póliza';

  @override
  String get agentFormAvoirLpp => 'Haber LPP actual';

  @override
  String get agentFormRachatMax => 'Rescate máximo disponible';

  @override
  String get agentFormRachatsDeja => 'Rescates ya realizados';

  @override
  String get agentFormMontantRachatSouhaite => 'Importe del rescate deseado';

  @override
  String get agentFormToCompleteAupres => '[Por completar con la caja]';

  @override
  String agentFormToCompleteMax(String max) {
    return '[A introducir — máx. $max CHF]';
  }

  @override
  String get agentFormCivilCelibataire => 'Soltero·a';

  @override
  String get agentFormCivilMarie => 'Casado·a';

  @override
  String get agentFormCivilDivorce => 'Divorciado·a';

  @override
  String get agentFormCivilVeuf => 'Viudo·a';

  @override
  String get agentFormCivilConcubinage => 'Pareja de hecho';

  @override
  String get agentFormEmplSalarie => 'Empleado·a';

  @override
  String get agentFormEmplIndependant => 'Autónomo·a';

  @override
  String get agentFormEmplChomage => 'En búsqueda de empleo';

  @override
  String get agentFormEmplRetraite => 'Jubilado·a';

  @override
  String get agentLetterCaisseFallback => '[Nombre de la caja de pensiones]';

  @override
  String get agentLetterPostalCity => '[Código postal y ciudad]';

  @override
  String get agentLetterCaisseAddress => '[Dirección de la caja]';

  @override
  String get agentLetterPoliceNumber => '[Número de póliza : Por completar]';

  @override
  String get agentLetterCaisseCurrentName => '[Caja de pensiones actual]';

  @override
  String get agentLetterCaisseCurrentAddress => '[Dirección de la caja actual]';

  @override
  String get agentLetterToComplete => '[Por completar]';

  @override
  String get agentLetterAvsOrg => 'Caja de compensación AVS competente';

  @override
  String get agentLetterAvsAddress => '[Dirección]';

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
    return '$name\n$address\n$postalCity\n\n$caisse\n$caisseAddress\n$postalCity\n\n$date, $dateFormatted\n\nAsunto: $subject\n\nEstimado/a Sr./Sra.,\n\nPor medio de la presente, me permito dirigirles las siguientes solicitudes en relación con mi expediente de previsión profesional:\n\n1. Certificado de previsión actualizado $year (haber de vejez, prestaciones cubiertas, tasa de conversión aplicable)\n\n2. Confirmación de mi capacidad de rescate (importe máximo según el art. 79b LPP)\n\n3. Simulación de jubilación anticipada (proyección del haber y de la renta a los 63 y 64 años, en su caso)\n\nLes agradezco de antemano su diligencia y quedo a su disposición para cualquier información adicional.\n\nAtentamente,\n\n$name\n$policeNumber';
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
    return '$name\n$address\n$postalCity\n\n$caisseSource\n$caisseCurrentAddress\n$postalCity\n\n$date, $dateFormatted\n\nAsunto: $subject\n\nEstimado/a Sr./Sra.,\n\nDebido a la terminación de mi relación laboral / mi salida de Suiza (tachar lo que no corresponda), les solicito que procedan a la transferencia de mi haber de libre paso.\n\nImporte a transferir: la totalidad del haber de libre paso a la fecha de salida.\n\nEntidad de destino:\nNombre: $toComplete\nIBAN o número de cuenta: $toComplete\nDirección: $toComplete\n\nFecha de salida: $toComplete\n\nLes agradezco su diligencia y les ruego que confirmen la correcta ejecución de esta transferencia.\n\nAtentamente,\n\n$name';
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
    return '$name\n$ssn\n$address\n$postalCity\n\n$avsOrg\n$avsAddress\n$postalCity\n\n$date, $dateFormatted\n\nAsunto: $subject\n\nEstimado/a Sr./Sra.,\n\nLes solicito que me remitan un extracto de mi cuenta individual AVS (CI) para verificar el estado de mis cotizaciones e identificar posibles lagunas.\n\nLes agradezco de antemano su diligencia.\n\nAtentamente,\n\n$name';
  }

  @override
  String get seasonalEventCta => 'Hablar con el coach';

  @override
  String get communityChallengeCta => 'Aceptar el reto';

  @override
  String get dossierExpertSectionTitle => 'Consultar a un·a especialista';

  @override
  String get expertPrepareDossierCta => 'Preparar mi expediente';

  @override
  String get dossierAgentSectionTitle => 'Documentos preparados';

  @override
  String get agentFormsTaxCta => 'Preparar mi declaración';

  @override
  String get agentFormsTaxSubtitle => 'Pre-relleno desde tu perfil';

  @override
  String get agentFormsAvsCta => 'Solicitar mi extracto AVS';

  @override
  String get agentFormsAvsSubtitle => 'Plantilla de carta lista para enviar';

  @override
  String get agentFormsLppCta => 'Solicitar transferencia LPP';

  @override
  String get agentFormsLppSubtitle => 'Carta de transferencia de libre paso';

  @override
  String get notifThreeATitle => 'Plazo 3a';

  @override
  String get notifThreeA92Days => 'Quedan 92 días para aportar a tu 3a.';

  @override
  String notifThreeA61Days(String saving) {
    return 'Quedan 61 días. Ahorro estimado: CHF $saving.';
  }

  @override
  String notifThreeALastMonth(String saving) {
    return 'Último mes para tu 3a. CHF $saving de ahorro en juego.';
  }

  @override
  String get notifThreeA11Days => '11 días. Último recordatorio 3a.';

  @override
  String notifNewYearTitle(String year) {
    return 'Nuevos límites $year';
  }

  @override
  String notifNewYearBody(String year) {
    return 'Nuevos límites $year. Tu ahorro potencial ha cambiado.';
  }

  @override
  String get notifCheckInTitle => 'Check-in mensual';

  @override
  String get notifCheckInBody => 'Tu check-in mensual está disponible.';

  @override
  String get notifTaxTitle => 'Declaración fiscal';

  @override
  String get notifTax44Days =>
      'Declaración fiscal en 44 días. Empieza a reunir tus documentos.';

  @override
  String get notifTax16Days =>
      'Declaración fiscal en 16 días. Empieza a rellenarla.';

  @override
  String get notifTaxLastWeek =>
      'Declaración antes del 31 de marzo. Última semana.';

  @override
  String get notifFriTitle => 'Puntuación de solidez';

  @override
  String notifFriCheckIn(String delta) {
    return 'Desde tu último check-in: $delta puntos.';
  }

  @override
  String notifFriImproved(String delta) {
    return 'Tu solidez ha mejorado en $delta puntos.';
  }

  @override
  String get notifProfileUpdatedTitle => 'Perfil actualizado';

  @override
  String get notifProfileUpdatedBody =>
      'Tu perfil ha sido actualizado. Nuevas proyecciones disponibles.';

  @override
  String get notifOffTrackTitle => 'Te estás desviando de tu plan';

  @override
  String notifOffTrackBody(String adherence, String total, String impact) {
    return 'Adherencia al $adherence% en $total acciones. Estimación lineal (sin rendimiento/impuestos): ~CHF $impact.';
  }

  @override
  String get agentTaskTaxDeclarationTitle =>
      'Pre-rellenado de declaración fiscal';

  @override
  String get agentTaskTaxDeclarationDesc =>
      'Estimación de los principales campos de tu declaración fiscal basada en tu perfil MINT. Todos los importes son aproximados.';

  @override
  String get agentTaskThreeAFormTitle => 'Pre-rellenado formulario 3a';

  @override
  String get agentTaskThreeAFormDesc =>
      'Información básica para una aportación al pilar 3. El límite se calcula según tu situación laboral.';

  @override
  String get agentTaskCaisseLetterTitle => 'Carta al fondo de pensiones';

  @override
  String get agentTaskCaisseLetterDesc =>
      'Plantilla de carta formal para solicitar un certificado LPP, confirmación de recompra y simulación de jubilación anticipada.';

  @override
  String get agentTaskFiscalDossierTitle => 'Preparación del expediente fiscal';

  @override
  String get agentTaskFiscalDossierDesc =>
      'Resumen educativo de tu situación fiscal estimada con deducciones posibles y preguntas para un·a especialista.';

  @override
  String get agentTaskAvsExtractTitle => 'Solicitud de extracto AVS';

  @override
  String get agentTaskAvsExtractDesc =>
      'Plantilla de carta para solicitar un extracto de cuenta individual (CI) a tu caja de compensación AVS.';

  @override
  String get agentTaskLppCertificateTitle => 'Solicitud de certificado LPP';

  @override
  String get agentTaskLppCertificateDesc =>
      'Plantilla de carta para solicitar un certificado de previsión profesional actualizado a tu fondo de pensiones.';

  @override
  String get agentTaskDisclaimer =>
      'Esta herramienta es puramente educativa y no constituye asesoramiento financiero, fiscal ni jurídico. Los importes mostrados son estimaciones indicativas. Consulta a un·a especialista cualificado·a antes de cualquier decisión. Conforme a LSFin.';

  @override
  String get agentTaskValidationPromptDefault =>
      'Verifica cuidadosamente cada información antes de usar. Todos los campos son estimaciones a confirmar.';

  @override
  String get agentTaskValidationPromptLetter =>
      'Verifica la información y completa los campos entre corchetes antes de enviar esta carta.';

  @override
  String get agentTaskValidationPromptRequest =>
      'Verifica la información y completa los campos entre corchetes antes de enviar esta solicitud.';

  @override
  String agentFieldRevenuBrutValue(String range) {
    return '~$range CHF/año';
  }

  @override
  String agentFieldRachatLppValue(String range) {
    return '~$range CHF';
  }

  @override
  String get agentFieldAnneRef => 'Año de referencia';

  @override
  String get agentFieldCaissePension => 'Fondo de pensiones';

  @override
  String get agentFieldAddressPerso => 'Dirección personal';

  @override
  String get agentFieldAddresseCaisse => 'Dirección del fondo de pensiones';

  @override
  String get agentFieldNumeroPolice => 'Número de póliza';

  @override
  String get agentFieldNumeroAvs => 'Número AVS';

  @override
  String get agentFieldAddresseCaisseAvs => 'Dirección de la caja AVS';

  @override
  String get agentFiscalDossierRevenu => 'Ingresos brutos estimados';

  @override
  String get agentFiscalDossierPlafond3a => 'Límite 3a aplicable';

  @override
  String get agentFiscalDossierRachat => 'Recompra LPP disponible';

  @override
  String get agentFiscalDossierCapital3a => 'Capital 3a acumulado';

  @override
  String get proactiveLifecycleChange =>
      'Acabas de entrar en una nueva etapa de vida. ¿Vemos qué cambia para ti ?';

  @override
  String get proactiveWeeklyRecap =>
      'Tu resumen semanal está listo. ¿Quieres verlo ?';

  @override
  String proactiveGoalMilestone(String progress) {
    return 'Tu objetivo ha superado el $progress %. ¡Bien hecho !';
  }

  @override
  String proactiveSeasonalReminder(String event) {
    return 'Es la temporada de $event. Un buen momento para…';
  }

  @override
  String proactiveInactivityReturn(String days) {
    return '¡Me alegra verte de nuevo ! Han pasado $days días. ¿Hacemos el punto ?';
  }

  @override
  String proactiveConfidenceUp(String delta) {
    return 'Tu confianza ha mejorado $delta pts desde la última vez.';
  }

  @override
  String get proactiveNewCap => 'Tengo una nueva prioridad para ti.';

  @override
  String get dossierToolsSection => 'Herramientas';

  @override
  String get dossierToolsCta => 'Ver todas las herramientas';

  @override
  String get pulseNarrativeBudgetGoal => 'tu margen mensual libre:';

  @override
  String get pulseNarrativeHousingGoal => 'tu capacidad de compra estimada:';

  @override
  String get pulseNarrativeRetirementGoal => 'tu tasa de reemplazo:';

  @override
  String get pulseLabelBudgetFree => 'Presupuesto libre este mes';

  @override
  String get pulseLabelPurchasingCapacity => 'Capacidad de compra estimada';

  @override
  String capSequenceProgress(int completed, int total) {
    return '$completed/$total pasos';
  }

  @override
  String get capSequenceComplete => '¡Plan completado!';

  @override
  String get capSequenceCurrentStep => 'Próximo paso';

  @override
  String get capStepRetirement01Title => 'Conocer tu salario bruto';

  @override
  String get capStepRetirement01Desc =>
      'La base de todos los cálculos de jubilación.';

  @override
  String get capStepRetirement02Title => 'Estimar tu renta AVS';

  @override
  String get capStepRetirement02Desc =>
      'Tus años cotizados determinan el 1er pilar.';

  @override
  String get capStepRetirement03Title => 'Verificar tu capital LPP';

  @override
  String get capStepRetirement03Desc =>
      'El certificado LPP revela tu capital del 2º pilar.';

  @override
  String get capStepRetirement04Title => 'Calcular tu tasa de reemplazo';

  @override
  String get capStepRetirement04Desc =>
      'Cuánto de tu salario recibirás al jubilarte.';

  @override
  String get capStepRetirement05Title => 'Simular una aportación 3a';

  @override
  String get capStepRetirement05Desc =>
      'Deducir hasta CHF 7.258 y reforzar tu jubilación.';

  @override
  String get capStepRetirement06Title => 'Evaluar una recompra LPP';

  @override
  String get capStepRetirement06Desc => 'Cubrir lagunas y reducir impuestos.';

  @override
  String get capStepRetirement07Title => 'Comparar renta vs capital';

  @override
  String get capStepRetirement07Desc => '¿Renta mensual o retiro de capital?';

  @override
  String get capStepRetirement08Title => 'Planificar el retiro';

  @override
  String get capStepRetirement08Desc =>
      'El orden de retiro impacta tu factura fiscal.';

  @override
  String get capStepRetirement09Title => 'Optimizar fiscalmente';

  @override
  String get capStepRetirement09Desc =>
      '3a, recompra, timing: reducir la imposición del capital.';

  @override
  String get capStepRetirement10Title => 'Consultar a un especialista';

  @override
  String get capStepRetirement10Desc =>
      'Una revisión experta de tu situación completa.';

  @override
  String get capStepBudget01Title => 'Conocer tus ingresos';

  @override
  String get capStepBudget01Desc =>
      'El punto de partida de cualquier análisis presupuestario.';

  @override
  String get capStepBudget02Title => 'Listar tus gastos fijos';

  @override
  String get capStepBudget02Desc =>
      'Alquiler, seguro de salud, transporte: lo inevitable.';

  @override
  String get capStepBudget03Title => 'Calcular tu margen libre';

  @override
  String get capStepBudget03Desc =>
      'Lo que queda tras los gastos — tu campo de juego.';

  @override
  String get capStepBudget04Title => 'Identificar ahorros posibles';

  @override
  String get capStepBudget04Desc => 'Pequeños ajustes, gran impacto mensual.';

  @override
  String get capStepBudget05Title => 'Construir un fondo de emergencia';

  @override
  String get capStepBudget05Desc =>
      '3 meses de gastos líquidos: tu red de seguridad.';

  @override
  String get capStepBudget06Title => 'Planificar el 3a';

  @override
  String get capStepBudget06Desc =>
      'Cada franco aportado reduce impuestos y prepara la jubilación.';

  @override
  String get capStepHousing01Title => 'Conocer tus ingresos';

  @override
  String get capStepHousing01Desc =>
      'La base del cálculo de capacidad de compra.';

  @override
  String get capStepHousing02Title => 'Evaluar tus fondos propios';

  @override
  String get capStepHousing02Desc =>
      'Ahorros, 3a y LPP: reunir el aporte necesario.';

  @override
  String get capStepHousing03Title => 'Calcular tu capacidad de compra';

  @override
  String get capStepHousing03Desc => '¿Hasta qué precio puedes comprar?';

  @override
  String get capStepHousing04Title => 'Simular la hipoteca';

  @override
  String get capStepHousing04Desc =>
      'Cuota mensual, amortización, tasa teórica.';

  @override
  String get capStepHousing05Title => 'Evaluar el EPL (2º pilar)';

  @override
  String get capStepHousing05Desc =>
      'Retiro anticipado LPP para financiar el aporte.';

  @override
  String get capStepHousing06Title => 'Comparar alquiler vs compra';

  @override
  String get capStepHousing06Desc =>
      'El cálculo que va más allá de las intuiciones.';

  @override
  String get capStepHousing07Title => 'Consultar a un especialista';

  @override
  String get capStepHousing07Desc =>
      'Notario, intermediario, asesor: cuándo involucrar a quién.';

  @override
  String get goalSelectorTitle => '¿Cuál es tu objetivo principal?';

  @override
  String get goalSelectorAuto => 'Dejar que MINT decida';

  @override
  String get goalSelectorAutoDesc =>
      'MINT se adapta automáticamente según tu perfil';

  @override
  String get goalRetirementTitle => 'Mi jubilación';

  @override
  String get goalRetirementDesc => 'Planificar la transición a la jubilación';

  @override
  String get goalBudgetTitle => 'Mi presupuesto';

  @override
  String get goalBudgetDesc => 'Controlar mis gastos y ahorrar';

  @override
  String get goalHousingTitle => 'Comprar una vivienda';

  @override
  String get goalHousingDesc => 'Evaluar mi capacidad y planificar la compra';

  @override
  String get goalTaxTitle => 'Pagar menos impuestos';

  @override
  String get goalTaxDesc => 'Optimizar mis deducciones (3a, rescate LPP)';

  @override
  String get goalDebtTitle => 'Gestionar mis deudas';

  @override
  String get goalDebtDesc => 'Recuperar margen y reembolsar';

  @override
  String get goalBirthTitle => 'Preparar un nacimiento';

  @override
  String get goalBirthDesc => 'Anticipar los costes y adaptar el presupuesto';

  @override
  String get goalIndependentTitle => 'Hacerse autónomo/a';

  @override
  String get goalIndependentDesc => 'Previsión, fiscalidad y cobertura';

  @override
  String pulseGoalChip(String goal) {
    return 'Objetivo: $goal';
  }

  @override
  String get dossierProfileSection => 'Mi perfil';

  @override
  String get dossierPlanSection => 'Mi plan';

  @override
  String get dossierDataSection => 'Mis datos';

  @override
  String get dossierConfidenceLabel => 'Fiabilidad del expediente';

  @override
  String get dossierCompleteCta => 'Completar mi perfil';

  @override
  String get dossierChooseGoalCta => 'Elegir un objetivo';

  @override
  String get dossierScanLppCta => 'Escanear mi certificado LPP';

  @override
  String get dossierDataRevenu => 'Ingresos';

  @override
  String get dossierDataLpp => '2º pilar';

  @override
  String get dossierData3a => '3º pilar';

  @override
  String get dossierDataBudget => 'Margen mensual';

  @override
  String get dossierDataUnknown => 'No indicado';

  @override
  String dossierPlanProgress(int done, int total) {
    return '$done / $total pasos';
  }

  @override
  String get dossierPlanChangeGoal => 'Cambiar objetivo';

  @override
  String get dossierPlanCurrentStep => 'Paso actual';

  @override
  String get dossierPlanNextStep => 'Próximo paso';

  @override
  String dossierConfidencePct(int pct) {
    return '$pct %';
  }

  @override
  String memoryRefTopic(int days, String topic) {
    return 'Hace $days días, me hablaste de $topic.';
  }

  @override
  String memoryRefGoal(String goal) {
    return 'Te habías fijado el objetivo: $goal. ¿Hacemos balance?';
  }

  @override
  String memoryRefScreenVisit(String screen) {
    return 'La última vez, usaste $screen.';
  }

  @override
  String get memoryRefRecentInsights =>
      'Lo que recuerdo de nuestras conversaciones:';

  @override
  String openerBudgetDeficit(String deficit) {
    return 'CHF $deficit/mes de déficit. ¿Vemos dónde se atasca?';
  }

  @override
  String opener3aDeadline(String days, String plafond) {
    return 'Quedan $days días para ingresar hasta $plafond CHF en tu 3a.';
  }

  @override
  String openerGapWarning(String rate, String gap) {
    return 'Tu tasa de reemplazo: $rate %. En la jubilación te faltarían CHF $gap/mes.';
  }

  @override
  String openerSavingsOpportunity(String plafond) {
    return 'Tu 3a: CHF 0 este año. $plafond CHF de ahorro fiscal en juego.';
  }

  @override
  String openerProgressCelebration(String delta) {
    return 'Tu fiabilidad ha ganado $delta puntos. Tus cifras son más precisas.';
  }

  @override
  String openerPlanProgress(String n, String total, String next) {
    return 'Etapa $n/$total completada. Siguiente: $next.';
  }

  @override
  String get semanticsBackButton => 'Volver';

  @override
  String get semanticsDecrement => 'Disminuir';

  @override
  String get semanticsIncrement => 'Aumentar';

  @override
  String get frontalierDisclaimer =>
      'Estimaciones simplificadas con fines educativos — no constituye asesoramiento fiscal o jurídico. Los importes dependen de muchos factores. Consulta un especialista fiscal para un análisis personalizado. LSFin.';

  @override
  String get firstJobPayslipAvsLabel => 'AVS/AI/APG';

  @override
  String get firstJobPayslipAvsExplanation =>
      'Cotización del empleado: 5.3% del salario bruto. Tu empleador también paga 5.3% adicional.';

  @override
  String get firstJobPayslipLppLabel => 'LPP (2.° pilar)';

  @override
  String get firstJobPayslipLppExplanation =>
      'Ahorro para la jubilación obligatorio desde los 25 años. La tasa exacta depende de tu fondo y edad.';

  @override
  String get firstJobPayslipImpotLabel => 'Impuesto en la fuente (estimación)';

  @override
  String get firstJobPayslipImpotExplanation =>
      'Deducido directamente del salario si pagas impuestos en la fuente. La tasa varía según cantón, estado civil e ingresos.';

  @override
  String get firstJobChecklistDeadline1 => 'Antes de salir';

  @override
  String get firstJobChecklistAction1 =>
      'Solicita tu certificado LPP a tu empleador actual.';

  @override
  String get firstJobChecklistConsequence1 =>
      'Sin certificado, no puedes verificar que el importe transferido es correcto.';

  @override
  String get firstJobChecklistDeadline2 => '30 días';

  @override
  String get firstJobChecklistAction2 =>
      'Verifica que tu capital LPP se haya transferido al fondo de tu nuevo empleador.';

  @override
  String get firstJobChecklistConsequence2 =>
      'Sin transferencia, tu capital va a la fundación supletoria a una tasa del 0.05%.';

  @override
  String get firstJobChecklistDeadline3 => '1 mes';

  @override
  String get firstJobChecklistAction3 =>
      'Informa a tu seguro de salud LAMal del cambio de empleador si tenías cobertura colectiva.';

  @override
  String get firstJobChecklistDeadline4 => 'Desde el primer sueldo';

  @override
  String get firstJobChecklistAction4 =>
      'Continúa tus aportaciones al pilar 3a — la interrupción te cuesta deducciones fiscales.';

  @override
  String get firstJobBudgetBesoins => 'Necesidades';

  @override
  String get firstJobBudgetLoyer => 'Alquiler';

  @override
  String get firstJobBudgetTransport => 'Transporte';

  @override
  String get firstJobBudgetAlimentation => 'Alimentación';

  @override
  String get firstJobBudgetEnvies => 'Deseos';

  @override
  String get firstJobBudgetLoisirs => 'Ocio';

  @override
  String get firstJobBudgetRestaurants => 'Restaurantes';

  @override
  String get firstJobBudgetVoyages => 'Viajes';

  @override
  String get firstJobBudgetShopping => 'Compras';

  @override
  String get firstJobBudgetEpargne => 'Ahorro & 3a';

  @override
  String get firstJobBudgetPilier3a => 'Pilar 3a';

  @override
  String get firstJobBudgetEpargneCourt => 'Ahorros';

  @override
  String get firstJobBudgetFondsUrgence => 'Fondo de emergencia';

  @override
  String firstJobBudgetChiffreChoc(String annual, String future) {
    return 'Si ahorras $annual CHF/año desde ahora, tendrás ~$future CHF a los 65.';
  }

  @override
  String get firstJobScenarioMySalary => 'Mi salario';

  @override
  String get firstJobScenarioDefault => 'Por defecto';

  @override
  String get firstJobScenarioMedianCH => 'Mediana CH';

  @override
  String get firstJobScenarioBoosted => '+20%';

  @override
  String firstJobScenarioSemantics(String label) {
    return 'Escenario salarial: $label';
  }

  @override
  String get pulseRetirementIncome => 'Ingreso jubilación estimado';

  @override
  String get pulseCapImpact => 'Palanca identificada';

  @override
  String get dossierAddConjointCta => 'Añadir mi pareja';

  @override
  String get dossierDataAvs => '1er pilar';

  @override
  String get dossierDataFiscalite => 'Fiscalidad';

  @override
  String get pulseRetirementIncomeEstimated =>
      'Jubilación estimada (mínimo LPP)';

  @override
  String get dossierScanLppPrecision =>
      'Escanea tu certificado para proyecciones más precisas';

  @override
  String get pulsePlanTitle => 'Mi plan';

  @override
  String pulsePlanProgress(int completed, int total) {
    return '$completed/$total';
  }

  @override
  String pulsePlanNextStep(String stepName) {
    return 'Próximo paso: $stepName';
  }

  @override
  String get dossierCoachingTitle => 'Acompañamiento';

  @override
  String get dossierCoachingSubtitle =>
      'Frecuencia de recordatorios y sugerencias';

  @override
  String get coachingSheetSubtitle =>
      'Elige con qué frecuencia MINT te acompaña';

  @override
  String get coachingIntensityDiscret => 'Discreto';

  @override
  String get coachingIntensityCalme => 'Calmo';

  @override
  String get coachingIntensityEquilibre => 'Equilibrado';

  @override
  String get coachingIntensityAttentif => 'Atento';

  @override
  String get coachingIntensityProactif => 'Proactivo';

  @override
  String get coachingDescDiscret =>
      'MINT te deja tranquilo. Recordatorios raros, solo plazos críticos.';

  @override
  String get coachingDescCalme =>
      'MINT interviene ocasionalmente. Un recordatorio cada 3 días máximo.';

  @override
  String get coachingDescEquilibre =>
      'MINT te guía diariamente. Un recordatorio por día, sugerencias contextuales.';

  @override
  String get coachingDescAttentif =>
      'MINT está atento en cada sesión. Sugerencias frecuentes y memoria rica.';

  @override
  String get coachingDescProactif =>
      'MINT te acompaña activamente. Recordatorios en cada visita, memoria completa.';

  @override
  String coachingEngagementStats(Object engaged, Object total) {
    return '$engaged interacciones de $total sugerencias';
  }

  @override
  String get landingHiddenAmount => 'Monto oculto';

  @override
  String get landingHiddenSubtitle => 'Crea una cuenta para ver tus números';

  @override
  String get friBarTitle => 'Resiliencia financiera';

  @override
  String get friBarLiquidity => 'Liquidez';

  @override
  String get friBarFlexibility => 'Flexibilidad';

  @override
  String get friBarResilience => 'Resiliencia';

  @override
  String get friBarStability => 'Estabilidad';

  @override
  String get deuxViesTitle => 'Vuestras dos vidas';

  @override
  String deuxViesGap(String amount, String name) {
    return 'Brecha de $amount/mes a favor de $name';
  }

  @override
  String deuxViesLever(String lever, String impact) {
    return '$lever cerraría $impact de la brecha';
  }

  @override
  String get deuxViesDisclaimer =>
      'Herramienta educativa. No es asesoramiento financiero (LSFin).';

  @override
  String get expertTierScreenTitle => 'Consultar a un·a especialista';

  @override
  String get expertTierFinancialPlanner => 'Planificador·a financiero·a';

  @override
  String get expertTierFinancialPlannerDesc =>
      'Jubilación, previsión, estrategia de retiro, planificación patrimonial global';

  @override
  String get expertTierTaxSpecialist => 'Especialista fiscal';

  @override
  String get expertTierTaxSpecialistDesc =>
      'Optimización fiscal, recompra LPP, declaración, planificación intercantonal';

  @override
  String get expertTierNotary => 'Notario·a';

  @override
  String get expertTierNotaryDesc =>
      'Sucesión, testamento, donación, régimen matrimonial, pacto sucesorio';

  @override
  String get expertTierPrice => 'CHF 129 / sesión';

  @override
  String get expertTierSelectCta => 'Preparar mi expediente';

  @override
  String get expertTierDossierPreviewTitle => 'Vista previa de tu expediente';

  @override
  String get expertTierDossierGenerating => 'Preparando el expediente…';

  @override
  String get expertTierDossierReady => 'Expediente listo';

  @override
  String get expertTierRequestCta => 'Solicitar una cita';

  @override
  String get expertTierComingSoonTitle => 'Próximamente';

  @override
  String get expertTierComingSoon =>
      'La reserva de citas llegará pronto. Tu expediente está listo — podrás compartirlo en cuanto el servicio esté disponible.';

  @override
  String expertTierCompleteness(String percent) {
    return 'Perfil completo al $percent %';
  }

  @override
  String get expertTierEstimated => 'Estimado';

  @override
  String get expertTierMissingDataTitle => 'Datos por completar';

  @override
  String get expertTierDisclaimerBanner =>
      'MINT prepara el expediente, el·la especialista da el consejo';

  @override
  String get expertTierBack => 'Elegir otro·a especialista';

  @override
  String get expertTierOk => 'Entendido';

  @override
  String get docCardTitle => 'Documento pre-rellenado';

  @override
  String get docCardFiscalDeclaration => 'Declaración fiscal';

  @override
  String get docCardPensionFundLetter => 'Carta al fondo de pensiones';

  @override
  String get docCardLppBuybackRequest => 'Solicitud de recompra LPP';

  @override
  String get docCardDisclaimer => 'Verifica cada campo. MINT nunca envía nada.';

  @override
  String get docCardViewDocument => 'Ver documento';

  @override
  String get docCardValidationFailed => 'La validación del documento falló.';

  @override
  String get docCardGenerating => 'Generando documento…';

  @override
  String docCardFieldCount(int count) {
    return '$count campos pre-rellenados';
  }

  @override
  String get docCardReadOnly => 'Solo lectura — completar manualmente';

  @override
  String get sourceBadgeEstimated => 'Estimado';

  @override
  String get sourceBadgeDeclared => 'Declarado';

  @override
  String get sourceBadgeCertified => 'Certificado';

  @override
  String get monteCarloTitle => 'Tus probabilidades de vivir cómodamente';

  @override
  String monteCarloSubtitle(int count) {
    return '$count escenarios simulados';
  }

  @override
  String get monteCarloHeroPhrase =>
      'de probabilidad de que tu capital dure hasta los 90 años';

  @override
  String get monteCarloLegendWideBand => 'Rango amplio';

  @override
  String get monteCarloLegendProbableBand => 'Rango probable';

  @override
  String get monteCarloLegendMedian => 'Escenario central';

  @override
  String get monteCarloLegendCurrentIncome => 'Lo que ganas hoy';

  @override
  String monteCarloMedianAtAge(int age) {
    return 'Escenario central a los $age años';
  }

  @override
  String get monteCarloProbableRange => 'Rango probable';

  @override
  String get monteCarloSuccessLabel =>
      'Probabilidad de que tu\ncapital dure hasta los 90 años';

  @override
  String get monteCarloDisclaimer =>
      'Los rendimientos pasados no predicen los rendimientos futuros. Simulación educativa (LSFin).';

  @override
  String get dossierIdentiteSection => 'Identidad';

  @override
  String get dossierDocumentsSection => 'Documentos';

  @override
  String get dossierCoupleSection => 'Pareja';

  @override
  String get dossierPreferencesSection => 'Preferencias';

  @override
  String dossierUpdatedAgo(int days) {
    return 'Actualizado hace $days días';
  }

  @override
  String dossierUpdatedOn(String date) {
    return 'Actualizado el $date';
  }

  @override
  String get dossierUpdatedToday => 'Actualizado hoy';

  @override
  String get dossierUpdatedYesterday => 'Actualizado ayer';

  @override
  String get exploreHubOtherTopics => 'Otros temas';

  @override
  String get bankImportSummaryHeader => 'RESUMEN';

  @override
  String get bankImportTransactionsHeader => 'TRANSACCIONES';

  @override
  String bankImportMoreTransactions(int count) {
    return '... y $count transacciones más';
  }

  @override
  String get bankImportGenericError =>
      'Se produjo un error al analizar el extracto.';

  @override
  String get helpResourcesAppBarTitle => 'AYUDA EN CASO DE DEUDA';

  @override
  String get helpResourcesIntroTitle => 'No estás solo';

  @override
  String get helpResourcesIntroBody =>
      'En Suiza, muchos servicios profesionales ofrecen acompañamiento gratuito y confidencial para personas que enfrentan dificultades financieras. Pedir ayuda es un acto de valentía.';

  @override
  String get helpResourcesIntroNote =>
      'Todos los enlaces llevan a sitios externos. MINT no transmite ningún dato a estos servicios.';

  @override
  String get helpResourcesDettesName => 'Dettes Conseils Suisse';

  @override
  String get helpResourcesDettesDesc =>
      'Federación de servicios de asesoramiento en deudas en Suiza. Asesoramiento gratuito, confidencial y profesional.';

  @override
  String get helpResourcesCaritasName => 'Caritas — Asesoramiento en deudas';

  @override
  String get helpResourcesCaritasDesc =>
      'Servicio de ayuda de Caritas Suiza para personas endeudadas. Ayuda en desendeudamiento, negociación con acreedores.';

  @override
  String get helpResourcesFreeLabel => 'GRATIS';

  @override
  String get helpResourcesCantonalHeader => 'SERVICIO CANTONAL';

  @override
  String get helpResourcesCantonLabel => 'Tu cantón';

  @override
  String get helpResourcesNoService =>
      'Ningún servicio cantonal registrado para este cantón. Contacta Dettes Conseils Suisse.';

  @override
  String get helpResourcesPrivacyTitle => 'Protección de datos (nLPD)';

  @override
  String get helpResourcesPrivacyBody =>
      'MINT no transmite ningún dato personal a los servicios mencionados. Los enlaces externos abren tu navegador. Tu uso de esta pantalla es estrictamente confidencial.';

  @override
  String get helpResourcesDisclaimer =>
      'MINT proporciona estos enlaces con fines informativos y educativos. Estos servicios son independientes de MINT. MINT no ofrece asesoramiento jurídico o financiero.';

  @override
  String get successionUrgenceAction1 =>
      'Declarar el fallecimiento en el registro civil en 2 días';

  @override
  String get successionUrgenceAction2 =>
      'Informar al empleador y aseguradoras (LAMal, LPP)';

  @override
  String get successionUrgenceAction3 =>
      'Bloquear cuentas bancarias conjuntas si es necesario';

  @override
  String get successionUrgenceAction4 =>
      'Contactar al notario si la persona tenía testamento';

  @override
  String get successionDemarchesAction1 =>
      'Solicitar pensiones de sobrevivientes AVS (LAVS art. 23)';

  @override
  String get successionDemarchesAction2 =>
      'Contactar la caja LPP para el capital de fallecimiento';

  @override
  String get successionDemarchesAction3 =>
      'Cancelar suscripciones y contratos a nombre del difunto';

  @override
  String get successionDemarchesAction4 =>
      'Hacer inventario de activos y deudas';

  @override
  String get successionDemarchesAction5 =>
      'Solicitar certificados de herederos al notario';

  @override
  String get successionLegaleAction1 =>
      'Abrir el procedimiento de sucesión con el notario';

  @override
  String get successionLegaleAction2 =>
      'Repartir bienes según testamento o ley (CC art. 537)';

  @override
  String get successionLegaleAction3 =>
      'Presentar declaración fiscal del año del fallecimiento';

  @override
  String get successionLegaleAction4 =>
      'Actualizar beneficiarios de tus propios contratos';

  @override
  String get disabilityGapAct1Label => 'ACTO 1 · Empleador';

  @override
  String get disabilityGapAct1Detail =>
      '80 % de tu salario pagado por tu empleador';

  @override
  String get disabilityGapAct1Duration => 'Semanas 1-26';

  @override
  String get disabilityGapAct2LabelIjm => 'ACTO 2 · IJM (seguro de enfermedad)';

  @override
  String get disabilityGapAct2LabelNoIjm => 'ACTO 2 · Sin IJM';

  @override
  String get disabilityGapAct2SubIjm =>
      'Seguro colectivo — 80% durante 720 días máx.';

  @override
  String get disabilityGapAct2SubNoIjm =>
      'Sin IJM, pasas directamente a AI después del empleador';

  @override
  String get disabilityGapAct2Duration => 'Hasta 24 meses';

  @override
  String get disabilityGapAct2DetailIjm => '80% del salario asegurado';

  @override
  String get disabilityGapAct2DetailNoIjm =>
      'Sin cobertura — plazo AI en curso';

  @override
  String get disabilityGapAct3Label => 'ACTO 3 · AI + LPP (definitivo)';

  @override
  String get disabilityGapAct3Duration => 'Después de 24 meses';

  @override
  String disabilityGapAct3Detail(
      String aiAmount, String lppAmount, String totalAmount) {
    return 'AI $aiAmount + LPP $lppAmount = $totalAmount CHF/mes';
  }

  @override
  String get disabilityGapIjmCoverage =>
      '80% durante 720 días — seguro colectivo';

  @override
  String get disabilityGapNoIjmCoverage =>
      'Ninguna IJM suscrita — riesgo máximo';

  @override
  String disabilityGapAiDetail(String amount) {
    return 'Máx. $amount CHF/mes — ~14 meses de espera';
  }

  @override
  String get disabilityGapLppCovered =>
      'Pensión de invalidez ≈ 40% salario coordinado (LPP art. 23)';

  @override
  String get disabilityGapLppNotCovered =>
      'Salario bajo el umbral LPP — sin cobertura 2º pilar';

  @override
  String get disabilityGapSavingsLabel => 'Reserva de emergencia';

  @override
  String disabilityGapSavingsDetail(String months) {
    return '$months meses de gastos cubiertos';
  }

  @override
  String get disabilityGapApgLabel => 'APG / IJM (pérdida de ingresos)';

  @override
  String get disabilityGapAiLabel => 'AI (seguro de invalidez)';

  @override
  String get disabilityGapLppLabel => 'LPP invalidez (2º pilar)';

  @override
  String get disabilityGapSources =>
      '• LAI art. 28-29 (pensión AI)\n• LPP art. 23-26 (invalidez 2º pilar)\n• CO art. 324a (mantenimiento salario)\n• LPGA art. 19 (plazo de carencia)';

  @override
  String disabilityGapAgeLabel(int age) {
    return '$age años';
  }

  @override
  String get documentDetailExplanationObligatoire =>
      'Monto acumulado en la parte obligatoria LPP';

  @override
  String get documentDetailExplanationSurobligatoire =>
      'Parte más allá del mínimo legal';

  @override
  String get documentDetailExplanationTotal => 'Total de tu capital de vejez';

  @override
  String get documentDetailExplanationSalaireAssure =>
      'Salario sobre el cual se calculan las cotizaciones';

  @override
  String get documentDetailExplanationSalaireAvs =>
      'Salario determinante para el AVS';

  @override
  String get documentDetailExplanationDeduction =>
      'Monto deducido para coordinar con el AVS';

  @override
  String get documentDetailExplanationTauxOblig => 'Mínimo legal: 6.8%';

  @override
  String get documentDetailExplanationTauxSurob =>
      'Fijado por tu caja de pensiones';

  @override
  String get documentDetailExplanationTauxEnv => 'Tasa media ponderada';

  @override
  String get documentDetailExplanationInvalidite =>
      'Pensión en caso de incapacidad laboral';

  @override
  String get documentDetailExplanationDeces =>
      'Monto pagado a beneficiarios en caso de fallecimiento';

  @override
  String get documentDetailExplanationConjoint =>
      'Pensión pagada al cónyuge sobreviviente';

  @override
  String get documentDetailExplanationEnfant => 'Pensión pagada por hijo';

  @override
  String get documentDetailExplanationRachat =>
      'Monto que puede ser rescatado para optimizar tu previsión';

  @override
  String get documentDetailExplanationEmploye => 'Tu contribución anual';

  @override
  String get documentDetailExplanationEmployeur =>
      'Contribución de tu empleador';

  @override
  String get disabilitySelfEmployedAlertLabel => '🚨  ALERTA INDEPENDIENTE';

  @override
  String get disabilitySelfEmployedTitle => 'Tu red de seguridad no existe';

  @override
  String get disabilitySelfEmployedAppBarTitle => 'Invalidez — Independiente';

  @override
  String get disabilitySelfEmployedRevenueTitle => 'Tu ingreso mensual neto';

  @override
  String get disabilitySelfEmployedRevenueHint =>
      'Ajusta para ver el impacto en tu situación real';

  @override
  String get disabilitySelfEmployedRevenueLabel => 'Ingreso neto/mes';

  @override
  String get disabilitySelfEmployedInsuranceQuestion =>
      '¿Ya tienes seguro de pérdida de ingresos?';

  @override
  String get disabilitySelfEmployedYes => 'Sí';

  @override
  String get disabilitySelfEmployedNo => 'No / No sé';

  @override
  String get disabilitySelfEmployedApgTip =>
      'Una APG individual desde CHF 45/mes puede cubrir el 80% de tus ingresos durante 720 días. Es la red más efectiva para independientes.';

  @override
  String get disabilitySelfEmployedDisclaimer =>
      'Herramienta educativa — no constituye asesoramiento de seguros. Un corredor independiente puede comparar ofertas APG.';

  @override
  String get disabilitySelfEmployedSources =>
      '• LAMal art. 67-77\n• CO art. 324a\n• LAI art. 28\n• LAVS art. 2 al. 3';

  @override
  String get confidenceDashboardLevelExcellent => 'Excelente';

  @override
  String get confidenceDashboardLevelGood => 'Buena';

  @override
  String get confidenceDashboardLevelFair => 'Correcta';

  @override
  String get confidenceDashboardLevelImprove => 'A mejorar';

  @override
  String get confidenceDashboardLevelInsufficient => 'Insuficiente';

  @override
  String get confidenceDashboardBreakdownTitle => 'Detalle por eje';

  @override
  String get confidenceDashboardFeaturesTitle =>
      'Funcionalidades desbloqueadas';

  @override
  String confidenceDashboardRequired(String percent) {
    return '$percent % requerido';
  }

  @override
  String get confidenceDashboardEnrichTitle => 'Mejora tu precisión';

  @override
  String get confidenceDashboardSourcesTitle => 'Fuentes';

  @override
  String get cockpitDetailEmptyState =>
      'Completa tu perfil para acceder al cockpit detallado.';

  @override
  String get cockpitDetailEnrichProfile => 'Enriquecer mi perfil';

  @override
  String get cockpitDetailDisclaimer =>
      'Herramienta educativa simplificada. No constituye asesoramiento financiero (LSFin). Fuentes: LAVS art. 21-29, LPP art. 14, OPP3 art. 7.';

  @override
  String get toolBudgetSnapshotHint =>
      'Aquí tienes una vista de tu presupuesto actual.';

  @override
  String get toolScoreGaugeHint =>
      'Aquí tienes tu puntuación de confianza financiera.';

  @override
  String get coachFactCardTitle => '¿Sabías que?';

  @override
  String firstJobPrimePerMonth(String amount) {
    return '$amount/mes';
  }

  @override
  String firstJobCoutMaxPerYear(String amount) {
    return 'Máx. $amount/año';
  }

  @override
  String get jobChangeChecklistSemantics =>
      'Lista de verificación nuevo empleo LPP libre paso acciones urgentes';

  @override
  String get jobChangeChecklistTitle =>
      'Lista de verificación cambio de empleo';

  @override
  String get jobChangeChecklistSubtitle =>
      'Tienes 30 días para verificar que tu LPP ha sido transferido.';

  @override
  String jobChangeChecklistProgress(int completed, int total) {
    return '$completed / $total acciones completadas';
  }

  @override
  String get jobChangeChecklistAlertTitle =>
      'Solicita SIEMPRE el certificado LPP antes de firmar';

  @override
  String get jobChangeChecklistAlertBody =>
      'Sin transferencia del libre paso en los plazos, tu capital LPP puede acabar en la Fundación supletoria al 0.05 %.';

  @override
  String get jobChangeChecklistDisclaimer =>
      'Herramienta educativa · no constituye asesoramiento financiero en el sentido de la LSFin. Fuente: LPP art. 3 (libre paso), OLP art. 1-3.';

  @override
  String get circleLabelEmergencyFund => 'Fondo de emergencia';

  @override
  String get circleLabelDettes => 'Deudas';

  @override
  String get circleLabelRevenu => 'Ingresos';

  @override
  String get circleLabelAssurancesObligatoires => 'Seguros obligatorios';

  @override
  String get circleLabelTroisaOptimisation => '3a - Optimización';

  @override
  String get circleLabelTroisaVersement => '3a - Aportación';

  @override
  String get circleLabelLppRachat => 'LPP - Rescate';

  @override
  String get circleLabelAvs => 'AVS';

  @override
  String get circleLabelInvestissements => 'Inversiones';

  @override
  String get circleLabelPatrimoineImmobilier => 'Patrimonio inmobiliario';

  @override
  String get circleNameProtection => 'Protección & Seguridad';

  @override
  String get circleNamePrevoyance => 'Previsión Fiscal';

  @override
  String get circleNameCroissance => 'Crecimiento';

  @override
  String get circleNameOptimisation => 'Optimización & Transmisión';

  @override
  String get nudgeSalaryDayTitle => '¡Día de cobro!';

  @override
  String get nudgeSalaryDayMessage =>
      '¿Has pensado en tu transferencia al 3a este mes? Cada mes cuenta para tu previsión.';

  @override
  String get nudgeSalaryDayAction => 'Ver mi 3a';

  @override
  String get nudgeTaxDeadlineMessage =>
      'Verifica el plazo de la declaración fiscal en tu cantón. ¿Has revisado tus deducciones 3a y LPP?';

  @override
  String get nudgeTaxDeadlineAction => 'Simular mis impuestos';

  @override
  String get nudgeThreeADeadlineTitle => 'Última oportunidad para tu 3a';

  @override
  String get nudgeThreeADeadlineMessageLastDay =>
      '¡Hoy es el último día para aportar a tu 3a!';

  @override
  String get nudgeThreeADeadlineAction => 'Calcular mi ahorro';

  @override
  String get nudgeBirthdayDashboardAction => 'Ver mi panel';

  @override
  String get nudgeLppBonifStartTitle => 'Inicio de cotizaciones LPP';

  @override
  String get nudgeLppBonifChangeTitle => 'Cambio de tramo LPP';

  @override
  String get nudgeLppBonifAction => 'Explorar el rescate';

  @override
  String get nudgeWeeklyCheckInTitle => '¡Ha pasado un tiempo!';

  @override
  String get nudgeWeeklyCheckInMessage =>
      'Tu situación financiera evoluciona cada semana. Tómate 2 minutos para revisar tu panel.';

  @override
  String get nudgeWeeklyCheckInAction => 'Ver mi Pulse';

  @override
  String get nudgeStreakRiskTitle => '¡Tu racha está en peligro!';

  @override
  String get nudgeStreakRiskAction => 'Continuar mi racha';

  @override
  String get nudgeGoalApproachingTitle => 'Tu objetivo se acerca';

  @override
  String get nudgeGoalApproachingAction => 'Hablar con el coach';

  @override
  String get nudgeFhsDroppedTitle => 'Tu puntuación de salud ha bajado';

  @override
  String get nudgeFhsDroppedAction => 'Entender la caída';

  @override
  String get ragErrorInvalidKey => 'La clave API es inválida o ha expirado.';

  @override
  String get ragErrorRateLimit =>
      'Límite de solicitudes alcanzado. Inténtalo de nuevo en un momento.';

  @override
  String get ragErrorBadRequest => 'Solicitud inválida.';

  @override
  String get ragErrorServiceUnavailable =>
      'Servicio temporalmente no disponible. Inténtalo más tarde.';

  @override
  String get ragErrorStatus =>
      'No se puede verificar el estado del sistema RAG.';

  @override
  String get ragErrorVisionBadRequest => 'Solicitud de visión inválida.';

  @override
  String get ragErrorImageTooLarge =>
      'La imagen supera el límite de tamaño de 20 MB.';

  @override
  String get ragErrorRateLimitShort => 'Límite de solicitudes alcanzado.';

  @override
  String get paywallTitle => 'Desbloquea MINT Coach';

  @override
  String get paywallSubtitle => 'Tu coach financiero personal';

  @override
  String get paywallTrialBadge => 'Prueba gratuita 14 días';

  @override
  String paywallSubscriptionActivated(String tier) {
    return 'Suscripción $tier activada con éxito.';
  }

  @override
  String get paywallTrialActivated =>
      '¡Prueba gratuita activada! Disfruta de MINT Coach durante 14 días.';

  @override
  String get paywallRestoreButton => 'Restaurar una compra';

  @override
  String get paywallRestoreSuccess => '¡Suscripción restaurada con éxito!';

  @override
  String get paywallRestoreNoPurchase =>
      'No se encontró ninguna compra anterior.';

  @override
  String get paywallDisclaimer =>
      'Herramienta educativa — no constituye asesoramiento financiero. LSFin. Puedes cancelar en cualquier momento desde la configuración de tu cuenta.';

  @override
  String get paywallClose => 'Cerrar';

  @override
  String paywallSelectTier(String name) {
    return 'Seleccionar $name';
  }

  @override
  String paywallChooseTier(String tier) {
    return 'Elegir $tier';
  }

  @override
  String get paywallStartTrial => 'Iniciar prueba gratuita';

  @override
  String get paywallPricePerMonth => '/mes';

  @override
  String get paywallFeatureTop => 'Top';

  @override
  String get arbitrageOptionFullRente => '100 % Renta';

  @override
  String get arbitrageOptionFullCapital => '100 % Capital';

  @override
  String get arbitrageOptionMixed =>
      'Mixto (renta oblig. + capital sobreoblig.)';

  @override
  String get arbitrageOptionAmortIndirect => 'Amortización indirecta';

  @override
  String get arbitrageOptionInvestLibre => 'Inversión libre';

  @override
  String get tornadoLabelRendementCapital => 'Rendimiento de tu capital';

  @override
  String get tornadoLabelTauxRetrait => 'Retiro anual de capital';

  @override
  String get tornadoLabelConversionOblig => 'Conversión LPP obligatoria';

  @override
  String get tornadoLabelConversionSurob => 'Conversión LPP sobreoblig.';

  @override
  String get tornadoLabelRendementMarche => 'Rendimiento de tus inversiones';

  @override
  String get tornadoLabelTauxMarginal => 'Tu tipo impositivo';

  @override
  String get tornadoLabelRendement3a => 'Rendimiento de tu 3er pilar';

  @override
  String get tornadoLabelRendementLpp => 'Rendimiento de tu fondo LPP';

  @override
  String get tornadoLabelTauxHypothecaire => 'Tipo hipotecario';

  @override
  String get tornadoLabelAppreciationImmo => 'Revalorización inmobiliaria';

  @override
  String get tornadoLabelLoyerMensuel => 'Alquiler mensual';

  @override
  String get tornadoLabelTauxImpotCapital => 'Tipo impositivo sobre el capital';

  @override
  String get tornadoLabelAgeRetraite => 'Edad de jubilación';

  @override
  String get tornadoLabelCapitalTotal => 'Capital total';

  @override
  String get tornadoLabelAnneesAvantRetraite => 'Años antes de la jubilación';

  @override
  String get tornadoLabelBas => 'Bajo';

  @override
  String get tornadoLabelHaut => 'Alto';

  @override
  String get educationalLearnMoreStressCheck =>
      'Tu estrés financiero, explicado claramente';

  @override
  String get educationalLearnMoreLpp => 'Entender el 2º pilar (LPP)';

  @override
  String get educationalLearnMoreTroisA => 'El 3er pilar en detalle';

  @override
  String get educationalLearnMoreMortgage => 'Tipos de hipotecas en Suiza';

  @override
  String get educationalLearnMoreCredit => 'Crédito al consumo';

  @override
  String get educationalLearnMoreLeasing => 'Leasing vs compra';

  @override
  String get educationalLearnMoreEmergency =>
      '¿Por qué un fondo de emergencia?';

  @override
  String get educationalLearnMoreCivilStatus =>
      'Estado civil y finanzas en Suiza';

  @override
  String get educationalLearnMoreEmployment =>
      'Estatus profesional y jubilación';

  @override
  String get educationalLearnMoreHousing => '¿Alquilar o ser propietario?';

  @override
  String get educationalLearnMoreCanton => 'Fiscalidad cantonal en Suiza';

  @override
  String get educationalLearnMoreLppBuyback => 'Rescate LPP, ¿cómo funciona?';

  @override
  String get educationalLearnMoreTroisaCount => 'Estrategia multi-cuenta 3a';

  @override
  String get educationalLearnMoreInvestments =>
      'Inversiones y fiscalidad suiza';

  @override
  String get educationalLearnMoreRealEstate =>
      'Financiar una compra inmobiliaria';

  @override
  String get capMissingPieceHeadline => 'Falta una pieza';

  @override
  String capMissingPieceWhyNow(String label) {
    return '$label — sin este dato, tu proyección sigue siendo imprecisa.';
  }

  @override
  String capMissingPieceExpectedImpact(String impact) {
    return '+$impact puntos de confianza';
  }

  @override
  String capMissingPieceConfidenceLabel(String score) {
    return 'confianza $score %';
  }

  @override
  String get capDebtHeadline => 'Tu deuda pesa';

  @override
  String get capDebtWhyNow =>
      'Pagar primero el tipo más alto libera margen cada mes.';

  @override
  String get capDebtCtaLabel => 'Ver mi plan';

  @override
  String get capDebtExpectedImpact => 'margen a recuperar';

  @override
  String get capIndepNoLppHeadline => 'Tu 2.o pilar : CHF 0';

  @override
  String get capIndepNoLppWhyNow =>
      'Sin LPP, tu jubilación = AVS solo. Una red voluntaria cambia la trayectoria.';

  @override
  String get capIndepNoLppCtaLabel => 'Construir mi red';

  @override
  String get capIndepNoLppExpectedImpact => 'jubilación reforzada';

  @override
  String get capDisabilityGapHeadline => 'Tu red de invalidez : solo AI';

  @override
  String get capDisabilityGapWhyNow =>
      'Sin LPP, tu cobertura de invalidez se limita a la AI. La brecha puede sorprender.';

  @override
  String get capDisabilityGapCtaLabel => 'Ver la brecha';

  @override
  String get capDisabilityGapExpectedImpact => 'entender la brecha ~70 %';

  @override
  String get cap3aHeadline => 'Este año aún cuenta';

  @override
  String get cap3aWhyNow =>
      'Una aportación 3a puede reducir tus impuestos y reforzar tu jubilación.';

  @override
  String get cap3aCtaLabel => 'Simular mi 3a';

  @override
  String get capLppBuybackHeadline => 'Rescate LPP disponible';

  @override
  String capLppBuybackWhyNow(String amount) {
    return 'Puedes rescatar hasta $amount y deducirlo de tus impuestos.';
  }

  @override
  String get capLppBuybackCtaLabel => 'Simular un rescate';

  @override
  String get capLppBuybackExpectedImpact => 'deducción fiscal';

  @override
  String get capBudgetDeficitHeadline => 'Tu margen a recuperar';

  @override
  String get capBudgetDeficitWhyNow =>
      'Tu presupuesto está ajustado. Ajustar una partida puede darte respiro.';

  @override
  String get capBudgetDeficitCtaLabel => 'Ajustar mi presupuesto';

  @override
  String get capBudgetDeficitExpectedImpact => 'margen mensual';

  @override
  String get capReplacementRateHeadline => 'Tu jubilación aún es justa';

  @override
  String capReplacementRateWhyNow(String rate) {
    return '$rate % de tasa de sustitución. Un rescate o 3a cambia la trayectoria.';
  }

  @override
  String get capReplacementRateCtaLabel => 'Explorar mis escenarios';

  @override
  String get capReplacementRateExpectedImpact => '+4 a +7 puntos';

  @override
  String get capCoverageCheckSeniorHeadline =>
      'Invalidez después de los 50 : ¿un punto ciego ?';

  @override
  String get capCoverageCheckHeadline => 'Tu cobertura merece una revisión';

  @override
  String get capCoverageCheckSeniorWhyNow =>
      'Después de los 50, la brecha entre ingresos y prestaciones AI + LPP puede superar el 40 %. ¿Tu IJM cubre el resto ?';

  @override
  String get capCoverageCheckWhyNow =>
      'IJM, AI, LPP invalidez — verifica que tu red aguanta.';

  @override
  String get capCoverageCheckCtaLabel => 'Verificar';

  @override
  String get capChomageHeadline => 'Asegurar los próximos 90 días';

  @override
  String get capChomageWhyNow =>
      'En paro : tres urgencias — tus derechos AC, el impacto en tu LPP y ajustar tu presupuesto.';

  @override
  String get capChomageCtaLabel => 'Ver mis derechos';

  @override
  String get capChomageExpectedImpact => 'estabilización inmediata';

  @override
  String get capDivorceUrgencyHeadline => 'Divorcio : aclarar lo que cambia';

  @override
  String get capDivorceUrgencyWhyNow =>
      'Reparto LPP, pensión alimenticia, vivienda — los impactos financieros merecen una valoración clara.';

  @override
  String get capDivorceUrgencyCtaLabel => 'Simular el impacto';

  @override
  String get capDivorceUrgencyExpectedImpact => 'aclaración LPP + impuestos';

  @override
  String get capLeMarriageHeadline => 'Matrimonio en vista';

  @override
  String get capLeMarriageWhyNow =>
      'Impuestos, AVS, LPP, sucesión — todo cambia.';

  @override
  String get capLeMarriageCtaLabel => 'Ver el impacto';

  @override
  String get capLeDivorceHeadline => 'Divorcio en curso';

  @override
  String get capLeDivorceWhyNow =>
      'Reparto LPP, pensión, impuestos — anticipa.';

  @override
  String get capLeDivorceCtaLabel => 'Simular';

  @override
  String get capLeBirthHeadline => 'Nacimiento previsto';

  @override
  String get capLeBirthWhyNow =>
      'Subsidios, deducciones, presupuesto — prepárate.';

  @override
  String get capLeBirthCtaLabel => 'Ver el impacto';

  @override
  String get capLeHousingPurchaseHeadline => 'Compra inmobiliaria';

  @override
  String get capLeHousingPurchaseWhyNow =>
      'EPL, 3a, hipoteca — todo se juega ahora.';

  @override
  String get capLeHousingPurchaseCtaLabel => 'Simular mi capacidad';

  @override
  String get capLeJobLossHeadline => 'Pérdida de empleo';

  @override
  String get capLeJobLossWhyNow => 'Paro, LPP, presupuesto — las 3 urgencias.';

  @override
  String get capLeJobLossCtaLabel => 'Ver mis derechos';

  @override
  String get capLeSelfEmploymentHeadline => 'Paso a la autonomía';

  @override
  String get capLeSelfEmploymentWhyNow =>
      'LPP voluntario, máx. 3a, IJM — reconstruye tu red.';

  @override
  String get capLeSelfEmploymentCtaLabel => 'Verificar mi cobertura';

  @override
  String get capLeRetirementHeadline => 'Jubilación en el horizonte';

  @override
  String get capLeRetirementWhyNow =>
      'Capital o renta, disposición, momento — es la hora.';

  @override
  String get capLeRetirementCtaLabel => 'Explorar mis opciones';

  @override
  String get capLeConcubinageHeadline => 'Convivencia';

  @override
  String get capLeConcubinageWhyNow =>
      'Sin tope AVS 150 %, sin reparto LPP automático — anticipa.';

  @override
  String get capLeConcubinageCtaLabel => 'Ver las diferencias';

  @override
  String get capLeDeathOfRelativeHeadline => 'Pérdida de un ser querido';

  @override
  String get capLeDeathOfRelativeWhyNow =>
      'Sucesión, rentas de supervivencia, plazos — lo urgente.';

  @override
  String get capLeDeathOfRelativeCtaLabel => 'Ver los trámites';

  @override
  String get capLeNewJobHeadline => 'Nuevo puesto';

  @override
  String get capLeNewJobWhyNow =>
      'LPP, libre paso, 3a — tres cosas a verificar.';

  @override
  String get capLeNewJobCtaLabel => 'Comparar';

  @override
  String get capLeHousingSaleHeadline => 'Venta inmobiliaria';

  @override
  String get capLeHousingSaleWhyNow =>
      'Plusvalía, reembolso EPL, reinversión — planifica.';

  @override
  String get capLeHousingSaleCtaLabel => 'Ver el impacto';

  @override
  String get capLeInheritanceHeadline => 'Herencia recibida';

  @override
  String get capLeInheritanceWhyNow =>
      'Impuestos, integración al patrimonio, rescate LPP — valora.';

  @override
  String get capLeInheritanceCtaLabel => 'Ver mis opciones';

  @override
  String get capLeDonationHeadline => 'Donación planeada';

  @override
  String get capLeDonationWhyNow =>
      'Adelanto de herencia, fiscalidad, informe — anticipa.';

  @override
  String get capLeDonationCtaLabel => 'Ver el impacto';

  @override
  String get capLeDisabilityHeadline => 'Riesgo de invalidez';

  @override
  String get capLeDisabilityWhyNow =>
      'AI, LPP invalidez, IJM — verifica tu red.';

  @override
  String get capLeDisabilityCtaLabel => 'Verificar mi cobertura';

  @override
  String get capLeCantonMoveHeadline => 'Cambio de cantón';

  @override
  String get capLeCantonMoveWhyNow =>
      'Impuestos, LAMal, cargas — el impacto puede sorprender.';

  @override
  String get capLeCantonMoveCtaLabel => 'Comparar cantones';

  @override
  String get capLeCountryMoveHeadline => 'Salida de Suiza';

  @override
  String get capLeCountryMoveWhyNow =>
      'Libre paso, AVS, 3a — lo que te sigue, lo que se queda.';

  @override
  String get capLeCountryMoveCtaLabel => 'Ver las consecuencias';

  @override
  String get capLeDebtCrisisHeadline => 'Situación de deuda';

  @override
  String get capLeDebtCrisisWhyNow =>
      'Priorizar, reestructurar, proteger lo esencial — paso a paso.';

  @override
  String get capLeDebtCrisisCtaLabel => 'Ver mi plan';

  @override
  String get capCouple3aHeadline => 'Juntos, una palanca más';

  @override
  String get capCouple3aWhyNow =>
      'Vuestro hogar puede deducir 2 × 7’258 CHF si cada uno aporta al 3a. La cuenta de tu pareja aún no está registrada.';

  @override
  String get capCouple3aCtaLabel => 'Simular el 3a de pareja';

  @override
  String get capCouple3aExpectedImpact => 'hasta 14’516 CHF en deducciones';

  @override
  String get capCoupleLppBuybackHeadline =>
      'Rescate LPP : la palanca de pareja';

  @override
  String capCoupleLppBuybackWhyNow(String amount) {
    return 'Tu pareja tiene un rescate posible de $amount. Priorizar el tipo marginal más alto maximiza la deducción.';
  }

  @override
  String get capCoupleLppBuybackCtaLabel => 'Comparar rescates';

  @override
  String get capCoupleLppBuybackExpectedImpact =>
      'optimización fiscal del hogar';

  @override
  String get capCoupleAvsCapHeadline => 'AVS de pareja : el límite del 150 %';

  @override
  String get capCoupleAvsCapWhyNow =>
      'Casados, vuestras rentas AVS acumuladas están limitadas al 150 % de la renta máxima (LAVS art. 35). La diferencia puede llegar a ~10’000 CHF/año.';

  @override
  String get capCoupleAvsCapCtaLabel => 'Ver el impacto AVS';

  @override
  String get capCoupleAvsCapExpectedImpact => 'entender el delta ~10k/año';

  @override
  String get capHonestyDebtHeadline => 'Tu situación merece una mirada experta';

  @override
  String get capHonestyDebtWhyNow =>
      'Las palancas clásicas no son suficientes aquí. Un especialista en deudas puede ayudarte a construir un plan realista.';

  @override
  String get capHonestryCrossBorderHeadline => 'Hagamos balance juntos';

  @override
  String get capHonestryCrossBorderWhyNow =>
      'En tu horizonte, las palancas del 2.o pilar son limitadas. Un especialista fronterizo puede identificar vías que MINT aún no cubre.';

  @override
  String get capHonestyNoLppHeadline => 'Tu base está ahí';

  @override
  String get capHonestyNoLppWhyNow =>
      'Las palancas clásicas no cambian mucho el panorama aquí. Un especialista puede ayudarte a ver más lejos.';

  @override
  String get capHonestyCtaLabel => 'Hablar con el coach';

  @override
  String get capHonestyExpectedImpact => 'aclaración';

  @override
  String capAcquiredAvsWithRente(String rente, String years) {
    return 'AVS : ~$rente CHF/mes ($years años cotizados)';
  }

  @override
  String capAcquiredAvsYearsOnly(String years) {
    return 'AVS : $years años cotizados';
  }

  @override
  String get capAcquiredAvsInProgress => 'AVS : derechos en curso';

  @override
  String capAcquiredLpp(String amount) {
    return 'LPP : $amount acumulado';
  }

  @override
  String capAcquired3a(String amount) {
    return '3a : $amount ahorrado';
  }

  @override
  String get capFallbackHeadline => 'Completa tu perfil';

  @override
  String get capFallbackWhyNow =>
      'Cuanto más conoce MINT, más precisas son las palancas.';

  @override
  String get capFallbackCtaLabel => 'Enriquecer';

  @override
  String get pulseIndepLppTitle => 'CHF 0';

  @override
  String get pulseIndepLppSubtitle => 'Ese es tu 2.o pilar hoy.';

  @override
  String get pulseIndepLppDetail =>
      'Sin LPP, tu jubilación = AVS solo : ~CHF 1’934/mes.';

  @override
  String get pulseIndepLppCta => 'Construir mi red';

  @override
  String get pulseDebtSubtitle => 'de deuda a reembolsar.';

  @override
  String get pulseDebtCta => 'Ver mi plan';

  @override
  String get pulseComprSalaireSubtitle =>
      'desaparecen de tu salario antes de llegar.';

  @override
  String get pulseComprSalaireDetail =>
      'AVS, LPP, AC, impuestos — descubre a dónde va cada franco.';

  @override
  String get pulseComprSalaireCta => 'Entender mi nómina';

  @override
  String get pulseComprSystemeTitle => '3 pilares';

  @override
  String get pulseComprSystemeSubtitle => 'El sistema suizo en 1 minuto.';

  @override
  String get pulseComprSystemeDetail =>
      'AVS (Estado) + LPP (empleador) + 3a (tú) = tu jubilación.';

  @override
  String get pulseComprSystemeCta => 'Descubrir';

  @override
  String get pulseComprSituationTitle => 'Tu visibilidad financiera';

  @override
  String get pulseComprSituationSubtitle =>
      '¿Qué sabes realmente de tu situación ?';

  @override
  String get pulseComprSituationDetail =>
      'Completa tu perfil para afinar tu puntuación.';

  @override
  String get pulseComprSituationCta => 'Ver mi puntuación';

  @override
  String get pulseProtRetraiteCapRenteTitle => '¿Capital o Renta ?';

  @override
  String get pulseProtRetraiteCapRenteSubtitle =>
      'La elección que cambia todo.';

  @override
  String get pulseProtRetraiteCapRenteDetail =>
      'Compara ambas opciones con tus cifras reales.';

  @override
  String get pulseProtRetraiteCapRenteCta => 'Comparar';

  @override
  String get pulseProtRetraiteSubtitle => 'conservado en la jubilación.';

  @override
  String get pulseProtRetraiteDetail => 'Mediana suiza : 60 %. ¿Dónde estás ?';

  @override
  String get pulseProtRetraiteCta => 'Ver mi proyección';

  @override
  String get pulseProtFamilleSubtitle => 'Vuestra jubilación a dos.';

  @override
  String get pulseProtFamilleDetail =>
      'Anticipa el bache cuando solo uno está jubilado.';

  @override
  String get pulseProtFamilleCta => 'Ver la línea de tiempo';

  @override
  String get pulseProtUrgenceDebtSubtitle => 'a reembolsar.';

  @override
  String get pulseProtUrgenceDebtDetail => 'Empieza por el tipo más alto.';

  @override
  String get pulseProtUrgenceDebtCta => 'Mi plan de reembolso';

  @override
  String get pulseProtUrgenceTitle => 'Tu red de seguridad';

  @override
  String get pulseProtUrgenceSubtitle => '¿Qué pasa si ya no puedes trabajar ?';

  @override
  String get pulseProtUrgenceDetail =>
      'IJM, AI, LPP invalidez — verifica tu cobertura.';

  @override
  String get pulseProtUrgenceCta => 'Verificar';

  @override
  String get pulseOptFiscalSubtitle => 'dejados al fisco cada año.';

  @override
  String get pulseOptFiscalDetail =>
      '3a + rescate LPP = tus palancas más potentes.';

  @override
  String get pulseOptFiscalCta => 'Recuperar';

  @override
  String get pulseOptPatrimoineSubtitle => 'Tu patrimonio total.';

  @override
  String get pulseOptPatrimoineDetail => 'Ahorro + LPP + 3a + inversiones.';

  @override
  String get pulseOptPatrimoineCtaLabel => 'Detalle';

  @override
  String get pulseOptCapRenteTitle => '¿Capital o Renta ?';

  @override
  String get pulseOptCapRenteSubtitle =>
      'La diferencia puede superar CHF 200’000.';

  @override
  String get pulseOptCapRenteDetail =>
      'Tributado una vez (capital) vs cada año (renta).';

  @override
  String get pulseOptCapRenteCta => 'Comparar';

  @override
  String get pulseNavExpatGapsSubtitle => 'de cotizaciones faltan en tu AVS.';

  @override
  String get pulseNavExpatGapsDetail =>
      'Cada año faltante = -2.3 % de renta de por vida.';

  @override
  String get pulseNavExpatGapsCta => 'Analizar mis lagunas';

  @override
  String get pulseNavExpatTitle => '¿Nuevo en Suiza ?';

  @override
  String get pulseNavExpatSubtitle =>
      'Tus derechos, tus lagunas, tus trampas a evitar.';

  @override
  String get pulseNavExpatDetail =>
      'AVS, LPP, 3a — todo lo que cuenta desde la llegada.';

  @override
  String get pulseNavExpatCta => 'Descubrir';

  @override
  String get pulseNavAchatTitle => 'Comprar un bien';

  @override
  String get pulseNavAchatSubtitle => 'Calcula tu capacidad de compra.';

  @override
  String get pulseNavAchatDetail => 'Tu 3a y tu LPP = tu principal entrada.';

  @override
  String get pulseNavAchatCta => 'Simular';

  @override
  String get pulseNavAchatCapSubtitle => 'El bien que podrías comprar.';

  @override
  String get pulseNavAchatCapCta => 'Simular mi compra';

  @override
  String get pulseNavIndependantTitle => '¿Autónomo§a ?';

  @override
  String get pulseNavIndependantSubtitle => 'Sin empleador, tu red = tú.';

  @override
  String get pulseNavIndependantDetail =>
      'LPP voluntario, máx. 3a 36’288/año, IJM obligatorio.';

  @override
  String get pulseNavIndependantCta => 'Verificar mi cobertura';

  @override
  String get pulseNavEvenementTitle => '¿Un cambio de vida ?';

  @override
  String get pulseNavEvenementSubtitle =>
      'Cada evento tiene un impacto financiero.';

  @override
  String get pulseNavEvenementDetail =>
      'Matrimonio, nacimiento, divorcio, herencia, mudanza...';

  @override
  String get pulseNavEvenementCta => 'Explorar';

  @override
  String get reengagementTitleNewYear => 'Nuevos límites del 3a';

  @override
  String get reengagementTitleTaxPrep => 'Declaración fiscal';

  @override
  String get reengagementTitleTaxDeadline => 'Fecha límite fiscal';

  @override
  String get reengagementTitleThreeA => 'Fecha límite 3a';

  @override
  String get reengagementTitleThreeAFinal => 'Último mes para el 3a';

  @override
  String get reengagementTitleQuarterlyFri => 'Puntuación de solidez';

  @override
  String get assurancesAlerteDelai =>
      'Recordatorio : los cambios de franquicia deben realizarse antes del 30 de noviembre de cada año para el año siguiente.';

  @override
  String get assurancesDisclaimerLamal =>
      'Este análisis es indicativo. Las primas varían según el asegurador, la región y el modelo de seguro. Consulte a su caja de salud para cifras exactas. Fuente : LAMal art. 62-64, OAMal.';

  @override
  String get assurancesDisclaimerCoverage =>
      'Este análisis es indicativo y no constituye asesoramiento personalizado en seguros. Las primas varían según el asegurador y su perfil. Consulte a un·a especialista para una evaluación completa.';

  @override
  String get recommendationsDisclaimer =>
      'Sugerencias pedagógicas basadas en su perfil — herramienta educativa que no constituye asesoramiento financiero personalizado en el sentido de la LSFin. Consulte a un·a especialista para un análisis adaptado a su situación.';

  @override
  String get recommendationsTitleEmergencyFund =>
      'Constituir un fondo de emergencia';

  @override
  String get recommendationsTitlePillar3a => 'Optimizar con el pilar 3a';

  @override
  String get recommendationsTitleLppBuyback => 'Simular una compra de LPP';

  @override
  String get recommendationsTitleCompoundInterest => 'El poder del tiempo';

  @override
  String get recommendationsTitleStartDiagnostic => 'Inicia tu diagnóstico';

  @override
  String get cantonalBenchmarkDisclaimer =>
      'Estas cifras son órdenes de magnitud derivados de estadísticas federales anonimizadas (OFS). No constituyen asesoramiento financiero. Ningún dato personal se compara con otros usuarios. Herramienta educativa : no constituye asesoramiento en el sentido de la LSFin.';

  @override
  String get scenarioLabelPrudent => 'Escenario prudente';

  @override
  String get scenarioLabelReference => 'Escenario de referencia';

  @override
  String get scenarioLabelFavorable => 'Escenario favorable';

  @override
  String get scenarioDisclaimer =>
      'Herramienta educativa — no constituye asesoramiento financiero en el sentido de la LSFin. Las proyecciones se basan en hipótesis de rendimiento y no predicen resultados futuros. Consulte a un·a especialista para un plan personalizado.';

  @override
  String get bayesianDisclaimer =>
      'Estimaciones bayesianas basadas en estadísticas suizas (OFS/BFS). Estos valores son aproximaciones pedagógicas, no certezas. No constituye asesoramiento financiero en el sentido de la LSFin.';

  @override
  String get consentLabelByok => 'Personalización con IA';

  @override
  String get consentLabelSnapshot => 'Historial de progreso';

  @override
  String get consentLabelNotifications => 'Recordatorios personalizados';

  @override
  String get consentDashboardDisclaimer =>
      'Tus datos te pertenecen. Cada parámetro es revocable en cualquier momento (nLPD art. 6).';

  @override
  String get wizardValidationRequired => 'Esta pregunta es obligatoria';

  @override
  String get wizardAnswerNotProvided => 'No proporcionado';

  @override
  String get arbitrageTitleRenteVsCapital => 'Renta vs Capital';

  @override
  String get arbitrageMissingLpp =>
      'Añade tu saldo de fondo de pensiones para ver esta comparación';

  @override
  String get arbitrageTitleCalendrierRetraits => 'Calendario de retiros';

  @override
  String get arbitrageMissingLppAnd3a =>
      'Añade tu saldo de fondo de pensiones y 3a para ver el calendario';

  @override
  String get arbitrageTitleRachatVsMarche => 'Recompra LPP vs Mercado';

  @override
  String get arbitrageMissingLppCertificat =>
      'Escanea tu certificado LPP para conocer tu margen de recompra';

  @override
  String get reportTitleBilanFlash => 'Tu Resumen Financiero';

  @override
  String get reportLabelSanteFinanciere => 'Salud Financiera';

  @override
  String get retirementProjectionDisclaimer =>
      'Proyección educativa basada en las tarifas AVS/LPP 2025. No constituye asesoramiento financiero ni de previsión. Los importes son estimaciones que pueden variar según los cambios legislativos y su situación personal. Consulte a un especialista para un plan personalizado. LSFin.';

  @override
  String get retirementIncomeLabelPillar3a => '3er pilar';

  @override
  String get retirementIncomeLabelPatrimoine => 'Patrimonio libre';

  @override
  String get retirementPhaseLabelBothRetired => 'Ambos jubilados';

  @override
  String get retirementPhaseLabelRetraite => 'Jubilación';

  @override
  String get forecasterDisclaimer =>
      'Proyecciones educativas basadas en supuestos de rentabilidad. No constituye asesoramiento financiero. Los rendimientos pasados no predicen los futuros. Consulte a un especialista para un plan personalizado. LSFin.';

  @override
  String get forecasterEtSiDisclaimer =>
      'Simulación «Y si...» solo con fines educativos. Supuestos de rentabilidad ajustados manualmente. No constituye asesoramiento financiero (LSFin). Los rendimientos pasados no predicen los futuros.';

  @override
  String get lppRachatDisclaimerEchelonne =>
      'Simulación educativa basada en tipos impositivos cantonales estimados. La recompra LPP está sujeta a la aprobación del fondo de pensiones. La deducción anual está limitada a los ingresos gravables. Bloqueo EPL de 3 años tras cada recompra (LPP art. 79b al. 3). Consulte a su fondo de pensiones y a un especialista antes de cualquier decisión.';

  @override
  String get lppLibrePassageDisclaimer =>
      'Esta información es educativa y no constituye asesoramiento jurídico o financiero personalizado. Las normas dependen de su fondo de pensiones y situación. Base legal: LFLP, OLP. Consulte a un especialista en previsión profesional.';

  @override
  String get lppEplDisclaimer =>
      'Simulación educativa de carácter orientativo. El importe exacto retirable depende del reglamento de su fondo de pensiones y su saldo a los 50 años. El impuesto varía según el cantón y la situación personal. Base legal: art. 30c LPP, OEPL. Consulte a su fondo de pensiones y a un especialista antes de cualquier decisión.';

  @override
  String get lppChecklistTitleDecompte => 'Solicitar un estado de salida';

  @override
  String get lppChecklistDescDecompte =>
      'Solicite un estado detallado a su fondo de pensiones con el desglose obligatorio/suplementario.';

  @override
  String get lppChecklistTitleTransfert30j => 'Transferir su saldo en 30 días';

  @override
  String get lppChecklistDescTransfert30j =>
      'El saldo debe transferirse al nuevo fondo de pensiones. Facilite los datos del nuevo fondo al antiguo.';

  @override
  String get lppChecklistAlertTransfertTitle =>
      'Plazo de transferencia próximo';

  @override
  String get lppChecklistAlertTransfertMsg =>
      'El saldo debe transferirse en 30 días. Contacte a su antiguo fondo de pensiones rápidamente.';

  @override
  String get lppChecklistTitleOuvrirLP => 'Abrir una cuenta de libre paso';

  @override
  String get lppChecklistDescOuvrirLP =>
      'Sin nuevo empleador, su saldo debe depositarse en una o dos cuentas de libre paso (máx. 2 según la ley).';

  @override
  String get lppChecklistTitleChoisirLP =>
      'Elegir entre cuenta bancaria y póliza de libre paso';

  @override
  String get lppChecklistDescChoisirLP =>
      'La cuenta bancaria ofrece más flexibilidad. La póliza de seguro puede incluir cobertura de riesgo.';

  @override
  String get lppChecklistTitleVerifierDestination =>
      'Verificar las normas de retiro según el país de destino';

  @override
  String get lppChecklistDescVerifierDestination =>
      'UE/AELE: solo la parte suplementaria puede retirarse en efectivo. La parte obligatoria permanece en Suiza. Fuera de UE/AELE: retiro total posible.';

  @override
  String get lppChecklistTitleAnnoncerDepart =>
      'Notificar su salida al fondo de pensiones';

  @override
  String get lppChecklistDescAnnoncerDepart =>
      'Informe a su fondo en los 30 días siguientes a su partida.';

  @override
  String get lppChecklistAlertTransfert6mTitle =>
      'Transferencia a realizar en 6 meses';

  @override
  String get lppChecklistAlertTransfert6mMsg =>
      'Tras salir de Suiza, dispone de 6 meses para transferir su saldo o abrir una cuenta de libre paso.';

  @override
  String get lppChecklistTitleChomage => 'Verificar sus derechos al desempleo';

  @override
  String get lppChecklistDescChomage =>
      'En caso de desempleo, su previsión profesional continúa a través de la institución supletoria (Fundación LPP).';

  @override
  String get lppChecklistTitleAvoirs => 'Buscar saldos olvidados';

  @override
  String get lppChecklistDescAvoirs =>
      'Utilice la Central del 2° pilar (sfbvg.ch) para buscar posibles saldos de libre paso olvidados.';

  @override
  String get lppChecklistTitleCouverture =>
      'Verificar la cobertura de riesgo transitoria';

  @override
  String get lppChecklistDescCouverture =>
      'Durante el período de libre paso, la cobertura de fallecimiento e invalidez puede reducirse. Compruebe sus contratos.';

  @override
  String get pillar3aStaggeredDisclaimer =>
      'Simulación educativa de carácter orientativo. El impuesto sobre el retiro de capital depende del cantón, el municipio, la situación personal y el total retirado en el año fiscal. Los tipos utilizados son medias cantonales simplificadas. Base legal: OPP3, LIFD art. 38. Consulte a un especialista antes de cualquier decisión.';

  @override
  String get pillar3aRealReturnDisclaimer =>
      'Simulación educativa basada en supuestos de rentabilidad constante. Los rendimientos pasados no predicen los futuros. Las comisiones y rendimientos varían según el proveedor. El ahorro fiscal depende de su tipo marginal real. Base legal: OPP3, LIFD art. 33 al. 1 let. e. Consulte a un especialista antes de cualquier decisión.';

  @override
  String get pillar3aProviderDisclaimer =>
      'Los rendimientos pasados no predicen los futuros. Las comisiones y rendimientos medios se basan en datos históricos simplificados con fines educativos. La elección de un proveedor 3a depende de su situación personal, perfil de riesgo y horizonte de inversión. MINT no es un intermediario financiero y no proporciona asesoramiento de inversión. Consulte a un especialista.';

  @override
  String get reportDisclaimerBase1 =>
      'Herramienta educativa — no constituye asesoramiento financiero en el sentido de la LSFin.';

  @override
  String get reportDisclaimerBase2 =>
      'Los importes son estimaciones basadas en los datos declarados.';

  @override
  String get reportDisclaimerBase3 =>
      'Los resultados pasados no predicen los resultados futuros.';

  @override
  String get reportDisclaimerFiscal =>
      'La estimación fiscal es aproximada y no reemplaza una declaración de impuestos.';

  @override
  String get reportDisclaimerRetraite =>
      'La proyección de jubilación es orientativa y depende de los cambios legislativos (reformas AVS/LPP).';

  @override
  String get reportDisclaimerRachatLpp =>
      'La recompra LPP está sujeta a un bloqueo de 3 años para los retiros EPL (LPP art. 79b al. 3).';

  @override
  String get reportActionTitle3aFirst => 'Abre tu primer 3a';

  @override
  String get reportActionDesc3aFirst =>
      'Deduce hasta CHF 7’258/año de tu renta gravable. Ahorro inmediato.';

  @override
  String get reportActionTitle3aSecond => 'Abre una 2ª cuenta 3a fintech';

  @override
  String get reportActionDesc3aSecond =>
      'Optimiza tu fiscalidad al retirar y diversifica tus inversiones.';

  @override
  String get reportActionTitleAvsCheck => 'Verifica tu cuenta AVS';

  @override
  String get reportActionDescAvsCheck =>
      'Evita perder hasta CHF 38’000 de pensión de por vida.';

  @override
  String get reportActionTitleDette => 'Reembolsa tus deudas de consumo';

  @override
  String get reportActionDescDette =>
      'Es la inversión más rentable: ahorras 6-10 % al año en intereses.';

  @override
  String get reportActionTitleUrgence => 'Crea tu fondo de emergencia';

  @override
  String get reportActionDescUrgence =>
      'Apunta a 3 meses de gastos en una cuenta de ahorro separada.';

  @override
  String get reportRoadmapPhaseImmediat => 'Inmediato';

  @override
  String get reportRoadmapTimeframeImmediat => 'Este mes';

  @override
  String get reportRoadmapPhaseCourtTerme => 'Corto Plazo';

  @override
  String get reportRoadmapTimeframeCourtTerme => '3-6 meses';

  @override
  String get visibilityNarrativeHigh =>
      'Tienes una visión clara de tu situación. Mantén tus datos actualizados.';

  @override
  String visibilityNarrativeMediumHigh(String axisLabel) {
    return '¡Buena visibilidad! Afina tu $axisLabel para ir más lejos.';
  }

  @override
  String visibilityNarrativeMedium(String axisLabel) {
    return 'Empiezas a ver con más claridad. Concéntrate en tu $axisLabel.';
  }

  @override
  String visibilityNarrativeLow(String hint) {
    return 'Cada información cuenta. Empieza por $hint.';
  }

  @override
  String get visibilityAxisLabelLiquidite => 'Liquidez';

  @override
  String get visibilityAxisLabelFiscalite => 'Fiscalidad';

  @override
  String get visibilityAxisLabelRetraite => 'Jubilación';

  @override
  String get visibilityAxisLabelSecurite => 'Seguridad';

  @override
  String get visibilityHintAddSalaire => 'Añade tu salario para empezar';

  @override
  String get visibilityHintAddEpargne => 'Indica tus ahorros e inversiones';

  @override
  String get visibilityHintLiquiditeComplete =>
      'Tus datos de liquidez están completos';

  @override
  String get visibilityHintAddAgeCanton =>
      'Indica tu edad y cantón de residencia';

  @override
  String get visibilityHintScanFiscal => 'Escanea tu declaración fiscal';

  @override
  String get visibilityHintFiscaliteComplete =>
      'Tus datos fiscales están completos';

  @override
  String get visibilityHintAddLpp => 'Añade tu certificado LPP';

  @override
  String get visibilityHintCommandeAvs => 'Solicita tu extracto AVS';

  @override
  String get visibilityHintAdd3a => 'Indica tus cuentas 3a';

  @override
  String get visibilityHintRetraiteComplete =>
      'Tus datos de jubilación están completos';

  @override
  String get visibilityHintAddFamille => 'Indica tu situación familiar';

  @override
  String get visibilityHintAddStatutPro => 'Completa tu estado profesional';

  @override
  String get visibilityHintSecuriteComplete =>
      'Tus datos de seguridad están completos';

  @override
  String get exploreHubRetraiteIntro =>
      'Cada año que pasa cambia tus opciones. Aquí estás.';

  @override
  String get exploreHubFamilleIntro =>
      'Matrimonio, nacimiento, separación: cada hito tiene un impacto financiero.';

  @override
  String get exploreHubTravailIntro =>
      'Tu estado profesional determina tus derechos. Verifícalos.';

  @override
  String get exploreHubLogementIntro =>
      'Comprar, alquilar, mudarse: los números antes de la decisión.';

  @override
  String get exploreHubFiscaliteIntro =>
      'Cada franco deducido es un franco ganado. Encuentra tus palancas.';

  @override
  String get exploreHubPatrimoineIntro =>
      'Lo que transmites merece tanta atención como lo que ganas.';

  @override
  String get exploreHubSanteIntro =>
      'Tu cobertura te protege — o te cuesta demasiado. Verifícalo.';

  @override
  String get exploreTalkToMint => 'Hablar con MINT';

  @override
  String get dossierSettingsTitle => 'Ajustes';

  @override
  String get dossierEnrichmentHint => 'Para mejorar la precisión:';

  @override
  String get pulseBudgetATitle => 'Hoy';

  @override
  String get pulseBudgetBTitle => 'Al jubilarte';

  @override
  String get pulseBudgetRevenu => 'Ingresos';

  @override
  String get pulseBudgetCharges => 'Gastos';

  @override
  String get pulseBudgetLibre => 'Libre';

  @override
  String get pulseBudgetRetirementNet => 'Neto jubilación';

  @override
  String get pulseBudgetGap => 'Brecha';

  @override
  String get sim3aTaxRateChipsLabel => 'Tasa impositiva marginal';

  @override
  String get sim3aReturnChipsLabel => 'Rendimiento esperado';

  @override
  String get sim3aYearsAutoLabel => 'Años hasta la jubilación';

  @override
  String get sim3aContributionFieldLabel => 'Contribución anual';

  @override
  String get sim3aProfilePreFilled => 'Prellenado desde tu perfil';

  @override
  String sim3aProfileEstimatedRate(String rate, String canton) {
    return 'Tu tasa marginal estimada: $rate% ($canton)';
  }

  @override
  String sim3aYearsReadOnly(int years) {
    return '$years años (calculado desde tu edad)';
  }

  @override
  String get renteVsCapitalRetirementAgeChips => 'Edad de jubilación';

  @override
  String get renteVsCapitalLifeExpectancyChips => 'Esperanza de vida';

  @override
  String get budgetEnvelopeFieldHint => 'Monto en CHF';

  @override
  String get budgetEnvelopeFieldFuture => 'Ahorro futuro (CHF/mes)';

  @override
  String get budgetEnvelopeFieldVariables => 'Gastos variables (CHF/mes)';

  @override
  String get retroactive3aYearsChipsLabel => 'Años a recuperar';

  @override
  String get lightningMenuTitle => '¿Qué quieres explorar?';

  @override
  String get lightningMenuSubtitle => 'MINT calcula, tú decides.';

  @override
  String get lightningMenuRetirementTitle => 'Mi visión de jubilación';

  @override
  String get lightningMenuRetirementSubtitle =>
      'Cuánto conservarás al jubilarte';

  @override
  String get lightningMenuRetirementAction => '¿Cuánto a la jubilación?';

  @override
  String get lightningMenuBudgetTitle => 'Mi presupuesto';

  @override
  String get lightningMenuBudgetSubtitle => 'A dónde va tu dinero este mes';

  @override
  String get lightningMenuBudgetAction => 'Mi presupuesto este mes';

  @override
  String get lightningMenuRenteCapitalTitle => '¿Renta o capital?';

  @override
  String get lightningMenuRenteCapitalSubtitle => 'Comparar ambos escenarios';

  @override
  String get lightningMenuRenteCapitalAction => '¿Renta o capital?';

  @override
  String get lightningMenuScoreTitle => 'Mi puntuación fitness';

  @override
  String get lightningMenuScoreSubtitle => 'Tu salud financiera de un vistazo';

  @override
  String get lightningMenuScoreAction => 'Mi puntuación financiera';

  @override
  String get lightningMenuCoupleTitle => 'Nuestra situación en pareja';

  @override
  String get lightningMenuCoupleSubtitle => 'Previsión y patrimonio en pareja';

  @override
  String get lightningMenuCoupleAction => 'Nuestra previsión en pareja';

  @override
  String get lightningMenuDebtTitle => 'Salir de la deuda';

  @override
  String get lightningMenuDebtSubtitle => 'Un plan para reducir tus cargas';

  @override
  String get lightningMenuDebtAction => '¿Cómo reducir mi deuda?';

  @override
  String get lightningMenuIndependantTitle => 'Mi red de seguridad';

  @override
  String get lightningMenuIndependantSubtitle =>
      'Cobertura y protección como independiente';

  @override
  String get lightningMenuIndependantAction =>
      'Mi cobertura como independiente';

  @override
  String get lightningMenuRetirementPrepTitle => 'Preparar mi jubilación';

  @override
  String get lightningMenuRetirementPrepSubtitle =>
      'Los últimos años cuentan doble';

  @override
  String get lightningMenuRetirementPrepAction => 'Mi plan de jubilación';

  @override
  String get lightningMenuPayslipTitle => 'Entender mi nómina';

  @override
  String get lightningMenuPayslipSubtitle =>
      'Bruto, neto, deducciones: todo claro';

  @override
  String get lightningMenuPayslipAction => 'Explícame mi nómina';

  @override
  String get lightningMenuThreePillarsTitle => '¿Qué son los 3 pilares?';

  @override
  String get lightningMenuThreePillarsSubtitle =>
      'El sistema suizo en 2 minutos';

  @override
  String get lightningMenuThreePillarsAction =>
      '¿Qué son los 3 pilares suizos?';

  @override
  String get lightningMenuScanDocTitle => 'Escanear un documento';

  @override
  String get lightningMenuScanDocSubtitle =>
      'Certificado LPP, nómina, impuestos';

  @override
  String get lightningMenuFirstBudgetTitle => 'Mi primer presupuesto';

  @override
  String get lightningMenuFirstBudgetSubtitle =>
      'Saber a dónde va tu dinero cada mes';

  @override
  String get lightningMenuFirstBudgetAction => 'Ayúdame a hacer mi presupuesto';

  @override
  String get lightningMenuTaxReliefTitle => 'Dónde reducir impuestos';

  @override
  String get lightningMenuTaxReliefSubtitle =>
      'Deducciones y palancas fiscales';

  @override
  String get lightningMenuTaxReliefAction => '¿Cómo pagar menos impuestos?';

  @override
  String get lightningMenuCompleteProfileTitle => 'Completar mi perfil';

  @override
  String get lightningMenuCompleteProfileSubtitle =>
      'Cuanto más preciso, más justo MINT';

  @override
  String get lightningMenuLppBuybackTitle => 'Recomprar LPP';

  @override
  String get lightningMenuLppBuybackSubtitle =>
      'Una palanca fiscal a menudo subestimada';

  @override
  String get lightningMenuLppBuybackAction => '¿Vale la pena una recompra LPP?';

  @override
  String get lightningMenuLivingBudgetTitle => 'Mi presupuesto vivo';

  @override
  String get lightningMenuLivingBudgetSubtitle =>
      'Tu equilibrio este mes, actualizado';

  @override
  String get lightningMenuLivingBudgetAction => '¿Dónde estoy?';

  @override
  String get budgetSnapshotTitle => 'Tu presupuesto vivo';

  @override
  String get budgetSnapshotPresentLabel => 'Libre hoy';

  @override
  String get budgetSnapshotRetirementLabel => 'Libre en la jubilación';

  @override
  String get budgetSnapshotGapLabel => 'Brecha';

  @override
  String get budgetSnapshotConfidenceLabel => 'Fiabilidad';

  @override
  String get budgetSnapshotConfidenceLow => 'Añade datos para afinar.';

  @override
  String get budgetSnapshotConfidenceOk => 'Estimación creíble.';

  @override
  String get budgetSnapshotLeverLabel => 'Palanca';

  @override
  String get budgetSnapshotFreeLabel => 'Tu libre mensual';

  @override
  String get onboardingSmartTitle =>
      'Descubre tu situación de jubilación en 30 segundos';

  @override
  String get onboardingSmartSubtitle =>
      'Unos pocos datos bastan para una primera visión personalizada.';

  @override
  String get onboardingSmartFirstNameLabel => '¿Cómo te llamas?';

  @override
  String get onboardingSmartFirstNameHint => 'Tu nombre (opcional)';

  @override
  String get onboardingSmartAgeDirectInput => 'Entrada directa';

  @override
  String get onboardingSmartSeeResult => 'Ver mi resultado';

  @override
  String get onboardingSmartDisclaimer =>
      'Herramienta educativa — no constituye asesoramiento financiero (LSFin). Las estimaciones se basan en las escalas de 2025 y pueden variar.';

  @override
  String get onboardingSmartAgePickerHint => 'Elige tu edad';

  @override
  String get onboardingSmartCountryOrigin => 'Tu país de origen';

  @override
  String get onboardingSmartCantonTitle => 'Elige tu cantón';

  @override
  String get onboardingSmartCantonNotFound => 'Ningún cantón encontrado';

  @override
  String get onboardingSmartSalaryLabel => 'Tu salario bruto anual';

  @override
  String get onboardingSmartAgeLabel => 'Tu edad';

  @override
  String get onboardingSmartEmploymentLabel => 'Tu situación profesional';

  @override
  String get onboardingSmartNationalityLabel => 'Tu nacionalidad';

  @override
  String get onboardingSmartCantonLabel => 'Tu cantón';

  @override
  String get onboardingAgeInvalid => 'La edad debe estar entre 18 y 75';

  @override
  String get onboardingSmartCantonSearch => 'Buscar (ej. VD, Vaud)';

  @override
  String get onboardingSmartSalaryPerYear => 'CHF/año';

  @override
  String get greetingMorning => 'mañana';

  @override
  String get greetingAfternoon => 'tarde';

  @override
  String get greetingEvening => 'noche';

  @override
  String get authShowPassword => 'Mostrar contraseña';

  @override
  String get authHidePassword => 'Ocultar contraseña';

  @override
  String get exploreHubRetraiteIntro55plus =>
      'La jubilación se acerca: cada decisión cuenta doble. Aquí estás.';

  @override
  String get exploreHubRetraiteIntro40plus =>
      'Cada año que pasa cambia tus opciones. Aquí estás.';

  @override
  String get exploreHubRetraiteIntroYoung =>
      'Está lejos, pero ahora es cuando importa. He aquí por qué.';

  @override
  String get exploreHubTravailIntro55plus =>
      'Fin de carrera, jubilación anticipada, transición: tus derechos cambian.';

  @override
  String get exploreHubTravailIntro40plus =>
      'Tu situación profesional determina tus derechos. Verifícalos.';

  @override
  String get exploreHubTravailIntroYoung =>
      'Primer empleo, autónomo, fronterizo: cada estatus tiene sus reglas.';

  @override
  String get exploreHubLogementIntro55plus =>
      'Quedarse, vender, transmitir: los números antes de la decisión.';

  @override
  String get exploreHubLogementIntro40plus =>
      'Comprar, alquilar, mudarse: los números antes de la decisión.';

  @override
  String get exploreHubLogementIntroYoung =>
      'Primera compra o alquiler: entender las reglas del juego.';

  @override
  String get archetypeSwissNative => 'Residente suizo/a';

  @override
  String get archetypeExpatEu => 'Expat UE/AELC';

  @override
  String get archetypeExpatNonEu => 'Expat fuera de la UE';

  @override
  String get archetypeExpatUs => 'Residente en EE.UU. (FATCA)';

  @override
  String get archetypeIndependentWithLpp => 'Autónomo/a con LPP';

  @override
  String get archetypeIndependentNoLpp => 'Autónomo/a sin LPP';

  @override
  String get archetypeCrossBorder => 'Fronterizo/a';

  @override
  String get archetypeReturningSwiss => 'Suizo/a de regreso';

  @override
  String get employmentSalarie => 'Asalariado/a';

  @override
  String get employmentIndependant => 'Autónomo/a';

  @override
  String get employmentSansEmploi => 'Sin empleo';

  @override
  String get employmentRetraite => 'Jubilado/a';

  @override
  String get nationalitySuisse => 'Suiza';

  @override
  String get nationalityEuAele => 'UE/AELC';

  @override
  String get nationalityAutre => 'Otro';
}
