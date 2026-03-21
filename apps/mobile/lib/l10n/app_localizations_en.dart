// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MINT';

  @override
  String get landingHero => 'Financial OS.';

  @override
  String get landingSubtitle => 'Your Swiss financial copilot.';

  @override
  String get landingBetaBadge => 'Private Beta';

  @override
  String get landingHeroPrefix => 'The first';

  @override
  String get landingSubtitleLong =>
      'A CFO\'s intelligence, in your pocket.\nZero bullshit. Pure advice.';

  @override
  String get landingFeature1Title => 'Instant Diagnostic';

  @override
  String get landingFeature1Desc => '360° analysis in 5 minutes.';

  @override
  String get landingFeature2Title => '100% Private & Local';

  @override
  String get landingFeature2Desc => 'Your data stays on your device.';

  @override
  String get landingFeature3Title => 'Neutral Strategy';

  @override
  String get landingFeature3Desc => 'Zero commission. Zero conflict.';

  @override
  String get landingDiagnosticSubtitle => '360° Review • 5 minutes';

  @override
  String get landingResumeDiagnostic => 'Resume my diagnostic';

  @override
  String get startDiagnostic => 'Start my diagnostic';

  @override
  String get tabNow => 'NOW';

  @override
  String get tabExplore => 'Explore';

  @override
  String get tabTrack => 'TRACK';

  @override
  String get budgetTitle => 'Master my Budget';

  @override
  String get simulatorsTitle => 'Journey Simulators';

  @override
  String get recommendations => 'Your Recommendations';

  @override
  String get disclaimer =>
      'The results presented are estimates for informational purposes only. They do not constitute personalised financial advice.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String onboardingProgress(String step, String total) {
    return 'Step $step of $total';
  }

  @override
  String get onboardingStep1Title => 'Hello, I\'m your mentor.';

  @override
  String get onboardingStep1Subtitle =>
      'Let\'s get acquainted. What is your current situation?';

  @override
  String get onboardingHouseholdSingle => 'Single';

  @override
  String get onboardingHouseholdSingleDesc => 'I manage my finances alone';

  @override
  String get onboardingHouseholdCouple => 'Couple';

  @override
  String get onboardingHouseholdCoupleDesc => 'We share our financial goals';

  @override
  String get onboardingHouseholdFamily => 'Family';

  @override
  String get onboardingHouseholdFamilyDesc => 'With dependent children';

  @override
  String get onboardingHouseholdSingleParent => 'Single parent';

  @override
  String get onboardingHouseholdSingleParentDesc =>
      'I manage alone with dependent child(ren)';

  @override
  String get onboardingStep2Title => 'Very good.';

  @override
  String get onboardingStep2Subtitle =>
      'Which financial journey would you like to embark on first?';

  @override
  String get onboardingGoalHouse => 'Become a homeowner';

  @override
  String get onboardingGoalHouseDesc => 'Prepare my deposit and mortgage';

  @override
  String get onboardingGoalRetire => 'Retirement Serenity';

  @override
  String get onboardingGoalRetireDesc => 'Maximise my long-term future';

  @override
  String get onboardingGoalInvest => 'Invest & Grow';

  @override
  String get onboardingGoalInvestDesc => 'Grow my savings intelligently';

  @override
  String get onboardingGoalTaxOptim => 'Tax Optimisation';

  @override
  String get onboardingGoalTaxOptimDesc => 'Reduce my taxes legally';

  @override
  String get onboardingStep3Title => 'Almost there.';

  @override
  String get onboardingStep3Subtitle =>
      'These details allow us to personalise your calculations according to Swiss law.';

  @override
  String get onboardingCantonLabel => 'Canton of residence';

  @override
  String get onboardingCantonHint => 'Select your canton';

  @override
  String get onboardingBirthYearLabel => 'Year of birth (optional)';

  @override
  String get onboardingBirthYearHint => 'E.g.: 1990';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingStep4Title => 'Ready to start?';

  @override
  String get onboardingStep4Subtitle =>
      'Mint is a safe environment. Here are our commitments to you.';

  @override
  String get onboardingTrustTransparency => 'Total transparency';

  @override
  String get onboardingTrustTransparencyDesc => 'All assumptions are visible.';

  @override
  String get onboardingTrustPrivacy => 'Privacy';

  @override
  String get onboardingTrustPrivacyDesc =>
      'Local calculations, no storage of sensitive data.';

  @override
  String get onboardingTrustSecurity => 'Security';

  @override
  String get onboardingTrustSecurityDesc => 'No direct access to your money.';

  @override
  String get onboardingEnterSpace => 'Enter my space';

  @override
  String get advisorMiniStep1Title => 'What is your priority?';

  @override
  String get advisorMiniStep1Subtitle =>
      'MINT adapts to what matters most to you right now';

  @override
  String get advisorMiniFirstNameLabel => 'First name (optional)';

  @override
  String get advisorMiniFirstNameHint => 'First name';

  @override
  String get advisorMiniStressBudget => 'Master my budget';

  @override
  String get advisorMiniStressDebt => 'Reduce my debt';

  @override
  String get advisorMiniStressTax => 'Optimize my taxes';

  @override
  String get advisorMiniStressRetirement => 'Secure my retirement';

  @override
  String advisorMiniResumeDiagnostic(String progress) {
    return 'Resume my diagnostic ($progress%)';
  }

  @override
  String get advisorMiniFullDiagnostic => 'Full diagnostic (10 min)';

  @override
  String get advisorMiniStep2Title => 'Essentials';

  @override
  String get advisorMiniStep2Subtitle =>
      'Age and canton change everything in Switzerland';

  @override
  String get advisorMiniBirthYearLabel => 'Year of birth';

  @override
  String get advisorMiniBirthYearInvalid => 'Invalid year';

  @override
  String advisorMiniBirthYearRange(String maxYear) {
    return 'Between 1940 and $maxYear';
  }

  @override
  String get advisorMiniCantonLabel => 'Canton of residence';

  @override
  String get advisorMiniCantonHint => 'Select';

  @override
  String get advisorMiniStep3Title => 'Your income';

  @override
  String get advisorMiniStep3Subtitle => 'To estimate your savings potential';

  @override
  String get advisorMiniIncomeLabel => 'Monthly net income (CHF)';

  @override
  String get advisorMiniHousingTitle => 'Housing';

  @override
  String get advisorMiniHousingTenant => 'Tenant';

  @override
  String get advisorMiniHousingOwner => 'Owner';

  @override
  String get advisorMiniHousingHosted => 'Hosted / no rent';

  @override
  String get advisorMiniHousingCostTenant => 'Rent / housing charges / month';

  @override
  String get advisorMiniHousingCostOwner => 'Housing costs / mortgage / month';

  @override
  String get advisorMiniDebtPaymentsLabel =>
      'Debt / leasing repayments / month';

  @override
  String get advisorMiniPatrimonyTitle => 'Assets (optional)';

  @override
  String get advisorMiniCashSavingsLabel => 'Cash / available savings';

  @override
  String get advisorMiniInvestmentsTotalLabel =>
      'Investments (stocks, ETFs, funds)';

  @override
  String get advisorMiniPillar3aTotalLabel => 'Approximate pillar 3a total';

  @override
  String get advisorMiniCivilStatusLabel => 'Couple\'s civil status';

  @override
  String get advisorMiniCivilStatusMarried => 'Married';

  @override
  String get advisorMiniCivilStatusConcubinage => 'Cohabiting';

  @override
  String get advisorMiniPartnerIncomeLabel => 'Partner monthly net income';

  @override
  String get advisorMiniPartnerBirthYearLabel => 'Partner year of birth';

  @override
  String get advisorMiniPartnerFirstNameLabel =>
      'Partner first name (optional)';

  @override
  String get advisorMiniPartnerFirstNameHint => 'First name';

  @override
  String get advisorMiniPartnerStatusHint => 'Partner';

  @override
  String get advisorMiniPartnerStatusInactive => 'No activity';

  @override
  String get advisorMiniPartnerRequiredTitle => 'Partner info required';

  @override
  String get advisorMiniPartnerRequiredBody =>
      'Add civil status, income, birth year and partner status for a reliable household projection.';

  @override
  String get advisorMiniPartnerProfileTitle => 'Partner profile';

  @override
  String get advisorReadinessLabel => 'Profile completeness';

  @override
  String get advisorReadinessLevel => 'Level';

  @override
  String get advisorReadinessSufficient =>
      'Sufficient foundation for an initial plan.';

  @override
  String get advisorReadinessToComplete => 'To complete';

  @override
  String get advisorMiniCoachIntroTitle => 'Your MINT coach';

  @override
  String get advisorMiniCoachIntroControl =>
      'You now have a concrete plan. We move on 3 priorities over 7 days, then refine with your coach.';

  @override
  String get advisorMiniWelcomeTitle => 'Welcome!';

  @override
  String get advisorMiniWelcomeBody =>
      'Your financial space is ready. See what your coach has prepared.';

  @override
  String get advisorMiniCoachIntroWarmth =>
      'Let\'s do this together. Every week, I help you make progress on one concrete point.';

  @override
  String get advisorMiniCoachPriorityBaseline =>
      'Confirm your baseline score and trajectory';

  @override
  String get advisorMiniCoachPriorityCouple =>
      'Align household strategy to avoid couple blind spots';

  @override
  String get advisorMiniCoachPrioritySingleParent =>
      'Prioritize household protection and emergency buffer';

  @override
  String get advisorMiniCoachPriorityBudget =>
      'Stabilize budget and fixed costs first';

  @override
  String get advisorMiniCoachPriorityTax =>
      'Identify priority tax optimizations';

  @override
  String get advisorMiniCoachPriorityRetirement =>
      'Strengthen retirement trajectory with concrete actions';

  @override
  String get advisorMiniCoachPriorityRealEstate =>
      'Verify affordability of your real-estate project';

  @override
  String get advisorMiniCoachPriorityDebtFree =>
      'Accelerate debt payoff without breaking liquidity';

  @override
  String get advisorMiniCoachPriorityWealth =>
      'Build a robust wealth accumulation plan';

  @override
  String get advisorMiniCoachPriorityPension =>
      'Optimize pillar 3a/LPP and retirement income level';

  @override
  String get advisorMiniQuickPickLabel => 'Quick pick';

  @override
  String get advisorMiniQuickPickIncomeLabel => 'Common amounts';

  @override
  String get advisorMiniFixedCostsTitle => 'Fixed costs (optional)';

  @override
  String get advisorMiniFixedCostsHint =>
      'Include: internet/mobile, household/third-party liability/car insurance, transport, subscriptions and recurring fees.';

  @override
  String get advisorMiniFixedCostsSubtitle =>
      'Add taxes, LAMal and other fixed costs for a realistic budget from day one.';

  @override
  String get advisorMiniPrefillEstimates => 'Prefill estimates';

  @override
  String get advisorMiniPrefillHint =>
      'Estimated based on your canton — adjust if different.';

  @override
  String advisorMiniPrefillTaxCouple(String canton) {
    return 'Pre-filled from your income above (canton $canton, couple)';
  }

  @override
  String advisorMiniPrefillTaxSingle(String canton) {
    return 'Pre-filled from your income above (canton $canton)';
  }

  @override
  String advisorMiniPrefillLamalFamily(String adults, String children) {
    return 'LAMal estimated for $adults adult(s) + $children child(ren)';
  }

  @override
  String advisorMiniPrefillLamalCouple(String adults) {
    return 'LAMal estimated for $adults adults';
  }

  @override
  String get advisorMiniPrefillLamalSingle => 'LAMal estimated for 1 adult';

  @override
  String get advisorMiniPrefillAdjust => 'Adjust if different.';

  @override
  String get advisorMiniTaxProvisionLabel => 'Tax provision / month';

  @override
  String get advisorMiniLamalLabel => 'LAMal premiums / month';

  @override
  String get advisorMiniOtherFixedLabel => 'Other fixed costs / month';

  @override
  String get advisorMiniStep2AhaTitle => 'Your canton at a glance';

  @override
  String advisorMiniStep2AhaHorizon(String years) {
    return 'Retirement horizon: ~$years years';
  }

  @override
  String advisorMiniStep2AhaTaxQualitative(String canton, String pressure) {
    return 'Taxation in $canton: $pressure compared to Swiss average';
  }

  @override
  String get advisorMiniStep2AhaPressureLow => 'low';

  @override
  String get advisorMiniStep2AhaPressureMedium => 'moderate';

  @override
  String get advisorMiniStep2AhaPressureHigh => 'high';

  @override
  String get advisorMiniStep2AhaPressureVeryHigh => 'very high';

  @override
  String get advisorMiniStep2AhaPressureLabel => 'Tax pressure';

  @override
  String get advisorMiniStep2AhaQualitativeHint =>
      'We\'ll refine this with your income in the next step.';

  @override
  String get advisorMiniStep2AhaDisclaimer =>
      'Educational order-of-magnitude based on MINT reference cantonal data.';

  @override
  String get advisorMiniProjectionDisclaimer =>
      'Educational tool — does not constitute financial advice (OASI/BVG).';

  @override
  String get advisorMiniExitTitle => 'Leave now?';

  @override
  String get advisorMiniExitBodyControl =>
      'Your progress is saved. You can resume later.';

  @override
  String get advisorMiniExitBodyChallenge =>
      'Just a few more seconds and you get your personalized trajectory.';

  @override
  String get advisorMiniExitStay => 'Continue';

  @override
  String get advisorMiniExitLeave => 'Leave';

  @override
  String get advisorMiniMetricsTitle => 'Onboarding metrics';

  @override
  String get advisorMiniMetricsSubtitle =>
      'Local tracking for control/challenge variants';

  @override
  String get advisorMiniMetricsControl => 'Control';

  @override
  String get advisorMiniMetricsChallenge => 'Challenge';

  @override
  String get advisorMiniMetricsStarts => 'Starts';

  @override
  String get advisorMiniMetricsCompletionRate => 'Completion rate';

  @override
  String get advisorMiniMetricsExitStayRate => 'Exit prompt stay rate';

  @override
  String get advisorMiniMetricsAhaToStep3 => 'Step2 A-ha -> Step3';

  @override
  String get advisorMiniMetricsQuickPicks => 'Quick picks';

  @override
  String get advisorMiniMetricsAvgStepTime => 'Avg step time';

  @override
  String get advisorMiniMetricsReset => 'Reset metrics';

  @override
  String advisorMiniEtaLabel(String seconds) {
    return 'Estimated time left: ${seconds}s';
  }

  @override
  String get advisorMiniEtaConfidenceHigh => 'High confidence';

  @override
  String get advisorMiniEtaConfidenceLow => 'Medium confidence';

  @override
  String get advisorMiniEmploymentLabel => 'Employment status';

  @override
  String get advisorMiniHouseholdLabel => 'Your household';

  @override
  String get advisorMiniHouseholdSubtitle =>
      'We adjust taxes and fixed costs to your situation';

  @override
  String get advisorMiniReadyTitle => 'Ready';

  @override
  String get advisorMiniReadyLabel => 'What MINT understood';

  @override
  String get advisorMiniReadyStep1 =>
      'Priority captured. We personalize your trajectory.';

  @override
  String get advisorMiniReadyStep2 =>
      'Tax base is ready. Cantonal context is calibrated.';

  @override
  String get advisorMiniReadyStep3 =>
      'Minimum profile ready. Indicative projection available.';

  @override
  String advisorMiniReadyStress(String label) {
    return 'Priority: $label';
  }

  @override
  String advisorMiniReadyProfile(String employment, String household) {
    return 'Profile: $employment · $household';
  }

  @override
  String advisorMiniReadyLocation(String canton, String horizon) {
    return 'Tax base: $canton · $horizon';
  }

  @override
  String advisorMiniReadyIncome(String income) {
    return 'Net income: CHF $income/month';
  }

  @override
  String advisorMiniReadyFixed(String count) {
    return 'Fixed costs captured: $count/3';
  }

  @override
  String get advisorMiniEmploymentEmployee => 'Employee';

  @override
  String get advisorMiniEmploymentSelfEmployed => 'Self-employed';

  @override
  String get advisorMiniEmploymentStudent => 'Student / Apprentice';

  @override
  String get advisorMiniEmploymentUnemployed => 'Unemployed';

  @override
  String get advisorMiniSeeProjection => 'See my projection';

  @override
  String get advisorMiniPreferFullDiagnostic =>
      'I prefer the full diagnostic (10 min)';

  @override
  String advisorMiniQuickInsight(String low, String high, String horizon) {
    return 'Quick estimate: consistent savings between CHF $low and CHF $high/month can already shift your trajectory. $horizon';
  }

  @override
  String advisorMiniHorizon(String years) {
    return 'Retirement horizon: ~$years years.';
  }

  @override
  String get advisorMiniStep4Title => 'Your goal';

  @override
  String get advisorMiniStep4Subtitle =>
      'MINT personalizes your plan based on your main priority';

  @override
  String get advisorMiniGoalRetirement => 'Prepare for retirement';

  @override
  String get advisorMiniGoalRealEstate => 'Buy a property';

  @override
  String get advisorMiniGoalDebtFree => 'Reduce my debt';

  @override
  String get advisorMiniGoalIndependence => 'Build my financial independence';

  @override
  String get advisorMiniActivateDashboard => 'Activate my dashboard';

  @override
  String get advisorMiniAdjustLater =>
      'You can adjust everything later from Dashboard and Act.';

  @override
  String advisorMiniPreviewTitle(String goal) {
    return 'Trajectory preview: $goal';
  }

  @override
  String advisorMiniPreviewSubtitle(String years) {
    return 'Indicative projection over ~$years years';
  }

  @override
  String get advisorMiniPreviewPrudent => 'Prudent';

  @override
  String get advisorMiniPreviewBase => 'Base';

  @override
  String get advisorMiniPreviewOptimistic => 'Optimistic';

  @override
  String get homeSafeModeActive => 'PROTECTION MODE ACTIVE';

  @override
  String get homeHide => 'Hide';

  @override
  String get homeSafeModeMessage =>
      'We have detected warning signals. MINT advises you to stabilise your budget before investing.';

  @override
  String get homeSafeModeResources => 'Free Resources & Help';

  @override
  String get homeMentorAdvisor => 'Mentor Advisor';

  @override
  String get homeMentorDescription =>
      'Launch your personalised session for a complete diagnosis of your financial situation.';

  @override
  String get homeStartSession => 'Start my session';

  @override
  String get homeSimulator3a => 'Pillar 3a Retirement';

  @override
  String get homeSimulatorGrowth => 'Growth';

  @override
  String get homeSimulatorLeasing => 'Leasing';

  @override
  String get homeSimulatorCredit => 'Consumer Credit';

  @override
  String get homeReportV2Title => '🧪 NEW: Report V2 (Demo)';

  @override
  String get homeReportV2Subtitle =>
      'Circle scores, 3a comparison, pension strategy';

  @override
  String get profileTitle => 'MY MENTOR PROFILE';

  @override
  String get profilePrecisionIndex => 'Precision Index';

  @override
  String get profilePrecisionMessage =>
      'The more complete your profile, the more powerful your \"Statement of Advice\" report.';

  @override
  String get profileFactFindTitle => 'FactFind Details';

  @override
  String get profileSectionIdentity => 'Identity & Household';

  @override
  String get profileSectionIncome => 'Income & Savings';

  @override
  String get profileSectionPension => 'Pension (2nd Pillar)';

  @override
  String get profileSectionProperty => 'Property & Debts';

  @override
  String get profileStatusComplete => 'Complete';

  @override
  String get profileStatusPartial => 'Partial (Net)';

  @override
  String get profileStatusMissing => 'Missing';

  @override
  String get profileReward15 => '+15% precision';

  @override
  String get profileReward10 => '+10% precision';

  @override
  String get profileSecurityTitle => 'Security & Data';

  @override
  String get profileConsentControl => 'Consent Control';

  @override
  String get profileConsentManage => 'Manage my bLink access';

  @override
  String get profileAccountTitle => 'Account';

  @override
  String get profileUser => 'User';

  @override
  String get profileDeleteData => 'Delete my local data';

  @override
  String get rentVsCapitalTitle => 'Annuity vs Lump Sum';

  @override
  String get rentVsCapitalDescription =>
      'Compare the lifelong annuity with the lump-sum withdrawal from your 2nd pillar';

  @override
  String get rentVsCapitalSubtitle => 'Simulate your 2nd pillar • Pension fund';

  @override
  String get rentVsCapitalAvoirOblig => 'Mandatory assets';

  @override
  String get rentVsCapitalAvoirSurob => 'Extra-mandatory assets';

  @override
  String get rentVsCapitalTauxConversion => 'Extra-mandatory conversion rate';

  @override
  String get rentVsCapitalAgeRetraite => 'Retirement age';

  @override
  String get rentVsCapitalCanton => 'Canton';

  @override
  String get rentVsCapitalStatutCivil => 'Marital status';

  @override
  String get rentVsCapitalSingle => 'Single';

  @override
  String get rentVsCapitalMarried => 'Married';

  @override
  String get rentVsCapitalRenteViagere => 'Lifelong annuity';

  @override
  String get rentVsCapitalCapitalNet => 'Net capital';

  @override
  String get rentVsCapitalBreakEven => 'Break-even';

  @override
  String get rentVsCapitalCapitalA85 => 'Capital at 85';

  @override
  String get rentVsCapitalJamais => 'Never';

  @override
  String get rentVsCapitalPrudent => 'Prudent (1%)';

  @override
  String get rentVsCapitalCentral => 'Central (3%)';

  @override
  String get rentVsCapitalOptimiste => 'Optimistic (5%)';

  @override
  String get rentVsCapitalTauxConversionExpl =>
      'The conversion rate determines your annual pension based on your retirement savings. The legal minimum rate is 6.8% for the mandatory part (BVG Art. 14). For the extra-mandatory part, each pension fund sets its own rate, typically between 3% and 6%.';

  @override
  String get rentVsCapitalChoixExpl =>
      'The annuity offers regular lifetime income but stops at death (with a possibly reduced survivor\'s pension). Capital provides more flexibility but carries a risk of depletion if returns are low or longevity is high.';

  @override
  String get rentVsCapitalDisclaimer =>
      'The results presented are estimates for informational purposes only. They do not constitute personalised financial advice. Consult your pension fund and a qualified adviser before any decision.';

  @override
  String get disabilityGapTitle => 'My safety net';

  @override
  String get disabilityGapSubtitle => 'What happens if I can no longer work?';

  @override
  String get disabilityGapRevenu => 'Monthly net income';

  @override
  String get disabilityGapCanton => 'Canton';

  @override
  String get disabilityGapStatut => 'Professional status';

  @override
  String get disabilityGapSalarie => 'Employed';

  @override
  String get disabilityGapIndependant => 'Self-employed';

  @override
  String get disabilityGapAnciennete => 'Years of service';

  @override
  String get disabilityGapIjm =>
      'Collective daily sickness benefit via my employer';

  @override
  String get disabilityGapDegre => 'Degree of disability';

  @override
  String get disabilityGapPhase1 => 'Phase 1 — Employer';

  @override
  String get disabilityGapPhase2 => 'Phase 2 — Daily sickness benefit';

  @override
  String get disabilityGapPhase3 => 'Phase 3 — Disability insurance + Pension';

  @override
  String get disabilityGapRevenuActuel => 'Current income';

  @override
  String get disabilityGapGapMensuel => 'Maximum monthly gap';

  @override
  String get disabilityGapRiskCritical => 'Critical risk';

  @override
  String get disabilityGapRiskHigh => 'High risk';

  @override
  String get disabilityGapRiskMedium => 'Moderate risk';

  @override
  String get disabilityGapRiskLow => 'Low risk';

  @override
  String get disabilityGapDisclaimer =>
      'These results are indicative estimates based on legal scales. Your actual coverage depends on your employment contract, pension fund and individual insurance. Consult your employer and a qualified specialist.';

  @override
  String get disabilityGapIjmExpl =>
      'Daily sickness benefit insurance covers 80% of your salary for a maximum of 720 days in case of illness. The employer is not obliged to take it out, but many do so through collective insurance. Without it, after the legal salary maintenance period, you receive nothing until possible disability insurance benefits.';

  @override
  String get disabilityGapCo324aExpl =>
      'According to Art. 324a CO, the employer must pay salary for a limited period in case of illness. This duration depends on years of service and the applicable cantonal scale (Bernese, Zurich, or Basel). After this period, only daily sickness benefit insurance (if existing) takes over.';

  @override
  String get authLogin => 'Log in';

  @override
  String get authRegister => 'Create account';

  @override
  String get authEmail => 'Email address';

  @override
  String get authPassword => 'Password';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authDisplayName => 'Display name (optional)';

  @override
  String get authCreateAccount => 'Create my account';

  @override
  String get authAlreadyAccount => 'Already registered?';

  @override
  String get authNoAccount => 'No account yet?';

  @override
  String get authLogout => 'Log out';

  @override
  String get authLoginTitle => 'Login';

  @override
  String get authRegisterTitle => 'Create your account';

  @override
  String get authPasswordHint => 'Minimum 8 characters';

  @override
  String get authError => 'Login error';

  @override
  String get authEmailInvalid => 'Invalid email address';

  @override
  String get authPasswordTooShort =>
      'Password must contain at least 8 characters';

  @override
  String get authPasswordMismatch => 'Passwords do not match';

  @override
  String get authForgotTitle => 'Reset password';

  @override
  String get authForgotSteps =>
      '1) Request link  2) Paste token  3) Choose a new password';

  @override
  String get authForgotSendLink => 'Send reset link';

  @override
  String get authForgotResetTokenLabel => 'Reset token';

  @override
  String get authForgotNewPasswordLabel => 'New password';

  @override
  String get authForgotSubmitNewPassword => 'Confirm new password';

  @override
  String get authForgotRequestAccepted =>
      'If an account exists, a reset link has been sent.';

  @override
  String get authForgotResetSuccess => 'Password updated. You can now sign in.';

  @override
  String get authVerifyTitle => 'Verify my email';

  @override
  String get authVerifyInstructions =>
      'Request a new link, then paste the verification token.';

  @override
  String get authVerifySendLink => 'Send verification link';

  @override
  String get authVerifyTokenLabel => 'Verification token';

  @override
  String get authVerifySubmit => 'Confirm verification';

  @override
  String get authVerifyRequestAccepted =>
      'Verification link sent (if account exists).';

  @override
  String get authVerifySuccess => 'Email verified. You can now sign in.';

  @override
  String get authTokenRequired => 'Token required.';

  @override
  String get authEmailInvalidPrompt => 'Enter a valid email address.';

  @override
  String get authDebugTokenLabel => 'Debug token (tests)';

  @override
  String get adminObsTitle => 'Admin observability';

  @override
  String get adminObsExportCsv => 'Export cohort CSV';

  @override
  String get adminObsCsvCopied => 'Cohort CSV copied to clipboard';

  @override
  String get adminObsExportFailed => 'Export failed';

  @override
  String get adminObsWindowLabel => 'Window';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonDays => 'days';

  @override
  String get analyticsConsentTitle => 'Anonymous statistics';

  @override
  String get analyticsConsentMessage =>
      'MINT uses anonymous statistics to improve the experience. No personal data is collected.';

  @override
  String get analyticsAccept => 'Accept';

  @override
  String get analyticsRefuse => 'Refuse';

  @override
  String get askMintTitle => 'Ask MINT';

  @override
  String get askMintSubtitle => 'Ask your questions about Swiss finance';

  @override
  String get askMintConfigureTitle => 'Configure your AI';

  @override
  String get askMintConfigureBody =>
      'To ask questions about Swiss finance, connect your own API key (Claude, OpenAI or Mistral). Your key is encrypted locally and never stored on our servers.';

  @override
  String get askMintConfigureButton => 'Configure my API key';

  @override
  String get askMintEmptyTitle => 'Ask me a question';

  @override
  String get askMintEmptySubtitle =>
      'I can help you with Swiss finance: pillar 3a, pension fund, taxes, budget...';

  @override
  String get askMintSuggestedTitle => 'SUGGESTIONS';

  @override
  String get askMintSuggestion1 =>
      'How does the 3rd pillar work in Switzerland?';

  @override
  String get askMintSuggestion2 =>
      'Should I choose annuity or lump sum from my pension fund?';

  @override
  String get askMintSuggestion3 => 'How can I optimise my taxes?';

  @override
  String get askMintSuggestion4 => 'What is a pension fund buyback?';

  @override
  String get askMintInputHint => 'Ask your question about Swiss finance...';

  @override
  String get askMintSourcesTitle => 'Sources';

  @override
  String get askMintErrorInvalidKey =>
      'Your API key seems invalid or expired. Check it in the settings.';

  @override
  String get askMintErrorRateLimit =>
      'Rate limit reached. Wait a moment before trying again.';

  @override
  String get askMintErrorGeneric =>
      'An error occurred. Check your connection and try again.';

  @override
  String get askMintDisclaimer =>
      'Responses are AI-generated and do not constitute personalised financial advice.';

  @override
  String get byokTitle => 'Artificial Intelligence';

  @override
  String get byokSubtitle => 'Connect your own LLM for personalised answers';

  @override
  String get byokProviderLabel => 'Provider';

  @override
  String get byokApiKeyLabel => 'API Key';

  @override
  String get byokTestButton => 'Test the key';

  @override
  String get byokTesting => 'Testing...';

  @override
  String get byokSaveButton => 'Save';

  @override
  String get byokSaved => 'Key saved successfully';

  @override
  String get byokTestSuccess => 'Connection successful! Your AI is ready.';

  @override
  String get byokPrivacyTitle => 'Your key, your data';

  @override
  String get byokPrivacyBody =>
      'Your API key is stored encrypted on your device. It is securely transmitted (HTTPS) to our server to communicate with the AI provider, then immediately discarded — never stored server-side.';

  @override
  String get byokPrivacyShort =>
      'Key encrypted locally, never stored on our servers';

  @override
  String get byokClearButton => 'Delete saved key';

  @override
  String get byokClearTitle => 'Delete the key?';

  @override
  String get byokClearMessage =>
      'This will delete your locally stored API key. You can configure a new one at any time.';

  @override
  String get byokClearCancel => 'Cancel';

  @override
  String get byokClearConfirm => 'Delete';

  @override
  String get byokLearnTitle => 'About BYOK';

  @override
  String get byokLearnHeading => 'What is BYOK (Bring Your Own Key)?';

  @override
  String get byokLearnBody =>
      'BYOK lets you use your own API key from an AI provider (Claude, OpenAI, Mistral) to get personalised answers about Swiss finance.\n\nBenefits:\n• Full control over your data\n• No hidden costs from MINT\n• You only pay for what you use\n• Key encrypted on your device';

  @override
  String get profileAiTitle => 'Artificial Intelligence';

  @override
  String get profileAiByok => 'Ask MINT (BYOK)';

  @override
  String get profileAiConfigured => 'Configured';

  @override
  String get profileAiNotConfigured => 'Not configured';

  @override
  String get documentsTitle => 'My documents';

  @override
  String get documentsSubtitle => 'Upload and analyse your financial documents';

  @override
  String get documentsUploadTitle => 'Upload your pension certificate';

  @override
  String get documentsUploadBody =>
      'MINT automatically extracts your pension fund data';

  @override
  String get documentsUploadButton => 'Choose a PDF file';

  @override
  String get documentsAnalyzing => 'Analysing...';

  @override
  String documentsConfidence(String confidence) {
    return 'Confidence: $confidence%';
  }

  @override
  String documentsFieldsFound(String found, String total) {
    return '$found fields extracted out of $total';
  }

  @override
  String get documentsConfirmButton => 'Confirm and update my profile';

  @override
  String get documentsDeleteButton => 'Delete this document';

  @override
  String get documentsDeleteTitle => 'Delete the document?';

  @override
  String get documentsDeleteMessage => 'This action cannot be undone.';

  @override
  String get documentsPrivacy =>
      'Your documents are analysed locally and are never shared with third parties. You can delete them at any time.';

  @override
  String get documentsEmpty => 'No documents';

  @override
  String get documentsLppCertificate => 'Pension certificate';

  @override
  String get documentsUnknown => 'Unknown document';

  @override
  String get documentsCategoryEpargne => 'Savings';

  @override
  String get documentsCategorySalaire => 'Salary';

  @override
  String get documentsCategoryTaux => 'Conversion rate';

  @override
  String get documentsCategoryRisque => 'Risk coverage';

  @override
  String get documentsCategoryRachat => 'Buyback';

  @override
  String get documentsCategoryCotisations => 'Contributions';

  @override
  String get documentsFieldAvoirObligatoire => 'Mandatory retirement assets';

  @override
  String get documentsFieldAvoirSurobligatoire =>
      'Extra-mandatory retirement assets';

  @override
  String get documentsFieldAvoirTotal => 'Total retirement assets';

  @override
  String get documentsFieldSalaireAssure => 'Insured salary';

  @override
  String get documentsFieldSalaireAvs => 'AHV salary';

  @override
  String get documentsFieldDeductionCoordination => 'Coordination deduction';

  @override
  String get documentsFieldTauxObligatoire => 'Mandatory conversion rate';

  @override
  String get documentsFieldTauxSurobligatoire =>
      'Extra-mandatory conversion rate';

  @override
  String get documentsFieldTauxEnveloppe => 'Envelope conversion rate';

  @override
  String get documentsFieldRenteInvalidite => 'Annual disability pension';

  @override
  String get documentsFieldCapitalDeces => 'Death capital';

  @override
  String get documentsFieldRenteConjoint => 'Annual spouse pension';

  @override
  String get documentsFieldRenteEnfant => 'Annual child pension';

  @override
  String get documentsFieldRachatMax => 'Maximum possible buyback';

  @override
  String get documentsFieldCotisationEmploye => 'Annual employee contribution';

  @override
  String get documentsFieldCotisationEmployeur =>
      'Annual employer contribution';

  @override
  String get documentsWarningsTitle => 'Points of attention';

  @override
  String get profileDocuments => 'My documents';

  @override
  String profileDocumentsCount(String count) {
    return '$count document(s)';
  }

  @override
  String get bankImportTitle => 'Import my statements';

  @override
  String get bankImportSubtitle => 'Automatic analysis of your transactions';

  @override
  String get bankImportUploadTitle => 'Import your bank statement';

  @override
  String get bankImportUploadBody =>
      'CSV or PDF — UBS, PostFinance, Raiffeisen, ZKB and other Swiss banks';

  @override
  String get bankImportUploadButton => 'Choose a file';

  @override
  String get bankImportAnalyzing => 'Analysing transactions...';

  @override
  String bankImportBankDetected(String bank) {
    return '$bank detected';
  }

  @override
  String bankImportPeriod(String start, String end) {
    return 'Period: $start - $end';
  }

  @override
  String bankImportTransactionCount(String count) {
    return '$count transactions';
  }

  @override
  String get bankImportIncome => 'Income';

  @override
  String get bankImportExpenses => 'Expenses';

  @override
  String get bankImportCategories => 'Breakdown by category';

  @override
  String get bankImportRecurring => 'Detected recurring charges';

  @override
  String bankImportPerMonth(String amount) {
    return '$amount/month';
  }

  @override
  String get bankImportBudgetPreview => 'Your estimated budget';

  @override
  String get bankImportMonthlyIncome => 'Monthly income';

  @override
  String get bankImportFixedCharges => 'Fixed charges';

  @override
  String get bankImportVariable => 'Variable expenses';

  @override
  String get bankImportSavingsRate => 'Savings rate';

  @override
  String get bankImportButton => 'Import into my budget';

  @override
  String get bankImportPrivacy =>
      'Your statements are analysed locally. Transactions are never stored on our servers.';

  @override
  String get bankImportSuccess => 'Budget updated successfully';

  @override
  String get bankImportCategoryLogement => 'Housing';

  @override
  String get bankImportCategoryAlimentation => 'Groceries';

  @override
  String get bankImportCategoryTransport => 'Transport';

  @override
  String get bankImportCategoryAssurance => 'Insurance';

  @override
  String get bankImportCategoryTelecom => 'Telecom';

  @override
  String get bankImportCategoryImpots => 'Taxes';

  @override
  String get bankImportCategorySante => 'Health';

  @override
  String get bankImportCategoryLoisirs => 'Leisure';

  @override
  String get bankImportCategoryEpargne => 'Savings';

  @override
  String get bankImportCategorySalaire => 'Salary';

  @override
  String get bankImportCategoryRestaurant => 'Restaurant';

  @override
  String get bankImportCategoryDivers => 'Other';

  @override
  String get jobCompareTitle => 'Compare two jobs';

  @override
  String get jobCompareSubtitle => 'Discover the invisible salary';

  @override
  String get jobCompareIntro =>
      'Gross salary doesn\'t tell the full story. Compare the invisible salary (pension, insurance) between two positions.';

  @override
  String get jobCompareCurrentJob => 'CURRENT JOB';

  @override
  String get jobCompareNewJob => 'PROSPECTIVE JOB';

  @override
  String get jobCompareSalaireBrut => 'Gross annual salary';

  @override
  String get jobCompareAge => 'Your age';

  @override
  String get jobComparePartEmployeur => 'Employer share pension fund';

  @override
  String get jobCompareTauxConversion => 'Conversion rate';

  @override
  String get jobCompareAvoirVieillesse => 'Current retirement assets';

  @override
  String get jobCompareCouvertureInvalidite => 'Disability coverage';

  @override
  String get jobCompareCapitalDeces => 'Death capital';

  @override
  String get jobCompareRachatMax => 'Maximum buyback';

  @override
  String get jobCompareIjm => 'Collective IJM included';

  @override
  String get jobCompareButton => 'Compare';

  @override
  String get jobCompareResults => 'Results';

  @override
  String get jobCompareAxis => 'Axis';

  @override
  String get jobCompareActuel => 'Current';

  @override
  String get jobCompareNouveau => 'New';

  @override
  String get jobCompareDelta => 'Difference';

  @override
  String get jobCompareSalaireNet => 'Net salary';

  @override
  String get jobCompareCotisLpp => 'Pension contributions';

  @override
  String get jobCompareCapitalRetraite => 'Retirement capital';

  @override
  String get jobCompareRenteMois => 'Pension/month';

  @override
  String get jobCompareCouvertureDeces => 'Death coverage';

  @override
  String get jobCompareInvalidite => 'Disability coverage';

  @override
  String get jobCompareRachat => 'Max buyback';

  @override
  String get jobCompareLifetimeImpact => 'Lifetime retirement impact';

  @override
  String get jobCompareAlerts => 'Points of attention';

  @override
  String get jobCompareChecklist => 'Before you sign';

  @override
  String get jobCompareChecklistReglement =>
      'Request the pension fund regulations';

  @override
  String get jobCompareChecklistTaux =>
      'Check the extra-mandatory conversion rate';

  @override
  String get jobCompareChecklistPart => 'Compare the employer share';

  @override
  String get jobCompareChecklistCoordination =>
      'Check the coordination deduction';

  @override
  String get jobCompareChecklistIjm =>
      'Ask if collective daily sickness benefit is included';

  @override
  String get jobCompareChecklistRachat =>
      'Check the waiting period for buyback';

  @override
  String get jobCompareChecklistRisque =>
      'Calculate the impact on risk benefits';

  @override
  String get jobCompareChecklistLibrePassage =>
      'Check vested benefits: transfer within 30 days max';

  @override
  String get jobCompareEducational =>
      'The invisible salary represents 10-30% of your total compensation.';

  @override
  String get jobCompareVerdictBetter => 'The new position is overall better';

  @override
  String get jobCompareVerdictWorse =>
      'The current position offers better protection';

  @override
  String get jobCompareVerdictComparable => 'Both positions are comparable';

  @override
  String get jobCompareDetailedComparison => 'Detailed comparison';

  @override
  String get jobCompareDetailedSubtitle => '7 pension axes';

  @override
  String get jobCompareReduce => 'Collapse';

  @override
  String get jobCompareShowDetails => 'Show details';

  @override
  String get jobCompareChecklistSubtitle => 'Verification checklist';

  @override
  String get jobCompareLifetimeTitle => 'Lifetime retirement impact';

  @override
  String get jobCompareDisclaimer =>
      'The results shown are indicative estimates. They do not constitute personalized financial advice. Consult your pension fund and a qualified specialist before any decision.';

  @override
  String get divorceTitle => 'Financial impact of a divorce';

  @override
  String get divorceSubtitle => 'Anticipate the financial consequences';

  @override
  String get divorceIntro =>
      'A divorce has often underestimated financial consequences: asset division, pension fund (LPP/3a) splitting, tax impact and alimony.';

  @override
  String get divorceSituationFamiliale => 'FAMILY SITUATION';

  @override
  String get divorceSituationSubtitle =>
      'Duration of marriage, children, regime';

  @override
  String get divorceDureeMariage => 'Duration of marriage';

  @override
  String get divorceNombreEnfants => 'Number of children';

  @override
  String get divorceRegimeMatrimonial => 'Matrimonial regime';

  @override
  String get divorceRegimeAcquets =>
      'Participation in acquired property (default)';

  @override
  String get divorceRegimeCommunaute => 'Community of property';

  @override
  String get divorceRegimeSeparation => 'Separation of property';

  @override
  String get divorceRevenus => 'INCOME';

  @override
  String get divorceRevenusSubtitle => 'Annual income of each spouse';

  @override
  String get divorceConjoint1Revenu => 'Spouse 1 — annual income';

  @override
  String get divorceConjoint2Revenu => 'Spouse 2 — annual income';

  @override
  String get divorcePrevoyance => 'PENSION';

  @override
  String get divorcePrevoyanceSubtitle =>
      'LPP and 3a accumulated during marriage';

  @override
  String get divorceLppConjoint1 => 'LPP Spouse 1 (during marriage)';

  @override
  String get divorceLppConjoint2 => 'LPP Spouse 2 (during marriage)';

  @override
  String get divorce3aConjoint1 => '3a Spouse 1';

  @override
  String get divorce3aConjoint2 => '3a Spouse 2';

  @override
  String get divorcePatrimoine => 'ASSETS';

  @override
  String get divorcePatrimoineSubtitle => 'Common fortune and debts';

  @override
  String get divorceFortuneCommune => 'Common assets';

  @override
  String get divorceDettesCommunes => 'Common debts';

  @override
  String get divorceSimuler => 'Simulate';

  @override
  String get divorcePartageLpp => 'LPP SHARING';

  @override
  String get divorceTotalLpp => 'Total LPP (during marriage)';

  @override
  String get divorcePartConjoint1 => 'Share Spouse 1';

  @override
  String get divorcePartConjoint2 => 'Share Spouse 2';

  @override
  String get divorceTransfert => 'Transfer';

  @override
  String get divorceImpactFiscal => 'TAX IMPACT';

  @override
  String get divorceImpotMarie => 'Estimated tax (married)';

  @override
  String get divorceImpotConjoint1 => 'Tax Spouse 1 (individual)';

  @override
  String get divorceImpotConjoint2 => 'Tax Spouse 2 (individual)';

  @override
  String get divorceTotalApresDivorce => 'Total after divorce';

  @override
  String get divorceDifference => 'Difference';

  @override
  String get divorcePartagePatrimoine => 'ASSET DIVISION';

  @override
  String get divorceFortuneNette => 'Net fortune';

  @override
  String get divorcePensionAlimentaire => 'ALIMONY (ESTIMATE)';

  @override
  String get divorcePensionAlimentaireNote =>
      'Estimate based on income gap and number of children.';

  @override
  String get divorcePointsAttention => 'POINTS OF ATTENTION';

  @override
  String get divorceActions => 'Actions to take';

  @override
  String get divorceActionsSubtitle => 'Preparation checklist';

  @override
  String get divorceEduAcquets => 'What is participation in acquired property?';

  @override
  String get divorceEduAcquetsBody =>
      'Participation in acquired property is the default matrimonial regime in Switzerland (CC Art. 181 ff). Acquired property is split equally in case of divorce.';

  @override
  String get divorceEduLpp => 'How does pension fund splitting work?';

  @override
  String get divorceEduLppBody =>
      'Pension fund assets accumulated during marriage are split equally (CC Art. 122).';

  @override
  String get divorceDisclaimer =>
      'The results presented are indicative estimates and do not constitute personalized legal or financial advice. Each situation is unique. Consult a family law attorney and a financial specialist before any decision.';

  @override
  String get successionTitle => 'Estate and inheritance';

  @override
  String get successionSubtitle => 'New succession law 2023';

  @override
  String get successionIntro =>
      'The new succession law (2023) expanded the freely disposable share. You now have more freedom to favour certain heirs.';

  @override
  String get successionSituationPersonnelle => 'Personal situation';

  @override
  String get successionSituationSubtitle => 'Civil status, heirs';

  @override
  String get successionStatutCivil => 'Civil status';

  @override
  String get successionCivilMarie => 'Married';

  @override
  String get successionCivilCelibataire => 'Single';

  @override
  String get successionCivilDivorce => 'Divorced';

  @override
  String get successionCivilVeuf => 'Widowed';

  @override
  String get successionCivilConcubinage => 'Cohabiting';

  @override
  String get successionNombreEnfants => 'Number of children';

  @override
  String get successionParentsVivants => 'Living parents';

  @override
  String get successionFratrie => 'Siblings';

  @override
  String get successionConcubin => 'Cohabiting partner';

  @override
  String get successionFortune => 'Assets';

  @override
  String get successionFortuneSubtitle => 'Total assets, 3a, pension fund';

  @override
  String get successionFortuneTotale => 'Total assets';

  @override
  String get successionAvoirs3a => 'Pillar 3a assets';

  @override
  String get successionCapitalDecesLpp => 'Pension fund death capital';

  @override
  String get successionCanton => 'Canton';

  @override
  String get successionTestament => 'Will';

  @override
  String get successionTestamentSubtitle => 'CC art. 498–504';

  @override
  String get successionHasTestament => 'I have a will';

  @override
  String get successionQuotiteBeneficiaire =>
      'Who receives the disposable share?';

  @override
  String get successionBeneficiaireConjoint => 'Spouse';

  @override
  String get successionBeneficiaireEnfants => 'Children';

  @override
  String get successionBeneficiaireConcubin => 'Cohabiting partner';

  @override
  String get successionBeneficiaireTiers => 'Third party / Charity';

  @override
  String get successionSimuler => 'Simulate';

  @override
  String get successionRepartitionLegale => 'Legal distribution';

  @override
  String get successionRepartitionTestament => 'Distribution with will';

  @override
  String get successionReservesHereditaires => 'Forced heirship shares (2023)';

  @override
  String get successionReservesNote =>
      'Legally protected amounts (untouchable)';

  @override
  String get successionQuotiteDisponible => 'Freely disposable share';

  @override
  String get successionQuotiteNote =>
      'This amount can be freely assigned by will.';

  @override
  String get successionFiscalite => 'Succession tax';

  @override
  String get successionExonere => 'Exempt';

  @override
  String get successionTotalImpot => 'Total succession tax';

  @override
  String get succession3aOpp3 => '3a beneficiaries (OPO3 Art. 2)';

  @override
  String get succession3aNote =>
      'Pillar 3a does NOT follow your will. The order of beneficiaries is set by law.';

  @override
  String get successionPointsAttention => 'Points of attention';

  @override
  String get successionChecklist => 'Protecting my loved ones';

  @override
  String get successionChecklistSubtitle => 'Actions to take';

  @override
  String get successionEduQuotite => 'What is the freely disposable share?';

  @override
  String get successionEduQuotiteBody =>
      'The freely disposable share is the portion of your estate you can freely assign by will. Since 2023, the forced share for descendants is 1/2.';

  @override
  String get successionEdu3a => '3a and succession: beware!';

  @override
  String get successionEdu3aBody =>
      'Pillar 3a is paid directly according to OPO3, not according to your will.';

  @override
  String get successionEduConcubin => 'Cohabiting partners and succession';

  @override
  String get successionEduConcubinBody =>
      'Cohabiting partners have no legal inheritance rights. Without a will, they receive nothing.';

  @override
  String get successionDisclaimer =>
      'Educational information, not legal advice (FinSA/CC). Consult a specialist for your situation.';

  @override
  String get lifeEventsSection => 'Life events';

  @override
  String get lifeEventDivorce => 'Divorce';

  @override
  String get lifeEventSuccession => 'Succession';

  @override
  String get coachingTitle => 'Proactive Coaching';

  @override
  String get coachingSubtitle => 'Your personalised suggestions';

  @override
  String get coachingIntro =>
      'Personalised suggestions based on your profile. The more complete your profile, the more relevant the advice.';

  @override
  String get coachingFilterAll => 'All';

  @override
  String get coachingFilterHigh => 'High priority';

  @override
  String get coachingFilterFiscal => 'Tax';

  @override
  String get coachingFilterPrevoyance => 'Pension';

  @override
  String get coachingFilterBudget => 'Budget';

  @override
  String get coachingFilterRetraite => 'Retirement';

  @override
  String get coachingNoTips =>
      'Your profile is complete. Nothing to flag right now.';

  @override
  String coachingImpact(String amount) {
    return 'Estimated impact: $amount';
  }

  @override
  String get coachingSource => 'Source';

  @override
  String coachingTipCount(String count) {
    return '$count tips';
  }

  @override
  String get coachingPriorityHigh => 'High priority';

  @override
  String get coachingPriorityMedium => 'Medium priority';

  @override
  String get coachingPriorityLow => 'Information';

  @override
  String get coaching3aDeadlineTitle =>
      'Pillar 3a contribution before December 31';

  @override
  String coaching3aDeadlineMessage(
      String remaining, String plafond, String impact) {
    return 'You have $remaining left on your 3a ceiling ($plafond). A contribution before December 31 could reduce your tax burden by approximately $impact.';
  }

  @override
  String get coaching3aDeadlineAction => 'Simulate my 3a';

  @override
  String get coaching3aMissingTitle => 'You don\'t have a pillar 3a';

  @override
  String coaching3aMissingMessage(
      String plafond, String impact, String canton) {
    return 'Opening a pillar 3a would allow you to deduct up to $plafond from your taxable income each year. The estimated tax saving is $impact per year in the canton of $canton.';
  }

  @override
  String get coaching3aMissingAction => 'Discover pillar 3a';

  @override
  String get coaching3aNotMaxedTitle => 'Pillar 3a ceiling not reached';

  @override
  String coaching3aNotMaxedMessage(
      String current, String plafond, String remaining, String impact) {
    return 'Your current 3a contribution is $current out of a ceiling of $plafond. Contributing the remaining $remaining could represent a tax saving of approximately $impact.';
  }

  @override
  String get coaching3aNotMaxedAction => 'Simulate my 3a';

  @override
  String get coachingLppBuybackTitle => 'Pension fund buyback possible';

  @override
  String coachingLppBuybackMessage(String gap, String impact) {
    return 'You have a pension gap of $gap. A voluntary buyback could save you approximately $impact in taxes while improving your retirement.';
  }

  @override
  String get coachingLppBuybackAction => 'Simulate a buyback';

  @override
  String get coachingTaxDeadlineTitle => 'Tax return due';

  @override
  String coachingTaxDeadlineMessage(String canton, String days) {
    return 'The deadline for your tax return in the canton of $canton is March 31. $days days remaining.';
  }

  @override
  String get coachingTaxDeadlineAction => 'View my tax checklist';

  @override
  String coachingRetirementTitle(String years) {
    return 'Retirement in $years years';
  }

  @override
  String coachingRetirementMessage(String years) {
    return 'With $years years until retirement, it\'s important to review your pension strategy. Have you optimised your buybacks? Are your 3a accounts diversified?';
  }

  @override
  String get coachingRetirementAction => 'Plan my retirement';

  @override
  String get coachingEmergencyTitle => 'Insufficient emergency fund';

  @override
  String coachingEmergencyMessage(String months, String deficit) {
    return 'Your available savings cover $months months of fixed charges. Experts recommend at least 3 months. You need approximately $deficit more.';
  }

  @override
  String get coachingEmergencyAction => 'View my budget';

  @override
  String coachingDebtTitle(String ratio) {
    return 'High debt ratio ($ratio%)';
  }

  @override
  String coachingDebtMessage(String ratio) {
    return 'Your estimated debt ratio is $ratio%, above the 33% threshold recommended by Swiss banks.';
  }

  @override
  String get coachingDebtAction => 'Analyse my debts';

  @override
  String get coachingPartTimeTitle => 'Part-time: pension gap';

  @override
  String coachingPartTimeMessage(String rate) {
    return 'At $rate% activity, your occupational pension is reduced. The coordination deduction further penalises part-time workers.';
  }

  @override
  String get coachingPartTimeAction => 'Simulate my pension';

  @override
  String get coachingIndependantTitle =>
      'Self-employed: no mandatory pension fund';

  @override
  String get coachingIndependantMessage =>
      'As a self-employed person, you are not subject to mandatory pension fund contributions. Your pension relies on AHV/AVS and your pillar 3a. Maximise your 3a contributions.';

  @override
  String get coachingIndependantAction => 'Explore my options';

  @override
  String get coachingBudgetMissingTitle => 'No budget yet';

  @override
  String get coachingBudgetMissingMessage =>
      'A structured budget is the foundation of any financial strategy. It helps identify your real savings capacity.';

  @override
  String get coachingBudgetMissingAction => 'Create my budget';

  @override
  String get coachingAge25Title => '25: Start your pillar 3a';

  @override
  String get coachingAge25Message =>
      'At 25, it\'s the ideal time to open a pillar 3a. Thanks to compound interest, every year counts.';

  @override
  String get coachingAge35Title => '35: Pension check-up';

  @override
  String get coachingAge35Message =>
      'At 35, verify your pension is on track. Do you have a 3a? Is your pension fund sufficient?';

  @override
  String get coachingAge45Title => '45: Optimise your strategy';

  @override
  String get coachingAge45Message =>
      'At 45, there are 20 years until retirement. Time to optimise: maximise 3a, consider pension fund buybacks.';

  @override
  String get coachingAge50Title => '50: Prepare for retirement';

  @override
  String get coachingAge50Message =>
      'At 50, retirement is approaching. Check your pension fund balance and plan your final buybacks.';

  @override
  String get coachingAge55Title => '55: The final stretch';

  @override
  String get coachingAge55Message =>
      'At 55, tax planning for withdrawals becomes crucial. Staggering 3a withdrawals across tax years can mean significant savings.';

  @override
  String get coachingAge58Title => '58: Early retirement possible';

  @override
  String get coachingAge58Message =>
      'From 58, early withdrawal of your 2nd pillar is possible. Note: the pension will be reduced.';

  @override
  String get coachingAge63Title => '63: Final adjustments';

  @override
  String get coachingAge63Message =>
      '2 years from retirement: finalise your strategy. Last pension buyback, annuity vs lump sum choice.';

  @override
  String get coachingDisclaimer =>
      'The suggestions presented are food for thought based on simplified estimates. They do not constitute personalised financial advice. Consult a qualified professional before any decision.';

  @override
  String get coachingDemoMode =>
      'Demo mode: example profile (35 years, VD, CHF 85\'000). Complete your diagnostic for personalised advice.';

  @override
  String get coachingNowCardTitle => 'Proactive Coaching';

  @override
  String get coachingNowCardSubtitle =>
      'Personalised advice based on your profile';

  @override
  String get coachingCategoryFiscalite => 'Tax';

  @override
  String get coachingCategoryPrevoyance => 'Pension';

  @override
  String get coachingCategoryBudget => 'Budget';

  @override
  String get coachingCategoryRetraite => 'Retirement';

  @override
  String get segmentsSection => 'Segments';

  @override
  String get segmentsGenderGapTitle => 'Gender pension gap';

  @override
  String get segmentsGenderGapSubtitle =>
      'Impact of part-time work on retirement';

  @override
  String get segmentsGenderGapAppBar => 'GENDER PENSION GAP';

  @override
  String get segmentsGenderGapHeader => 'Pension gap';

  @override
  String get segmentsGenderGapHeaderSub =>
      'Impact of part-time work on retirement';

  @override
  String get segmentsGenderGapIntro =>
      'The coordination deduction (CHF 25,725) is not prorated for part-time work, which further penalises people working reduced hours. Move the slider to see the impact.';

  @override
  String get segmentsGenderGapTauxLabel => 'Activity rate';

  @override
  String get segmentsGenderGapParams => 'Parameters';

  @override
  String get segmentsGenderGapRevenuLabel => 'Annual gross income (100%)';

  @override
  String get segmentsGenderGapAgeLabel => 'Age';

  @override
  String get segmentsGenderGapAvoirLabel => 'Current pension fund assets';

  @override
  String get segmentsGenderGapAnneesCotisLabel => 'Contribution years';

  @override
  String get segmentsGenderGapCantonLabel => 'Canton';

  @override
  String get segmentsGenderGapRenteTitle => 'Estimated pension fund annuity';

  @override
  String segmentsGenderGapRenteSub(String years) {
    return 'Projection at $years years (age 65)';
  }

  @override
  String get segmentsGenderGapAt100 => 'At 100%';

  @override
  String segmentsGenderGapAtCurrent(String rate) {
    return 'At $rate%';
  }

  @override
  String get segmentsGenderGapLacuneAnnuelle => 'Annual gap';

  @override
  String get segmentsGenderGapLacuneTotale => 'Total gap (~20 years)';

  @override
  String get segmentsGenderGapCoordinationTitle =>
      'Understanding the coordination deduction';

  @override
  String get segmentsGenderGapCoordinationBody =>
      'The coordination deduction is a fixed amount of CHF 25,725 subtracted from your gross salary to calculate the coordinated salary (pension fund base). This amount is the same whether you work at 100% or 50%.';

  @override
  String get segmentsGenderGapSalaireBrut100 => 'Gross salary at 100%';

  @override
  String get segmentsGenderGapSalaireCoord100 => 'Coordinated salary at 100%';

  @override
  String segmentsGenderGapSalaireBrutCurrent(String rate) {
    return 'Gross salary at $rate%';
  }

  @override
  String segmentsGenderGapSalaireCoordCurrent(String rate) {
    return 'Coordinated salary at $rate%';
  }

  @override
  String get segmentsGenderGapDeductionFixe => 'Coordination deduction (fixed)';

  @override
  String get segmentsGenderGapOfsTitle => 'FSO Statistic';

  @override
  String get segmentsGenderGapOfsStat =>
      'In Switzerland, women receive on average 37% less pension than men (FSO 2024)';

  @override
  String get segmentsGenderGapRecTitle => 'RECOMMENDATIONS';

  @override
  String get segmentsGenderGapRecRachat => 'Voluntary pension fund buyback';

  @override
  String get segmentsGenderGapRecRachatDesc =>
      'A voluntary buyback can partially fill the pension gap while benefiting from a tax deduction.';

  @override
  String get segmentsGenderGapRec3a => 'Maximised pillar 3a';

  @override
  String get segmentsGenderGapRec3aDesc =>
      'Contribute the annual ceiling of CHF 7,258 (employees) to partially compensate for the pension fund gap.';

  @override
  String get segmentsGenderGapRecCoord => 'Check coordination proration';

  @override
  String get segmentsGenderGapRecCoordDesc =>
      'Some pension funds prorate the coordination deduction based on the activity rate.';

  @override
  String get segmentsGenderGapRecTaux =>
      'Explore increasing your activity rate';

  @override
  String get segmentsGenderGapRecTauxDesc =>
      'Even an increase of 10 to 20 percentage points can significantly reduce the gap.';

  @override
  String get segmentsGenderGapDisclaimer =>
      'The results presented are simplified estimates for informational purposes only. They do not constitute personalised financial advice. Consult your pension fund and a qualified professional.';

  @override
  String get segmentsGenderGapSources => 'Sources';

  @override
  String get segmentsFrontalierTitle => 'Cross-border worker';

  @override
  String get segmentsFrontalierSubtitle => 'Rights and obligations by country';

  @override
  String get segmentsFrontalierAppBar => 'CROSS-BORDER WORKER';

  @override
  String get segmentsFrontalierHeader => 'Cross-border worker';

  @override
  String get segmentsFrontalierHeaderSub => 'Rights and obligations by country';

  @override
  String get segmentsFrontalierIntro =>
      'Tax, pension and insurance rules vary depending on your country of residence and your canton of work.';

  @override
  String get segmentsFrontalierPaysLabel => 'Country of residence';

  @override
  String get segmentsFrontalierCantonLabel => 'Canton of work';

  @override
  String get segmentsFrontalierRulesTitle => 'APPLICABLE RULES';

  @override
  String get segmentsFrontalierCatFiscal => 'Tax regime';

  @override
  String get segmentsFrontalierCat3a => 'Pillar 3a';

  @override
  String get segmentsFrontalierCatLpp => 'Pension fund / Vested benefits';

  @override
  String get segmentsFrontalierCatAvs => 'AHV / Coordination';

  @override
  String get segmentsFrontalierQuasiResidentTitle =>
      'Quasi-resident status (GE)';

  @override
  String get segmentsFrontalierQuasiResidentDesc =>
      'Quasi-resident status is available if at least 90% of your household income comes from Switzerland.';

  @override
  String get segmentsFrontalierQuasiResidentCondition =>
      'Condition: >= 90% of household income from Switzerland';

  @override
  String get segmentsFrontalierChecklist => 'Cross-border worker checklist';

  @override
  String get segmentsFrontalierPaysFR => 'France';

  @override
  String get segmentsFrontalierPaysDE => 'Germany';

  @override
  String get segmentsFrontalierPaysIT => 'Italy';

  @override
  String get segmentsFrontalierPaysAT => 'Austria';

  @override
  String get segmentsFrontalierPaysLI => 'Liechtenstein';

  @override
  String get segmentsFrontalierAttention => 'Attention';

  @override
  String get segmentsFrontalierDisclaimer =>
      'The information presented is general and may vary depending on your personal situation. Consult a fiduciary specialised in cross-border situations.';

  @override
  String get segmentsFrontalierSources => 'Sources';

  @override
  String get segmentsIndependantTitle => 'Self-employed';

  @override
  String get segmentsIndependantSubtitle => 'Coverage and social protection';

  @override
  String get segmentsIndependantAppBar => 'SELF-EMPLOYED PATHWAY';

  @override
  String get segmentsIndependantHeader => 'Self-employed';

  @override
  String get segmentsIndependantHeaderSub => 'Coverage and protection analysis';

  @override
  String get segmentsIndependantIntro =>
      'As a self-employed person, you have no mandatory pension fund, no daily sickness benefit, and no accident insurance. Your protection depends on your personal steps.';

  @override
  String get segmentsIndependantRevenuLabel => 'Annual net income';

  @override
  String get segmentsIndependantCoverageTitle => 'My current coverage';

  @override
  String get segmentsIndependantLpp => 'Pension fund (voluntary affiliation)';

  @override
  String get segmentsIndependantIjm => 'Daily sickness benefit';

  @override
  String get segmentsIndependantLaa => 'Accident insurance (LAA)';

  @override
  String get segmentsIndependant3a => 'Pillar 3a';

  @override
  String get segmentsIndependantAnalyseTitle => 'COVERAGE ANALYSIS';

  @override
  String get segmentsIndependantCouvert => 'Covered';

  @override
  String get segmentsIndependantNonCouvert => 'NOT COVERED';

  @override
  String get segmentsIndependantCritique => 'NOT COVERED — Critical';

  @override
  String get segmentsIndependantProtectionTitle => 'Cost of full protection';

  @override
  String get segmentsIndependantProtectionSub => 'Monthly estimate';

  @override
  String get segmentsIndependantAvs => 'AHV / DI / EO';

  @override
  String get segmentsIndependantIjmEst => 'Daily sickness benefit (estimate)';

  @override
  String get segmentsIndependantLaaEst => 'Accident insurance (estimate)';

  @override
  String get segmentsIndependant3aMax => 'Pillar 3a (max)';

  @override
  String get segmentsIndependantTotalMensuel => 'Monthly total';

  @override
  String get segmentsIndependantAvsTitle => 'Self-employed AHV contribution';

  @override
  String segmentsIndependantAvsDesc(String amount) {
    return 'Your estimated AHV contribution: $amount/year (degressive rate for income below CHF 58,800).';
  }

  @override
  String get segmentsIndependant3aTitle => 'Pillar 3a — self-employed ceiling';

  @override
  String get segmentsIndependant3aWithLpp =>
      'With voluntary pension fund: standard 3a ceiling of CHF 7,258/year.';

  @override
  String get segmentsIndependant3aWithoutLpp =>
      'Without pension fund: \'large\' 3a ceiling of 20% of net income, max CHF 36,288/year.';

  @override
  String get segmentsIndependantRecTitle => 'RECOMMENDATIONS';

  @override
  String get segmentsIndependantDisclaimer =>
      'The amounts presented are indicative estimates. Consult a fiduciary or insurer before any decision.';

  @override
  String get segmentsIndependantSources => 'Sources';

  @override
  String get segmentsIndependantAlertIjm =>
      'CRITICAL: You have no daily sickness benefit insurance. In case of illness, you will have no replacement income.';

  @override
  String get segmentsIndependantAlertLaa =>
      'IMPORTANT: Without individual accident insurance (LAA), medical costs in case of accident are not covered.';

  @override
  String get segmentsIndependantAlertLpp =>
      'Your pension relies solely on AHV and pillar 3a.';

  @override
  String get segmentsIndependantAlert3a =>
      'You are not using pillar 3a. Self-employed ceiling: CHF 36,288/year.';

  @override
  String get segmentsDemoMode =>
      'Demo mode: example profile. Complete your diagnostic for personalised results.';

  @override
  String get assurancesLamalTitle => 'LAMal Franchise Optimiser';

  @override
  String get assurancesLamalSubtitle =>
      'Find the ideal franchise based on your health expenses';

  @override
  String get assurancesLamalPrimeMensuelle => 'Monthly premium (franchise 300)';

  @override
  String get assurancesLamalDepensesSante => 'Estimated annual health expenses';

  @override
  String get assurancesLamalAdulte => 'Adult';

  @override
  String get assurancesLamalEnfant => 'Child';

  @override
  String get assurancesLamalFranchise => 'Franchise';

  @override
  String get assurancesLamalPrimeAnnuelle => 'Annual premium';

  @override
  String get assurancesLamalCoutTotal => 'Total cost';

  @override
  String get assurancesLamalEconomie => 'Savings vs. 300';

  @override
  String get assurancesLamalOptimale => 'Recommended franchise';

  @override
  String get assurancesLamalBreakEven => 'Break-even point';

  @override
  String get assurancesLamalDelaiRappel =>
      'Reminder: change possible before November 30';

  @override
  String get assurancesLamalQuotePart => 'Co-payment (10%, max CHF 700)';

  @override
  String get assurancesCoverageTitle => 'Coverage check-up';

  @override
  String get assurancesCoverageSubtitle => 'Evaluate your insurance protection';

  @override
  String get assurancesCoverageScore => 'Coverage score';

  @override
  String get assurancesCoverageLacunes => 'Identified gaps';

  @override
  String get assurancesCoverageStatut => 'Professional status';

  @override
  String get assurancesCoverageSalarie => 'Employed';

  @override
  String get assurancesCoverageIndependant => 'Self-employed';

  @override
  String get assurancesCoverageSansEmploi => 'Unemployed';

  @override
  String get assurancesCoverageHypotheque => 'Active mortgage';

  @override
  String get assurancesCoverageFamille => 'Dependants';

  @override
  String get assurancesCoverageLocataire => 'Tenant';

  @override
  String get assurancesCoverageVoyages => 'Frequent traveller';

  @override
  String get assurancesCoverageIjm =>
      'Collective daily sickness benefit (employer)';

  @override
  String get assurancesCoverageLaa => 'LAA (accident insurance)';

  @override
  String get assurancesCoverageRc => 'Private liability';

  @override
  String get assurancesCoverageMenage => 'Household insurance';

  @override
  String get assurancesCoverageJuridique => 'Legal protection';

  @override
  String get assurancesCoverageVoyage => 'Travel insurance';

  @override
  String get assurancesCoverageDeces => 'Life insurance';

  @override
  String get assurancesCoverageCouvert => 'Covered';

  @override
  String get assurancesCoverageNonCouvert => 'Not covered';

  @override
  String get assurancesCoverageAVerifier => 'To verify';

  @override
  String get assurancesCoverageCritique => 'Critical';

  @override
  String get assurancesCoverageHaute => 'High';

  @override
  String get assurancesCoverageMoyenne => 'Medium';

  @override
  String get assurancesCoverageBasse => 'Low';

  @override
  String get assurancesDemoMode => 'DEMO MODE';

  @override
  String get assurancesDisclaimer =>
      'This analysis is indicative. Premiums vary by insurer, region and insurance model. Consult your health insurer for exact figures.';

  @override
  String get assurancesSection => 'Insurance';

  @override
  String get assurancesLamalTile => 'LAMal Franchise';

  @override
  String get assurancesLamalTileSub => 'Find the ideal franchise';

  @override
  String get assurancesCoverageTile => 'Coverage check-up';

  @override
  String get assurancesCoverageTileSub => 'Evaluate your insurance protection';

  @override
  String get openBankingTitle => 'Open Banking';

  @override
  String get openBankingSubtitle => 'Connect your bank accounts';

  @override
  String get openBankingFinmaGate =>
      'Feature in preparation — FINMA regulatory consultation in progress';

  @override
  String get openBankingDemoData =>
      'The displayed data are demonstration examples';

  @override
  String get openBankingTotalBalance => 'Total balance';

  @override
  String get openBankingAccounts => 'Connected accounts';

  @override
  String get openBankingAddBank => 'Add a bank';

  @override
  String get openBankingAddBankDisabled => 'Available after FINMA consultation';

  @override
  String get openBankingTransactions => 'Transactions';

  @override
  String get openBankingNoTransactions => 'No transactions';

  @override
  String get openBankingIncome => 'Income';

  @override
  String get openBankingExpenses => 'Expenses';

  @override
  String get openBankingNetSavings => 'Net savings';

  @override
  String get openBankingSavingsRate => 'Savings rate';

  @override
  String get openBankingConsents => 'Consents';

  @override
  String get openBankingConsentActive => 'Active';

  @override
  String get openBankingConsentExpiring => 'Expiring soon';

  @override
  String get openBankingConsentExpired => 'Expired';

  @override
  String get openBankingConsentRevoke => 'Revoke';

  @override
  String get openBankingConsentRevoked => 'Revoked';

  @override
  String get openBankingConsentScopes => 'Permissions';

  @override
  String get openBankingConsentScopeAccounts => 'Accounts';

  @override
  String get openBankingConsentScopeBalances => 'Balances';

  @override
  String get openBankingConsentScopeTransactions => 'Transactions';

  @override
  String get openBankingConsentDuration => 'Maximum duration: 90 days';

  @override
  String get openBankingNlpdTitle => 'Your rights (nFADP)';

  @override
  String get openBankingNlpdRevoke => 'You can revoke your consent at any time';

  @override
  String get openBankingNlpdNoSharing =>
      'Your data is never shared with third parties';

  @override
  String get openBankingNlpdReadOnly =>
      'Read-only access — no financial operations';

  @override
  String get openBankingNlpdDuration => 'Maximum consent duration: 90 days';

  @override
  String get openBankingSelectBank => 'Select a bank';

  @override
  String get openBankingSelectScopes => 'Select permissions';

  @override
  String get openBankingConfirm => 'Confirm';

  @override
  String get openBankingCancel => 'Cancel';

  @override
  String get openBankingBack => 'Back';

  @override
  String get openBankingNext => 'Next';

  @override
  String get openBankingCategoryAll => 'All';

  @override
  String get openBankingCategoryAlimentation => 'Groceries';

  @override
  String get openBankingCategoryTransport => 'Transport';

  @override
  String get openBankingCategoryLogement => 'Housing';

  @override
  String get openBankingCategoryTelecom => 'Telecom';

  @override
  String get openBankingCategoryAssurances => 'Insurance';

  @override
  String get openBankingCategoryEnergie => 'Energy';

  @override
  String get openBankingCategorySante => 'Health';

  @override
  String get openBankingCategoryLoisirs => 'Leisure';

  @override
  String get openBankingCategoryImpots => 'Taxes';

  @override
  String get openBankingCategoryEpargne => 'Savings';

  @override
  String get openBankingCategoryDivers => 'Miscellaneous';

  @override
  String get openBankingCategoryRevenu => 'Income';

  @override
  String get openBankingLastSync => 'Last synchronisation';

  @override
  String get openBankingIbanMasked => 'Masked IBAN';

  @override
  String get openBankingFilterAll => 'All';

  @override
  String get openBankingThisMonth => 'This month';

  @override
  String get openBankingLastMonth => 'Previous month';

  @override
  String get openBankingDemoMode => 'DEMO MODE';

  @override
  String get openBankingDisclaimer =>
      'This feature is under development. The displayed data are examples. The activation of the Open Banking service is subject to prior regulatory consultation.';

  @override
  String get openBankingBlink => 'Powered by bLink (SIX)';

  @override
  String get openBankingFinancialOverview => 'Financial overview';

  @override
  String get openBankingTopExpenses => 'Top 3 expenses';

  @override
  String get openBankingViewTransactions => 'View transactions';

  @override
  String get openBankingManageConsents => 'Manage consents';

  @override
  String get openBankingMonthlySummary => 'Monthly summary';

  @override
  String get openBankingAddConsent => 'Add consent';

  @override
  String get openBankingConsentGrantedOn => 'Granted on';

  @override
  String get openBankingConsentExpiresOn => 'Expires on';

  @override
  String get openBankingConsentRevokedConfirm => 'Consent revoked';

  @override
  String get openBankingScopeAccountsDesc => 'Accounts (list of your accounts)';

  @override
  String get openBankingScopeBalancesDesc =>
      'Balances (current account balances)';

  @override
  String get openBankingScopeTransactionsDesc =>
      'Transactions (movement history)';

  @override
  String get openBankingReadOnlyInfo =>
      'Read-only access. No financial operations can be performed.';

  @override
  String get openBankingConsentConfirmText =>
      'By confirming, you authorise MINT to access the selected data in read-only mode for a duration of 90 days. You can revoke this consent at any time.';

  @override
  String get openBankingSection => 'Open Banking';

  @override
  String get openBankingTile => 'Open Banking';

  @override
  String get openBankingTileSub => 'Connect your bank accounts';

  @override
  String get lppDeepSection => 'LPP IN DEPTH';

  @override
  String get lppDeepRachatTitle => 'Staggered buyback';

  @override
  String get lppDeepRachatSubtitle =>
      'Optimise your pension fund buybacks over several years';

  @override
  String get lppDeepRachatAppBar => 'STAGGERED PENSION BUYBACK';

  @override
  String get lppDeepRachatIntroTitle => 'Why stagger your buybacks?';

  @override
  String get lppDeepRachatIntroBody =>
      'Swiss income tax is progressive, so spreading a pension fund buyback over several years allows you to stay in higher marginal brackets each year, thus maximising the total tax saving.';

  @override
  String get lppDeepRachatParams => 'Parameters';

  @override
  String get lppDeepRachatAvoirActuel => 'Current pension fund assets';

  @override
  String get lppDeepRachatMax => 'Maximum buyback';

  @override
  String get lppDeepRachatRevenu => 'Taxable income';

  @override
  String get lppDeepRachatTauxMarginal => 'Estimated marginal rate';

  @override
  String get lppDeepRachatHorizon => 'Horizon (years)';

  @override
  String get lppDeepRachatComparaison => 'Comparison';

  @override
  String get lppDeepRachatBloc => 'ALL IN 1 YEAR';

  @override
  String get lppDeepRachatBlocSub => 'Lump-sum buyback';

  @override
  String lppDeepRachatEchelonne(String years) {
    return 'STAGGERED OVER $years YEARS';
  }

  @override
  String get lppDeepRachatEchelonneSub => 'Staggered buyback';

  @override
  String get lppDeepRachatEconomie => 'Tax saving';

  @override
  String lppDeepRachatEconomieDelta(String amount) {
    return 'By staggering, you save an additional CHF $amount in taxes.';
  }

  @override
  String get lppDeepRachatPlanAnnuel => 'Annual plan';

  @override
  String get lppDeepRachatAnnee => 'Year';

  @override
  String get lppDeepRachatMontant => 'Buyback';

  @override
  String get lppDeepRachatEcoFiscale => 'Tax saving';

  @override
  String get lppDeepRachatCoutNet => 'Net cost';

  @override
  String get lppDeepRachatTotal => 'Total';

  @override
  String get lppDeepRachatBlocageEpl => 'BVG Art. 79b para. 3 — EPL lock';

  @override
  String get lppDeepRachatBlocageEplBody =>
      'After each buyback, any EPL withdrawal (home ownership encouragement) is locked for 3 years. Plan accordingly if a property purchase is expected.';

  @override
  String get lppDeepRachatDisclaimer =>
      'Educational simulation based on estimated progressivity. Pension fund buybacks are subject to acceptance by the pension fund. Consult your pension fund and a qualified pension specialist before any decision.';

  @override
  String get lppDeepLibrePassageTitle => 'Vested benefits';

  @override
  String get lppDeepLibrePassageSubtitle =>
      'Checklist for job changes or departures';

  @override
  String get lppDeepLibrePassageAppBar => 'VESTED BENEFITS';

  @override
  String get lppDeepLibrePassageSituation => 'Situation';

  @override
  String get lppDeepLibrePassageChangement => 'Job change';

  @override
  String get lppDeepLibrePassageDepart => 'Departure from Switzerland';

  @override
  String get lppDeepLibrePassageCessation => 'Cessation of activity';

  @override
  String get lppDeepLibrePassageNewEmployer => 'New employer';

  @override
  String get lppDeepLibrePassageNewEmployerSub =>
      'Do you already have a new employer?';

  @override
  String get lppDeepLibrePassageAlertes => 'Alerts';

  @override
  String get lppDeepLibrePassageChecklist => 'Checklist';

  @override
  String get lppDeepLibrePassageRecommandations => 'Recommendations';

  @override
  String get lppDeepLibrePassageUrgenceCritique => 'Critical';

  @override
  String get lppDeepLibrePassageUrgenceHaute => 'High';

  @override
  String get lppDeepLibrePassageUrgenceMoyenne => 'Medium';

  @override
  String get lppDeepLibrePassageCentrale =>
      '2nd Pillar Central Office (sfbvg.ch)';

  @override
  String get lppDeepLibrePassageCentraleSub =>
      'Search for forgotten vested benefits';

  @override
  String get lppDeepLibrePassagePrivacy =>
      'Your data stays on your device. No information is transmitted to third parties. Compliant with the nFADP.';

  @override
  String get lppDeepLibrePassageDisclaimer =>
      'This information is educational and does not constitute personalised legal or financial advice. Rules depend on your pension fund and your situation. Legal basis: LFLP, OLP.';

  @override
  String get lppDeepEplTitle => 'EPL withdrawal';

  @override
  String get lppDeepEplSubtitle => 'Finance a home with your 2nd pillar';

  @override
  String get lppDeepEplAppBar => 'EPL WITHDRAWAL';

  @override
  String get lppDeepEplIntroTitle => 'EPL Withdrawal — Home ownership';

  @override
  String get lppDeepEplIntroBody =>
      'The EPL allows you to use your pension fund assets to finance a home purchase, amortise a mortgage or fund renovations. Minimum amount: CHF 20,000.';

  @override
  String get lppDeepEplParams => 'Parameters';

  @override
  String get lppDeepEplAvoirTotal => 'Total pension fund assets';

  @override
  String get lppDeepEplAge => 'Age';

  @override
  String get lppDeepEplMontantSouhaite => 'Desired amount';

  @override
  String get lppDeepEplRachatsRecents => 'Recent pension buybacks';

  @override
  String get lppDeepEplRachatsRecentsSub =>
      'Have you made a pension buyback in the last 3 years?';

  @override
  String get lppDeepEplAnneesSDepuisRachat => 'Years since buyback';

  @override
  String get lppDeepEplResultat => 'Result';

  @override
  String get lppDeepEplMontantMaxRetirable => 'Maximum withdrawable amount';

  @override
  String get lppDeepEplMontantApplicable => 'Applicable amount';

  @override
  String get lppDeepEplRetraitImpossible =>
      'Withdrawal is not possible with the current configuration.';

  @override
  String get lppDeepEplImpactPrestations => 'Impact on benefits';

  @override
  String get lppDeepEplReductionInvalidite =>
      'Disability pension reduction (annual estimate)';

  @override
  String get lppDeepEplReductionDeces => 'Death capital reduction (estimate)';

  @override
  String get lppDeepEplImpactNote =>
      'The EPL withdrawal proportionally reduces your risk benefits. Check with your pension fund for the exact amounts.';

  @override
  String get lppDeepEplEstimationFiscale => 'Tax estimate';

  @override
  String get lppDeepEplMontantRetire => 'Amount withdrawn';

  @override
  String get lppDeepEplImpotEstime => 'Estimated tax on withdrawal';

  @override
  String get lppDeepEplMontantNet => 'Net amount after tax';

  @override
  String get lppDeepEplTaxNote =>
      'Capital withdrawal is taxed at a reduced rate (approximately 1/5 of the ordinary scale). The exact rate depends on the canton and personal situation.';

  @override
  String get lppDeepEplPointsAttention => 'Points of attention';

  @override
  String get lppDeepEplDisclaimer =>
      'Educational simulation for informational purposes only. The exact withdrawable amount depends on your pension fund regulations. Tax varies by canton and personal situation. Legal basis: Art. 30c BVG, OEPL.';

  @override
  String get exploreTitle => 'EXPLORE';

  @override
  String get explorePillarComprendreTitle => 'I want to understand';

  @override
  String get explorePillarComprendreSub =>
      'Swiss finance essentials, no jargon. Quiz included.';

  @override
  String get explorePillarComprendreCta => 'Explore all 9 topics';

  @override
  String get explorePillarCalculerTitle => 'I want to calculate';

  @override
  String get explorePillarCalculerSub =>
      'Simulate, compare, optimize. 49 tools at your fingertips.';

  @override
  String get explorePillarCalculerCta => 'See all tools';

  @override
  String get explorePillarLifeTitle => 'Something is happening';

  @override
  String get explorePillarLifeSub =>
      'Marriage, birth, divorce, relocation... we\'ve got you covered.';

  @override
  String get exploreGoalBudget => 'Master my Budget';

  @override
  String get exploreGoalBudgetSub => 'Manage my expenses → 3 min';

  @override
  String get exploreGoalProperty => 'Become a Homeowner';

  @override
  String get exploreGoalPropertySub => 'Simulate my purchase → 5 min';

  @override
  String get exploreGoalTax => 'Pay Less Taxes';

  @override
  String get exploreGoalTaxSub => 'Optimize my 3a → 3 min';

  @override
  String get exploreGoalRetirement => 'Prepare my Retirement';

  @override
  String get exploreGoalRetirementSub => 'See my plan → 10 min';

  @override
  String get exploreEventMarriage => 'Marriage';

  @override
  String get exploreEventMarriageSub => 'Tax and pension impact';

  @override
  String get exploreEventBirth => 'Birth';

  @override
  String get exploreEventBirthSub => 'Allowances and deductions';

  @override
  String get exploreEventConcubinage => 'Cohabitation';

  @override
  String get exploreEventConcubinageSub => 'Protect your couple';

  @override
  String get exploreEventDivorce => 'Divorce';

  @override
  String get exploreEventDivorceSub => 'Pension fund and AVS split';

  @override
  String get exploreEventSuccession => 'Succession';

  @override
  String get exploreEventSuccessionSub => 'Rights and planning';

  @override
  String get exploreEventHouseSale => 'Property Sale';

  @override
  String get exploreEventHouseSaleSub => 'Capital gains tax';

  @override
  String get exploreEventDonation => 'Donation';

  @override
  String get exploreEventDonationSub => 'Tax rules and limits';

  @override
  String get exploreEventExpat => 'Expatriation';

  @override
  String get exploreEventExpatSub => 'Departure or arrival';

  @override
  String get exploreDocUploadLpp => 'Certificates & documents';

  @override
  String get exploreDocUploadLppSub => 'Pension certificate, AVS extracts →';

  @override
  String get exploreAskMintTitle => 'Ask MINT';

  @override
  String get exploreAskMintConfigured => 'Ask your Swiss finance questions →';

  @override
  String get exploreAskMintNotConfigured => 'Set up your AI to get started →';

  @override
  String get exploreLearn3a => 'What is pillar 3a?';

  @override
  String get exploreLearnLpp => 'Pension Fund: How it works';

  @override
  String get exploreLearnFiscal => 'Swiss Taxation 101';

  @override
  String get coachWelcome => 'Welcome to MINT';

  @override
  String coachHello(String firstName) {
    return 'Hello $firstName';
  }

  @override
  String get coachFitnessTitle => 'Your Financial Fitness';

  @override
  String get coachFinancialForm => 'Financial shape';

  @override
  String get coachScoreComposite => 'Composite score · 3 pillars';

  @override
  String get coachPillarBudget => 'Budget';

  @override
  String get coachPillarPrevoyance => 'Pension';

  @override
  String get coachPillarPatrimoine => 'Wealth';

  @override
  String get coachCompletePrompt =>
      'Complete your diagnostic to discover your score';

  @override
  String get coachDiscoverScore => 'Discover my score — 10 min';

  @override
  String get coachTrajectory => 'Your trajectory';

  @override
  String get coachTrajectoryPrompt => 'Your financial trajectory awaits';

  @override
  String get coachDidYouKnow => 'Did you know?';

  @override
  String get coachFact3a =>
      'Pillar 3a can save you up to CHF 2,500 in taxes per year, depending on your canton and income.';

  @override
  String get coachFact3aLink => 'Simulate my 3a savings';

  @override
  String get coachFactAvs =>
      'In Switzerland, each missing AVS year = −2.3% pension for life. Catch-up is possible in some cases.';

  @override
  String get coachFactAvsLink => 'Check my AVS years';

  @override
  String get coachFactLpp =>
      'Pension fund buyback is one of the most powerful tax levers for employees in Switzerland. It is fully deductible from taxable income.';

  @override
  String get coachFactLppLink => 'Explore pension buyback';

  @override
  String get coachMotivation =>
      'Join the thousands of users who have already completed their financial diagnostic';

  @override
  String get coachMotivationSub => 'and receive concrete actions.';

  @override
  String get coachLaunchDiagnostic => 'Start my diagnostic';

  @override
  String get coachQuickActions => 'Quick actions';

  @override
  String get coachCheckin => 'Monthly\ncheck-in';

  @override
  String get coachVerse3a => 'Contribute\n3a';

  @override
  String get coachSimBuyback => 'Simulate\nbuyback';

  @override
  String get coachExplore => 'Explore';

  @override
  String get coachPulseDisclaimer =>
      'Educational estimates — not financial advice. Past returns do not predict future returns. Consult a specialist for a personalized plan. FinSA.';

  @override
  String get eduTheme3aTitle => 'Pillar 3a';

  @override
  String get eduTheme3aQuestion =>
      'What is 3a and why does everyone talk about it?';

  @override
  String get eduTheme3aAction => 'Estimate my tax savings';

  @override
  String get eduTheme3aReminder =>
      'December → Last chance to contribute this year';

  @override
  String get eduThemeLppTitle => 'Pension Fund (LPP)';

  @override
  String get eduThemeLppQuestion => 'Do I have a pension fund?';

  @override
  String get eduThemeLppAction => 'Analyze my pension certificate';

  @override
  String get eduThemeLppReminder =>
      'Request my pension certificate from my employer';

  @override
  String get eduThemeAvsTitle => 'AVS Gaps';

  @override
  String get eduThemeAvsQuestion => 'Do I have missing contribution years?';

  @override
  String get eduThemeAvsAction => 'Check my AVS account statement';

  @override
  String get eduThemeAvsReminder => 'Order my statement on ahv-iv.ch';

  @override
  String get eduThemeEmergencyTitle => 'The Emergency Fund';

  @override
  String get eduThemeEmergencyQuestion => 'How much should I have set aside?';

  @override
  String get eduThemeEmergencyAction => 'Calculate my target';

  @override
  String get eduThemeEmergencyReminder =>
      'Check my safety savings every quarter';

  @override
  String get eduThemeDebtTitle => 'Debts';

  @override
  String get eduThemeDebtQuestion => 'How much is my debt really costing me?';

  @override
  String get eduThemeDebtAction => 'Calculate the total cost';

  @override
  String get eduThemeDebtReminder => 'Priority: pay off debt before investing';

  @override
  String get eduThemeMortgageTitle => 'The Mortgage';

  @override
  String get eduThemeMortgageQuestion =>
      'Fixed or SARON, what\'s the difference?';

  @override
  String get eduThemeMortgageAction => 'Compare the two strategies';

  @override
  String get eduThemeMortgageReminder =>
      'Before renewal: compare 3 months in advance';

  @override
  String get eduThemeBudgetTitle => 'Disposable Income';

  @override
  String get eduThemeBudgetQuestion => 'How much is left after fixed costs?';

  @override
  String get eduThemeBudgetAction => 'Estimate my disposable income';

  @override
  String get eduThemeBudgetReminder => 'Review my budget every month';

  @override
  String get eduThemeLamalTitle => 'Health Insurance Subsidies';

  @override
  String get eduThemeLamalQuestion => 'Am I eligible for premium assistance?';

  @override
  String get eduThemeLamalAction => 'Check my eligibility';

  @override
  String get eduThemeLamalReminder => 'Criteria vary by canton';

  @override
  String get eduThemeFiscalTitle => 'Swiss Taxation';

  @override
  String get eduThemeFiscalQuestion => 'How do taxes work in Switzerland?';

  @override
  String get eduThemeFiscalAction => 'Simulate my 3a savings';

  @override
  String get eduThemeFiscalReminder =>
      'Tax return deadline: March 31 (extendable)';

  @override
  String get eduHubTitle => 'I DON\'T GET IT';

  @override
  String get eduHubSubtitle =>
      'Don\'t panic. Pick a topic, we\'ll explain the essentials and give you a simple action.';

  @override
  String get eduHubReadQuiz => 'Read + quiz • 2 min';

  @override
  String get askMintSuggestDebt =>
      'I have debts — where should I start to get out?';

  @override
  String askMintSuggestAge3a(String age) {
    return 'I\'m $age years old, should I already contribute to pillar 3a?';
  }

  @override
  String askMintSuggestAgeLpp(String age) {
    return 'I\'m $age years old, should I buy back into my pension fund?';
  }

  @override
  String askMintSuggestAgeRetirement(String age) {
    return 'I\'m $age years old, how can I best prepare for retirement?';
  }

  @override
  String get askMintSuggestSelfEmployed =>
      'I\'m self-employed — how do I protect myself without a pension fund?';

  @override
  String get askMintSuggestUnemployed =>
      'I\'m unemployed — what impact on my pension?';

  @override
  String askMintSuggestCanton(String canton) {
    return 'What tax deductions are available in the canton of $canton?';
  }

  @override
  String get askMintSuggestIncome =>
      'With my income, how much can I deduct from taxes per year?';

  @override
  String get askMintSuggestGeneric1 =>
      'Annuity or lump sum — what\'s the difference?';

  @override
  String get askMintSuggestGeneric2 => 'How can I optimize my taxes this year?';

  @override
  String get askMintSuggestGeneric3 =>
      'What is a pension fund buyback and is it worth it?';

  @override
  String get askMintSuggestGeneric4 =>
      'How does the LAMal health insurance franchise work?';

  @override
  String get askMintEmptyBody =>
      'Swiss finance, laws explained, simulators — I\'ll explain everything, with sources.';

  @override
  String get askMintPrivacyBadge => 'Your data stays on your device';

  @override
  String get askMintForYou => 'FOR YOU';

  @override
  String get byokRecommended => 'Recommended';

  @override
  String byokGetKeyOn(String provider) {
    return 'Get a key from $provider';
  }

  @override
  String get byokCopilotActivated => 'Your financial copilot is activated';

  @override
  String get byokCopilotBody =>
      'Ask your first question about Swiss finance — 3rd pillar, taxes, pension fund, budget...';

  @override
  String get byokTryNow => 'Try now';

  @override
  String get trajectoryTitle => 'Your trajectory';

  @override
  String trajectorySubtitle(String years) {
    return '3 scenarios · $years years';
  }

  @override
  String get trajectoryOptimiste => 'Optimistic';

  @override
  String get trajectoryBase => 'Base';

  @override
  String get trajectoryPrudent => 'Conservative';

  @override
  String get trajectoryTauxRemplacement => 'Estimated replacement rate: ';

  @override
  String get trajectoryEmpty => 'No projection available yet';

  @override
  String get trajectoryEmptySub =>
      'Complete your profile to see your trajectory';

  @override
  String get trajectoryDisclaimer =>
      'Educational estimates — not financial advice.';

  @override
  String get trajectoryDragHint => 'Drag to explore';

  @override
  String get trajectoryGoalLabel => 'Target';

  @override
  String get agirTitle => 'ACT';

  @override
  String get agirThisMonth => 'This month';

  @override
  String get agirTimeline => 'Timeline';

  @override
  String get agirTimelineSub => 'Your upcoming deadlines';

  @override
  String get agirHistory => 'History';

  @override
  String get agirHistorySub => 'Your past check-ins';

  @override
  String agirCheckinDone(String month) {
    return 'Check-in $month completed';
  }

  @override
  String get agirDone => 'Done';

  @override
  String agirCheckinCta(String month) {
    return 'Do my check-in $month';
  }

  @override
  String get agirNoCheckin => 'No check-ins yet';

  @override
  String get agirNoCheckinSub =>
      'Do your first check-in to start tracking your progress.';

  @override
  String get agirTimeline3a => 'Last day for 3a contribution';

  @override
  String get agirTimeline3aSub =>
      'Make sure your ceiling is reached before end of December.';

  @override
  String get agirTimeline3aCta => 'Check my 3a';

  @override
  String agirTimelineTax(String canton) {
    return 'Tax declaration $canton';
  }

  @override
  String get agirTimelineTaxSub =>
      'Remember to gather your 3a and LPP certificates.';

  @override
  String get agirTimelineTaxCta => 'Prepare my documents';

  @override
  String get agirTimelineLamal => 'LAMal deductible (change?)';

  @override
  String get agirTimelineLamalSub =>
      'Check if your current deductible is still appropriate.';

  @override
  String get agirTimelineLamalCta => 'Simulate deductibles';

  @override
  String get agirTimelineRetireSub => 'Your main goal.';

  @override
  String get agirAuto => 'Auto';

  @override
  String get agirManuel => 'Manual';

  @override
  String get agirDisclaimer =>
      'Educational tool — not personalized financial advice. Deadlines and projections are indicative. Consult a specialist for tailored guidance. FinSA.';

  @override
  String checkinTitle(String month) {
    return 'CHECK-IN $month';
  }

  @override
  String checkinHeader(String month) {
    return 'Check-in $month';
  }

  @override
  String get checkinSubtitle => 'Confirm your monthly contributions';

  @override
  String get checkinPlannedSection => 'Planned contributions';

  @override
  String get checkinEventsSection => 'Monthly events';

  @override
  String get checkinExpenses => 'Exceptional expenses?';

  @override
  String get checkinExpensesHint => 'E.g.: 2000 (car repair)';

  @override
  String get checkinRevenues => 'Exceptional income?';

  @override
  String get checkinRevenuesHint => 'E.g.: 5000 (annual bonus)';

  @override
  String get checkinNoteSection => 'Monthly note (optional)';

  @override
  String get checkinNoteHint => 'E.g.: Tough month, unexpected car expense...';

  @override
  String get checkinSubmit => 'Submit check-in';

  @override
  String get checkinInvalidAmount => 'Invalid amount';

  @override
  String checkinSuccessTitle(String month) {
    return 'All set. Check-in $month completed.';
  }

  @override
  String get checkinSeeTrajectory => 'See my updated trajectory';

  @override
  String get checkinImpactLabel => 'Impact on your trajectory';

  @override
  String checkinImpactCapital(String amount) {
    return 'Projected capital +$amount this month';
  }

  @override
  String checkinImpactTotal(String amount) {
    return 'Total contributions: $amount';
  }

  @override
  String get checkinStreakLabel => 'Current streak';

  @override
  String checkinStreakCount(String count) {
    return '$count consecutive months on-track!';
  }

  @override
  String get checkinCoachTip => 'Coach tip';

  @override
  String get checkinAuto => 'Auto';

  @override
  String get checkinManuel => 'Manual';

  @override
  String get checkinDisclaimer =>
      'Educational tool — not personalized financial advice. Projections are based on assumptions and may vary. Consult a specialist for tailored guidance. FinSA.';

  @override
  String get checkinAddContribution => 'Add a contribution';

  @override
  String get checkinCategoryLabel => 'Category';

  @override
  String get checkinCat3a => 'Pillar 3a';

  @override
  String get checkinCatLpp => 'LPP buyback';

  @override
  String get checkinCatInvest => 'Investment';

  @override
  String get checkinCatEpargne => 'Free savings';

  @override
  String get checkinLabelField => 'Name';

  @override
  String get checkinLabelHint => 'E.g.: 3a VIAC, Vacation savings...';

  @override
  String get checkinAmountField => 'Monthly amount';

  @override
  String get checkinAutoToggle => 'Standing order (automatic)';

  @override
  String get checkinAddConfirm => 'Add';

  @override
  String get vaultTitle => 'Vault';

  @override
  String get vaultHeaderTitle => 'Your financial vault';

  @override
  String get vaultHeaderSubtitle =>
      'Centralise, understand and act on your documents';

  @override
  String vaultDocCount(String count) {
    return '$count documents';
  }

  @override
  String get vaultCategoryLpp => 'LPP Pension Fund';

  @override
  String get vaultCategorySalary => 'Salary Certificate';

  @override
  String get vaultCategory3a => 'Pillar 3a';

  @override
  String get vaultCategoryInsurance => 'Insurance';

  @override
  String get vaultCategoryLease => 'Lease';

  @override
  String get vaultCategoryLamal => 'Health (LAMal)';

  @override
  String get vaultCategoryOther => 'Other';

  @override
  String vaultCategoryCount(String count) {
    return '$count';
  }

  @override
  String get vaultCategoryNone => 'None';

  @override
  String get vaultGuidanceTitle => 'Legal guidance';

  @override
  String get vaultGuidanceLeaseTitle => 'Lease — Your tenant rights';

  @override
  String get vaultGuidanceLeaseBody =>
      'In Switzerland, rent can be challenged if it exceeds the permissible return (CO art. 269). The legal notice period is 3 months for an apartment, unless otherwise stipulated in the lease. ASLOCA offers free consultations in most cantons.';

  @override
  String get vaultGuidanceLeaseSource => 'CO art. 269-270, OBLF art. 12-13';

  @override
  String get vaultGuidanceInsuranceTitle => 'Insurance — Coverage audit';

  @override
  String get vaultGuidanceInsuranceBody =>
      'Private liability and household insurance are not mandatory in Switzerland but are strongly recommended. Check that your household insured sum covers the actual value of your belongings. Under-insurance can reduce compensation proportionally (ICA art. 69).';

  @override
  String get vaultGuidanceInsuranceSource =>
      'ICA art. 69, General insurance conditions';

  @override
  String get vaultGuidanceLamalTitle => 'LAMal — Deductible optimisation';

  @override
  String get vaultGuidanceLamalBody =>
      'You can change your LAMal deductible every year by November 30 (higher deductible) or December 31 (lower deductible). A healthy adult can save up to CHF 1,500/year with a CHF 2,500 deductible vs CHF 300.';

  @override
  String get vaultGuidanceLamalSource => 'HIA art. 62, HIO art. 93-94';

  @override
  String get vaultGuidanceSalaryTitle => 'Salary — Certificate verification';

  @override
  String get vaultGuidanceSalaryBody =>
      'Your salary certificate (Lohnausweis) is the key document for your tax return. Check that LPP, AHV contributions and family allowances match your payslips. Any error can impact your taxes and pension.';

  @override
  String get vaultGuidanceSalarySource => 'DITA art. 127, FSO form 11';

  @override
  String get vaultUploadTitle => 'What type of document?';

  @override
  String get vaultUploadButton => 'Choose a PDF file';

  @override
  String get vaultEmptyTitle => 'No documents';

  @override
  String get vaultEmptySubtitle =>
      'Add your first document to power your simulations with real data';

  @override
  String get vaultPremiumTitle => 'Premium Vault';

  @override
  String get vaultPremiumBody =>
      'Upgrade to MINT Premium for unlimited document storage and automatic coverage audit';

  @override
  String get vaultPremiumCta => 'Discover Premium';

  @override
  String get vaultDocListTitle => 'My documents';

  @override
  String vaultConfidence(String confidence) {
    return 'Confidence: $confidence%';
  }

  @override
  String get vaultAnalyzing => 'Analyzing...';

  @override
  String get vaultDeleteTitle => 'Delete this document?';

  @override
  String get vaultDeleteMessage => 'This action cannot be undone.';

  @override
  String get vaultDeleteButton => 'Delete';

  @override
  String get vaultPrivacy =>
      'Your documents are analyzed locally and never shared with third parties. You can delete them at any time.';

  @override
  String get vaultDisclaimer =>
      'MINT is an educational tool. Legal information is provided for informational purposes only and does not constitute personalized legal advice (FinSA, nFADP). For specific questions, consult a qualified professional.';

  @override
  String get soaTitle => 'Your Mint Plan';

  @override
  String get soaScoreLabel => 'Financial Health Score';

  @override
  String get soaPrioritiesTitle => 'Your Top 3 Actions';

  @override
  String get soaDiagnosticTitle => 'Diagnostic by Circle';

  @override
  String get soaTaxTitle => 'Tax Simulation';

  @override
  String get soaRetirementTitle => 'Retirement Projection (Age 65)';

  @override
  String get soaLppTitle => 'LPP Buyback Strategy';

  @override
  String get soaBudgetTitle => 'Your Calculated Budget';

  @override
  String get soaTransparencyTitle => 'Transparency & Roadmap';

  @override
  String get soaDisclaimerText =>
      'Educational tool — does not constitute financial advice under FinSA. Amounts are estimates based on declared data.';

  @override
  String get soaNextTitle => 'What\'s next?';

  @override
  String get soaNextSubtitle => 'Modules tailored to your profile';

  @override
  String get soaExportPdf => 'Export PDF';

  @override
  String get soaActionStart => 'Start';

  @override
  String get soaTaxableIncome => 'Taxable income';

  @override
  String get soaDeductions => 'Deductions';

  @override
  String get soaEstimatedTax => 'Estimated tax';

  @override
  String get soaEffectiveRate => 'Effective rate';

  @override
  String get soaCapitalEstimate => 'Estimated capital';

  @override
  String get soaAvsRent => 'Monthly AVS pension';

  @override
  String get soaLppRent => 'Monthly LPP pension';

  @override
  String get soaTotalMonthly => 'TOTAL monthly';

  @override
  String soaAvsGapWarning(String gap) {
    return 'Warning: AVS gaps detected ($gap years)';
  }

  @override
  String soaBuybackYear(String year) {
    return 'Year $year';
  }

  @override
  String soaBuybackAmount(String amount) {
    return 'Buyback: CHF $amount';
  }

  @override
  String soaBuybackSaving(String amount) {
    return 'Savings: CHF $amount';
  }

  @override
  String soaTotalSaving(String amount) {
    return 'Total tax savings: CHF $amount';
  }

  @override
  String soaNature(String nature) {
    return 'Nature: $nature';
  }

  @override
  String get soaAssumptions => 'Working Assumptions';

  @override
  String get soaConflicts => 'Conflicts of Interest & Commissions';

  @override
  String get soaNoConflict =>
      'No conflict of interest identified for this report.';

  @override
  String get soaSafeModeLocked => 'Priority: Debt Reduction';

  @override
  String get soaSafeModeMessage =>
      'Your priority actions have been replaced with a debt reduction plan.';

  @override
  String get soaLimitations => 'Limitations';

  @override
  String get soaProtectionSources => 'Sources: LP art. 93, CSIAS Guidelines';

  @override
  String get soaPrevoyanceSources => 'Sources: LPP art. 14, OPP3, LAVS';

  @override
  String get soaCroissanceSources => 'Sources: LIFD art. 33';

  @override
  String get soaOptimisationSources => 'Sources: CC art. 470, LIFD';

  @override
  String get soaAvailableMonth => 'Available / month';

  @override
  String get soaRemainder => 'Disposable income';

  @override
  String get soaEstimatedTaxLabel => 'Estimated Taxes';

  @override
  String get soaSavingsRate => 'Savings rate';

  @override
  String get soaSavingsGoal => 'Goal: 20%';

  @override
  String get soaProtectionScore => 'Protection Score';

  @override
  String get soaActiveDebts => 'Active debts';

  @override
  String get soaSerene => 'Secure';

  @override
  String get soaNetIncome => 'Net income';

  @override
  String get soaHousing => 'Housing';

  @override
  String get soaDebtRepayment => 'Debt repayment';

  @override
  String get soaAvailable => 'Available';

  @override
  String get soaImportant => 'IMPORTANT:';

  @override
  String get soaDisclaimer1 =>
      'This is an educational tool, not financial advice (FinSA).';

  @override
  String get soaDisclaimer2 =>
      'Amounts are based on the information you provided.';

  @override
  String get soaDisclaimer3 =>
      '\'Available\' = Income - Housing - Debts - Taxes - Health Insurance - Fixed Costs.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get profileCompleteBanner =>
      'Profile complete! Your coach has all the data for reliable advice.';

  @override
  String get profileAnnualRefreshTitle => 'Annual update';

  @override
  String get profileAnnualRefreshBody =>
      'Your data is over 10 months old. A quick check-up (2 min) improves your plan accuracy.';

  @override
  String get profileAnnualRefreshCta => 'Start check-up';

  @override
  String get profileDangerZoneTitle => 'Danger zone';

  @override
  String get profileDangerZoneSubtitle =>
      'Reset your local financial history without deleting your account.';

  @override
  String get profileResetDialogTitle => 'Reset my situation?';

  @override
  String get profileResetDialogBody =>
      'This action deletes your diagnostic, check-ins, score history, and local budget.';

  @override
  String get profileResetDialogConfirmLabel => 'Type RESET to confirm:';

  @override
  String get profileResetDialogInvalid => 'Invalid keyword.';

  @override
  String get profileResetDialogAction => 'Reset';

  @override
  String get profileResetSuccess => 'Local financial history has been reset.';

  @override
  String get profileResetScopeNote =>
      'Keeps login and BYOK key. Backend documents are not deleted.';

  @override
  String get coachPulseTitle => 'Coach Pulse';

  @override
  String get coachIaBadge => 'AI Coach';

  @override
  String get agirCoachPulseDone =>
      'You\'re up to date this month. Focus now on the most impactful action.';

  @override
  String get agirCoachPulsePending =>
      'Your monthly check-in is the next critical action to keep your trajectory reliable.';

  @override
  String agirCoachPulseWhyNow(String reason) {
    return 'Why now: $reason';
  }

  @override
  String get agirScenarioBriefTitle => 'Retirement scenarios at a glance';

  @override
  String agirScenarioBriefSummary(
      String years, String baseCapital, String replacement, String gapCapital) {
    return 'In ~$years years, your Base scenario targets $baseCapital (~$replacement% replacement). The Prudential vs Optimistic gap is $gapCapital.';
  }

  @override
  String get agirScenarioBriefCta => 'Open full simulation';

  @override
  String get advisorMiniWeekOneCta => 'Launch my week 1';

  @override
  String get advisorMiniStartWithDashboard => 'Start with dashboard';

  @override
  String get advisorMiniCoachIntroChallenge =>
      'Goal: move from analysis to action this week. We start now with 3 priorities.';

  @override
  String get checkinScoreReasonStable =>
      'Stable score this month: keep your actions consistent.';

  @override
  String checkinScoreReasonPositiveContrib(String amount) {
    return 'Main increase driver: confirmed contributions ($amount) this month.';
  }

  @override
  String get checkinScoreReasonPositiveIncome =>
      'Main increase driver: exceptional income added this month.';

  @override
  String get checkinScoreReasonPositiveGeneral =>
      'Main increase driver: overall improvement in your financial discipline.';

  @override
  String checkinScoreReasonNegativeExpense(String amount) {
    return 'Main decrease driver: exceptional expenses this month ($amount).';
  }

  @override
  String checkinScoreReasonNegativeContrib(String amount) {
    return 'Main decrease driver: reduced planned contributions ($amount/month).';
  }

  @override
  String get checkinScoreReasonNegativeGeneral =>
      'Temporary decrease this month. We\'ll adjust the plan at the next check-in.';

  @override
  String get checkinImpactPending => 'Impact being calculated';

  @override
  String get coachDataQualityTitle => 'Data quality';

  @override
  String coachDataQualityBody(String dataPoints, String percentage) {
    return 'Current calculation: $dataPoints entered data points ($percentage%). Missing items remain estimated until full diagnostic is completed.';
  }

  @override
  String get coachShockTitle => 'Your key numbers';

  @override
  String get coachShockSubtitle =>
      'Personalized amounts to guide your decisions';

  @override
  String get coachScenarioDecodedTitle => 'Your decoded scenarios';

  @override
  String get coachBadgeStatic => 'Coach';

  @override
  String get agirActionsRecommendedTitle => 'Recommended actions';

  @override
  String get agirActionsRecommendedSubtitle => 'Sorted by priority';

  @override
  String get profileCoachKnowledgeTitle => 'What MINT knows about you';

  @override
  String get profileStateFull => 'Full profile';

  @override
  String get profileStatePartial => 'Partial profile';

  @override
  String get profileStateMissing => 'Profile not completed';

  @override
  String profileCoachKnowledgeSummary(String profileState, String precision,
      String checkins, String scorePart) {
    return '$profileState • Precision $precision% • Check-ins: $checkins$scorePart';
  }

  @override
  String get profileChipEntered => 'entered';

  @override
  String get profileChipEstimated => 'estimated';

  @override
  String get profileChipToComplete => 'to complete';

  @override
  String get coachNarrativeModeConcise => 'Short';

  @override
  String get coachNarrativeModeDetailed => 'Detailed';

  @override
  String get advisorMiniMetricsWinnerLive => 'Live winner';

  @override
  String get advisorMiniMetricsUplift => 'Challenge uplift vs control';

  @override
  String get advisorMiniMetricsSignal => 'Signal';

  @override
  String get advisorMiniMetricsSignalInsufficient =>
      'Wait for >=10 starts per variant';

  @override
  String get profileCoachMonthlyTitle => 'Monthly coach summary';

  @override
  String get profileCoachMonthlyTrendInsufficient =>
      'Not enough check-ins yet for a monthly trend.';

  @override
  String profileCoachMonthlyTrendUp(String delta) {
    return '+$delta points this month, good momentum.';
  }

  @override
  String profileCoachMonthlyTrendDown(String delta) {
    return '-$delta points this month, priorities need rebalancing.';
  }

  @override
  String get profileCoachMonthlyTrendFlat =>
      'Stable score this month, keep the rhythm.';

  @override
  String profileCoachMonthlyByokPrefix(String trend) {
    return 'AI coach read: $trend';
  }

  @override
  String get profileCoachMonthlyActionComplete =>
      'Next step: complete your diagnosis to improve recommendation quality.';

  @override
  String get profileCoachMonthlyActionCheckin =>
      'Next step: complete your monthly check-in to recalibrate the plan.';

  @override
  String get profileCoachMonthlyActionAgir =>
      'Next step: execute one priority action in Agir.';

  @override
  String get profileGuidanceTitle => 'Recommended section';

  @override
  String profileGuidanceBody(String section) {
    return 'Complete $section now to make your plan more reliable.';
  }

  @override
  String profileGuidanceCta(String section) {
    return 'Complete $section';
  }

  @override
  String get advisorMiniMetricsLiveTitle => 'Live onboarding quality';

  @override
  String get advisorMiniMetricsLiveStep => 'Current step';

  @override
  String get advisorMiniMetricsLiveQuality => 'Quality score';

  @override
  String get advisorMiniMetricsLiveNext => 'Recommended section';

  @override
  String get coachPersonaPriorityCouple => 'Couple priority';

  @override
  String get coachPersonaPriorityFamily => 'Family priority';

  @override
  String get coachPersonaPrioritySingleParent => 'Single-parent priority';

  @override
  String get coachPersonaPrioritySingle => 'Personal priority';

  @override
  String get coachWizardSectionIdentity => 'Identity & household';

  @override
  String get coachWizardSectionIncome => 'Income & household';

  @override
  String get coachWizardSectionPension => 'Pension';

  @override
  String get coachWizardSectionProperty => 'Property & debt';

  @override
  String coachPersonaGuidanceCouple(String section) {
    return 'To stabilize household projections, complete $section now.';
  }

  @override
  String coachPersonaGuidanceSingleParent(String section) {
    return 'Your plan depends on household protection. Complete $section now.';
  }

  @override
  String coachPersonaGuidanceSingle(String section) {
    return 'To personalize your coach plan, complete $section now.';
  }

  @override
  String coachEnrichTargetTitle(String current, String target) {
    return 'Move from $current% to $target% precision';
  }

  @override
  String get coachEnrichBodyIdentity =>
      'Add identity/household basics to activate reliable calculations today.';

  @override
  String get coachEnrichBodyIncome =>
      'Complete income and household structure for truly personalized recommendations.';

  @override
  String get coachEnrichBodyPension =>
      'Add AVS/LPP/3a details for an actionable retirement projection.';

  @override
  String get coachEnrichBodyProperty =>
      'Add property and debts to calibrate real budget and risk.';

  @override
  String get coachEnrichBodyDefault =>
      'The full diagnostic takes 10 minutes and unlocks your personalized trajectory.';

  @override
  String get coachEnrichActionIdentity => 'Complete Identity & household';

  @override
  String get coachEnrichActionIncome => 'Complete Income & household';

  @override
  String get coachEnrichActionPension => 'Complete Pension';

  @override
  String get coachEnrichActionProperty => 'Complete Property & debt';

  @override
  String get coachEnrichActionDefault => 'Complete my diagnosis';

  @override
  String coachAgirPartialTitle(String quality) {
    return 'Plan in progress ($quality%)';
  }

  @override
  String coachAgirPartialBody(String section) {
    return 'To activate your priority actions, complete $section now.';
  }

  @override
  String coachAgirPartialAction(String section) {
    return 'Complete $section';
  }

  @override
  String get landingTagline => 'Your Swiss financial coach';

  @override
  String get landingRegister => 'Sign up';

  @override
  String get landingHeroRetirementNow1 => 'Your retirement,';

  @override
  String get landingHeroRetirementNow2 => 'it\'s now.';

  @override
  String landingHeroCountdown1(String years) {
    return 'In $years years,';
  }

  @override
  String get landingHeroCountdown1Single => 'In 1 year,';

  @override
  String get landingHeroCountdown2 => 'your retirement begins.';

  @override
  String get landingHeroSubtitle =>
      'Most Swiss residents discover their retirement gap too late.';

  @override
  String get landingSliderAge => 'Your age';

  @override
  String landingSliderAgeSuffix(String age) {
    return '$age years';
  }

  @override
  String get landingSliderSalary => 'Your gross salary';

  @override
  String landingSliderSalarySuffix(String amount) {
    return '$amount CHF/year';
  }

  @override
  String get landingToday => 'Today';

  @override
  String get landingChfPerMonth => 'CHF/month';

  @override
  String get landingAtRetirement => 'At retirement*';

  @override
  String landingDropPurchasingPower(String percent) {
    return '-$percent% purchasing power';
  }

  @override
  String landingLppCapNotice(String amount) {
    return 'Above $amount CHF/year, the mandatory pension is capped.';
  }

  @override
  String landingHookHigh(String amount) {
    return 'A gap of $amount/month is significant. MINT helps you understand where to act.';
  }

  @override
  String get landingHookMedium =>
      'Your gap is manageable. MINT shows you concrete levers (LPP buyback, 3a, early retirement).';

  @override
  String get landingHookLow =>
      'You\'re in good shape. MINT shows you how to stay on track and optimise your pillars.';

  @override
  String get landingWhyMint => 'Why MINT?';

  @override
  String get landingFeaturePillarsTitle => 'All your pillars, one dashboard';

  @override
  String get landingFeaturePillarsSubtitle =>
      'AVS, LPP and 3a calculated for your real situation — not Swiss averages.';

  @override
  String get landingFeatureCoachTitle => 'Coach adapted to your life stage';

  @override
  String get landingFeatureCoachSubtitle =>
      '25 or 60, cross-border or self-employed — advice changes based on who you are.';

  @override
  String get landingFeaturePrivacyTitle => '100% private, data on your device';

  @override
  String get landingFeaturePrivacySubtitle =>
      'No sharing, no ads. Your profile stays local unless you create an account.';

  @override
  String get landingTrustSwiss => 'Made in Switzerland';

  @override
  String get landingTrustPrivate => '100% private';

  @override
  String get landingTrustNoCommitment => 'No commitment';

  @override
  String get landingCtaTitle => 'Your plan in 30 seconds';

  @override
  String get landingCtaSubtitle => '3 questions • Free • No commitment';

  @override
  String get landingLegalFooter =>
      '*Indicative estimate (1st + 2nd pillar), based on current salary as career proxy. Does not constitute financial advice under FinSA. Your data stays on your device.';

  @override
  String get onboardingConsentTitle => 'Local save of answers';

  @override
  String get onboardingConsentBody =>
      'Your answers can be saved locally on your device to resume later. No data is sent without your consent.';

  @override
  String get onboardingConsentAllow => 'Allow';

  @override
  String get onboardingConsentContinueWithout => 'Continue without saving';

  @override
  String get profileBilanTitle => 'My financial overview';

  @override
  String get profileBilanSubtitleComplete => 'Income, pension, assets, debts';

  @override
  String get profileBilanSubtitleIncomplete =>
      'Complete your profile to see your numbers';

  @override
  String get profileFamilyTitle => 'Family';

  @override
  String get profileHouseholdTitle => 'Our household';

  @override
  String get profileHouseholdStatus => 'Couple+';

  @override
  String get profileAiSlmTitle => 'On-device AI (SLM)';

  @override
  String get profileAiSlmReady => 'Model ready';

  @override
  String get profileAiSlmNotInstalled => 'Model not installed';

  @override
  String get profileLanguageTitle => 'Language';

  @override
  String get profileAdminObservability => 'Admin observability';

  @override
  String get profileAdminAnalytics => 'Beta tester analytics';

  @override
  String get profileDeleteCloudAccount => 'Delete my cloud account';

  @override
  String get profileDeleteCloudTitle => 'Delete account?';

  @override
  String get profileDeleteCloudBody =>
      'This action deletes your cloud account and associated data. Your local data remains on this device.';

  @override
  String get profileDeleteCloudConfirm => 'Delete';

  @override
  String get profileDeleteCloudSuccess => 'Account deleted successfully.';

  @override
  String get profileDeleteCloudError =>
      'Deletion not possible at the moment. Please try again later.';

  @override
  String get dashboardDefaultUserName => 'You';

  @override
  String get dashboardDefaultConjointName => 'Partner';

  @override
  String get dashboardGoalRetirement => 'Retirement';

  @override
  String dashboardAppBarWithName(String firstName) {
    return 'Retirement · $firstName';
  }

  @override
  String get dashboardAppBarDefault => 'My dashboard';

  @override
  String get dashboardMyData => 'My data';

  @override
  String get dashboardQuickStartTitle =>
      'Discover your projection in 30 seconds';

  @override
  String get dashboardQuickStartBody =>
      '4 inputs are enough to estimate your retirement income. You can refine with documents and details.';

  @override
  String get dashboardQuickStartCta => 'Start';

  @override
  String get dashboardEnrichScanTitle => 'Scan your LPP certificate';

  @override
  String get dashboardEnrichScanImpact => '+20 pts precision';

  @override
  String get dashboardEnrichCoachTitle => 'Talk to the Coach';

  @override
  String get dashboardEnrichCoachImpact => 'Get your questions answered';

  @override
  String get dashboardEnrichSimTitle => 'Run a simulation';

  @override
  String get dashboardEnrichSimImpact => '3a, LPP, mortgage...';

  @override
  String get dashboardNextSteps => 'Next steps';

  @override
  String get dashboardEduTitle => 'The Swiss retirement system';

  @override
  String get dashboardEduAvs => '1st pillar — AVS';

  @override
  String get dashboardEduAvsDesc =>
      'Mandatory base for everyone. Funded by your contributions (LAVS art. 21).';

  @override
  String get dashboardEduLpp => '2nd pillar — LPP';

  @override
  String get dashboardEduLppDesc =>
      'Occupational pension via your pension fund (LPP art. 14).';

  @override
  String get dashboardEdu3a => '3rd pillar — 3a';

  @override
  String get dashboardEdu3aDesc =>
      'Voluntary savings with tax deduction (OPP3 art. 7).';

  @override
  String get dashboardDisclaimer =>
      'Simplified educational tool. Does not constitute financial advice (FinSA). Sources: LAVS art. 21-29, LPP art. 14, OPP3 art. 7.';

  @override
  String get dashboardCockpitLink => 'Detailed cockpit';

  @override
  String dashboardImpactEstimate(String amount) {
    return 'Estimated impact: CHF $amount';
  }

  @override
  String get dashboardMetricMonthlyIncome => 'Monthly income';

  @override
  String get dashboardMetricChfMonth => 'CHF/month';

  @override
  String get dashboardMetricReplacementRate => 'Replacement rate';

  @override
  String get dashboardMetricRetirementDuration =>
      'Estimated retirement duration';

  @override
  String get dashboardMetricYears => 'years';

  @override
  String get dashboardMetricLifeExpectancy =>
      'Estimated life expectancy: 85 years';

  @override
  String get dashboardMetricMonthlyGap => 'Monthly gap';

  @override
  String get dashboardMetricVsTarget => 'Vs target 70% of gross salary';

  @override
  String get dashboardNextActionLabel => 'Improve your precision';

  @override
  String get dashboardNextActionDetail =>
      'Scan your LPP certificate to refine your projections.';

  @override
  String get dashboardWeatherSunny => 'Favorable markets, maximized savings.';

  @override
  String get dashboardWeatherPartlyCloudy =>
      'Current trajectory, some adjustments.';

  @override
  String get dashboardWeatherRainy => 'Market shocks or AVS/LPP gaps.';

  @override
  String get dashboardAgeBandYoungTitle => 'Your main lever: pillar 3a';

  @override
  String get dashboardAgeBandYoungSubtitle =>
      'Every franc invested now works for 40 years. Opening your 3a takes 15 minutes.';

  @override
  String get dashboardAgeBandYoungCta => 'Simulate my 3a';

  @override
  String get dashboardAgeBandStabTitle => '3a + family protection';

  @override
  String get dashboardAgeBandStabSubtitle =>
      'Housing, death/disability coverage: now is the time to build the architecture.';

  @override
  String get dashboardAgeBandStabCta => 'See simulators';

  @override
  String get dashboardAgeBandPeakTitle => 'LPP buyback + tax optimization';

  @override
  String get dashboardAgeBandPeakSubtitle =>
      'Your income is at its peak — this is the window to reduce the retirement gap.';

  @override
  String get dashboardAgeBandPeakCta => 'Simulate a buyback';

  @override
  String get dashboardAgeBandPreRetTitle => 'Your retirement gap in CHF/month';

  @override
  String get dashboardAgeBandPreRetSubtitle =>
      'Annuity vs capital, early retirement, staggered buyback: decisions are approaching.';

  @override
  String get dashboardAgeBandPreRetCta => 'Annuity vs Capital';

  @override
  String get dashboardAgeBandRetWithdrawTitle => '3a withdrawal order';

  @override
  String get dashboardAgeBandRetWithdrawSubtitle =>
      'Staggering your 3a withdrawals over 3–5 years significantly reduces tax depending on canton.';

  @override
  String get dashboardAgeBandRetWithdrawCta => 'Plan my withdrawals';

  @override
  String get dashboardAgeBandRetSuccessionTitle =>
      'Succession & estate planning';

  @override
  String get dashboardAgeBandRetSuccessionSubtitle =>
      'Will, lifetime donation, LPP beneficiaries: protecting those you love.';

  @override
  String get dashboardAgeBandRetSuccessionCta => 'Explore';

  @override
  String get agirResetTooltip => 'Reset';

  @override
  String get agirResetHistoryLabel => 'Reset my coach history';

  @override
  String get agirResetDiagnosticLabel => 'Restart my diagnostic';

  @override
  String get agirResetHistoryTitle => 'Reset your coach history?';

  @override
  String get agirResetHistoryMessage =>
      'This deletes your check-ins, score history and simulator progress.';

  @override
  String get agirResetHistoryCta => 'Reset';

  @override
  String get agirResetDiagnosticTitle => 'Restart your diagnostic?';

  @override
  String get agirResetDiagnosticMessage =>
      'This deletes your current diagnostic and mini-onboarding answers.';

  @override
  String get agirResetDiagnosticCta => 'Restart';

  @override
  String get agirHistoryResetSnackbar => 'Coach history reset.';

  @override
  String get agirSwipeDone => 'Done';

  @override
  String get agirSwipeSnooze => 'Snooze 30d';

  @override
  String agirSwipeDoneSnackbar(String title) {
    return '$title — marked as done';
  }

  @override
  String agirSwipeSnoozeSnackbar(String title) {
    return '$title — postponed 30 days';
  }

  @override
  String get agirDependencyDebt => 'After: debt repayment';

  @override
  String get agirEmptyTitle => 'Your action plan awaits';

  @override
  String get agirEmptyBody =>
      'Complete your diagnostic to get a personalized monthly plan based on your real situation.';

  @override
  String get agirEmptyLaunchCta => 'Launch my diagnostic — 10 min';

  @override
  String get agirNoContribTitle => 'No planned contributions';

  @override
  String get agirNoContribBody =>
      'Do your first check-in to set up your monthly contributions.';

  @override
  String get agirNoContribCta => 'Set up my contributions';

  @override
  String get agirProgressTitle => 'Annual progress';

  @override
  String agirProgressSubtitle(String year) {
    return 'Planned vs paid in $year';
  }

  @override
  String get agirConfirmLabel => 'To confirm';

  @override
  String agirVersesLabel(String amount) {
    return '$amount paid';
  }

  @override
  String agirObjectifLabel(String amount) {
    return 'Target: $amount';
  }

  @override
  String get agirPriorityImmediate => 'Immediate priority';

  @override
  String get agirPriorityTrimestre => 'This quarter';

  @override
  String get agirPriorityAnnee => 'This year';

  @override
  String get agirPriorityLongTerme => 'Long term';

  @override
  String get agirTimelineCheckinTitle => 'Monthly check-in';

  @override
  String get agirTimelineCheckinDone =>
      'Done — contributions confirmed for this month.';

  @override
  String get agirTimelineCheckinPending =>
      'Confirm your monthly contributions in 2 min.';

  @override
  String get agirTimelineCheckinCta => 'Do my check-in';

  @override
  String agirTimelineRetirementTitle(String name) {
    return 'Retirement $name (65 years)';
  }

  @override
  String get agirTimelineThisMonth => 'This month';

  @override
  String agirTimelineInMonths(String months) {
    return 'in $months months';
  }

  @override
  String agirTimelineInYears(String years) {
    return 'in $years years';
  }

  @override
  String get agirTimelineInOneYear => 'in 1 year';

  @override
  String get agirPerYear => '/yr';

  @override
  String get agirCoachPulseWhyDefault =>
      'Start with a simple action to build your momentum.';

  @override
  String get checkinScoreTitle => 'Your financial score';

  @override
  String checkinScorePositive(String delta) {
    return '+$delta pts — your actions are paying off!';
  }

  @override
  String checkinScoreNegative(String delta) {
    return '$delta pts — keep going, every month counts';
  }

  @override
  String get budgetEmptyTitle => 'Your budget builds itself automatically';

  @override
  String get budgetEmptyBody =>
      'Complete your diagnosis to unlock your monthly plan with your real income and expenses.';

  @override
  String get budgetEmptyAction => 'Start my diagnosis';

  @override
  String get budgetMonthlyTitle => 'Monthly Budget';

  @override
  String get budgetAvailableThisMonth => 'Available this month';

  @override
  String get budgetNetIncome => 'Net income';

  @override
  String get budgetHousing => 'Housing';

  @override
  String get budgetDebtRepayment => 'Debt repayment';

  @override
  String get budgetDebts => 'Debts';

  @override
  String get budgetTaxProvision => 'Tax provision';

  @override
  String get budgetHealthInsurance => 'Health insurance (LAMal)';

  @override
  String get budgetOtherFixed => 'Other fixed costs';

  @override
  String get budgetNotProvided => '(not provided)';

  @override
  String get budgetQualityEstimated => 'estimated';

  @override
  String get budgetQualityEntered => 'entered';

  @override
  String get budgetQualityMissing => 'missing';

  @override
  String get budgetAvailable => 'Available';

  @override
  String get budgetMissingDataBanner =>
      'Some expenses are still missing. Complete your diagnosis to make this budget more reliable.';

  @override
  String get budgetEstimatedDataBanner =>
      'This budget includes estimates (taxes/LAMal). Enter your actual amounts for a more reliable projection.';

  @override
  String get budgetCompleteData => 'Complete my data →';

  @override
  String get budgetEnvelopeFuture => '🔒 Future (Savings, Projects)';

  @override
  String get budgetEnvelopeVariables => '🛍️ Variable (Living)';

  @override
  String get budgetNeeds => 'Needs';

  @override
  String get budgetLife => 'Living';

  @override
  String get budgetFuture => 'Future';

  @override
  String get budgetVariables => 'Variable';

  @override
  String get budgetExampleRent => 'Rent';

  @override
  String get budgetExampleLamal => 'LAMal';

  @override
  String get budgetExampleTaxes => 'taxes';

  @override
  String get budgetExampleDebts => 'debts';

  @override
  String get budgetExampleFood => 'Food';

  @override
  String get budgetExampleTransport => 'transport';

  @override
  String get budgetExampleLeisure => 'leisure';

  @override
  String get budgetExampleSavings => 'Savings';

  @override
  String get budgetExampleProjects => 'projects';

  @override
  String budgetChiffreChoc503020(String monthly, String total) {
    return 'By saving CHF $monthly/month, you accumulate CHF $total in 10 years.';
  }

  @override
  String get budgetEmergencyFund => 'Emergency fund';

  @override
  String get budgetEmergencyGoalReached => 'Goal reached';

  @override
  String get budgetEmergencyOnTrack => 'On track';

  @override
  String get budgetEmergencyToReinforce => 'Needs reinforcement';

  @override
  String budgetEmergencyMonthsCovered(String months) {
    return '$months months covered';
  }

  @override
  String budgetEmergencyTarget(String target) {
    return 'Target: $target months';
  }

  @override
  String get budgetEmergencyComplete =>
      'You are protected against unexpected events. Keep it up.';

  @override
  String budgetEmergencyIncomplete(String target) {
    return 'Save at least $target months of expenses to protect yourself against unexpected events (job loss, repairs...).';
  }

  @override
  String get budgetDisclaimerTitle => 'IMPORTANT:';

  @override
  String get budgetDisclaimerEducational =>
      '• This is an educational tool, not financial advice (FinSA).';

  @override
  String get budgetDisclaimerDeclarative =>
      '• Amounts are based on declared information.';

  @override
  String get budgetDisclaimerFormula =>
      '• \'Available\' = Income - Housing - Debts - Taxes - LAMal - Fixed costs.';

  @override
  String get toolsAllTools => 'All tools';

  @override
  String get toolsSearchHint => 'Search for a tool...';

  @override
  String toolsToolCount(String count) {
    return '$count tools';
  }

  @override
  String toolsCategoryCount(String count) {
    return '$count categories';
  }

  @override
  String get toolsClear => 'Clear';

  @override
  String get toolsNoResults => 'No tool found';

  @override
  String get toolsNoResultsHint => 'Try other keywords';

  @override
  String get toolsCatPrevoyance => 'Pension planning';

  @override
  String get toolsRetirementPlanner => 'Retirement planner';

  @override
  String get toolsRetirementPlannerDesc =>
      'Simulate your AVS + LPP + 3a retirement';

  @override
  String get toolsSimulator3a => '3a Simulator';

  @override
  String get toolsSimulator3aDesc => 'Calculate your annual tax savings';

  @override
  String get toolsComparator3a => '3a Comparator';

  @override
  String get toolsComparator3aDesc => 'Compare providers (bank vs insurance)';

  @override
  String get toolsRealReturn3a => '3a real return';

  @override
  String get toolsRealReturn3aDesc => 'Net return after fees and inflation';

  @override
  String get toolsStaggeredWithdrawal3a => 'Staggered 3a withdrawal';

  @override
  String get toolsStaggeredWithdrawal3aDesc =>
      'Optimize withdrawal over several years';

  @override
  String get toolsRenteVsCapital => 'Annuity vs Capital';

  @override
  String get toolsRenteVsCapitalDesc =>
      'Compare LPP annuity and capital withdrawal';

  @override
  String get toolsRachatLpp => 'Staggered LPP buyback';

  @override
  String get toolsRachatLppDesc =>
      'Optimize your LPP buybacks over several years';

  @override
  String get toolsLibrePassage => 'Vested benefits';

  @override
  String get toolsLibrePassageDesc => 'Job change or departure checklist';

  @override
  String get toolsDisabilityGap => 'Safety net';

  @override
  String get toolsDisabilityGapDesc => 'Simulate your disability/death gap';

  @override
  String get toolsGenderGap => 'Pension gender gap';

  @override
  String get toolsGenderGapDesc =>
      'Impact of part-time work on your retirement';

  @override
  String get toolsCatFamily => 'Family';

  @override
  String get toolsMarriage => 'Marriage & taxes';

  @override
  String get toolsMarriageDesc => 'Marriage penalty/bonus + regimes + survivor';

  @override
  String get toolsBirth => 'Birth & family';

  @override
  String get toolsBirthDesc => 'Parental leave, allowances, tax impact';

  @override
  String get toolsConcubinage => 'Marriage vs Cohabitation';

  @override
  String get toolsConcubinageDesc => 'Comparator + protection checklist';

  @override
  String get toolsDivorce => 'Divorce simulator';

  @override
  String get toolsDivorceDesc => 'Financial impact of divorce on LPP';

  @override
  String get toolsSuccession => 'Inheritance simulator';

  @override
  String get toolsSuccessionDesc => 'Calculate legal shares and taxes';

  @override
  String get toolsCatEmployment => 'Employment';

  @override
  String get toolsFirstJob => 'First job';

  @override
  String get toolsFirstJobDesc => 'Understand your payslip and your rights';

  @override
  String get toolsUnemployment => 'Unemployment simulator';

  @override
  String get toolsUnemploymentDesc => 'Calculate your benefits and duration';

  @override
  String get toolsJobComparison => 'Job comparator';

  @override
  String get toolsJobComparisonDesc =>
      'Compare two offers (net + LPP + benefits)';

  @override
  String get toolsSelfEmployed => 'Self-employed';

  @override
  String get toolsSelfEmployedDesc => 'Social coverage and protection';

  @override
  String get toolsAvsContributions => 'AVS contributions (self-empl.)';

  @override
  String get toolsAvsContributionsDesc =>
      'Calculate your AVS/AI/APG contributions';

  @override
  String get toolsIjm => 'Daily sickness benefit';

  @override
  String get toolsIjmDesc => 'Daily sickness benefit insurance';

  @override
  String get tools3aSelfEmployed => '3a self-employed';

  @override
  String get tools3aSelfEmployedDesc => 'Higher ceiling for self-employed';

  @override
  String get toolsDividendVsSalary => 'Dividend vs Salary';

  @override
  String get toolsDividendVsSalaryDesc =>
      'Optimize your compensation in SA/Sàrl';

  @override
  String get toolsLppVoluntary => 'Voluntary LPP';

  @override
  String get toolsLppVoluntaryDesc => 'Optional pension for self-employed';

  @override
  String get toolsCrossBorder => 'Cross-border worker';

  @override
  String get toolsCrossBorderDesc =>
      'Withholding tax, 90-day rule, social charges';

  @override
  String get toolsExpatriation => 'Expatriation';

  @override
  String get toolsExpatriationDesc => 'Lump-sum tax, departure, AVS gaps';

  @override
  String get toolsCatRealEstate => 'Real estate';

  @override
  String get toolsAffordability => 'Buying capacity';

  @override
  String get toolsAffordabilityDesc => 'Calculate the max price you can afford';

  @override
  String get toolsAmortization => 'Amortization plan';

  @override
  String get toolsAmortizationDesc => 'Mortgage repayment schedule';

  @override
  String get toolsSaronVsFixed => 'SARON vs Fixed';

  @override
  String get toolsSaronVsFixedDesc => 'Compare mortgage types';

  @override
  String get toolsImputedRental => 'Imputed rental value';

  @override
  String get toolsImputedRentalDesc => 'Estimate the imputed rental value';

  @override
  String get toolsEplCombined => 'Combined EPL';

  @override
  String get toolsEplCombinedDesc => 'Early LPP + 3a withdrawal for housing';

  @override
  String get toolsEplLpp => 'EPL withdrawal (LPP)';

  @override
  String get toolsEplLppDesc => 'Finance housing with your 2nd pillar';

  @override
  String get toolsCatTax => 'Taxation';

  @override
  String get toolsFiscalComparator => 'Tax comparator';

  @override
  String get toolsFiscalComparatorDesc =>
      'Compare your tax burden across cantons';

  @override
  String get toolsCompoundInterest => 'Compound interest';

  @override
  String get toolsCompoundInterestDesc =>
      'Visualize the growth of your savings';

  @override
  String get toolsCatHealth => 'Health';

  @override
  String get toolsLamalDeductible => 'LAMal deductible';

  @override
  String get toolsLamalDeductibleDesc => 'Find the ideal deductible for you';

  @override
  String get toolsCoverageCheckup => 'Coverage check-up';

  @override
  String get toolsCoverageCheckupDesc => 'Evaluate your insurance protection';

  @override
  String get toolsCatBudgetDebt => 'Budget & Debts';

  @override
  String get toolsBudget => 'Budget';

  @override
  String get toolsBudgetDesc => 'Plan and track your monthly expenses';

  @override
  String get toolsDebtCheck => 'Debt check';

  @override
  String get toolsDebtCheckDesc => 'Assess your over-indebtedness risk';

  @override
  String get toolsDebtRatio => 'Debt ratio';

  @override
  String get toolsDebtRatioDesc => 'Visual diagnosis of your situation';

  @override
  String get toolsRepaymentPlan => 'Repayment plan';

  @override
  String get toolsRepaymentPlanDesc => 'Adapted strategy to repay';

  @override
  String get toolsDebtHelp => 'Help & resources';

  @override
  String get toolsDebtHelpDesc => 'Contacts and support organizations';

  @override
  String get toolsConsumerCredit => 'Consumer credit';

  @override
  String get toolsConsumerCreditDesc => 'Simulate the real cost of a loan';

  @override
  String get toolsLeasing => 'Leasing calculator';

  @override
  String get toolsLeasingDesc => 'Real cost and alternatives to leasing';

  @override
  String get toolsCatBankDocs => 'Banking & Documents';

  @override
  String get toolsOpenBanking => 'Open Banking';

  @override
  String get toolsOpenBankingDesc => 'Connect your bank accounts';

  @override
  String get toolsBankImport => 'Bank import';

  @override
  String get toolsBankImportDesc => 'Import your CSV/PDF statements';

  @override
  String get toolsDocuments => 'My documents';

  @override
  String get toolsDocumentsDesc => 'LPP certificates and important documents';

  @override
  String get toolsPortfolio => 'Portfolio';

  @override
  String get toolsPortfolioDesc => 'Overview of your situation';

  @override
  String get toolsTimeline => 'Timeline';

  @override
  String get toolsTimelineDesc => 'Your deadlines and important reminders';

  @override
  String get toolsConsent => 'Consents';

  @override
  String get toolsConsentDesc => 'Manage your data permissions';

  @override
  String get vaultPremiumBadge => 'Premium';

  @override
  String get vaultExtractedFields => 'Extracted fields';

  @override
  String get vaultCancelButton => 'Cancel';

  @override
  String get vaultOkButton => 'OK';

  @override
  String get naissanceTitle => 'Birth & family';

  @override
  String get naissanceTabConge => 'Leave';

  @override
  String get naissanceTabAllocations => 'Allowances';

  @override
  String get naissanceTabImpact => 'Impact';

  @override
  String get naissanceTabChecklist => 'Checklist';

  @override
  String get naissanceLeaveType => 'Leave type';

  @override
  String get naissanceMother => 'Mother';

  @override
  String get naissanceFather => 'Father';

  @override
  String get naissanceMonthlySalary => 'Gross monthly salary';

  @override
  String naissanceCongeLabel(String type) {
    return '$type LEAVE';
  }

  @override
  String naissanceWeeks(int count) {
    return '$count weeks';
  }

  @override
  String get naissanceApgPerDay => 'APG per day';

  @override
  String get naissanceTotalApg => 'Total APG';

  @override
  String naissanceCappedAt(String amount) {
    return 'Capped at CHF $amount/day';
  }

  @override
  String get naissanceDailyDetail => 'DAILY DETAIL';

  @override
  String get naissanceSalaryPerDay => 'Salary/day';

  @override
  String get naissanceApgDay => 'APG/day';

  @override
  String get naissanceDiffPerDay => 'Difference/day';

  @override
  String get naissanceNoLoss => 'No loss';

  @override
  String naissanceTotalLossEstimated(String amount) {
    return 'Total estimated loss during leave: $amount';
  }

  @override
  String naissanceChiffreChocText(String type, String amount, int weeks) {
    return 'Your $type leave represents $amount in APG over $weeks weeks';
  }

  @override
  String get naissanceMaternite => 'maternity';

  @override
  String get naissancePaternite => 'paternity';

  @override
  String get naissanceCongeEducational =>
      'Switzerland only introduced paternity leave in 2021. At 2 weeks, it remains one of the shortest in Europe. Maternity leave (14 weeks) has existed since 2005.';

  @override
  String get naissanceCanton => 'Canton';

  @override
  String get naissanceNbEnfants => 'Number of children';

  @override
  String get naissanceRanking26 => 'ALLOWANCES BY CANTON';

  @override
  String naissanceBestCanton(String canton) {
    return '$canton offers some of the most generous family allowances in Switzerland!';
  }

  @override
  String naissanceAllocDiff(String bestCanton, String canton, String amount) {
    return 'By living in $bestCanton instead of $canton, you would receive $amount more per year in family allowances.';
  }

  @override
  String get naissanceRevenuAnnuel => 'Gross annual income';

  @override
  String get naissanceFraisGarde => 'Monthly childcare costs/child';

  @override
  String get naissanceTaxSavings => 'Tax savings';

  @override
  String get naissanceDeductionPerChild => 'Deduction per child';

  @override
  String get naissanceDeductionChildcare => 'Childcare cost deduction';

  @override
  String get naissanceEstimatedTaxSaving => 'Estimated tax saving';

  @override
  String get naissanceAllowanceIncome => 'Allowance income';

  @override
  String get naissanceAnnualAllowances => 'Annual allowances';

  @override
  String get naissanceCareerImpact => 'Career impact (LPP)';

  @override
  String get naissanceEstimatedInterruption => 'Estimated interruption';

  @override
  String naissanceMonths(int count) {
    return '$count months';
  }

  @override
  String get naissanceLppLossEstimated => 'Estimated LPP loss';

  @override
  String get naissanceLppLessContributions =>
      'Fewer LPP contributions = less retirement capital';

  @override
  String get naissanceNetAnnualImpact => 'Estimated annual net impact';

  @override
  String get naissanceNetFormula => 'Tax savings + allowances - estimated cost';

  @override
  String get naissanceWaterfallRevenu => 'Gross annual income';

  @override
  String get naissanceWaterfallAlloc => 'Family allowances';

  @override
  String get naissanceWaterfallCosts => 'Base costs (est.)';

  @override
  String get naissanceWaterfallChildcare => 'Annual childcare costs';

  @override
  String get naissanceWaterfallAfter => 'After child(ren)';

  @override
  String get naissanceChildCostEducational =>
      'A child costs on average CHF 1,500/month in Switzerland (food, clothing, activities, insurance). But allowances and tax deductions significantly reduce the net impact.';

  @override
  String get naissanceChecklistIntro =>
      'The arrival of a child involves many administrative and financial steps. Here are the steps not to forget.';

  @override
  String naissanceStepsCompleted(int done, int total) {
    return '$done/$total steps completed';
  }

  @override
  String get naissanceDidYouKnow => 'Did you know?';

  @override
  String get naissanceDisclaimer =>
      'Simplified estimates for educational purposes — not financial or tax advice. Amounts depend on many factors (canton, municipality, family situation, etc.). Consult a specialist for a personalized calculation.';

  @override
  String get mariageTitle => 'Marriage & taxation';

  @override
  String get mariageTabImpots => 'Taxes';

  @override
  String get mariageTabRegime => 'Regime';

  @override
  String get mariageTabProtection => 'Protection';

  @override
  String get mariageRevenu1 => 'Income 1';

  @override
  String get mariageRevenu2 => 'Income 2';

  @override
  String get mariageCanton => 'Canton';

  @override
  String get mariageEnfants => 'Children';

  @override
  String get mariageFiscalComparison => 'TAX COMPARISON';

  @override
  String get mariageTwoCelibataires => '2 singles';

  @override
  String get mariageMaries => 'Married';

  @override
  String mariagePenaltyAmount(String amount) {
    return 'Penalty +$amount/year';
  }

  @override
  String mariageBonusAmount(String amount) {
    return 'Bonus -$amount/year';
  }

  @override
  String get mariageDeductions => 'MARRIAGE DEDUCTIONS';

  @override
  String get mariageDeductionCouple => 'Married couple deduction';

  @override
  String get mariageDeductionInsurance => 'Insurance deduction (married)';

  @override
  String get mariageDeductionDualIncome => 'Dual income deduction';

  @override
  String get mariageDeductionChildren => 'Children deduction';

  @override
  String get mariageTotalDeductions => 'Total deductions';

  @override
  String get mariageEducationalPenalty =>
      'Did you know the marriage penalty affects ~700,000 couples in Switzerland? The Federal Court ruled this unconstitutional in 1984, but it still hasn\'t been corrected.';

  @override
  String get mariageRegimeMatrimonial => 'MATRIMONIAL REGIME';

  @override
  String get mariageParticipation => 'Participation in acquired property';

  @override
  String get mariageParticipationSub => 'Default regime (CC art. 181)';

  @override
  String get mariageParticipationDesc =>
      'Each keeps their own property. Acquired assets (gains during marriage) are split 50/50 in case of dissolution.';

  @override
  String get mariageSeparation => 'Separation of property';

  @override
  String get mariageSeparationSub => 'CC art. 247';

  @override
  String get mariageSeparationDesc =>
      'Each keeps all their property and income. No automatic sharing.';

  @override
  String get mariageCommunaute => 'Community of property';

  @override
  String get mariageCommunauteSub => 'CC art. 221';

  @override
  String get mariageCommunauteDesc =>
      'Everything is pooled: own property and acquired assets. Full equal sharing in case of dissolution.';

  @override
  String get mariagePatrimoine1 => 'Person 1 wealth';

  @override
  String get mariagePatrimoine2 => 'Person 2 wealth';

  @override
  String get mariageChiffreChocDefault =>
      'Under the default regime, this share of your acquired assets would go to your spouse in case of dissolution';

  @override
  String get mariageChiffreChocCommunaute =>
      'In community of property, this amount would be shared with your spouse';

  @override
  String get mariageProtectionIntro =>
      'What happens if one of you dies? Compare legal protection between married couples and cohabitants.';

  @override
  String get mariageLppRenteLabel => 'Monthly LPP pension of the deceased';

  @override
  String get mariageAvsSurvivor => 'AVS survivor pension';

  @override
  String get mariageAvsSurvivorSub =>
      '80% of the maximum pension of the deceased';

  @override
  String get mariageAvsSurvivorFootnote =>
      'OASI art. 35 — married couples only';

  @override
  String get mariageLppSurvivor => 'LPP survivor pension';

  @override
  String get mariageLppSurvivorSub =>
      '60% of the insured pension of the deceased';

  @override
  String get mariageLppSurvivorFootnote =>
      'LPP art. 19 — married (cohabitants: clause required)';

  @override
  String get mariageSurvivorMonthly => 'Monthly income of the married survivor';

  @override
  String get mariageVsConcubin => 'MARRIED VS COHABITANT';

  @override
  String get mariageRenteAvsSurvivor => 'AVS survivor pension';

  @override
  String get mariageRenteLppSurvivor => 'LPP survivor pension';

  @override
  String get mariageHeritageExonere => 'Tax-exempt inheritance';

  @override
  String get mariagePensionAlimentaire => 'Alimony';

  @override
  String get mariageConcubinWarning =>
      'In cohabitation, the surviving partner has no rights by default — no AVS pension, no tax-exempt inheritance. Everything must be planned by contract.';

  @override
  String get mariageProtectionsEssentielles => 'ESSENTIAL PROTECTIONS';

  @override
  String get mariageChecklistIntro =>
      'Marriage has financial and legal consequences. Here are the essential steps to anticipate to prepare well.';

  @override
  String get mariageDisclaimer =>
      'Simplified estimates for educational purposes — not tax or legal advice. Amounts depend on many factors (deductions, municipality, wealth, etc.). Consult a tax specialist for a personalized calculation.';

  @override
  String get divorceAppBarTitle => 'Divorce — Financial impact';

  @override
  String get divorceHeaderTitle => 'Financial impact of a divorce';

  @override
  String get divorceHeaderSubtitle => 'Anticipate the financial consequences';

  @override
  String get divorceIntroText =>
      'A divorce has financial consequences that are often underestimated: division of assets, pension sharing (LPP/3a), tax impact and alimony. This tool helps you see more clearly.';

  @override
  String divorceYears(int count) {
    return '$count years';
  }

  @override
  String get divorceNbEnfants => 'Number of children';

  @override
  String get divorceParticipationDefault =>
      'Participation in acquired property (default)';

  @override
  String get divorceCommunaute => 'Community of property';

  @override
  String get divorceSeparation => 'Separation of property';

  @override
  String get divorceFortune => 'Common fortune';

  @override
  String get divorceDettes => 'Common debts';

  @override
  String get divorcePensionDescription =>
      'Estimate based on income gap and number of children. The actual amount depends on many factors (custody, needs, standard of living).';

  @override
  String get divorceActionsTitle => 'Actions to take';

  @override
  String get divorceComprendre => 'UNDERSTAND';

  @override
  String get divorceEduParticipationTitle =>
      'What is participation in acquired property?';

  @override
  String get divorceEduParticipationContent =>
      'Participation in acquired property is the default matrimonial regime in Switzerland (CC art. 181 ff). Each spouse keeps their own property (acquired before marriage or by inheritance/donation). Acquired assets (property acquired during marriage) are shared equally in case of divorce. It is the most common regime in Switzerland.';

  @override
  String get divorceEduLppTitle => 'How does LPP sharing work?';

  @override
  String get divorceEduLppContent =>
      'Since January 1, 2017 (CC art. 122), occupational pension assets (2nd pillar) accumulated during marriage are shared equally in case of divorce. The sharing is done directly between the two pension funds, without passing through the spouses\' personal accounts. This is a mandatory right that spouses can only waive under strict conditions.';

  @override
  String get successionAppBarTitle => 'Succession — Planning';

  @override
  String get successionHeaderTitle => 'Plan my succession';

  @override
  String get successionHeaderSubtitle => 'New inheritance law 2023';

  @override
  String get successionIntroText =>
      'The new succession law (2023) expanded the disposable portion. You now have more freedom to favor certain heirs. This tool shows you the legal distribution and the impact of a will.';

  @override
  String get donationAppBarTitle => 'Donation — Simulator';

  @override
  String get donationHeaderTitle => 'Simulate a donation';

  @override
  String get donationHeaderSubtitle => 'Taxation, statutory reserve, impact';

  @override
  String get housingSaleAppBarTitle => 'Property sale';

  @override
  String get housingSaleHeaderTitle => 'Simulate your property sale';

  @override
  String get housingSaleHeaderSubtitle =>
      'Capital gains tax, EPL, net proceeds';

  @override
  String get housingSaleCalculer => 'Calculate';

  @override
  String get lifeEventComprendre => 'UNDERSTAND';

  @override
  String get lifeEventPointsAttention => 'POINTS OF ATTENTION';

  @override
  String get lifeEventActionsTitle => 'Actions to take';

  @override
  String get lifeEventChecklistSubtitle => 'Preparation checklist';

  @override
  String get lifeEventDidYouKnow => 'Did you know?';

  @override
  String get unemploymentTitle => 'Job loss';

  @override
  String get unemploymentHeaderDesc =>
      'Estimate your unemployment benefits (LACI). The calculation depends on your insured earnings, your age and the contribution period over the last 2 years.';

  @override
  String get unemploymentGainSliderTitle => 'Monthly insured earnings';

  @override
  String get unemploymentAgeSliderTitle => 'Your age';

  @override
  String unemploymentAgeValue(int age) {
    return '$age years';
  }

  @override
  String get unemploymentAgeMin => '18 years';

  @override
  String get unemploymentAgeMax => '65 years';

  @override
  String get unemploymentContribTitle => 'Contribution months (last 2 years)';

  @override
  String unemploymentContribValue(int months) {
    return '$months months';
  }

  @override
  String get unemploymentContribMax => '24 months';

  @override
  String get unemploymentSituationTitle => 'Personal situation';

  @override
  String get unemploymentSituationSubtitle =>
      'Affects the compensation rate (70% or 80%)';

  @override
  String get unemploymentChildrenToggle => 'Maintenance obligation (children)';

  @override
  String get unemploymentDisabilityToggle => 'Recognized disability';

  @override
  String get unemploymentNotEligible => 'Not eligible';

  @override
  String get unemploymentCompensationRate => 'Compensation rate';

  @override
  String get unemploymentRateEnhanced =>
      'Enhanced rate (80%): maintenance obligation, disability, or salary < CHF 3,797';

  @override
  String get unemploymentRateStandard =>
      'Standard rate (70%): applicable in other situations';

  @override
  String get unemploymentDailyBenefit => 'Daily benefit';

  @override
  String get unemploymentMonthlyBenefit => 'Monthly benefit';

  @override
  String get unemploymentInsuredEarnings => 'Retained insured earnings';

  @override
  String get unemploymentWaitingPeriod => 'Waiting period';

  @override
  String unemploymentWaitingDays(int days) {
    return '$days days';
  }

  @override
  String get unemploymentDurationHeader => 'BENEFIT DURATION';

  @override
  String get unemploymentDailyBenefits => 'daily benefits';

  @override
  String get unemploymentCoverageMonths => 'months of coverage';

  @override
  String get unemploymentYouTag => 'YOU';

  @override
  String get unemploymentChecklistHeader => 'CHECKLIST';

  @override
  String get unemploymentCheckItem1 =>
      'Register at the ORP from the 1st day of unemployment';

  @override
  String get unemploymentCheckItem2 =>
      'Submit the file to the unemployment office';

  @override
  String get unemploymentCheckItem3 => 'Adjust the budget to the new income';

  @override
  String get unemploymentCheckItem4 =>
      'Transfer the LPP assets to a vested benefits account';

  @override
  String get unemploymentCheckItem5 =>
      'Check eligibility for health insurance premium reduction';

  @override
  String get unemploymentCheckItem6 =>
      'Update the MINT budget with the new income';

  @override
  String get unemploymentGoodToKnow => 'GOOD TO KNOW';

  @override
  String get unemploymentEduFastTitle => 'Quick registration';

  @override
  String get unemploymentEduFastBody =>
      'Register at the ORP as soon as possible. Each day of delay may result in a suspension of your benefits.';

  @override
  String get unemploymentEdu3aTitle => '3rd pillar on hold';

  @override
  String get unemploymentEdu3aBody =>
      'Without earned income, you can no longer contribute to pillar 3a. Unemployment benefits are not considered earned income for 3rd pillar purposes.';

  @override
  String get unemploymentEduLppTitle => 'LPP and unemployment';

  @override
  String get unemploymentEduLppBody =>
      'During unemployment, only death and disability risks are covered by the LPP. Retirement savings stop. Transfer your assets to a vested benefits account.';

  @override
  String get unemploymentEduLamalTitle => 'LAMal premium reduction';

  @override
  String get unemploymentEduLamalBody =>
      'With a lower income, you may be entitled to LAMal subsidies. Apply through your canton.';

  @override
  String get unemploymentTsunamiTitle => 'Your financial tsunami in 3 waves';

  @override
  String get unemploymentDisclaimer =>
      'Educational estimates — not financial advice under LSFin — LACI/LPP/OPP3. The amounts shown are approximate and depend on your personal situation. Consult a specialist or your canton\'s ORP.';

  @override
  String get firstJobTitle => 'First job';

  @override
  String get firstJobHeaderDesc =>
      'Understand your payslip! We show you where your contributions go, what your employer pays on top, and the first financial reflexes to adopt.';

  @override
  String get firstJobSalaryTitle => 'Monthly gross salary';

  @override
  String get firstJobActivityRate => 'Activity rate';

  @override
  String get firstJob3aHeader => 'PILLAR 3A — OPEN NOW';

  @override
  String get firstJob3aAnnualCap => 'Annual cap';

  @override
  String get firstJob3aMonthlySuggestion => 'Suggestion /month';

  @override
  String get firstJob3aWarningTitle => 'WARNING — LIFE INSURANCE 3A';

  @override
  String get firstJobLamalHeader => 'LAMAL DEDUCTIBLE COMPARISON';

  @override
  String get firstJobChecklistHeader => 'FIRST STEPS';

  @override
  String get firstJobEduLppTitle => 'LPP from age 25';

  @override
  String get firstJobEduLppBody =>
      'LPP (2nd pillar) contributions start at age 25 for retirement savings. Before 25, only death and disability risks are covered.';

  @override
  String get firstJobEdu13Title => '13th salary';

  @override
  String get firstJobEdu13Body =>
      'If your contract includes a 13th salary, it is also subject to social deductions. Your monthly gross salary is then the annual salary divided by 13.';

  @override
  String get firstJobEduBudgetTitle => '50/30/20 rule';

  @override
  String get firstJobEduBudgetBody =>
      'A good reflex for your first salary: 50% for fixed expenses, 30% for leisure, 20% for savings and retirement planning (3a included).';

  @override
  String get firstJobEduTaxTitle => 'Tax declaration';

  @override
  String get firstJobEduTaxBody =>
      'From your first job, you will need to file a tax return. Keep all your certificates (salary, 3a, professional expenses).';

  @override
  String get firstJobAnalysisHeader => 'MINT Analysis — Your salary story';

  @override
  String get firstJobProfileBadge => 'Your profile';

  @override
  String get firstJobIllustrativeBadge => 'Illustrative';

  @override
  String get firstJobDisclaimer =>
      'Educational estimates — not financial advice — LACI/LPP/OPP3. Amounts are approximate and do not account for all cantonal specificities. Check priminfo.admin.ch for exact LAMal premiums. Consult a retirement planning specialist.';

  @override
  String get independantAppBarTitle => 'SELF-EMPLOYED PATH';

  @override
  String get independantTitle => 'Self-employed';

  @override
  String get independantSubtitle => 'Coverage and protection analysis';

  @override
  String get independantIntroDesc =>
      'As a self-employed person, you have no mandatory LPP, no IJM, and no LAA. Your social protection depends entirely on your personal steps. Identify your gaps.';

  @override
  String get independantRevenueTitle => 'Annual net income';

  @override
  String independantAgeLabel(int age) {
    return 'Age: $age years';
  }

  @override
  String get independantCoverageTitle => 'My current coverage';

  @override
  String get independantToggleLpp => 'LPP (voluntary affiliation)';

  @override
  String get independantToggleIjm => 'IJM (daily sickness benefit)';

  @override
  String get independantToggleLaa => 'LAA (accident insurance)';

  @override
  String get independantToggle3a => '3rd pillar (3a)';

  @override
  String get independantCoverageAnalysis => 'COVERAGE ANALYSIS';

  @override
  String get independantProtectionCostTitle => 'Cost of my full protection';

  @override
  String get independantProtectionCostSubtitle => 'Monthly estimate';

  @override
  String get independantTotalMonthly => 'Monthly total';

  @override
  String get independantAvsTitle => 'Self-employed AVS contribution';

  @override
  String get independant3aTitle => '3rd pillar — self-employed cap';

  @override
  String get independantRecommendationsHeader => 'RECOMMENDATIONS';

  @override
  String get independantAnalysisHeader =>
      'MINT Analysis — Your self-employment kit';

  @override
  String get independantSourcesTitle => 'Sources';

  @override
  String get independantSourcesBody =>
      'LPP art. 4 (no obligation for self-employed) / LPP art. 44 (voluntary affiliation) / OPP3 art. 7 (large 3a: 20% of net income, max 36,288) / LAVS art. 8 (self-employed contributions) / LAA art. 4 / LAMal';

  @override
  String get independantDisclaimer =>
      'The amounts shown are indicative estimates. Actual contributions depend on your personal situation and available insurance offers. Consult a fiduciary or insurer before any decision.';

  @override
  String get jobCompareAgeTitle => 'Your age';

  @override
  String get jobCompareAgeSubtitle => 'Used to project retirement capital';

  @override
  String get jobCompareSalaryLabel => 'Annual gross salary';

  @override
  String get jobCompareEmployerShare => 'Employer LPP share';

  @override
  String get jobCompareConversionRate => 'Conversion rate';

  @override
  String get jobCompareRetirementAssets => 'Current retirement assets';

  @override
  String get jobCompareDisabilityCoverage => 'Disability coverage';

  @override
  String get jobCompareDeathCapital => 'Death capital';

  @override
  String get jobCompareMaxBuyback => 'Maximum buyback';

  @override
  String get jobCompareVerdictLabel => 'VERDICT';

  @override
  String get jobCompareDetailedTitle => 'Detailed comparison';

  @override
  String get jobCompareRetirementImpact => 'IMPACT ON ENTIRE RETIREMENT';

  @override
  String get jobCompareAttentionPoints => 'ATTENTION POINTS';

  @override
  String get jobCompareChecklistTitle => 'Before signing';

  @override
  String get jobCompareUnderstandHeader => 'UNDERSTAND';

  @override
  String get jobCompareEduInvisibleTitle => 'What is the invisible salary?';

  @override
  String get jobCompareEduInvisibleBody =>
      'The \"invisible salary\" represents 10-30% of your total compensation. It includes the employer\'s pension fund contribution (LPP), insurance (IJM, accident), and sometimes additional benefits. Two positions with the same gross salary can offer very different protections.';

  @override
  String get jobCompareEduCertTitle => 'How to read my pension certificate?';

  @override
  String get jobCompareEduCertBody =>
      'Your pension certificate (LPP) contains all the necessary information: insured salary, coordination deduction, contribution rate, retirement assets, conversion rate, risk benefits (disability and death), and possible buyback. Request it from your HR or pension fund.';

  @override
  String get jobCompareAxisLabel => 'Axis';

  @override
  String get jobCompareCurrentLabel => 'Current';

  @override
  String get jobCompareNewLabel => 'New';

  @override
  String get disabilityGapParamsTitle => 'Your parameters';

  @override
  String get disabilityGapParamsSubtitle => 'Adjust to your situation';

  @override
  String get disabilityGapIncomeLabel => 'Monthly net income';

  @override
  String get disabilityGapCantonLabel => 'Canton';

  @override
  String get disabilityGapStatusLabel => 'Employment status';

  @override
  String get disabilityGapEmployee => 'Employee';

  @override
  String get disabilityGapSelfEmployed => 'Self-empl.';

  @override
  String get disabilityGapSeniorityLabel => 'Years of seniority';

  @override
  String get disabilityGapIjmLabel => 'Collective IJM via my employer';

  @override
  String get disabilityGapDegreeLabel => 'Degree of disability';

  @override
  String get disabilityGapChartTitle => 'Evolution of your coverage';

  @override
  String get disabilityGapChartSubtitle => 'The 3 phases of protection';

  @override
  String get disabilityGapCurrentIncome => 'Current income';

  @override
  String get disabilityGapMaxGap => 'MAXIMUM MONTHLY GAP';

  @override
  String get disabilityGapPhaseDetail => 'PHASE DETAILS';

  @override
  String get disabilityGapPhase1Title => 'Phase 1: Employer';

  @override
  String get disabilityGapPhase2Title => 'Phase 2: IJM';

  @override
  String get disabilityGapPhase3Title => 'Phase 3: DI + LPP';

  @override
  String get disabilityGapDurationLabel => 'Duration:';

  @override
  String get disabilityGapCoverageLabel => 'Coverage:';

  @override
  String get disabilityGapLegalLabel => 'Legal source:';

  @override
  String get disabilityGapIfYouAre => 'IF YOU ARE...';

  @override
  String get disabilityGapEduTitle => 'UNDERSTAND';

  @override
  String get disabilityGapEduIjmTitle => 'IJM vs DI: what\'s the difference?';

  @override
  String get disabilityGapEduIjmBody =>
      'The IJM (daily sickness benefit) is an insurance covering 80% of your salary for max. 720 days in case of illness. The employer is not required to subscribe, but many do through collective insurance. Without IJM, after the legal salary continuation period, you receive nothing until a potential DI pension.';

  @override
  String get disabilityGapEduCoTitle =>
      'Your employer\'s obligation (CO art. 324a)';

  @override
  String get disabilityGapEduCoBody =>
      'Under art. 324a CO, the employer must pay the salary for a limited period in case of illness. This duration depends on years of service and the applicable cantonal scale (Bernese, Zurich or Basel). After this period, only the IJM (if any) takes over.';

  @override
  String get successionIntroDesc =>
      'The new inheritance law (2023) expanded the disposable portion. You now have more freedom to favor certain heirs. This tool shows you the legal distribution and the impact of a will.';

  @override
  String get successionSimulateButton => 'Simulate';

  @override
  String get successionLegalDistribution => 'LEGAL DISTRIBUTION';

  @override
  String get successionTestamentDistribution => 'DISTRIBUTION WITH WILL';

  @override
  String get successionReservesTitle => 'Statutory inheritance portions';

  @override
  String get successionReservesSubtitle => 'CC art. 470–471';

  @override
  String get successionQuotiteTitle => 'Disposable portion';

  @override
  String get successionQuotiteDesc =>
      'This amount can be freely assigned by will to the person of your choice.';

  @override
  String get successionBeneficiaries3aTitle => '3A BENEFICIARIES (OPP3 ART. 2)';

  @override
  String get successionBeneficiaries3aDesc =>
      'The 3rd pillar does NOT follow your will. The beneficiary order is set by law:';

  @override
  String get successionChecklistTitle => 'Estate protection checklist';

  @override
  String get successionTotalTax => 'Total inheritance tax';

  @override
  String get successionTestamentSwitch => 'I have a will';

  @override
  String get successionBeneficiaryQuestion =>
      'Who receives the disposable portion?';

  @override
  String get successionCivilStatusLabel => 'Civil status';

  @override
  String get successionFortuneLabel => 'Total wealth';

  @override
  String get successionAvoirs3aLabel => '3a assets';

  @override
  String get successionDeathCapitalLabel => 'LPP death capital';

  @override
  String get successionChildrenLabel => 'Number of children';

  @override
  String get successionParentsAlive => 'Living parents';

  @override
  String get successionSiblings => 'Siblings (brothers/sisters)';

  @override
  String get mariageProtectionItem1 => 'Draft a will (usufruct clause)';

  @override
  String get mariageProtectionItem2 =>
      'LPP beneficiary clause (ask your pension fund)';

  @override
  String get mariageProtectionItem3 =>
      'Cross life insurance (partner protection)';

  @override
  String get mariageProtectionItem4 => 'Power of attorney for incapacity';

  @override
  String get mariageProtectionItem5 => 'Advance patient directives';

  @override
  String get mariageChecklistItem1Title =>
      'Simulate the tax impact of marriage';

  @override
  String get mariageChecklistItem1Desc =>
      'Before getting married, compare the tax burden as a couple (married vs single). If your incomes are similar and high, the marriage penalty can amount to several thousand francs per year.';

  @override
  String get mariageChecklistItem2Title => 'Choose the matrimonial regime';

  @override
  String get mariageChecklistItem2Desc =>
      'By default, it is participation in acquired property (CC art. 181). If you want another regime (separation of property, community of property), you must sign a marriage contract with a notary BEFORE or during the marriage.';

  @override
  String get mariageChecklistItem3Title =>
      'Update LPP and 3a beneficiary clauses';

  @override
  String get mariageChecklistItem3Desc =>
      'Marriage changes the order of beneficiaries. Your spouse automatically becomes the LPP survivor pension beneficiary (LPP art. 19). Also check your 3rd pillar beneficiaries.';

  @override
  String get mariageChecklistItem4Title =>
      'Inform your employer and health insurer';

  @override
  String get mariageChecklistItem4Desc =>
      'Your employer must update your data (marital status, deductions). Your health insurer must be informed — premiums don\'t change, but any subsidies are recalculated based on household income.';

  @override
  String get mariageChecklistItem5Title => 'Prepare the first joint tax return';

  @override
  String get mariageChecklistItem5Desc =>
      'From the year of marriage, you file a single joint tax return. Gather supporting documents for both (salary certificates, 3a, LPP, etc.). The switch to joint filing can change your tax bracket.';

  @override
  String get mariageChecklistItem6Title => 'Check the couple\'s AVS pensions';

  @override
  String get mariageChecklistItem6Desc =>
      'The maximum AVS pension for a couple is capped at 150% of the individual maximum pension (LAVS art. 35). If you\'re entitled to the max pension with your spouse, the cap may reduce your total.';

  @override
  String get mariageChecklistItem7Title => 'Update the will';

  @override
  String get mariageChecklistItem7Desc =>
      'Marriage changes the order of succession. The spouse becomes a legal heir with significant rights (CC art. 462). If you had a will in favour of a third party, it may need to be reviewed.';

  @override
  String mariageChecklistProgress(int done, int total) {
    return '$done/$total steps completed';
  }

  @override
  String get mariageRepartitionDissolution =>
      'DISTRIBUTION IN CASE OF DISSOLUTION';

  @override
  String get mariagePersonne1Recoit => 'Person 1 receives';

  @override
  String get mariagePersonne2Recoit => 'Person 2 receives';

  @override
  String get mariagePersonne1Garde => 'Person 1 keeps';

  @override
  String get mariagePersonne2Garde => 'Person 2 keeps';

  @override
  String get successionSituationTitle => 'PERSONAL SITUATION';

  @override
  String get successionSituationSubtitle2 => 'Marital status, heirs';

  @override
  String get successionFortuneTitle => 'WEALTH';

  @override
  String get successionFortuneSubtitle2 => 'Total wealth, 3a, LPP';

  @override
  String get successionTestamentTitle => 'Will';

  @override
  String get successionTestamentSubtitle2 => 'Testamentary wishes';

  @override
  String successionQuotitePct(String pct) {
    return 'i.e. $pct% of the estate';
  }

  @override
  String get successionExonereLabel => 'Exempt';

  @override
  String successionFiscaliteCanton(String canton) {
    return 'ESTATE TAX ($canton)';
  }

  @override
  String get successionEduQuotiteBody2 =>
      'The disposable portion is the part of your estate you can freely assign by will. Since January 1, 2023, the children\'s reserved portion has been reduced from 3/4 to 1/2 of their legal share. Parents no longer have a reserved portion. This gives you more freedom to favour your spouse, partner, or anyone else.';

  @override
  String get successionEdu3aBody2 =>
      'The 3rd pillar (3a) does NOT form part of the ordinary estate. It is paid directly to beneficiaries in an order set by OPP3 (art. 2): spouse/registered partner, then descendants, parents, siblings. A cohabiting partner can be designated as beneficiary, but only by an explicit clause filed with the foundation. Without this step, the cohabiting partner receives nothing from the 3a.';

  @override
  String get successionEduConcubinBody2 =>
      'Under Swiss law, cohabiting partners have NO legal inheritance rights. Without a will, a cohabiting partner receives nothing. Moreover, inheritance tax for cohabiting partners is generally much higher than for spouses (often 20-25% instead of 0%). To protect your partner, it is essential to draft a will, check 3a/LPP beneficiary clauses, and consider life insurance.';

  @override
  String get successionDisclaimerText =>
      'The results presented are indicative estimates and do not constitute personalised legal or notarial advice. Succession law has many subtleties. Consult a notary or specialised lawyer before making any decisions.';

  @override
  String get donationIntroText =>
      'Donations in Switzerland are subject to a cantonal tax that varies according to the relationship and the canton. Since 2023, the reserved portion has been reduced, giving you more freedom. This tool helps you estimate the tax and check compatibility with heirs\' rights.';

  @override
  String get donationSectionTitle => 'DONATION';

  @override
  String get donationSectionSubtitle => 'Amount, beneficiary, type';

  @override
  String get donationMontantLabel => 'Donation amount';

  @override
  String get donationLienParente => 'Kinship';

  @override
  String get donationTypeDonation => 'Type of donation';

  @override
  String get donationValeurImmobiliere => 'Real estate value';

  @override
  String get donationAvancementHoirie => 'Advancement of inheritance';

  @override
  String get donationContexteSuccessoral => 'SUCCESSION CONTEXT';

  @override
  String get donationContexteSubtitle => 'Family, wealth, matrimonial regime';

  @override
  String get donationAgeLabel => 'Donor\'s age';

  @override
  String get donationNbEnfants => 'Number of children';

  @override
  String get donationFortuneTotale => 'Donor\'s total wealth';

  @override
  String get donationRegimeMatrimonial => 'Matrimonial regime';

  @override
  String get donationCalculer => 'Calculate';

  @override
  String get donationImpotTitle => 'DONATION TAX';

  @override
  String get donationExoneree => 'Exempt';

  @override
  String donationTauxCanton(String taux, String canton) {
    return 'Rate: $taux% (canton $canton)';
  }

  @override
  String get donationMontantRow => 'Donation amount';

  @override
  String get donationLienRow => 'Kinship';

  @override
  String get donationReserveTitle => 'RESERVED PORTION (2023)';

  @override
  String get donationReserveProtege => 'amount protected by law (untouchable)';

  @override
  String get donationReserveNote =>
      'Since 2023, parents no longer have a reserved portion. The descendants\' reserve is 50% of their legal share (CC art. 471).';

  @override
  String get donationQuotiteTitle => 'DISPOSABLE PORTION';

  @override
  String get donationQuotiteDesc => 'amount you can freely donate';

  @override
  String donationDepassement(String amount) {
    return 'Exceeded by $amount — risk of reduction claim';
  }

  @override
  String get donationImpactTitle => 'IMPACT ON SUCCESSION';

  @override
  String get donationAvancementNote =>
      'Advancement of inheritance: the donation will be reported to the estate.';

  @override
  String get donationHorsPartNote =>
      'Donation outside share: it is charged only to the disposable portion.';

  @override
  String get donationEduQuotiteTitle => 'What is the disposable portion?';

  @override
  String get donationEduQuotiteBody =>
      'The disposable portion is the part of your wealth you can freely donate or bequeath without encroaching on the reserved portions. Since January 1, 2023, the children\'s reserved portion has been reduced from 3/4 to 1/2 of their legal share, and parents no longer have a reserved portion. This gives you more freedom to make donations.';

  @override
  String get donationEduAvancementTitle =>
      'Advancement of inheritance vs separate donation';

  @override
  String get donationEduAvancementBody =>
      'An advancement of inheritance is an advance on the beneficiary\'s share of the estate. It will be reported to the estate upon death. A separate donation (or preciput) is charged only to the disposable portion and is not reported. The choice between the two has a major impact on the balance between heirs.';

  @override
  String get donationEduConcubinTitle => 'Donations and cohabiting partners';

  @override
  String get donationEduConcubinBody =>
      'Cohabiting partners have no legal inheritance rights in Switzerland. A donation is the most direct way to benefit them. However, cantonal donation tax between cohabiting partners is generally high (18-25% depending on the canton). Schwyz is the exception: no donation tax regardless of relationship. Consider a will in addition for complete protection.';

  @override
  String get donationDisclaimer =>
      'This educational tool provides indicative estimates and does not constitute personalised legal, tax, or notarial advice within the meaning of FinSA. Consult a specialist (notary) for your situation.';

  @override
  String get donationCanton => 'Canton';

  @override
  String get housingSaleIntroText =>
      'Selling property in Switzerland involves a capital gains tax (LHID art. 12), possible reimbursement of pension funds used (EPL), and transaction costs. This tool helps you estimate your net sale proceeds.';

  @override
  String get housingSaleBienTitle => 'PROPERTY';

  @override
  String get housingSaleBienSubtitle => 'Purchase price, sale, investments';

  @override
  String get housingSalePrixAchat => 'Purchase price';

  @override
  String get housingSalePrixVente => 'Sale price';

  @override
  String get housingSaleAnneeAchat => 'Year of purchase';

  @override
  String get housingSaleInvestissements => 'Value-enhancing investments';

  @override
  String get housingSaleFraisAcquisition => 'Acquisition costs (notary, etc.)';

  @override
  String get housingSaleResidencePrincipale => 'Primary residence';

  @override
  String get housingSaleFinancementTitle => 'FINANCING';

  @override
  String get housingSaleFinancementSubtitle => 'Remaining mortgage';

  @override
  String get housingSaleHypotheque => 'Remaining mortgage';

  @override
  String get housingSaleEplTitle => 'EPL — PENSION FUNDS USED';

  @override
  String get housingSaleEplSubtitle => 'LPP and 3a used for the purchase';

  @override
  String get housingSaleEplLpp => 'LPP EPL used';

  @override
  String get housingSaleEpl3a => '3a EPL used';

  @override
  String get housingSaleRemploiTitle => 'REINVESTMENT';

  @override
  String get housingSaleRemploiSubtitle => 'Plan to purchase a new property';

  @override
  String get housingSaleProjetRemploi => 'Reinvestment project (repurchase)';

  @override
  String get housingSalePrixNouveauBien => 'Price of the new property';

  @override
  String get housingSalePlusValueTitle => 'REAL ESTATE CAPITAL GAIN';

  @override
  String get housingSalePlusValueBrute => 'Gross capital gain';

  @override
  String get housingSalePlusValueImposable => 'Taxable capital gain';

  @override
  String get housingSaleDureeDetention => 'Holding period';

  @override
  String housingSaleYearsCount(int count) {
    return '$count years';
  }

  @override
  String housingSaleImpotGainsCanton(String canton) {
    return 'CAPITAL GAINS TAX ($canton)';
  }

  @override
  String get housingSaleTauxImposition => 'Tax rate';

  @override
  String get housingSaleImpotGains => 'Capital gains tax';

  @override
  String get housingSaleReportRemploi => 'Deferral (reinvestment)';

  @override
  String get housingSaleImpotEffectif => 'Effective tax';

  @override
  String get housingSaleReportTitle => 'TAX DEFERRAL (REINVESTMENT)';

  @override
  String get housingSaleReportDesc =>
      'of deferred capital gain (not taxed now)';

  @override
  String get housingSaleReportNote =>
      'The deferral will be integrated upon resale of the new property (LHID art. 12 para. 3).';

  @override
  String get housingSaleEplRepaymentTitle => 'EPL REPAYMENT';

  @override
  String get housingSaleRemboursementLpp => 'LPP repayment';

  @override
  String get housingSaleRemboursement3a => '3a repayment';

  @override
  String get housingSaleEplNote =>
      'Legal obligation: pension funds used for the purchase must be repaid upon sale of the primary residence (LPP art. 30d).';

  @override
  String get housingSaleProduitNetTitle => 'NET SALE PROCEEDS';

  @override
  String get housingSaleImpotPlusValue => 'Capital gains tax';

  @override
  String get housingSaleRemboursementEplLpp => 'LPP EPL repayment';

  @override
  String get housingSaleRemboursementEpl3a => '3a EPL repayment';

  @override
  String get housingSaleEduImpotTitle =>
      'How does the real estate capital gains tax work?';

  @override
  String get housingSaleEduImpotBody =>
      'In Switzerland, any gain from selling property is subject to a specific cantonal tax (LHID art. 12). The rate decreases with the holding period. After 20-25 years depending on the canton, the gain may be fully or partially exempt. Value-enhancing investments (renovations) and acquisition costs are deductible from the capital gain.';

  @override
  String get housingSaleEduRemploiTitle => 'What is reinvestment (remploi)?';

  @override
  String get housingSaleEduRemploiBody =>
      'Reinvestment allows you to defer taxation of the capital gain if you buy a new primary residence within a reasonable period (usually 2 years). If the new property costs as much or more than the old one, the deferral is total. Otherwise, it is proportional. The tax will be due upon resale of the new property.';

  @override
  String get housingSaleEduEplTitle => 'EPL: what happens at sale?';

  @override
  String get housingSaleEduEplBody =>
      'If you used pension funds (EPL) to purchase your primary residence, you must repay them upon sale (LPP art. 30d). This repayment is mandatory and is made to your pension fund (LPP) and/or your 3a foundation. The amount is recorded in the land registry and cannot be avoided.';

  @override
  String get housingSaleDisclaimer =>
      'This educational tool provides indicative estimates and does not constitute personalised tax, legal, or real estate advice within the meaning of FinSA. Consult a specialist for your personal situation.';

  @override
  String get housingSaleCanton => 'Canton';

  @override
  String get jobCompareDeltaLabel => 'Delta';

  @override
  String jobCompareRetirementBody(
      String betterJob, String annualDelta, String monthlyDelta) {
    return '$betterJob is worth $annualDelta/year more in life annuity, i.e. $monthlyDelta/month FOR LIFE after retirement.';
  }

  @override
  String jobCompareLifetime20Years(String amount) {
    return 'Over 20 years of retirement: $amount';
  }

  @override
  String jobCompareAxesFavorable(String favorable, String total) {
    return '$favorable favorable axes out of $total';
  }

  @override
  String get jobCompareCurrentJobWidget => 'Current job';

  @override
  String get jobCompareNewJobWidget => 'Prospective job';

  @override
  String get jobCompareAxisSalary => 'Gross salary';

  @override
  String get jobCompareAxisLpp => 'LPP contribution';

  @override
  String get jobCompareAxisDistance => 'Distance';

  @override
  String get jobCompareAxisVacation => 'Vacation';

  @override
  String get jobCompareAxisWeeklyHours => 'Weekly hours';

  @override
  String get jobCompareChecklistSub => 'Verification checklist';

  @override
  String get independantJourJTitle => 'D-Day — The big switch';

  @override
  String get independantJourJSubtitle =>
      'What changes in 1 day when you become self-employed';

  @override
  String get independantJourJEmployee => 'Employee';

  @override
  String get independantJourJSelfEmployed => 'Self-employed';

  @override
  String independantJourJChiffreChoc(String amount) {
    return 'You lose ~$amount/month in invisible protection.\nYou didn\'t leave a job. You left a protection system.';
  }

  @override
  String independantAvsBody(String amount) {
    return 'Your estimated AVS contribution: $amount/year (degressive rate for income below CHF 58,800, then ~10.6% above).';
  }

  @override
  String get independantAvsSource =>
      'Source: OASI Act art. 8 / AVS contribution tables';

  @override
  String get independant3aWithLpp =>
      'With voluntary LPP: standard 3a cap of CHF 7,258/year.';

  @override
  String independant3aWithoutLpp(String amount) {
    return 'Without LPP: \"large\" 3a cap of 20% of net income, max $amount/year (legal cap CHF 36,288).';
  }

  @override
  String get independant3aSource => 'Source: OPP3 art. 7';

  @override
  String get independantPerMonth => '/month';

  @override
  String get independantPerYear => '/ year';

  @override
  String get independantCostAvs => 'AVS / AI / APG';

  @override
  String get independantCostIjm => 'DBI (estimate)';

  @override
  String get independantCostLaa => 'AIA (estimate)';

  @override
  String get independantCost3a => 'Pillar 3a (max)';

  @override
  String disabilityGapSeniorityYears(String years) {
    return '$years years';
  }

  @override
  String disabilityGapPhase1Duration(String weeks) {
    return '$weeks weeks';
  }

  @override
  String get disabilityGapPhase1Full => '100% of salary';

  @override
  String get disabilityGapNoCoverage => 'No coverage';

  @override
  String get disabilityGapNone => 'None';

  @override
  String get disabilityGapPhase2Duration => 'Up to 24 months';

  @override
  String disabilityGapPhase2Coverage(String amount) {
    return '80% of salary ($amount CHF/month)';
  }

  @override
  String get disabilityGapCollectiveInsurance => 'Collective insurance';

  @override
  String get disabilityGapNotSubscribed => 'Not subscribed';

  @override
  String get disabilityGapPhase3Duration => 'After 24 months';

  @override
  String get disabilityGapActionSelfIjm => 'Subscribe to an individual DBI';

  @override
  String get disabilityGapActionSelfIjmSub =>
      'Absolute priority for the self-employed';

  @override
  String get disabilityGapActionCheckHr => 'Check your health coverage with HR';

  @override
  String get disabilityGapActionCheckHrSub => 'Ask if a collective DBI exists';

  @override
  String get disabilityGapActionConditions =>
      'Ask for the exact conditions of your DBI';

  @override
  String get disabilityGapActionConditionsSub =>
      'Waiting period, duration, coverage rate';

  @override
  String get successionMarried => 'Married';

  @override
  String get successionSingle => 'Single';

  @override
  String get successionDivorced => 'Divorced';

  @override
  String get successionWidowed => 'Widowed';

  @override
  String get successionConcubinage => 'Cohabitation';

  @override
  String get successionConjoint => 'Spouse';

  @override
  String get successionChildren => 'Children';

  @override
  String get successionThirdParty => 'Third party / Charity';

  @override
  String get successionQuotiteFreedom =>
      'This amount can be freely allocated by will to the person of your choice.';

  @override
  String get successionFiscalTitle => 'INHERITANCE TAX';

  @override
  String get successionExempt => 'Exempt';

  @override
  String get successionEduQuotiteTitle => 'What is the disposable portion?';

  @override
  String get successionEdu3aTitle => 'Pillar 3a and succession: caution!';

  @override
  String get successionEduConcubinTitle => 'Cohabitants and succession';

  @override
  String get successionCantonLabel => 'Canton';

  @override
  String get debtCheckTitle => 'Financial Health Check-up';

  @override
  String get debtCheckExportTooltip => 'Export my report';

  @override
  String get debtCheckSectionDaily => 'Daily management';

  @override
  String get debtCheckOverdraftQuestion => 'Are you regularly overdrawn?';

  @override
  String get debtCheckOverdraftSub =>
      'Your account goes negative before month\'s end.';

  @override
  String get debtCheckMultipleCreditsQuestion =>
      'Do you have multiple ongoing loans?';

  @override
  String get debtCheckMultipleCreditsSub =>
      'Leasing, loans, small credits, credit cards...';

  @override
  String get debtCheckSectionObligations => 'Obligations';

  @override
  String get debtCheckLatePaymentsQuestion => 'Do you have late payments?';

  @override
  String get debtCheckLatePaymentsSub => 'Bills, taxes or rent paid late.';

  @override
  String get debtCheckCollectionQuestion =>
      'Have you received debt collection notices?';

  @override
  String get debtCheckCollectionSub => 'Payment orders or seizures.';

  @override
  String get debtCheckSectionBehaviors => 'Behaviors';

  @override
  String get debtCheckImpulsiveQuestion => 'Frequent impulse purchases?';

  @override
  String get debtCheckImpulsiveSub => 'Unplanned expenses you regret.';

  @override
  String get debtCheckGamblingQuestion => 'Do you gamble regularly?';

  @override
  String get debtCheckGamblingSub =>
      'Casinos, sports betting or frequent lotteries.';

  @override
  String get debtCheckAnalyzeButton => 'Analyze my situation';

  @override
  String get debtCheckMentorTitle => 'Mentor\'s word';

  @override
  String get debtCheckMentorBody =>
      'This 60-second check-up helps us detect warning signs before they become critical.';

  @override
  String get debtCheckYes => 'YES';

  @override
  String get debtCheckNo => 'NO';

  @override
  String get debtCheckRiskLow => 'Risk Under Control';

  @override
  String get debtCheckRiskMedium => 'Attention Points';

  @override
  String get debtCheckRiskHigh => 'Critical Alert';

  @override
  String get debtCheckRiskUnknown => 'Undetermined';

  @override
  String debtCheckFactorsDetected(int count) {
    return '$count factor(s) detected';
  }

  @override
  String get debtCheckRecommendationsTitle => 'MENTOR\'S RECOMMENDATIONS';

  @override
  String get debtCheckValidateButton => 'Validate my check-up';

  @override
  String get debtCheckRedoButton => 'Redo the check-up';

  @override
  String get debtCheckHonestyQuote =>
      'Honesty with oneself is the first step toward serenity.';

  @override
  String get debtCheckGamblingSupportTitle => 'Gambling Support';

  @override
  String get debtCheckGamblingSupportBody =>
      'Free professional and anonymous support is available.';

  @override
  String get debtCheckGamblingSupportCta => 'SOS Gambling - Online help';

  @override
  String get debtCheckPrivacyNote =>
      'Mint respects your privacy. No data is stored or transmitted.';

  @override
  String scoreRevealGreeting(String name) {
    return 'Here is your score, $name.';
  }

  @override
  String get scoreRevealTitle => 'Your diagnostic\nis ready.';

  @override
  String get scoreRevealBudget => 'Budget';

  @override
  String get scoreRevealPrevoyance => 'Pension';

  @override
  String get scoreRevealPatrimoine => 'Wealth';

  @override
  String get scoreRevealLevelExcellent => 'Excellent';

  @override
  String get scoreRevealLevelGood => 'Good';

  @override
  String get scoreRevealLevelWarning => 'Warning';

  @override
  String get scoreRevealLevelCritical => 'Critical';

  @override
  String get scoreRevealCoachLabel => 'YOUR COACH';

  @override
  String get scoreRevealCtaDashboard => 'View my dashboard';

  @override
  String get scoreRevealCtaReport => 'View detailed report';

  @override
  String get scoreRevealDisclaimer =>
      'Educational tool — does not constitute financial advice (FinSA).';

  @override
  String get affordabilityTitle => 'Buying capacity';

  @override
  String get affordabilitySource =>
      'Source: SBA directive on mortgage credit, Swiss banking practice.';

  @override
  String get affordabilityIndicators => 'Indicators';

  @override
  String get affordabilityChargesRatio => 'Charges / income ratio';

  @override
  String get affordabilityEquityRatio => 'Equity / price';

  @override
  String get affordabilityOk => 'OK';

  @override
  String get affordabilityExceeded => 'Exceeded';

  @override
  String get affordabilityParameters => 'Your assumptions';

  @override
  String get affordabilityCanton => 'Canton';

  @override
  String get affordabilityGrossIncome => 'Gross annual income';

  @override
  String get affordabilityTargetPrice => 'Target purchase price';

  @override
  String get affordabilityAvailableSavings => 'Available savings';

  @override
  String get affordabilityPillar3a => 'Pillar 3a assets';

  @override
  String get affordabilityPillarLpp => 'LPP assets';

  @override
  String get affordabilityCalculationDetail => 'Calculation details';

  @override
  String get affordabilityEquityRequired => 'Equity required (20%)';

  @override
  String get affordabilitySavingsLabel => 'Savings';

  @override
  String get affordabilityLppMax10 => 'LPP assets (max 10% of price)';

  @override
  String get affordabilityTotalEquity => 'Total equity';

  @override
  String affordabilityMortgagePercent(String percent) {
    return 'Mortgage ($percent%)';
  }

  @override
  String get affordabilityMonthlyCharges => 'Theoretical monthly charges';

  @override
  String get affordabilityCalculationNote =>
      'Theoretical calculation: mortgage x (5% imputed interest + 1% amortization) + price x 1% ancillary costs. Max 33% of gross income.';

  @override
  String get amortizationSource =>
      'Source: OPP3 (pillar 3a), Swiss mortgage practice. Pillar 3a cap for employees 2026: CHF 7,258.';

  @override
  String get amortizationIntroTitle => 'Amortization: direct or indirect?';

  @override
  String get amortizationIntroBody =>
      'In Switzerland, indirect amortization is a unique feature: instead of directly repaying the debt, you pay into a pledged pillar 3a. You benefit from a double tax deduction (interest + 3a contribution) and your capital stays invested.';

  @override
  String get amortizationDirect => 'Direct';

  @override
  String get amortizationDirectDesc =>
      'You repay the debt each year. Interest decreases progressively.';

  @override
  String get amortizationIndirect => 'Indirect';

  @override
  String get amortizationIndirectDesc =>
      'You pay into a pledged 3a. Double tax deduction.';

  @override
  String amortizationEvolutionTitle(int years) {
    return 'Evolution over $years years';
  }

  @override
  String get amortizationLegendDebtDirect => 'Debt (direct)';

  @override
  String get amortizationLegendDebtIndirect => 'Debt (indirect)';

  @override
  String get amortizationLegendCapital3a => '3a Capital';

  @override
  String get amortizationParameters => 'Parameters';

  @override
  String get amortizationMortgageAmount => 'Mortgage amount';

  @override
  String get amortizationInterestRate => 'Interest rate';

  @override
  String get amortizationDuration => 'Duration';

  @override
  String get amortizationMarginalRate => 'Estimated marginal rate';

  @override
  String get amortizationDetailedComparison => 'Detailed comparison';

  @override
  String get amortizationDirectTitle => 'Direct amortization';

  @override
  String get amortizationTotalInterest => 'Total interest paid';

  @override
  String get amortizationNetCost => 'Total net cost';

  @override
  String get amortizationIndirectTitle => 'Indirect amortization';

  @override
  String get amortizationCapital3aAccumulated => '3a capital accumulated';

  @override
  String get fiscalComparatorTitle => 'Tax comparator';

  @override
  String get fiscalTabMyTax => 'My tax';

  @override
  String get fiscalTab26Cantons => '26 cantons';

  @override
  String get fiscalTabMove => 'Move';

  @override
  String get fiscalGrossAnnualIncome => 'Gross annual income';

  @override
  String get fiscalCanton => 'Canton';

  @override
  String get fiscalCivilStatus => 'Civil status';

  @override
  String get fiscalSingle => 'Single';

  @override
  String get fiscalMarried => 'Married';

  @override
  String get fiscalChildren => 'Children';

  @override
  String get fiscalNetWealth => 'Net wealth';

  @override
  String get fiscalChurchMember => 'Church member';

  @override
  String get fiscalChurchTax => 'Church tax';

  @override
  String get fiscalEffectiveRate => 'Estimated effective rate';

  @override
  String fiscalBelowAverage(String rate) {
    return 'Below the Swiss average (~$rate%)';
  }

  @override
  String fiscalAboveAverage(String rate) {
    return 'Above the Swiss average (~$rate%)';
  }

  @override
  String get fiscalBreakdownTitle => 'TAX BREAKDOWN';

  @override
  String get fiscalFederalTax => 'Federal tax';

  @override
  String get fiscalCantonalCommunalTax => 'Cantonal + communal tax';

  @override
  String get fiscalWealthTax => 'Wealth tax';

  @override
  String get fiscalTotalBurden => 'Total tax burden';

  @override
  String get fiscalNationalPosition => 'NATIONAL POSITION';

  @override
  String get fiscalRanks => 'ranks';

  @override
  String get fiscalCantons => 'cantons';

  @override
  String get fiscalCheapest => 'Cheapest';

  @override
  String get fiscalMostExpensive => 'Most expensive';

  @override
  String get fiscalGapBetweenCantons =>
      'gap between the cheapest and most expensive canton';

  @override
  String get fiscalMoveIntro =>
      'Simulate the tax impact of moving between two cantons. Income and family situation parameters are shared with the \"My tax\" tab.';

  @override
  String get fiscalCurrentCanton => 'Current canton';

  @override
  String get fiscalDestinationCanton => 'Destination canton';

  @override
  String get fiscalIncomeTaxLabel => 'Income tax';

  @override
  String get fiscalEstimateNote => 'Estimated by cantonal rate';

  @override
  String get fiscalEstimatedRent => 'Estimated rent';

  @override
  String get fiscalRentNote => 'Varies by municipality and surface';

  @override
  String get fiscalMovingCosts => 'Moving costs';

  @override
  String get fiscalMovingCostsNote => 'Amortized over 24 months';

  @override
  String get fiscalWealthTaxTitle => 'WEALTH TAX';

  @override
  String fiscalNetWealthAmount(String amount) {
    return 'Net wealth: $amount';
  }

  @override
  String fiscalWealthSaving(String amount) {
    return 'Wealth saving: $amount/year';
  }

  @override
  String fiscalWealthSurcharge(String amount) {
    return 'Wealth surcharge: $amount/year';
  }

  @override
  String get fiscalWealthEquivalent => 'Equivalent wealth tax';

  @override
  String get fiscalChecklist1 =>
      'Declare your departure to your current municipality';

  @override
  String get fiscalChecklist2 =>
      'Register at the new municipality within 14 days';

  @override
  String get fiscalChecklist3 => 'Update address with your health insurance';

  @override
  String get fiscalChecklist4 => 'Adapt tax return (prorata temporis)';

  @override
  String get fiscalChecklist5 => 'Check LAMal subsidies in the new canton';

  @override
  String get fiscalChecklist6 =>
      'Transfer registrations (vehicle, schools, etc.)';

  @override
  String get fiscalChecklistTitle => 'MOVING CHECKLIST';

  @override
  String get fiscalGoodToKnow => 'GOOD TO KNOW';

  @override
  String get fiscalEduDateTitle => 'Reference date: December 31';

  @override
  String get fiscalEduDateBody =>
      'You are taxed in the canton where you resided on December 31 of the fiscal year. Moving on December 30 counts for the whole year!';

  @override
  String get fiscalEduProrataTitle => 'Prorata temporis';

  @override
  String get fiscalEduProrataBody =>
      'The federal tax is always the same. Only cantonal and communal taxes change. Prorata applies in the year of the move.';

  @override
  String get fiscalEduRentTitle => 'Rent and cost of living';

  @override
  String get fiscalEduRentBody =>
      'Don\'t forget that tax savings can be offset by differences in rent and cost of living. Compare the overall budget, not just taxes.';

  @override
  String get fiscalCommune => 'Municipality';

  @override
  String get fiscalCapitalDefault => 'Capital city (default)';

  @override
  String get fiscalDisclaimer =>
      'Simplified estimates for educational purposes — not tax advice. Effective rates depend on many factors (deductions, wealth, municipality, etc.). Consult a tax specialist for a personalized calculation.';

  @override
  String get expatTitle => 'Expatriation';

  @override
  String get expatTabForfait => 'Lump-sum';

  @override
  String get expatTabDeparture => 'Departure';

  @override
  String get expatTabAvs => 'AVS';

  @override
  String get expatForfaitEducation =>
      'The lump-sum tax (expenditure-based taxation) allows foreign nationals not to be taxed on their worldwide income, but on their living expenses. About 5,000 people benefit from it in Switzerland.';

  @override
  String get expatHighlightSchwyz =>
      'Most tax-advantageous canton in Switzerland';

  @override
  String get expatHighlightZug => 'International hub, Zurich access';

  @override
  String get expatCanton => 'Canton';

  @override
  String get expatLivingExpenses => 'Annual living expenses';

  @override
  String get expatActualIncome => 'Actual annual income';

  @override
  String get expatTaxComparison => 'TAX COMPARISON';

  @override
  String get expatForfaitFiscal => 'Lump-sum tax';

  @override
  String get expatOrdinaryTaxation => 'Ordinary taxation';

  @override
  String get expatOnActualIncome => 'On actual income';

  @override
  String get expatAbolishedCantons =>
      'Cantons that abolished lump-sum taxation';

  @override
  String expatAbolishedNote(String names) {
    return '$names — lump-sum taxation is no longer available in these cantons.';
  }

  @override
  String get expatDepartureDate => 'Departure date';

  @override
  String get expatCurrentCanton => 'Current canton';

  @override
  String get expatPillar3aBalance => 'Pillar 3a balance';

  @override
  String get expatLppBalance => 'LPP balance (retirement assets)';

  @override
  String get expatNoExitTax => 'No exit tax in Switzerland';

  @override
  String get expatRecommendedTimeline => 'RECOMMENDED TIMELINE';

  @override
  String get expatDepartureChecklist => 'DEPARTURE CHECKLIST';

  @override
  String get expatAvsEducation =>
      'To receive a full AVS pension (max CHF 2,520/month), you need 44 years of contributions without gaps. Each missing year reduces your pension by about 2.3%. If you live abroad, you can voluntarily contribute to AVS to avoid gaps.';

  @override
  String get expatYearsInSwitzerland => 'Years in Switzerland';

  @override
  String get expatYearsAbroad => 'Years abroad';

  @override
  String get expatAvsCompleteness => 'AVS COMPLETENESS';

  @override
  String get expatOfPension => 'of pension';

  @override
  String get expatEstimatedPension => 'Estimated pension';

  @override
  String get expatAvsComplete =>
      'Confirmed: you have your 44 full contribution years. Your AVS pension should not be reduced.';

  @override
  String get expatPensionImpact => 'IMPACT ON YOUR PENSION';

  @override
  String get expatMissingYears => 'Missing years';

  @override
  String get expatEstimatedReduction => 'Estimated reduction';

  @override
  String get expatMonthlyLoss => 'Monthly loss';

  @override
  String get expatAnnualLoss => 'Annual loss';

  @override
  String get expatVoluntaryContribution => 'VOLUNTARY CONTRIBUTION';

  @override
  String get expatVoluntaryAvsTitle => 'Voluntary AVS from abroad';

  @override
  String get expatMinContribution => 'Minimum contribution';

  @override
  String get expatMaxContribution => 'Maximum contribution';

  @override
  String get expatVoluntaryAvsBody =>
      'You can voluntarily contribute to AVS if you live abroad. Registration deadline: 1 year after leaving Switzerland. Requirements: at least 5 consecutive years of contributions before departure.';

  @override
  String get expatRecommendation => 'RECOMMENDED';

  @override
  String get expatDidYouKnow => 'Did you know?';

  @override
  String get mariageTimelinePartner1 => 'Person 1';

  @override
  String get mariageTimelinePartner2 => 'Person 2';

  @override
  String get mariageTimelineCoachTip =>
      'Each life phase requires adapting your marriage contract and pension planning.';

  @override
  String get mariageTimelineAct1Title => 'You both work';

  @override
  String get mariageTimelineAct1Period => '0-10 years of living together';

  @override
  String get mariageTimelineAct1Insight =>
      'Building phase: 3a, LPP, joint savings. Make the most of two incomes.';

  @override
  String get mariageTimelineAct2Title => 'Intensive savings phase';

  @override
  String get mariageTimelineAct2Period => '10-25 years';

  @override
  String get mariageTimelineAct2Insight =>
      'LPP buyback, max 3a, retirement preparation. Your capital doubles.';

  @override
  String get mariageTimelineAct3Title => 'Couple\'s retirement';

  @override
  String get mariageTimelineAct3Period => '25+ years';

  @override
  String get mariageTimelineAct3Insight =>
      'Warning: AVS couple cap (150% max pension). Plan annuity vs capital.';

  @override
  String get naissanceChecklistItem1Title =>
      'Register baby for health insurance (3 months)';

  @override
  String get naissanceChecklistItem1Desc =>
      'You have 3 months after birth to register your child with a health insurer. If done within this period, coverage is retroactive from birth. After this deadline, there is a risk of coverage interruption. Compare child premiums between insurers — differences can be significant.';

  @override
  String get naissanceChecklistItem2Title => 'Apply for family allowances';

  @override
  String get naissanceChecklistItem2Desc =>
      'Apply through your employer (or your allowance office if self-employed). Allowances are paid from the month of birth. The amount depends on the canton (CHF 200 to CHF 305/month per child).';

  @override
  String get naissanceChecklistItem3Title =>
      'Report the birth to the civil registry';

  @override
  String get naissanceChecklistItem3Desc =>
      'The hospital usually transmits the announcement to the civil registry office. Verify that the birth certificate has been properly issued. You will need it for all administrative procedures.';

  @override
  String get naissanceChecklistItem4Title => 'Organize parental leave (APG)';

  @override
  String get naissanceChecklistItem4Desc =>
      'Maternity leave: 14 weeks at 80% of salary (max CHF 220/day). Paternity leave: 2 weeks (10 days), to be taken within 6 months. APG registration is done through your employer or directly with the compensation office.';

  @override
  String get naissanceChecklistItem5Title => 'Update the tax return';

  @override
  String get naissanceChecklistItem5Desc =>
      'An additional child entitles you to a tax deduction of CHF 6,700/year (LIFD art. 35). If you have childcare costs, you can deduct up to CHF 25,500/year. Remember to adjust your tax instalments for the current year.';

  @override
  String get naissanceChecklistItem6Title => 'Adapt the family budget';

  @override
  String get naissanceChecklistItem6Desc =>
      'A child costs on average CHF 1,200 to CHF 1,500/month in Switzerland (food, clothing, activities, insurance, nappies, etc.). Reassess your budget with the MINT Budget module.';

  @override
  String get naissanceChecklistItem7Title =>
      'Check pension planning (LPP and 3a)';

  @override
  String get naissanceChecklistItem7Desc =>
      'If you reduce your work rate, your LPP contributions decrease. Each part-time year means less capital at retirement. Consider compensating by contributing the maximum to the 3rd pillar (CHF 7,258/year).';

  @override
  String get naissanceChecklistItem8Title => 'Draft or update the will';

  @override
  String get naissanceChecklistItem8Desc =>
      'The arrival of a child changes the inheritance order. Children are forced heirs (CC art. 471). If you have a will, check that it respects the legal reserves.';

  @override
  String get naissanceChecklistItem9Title =>
      'Take out death/disability risk insurance';

  @override
  String get naissanceChecklistItem9Desc =>
      'With a dependent child, financial protection in case of death or disability becomes even more important. Check your current coverage (LPP, life insurance) and supplement if necessary.';

  @override
  String get naissanceBabyCostCreche => 'Daycare / childcare';

  @override
  String get naissanceBabyCostCrecheNote =>
      'Average subsidized rate — varies greatly by canton';

  @override
  String get naissanceBabyCostAlimentation => 'Food';

  @override
  String get naissanceBabyCostVetements => 'Clothing & equipment';

  @override
  String get naissanceBabyCostLamal => 'Child health insurance';

  @override
  String get naissanceBabyCostLamalNote =>
      'Average child premium — no deductible until age 18';

  @override
  String get naissanceBabyCostActivites => 'Activities & leisure';

  @override
  String get naissanceBabyCostDivers => 'Miscellaneous (toys, hygiene…)';

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
  String get financialSummaryTitle => 'FINANCIAL OVERVIEW';

  @override
  String get financialSummaryNoProfile => 'No profile entered';

  @override
  String get financialSummaryStartDiagnostic => 'Start the diagnostic';

  @override
  String get financialSummaryRestartDiagnostic => 'Restart the diagnostic';

  @override
  String get financialSummaryNarrativeFiscalite =>
      'Tax optimization is your first lever: 3a, LPP buyback, deductions.';

  @override
  String get financialSummaryNarrativePrevoyance =>
      'Your pension determines your comfort in retirement. Every year counts.';

  @override
  String get financialSummaryNarrativeAvs =>
      'AVS is the foundation of your retirement. Check your contribution gaps.';

  @override
  String get financialSummaryLegendSaisi => 'Entered';

  @override
  String get financialSummaryLegendEstime => 'Estimated';

  @override
  String get financialSummaryLegendCertifie => 'Certified';

  @override
  String get financialSummarySalaireBrutMensuel => 'Gross monthly salary';

  @override
  String get financialSummary13emeSalaire => '13th salary';

  @override
  String financialSummaryNemeMois(String n) {
    return '${n}th month';
  }

  @override
  String financialSummaryBonusEstime(String pct) {
    return 'Estimated bonus ($pct%)';
  }

  @override
  String financialSummaryConjointBrutMensuel(String name) {
    return '$name — gross monthly';
  }

  @override
  String get financialSummaryDefaultConjoint => 'Spouse';

  @override
  String get financialSummaryRevenuBrutAnnuel => 'Gross annual income';

  @override
  String get financialSummaryRevenuBrutAnnuelCouple =>
      'Gross annual income (couple)';

  @override
  String get financialSummarySoitLisseSur12Mois => 'spread over 12 months';

  @override
  String get financialSummaryDeductionsSalariales => 'Salary deductions';

  @override
  String get financialSummaryChargesSociales => 'Social charges (AVS/AI/AC)';

  @override
  String get financialSummaryCotisationLpp => 'LPP employee contribution';

  @override
  String get financialSummaryNetFicheDePaie => 'Net payslip';

  @override
  String get financialSummaryNetFicheDePaieHint =>
      'What arrives in your account each month';

  @override
  String get financialSummaryFiscalite => 'Taxation';

  @override
  String get financialSummaryImpotEstime => 'Estimated tax (ICC + IFD)';

  @override
  String get financialSummaryTauxMarginalEstime => 'Estimated marginal rate';

  @override
  String financialSummary13emeEtBonusHint(String label, String montant) {
    return '$label: ~$montant net/year (not included in monthly)';
  }

  @override
  String get financialSummaryRevenusEtFiscalite => 'Income & Taxation';

  @override
  String get financialSummaryDisponibleApresImpot => 'Available after tax';

  @override
  String get financialSummaryFootnoteRevenus =>
      'Simplified estimate. AANP and IJM vary by employer and are not included. LPP employee reflects the legal minimum (50/50) — your fund may apply a different split.';

  @override
  String get financialSummaryScanFicheSalaire => 'Scan my payslip';

  @override
  String get financialSummaryModifierRevenu => 'Edit income';

  @override
  String get financialSummaryEditSalaireBrut => 'Gross monthly salary (CHF)';

  @override
  String get financialSummaryAvs1erPilier => 'AVS (1st pillar)';

  @override
  String get financialSummaryAnneesCotisees => 'Years contributed';

  @override
  String financialSummaryAnneesUnit(String n) {
    return '$n years';
  }

  @override
  String get financialSummaryLacunes => 'Gaps';

  @override
  String get financialSummaryRenteEstimee => 'Estimated pension';

  @override
  String get financialSummaryLpp2ePilier => 'LPP (2nd pillar)';

  @override
  String get financialSummaryAvoirTotal => 'Total assets';

  @override
  String get financialSummaryObligatoire => 'Mandatory';

  @override
  String get financialSummarySurobligatoire => 'Supra-mandatory';

  @override
  String get financialSummaryTauxConversion => 'Conversion rate';

  @override
  String get financialSummaryRachatPossible => 'Buyback possible';

  @override
  String get financialSummaryRachatPlanifie => 'Planned buyback';

  @override
  String get financialSummaryCaisse => 'Fund';

  @override
  String get financialSummary3a3ePilier => '3a (3rd pillar)';

  @override
  String financialSummaryNComptes(String n) {
    return '$n account(s)';
  }

  @override
  String get financialSummaryLibrePassage => 'Vested benefits';

  @override
  String financialSummaryCompteN(String n) {
    return 'Account $n';
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
      '⚠️ FATCA — Only a minority of providers accept (e.g. Raiffeisen)';

  @override
  String get financialSummaryPrevoyanceTitle => 'Pension';

  @override
  String get financialSummaryScanCertificatLpp => 'Scan LPP / AVS certificate';

  @override
  String get financialSummaryModifierPrevoyance => 'Edit pension';

  @override
  String get financialSummaryEditAvoirLpp => 'Total LPP assets (CHF)';

  @override
  String get financialSummaryEditNombre3a => 'Number of 3a accounts';

  @override
  String get financialSummaryEditTotal3a => 'Total 3a savings (CHF)';

  @override
  String get financialSummaryEditRachatLpp =>
      'Planned monthly LPP buyback (CHF/month)';

  @override
  String get financialSummaryLiquidites => 'Liquid assets';

  @override
  String get financialSummaryEpargneLiquide => 'Liquid savings';

  @override
  String get financialSummaryInvestissements => 'Investments';

  @override
  String get financialSummaryImmobilier => 'Real estate';

  @override
  String get financialSummaryValeurEstimee => 'Estimated value';

  @override
  String get financialSummaryHypothequeRestante => 'Remaining mortgage';

  @override
  String get financialSummaryValeurNetteImmobiliere => 'Net real estate value';

  @override
  String financialSummaryLtvAmortissement(String pct) {
    return 'LTV ratio: $pct% — 2nd rank amortization required';
  }

  @override
  String financialSummaryLtvBonneVoie(String pct) {
    return 'LTV ratio: $pct% — on track';
  }

  @override
  String financialSummaryLtvExcellent(String pct) {
    return 'LTV ratio: $pct% — excellent';
  }

  @override
  String get financialSummaryPrevoyanceCapital => 'Pension (capital)';

  @override
  String get financialSummaryAvoirLppTotal => 'Total LPP assets';

  @override
  String financialSummaryCapital3a(String n, String s) {
    return '3a capital ($n account$s)';
  }

  @override
  String get financialSummaryPatrimoineBrut => 'Gross wealth';

  @override
  String get financialSummaryDettesTotales => 'Total debts';

  @override
  String get financialSummaryPatrimoine => 'Wealth';

  @override
  String get financialSummaryPatrimoineTotalBloque =>
      'Total wealth (incl. locked pension)';

  @override
  String get financialSummaryModifierPatrimoine => 'Edit wealth';

  @override
  String get financialSummaryEditEpargneLiquide => 'Liquid savings (CHF)';

  @override
  String get financialSummaryEditInvestissements => 'Investments (CHF)';

  @override
  String get financialSummaryEditValeurImmobiliere => 'Real estate value (CHF)';

  @override
  String get financialSummaryLoyerCharges => 'Rent / charges';

  @override
  String get financialSummaryAssuranceMaladie => 'Health insurance';

  @override
  String get financialSummaryElectriciteEnergie => 'Electricity / energy';

  @override
  String get financialSummaryTransport => 'Transport';

  @override
  String get financialSummaryTelecom => 'Telecom';

  @override
  String get financialSummaryFraisMedicaux => 'Medical expenses';

  @override
  String get financialSummaryAutresFraisFixes => 'Other fixed costs';

  @override
  String get financialSummaryAucuneDepense => 'No expenses entered';

  @override
  String get financialSummaryDepensesFixes => 'Fixed expenses';

  @override
  String get financialSummaryTotalMensuel => 'Monthly total';

  @override
  String get financialSummaryModifierDepenses => 'Edit expenses';

  @override
  String get financialSummaryEditLoyerCharges => 'Rent / charges (CHF/month)';

  @override
  String get financialSummaryEditAssuranceMaladie =>
      'Health insurance (CHF/month)';

  @override
  String get financialSummaryEditElectricite =>
      'Electricity / energy (CHF/month)';

  @override
  String get financialSummaryEditTransport => 'Transport (CHF/month)';

  @override
  String get financialSummaryEditTelecom => 'Telecom (CHF/month)';

  @override
  String get financialSummaryEditFraisMedicaux =>
      'Medical expenses (CHF/month)';

  @override
  String get financialSummaryEditAutresFraisFixes =>
      'Other fixed costs (CHF/month)';

  @override
  String get financialSummaryModifierDettes => 'Edit debts';

  @override
  String get financialSummaryEditHypotheque => 'Mortgage (CHF)';

  @override
  String get financialSummaryEditCreditConsommation => 'Consumer credit (CHF)';

  @override
  String get financialSummaryEditLeasing => 'Leasing (CHF)';

  @override
  String get financialSummaryEditAutresDettes => 'Other debts (CHF)';

  @override
  String get financialSummaryDettes => 'Debts';

  @override
  String get financialSummaryAucuneDetteDeclaree => 'No debts declared — ';

  @override
  String get financialSummaryDetteStructurelle => 'Structural debt';

  @override
  String get financialSummaryHypotheque1erRang => '1st rank mortgage';

  @override
  String get financialSummaryHypotheque2emeRang => '2nd rank mortgage';

  @override
  String get financialSummaryHypotheque => 'Mortgage';

  @override
  String get financialSummaryChargeMensuelle => 'Monthly charge';

  @override
  String financialSummaryEcheance(String date, String years) {
    return 'Maturity: $date (~$years years)';
  }

  @override
  String financialSummaryInteretsDeductibles(String montant) {
    return 'Deductible interest (LIFD art. 33): $montant/year';
  }

  @override
  String get financialSummaryDetteConsommation => 'Consumer debt';

  @override
  String get financialSummaryCreditConsommation => 'Consumer credit';

  @override
  String get financialSummaryMensualite => 'Monthly payment';

  @override
  String get financialSummaryLeasing => 'Leasing';

  @override
  String get financialSummaryAutresDettes => 'Other debts';

  @override
  String financialSummaryConseilRemboursement(String taux) {
    return 'Pay off the $taux% debt first before investing. Every CHF repaid = $taux% effective return.';
  }

  @override
  String get financialSummaryTotalDettes => 'Total debts';

  @override
  String get financialSummaryScannerDocument => 'Scan a document';

  @override
  String get financialSummaryCascadeBudgetaire => 'Budget waterfall';

  @override
  String get financialSummaryToi => 'You';

  @override
  String get financialSummaryConjointeDefault => 'Spouse';

  @override
  String get financialSummaryDisclaimer =>
      'Educational tool — does not constitute financial advice (LSFin, LAVS, LPP, LIFD). Estimated values (~) are calculated from Swiss averages. Scan your certificates to improve projection accuracy.';

  @override
  String get financialSummaryEnregistrer => 'Save';

  @override
  String get financialSummaryCheckSalaireBrut => 'Gross salary';

  @override
  String get financialSummaryCheckCanton => 'Canton';

  @override
  String get financialSummaryCheckAvoirLpp => 'LPP assets';

  @override
  String get financialSummaryCheckEpargne3a => '3a savings';

  @override
  String get financialSummaryCheckEpargneLiquide => 'Liquid savings';

  @override
  String get financialSummaryCheckLoyerHypotheque => 'Rent / mortgage';

  @override
  String get financialSummaryCheckAssuranceMaladie => 'Health insurance';

  @override
  String get financialSummaryWhatIf3aQuestion =>
      'What if you maximized your 3a every year?';

  @override
  String get financialSummaryWhatIf3aExplanation =>
      'At your marginal rate, every franc contributed to 3a saves you ~30% in taxes.';

  @override
  String get financialSummaryWhatIf3aAction => 'Simulate';

  @override
  String get financialSummaryWhatIfLppQuestion =>
      'What if your LPP fund went from 1% to 3%?';

  @override
  String get financialSummaryWhatIfLppExplanation =>
      'A better LPP return increases your retirement capital without any effort on your part.';

  @override
  String get financialSummaryWhatIfLppAction => 'Compare';

  @override
  String get financialSummaryWhatIfAchatQuestion =>
      'What if you bought instead of renting?';

  @override
  String get financialSummaryWhatIfAchatExplanation =>
      'Indirect amortization via the 2nd pillar can reduce your taxes while building wealth.';

  @override
  String get financialSummaryWhatIfAchatAction => 'Explore';

  @override
  String get dataQualityTitle => 'Data quality';

  @override
  String dataQualityMissingCount(String count) {
    return '$count information(s) to add';
  }

  @override
  String get dataQualityComplete => 'Profile complete';

  @override
  String get dataQualityKnownSection => 'Known data';

  @override
  String get dataQualityMissingSection => 'Missing data';

  @override
  String get dataQualityCompleteness => 'Completeness';

  @override
  String get dataQualityAccuracy => 'Accuracy';

  @override
  String get dataQualityFreshness => 'Freshness';

  @override
  String get dataQualityCombined => 'Combined score';

  @override
  String get dataQualityEnrich => 'Enrich my profile';

  @override
  String dataQualityEnrichWithImpact(String impact) {
    return 'Enrich my profile ($impact)';
  }

  @override
  String get confidenceLabelSalaire => 'Gross salary';

  @override
  String get confidenceLabelAgeCanton => 'Age / Canton';

  @override
  String get confidenceLabelAge => 'Age';

  @override
  String get confidenceLabelCanton => 'Canton';

  @override
  String get confidenceLabelMenage => 'Household situation';

  @override
  String get confidenceLabelAvoirLpp => 'LPP assets';

  @override
  String get confidenceLabelTauxConversion => 'Conversion rate';

  @override
  String get confidenceLabelAnneesAvs => 'AVS years';

  @override
  String get confidenceLabelEpargne3a => 'Pillar 3a savings';

  @override
  String get confidenceLabelPatrimoine => 'Assets';

  @override
  String get confidencePromptFreshnessPrefix => 'Update: ';

  @override
  String confidencePromptFreshnessStale(String months) {
    return 'Data from $months months ago — rescan your certificate';
  }

  @override
  String get confidencePromptFreshnessConfirm =>
      'Confirm this value is still current';

  @override
  String get confidencePromptAccuracyPrefix => 'Confirm: ';

  @override
  String get confidencePromptAccuracyEstimated => 'Enter your actual value';

  @override
  String get confidencePromptAccuracyCertificate =>
      'Scan your certificate to confirm';

  @override
  String get pulseTitle => 'Pulse';

  @override
  String pulseGreeting(String name) {
    return 'Hello $name';
  }

  @override
  String pulseGreetingCouple(String name1, String name2) {
    return 'Hello $name1 and $name2';
  }

  @override
  String get pulseWelcome => 'Welcome to MINT';

  @override
  String get pulseEmptyTitle => 'Start by filling in your profile!';

  @override
  String get pulseEmptySubtitle =>
      'A few questions are enough to get your first financial visibility estimate.';

  @override
  String get pulseEmptyCtaStart => 'Get started';

  @override
  String get pulseVisibilityTitle => 'Financial visibility';

  @override
  String get pulsePrioritiesTitle => 'Your priorities';

  @override
  String get pulsePrioritiesSubtitle =>
      'Personalised actions based on your profile';

  @override
  String get pulseComprendreTitle => 'Understand';

  @override
  String get pulseComprendreSubtitle => 'Explore your simulators';

  @override
  String get pulseComprendreRenteCapital => 'Annuity or lump sum?';

  @override
  String get pulseComprendreRenteCapitalSub =>
      'Compare both withdrawal options';

  @override
  String get pulseComprendreRachatLpp => 'Simulate an LPP buyback';

  @override
  String get pulseComprendreRachatLppSub =>
      'Discover the tax impact of a buyback';

  @override
  String get pulseComprendre3a => 'Explore my 3a';

  @override
  String get pulseComprendre3aSub => 'Discover your annual tax saving';

  @override
  String get pulseComprendre_budget => 'My monthly budget';

  @override
  String get pulseComprendre_budgetSub => 'View your income and expenses';

  @override
  String get pulseComprendreAchat => 'Buy a property?';

  @override
  String get pulseComprendreAchatSub => 'Estimate your borrowing capacity';

  @override
  String get pulseDisclaimer =>
      'Educational tool. Does not constitute personalised financial advice. FinSA art. 3';

  @override
  String get pulseKeyFigRetraite => 'Estimated retirement';

  @override
  String pulseKeyFigRetraitePct(String pct) {
    return '$pct % of income';
  }

  @override
  String get pulseKeyFigBudgetLibre => 'Free budget';

  @override
  String get pulseKeyFigPatrimoine => 'Net worth';

  @override
  String pulseCoupleRetraite(String montant) {
    return 'Couple retirement: $montant';
  }

  @override
  String pulseCoupleAlertWeak(String name, String score) {
    return '$name\'s profile is at $score % visibility';
  }

  @override
  String get pulseAxisLiquidite => 'Liquidity';

  @override
  String get pulseAxisFiscalite => 'Taxation';

  @override
  String get pulseAxisRetraite => 'Retirement';

  @override
  String get pulseAxisSecurite => 'Security';

  @override
  String get pulseHintAddSalary => 'Add your salary to get started';

  @override
  String get pulseHintAddSavings => 'Enter your savings and investments';

  @override
  String get pulseHintLiquiditeComplete => 'Your liquidity data is complete';

  @override
  String get pulseHintAddAgeCanton => 'Enter your age and canton of residence';

  @override
  String get pulseHintScanTax => 'Scan your tax return';

  @override
  String get pulseHintFiscaliteComplete => 'Your tax data is complete';

  @override
  String get pulseHintAddLpp => 'Add your LPP certificate';

  @override
  String get pulseHintExtractAvs => 'Order your AVS extract';

  @override
  String get pulseHintAdd3a => 'Enter your 3a accounts';

  @override
  String get pulseHintRetraiteComplete => 'Your retirement data is complete';

  @override
  String get pulseHintAddFamily => 'Enter your family situation';

  @override
  String get pulseHintAddStatus => 'Complete your professional status';

  @override
  String get pulseHintSecuriteComplete => 'Your security data is complete';

  @override
  String get pulseNarrativeExcellent =>
      'You have a clear view of your situation. Keep your data up to date.';

  @override
  String pulseNarrativeGood(String axis) {
    return 'Good visibility! Refine your $axis to go further.';
  }

  @override
  String pulseNarrativeModerate(String axis) {
    return 'You\'re starting to see more clearly. Focus on your $axis.';
  }

  @override
  String pulseNarrativeWeak(String hint) {
    return 'Every piece of information counts. Start with $hint.';
  }

  @override
  String get pulseNoCheckinMsg =>
      'No check-in this month. Record your payments to track your progress.';

  @override
  String get pulseCheckinBtn => 'Check-in';

  @override
  String pulseBriefingTitle(String trend) {
    return 'Monthly review — $trend';
  }

  @override
  String get pulseFriLiquidite => 'Liquidity';

  @override
  String get pulseFriFiscalite => 'Tax optimisation';

  @override
  String get pulseFriRetraite => 'Retirement';

  @override
  String get pulseFriRisque => 'Structural risks';

  @override
  String get pulseFriTitle => 'Financial strength';

  @override
  String pulseFriWeakest(String axis) {
    return 'Weakest point: $axis';
  }

  @override
  String get lppBuybackAdvTitle => 'LPP buyback optimisation';

  @override
  String get lppBuybackAdvSubtitle => 'Tax leverage + capitalisation effect';

  @override
  String get lppBuybackAdvPotential => 'Buyback potential';

  @override
  String get lppBuybackAdvYears => 'Years until retirement';

  @override
  String get lppBuybackAdvStaggering => 'Staggering';

  @override
  String get lppBuybackAdvFundRate => 'LPP fund rate';

  @override
  String get lppBuybackAdvIncome => 'Taxable income';

  @override
  String get lppBuybackAdvFinalCapital => 'Final capitalised value';

  @override
  String lppBuybackAdvRealReturn(String pct) {
    return 'Real return: $pct % / year';
  }

  @override
  String get lppBuybackAdvTaxSaving => 'Tax saving';

  @override
  String get lppBuybackAdvNetEffort => 'Net effort';

  @override
  String get lppBuybackAdvTotalGain => 'Total gain from operation';

  @override
  String get lppBuybackAdvCapitalMinusEffort => 'Capital - Net effort';

  @override
  String get lppBuybackAdvFundRateLabel => 'LPP rate applied';

  @override
  String get lppBuybackAdvLeverageEffect => 'Tax leverage effect';

  @override
  String get lppBuybackAdvBonASavoir => 'Good to know';

  @override
  String get lppBuybackAdvBon1 =>
      'LPP buyback is one of the few tax planning tools available to all employees in Switzerland.';

  @override
  String get lppBuybackAdvBon2 =>
      'Every franc bought back is deductible from your taxable income (LIFD art. 33 al. 1 let. d).';

  @override
  String get lppBuybackAdvBon3 =>
      'Note: any EPL withdrawal is blocked for 3 years after a buyback (LPP art. 79b al. 3).';

  @override
  String get lppBuybackAdvDisclaimer =>
      'Simulation including fund interest and smoothed tax savings. The real return is calculated on your actual net effort.';

  @override
  String get householdTitle => 'Our Family';

  @override
  String get householdDiscoverCouplePlus => 'Discover Couple+';

  @override
  String get householdLoginPrompt => 'Log in to manage your household';

  @override
  String get householdLogin => 'Log in';

  @override
  String get householdRetry => 'Retry';

  @override
  String get householdInvitePartner => 'Invite my partner';

  @override
  String get householdRemoveMemberTitle => 'Remove this member?';

  @override
  String get householdRemoveMemberContent =>
      'This action is irreversible. A 30-day waiting period applies before you can invite a new partner.';

  @override
  String get householdCancel => 'Cancel';

  @override
  String get householdRemove => 'Remove';

  @override
  String get householdSendInvitation => 'Send invitation';

  @override
  String get householdCodeCopied => 'Code copied';

  @override
  String get householdMessageCopied => 'Message copied';

  @override
  String get householdCopy => 'Copy';

  @override
  String get householdShare => 'Share';

  @override
  String get householdHaveCode => 'I have an invitation code';

  @override
  String get householdCouplePlusTitle => 'Couple+';

  @override
  String get householdUpsellDescription =>
      'Optimise your retirement as a couple with a Couple+ subscription. Shared projections, staggered withdrawals, and couple coaching.';

  @override
  String get householdEmptyDescription =>
      'Optimise your retirement as a couple. Staggered withdrawals, couple projections, and a shared fiscal calendar.';

  @override
  String get householdHeaderTitle => 'Couple+ Household';

  @override
  String get householdMembersTitle => 'Members';

  @override
  String get householdOwnerBadge => 'Owner';

  @override
  String get householdPendingStatus => 'Invitation pending';

  @override
  String get householdActiveStatus => 'Active';

  @override
  String get householdRemoveTooltip => 'Remove from household';

  @override
  String get householdInviteSectionTitle => 'Invite a partner';

  @override
  String get householdInviteInfo =>
      'Your partner will receive an invitation code valid for 72 hours.';

  @override
  String get householdEmailLabel => 'Partner email';

  @override
  String get householdEmailHint => 'partner@email.ch';

  @override
  String get householdInviteSentTitle => 'Invitation sent';

  @override
  String get householdValidFor => 'Valid for 72 hours';

  @override
  String householdShareMessage(String code) {
    return 'Join my MINT household with the code: $code\n\nOpen the MINT app > Family > I have a code';
  }

  @override
  String householdMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count active member$_temp0';
  }

  @override
  String get householdPartnerDefault => 'Partner';

  @override
  String get documentScanCancel => 'Cancel';

  @override
  String get documentScanAnalyze => 'Analyse';

  @override
  String get documentScanTakePhoto => 'Take a photo';

  @override
  String get documentScanPasteOcr => 'Paste OCR text';

  @override
  String get documentScanCreateAccount => 'Create an account';

  @override
  String get documentScanRetakePhoto => 'Retake photo';

  @override
  String get documentScanExtracting => 'Extracting...';

  @override
  String get documentScanImportFile => 'Import a file';

  @override
  String get documentScanOcrTitle => 'OCR Text';

  @override
  String get documentScanPdfAuthTitle => 'Login required for PDF';

  @override
  String get documentScanPdfAuthContent =>
      'Automatic PDF analysis goes through the backend and requires a connected account. Without an account, you can scan a photo.';

  @override
  String get documentScanOcrHint =>
      'Paste the OCR text extracted from your PDF to continue.';

  @override
  String get documentScanOcrRetryHint =>
      'Paste the OCR text if the photo remains unreadable.';

  @override
  String get profileFamilySection => 'Family';

  @override
  String get profileAnalyticsBeta => 'Analytics beta testers';

  @override
  String get profileDeleteAccountTitle => 'Delete account?';

  @override
  String get profileDeleteAccountContent =>
      'This action deletes your cloud account and associated data. Your local data remains on this device.';

  @override
  String get profileDeleteCancel => 'Cancel';

  @override
  String get profileDeleteConfirm => 'Delete';

  @override
  String get consentAllRevoked => 'All optional consents have been revoked.';

  @override
  String get consentClose => 'Close';

  @override
  String get consentExportData => 'Export my data (nLPD art. 28)';

  @override
  String get consentRevokeAll => 'REVOKE ALL OPTIONAL CONSENTS';

  @override
  String get consentControlCenter => 'DATA CONTROL CENTRE';

  @override
  String get consentSecurityMessage =>
      'Your data stays on your device. You retain full control over third-party access.';

  @override
  String get consentRequired => 'Required';

  @override
  String get consentRequiredTitle => 'Required consents';

  @override
  String get consentOptionalTitle => 'Optional consents';

  @override
  String get consentExportTitle => 'Export your data';

  @override
  String consentRetentionDays(int days) {
    return 'Retention: $days days';
  }

  @override
  String get consentLegalSources => 'Legal sources';

  @override
  String get pillar3aPaymentPerYear => 'Payment/year:';

  @override
  String get pillar3aDuration => 'Duration:';

  @override
  String get pillar3aOpenViac => 'Open my VIAC account';

  @override
  String get pillar3aFees => 'Fees';

  @override
  String get pillar3aReturn => 'Return';

  @override
  String get pillar3aAt65 => 'At 65';

  @override
  String get pillar3aComparator => '3a Comparator';

  @override
  String pillar3aProjection(int years) {
    return 'Projection over $years years';
  }

  @override
  String get pillar3aScenarioTitle => 'Scenario: Max annual contribution';

  @override
  String pillar3aDurationYears(int years) {
    return '$years years (until age 65)';
  }

  @override
  String get pillar3aViacGainLabel => 'With VIAC instead of a bank:';

  @override
  String get pillar3aMoreAtRetirement => 'more at retirement!';

  @override
  String get pillar3aDisclaimer =>
      'Educational assumptions based on historical average returns. Past returns do not guarantee future returns.';

  @override
  String get pillar3aCapitalEvolution => 'Your 3a capital evolution';

  @override
  String get pillar3aYearLabel => 'Year';

  @override
  String get pillar3aBank15 => 'Bank 1.5%';

  @override
  String get pillar3aViac45 => 'VIAC 4.5%';

  @override
  String pillar3aYearN(int n) {
    return 'Year $n';
  }

  @override
  String get pillar3aCompoundTip =>
      'The last years account for +50% of the total gain thanks to compound interest!';

  @override
  String get pillar3aRecommended => 'RECOMMENDED';

  @override
  String pillar3aVsBank(String amount) {
    return '$amount vs Bank';
  }

  @override
  String get wizardCollapse => 'Collapse';

  @override
  String get wizardUnderstandTopic => 'Understand this topic';

  @override
  String get wizardSeeSimulation => 'See interactive simulation';

  @override
  String get wizardNext => 'Next';

  @override
  String get wizardExplanation => 'Explanation';

  @override
  String wizardValidateCount(int count) {
    return 'Validate ($count)';
  }

  @override
  String get wizardInvalidNumber => 'Enter a valid number';

  @override
  String wizardMinValue(String value) {
    return 'Minimum: $value';
  }

  @override
  String wizardMaxValue(String value) {
    return 'Maximum: $value';
  }

  @override
  String get wizardFieldRequired => 'This field is required';

  @override
  String get slmCancelDownload => 'Cancel download';

  @override
  String get slmCancel => 'Cancel';

  @override
  String get slmDownload => 'Download';

  @override
  String get slmDelete => 'Delete';

  @override
  String get slmIaOnDevice => 'On-device AI';

  @override
  String get slmPrivacyMessage =>
      'The model runs 100% on your device. No data leaves your phone.';

  @override
  String get slmDownloadModelTitle => 'Download the model?';

  @override
  String get slmDeleteModelTitle => 'Delete the model?';

  @override
  String slmDeleteModelContent(String size) {
    return 'This will free up $size of space. You can re-download it at any time.';
  }

  @override
  String get slmDeleteModelButton => 'Delete model';

  @override
  String get slmStartingDownload => 'Starting download...';

  @override
  String get slmRetryDownload => 'Retry download';

  @override
  String get slmDownloadUnavailable => 'Download unavailable on this build';

  @override
  String get slmEngineStatus => 'Engine status';

  @override
  String get slmHowItWorks => 'How does it work?';

  @override
  String get landingPunchline1 => 'The Swiss financial system is powerful.';

  @override
  String get landingPunchline2 => 'If you understand it.';

  @override
  String get landingCtaComprendre => 'Understand';

  @override
  String get landingJargon1 => 'Coordination deduction';

  @override
  String get landingClear1 => 'What they deduct';

  @override
  String get landingJargon2 => 'Imputed rental value';

  @override
  String get landingClear2 => 'The tax on your home';

  @override
  String get landingJargon3 => 'Marginal tax rate';

  @override
  String get landingClear3 => 'What you actually pay';

  @override
  String get landingJargon4 => 'Pension gap';

  @override
  String get landingClear4 => 'What you\'ll be missing';

  @override
  String get landingJargon5 => 'Transfer tax';

  @override
  String get landingClear5 => 'The tax when you buy';

  @override
  String get landingWhyNobody =>
      'What you don\'t know is costing you. Every year.';

  @override
  String get landingMintDoesIt => 'MINT does.';

  @override
  String get landingCtaCommencer => 'Get started';

  @override
  String get landingLegalFooterShort =>
      'Educational tool. Not financial advice (FinSA). Data stays on your device.';

  @override
  String pulseDigitalTwinPct(String pct) {
    return 'Digital twin: $pct%';
  }

  @override
  String get pulseDigitalTwinHint =>
      'The more complete your profile, the more reliable your projections.';

  @override
  String get pulseActionsThisMonth => 'To do this month';

  @override
  String get pulseHeroChangeBtn => 'Change';

  @override
  String get pulseCoachInsightTitle => 'Coach\'s insight';

  @override
  String get pulseRefineProfile => 'Refine my profile';

  @override
  String get pulseWhatIf3aQuestion => 'What if you maxed out your 3a?';

  @override
  String pulseWhatIf3aImpact(String amount) {
    return '−CHF $amount/year in taxes';
  }

  @override
  String get pulseWhatIfLppQuestion => 'What if you bought back pension fund?';

  @override
  String pulseWhatIfLppImpact(String amount) {
    return 'Up to −CHF $amount in taxes';
  }

  @override
  String get pulseWhatIfEarlyQuestion => 'What if you retired 1 year earlier?';

  @override
  String pulseWhatIfEarlyImpact(String amount) {
    return '−CHF $amount/month pension';
  }

  @override
  String get pulseActionSignalSingular => '1 action to do';

  @override
  String pulseActionSignalPlural(String count) {
    return '$count actions to do';
  }

  @override
  String get agirTopActionCta => 'Get started';

  @override
  String agirOtherActions(String count) {
    return '$count other actions';
  }

  @override
  String get exploreSuggestionLabel => 'Suggestion for you';

  @override
  String get exploreSuggestion3aTitle => 'Pillar 3a: your first tax lever';

  @override
  String get exploreSuggestion3aSub =>
      'Find out how much you can save on taxes';

  @override
  String get exploreSuggestionLppTitle => 'LPP buyback: an opportunity?';

  @override
  String get exploreSuggestionLppSub =>
      'Simulate the impact on your retirement and taxes';

  @override
  String get exploreSuggestionRetirementTitle =>
      'Your retirement is approaching';

  @override
  String get exploreSuggestionRetirementSub =>
      'Annuity, capital or mix? Compare your options';

  @override
  String get exploreSuggestionBudgetTitle => 'Start with your budget';

  @override
  String get exploreSuggestionBudgetSub =>
      '3 minutes to see where your money goes';

  @override
  String get pulseReadinessTitle => 'Financial fitness';

  @override
  String get pulseReadinessGood => 'Well prepared';

  @override
  String get pulseReadinessProgress => 'In progress';

  @override
  String get pulseReadinessWeak => 'Needs strengthening';

  @override
  String pulseReadinessRetireIn(int years) {
    return 'Retirement in $years years';
  }

  @override
  String pulseReadinessYearsToAct(int years) {
    return 'Still $years years to act';
  }

  @override
  String get pulseReadinessActNow => 'The essentials are happening now';

  @override
  String get pulseReadinessRetired => 'Already retired';

  @override
  String get pulseCompleteProfile => 'Complete your profile';

  @override
  String get profileSectionMyFile => 'My file';

  @override
  String get profileSectionSettings => 'Settings';

  @override
  String get profileCompletionLabel => 'Your file';

  @override
  String get agirBudgetNet => 'Net';

  @override
  String get agirBudgetFixed => 'Fixed';

  @override
  String get agirBudgetAvailable => 'Available';

  @override
  String get agirBudgetSaved => 'Saved';

  @override
  String get agirBudgetRemaining => 'Left';

  @override
  String get agirBudgetWarning =>
      'Your contributions exceed your available budget';

  @override
  String get enrichmentCtaScan => 'Scan a document';

  @override
  String enrichmentCtaMissing(int count) {
    return '$count field(s) to complete';
  }

  @override
  String get heroGapTitle => 'At retirement, you\'ll be short';

  @override
  String get heroGapCovered => 'You\'re well covered';

  @override
  String get heroGapPerMonth => '/month';

  @override
  String get heroGapToday => 'Today';

  @override
  String get heroGapRetirement => 'Retirement';

  @override
  String get heroGapConfidence => 'Confidence';

  @override
  String get heroGapScanCta => 'Scan LPP certificate';

  @override
  String heroGapBoost(int percent) {
    return '+$percent % accuracy';
  }

  @override
  String get heroGapMetaphor5k =>
      'It\'s like going from a 5-room flat to a studio';

  @override
  String get heroGapMetaphor3k => 'It\'s like giving up your car and holidays';

  @override
  String get heroGapMetaphor1k => 'It\'s like cutting out restaurant outings';

  @override
  String get heroGapMetaphorSmall => 'It\'s a coffee a day difference';

  @override
  String get drawerCeQueTuAs => 'What you have';

  @override
  String get drawerCeQueTuAsSubtitle => 'Net worth';

  @override
  String get drawerCeQueTuDois => 'What you owe';

  @override
  String get drawerCeQueTuDoisSubtitle => 'Total debt';

  @override
  String get drawerCeQueTuAuras => 'What you\'ll have';

  @override
  String get drawerCeQueTuAurasSubtitle => 'Projected retirement income';

  @override
  String get shellWelcomeBack => 'Welcome back! Your data is up to date.';

  @override
  String get shellRecommendationsUpdated => 'Recommendations updated';

  @override
  String get pulseEnrichirTitle => 'Scan your LPP certificate';

  @override
  String pulseEnrichirSubtitle(String points) {
    return 'Confidence → +$points points';
  }

  @override
  String get pulseEnrichirCta => 'Scan →';

  @override
  String get tabMoi => 'Me';

  @override
  String get coupleSwitchSolo => 'Solo';

  @override
  String get coupleSwitchDuo => 'Duo';

  @override
  String get identityStatusSalarie => 'Employed';

  @override
  String get identityStatusIndependant => 'Self-employed';

  @override
  String get identityStatusChomage => 'Job seeking';

  @override
  String get identityStatusRetraite => 'Retired';

  @override
  String get simLppBuybackTitle => 'LPP Buyback Optimization';

  @override
  String get simLppBuybackSubtitle => 'Fiscal leverage + Capitalization';

  @override
  String get simLppBuybackPotential => 'Buyback potential';

  @override
  String get simLppBuybackYearsToRetirement => 'Years to retirement';

  @override
  String get simLppBuybackStaggering => 'Staggering';

  @override
  String get simLppBuybackFundRate => 'LPP fund rate';

  @override
  String get simLppBuybackTaxableIncome => 'Taxable income';

  @override
  String get simLppBuybackUnitChf => 'CHF';

  @override
  String get simLppBuybackUnitYears => 'years';

  @override
  String get simLppBuybackFinalCapital => 'Final Capitalized Value';

  @override
  String simLppBuybackRealReturn(String rate) {
    return 'Real Return: $rate% / year';
  }

  @override
  String get simLppBuybackTaxSavings => 'Tax Savings';

  @override
  String get simLppBuybackNetEffort => 'Net Effort';

  @override
  String get simLppBuybackTotalGain => 'Total Operation Gain';

  @override
  String get simLppBuybackCapitalMinusEffort => 'Capital - Net Effort';

  @override
  String get simLppBuybackFundRateLabel => 'LPP rate served';

  @override
  String get simLppBuybackFiscalLeverage => 'Fiscal leverage effect';

  @override
  String get simLppBuybackBonASavoir => 'Good to know';

  @override
  String get simLppBuybackBonASavoirItem1 =>
      'LPP buyback is one of the few tax planning tools accessible to all employees in Switzerland.';

  @override
  String get simLppBuybackBonASavoirItem2 =>
      'Every franc bought back is deductible from your taxable income (LIFD art. 33 al. 1 let. d).';

  @override
  String get simLppBuybackBonASavoirItem3 =>
      'Warning: any EPL withdrawal is blocked for 3 years after a buyback (LPP art. 79b al. 3).';

  @override
  String simLppBuybackDisclaimer(
      String fundRate, int staggeringYears, String taxableIncome) {
    return 'Simulation including fund interest ($fundRate%) and tax savings staggered over $staggeringYears years for a taxable income of CHF $taxableIncome. Real return is calculated on your actual net effort.';
  }

  @override
  String get simRealInterestTitle => 'Real Interest Simulator';

  @override
  String get simRealInterestSubtitle =>
      'Capital + Reinvested tax savings (Virtual)';

  @override
  String get simRealInterestAmount => 'Amount Invested';

  @override
  String get simRealInterestDuration => 'Duration';

  @override
  String get simRealInterestPessimistic => 'Pessimistic';

  @override
  String get simRealInterestNeutral => 'Neutral';

  @override
  String get simRealInterestOptimistic => 'Optimistic';

  @override
  String simRealInterestHypotheses(String rate) {
    return 'Assumptions: Marginal rate $rate%. Market returns: 2% / 4% / 6%.';
  }

  @override
  String get simRealInterestEducTitle => 'Understanding real return';

  @override
  String get simRealInterestEducBullet1 =>
      'Real return = nominal return − inflation − fees';

  @override
  String get simRealInterestEducBullet2 =>
      'A 3% investment with 1.5% inflation and 0.5% fees yields only 1% in real terms';

  @override
  String get simRealInterestEducBullet3 =>
      'Over 30 years, this difference can represent tens of thousands of francs';

  @override
  String get simBuybackTitle => 'LPP Buyback Strategy';

  @override
  String get simBuybackSubtitle => 'Optimization through staggering';

  @override
  String get simBuybackDuration => 'Staggering duration';

  @override
  String simBuybackYears(int count) {
    return '$count years';
  }

  @override
  String get simBuybackLessOptimized => 'Less Optimized';

  @override
  String get simBuybackSingleShot => 'Lump sum';

  @override
  String get simBuybackOptimized => 'Optimized';

  @override
  String simBuybackInNTimes(int count) {
    return 'In $count times';
  }

  @override
  String simBuybackEstimatedGain(String amount) {
    return 'Estimated gain: + CHF $amount';
  }

  @override
  String get simBuybackSavingsLabel => 'Savings';

  @override
  String get simBuybackMarginalRateQuestion => 'What is the marginal tax rate?';

  @override
  String get simBuybackMarginalRateTitle => 'Marginal tax rate';

  @override
  String get simBuybackMarginalRateExplanation =>
      'The marginal rate is the tax percentage on your last franc earned. The higher your income, the higher this rate.';

  @override
  String get simBuybackMarginalRateTip =>
      'By staggering your buybacks, you stay in lower tax brackets each year, which increases your total tax savings.';

  @override
  String get simBuybackLockedTitle => 'LPP Buyback locked';

  @override
  String get simBuybackLockedMessage =>
      'LPP buyback is disabled in protection mode. A buyback locks your liquidity for 3 years (LPP art. 79b al. 3). Pay off your debts first before locking up capital.';

  @override
  String get pcWidgetTitle => 'Supplementary Benefits (PC)';

  @override
  String get pcWidgetSubtitle => 'Local eligibility checklist';

  @override
  String get pcWidgetRevenus => 'Income';

  @override
  String get pcWidgetFortune => 'Assets';

  @override
  String get pcWidgetLoyer => 'Rent';

  @override
  String get pcWidgetEligible =>
      'Your situation suggests a potential right to supplementary benefits.';

  @override
  String get pcWidgetNotEligible =>
      'Your income seems sufficient according to standard scales.';

  @override
  String pcWidgetFindOffice(String canton) {
    return 'Find the PC office ($canton)';
  }

  @override
  String get letterGenTitle => 'Automatic Secretariat';

  @override
  String get letterGenSubtitle => 'Generate ready-to-use letter templates.';

  @override
  String get letterGenBuybackTitle => 'LPP Buyback Request';

  @override
  String get letterGenBuybackSubtitle => 'To find out your buyback potential.';

  @override
  String get letterGenTaxTitle => 'Tax Certificate';

  @override
  String get letterGenTaxSubtitle => 'For your tax return.';

  @override
  String get letterGenDisclaimer =>
      'These documents are templates to be completed. They do not constitute legal advice.';

  @override
  String get precisionPromptTitle => 'Precision available';

  @override
  String get precisionPromptPreciser => 'Refine';

  @override
  String get precisionPromptContinuer => 'Continue';

  @override
  String get earlyRetirementHeader => 'What if I retired at…';

  @override
  String earlyRetirementAgeDisplay(int age) {
    return '$age years';
  }

  @override
  String get earlyRetirementZoneRisky =>
      'Risky — significant financial sacrifice';

  @override
  String get earlyRetirementZoneFeasible => 'Feasible — with compromises';

  @override
  String get earlyRetirementZoneStandard => 'Standard — no penalty';

  @override
  String get earlyRetirementZoneBonus =>
      'Bonus — you earn more, but enjoy it less long';

  @override
  String earlyRetirementResultLine(int age, String amount) {
    return 'At $age : $amount/month';
  }

  @override
  String earlyRetirementNarrativeEarly(
      String amount, int years, String plural) {
    return 'You lose $amount/month for life. But you gain $years year$plural of freedom.';
  }

  @override
  String earlyRetirementNarrativeLate(String amount, int years, String plural) {
    return 'You gain $amount/month more. $years year$plural of extra work.';
  }

  @override
  String earlyRetirementLifetimeImpact(String amount) {
    return 'Estimated impact over 25 years : $amount';
  }

  @override
  String get earlyRetirementDisclaimer =>
      'Educational estimates — not financial advice (LSFin).';

  @override
  String earlyRetirementSemanticsLabel(int age) {
    return 'Retirement age simulator. Selected age : $age years.';
  }

  @override
  String get budgetReportTitle => 'Your Calculated Budget';

  @override
  String get budgetReportDisponible => 'Available';

  @override
  String get budgetReportVariables => 'Variable (Living)';

  @override
  String get budgetReportFutur => 'Future (Savings)';

  @override
  String budgetReportChfAmount(String amount) {
    return 'CHF $amount';
  }

  @override
  String get budgetReportStopWarning =>
      'Warning: No room for variable expenses.';

  @override
  String get ninetyDayGaugeTitle => '90-Day Rule';

  @override
  String get ninetyDayGaugeSubtitle => 'Cross-border  ·  Tax threshold';

  @override
  String get ninetyDayGaugeDaysOf90 => '/ 90 days';

  @override
  String get ninetyDayGaugeStatusRed =>
      'Threshold exceeded — risk of ordinary taxation in Switzerland';

  @override
  String ninetyDayGaugeStatusOrange(int remaining, String plural) {
    return 'Warning: only $remaining day$plural left before threshold';
  }

  @override
  String ninetyDayGaugeStatusGreen(int remaining, String plural) {
    return 'Safe zone — $remaining day$plural remaining before threshold';
  }

  @override
  String ninetyDayGaugeSemanticsLabel(int days, String status) {
    return '90-day rule gauge. $days days out of 90. $status';
  }

  @override
  String get ninetyDayGaugeZoneSafe => 'Safe zone';

  @override
  String get ninetyDayGaugeZoneAttention => 'Caution';

  @override
  String get ninetyDayGaugeZoneRisk => 'Tax risk';

  @override
  String get forfaitFiscalTitle => 'Lump-sum tax vs Ordinary';

  @override
  String get forfaitFiscalSubtitle => 'Annual comparison  ·  Expatriates';

  @override
  String get forfaitFiscalSaving => 'Lump-sum savings';

  @override
  String get forfaitFiscalSurcharge => 'Lump-sum surcharge';

  @override
  String get forfaitFiscalPerYear => 'per year';

  @override
  String forfaitFiscalSemanticsLabel(
      String ordinary, String forfait, String savings) {
    return 'Lump-sum tax comparison. Ordinary taxation: $ordinary. Lump-sum tax: $forfait. Savings: $savings.';
  }

  @override
  String get forfaitFiscalOrdinaryLabel => 'Ordinary\ntaxation';

  @override
  String get forfaitFiscalForfaitLabel => 'Lump-sum\ntax';

  @override
  String get forfaitFiscalBaseLine => 'Lump-sum base';

  @override
  String get spendingMeterBudgetUnavailable => 'Budget unavailable';

  @override
  String get spendingMeterDisponible => 'Available';

  @override
  String spendingMeterVariablesLegend(int percent) {
    return 'Variable $percent%';
  }

  @override
  String spendingMeterFuturLegend(int percent) {
    return 'Future $percent%';
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
      'Ton salaire brut est la base de toutes les projections : prévoyance, impôts, budget. Plus il est précis, plus tes résultats seront fiables.';

  @override
  String get dataBlockRevenuCta => 'Préciser mon revenu';

  @override
  String get dataBlockLppTitle => 'Prévoyance LPP';

  @override
  String get dataBlockLppDesc =>
      'Ton avoir LPP (2e pilier) représente souvent le plus gros capital de ta prévoyance. Un certificat de prévoyance donne une valeur exacte plutôt qu\'une estimation.';

  @override
  String get dataBlockLppCta => 'Ajouter mon certificat LPP';

  @override
  String get dataBlockAvsTitle => 'Extrait AVS';

  @override
  String get dataBlockAvsDesc =>
      'L\'extrait AVS confirme tes années de cotisation effectives. Des lacunes (séjour à l\'étranger, années manquantes) réduisent ta rente AVS.';

  @override
  String get dataBlockAvsCta => 'Commander mon extrait AVS';

  @override
  String get dataBlock3aTitle => '3e pilier (3a)';

  @override
  String get dataBlock3aDesc =>
      'Tes comptes 3a s\'ajoutent à ta prévoyance et offrent un avantage fiscal. Renseigne les soldes actuels pour une vue complète.';

  @override
  String get dataBlock3aCta => 'Simuler mon 3a';

  @override
  String get dataBlockPatrimoineTitle => 'Patrimoine';

  @override
  String get dataBlockPatrimoineDesc =>
      'Épargne libre, investissements, immobilier : ces données complètent ta projection et permettent de calculer ton Financial Resilience Index.';

  @override
  String get dataBlockPatrimoineCta => 'Renseigner mon patrimoine';

  @override
  String get dataBlockFiscaliteTitle => 'Fiscalité';

  @override
  String get dataBlockFiscaliteDesc =>
      'Ta commune, ton revenu imposable et ta fortune déterminent ton taux marginal d\'imposition. Une déclaration fiscale ou un avis de taxation donne un taux réel plutôt qu\'estimé (coefficient communal 60%-130%).';

  @override
  String get dataBlockFiscaliteCta => 'Comparer ma fiscalité';

  @override
  String get dataBlockObjectifTitle => 'Objectif retraite';

  @override
  String get dataBlockObjectifDesc =>
      'À quel âge souhaites-tu arrêter de travailler ? Un objectif clair permet de calculer l\'effort d\'épargne nécessaire et les options (anticipation, retraite partielle).';

  @override
  String get dataBlockObjectifCta => 'Voir ma projection';

  @override
  String get dataBlockMenageTitle => 'Composition du ménage';

  @override
  String get dataBlockMenageDesc =>
      'En couple, les projections changent : AVS plafonnée pour les mariés (LAVS art. 35), rente de survivant (LPP art. 19), optimisation fiscale à deux.';

  @override
  String get dataBlockMenageCta => 'Gérer mon ménage';

  @override
  String get dataBlockUnknownTitle => 'Données';

  @override
  String get dataBlockUnknownDesc =>
      'Ce lien de données n’est plus à jour. Utilise la section recommandée pour compléter ton profil.';

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
      'À la retraite, tu choisis une fois pour toutes : un revenu à vie ou ton capital en main.';

  @override
  String get renteVsCapitalRenteLabel => 'Rente';

  @override
  String get renteVsCapitalRenteExplanation =>
      'Ta caisse de pension te verse un montant fixe chaque mois, tant que tu vis — même si tu atteins 100 ans. En échange, tu ne récupères jamais ton capital.';

  @override
  String get renteVsCapitalCapitalLabel => 'Capital';

  @override
  String get renteVsCapitalCapitalExplanation =>
      'Tu récupères tout ton avoir LPP d\'un coup. Tu le places, tu retires ce dont tu as besoin chaque mois. Liberté totale, mais le risque de manquer est réel.';

  @override
  String get renteVsCapitalMixteLabel => 'Mixte';

  @override
  String get renteVsCapitalMixteExplanation =>
      'La partie obligatoire en rente (taux 6.8 %) + le surobligatoire en capital. Un compromis entre sécurité et flexibilité.';

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
    return 'Avec le capital, tu pourrais manquer d\'argent dès $age ans. Avec la rente, tu reçois un montant fixe à vie. Tu ne peux choisir qu\'une fois.';
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
      'Capital (vert) : ce qu\'il reste après tes retraits. Rente (bleu) : total reçu depuis le départ. Le croisement = l\'âge auquel la rente a plus rapporté.';

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
      'Si tu fais des rachats LPP chaque année, leur valeur futur est ajoutée au capital à la retraite. Blocage 3 ans avant EPL (LPP art. 79b).';

  @override
  String get renteVsCapitalEplLabel => 'Retrait EPL pour achat immobilier';

  @override
  String get renteVsCapitalEplHint => 'Montant retiré (min 20\'000)';

  @override
  String get renteVsCapitalEplTooltip =>
      'Le retrait EPL réduit ton avoir LPP et donc ton capital ou ta rente à la retraite. Minimum CHF 20\'000 (OPP2 art. 5). Bloque le rachat LPP pendant 3 ans.';

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
      'Si plus de 90% de tes revenus mondiaux proviennent de Suisse, tu peux demander la taxation ordinaire avec déductions (3a, frais effectifs, etc.). Cela peut réduire significativement ton impôt.';

  @override
  String get frontalierTessinTitle => 'Tessin — régime spécial';

  @override
  String get frontalierEducationalTax =>
      'En Suisse, les frontaliers sont imposés à la source (barème C). Le taux varie selon le canton, l\'état civil et le nombre d\'enfants. À Genève, si plus de 90% de tes revenus mondiaux proviennent de Suisse, tu peux demander le statut de quasi-résident pour bénéficier des déductions.';

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
      'Depuis 2023, les accords amiables entre la Suisse et ses voisins fixent un seuil de tolérance pour le télétravail des frontaliers. Au-delà de 90 jours de home office par an, les cotisations sociales et l\'imposition peuvent basculer vers le pays de résidence.';

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
  String get frontalierLamalDesc =>
      'Obligatoire si tu travailles en CH. Prime individuelle (~CHF 300-500/mois).';

  @override
  String get frontalierCmuTitle => 'CMU/Sécu (France)';

  @override
  String get frontalierCmuDesc =>
      'Droit d\'option possible pour les frontaliers FR. Cotisation ~8% du revenu fiscal.';

  @override
  String get frontalierAssurancePriveeTitle => 'Assurance privée (DE/IT/AT)';

  @override
  String get frontalierAssurancePriveeDesc =>
      'En Allemagne, option PKV pour hauts revenus. IT/AT : régime obligatoire du pays.';

  @override
  String get frontalierEducationalCharges =>
      'En tant que frontalier, tu cotises aux assurances sociales suisses (AVS/AI/APG, AC, LPP). Les taux sont généralement plus bas qu\'en France ou en Allemagne — mais la LAMal est à ta charge individuellement, ce qui peut compenser l\'avantage.';

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
    return 'En concubinage, ton partenaire paierait $impot d\'impôt successoral sur un patrimoine de $patrimoine. Marié-e, il/elle serait totalement exonéré-e.';
  }

  @override
  String get concubinageNeutralTitle =>
      'Aucune option n\'est universellement meilleure';

  @override
  String get concubinageNeutralDesc =>
      'Le choix entre mariage et concubinage dépend de ta situation : revenus, patrimoine, enfants, canton, projet de vie. Le mariage offre plus de protections légales automatiques, le concubinage plus de flexibilité. Un·e spécialiste peut t\'aider à y voir plus clair.';

  @override
  String get concubinageChecklistIntro =>
      'En concubinage, rien n\'est automatique. Voici les protections essentielles à mettre en place pour protéger ton/ta partenaire.';

  @override
  String concubinageProtectionsCount(int count, int total) {
    return '$count/$total protections en place';
  }

  @override
  String get concubinageChecklist1Title => 'Rédiger un testament';

  @override
  String get concubinageChecklist1Desc =>
      'Sans testament, ton partenaire n\'hérite de rien — tout va à tes parents ou à tes frères et sœurs. Un testament olographe (écrit à la main, daté, signé) suffit. Tu peux léguer la quotité disponible à ton/ta partenaire.';

  @override
  String get concubinageChecklist2Title => 'Clause bénéficiaire LPP';

  @override
  String get concubinageChecklist2Desc =>
      'Contacte ta caisse de pension pour inscrire ton/ta partenaire comme bénéficiaire. Sans cette clause, le capital décès LPP ne lui revient pas. La plupart des caisses acceptent le concubin sous conditions (ménage commun, etc.).';

  @override
  String get concubinageChecklist3Title => 'Convention de concubinage';

  @override
  String get concubinageChecklist3Desc =>
      'Un contrat écrit qui règle le partage des frais, la propriété des biens, et ce qui se passe en cas de séparation. Pas obligatoire, mais fortement recommandé — surtout si tu achètes un bien immobilier ensemble.';

  @override
  String get concubinageChecklist4Title => 'Assurance-vie croisée';

  @override
  String get concubinageChecklist4Desc =>
      'Une assurance-vie où chacun est bénéficiaire de l\'autre permet de compenser l\'absence de rente AVS/LPP de survivant. Compare les offres — les primes dépendent de l\'âge et du capital assuré.';

  @override
  String get concubinageChecklist5Title => 'Mandat pour cause d\'inaptitude';

  @override
  String get concubinageChecklist5Desc =>
      'Si tu deviens incapable de discernement (accident, maladie), ton/ta partenaire n\'a aucun pouvoir de représentation. Un mandat pour cause d\'inaptitude (CC art. 360 ss) lui donne ce droit.';

  @override
  String get concubinageChecklist6Title => 'Directives anticipées';

  @override
  String get concubinageChecklist6Desc =>
      'Un document qui précise tes volontés médicales en cas d\'incapacité. Tu peux y désigner ton/ta partenaire comme personne de confiance pour les décisions médicales (CC art. 370 ss).';

  @override
  String get concubinageChecklist7Title =>
      'Compte joint pour les dépenses communes';

  @override
  String get concubinageChecklist7Desc =>
      'Un compte commun simplifie la gestion des dépenses partagées (loyer, courses, factures). Définissez clairement la contribution de chacun. En cas de séparation, le solde est partagé à 50/50 sauf convention contraire.';

  @override
  String get concubinageChecklist8Title => 'Bail commun ou individuel';

  @override
  String get concubinageChecklist8Desc =>
      'Si tu es sur le bail avec ton/ta partenaire, vous êtes solidairement responsables. En cas de séparation, les deux doivent donner congé. Si un seul est titulaire, l\'autre n\'a aucun droit sur le logement.';

  @override
  String get concubinageDisclaimer =>
      'Informations simplifiées à but éducatif — ne constitue pas un conseil juridique ou fiscal. Les règles dépendent du canton, de la commune et de ta situation personnelle. Consulte un·e spécialiste juridique pour un avis personnalisé.';

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
  String get frontalierJoursSuffix => 'days';

  @override
  String get conversationHistoryTitle => 'History';

  @override
  String get conversationNew => 'New conversation';

  @override
  String get conversationEmptyTitle => 'No conversations';

  @override
  String get conversationEmptySubtitle =>
      'Start chatting with your coach to see history here';

  @override
  String get conversationStartFirst => 'Start a conversation';

  @override
  String get conversationErrorTitle => 'Loading error';

  @override
  String get conversationRetry => 'Retry';

  @override
  String get conversationDeleteTitle => 'Delete this conversation?';

  @override
  String get conversationDeleteConfirm => 'This action cannot be undone.';

  @override
  String get conversationDeleteCancel => 'Cancel';

  @override
  String get conversationDeleteAction => 'Delete';

  @override
  String get conversationDateNow => 'Just now';

  @override
  String get conversationDateYesterday => 'Yesterday';

  @override
  String conversationDateMinutesAgo(String minutes) {
    return '$minutes min ago';
  }

  @override
  String conversationDateHoursAgo(String hours) {
    return '${hours}h ago';
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
        '1': 'January',
        '2': 'February',
        '3': 'March',
        '4': 'April',
        '5': 'May',
        '6': 'June',
        '7': 'July',
        '8': 'August',
        '9': 'September',
        '10': 'October',
        '11': 'November',
        '12': 'December',
        'other': 'month',
      },
    );
    return '$_temp0';
  }

  @override
  String get achievementsTitle => 'My achievements';

  @override
  String get achievementsEmptyProfile =>
      'Complete your profile to unlock achievements.';

  @override
  String get achievementsDaysSingular => 'day';

  @override
  String get achievementsDaysPlural => 'days!';

  @override
  String achievementsRecord(int count) {
    return 'Record: $count days';
  }

  @override
  String achievementsTotalDays(int count) {
    return '$count total days';
  }

  @override
  String get achievementsEngageCta =>
      'Take an action today to keep your streak!';

  @override
  String get achievementsEngagedToday => 'Engagement recorded today';

  @override
  String get achievementsBadgesTitle => 'Badges';

  @override
  String get achievementsBadgesSubtitle => 'Your monthly check-in regularity';

  @override
  String achievementsBadgeMonths(int count) {
    return '$count months';
  }

  @override
  String get achievementsMilestonesTitle => 'Milestones';

  @override
  String get achievementsMilestonesSubtitle => 'Your financial milestones';

  @override
  String get achievementsDisclaimer =>
      'Your achievements are personal — MINT never compares them to others.';

  @override
  String get achievementsDayMon => 'M';

  @override
  String get achievementsDayTue => 'T';

  @override
  String get achievementsDayWed => 'W';

  @override
  String get achievementsDayThu => 'T';

  @override
  String get achievementsDayFri => 'F';

  @override
  String get achievementsDaySat => 'S';

  @override
  String get achievementsDaySun => 'S';

  @override
  String get achievementsBadgeFirstStepLabel => 'First step';

  @override
  String get achievementsBadgeFirstStepDesc =>
      'You completed your first check-in.';

  @override
  String get achievementsBadgeRegulierLabel => 'Regular';

  @override
  String get achievementsBadgeRegulierDesc =>
      '3 consecutive months of check-in.';

  @override
  String get achievementsBadgeConstantLabel => 'Consistent';

  @override
  String get achievementsBadgeConstantDesc => '6 months uninterrupted.';

  @override
  String get achievementsBadgeDisciplineLabel => 'Disciplined';

  @override
  String get achievementsBadgeDisciplineDesc =>
      '12 consecutive months — a full year.';

  @override
  String get achievementsCatPatrimoine => 'Wealth';

  @override
  String get achievementsCatPrevoyance => 'Pension';

  @override
  String get achievementsCatSecurite => 'Security';

  @override
  String get achievementsCatScoreFri => 'FRI Score';

  @override
  String get achievementsCatEngagement => 'Engagement';

  @override
  String get achievementsFriAbove50Label => 'FRI Score 50+';

  @override
  String get achievementsFriAbove50Desc => 'Reach a solidity score of 50/100';

  @override
  String get achievementsFriAbove70Label => 'FRI Score 70+';

  @override
  String get achievementsFriAbove70Desc => 'Reach a solidity score of 70/100';

  @override
  String get achievementsFriAbove85Label => 'FRI Score 85+';

  @override
  String get achievementsFriAbove85Desc => 'Excellence zone — 85/100';

  @override
  String get achievementsFriImproved10Label => 'Progress +10';

  @override
  String get achievementsFriImproved10Desc =>
      'Gain 10 FRI score points in a month';

  @override
  String get achievementsStreak6MonthsLabel => '6-month streak';

  @override
  String get achievementsStreak6MonthsDesc =>
      '6 consecutive months of check-in';

  @override
  String get achievementsStreak12MonthsLabel => '12-month streak';

  @override
  String get achievementsStreak12MonthsDesc =>
      '12 consecutive months — a full year';

  @override
  String get achievementsFirstArbitrageLabel => 'First comparison';

  @override
  String get achievementsFirstArbitrageDesc =>
      'Complete your first comparison simulation';

  @override
  String get nudgeSalaryTitle => 'Payday!';

  @override
  String get nudgeSalaryMessage =>
      'Have you thought about your 3a transfer this month? Every month counts for your retirement savings.';

  @override
  String get nudgeSalaryAction => 'See my 3a';

  @override
  String get nudgeTaxTitle => 'Tax filing';

  @override
  String get nudgeTaxMessage =>
      'Check the tax filing deadline in your canton. Have you reviewed your 3a and LPP deductions?';

  @override
  String get nudgeTaxAction => 'Simulate my taxes';

  @override
  String get nudge3aTitle => 'Final stretch for your 3a';

  @override
  String get nudge3aMessageLastDay =>
      'It\'s the last day to contribute to your 3a!';

  @override
  String nudge3aMessage(String days, String limit, String year) {
    return '$days day(s) left to contribute up to $limit CHF and reduce your $year taxes.';
  }

  @override
  String get nudge3aAction => 'Calculate my savings';

  @override
  String nudgeBirthdayTitle(String age) {
    return 'You\'re turning $age this year!';
  }

  @override
  String get nudgeBirthdayAction => 'See my dashboard';

  @override
  String get nudgeAnniversaryTitle => 'Already 1 year together!';

  @override
  String get nudgeAnniversaryMessage =>
      'You\'ve been using MINT for a year. It\'s the perfect time to update your profile and measure your progress.';

  @override
  String get nudgeAnniversaryAction => 'Update my profile';

  @override
  String get nudgeLppStartTitle => 'LPP contributions start';

  @override
  String get nudgeLppChangeTitle => 'LPP bracket change';

  @override
  String nudgeLppStartMessage(String rate) {
    return 'Your LPP old-age contributions start this year ($rate%). It\'s the beginning of your occupational pension.';
  }

  @override
  String nudgeLppChangeMessage(String age, String rate) {
    return 'At $age, your old-age credit increases to $rate%. This could be a good time to consider an LPP buyback.';
  }

  @override
  String get nudgeLppAction => 'Explore buyback';

  @override
  String get nudgeWeeklyTitle => 'It\'s been a while!';

  @override
  String get nudgeWeeklyMessage =>
      'Your financial situation evolves every week. Take 2 minutes to check your dashboard.';

  @override
  String get nudgeWeeklyAction => 'See my Pulse';

  @override
  String get nudgeStreakTitle => 'Your streak is at risk!';

  @override
  String nudgeStreakMessage(String count) {
    return 'You have a $count-day streak. One small action today is enough to keep it going.';
  }

  @override
  String get nudgeStreakAction => 'Continue my streak';

  @override
  String get nudgeGoalTitle => 'Your goal is approaching';

  @override
  String nudgeGoalMessage(String desc, String days) {
    return '\"$desc\" — $days day(s) left. Have you made progress on this?';
  }

  @override
  String get nudgeGoalAction => 'Talk to the coach';

  @override
  String get nudgeFhsTitle => 'Your health score dropped';

  @override
  String nudgeFhsMessage(String drop) {
    return 'Your Financial Health Score lost $drop points. Let\'s look at what might explain this change.';
  }

  @override
  String get nudgeFhsAction => 'Understand the drop';

  @override
  String get recapEngagement => 'Engagement';

  @override
  String get recapBudget => 'Budget';

  @override
  String get recapGoals => 'Goals';

  @override
  String get recapFhs => 'Financial score';

  @override
  String get recapOnTrack => 'Budget on track this week.';

  @override
  String get recapOverBudget =>
      'Budget exceeded this week — check your main expense categories.';

  @override
  String get recapUnderBudget => 'You spent less than expected — nice control!';

  @override
  String get recapNoData => 'Not enough budget data this week.';

  @override
  String recapDaysActive(String count) {
    return '$count active day(s) this week.';
  }

  @override
  String recapGoalsActive(String count) {
    return '$count active goal(s).';
  }

  @override
  String recapFhsUp(String delta) {
    return 'Score up by +$delta points.';
  }

  @override
  String recapFhsDown(String delta) {
    return 'Score down by $delta points.';
  }

  @override
  String get recapFhsStable => 'Score stable this week.';

  @override
  String get recapTitle => 'Your weekly recap';

  @override
  String recapPeriod(String start, String end) {
    return 'From $start to $end';
  }

  @override
  String get recapBudgetTitle => 'Budget';

  @override
  String get recapBudgetSaved => 'Saved this week';

  @override
  String get recapBudgetRate => 'Savings rate';

  @override
  String get recapActionsTitle => 'Completed actions';

  @override
  String get recapActionsNone => 'No actions this week';

  @override
  String get recapProgressTitle => 'Progress';

  @override
  String recapProgressDelta(String delta) {
    return '$delta confidence pts';
  }

  @override
  String get recapHighlightsTitle => 'Highlights';

  @override
  String get recapNextFocusTitle => 'Next week';

  @override
  String get recapEmpty => 'No data yet this week';

  @override
  String get decesProcheTitre => 'Death of a relative';

  @override
  String get decesProcheMoisRepudiation =>
      'months to accept or repudiate the succession (CC art. 567)';

  @override
  String get decesProche48hTitre => 'Urgent: first 48 hours';

  @override
  String get decesProche48hActe =>
      'Obtain the death certificate from the civil registry';

  @override
  String get decesProche48hBanque =>
      'Notify the bank — accounts are frozen upon notification';

  @override
  String get decesProche48hAssurance =>
      'Contact insurance companies (life, health, household)';

  @override
  String get decesProche48hEmployeur =>
      'Notify the deceased\'s employer about salary balance';

  @override
  String get decesProcheSituation => 'Your situation';

  @override
  String get decesProcheLienParente => 'Relationship to the deceased';

  @override
  String get decesProcheLienConjoint => 'Spouse';

  @override
  String get decesProcheLienParent => 'Parent';

  @override
  String get decesProcheLienEnfant => 'Child';

  @override
  String get decesProcheFortune => 'Estimated estate of the deceased';

  @override
  String get decesProcheCanton => 'Canton';

  @override
  String get decesProchTestament => 'A will exists';

  @override
  String get decesProchTimelineTitre => 'Succession timeline';

  @override
  String get decesProchTimeline1Titre => 'Death certificate & freeze';

  @override
  String get decesProchTimeline1Desc =>
      'The civil registry issues the certificate. Bank accounts are frozen.';

  @override
  String get decesProchTimeline2Titre => 'Inventory & notary';

  @override
  String get decesProchTimeline2Desc =>
      'The notary opens the succession and establishes the asset inventory.';

  @override
  String get decesProchTimeline3Titre => 'Repudiation period';

  @override
  String get decesProchTimeline3Desc =>
      '3 months to accept or repudiate (CC art. 567). After this period, the succession is accepted.';

  @override
  String get decesProchTimeline4Titre => 'Division & taxes';

  @override
  String get decesProchTimeline4Desc =>
      'Succession declaration and payment of cantonal tax (if applicable).';

  @override
  String get decesProchebeneficiairesTitre => 'LPP & 3a beneficiaries';

  @override
  String get decesProchebeneficiairesLpp => 'Deceased\'s LPP capital';

  @override
  String get decesProchebeneficiaires3a => 'Deceased\'s 3a capital';

  @override
  String get decesProchebeneficiairesNote =>
      'The LPP beneficiary order is set by the pension fund rules (OPP2 art. 48). The 3a follows OPP3 art. 2.';

  @override
  String get decesProchImpactFiscalTitre => 'Tax impact';

  @override
  String decesProchImpactFiscalExempt(String canton) {
    return 'In $canton, the surviving spouse is exempt from inheritance tax.';
  }

  @override
  String decesProchImpactFiscalTaxe(String canton) {
    return 'In $canton, heirs are subject to cantonal inheritance tax. The rate varies by degree of kinship.';
  }

  @override
  String get decesProchActionsTitre => 'Next steps';

  @override
  String get decesProchAction1 =>
      'Gather documents: death certificate, will, LPP and 3a certificates';

  @override
  String get decesProchAction2 =>
      'Consult a notary for the succession inventory';

  @override
  String get decesProchAction3 =>
      'Check LPP and 3a beneficiaries with the pension funds';

  @override
  String get decesProchDisclaimer =>
      'Educational tool — does not constitute legal or tax advice (FinSA). Each succession is unique: consult a notary or specialist. Sources: CC art. 457-640, OPP2 art. 48, OPP3 art. 2.';

  @override
  String get demenagementTitre => 'Cantonal move';

  @override
  String get demenagementChiffreChocSousTitre =>
      'estimated annual savings (or additional cost)';

  @override
  String demenagementChiffreChocDetail(String depart, String arrivee) {
    return 'Moving from $depart to $arrivee (taxes + health insurance)';
  }

  @override
  String get demenagementSituation => 'Your situation';

  @override
  String get demenagementCantonDepart => 'Current canton';

  @override
  String get demenagementCantonArrivee => 'Destination canton';

  @override
  String get demenagementRevenu => 'Gross annual income';

  @override
  String get demenagementCelibataire => 'Single';

  @override
  String get demenagementMarie => 'Married';

  @override
  String get demenagementFiscalTitre => 'Tax comparison';

  @override
  String get demenagementEconomieFiscale => 'Estimated tax savings';

  @override
  String get demenagementLamalTitre => 'Health insurance premiums';

  @override
  String get demenagementChecklistTitre => 'Moving checklist';

  @override
  String get demenagementChecklist1 =>
      'Notify departure to the current municipality (8 days before)';

  @override
  String get demenagementChecklist2 =>
      'Register at the new municipality (within 8 days)';

  @override
  String get demenagementChecklist3 =>
      'Change health insurer or update premium region';

  @override
  String get demenagementChecklist4 =>
      'Update tax declaration (taxation as of Dec 31)';

  @override
  String get demenagementChecklist5 => 'Check cantonal family allowances';

  @override
  String get demenagementDisclaimer =>
      'Educational tool — does not constitute tax advice (FinSA). Figures are estimates based on simplified cantonal indices. Consult a specialist for your situation. Sources: FITL, HIA, cantonal scales 2025.';

  @override
  String get docScanAppBarTitle => 'SCAN A DOCUMENT';

  @override
  String get docScanHeaderTitle => 'Improve your profile accuracy';

  @override
  String get docScanHeaderSubtitle =>
      'Take a photo of a financial document and we\'ll extract the figures for you. You\'ll verify each value before confirming.';

  @override
  String get docScanDocumentType => 'Document type';

  @override
  String docScanConfidencePoints(int points) {
    return '+$points confidence points';
  }

  @override
  String get docScanFromGallery => 'From gallery';

  @override
  String get docScanPasteOcrText => 'Paste OCR text';

  @override
  String get docScanUseExample => 'Use a test example';

  @override
  String get docScanPrivacyNote =>
      'The image is analyzed locally (on-device OCR). If you use Vision AI analysis, the image is sent to your AI provider via your own API key. Only confirmed values are saved to your profile.';

  @override
  String get docScanCameraError =>
      'Unable to open the camera. Use the gallery.';

  @override
  String get docScanEmptyTextFile => 'The text file is empty.';

  @override
  String get docScanFileUnreadableTitle => 'File not usable';

  @override
  String get docScanFileUnreadableMessage =>
      'We couldn\'t read this file directly from your device. Take a photo of the document or paste OCR text.';

  @override
  String docScanImportError(String error) {
    return 'Unable to import the file: $error';
  }

  @override
  String get docScanOcrNotDetectedTitle => 'Text not detected';

  @override
  String get docScanOcrNotDetectedMessage =>
      'We couldn\'t read enough text from the photo.';

  @override
  String get docScanPhotoAnalysisTitle => 'Photo analysis unavailable';

  @override
  String get docScanPhotoAnalysisMessage =>
      'We couldn\'t extract text automatically. Try again with a clearer photo or paste OCR text.';

  @override
  String get docScanNoFieldRecognized => 'No field recognized automatically';

  @override
  String get docScanNoFieldHint =>
      'Add or correct the OCR text to improve the analysis, then retry.';

  @override
  String docScanParsingError(String error) {
    return 'Parsing failed for this document: $error';
  }

  @override
  String get docScanOcrPasteHint => 'Paste raw OCR text here…';

  @override
  String get docScanPdfDetected => 'PDF detected';

  @override
  String get docScanPdfCannotRead =>
      'Unable to read this PDF directly on this device. Take a photo of the document or paste OCR text.';

  @override
  String get docScanPdfAnalysisUnavailable => 'PDF analysis unavailable';

  @override
  String get docScanPdfNotParsed =>
      'The PDF could not be parsed automatically. You can take a photo (recommended) or paste OCR text.';

  @override
  String get docScanPdfNotAvailable =>
      'PDF parsing is not available in this context. Take a photo or paste OCR text.';

  @override
  String get docScanPdfOptimizedLpp =>
      'For now, automatic PDF parsing is mainly optimized for LPP certificates. Take a photo of the document.';

  @override
  String get docScanPdfTypeUnsupported =>
      'Document type not supported for PDF parsing.';

  @override
  String get docScanPdfNoData => 'No useful data was extracted from this PDF.';

  @override
  String docScanPdfBackendError(String error) {
    return 'Backend error during PDF parsing: $error';
  }

  @override
  String get docScanBackendDisclaimer =>
      'Data extracted automatically: verify each value before confirming.';

  @override
  String get docScanBackendDisclaimerShort =>
      'Verify amounts before confirming. Educational tool (FinSA).';

  @override
  String get docScanVisionAnalyze => 'Analyze via Vision AI';

  @override
  String get docScanVisionDisclaimer =>
      'The image will be sent to your AI provider via your API key.';

  @override
  String get docScanVisionNoFields =>
      'AI could not extract any fields from this document.';

  @override
  String get docScanVisionDefaultDisclaimer =>
      'Data extracted by AI: verify each value. Educational tool, not financial advice (FinSA).';

  @override
  String get docScanVisionConfigError =>
      'Configure an API key in Coach settings.';

  @override
  String docScanVisionError(String error) {
    return 'Vision AI error: $error';
  }

  @override
  String get docScanLabelLppTotal => 'Total LPP assets';

  @override
  String get docScanLabelObligatoire => 'Mandatory part';

  @override
  String get docScanLabelSurobligatoire => 'Supra-mandatory part';

  @override
  String get docScanLabelTauxConvOblig => 'Mandatory conversion rate';

  @override
  String get docScanLabelTauxConvSuroblig => 'Supra-mandatory conversion rate';

  @override
  String get docScanLabelRachatMax => 'Maximum buyback';

  @override
  String get docScanLabelSalaireAssure => 'Insured salary';

  @override
  String get docScanLabelTauxRemuneration => 'Remuneration rate';

  @override
  String get docImpactTitle => 'Your profile is more accurate';

  @override
  String docImpactSubtitle(String docType) {
    return 'Values from your $docType have been integrated into your projections.';
  }

  @override
  String get docImpactConfidenceLabel => '% confidence';

  @override
  String docImpactDeltaPoints(int points) {
    return '+$points confidence points';
  }

  @override
  String get docImpactChiffreChocTitle => 'Recalculated key figure';

  @override
  String docImpactLppRealAmount(String oblig) {
    return 'in real LPP assets (of which $oblig mandatory)';
  }

  @override
  String docImpactRenteOblig(String amount) {
    return 'Mandatory annuity at 6.8%: CHF $amount/year';
  }

  @override
  String docImpactSurobligWithRate(String suroblig, String rate, String rente) {
    return 'Supra-mandatory part (CHF $suroblig) at $rate% = CHF $rente/year';
  }

  @override
  String docImpactSurobligNoRate(String suroblig) {
    return 'Supra-mandatory part (CHF $suroblig) = pension fund\'s free conversion rate';
  }

  @override
  String docImpactAvsYears(int years) {
    return '$years years of contributions';
  }

  @override
  String docImpactAvsCompletion(int maxYears, int pct) {
    return 'out of $maxYears needed for a full AVS pension ($pct%)';
  }

  @override
  String get docImpactGenericMessage =>
      'Your projections are now based on real values.';

  @override
  String get docImpactFieldsUpdated => 'Fields updated';

  @override
  String get docImpactReturnDashboard => 'Return to dashboard';

  @override
  String get docImpactDisclaimer =>
      'Educational tool — not pension advice. Always verify with your original certificate (FinSA).';

  @override
  String get extractionReviewAppBar => 'VERIFICATION';

  @override
  String get extractionReviewTitle => 'Verify the extracted values';

  @override
  String extractionReviewSubtitle(int count, String reviewPart) {
    return '$count fields detected$reviewPart. You can modify each value before confirming.';
  }

  @override
  String extractionReviewNeedsReview(int count) {
    return ' including $count to verify';
  }

  @override
  String extractionReviewConfidence(int pct) {
    return 'Extraction confidence: $pct%';
  }

  @override
  String extractionReviewSourcePrefix(String text) {
    return 'Read: \"$text\"';
  }

  @override
  String get extractionReviewConfirmAll => 'Confirm all';

  @override
  String extractionReviewEditTitle(String label) {
    return 'Edit: $label';
  }

  @override
  String extractionReviewCurrentValue(String value) {
    return 'Current value: $value';
  }

  @override
  String get extractionReviewNewValue => 'New value';

  @override
  String get extractionReviewCancel => 'Cancel';

  @override
  String get extractionReviewValidate => 'Validate';

  @override
  String get extractionReviewEditTooltip => 'Edit';

  @override
  String get firstSalaryFilmTitle => 'Your first salary story';

  @override
  String firstSalaryFilmSubtitle(String amount) {
    return 'CHF $amount gross — 5 acts to understand everything.';
  }

  @override
  String get firstSalaryAct1Label => '1 · Gross→Net';

  @override
  String get firstSalaryAct2Label => '2 · Invisible';

  @override
  String get firstSalaryAct3Label => '3 · 3a';

  @override
  String get firstSalaryAct4Label => '4 · Health';

  @override
  String get firstSalaryAct5Label => '5 · Action';

  @override
  String get firstSalaryAct1Title => 'The cold shower';

  @override
  String firstSalaryAct1Quote(String amount) {
    return '$amount CHF disappear. But it\'s not lost — it\'s your future.';
  }

  @override
  String firstSalaryGross(String amount) {
    return 'Gross: CHF $amount';
  }

  @override
  String firstSalaryNet(String amount) {
    return 'Net: CHF $amount';
  }

  @override
  String firstSalaryNetPercent(int pct) {
    return '$pct% net';
  }

  @override
  String get firstSalaryAct2Title => 'The invisible money';

  @override
  String firstSalaryAct2Quote(String amount) {
    return 'Your real salary is CHF $amount. Your employer pays much more than you think.';
  }

  @override
  String get firstSalaryVisibleNet => '🌊 Visible: your net salary';

  @override
  String get firstSalaryVisibleNetSub => 'What you receive';

  @override
  String get firstSalaryCotisations => '💧 Your contributions';

  @override
  String get firstSalaryCotisationsSub => 'Deducted from your gross';

  @override
  String get firstSalaryEmployerCotisations => '🏔️ Employer contributions';

  @override
  String get firstSalaryEmployerCotisationsSub => 'Invisible on your payslip';

  @override
  String get firstSalaryTotalEmployerCost => 'Total employer cost';

  @override
  String get firstSalaryAct3Title => 'The 3a tax gift';

  @override
  String firstSalaryAct3Quote(String amount) {
    return 'CHF $amount/month → potentially a millionaire. Start now.';
  }

  @override
  String get firstSalaryAt30 => 'At 30';

  @override
  String get firstSalaryAt40 => 'At 40';

  @override
  String get firstSalaryAt65 => 'At 65';

  @override
  String get firstSalary3aInfo =>
      '💰 2026 ceiling: CHF 7\'258/year · Direct tax deduction · OPP3 art. 7';

  @override
  String get firstSalaryAct4Title => 'The health insurance trap';

  @override
  String get firstSalaryAct4Quote =>
      'The cheap franchise can cost you dearly if you get sick.';

  @override
  String get firstSalaryFranchise300Advice =>
      'Recommended if chronic conditions';

  @override
  String get firstSalaryFranchise1500Advice => 'Good compromise · Recommended';

  @override
  String get firstSalaryFranchise2500Advice =>
      'Save on premium · If you\'re healthy';

  @override
  String firstSalaryFranchiseLabel(String label) {
    return 'Franchise $label';
  }

  @override
  String firstSalaryFranchisePrime(String amount) {
    return '−CHF $amount/month premium';
  }

  @override
  String get firstSalaryLamalInfo =>
      '💡 HIA art. 64 — Annual franchise chosen, renewable each year.';

  @override
  String get firstSalaryAct5Title => 'Your startup checklist';

  @override
  String get firstSalaryAct5Quote => '5 actions. That\'s it. Start this week.';

  @override
  String get firstSalaryWeek1 => 'Week 1';

  @override
  String get firstSalaryWeek2 => 'Week 2';

  @override
  String get firstSalaryBefore31Dec => 'Before Dec 31';

  @override
  String get firstSalaryTask1 => 'Open a 3a account (bank or fintech)';

  @override
  String get firstSalaryTask2 => 'Set up an automatic monthly transfer';

  @override
  String get firstSalaryTask3 =>
      'Choose your health insurance franchise (recommended: CHF 1\'500)';

  @override
  String get firstSalaryTask4 =>
      'Check your private liability insurance (approx. CHF 100/year)';

  @override
  String get firstSalaryTask5 => 'Pay the maximum 3a before December 31';

  @override
  String get firstSalaryBadgeTitle => 'First financial step';

  @override
  String get firstSalaryBadgeSubtitle =>
      'You now know what 90% of people never know.';

  @override
  String get firstSalaryDisclaimer =>
      'Educational tool · not financial advice under FinSA. Source: OASI art. 3, LPP art. 7, UIA art. 3, OPP3 art. 7 (3a CHF 7\'258/year). Indicative 2026 contribution rates. 3a projection: hypothetical 4%/year return.';

  @override
  String get benchmarkAppBarTitle => 'Cantonal benchmarks';

  @override
  String get benchmarkOptInTitle => 'Enable cantonal comparisons';

  @override
  String get benchmarkOptInSubtitle =>
      'Compare your situation to rough figures from federal statistics (FSO).';

  @override
  String get benchmarkExplanationTitle => 'Benchmarks, not rankings';

  @override
  String get benchmarkExplanationBody =>
      'Enable this feature to see how your financial situation compares to similar profiles in your canton. These are rough figures from anonymized federal statistics (FSO). No ranking, no social comparison.';

  @override
  String get benchmarkNoProfile =>
      'Complete your profile to access cantonal benchmarks.';

  @override
  String benchmarkNoData(String canton, String ageGroup) {
    return 'No data available for canton $canton (age group $ageGroup).';
  }

  @override
  String benchmarkSimilarProfiles(String canton, String ageGroup) {
    return 'Similar profiles: $canton, age group $ageGroup';
  }

  @override
  String benchmarkSourceLabel(String source) {
    return 'Source: $source';
  }

  @override
  String get benchmarkWithinRange =>
      'Your situation is within the typical range.';

  @override
  String get benchmarkAboveRange =>
      'Your situation is above the typical range.';

  @override
  String get benchmarkBelowRange =>
      'Your situation is below the typical range.';

  @override
  String benchmarkTypicalRange(String low, String high) {
    return 'Typical range: $low – $high';
  }

  @override
  String get tabPulse => 'Pulse';

  @override
  String get tabMint => 'Mint';

  @override
  String get authGateDocScanTitle => 'Secure your documents';

  @override
  String get authGateDocScanMessage =>
      'Your certificates contain sensitive data. Create an account to protect them with end-to-end encryption.';

  @override
  String get authGateSalaryTitle => 'Protect your financial data';

  @override
  String get authGateSalaryMessage =>
      'Your salary and financial data deserve a secure vault.';

  @override
  String get authGateCoachTitle => 'The coach needs to know you';

  @override
  String get authGateCoachMessage =>
      'To give you personalised answers, the coach needs an account.';

  @override
  String get authGateGoalTitle => 'Track your progress';

  @override
  String get authGateGoalMessage =>
      'To track your goals over time, create your account.';

  @override
  String get authGateSimTitle => 'Save your simulation';

  @override
  String get authGateSimMessage =>
      'To find this simulation later, create your account.';

  @override
  String get authGateByokTitle => 'Protect your API key';

  @override
  String get authGateByokMessage =>
      'Your API key will be encrypted in your secure space.';

  @override
  String get authGateCoupleTitle => 'Couple mode requires an account';

  @override
  String get authGateCoupleMessage =>
      'To invite your partner, first create your personal account.';

  @override
  String get authGateProfileTitle => 'Enrich your profile securely';

  @override
  String get authGateProfileMessage =>
      'The more you enrich your profile, the more accurate your projections. Secure your data.';

  @override
  String get authGateCreateAccount => 'Create my account';

  @override
  String get authGateLogin => 'I already have an account';

  @override
  String get authGatePrivacyNote =>
      'Your data stays on your device and is encrypted.';

  @override
  String get budgetTaxProvisionNotProvided => 'Tax provision (not provided)';

  @override
  String get budgetHealthInsuranceNotProvided =>
      'Health insurance (LAMal) (not provided)';

  @override
  String get budgetOtherFixedCosts => 'Other fixed costs';

  @override
  String get budgetOtherFixedCostsNotProvided =>
      'Other fixed costs (not provided)';

  @override
  String get budgetQualityProvided => 'provided';

  @override
  String get budgetBannerMissing =>
      'Some expenses are still missing. Complete your assessment for a more reliable budget.';

  @override
  String get budgetBannerEstimated =>
      'This budget includes estimates (taxes/LAMal). Enter your actual amounts for a more reliable projection.';

  @override
  String get budgetCompleteMyData => 'Complete my data →';

  @override
  String get budgetEmergencyFundTitle => 'Emergency fund';

  @override
  String get budgetGoalReached => 'Goal reached';

  @override
  String get budgetOnTrack => 'On track';

  @override
  String get budgetToReinforce => 'To reinforce';

  @override
  String budgetMonthsCovered(String months) {
    return '$months months covered';
  }

  @override
  String budgetTargetMonths(String target) {
    return 'Target: $target months';
  }

  @override
  String get budgetEmergencyProtected =>
      'You are protected against unexpected events. Keep it up.';

  @override
  String budgetEmergencySaveMore(String target) {
    return 'Save at least $target months of expenses to protect yourself against unexpected events (job loss, repair...).';
  }

  @override
  String get budgetExploreAlso => 'Explore also';

  @override
  String get budgetDebtRatio => 'Debt ratio';

  @override
  String get budgetDebtRatioSubtitle => 'Assess your debt situation';

  @override
  String get budgetRepaymentPlan => 'Repayment plan';

  @override
  String get budgetRepaymentPlanSubtitle => 'Strategy to get out of debt';

  @override
  String get budgetHelpResources => 'Help resources';

  @override
  String get budgetHelpResourcesSubtitle => 'Where to find help in Switzerland';

  @override
  String get budgetCtaEvaluate => 'Evaluate';

  @override
  String get budgetCtaPlan => 'Plan';

  @override
  String get budgetCtaDiscover => 'Discover';

  @override
  String get budgetDisclaimerImportant => 'IMPORTANT:';

  @override
  String get budgetDisclaimerBased =>
      '• Amounts are based on declared information.';

  @override
  String get refreshReturnToDashboard => 'Return to dashboard';

  @override
  String get refreshOptionNone => 'None';

  @override
  String get refreshOptionPurchase => 'Purchase';

  @override
  String get refreshOptionSale => 'Sale';

  @override
  String get refreshOptionRefinancing => 'Refinancing';

  @override
  String get refreshOptionMarriage => 'Marriage';

  @override
  String get refreshOptionBirth => 'Birth';

  @override
  String get refreshOptionDivorce => 'Divorce';

  @override
  String get refreshOptionDeath => 'Death';

  @override
  String get refreshProfileUpdated => 'Profile updated!';

  @override
  String refreshScoreUp(String delta) {
    return 'Your score went up by $delta points!';
  }

  @override
  String refreshScoreDown(String delta) {
    return 'Your score went down by $delta points — let\'s check together';
  }

  @override
  String get refreshScoreStable => 'Your score is stable — keep it up!';

  @override
  String get refreshBefore => 'Before';

  @override
  String get refreshAfter => 'After';

  @override
  String get chiffreChocDisclaimer =>
      'Educational tool — not financial advice (FinSA). Sources: OASI art. 34, LPP art. 14-16, OPP3 art. 7.';

  @override
  String get chiffreChocAction => 'What can I do?';

  @override
  String get chiffreChocEnrich => 'Refine my profile';

  @override
  String chiffreChocConfidence(String count) {
    return 'Estimate based on $count data points. The more you provide, the more reliable.';
  }

  @override
  String get chatErrorInvalidKey =>
      'Your API key seems invalid or expired. Check it in settings.';

  @override
  String get chatErrorRateLimit =>
      'Rate limit reached. Try again in a few moments.';

  @override
  String get chatErrorTechnical => 'Technical error. Try again later.';

  @override
  String get chatErrorConnection =>
      'Connection error. Check your internet connection or API key.';

  @override
  String get chatCoachMint => 'MINT Coach';

  @override
  String get chatEmptyStateMessage =>
      'Complete your assessment to chat with your coach';

  @override
  String get chatStartButton => 'Start';

  @override
  String get chatDisclaimer =>
      'Educational tool — answers are not financial advice. FinSA.';

  @override
  String get chatTooltipHistory => 'History';

  @override
  String get chatTooltipExport => 'Export conversation';

  @override
  String get chatTooltipSettings => 'AI Settings';

  @override
  String get slmChooseModel => 'Choose your model';

  @override
  String get slmTwoSizesAvailable =>
      'Two sizes available depending on your device';

  @override
  String get slmRecommended => 'Recommended';

  @override
  String get slmDownloadFailedMessage =>
      'Download failed. Check your WiFi connection and available space on your device.';

  @override
  String get slmInitError =>
      'Model initialization error. Check that your device is compatible.';

  @override
  String get slmInitializing => 'Initializing...';

  @override
  String get slmInitEngine => 'Initialize engine';

  @override
  String get disabilityYourSituation => 'Your situation';

  @override
  String get disabilityGrossMonthly => 'Gross monthly salary';

  @override
  String get disabilityYourAge => 'Your age';

  @override
  String get disabilityAvailableSavings => 'Available savings';

  @override
  String get disabilityHasIjm => 'I have IJM insurance through my employer';

  @override
  String get disabilityExploreAlso => 'Explore also';

  @override
  String get disabilityCoverageInsurance => 'Insurance coverage';

  @override
  String get disabilityCoverageSubtitle => 'IJM, DI, LPP — your report card';

  @override
  String get disabilitySelfEmployed => 'Self-employed';

  @override
  String get disabilitySelfEmployedSubtitle => 'Specific risks without LPP';

  @override
  String get disabilityCtaEvaluate => 'Evaluate';

  @override
  String get disabilityCtaAnalyze => 'Analyze';

  @override
  String get disabilityAppBarTitle => 'If I can no longer work';

  @override
  String get disabilityStatLine1 => '1 in 5 people';

  @override
  String get disabilityStatLine2 => 'will be affected before age 65';

  @override
  String get authRegisterSubtitle =>
      'Optional account: your data stays local by default';

  @override
  String get authWhyCreateAccount => 'Why create an account?';

  @override
  String get authBenefitProjections =>
      'AVS/LPP projections aligned to your situation';

  @override
  String get authBenefitCoach => 'Personalised coach with your first name';

  @override
  String get authBenefitSync => 'Cloud backup + multi-device sync';

  @override
  String get authFirstName => 'First name';

  @override
  String get authFirstNameRequired =>
      'First name is needed to personalise your coach';

  @override
  String get authBirthYear => 'Year of birth';

  @override
  String get authBirthYearRequired => 'Required for AVS/LPP projections';

  @override
  String get authPasswordRequirements =>
      'Use at least 8 characters to secure your account';

  @override
  String get authCguAccept => 'I have read and accept the ';

  @override
  String get authCguLink => 'Terms & Conditions';

  @override
  String get authCguAndPrivacy => ' and the ';

  @override
  String get authPrivacyLink => 'Privacy Policy';

  @override
  String get authConfirm18 =>
      'I confirm I am at least 18 years old (T&C art. 4.1)';

  @override
  String get authConsentSection => 'Optional consents';

  @override
  String get authConsentNotifications =>
      'Coaching notifications (3a reminders, tax deadlines)';

  @override
  String get authConsentAnalytics =>
      'Anonymous data to improve Swiss benchmarks';

  @override
  String get authPasswordWeak => 'Weak';

  @override
  String get authPasswordMedium => 'Fair';

  @override
  String get authPasswordStrong => 'Strong';

  @override
  String get authPasswordVeryStrong => 'Very strong';

  @override
  String get authOrContinueWith => 'or continue with';

  @override
  String get authPrivacyReassurance =>
      'Your data stays encrypted on your device. No bank connection.';

  @override
  String get authContinueLocal => 'Continue in local mode';

  @override
  String get authBack => 'Back';

  @override
  String coachGreetingSlm(String name) {
    return 'Hi $name. Everything stays on your device — nothing leaves. What’s on your mind ?';
  }

  @override
  String coachGreetingDefault(String name, String scoreSuffix) {
    return 'Hi $name. I’m looking at your numbers — tell me what’s on your mind.$scoreSuffix';
  }

  @override
  String coachScoreSuffix(int score) {
    return ' Your score: $score/100 — let’s see where it sticks.';
  }

  @override
  String get coachComplianceError =>
      'I couldn\'t formulate a compliant answer. Rephrase your question or explore the simulators.';

  @override
  String get coachErrorInvalidKey =>
      'Your API key seems invalid or expired. Check it in settings.';

  @override
  String get coachErrorRateLimit =>
      'Rate limit reached. Try again in a moment.';

  @override
  String get coachErrorGeneric => 'Technical error. Try again later.';

  @override
  String get coachErrorConnection =>
      'Connection error. Check your internet connection or API key.';

  @override
  String get coachSuggestSimulate3a => 'How much can I save with pillar 3a?';

  @override
  String get coachSuggestView3a => 'Status of my 3a accounts';

  @override
  String get coachSuggestSimulateLpp => 'Calculate an LPP buyback';

  @override
  String get coachSuggestUnderstandLpp => 'How does LPP buyback work?';

  @override
  String get coachSuggestTrajectory => 'My trajectory to retirement';

  @override
  String get coachSuggestScenarios => 'Pension or lump sum: which suits me?';

  @override
  String get coachSuggestDeductions => 'Where to cut my taxes this year?';

  @override
  String get coachSuggestTaxImpact => 'Calculate the tax saving';

  @override
  String get coachSuggestFitness => 'My financial score in detail';

  @override
  String get coachSuggestRetirement => 'At 65, how much will I have?';

  @override
  String get coachEmptyStateMessage =>
      'No profile yet. Three questions, and we\'re talking.';

  @override
  String get coachEmptyStateButton => 'Take my diagnosis';

  @override
  String get coachTooltipHistory => 'History';

  @override
  String get coachTooltipExport => 'Export conversation';

  @override
  String get coachTooltipSettings => 'AI Settings';

  @override
  String get coachTooltipLifeEvent => 'Life event';

  @override
  String get coachTierSlm => 'On-device AI';

  @override
  String get coachTierByok => 'Cloud AI (BYOK)';

  @override
  String get coachTierFallback => 'Offline mode';

  @override
  String get coachBadgeSlm => 'On-device';

  @override
  String get coachBadgeByok => 'Cloud';

  @override
  String get coachBadgeFallback => 'Offline';

  @override
  String get coachDisclaimer =>
      'Educational tool — answers do not constitute financial advice (FinSA art. 3). Consult a specialist for important decisions.';

  @override
  String get coachLoading => 'Looking at your numbers…';

  @override
  String get coachSources => 'Sources';

  @override
  String get coachInputHint => 'A question about your finances?';

  @override
  String get coachTitle => 'MINT Coach';

  @override
  String get coachFallbackName => 'friend';

  @override
  String get coachUserMessage => 'Your message';

  @override
  String get coachCoachMessage => 'Coach response';

  @override
  String get coachSendButton => 'Send';

  @override
  String get profileDefaultName => 'User';

  @override
  String profileNameAge(String name, int age) {
    return '$name, $age years';
  }

  @override
  String get commonEdit => 'Edit';

  @override
  String get profileSlmTitle => 'On-device AI (SLM)';

  @override
  String get profileSlmReady => 'Model ready';

  @override
  String get profileSlmNotInstalled => 'Model not installed';

  @override
  String get profileDeleteAccountSuccess => 'Account successfully deleted.';

  @override
  String get profileDeleteAccountError =>
      'Deletion not possible at the moment. Try again later.';

  @override
  String get profileChangeLanguage => 'Change language';

  @override
  String profileDocCount(int count) {
    return '$count document(s)';
  }

  @override
  String get tabToday => 'Today';

  @override
  String get tabDossier => 'File';

  @override
  String get affordabilityInsightRevenueTitle =>
      'What\'s limiting you: your income, not your equity';

  @override
  String affordabilityInsightRevenueBody(
      String chargesTheoriques, String chargesReelles) {
    return 'Swiss banks use a theoretical 5% interest rate (ASB directive), even though the actual market rate is much lower. It\'s a stress test: they check you could handle the charges if rates rose. Your theoretical charges: $chargesTheoriques/mo. At market rate (~1.5%): $chargesReelles/mo.';
  }

  @override
  String get affordabilityInsightEquityTitle =>
      'What\'s limiting you: your equity';

  @override
  String affordabilityInsightEquityBody(String manque) {
    return 'You\'re missing approximately CHF $manque in equity to reach the 20% minimum required by banks.';
  }

  @override
  String get affordabilityInsightOkTitle => 'Good news: both criteria are met';

  @override
  String get affordabilityInsightOkBody =>
      'Your income and equity allow you to afford this property. Consider comparing mortgage types and amortization strategies.';

  @override
  String affordabilityInsightLppCap(String lppUtilise, String lppTotal) {
    return 'Your 2nd pillar is capped: only CHF $lppUtilise out of $lppTotal count (max 10% of price, ASB rule).';
  }

  @override
  String get tabCoach => 'Coach';

  @override
  String get pulseNarrativeRetirementClose =>
      'your retirement is near. Here\'s where you stand.';

  @override
  String pulseNarrativeYearsToAct(int yearsToRetire) {
    return 'you have $yearsToRetire years to act. Every year counts.';
  }

  @override
  String get pulseNarrativeTimeToBuild =>
      'you have time to build. Here\'s your situation.';

  @override
  String get pulseNarrativeDefault => 'here\'s your financial situation.';

  @override
  String get pulseLabelReplacementRate => 'Replacement rate at retirement';

  @override
  String get pulseLabelRetirementIncome => 'Estimated retirement income';

  @override
  String get pulseLabelFinancialScore => 'Financial readiness score';

  @override
  String get exploreHubRetraiteTitle => 'Retirement';

  @override
  String get exploreHubRetraiteSubtitle => 'OASI, LPP, 3a, projections';

  @override
  String get exploreHubFamilleTitle => 'Family';

  @override
  String get exploreHubFamilleSubtitle => 'Marriage, birth, cohabitation';

  @override
  String get exploreHubTravailTitle => 'Work & Status';

  @override
  String get exploreHubTravailSubtitle =>
      'Employment, self-employed, cross-border';

  @override
  String get exploreHubLogementTitle => 'Housing';

  @override
  String get exploreHubLogementSubtitle => 'Mortgage, purchase, sale';

  @override
  String get exploreHubFiscaliteTitle => 'Taxation';

  @override
  String get exploreHubFiscaliteSubtitle => 'Taxes, cantonal comparison';

  @override
  String get exploreHubPatrimoineTitle => 'Wealth & Inheritance';

  @override
  String get exploreHubPatrimoineSubtitle =>
      'Donation, inheritance, allocation';

  @override
  String get exploreHubSanteTitle => 'Health & Protection';

  @override
  String get exploreHubSanteSubtitle =>
      'Health insurance, disability, coverage';

  @override
  String get dossierDocumentsTitle => 'Documents';

  @override
  String get dossierDocumentsSubtitle => 'Certificates, statements, scans';

  @override
  String get dossierCoupleTitle => 'Couple';

  @override
  String get dossierCoupleSubtitle => 'Household, partner, duo projections';

  @override
  String get dossierBilanTitle => 'Financial overview';

  @override
  String get dossierBilanSubtitle => 'Overview of your assets';

  @override
  String get dossierReglages => 'Settings';

  @override
  String get dossierConsentsTitle => 'Consents';

  @override
  String get dossierConsentsSubtitle => 'Privacy and data sharing';

  @override
  String get dossierAiTitle => 'AI & Coach';

  @override
  String get dossierAiSubtitle => 'Local model, API key';

  @override
  String get dossierStartProfile => 'Start your profile';

  @override
  String dossierProfileCompleted(int percent) {
    return '$percent% completed';
  }

  @override
  String get exploreHubFeatured => 'Featured journeys';

  @override
  String get exploreHubSeeAll => 'See all';

  @override
  String get exploreHubLearnMore => 'Learn about this topic';

  @override
  String get retraiteHubFeaturedOverview => 'Retirement overview';

  @override
  String get retraiteHubFeaturedOverviewSub =>
      'Your personalized estimate in 3 minutes';

  @override
  String get retraiteHubFeaturedRenteCapital => 'Annuity vs Lump sum';

  @override
  String get retraiteHubFeaturedRenteCapitalSub =>
      'Compare both options side by side';

  @override
  String get retraiteHubFeaturedRachat => 'LPP buyback';

  @override
  String get retraiteHubFeaturedRachatSub =>
      'Simulate the tax impact of a buyback';

  @override
  String get retraiteHubToolPilier3a => 'Pillar 3a';

  @override
  String get retraiteHubTool3aComparateur => '3a Comparator';

  @override
  String get retraiteHubTool3aRendement => '3a Real return';

  @override
  String get retraiteHubTool3aRetrait => '3a Staggered withdrawal';

  @override
  String get retraiteHubTool3aRetroactif => '3a Retroactive';

  @override
  String get retraiteHubToolLibrePassage => 'Vested benefits';

  @override
  String get retraiteHubToolDecaissement => 'Withdrawal';

  @override
  String get retraiteHubToolEpl => 'EPL';

  @override
  String get familleHubFeaturedMariage => 'Marriage';

  @override
  String get familleHubFeaturedMariageSub =>
      'Impact on your taxes, OASI and pension';

  @override
  String get familleHubFeaturedNaissance => 'Birth';

  @override
  String get familleHubFeaturedNaissanceSub =>
      'Benefits, leave and financial adjustments';

  @override
  String get familleHubFeaturedConcubinage => 'Cohabitation';

  @override
  String get familleHubFeaturedConcubinageSub =>
      'Protect your relationship without marriage';

  @override
  String get familleHubToolDivorce => 'Divorce';

  @override
  String get familleHubToolDecesProche => 'Death of a relative';

  @override
  String get travailHubFeaturedPremierEmploi => 'First job';

  @override
  String get travailHubFeaturedPremierEmploiSub =>
      'Everything you need to know to get started';

  @override
  String get travailHubFeaturedChomage => 'Unemployment';

  @override
  String get travailHubFeaturedChomageSub =>
      'Your rights, benefits and procedures';

  @override
  String get travailHubFeaturedIndependant => 'Self-employed';

  @override
  String get travailHubFeaturedIndependantSub =>
      'Tailored pension and taxation';

  @override
  String get travailHubToolComparateurEmploi => 'Job comparator';

  @override
  String get travailHubToolFrontalier => 'Cross-border';

  @override
  String get travailHubToolExpatriation => 'Expatriation';

  @override
  String get travailHubToolGenderGap => 'Gender gap';

  @override
  String get travailHubToolAvsIndependant => 'Self-employed OASI';

  @override
  String get travailHubToolIjm => 'Daily benefits';

  @override
  String get travailHubTool3aIndependant => 'Self-employed 3a';

  @override
  String get travailHubToolDividendeSalaire => 'Dividend vs Salary';

  @override
  String get travailHubToolLppVolontaire => 'Voluntary LPP';

  @override
  String get logementHubFeaturedCapacite => 'Mortgage capacity';

  @override
  String get logementHubFeaturedCapaciteSub => 'How much can you borrow?';

  @override
  String get logementHubFeaturedLocationPropriete => 'Renting vs Buying';

  @override
  String get logementHubFeaturedLocationProprieteSub =>
      'Compare both scenarios over 20 years';

  @override
  String get logementHubFeaturedVente => 'Property sale';

  @override
  String get logementHubFeaturedVenteSub =>
      'Capital gains tax and reinvestment';

  @override
  String get logementHubToolAmortissement => 'Amortization';

  @override
  String get logementHubToolEplCombine => 'Combined EPL';

  @override
  String get logementHubToolValeurLocative => 'Imputed rental value';

  @override
  String get logementHubToolSaronFixe => 'SARON vs Fixed';

  @override
  String get fiscaliteHubFeaturedComparateur => 'Tax comparator';

  @override
  String get fiscaliteHubFeaturedComparateurSub =>
      'Estimate your tax under different scenarios';

  @override
  String get fiscaliteHubFeaturedDemenagement => 'Cantonal move';

  @override
  String get fiscaliteHubFeaturedDemenagementSub =>
      'Compare taxation between cantons';

  @override
  String get fiscaliteHubFeaturedAllocation => 'Annual allocation';

  @override
  String get fiscaliteHubFeaturedAllocationSub =>
      'Where to put your savings this year?';

  @override
  String get fiscaliteHubToolInteretsComposes => 'Compound interest';

  @override
  String get fiscaliteHubToolBilanArbitrage => 'Arbitrage overview';

  @override
  String get patrimoineHubFeaturedSuccession => 'Inheritance';

  @override
  String get patrimoineHubFeaturedSuccessionSub =>
      'Plan ahead for your estate transfer';

  @override
  String get patrimoineHubFeaturedDonation => 'Donation';

  @override
  String get patrimoineHubFeaturedDonationSub =>
      'Taxation and impact on your pension';

  @override
  String get patrimoineHubFeaturedRenteCapital => 'Annuity vs Lump sum';

  @override
  String get patrimoineHubFeaturedRenteCapitalSub =>
      'Compare both options side by side';

  @override
  String get patrimoineHubToolBilan => 'Financial overview';

  @override
  String get patrimoineHubToolPortfolio => 'Portfolio';

  @override
  String get santeHubFeaturedFranchise => 'LAMal deductible';

  @override
  String get santeHubFeaturedFranchiseSub =>
      'Find the deductible that costs you least';

  @override
  String get santeHubFeaturedInvalidite => 'Disability';

  @override
  String get santeHubFeaturedInvaliditeSub =>
      'Estimate your coverage in case of disability';

  @override
  String get santeHubFeaturedCheckup => 'Coverage check-up';

  @override
  String get santeHubFeaturedCheckupSub => 'Check that you\'re well covered';

  @override
  String get santeHubToolAssuranceInvalidite => 'Disability insurance';

  @override
  String get santeHubToolInvaliditeIndependant => 'Self-employed disability';

  @override
  String get dossierSlmTitle => 'Local model (SLM)';

  @override
  String get dossierSlmSubtitle => 'On-device AI, works offline';

  @override
  String get dossierByokTitle => 'API Key (BYOK)';

  @override
  String get dossierByokSubtitle => 'Connect your own AI model';

  @override
  String get budgetErrorRetry => 'Something went wrong. Try again?';

  @override
  String get budgetChiffreChocCaption =>
      'What\'s left after all your fixed charges';

  @override
  String get budgetMethodTitle => 'Understanding this budget';

  @override
  String get budgetMethodBody =>
      'This budget separates your fixed charges (rent, health insurance, taxes) from your disposable income. The 50/30/20 rule suggests: 50% for needs, 30% for wants, 20% for savings. It\'s a guide, not an obligation.';

  @override
  String get budgetMethodSource =>
      'Source: 50/30/20 method (Elizabeth Warren, 2005)';

  @override
  String get budgetDisclaimerNote =>
      'Educational estimate. Not financial advice (FinSA art. 3).';

  @override
  String get chiffreChocIfYouAct => 'If you act';

  @override
  String get chiffreChocIfYouDontAct => 'If you don\'t act';

  @override
  String get chiffreChocAvantApresGapAct =>
      'A LPP buyback or 3a contributions could halve this gap.';

  @override
  String get chiffreChocAvantApresGapNoAct =>
      'The gap widens every year. At retirement, it\'s too late.';

  @override
  String get chiffreChocAvantApresLiquidityAct =>
      'Saving CHF 500/month rebuilds 3 months of reserves in 6 months.';

  @override
  String get chiffreChocAvantApresLiquidityNoAct =>
      'An emergency without reserves means consumer debt.';

  @override
  String get chiffreChocAvantApresTaxAct =>
      'Each year without 3a is a tax deduction lost.';

  @override
  String get chiffreChocAvantApresTaxNoAct =>
      'Without 3a, you pay full tax rate and don\'t prepare for retirement.';

  @override
  String get chiffreChocAvantApresIncomeAct =>
      'A few adjustments can improve your projection.';

  @override
  String get chiffreChocAvantApresIncomeNoAct =>
      'Your situation stays stable, but without room for growth.';

  @override
  String chiffreChocConfidenceSimple(String count) {
    return 'Based on $count data points. Add more to refine.';
  }

  @override
  String get quickStartTitle => 'Three questions, one first number.';

  @override
  String get quickStartSubtitle => 'The rest is up to you, when you\'re ready.';

  @override
  String get quickStartFirstName => 'Your first name';

  @override
  String get quickStartFirstNameHint => 'Optional';

  @override
  String get quickStartAge => 'Your age';

  @override
  String quickStartAgeValue(String age) {
    return '$age years';
  }

  @override
  String get quickStartSalary => 'Your gross annual income';

  @override
  String quickStartSalaryValue(String salary) {
    return '$salary/year';
  }

  @override
  String get quickStartCanton => 'Canton';

  @override
  String get quickStartPreviewTitle => 'Retirement preview';

  @override
  String get quickStartVerdictGood => 'On track';

  @override
  String get quickStartVerdictWatch => 'Worth watching';

  @override
  String get quickStartVerdictGap => 'Significant gap';

  @override
  String get quickStartToday => 'Today';

  @override
  String get quickStartAtRetirement => 'At retirement';

  @override
  String get quickStartPerMonth => '/month';

  @override
  String quickStartDropPct(String pct, String gap) {
    return '-$pct% purchasing power ($gap/month)';
  }

  @override
  String get quickStartDisclaimer =>
      'Educational estimate. Not financial advice (FinSA).';

  @override
  String get quickStartCta => 'See my overview';

  @override
  String get quickStartSectionIdentity => 'Identity & Household';

  @override
  String get quickStartSectionIncome => 'Income & Savings';

  @override
  String get quickStartSectionPension => 'Pension (LPP)';

  @override
  String get quickStartSectionProperty => 'Property & Debts';

  @override
  String quickStartSectionGuidance(String label) {
    return 'Section: $label — update your information below.';
  }

  @override
  String profileCompletionHint(int pct, String missing) {
    return '$pct % — missing $missing';
  }

  @override
  String get profileMissingLpp => 'your LPP';

  @override
  String get profileMissingIncome => 'your income';

  @override
  String get profileMissingProperty => 'your property';

  @override
  String get profileMissingIdentity => 'your identity';

  @override
  String get profileMissingAnd => ' and ';

  @override
  String profileAnnualRefreshDays(int days) {
    return 'Last updated $days days ago';
  }

  @override
  String get chiffreChocBack => 'Back';

  @override
  String get chiffreChocShowComparison => 'Show comparison';

  @override
  String get chiffreChocHideComparison => 'Hide comparison';

  @override
  String get dashboardNextActionsTitle => 'Your next actions';

  @override
  String get dashboardExploreAlsoTitle => 'Explore more';

  @override
  String get dashboardImproveAccuracyTitle => 'Improve your accuracy';

  @override
  String dashboardCurrentConfidence(int score) {
    return 'Current confidence: $score%';
  }

  @override
  String dashboardPrecisionPtsGain(int pts) {
    return '+$pts accuracy points';
  }

  @override
  String get dashboardOnboardingHeroTitle => 'Your retirement at a glance';

  @override
  String get dashboardOnboardingCta => 'Get started — 2 min';

  @override
  String get dashboardOnboardingConsent =>
      'No data stored without your consent.';

  @override
  String get dashboardEducationTitle =>
      'How does retirement work in Switzerland?';

  @override
  String get dashboardEducationSubtitle =>
      'AVS, LPP, 3a — the basics in 5 minutes';

  @override
  String get dashboardCockpitTitle => 'Detailed cockpit';

  @override
  String get dashboardCockpitSubtitle => 'Breakdown by pillar';

  @override
  String get dashboardCockpitCta => 'Open';

  @override
  String get dashboardRenteVsCapitalTitle => 'Annuity vs Lump sum';

  @override
  String get dashboardRenteVsCapitalSubtitle => 'Explore the break-even point';

  @override
  String get dashboardRenteVsCapitalCta => 'Simulate';

  @override
  String get dashboardRachatLppTitle => 'LPP buyback';

  @override
  String get dashboardRachatLppSubtitle => 'Simulate the tax impact';

  @override
  String get dashboardRachatLppCta => 'Calculate';

  @override
  String dashboardPrecisionGainPercent(int percent) {
    return 'Accuracy +$percent%';
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
      'You\'re on track to maintain your standard of living.';

  @override
  String get dashboardOneLinerLevers =>
      'There are levers to improve your projection.';

  @override
  String get dashboardOneLinerEveryAction =>
      'Every action counts — explore the available options.';

  @override
  String get profileFamilyCouple => 'In a couple';

  @override
  String get profileFamilySingle => 'Single';

  @override
  String get renteVsCapitalErrorRetry =>
      'The calculation failed. Please try again later.';

  @override
  String get rachatEchelonneTitle => 'Staggered LPP buyback';

  @override
  String get rachatEchelonneIntroTitle => 'Why stagger your buybacks?';

  @override
  String get rachatEchelonneIntroBody =>
      'Swiss tax is progressive: spreading an LPP buyback over several years keeps each deduction in a higher marginal bracket, maximising total tax savings. This simulator compares both approaches.';

  @override
  String get rachatEchelonneSavingsCaption =>
      'additional savings by staggering';

  @override
  String get rachatEchelonneBlocBetter =>
      'Lump-sum buyback more advantageous in this case';

  @override
  String get rachatEchelonneSituationLpp => 'LPP situation';

  @override
  String get rachatEchelonneAvoirActuel => 'Current LPP assets';

  @override
  String get rachatEchelonneRachatMax => 'Maximum buyback';

  @override
  String get rachatEchelonneSituationFiscale => 'Tax situation';

  @override
  String get rachatEchelonneCanton => 'Canton';

  @override
  String get rachatEchelonneEtatCivil => 'Civil status';

  @override
  String get rachatEchelonneCelibataire => 'Single';

  @override
  String get rachatEchelonneMarieE => 'Married';

  @override
  String get rachatEchelonneRevenuImposable => 'Taxable income';

  @override
  String get rachatEchelonneTauxMarginal => 'Estimated marginal rate';

  @override
  String get rachatEchelonneTauxManuel => 'Manually adjusted value';

  @override
  String get rachatEchelonneAjuster => 'Adjust';

  @override
  String get rachatEchelonneAuto => 'Auto';

  @override
  String get rachatEchelonneStrategie => 'Strategy';

  @override
  String get rachatEchelonneHorizon => 'Horizon (years)';

  @override
  String get rachatEchelonneComparaison => 'Comparison';

  @override
  String get rachatEchelonneBlocTitle => 'All in 1 year';

  @override
  String get rachatEchelonneBlocSubtitle => 'Lump-sum buyback';

  @override
  String get rachatEchelonneEchelonneSubtitle => 'Spread buyback';

  @override
  String get rachatEchelonnePlusAdapte => 'Best fit';

  @override
  String get rachatEchelonneEconomieFiscale => 'Tax savings';

  @override
  String get rachatEchelonneImpactTranche => 'Impact by tax bracket';

  @override
  String get rachatEchelonneImpactBlocExplain =>
      'As a lump sum, the deduction crosses several brackets (lower average rate). By staggering, each deduction stays in the highest bracket.';

  @override
  String get rachatEchelonneBloc => 'Lump sum';

  @override
  String get rachatEchelonneEchelonne => 'Staggered';

  @override
  String get rachatEchelonnePlanAnnuel => 'Annual plan';

  @override
  String get rachatEchelonneTotal => 'Total';

  @override
  String get rachatEchelonneRachat => 'Buyback';

  @override
  String get rachatEchelonneBlockageTitle => 'LPP art. 79b para. 3 — EPL lock';

  @override
  String get rachatEchelonneBlockageBody =>
      'After each buyback, any EPL withdrawal (home ownership promotion) is locked for 3 years. Plan accordingly if a property purchase is planned.';

  @override
  String get rachatEchelonneTauxMarginalTitle => 'Marginal tax rate';

  @override
  String get rachatEchelonneTauxMarginalBody =>
      'The marginal rate is the tax percentage on your last franc earned. At 32%, every CHF 1,000 deducted saves you CHF 320. The higher your income, the higher this rate.';

  @override
  String get rachatEchelonneTauxMarginalTip =>
      'That\'s why staggering buybacks is smart: each instalment stays in a high marginal bracket.';

  @override
  String get rachatEchelonneTauxMarginalSemantics =>
      'Marginal rate information';

  @override
  String get staggered3aTitle => 'Staggered 3a withdrawal';

  @override
  String get staggered3aEconomie => 'Estimated savings';

  @override
  String get staggered3aIntroTitle => 'Why stagger 3a withdrawals?';

  @override
  String get staggered3aIntroBody =>
      'Tax on pension capital withdrawal is progressive. By spreading your 3a assets across several accounts and withdrawing in different tax years, you reduce the average tax rate. The law allows up to 5 pillar 3a accounts per person (OPP3).';

  @override
  String get staggered3aParametres => 'Parameters';

  @override
  String get staggered3aAvoirTotal => 'Total 3a assets';

  @override
  String get staggered3aNbComptes => 'Number of 3a accounts';

  @override
  String get staggered3aCanton => 'Canton';

  @override
  String get staggered3aRevenuImposable => 'Taxable income';

  @override
  String get staggered3aAgeDebut => 'Withdrawal start age';

  @override
  String get staggered3aAgeFin => 'Last withdrawal age';

  @override
  String get staggered3aResultat => 'Result';

  @override
  String get staggered3aEnBloc => 'Lump sum';

  @override
  String get staggered3aRetraitUnique => 'Single withdrawal';

  @override
  String get staggered3aEchelonneLabel => 'Staggered';

  @override
  String get staggered3aImpotEstime => 'Estimated tax';

  @override
  String get staggered3aPlanAnnuel => 'Annual plan';

  @override
  String get staggered3aAge => 'Age';

  @override
  String get staggered3aRetrait => 'Withdrawal';

  @override
  String get staggered3aImpot => 'Tax';

  @override
  String get staggered3aNet => 'Net';

  @override
  String get staggered3aTotal => 'Total';

  @override
  String get staggered3aAns => 'years';

  @override
  String get optimDecaissementTitle => '3a withdrawal order';

  @override
  String get optimDecaissementChiffre => '+CHF 3,500';

  @override
  String get optimDecaissementChiffreExplication =>
      'That\'s the extra tax paid when withdrawing 2 pillar 3a accounts in the same year rather than spreading them over 2 different tax years — per LIFD art. 38.';

  @override
  String get optimDecaissementPrincipe => 'The staggering principle';

  @override
  String get optimDecaissementInfo1Title => '1 pillar 3a account per tax year';

  @override
  String get optimDecaissementInfo1Body =>
      'The 3a withdrawal is taxed separately from ordinary income (LIFD art. 38), but the rate increases with the amount withdrawn. By splitting over several years, each withdrawal stays in a low bracket.';

  @override
  String get optimDecaissementInfo2Title => 'Up to 10 simultaneous 3a accounts';

  @override
  String get optimDecaissementInfo2Body =>
      'Since 2026, you can hold several 3a accounts simultaneously (OPP3 2026 revision). By opening them progressively, you can stagger withdrawals over 3 to 10 years.';

  @override
  String get optimDecaissementInfo3Title => 'Taxation varies by canton';

  @override
  String get optimDecaissementInfo3Body =>
      'Several cantons offer additional deductions. The choice of residence canton at the time of withdrawal directly influences taxation.';

  @override
  String get optimDecaissementIllustration => 'Example: CHF 150,000 in 3a';

  @override
  String get optimDecaissementTableSpread => 'Spread';

  @override
  String get optimDecaissementTableAmount => 'Amount/withdrawal';

  @override
  String get optimDecaissementTableTax => 'Est. tax*';

  @override
  String get optimDecaissementTableRow1Spread => '1 year';

  @override
  String get optimDecaissementTableRow1Amount => 'CHF 150,000';

  @override
  String get optimDecaissementTableRow1Tax => '~CHF 12,500';

  @override
  String get optimDecaissementTableRow2Spread => '3 years';

  @override
  String get optimDecaissementTableRow2Amount => 'CHF 50,000/yr';

  @override
  String get optimDecaissementTableRow2Tax => '~CHF 3,200/yr';

  @override
  String get optimDecaissementTableRow3Spread => '5 years';

  @override
  String get optimDecaissementTableRow3Amount => 'CHF 30,000/yr';

  @override
  String get optimDecaissementTableRow3Tax => '~CHF 1,700/yr';

  @override
  String get optimDecaissementTableFootnote =>
      '* Indicative estimates based on an average cantonal rate (ZH). Varies by canton and individual tax situation.';

  @override
  String get optimDecaissementPlanTitle => 'How to plan your withdrawal';

  @override
  String get optimDecaissementStep1Title => 'Inventory of your 3a accounts';

  @override
  String get optimDecaissementStep1Body =>
      'List each 3a account with its balance and provider. Note the planned retirement years for each withdrawal.';

  @override
  String get optimDecaissementStep2Title =>
      'Simulate the tax impact by scenario';

  @override
  String get optimDecaissementStep2Body =>
      'Compare: withdraw everything in 1 year vs. spread over 3, 5 or 7 years. The difference can be several thousand francs.';

  @override
  String get optimDecaissementStep3Title =>
      'Coordinate with your LPP retirement';

  @override
  String get optimDecaissementStep3Body =>
      'Waiting 1 to 2 years after the LPP capital withdrawal for the first 3a reduces the total tax burden in the departure year.';

  @override
  String get optimDecaissementSpecialisteTitle => 'Consult a specialist';

  @override
  String get optimDecaissementSpecialisteBody =>
      'A pension specialist can model your precise withdrawal plan based on your situation.';

  @override
  String get optimDecaissementSources =>
      '• LIFD art. 38 — Separate taxation of capital benefits\n• OPP3 art. 3 — Early withdrawal conditions\n• OPP3 art. 7 — Deduction ceilings\n• OPP3 (2026 revision) — Multiple 3a accounts';

  @override
  String get optimDecaissementDisclaimer =>
      'Educational information, not tax advice under FinSA.';

  @override
  String get successionAlertTitle =>
      'Without a will, your partner inherits nothing';

  @override
  String get successionAlertBody =>
      'Swiss inheritance law (CC art. 457 ff.) first protects descendants, then parents and the legal spouse. Without a legal bond and without a will, an unmarried partner is excluded.';

  @override
  String get successionNotionsCles => 'Key concepts';

  @override
  String get successionReservesBody =>
      'A share of your estate is reserved by law for your descendants and your spouse. This portion cannot be set aside by will.';

  @override
  String get successionQuotiteSubtitle => 'CC art. 470 para. 2';

  @override
  String get successionQuotiteBody =>
      'What remains after statutory portions is your disposable portion — the share you can freely bequeath to anyone.';

  @override
  String get successionTestamentBody =>
      'Two valid forms: holographic (handwritten) or notarised (before a notary). No will = legal succession by default.';

  @override
  String get successionDonationTitle => 'Lifetime gift';

  @override
  String get successionDonationSubtitle => 'CO art. 239 ff.';

  @override
  String get successionDonationBody =>
      'Giving during your lifetime anticipates the succession and may reduce inheritance tax.';

  @override
  String get successionBeneficiairesTitle => 'LPP and 3a beneficiaries';

  @override
  String get successionBeneficiairesSubtitle => 'LPP art. 20 · OPP3 art. 2';

  @override
  String get successionBeneficiairesBody =>
      'LPP capital and 3a balance are NOT part of your ordinary estate — they are paid to designated beneficiaries.';

  @override
  String get successionDecesProche => 'In case of death of a loved one';

  @override
  String get successionCheck1 =>
      'Check beneficiary designation on each 3a account';

  @override
  String get successionCheck2 =>
      'Check LPP beneficiary designation with your pension fund';

  @override
  String get successionCheck3 => 'Draft or update your will';

  @override
  String get successionCheck4 =>
      'Check your matrimonial regime if married (CC art. 181 ff.)';

  @override
  String get successionCheck5 =>
      'Inform your loved ones of the location of your will';

  @override
  String get successionSpecialisteTitle => 'Consult a notary or specialist';

  @override
  String get successionSpecialisteBody =>
      'A notary or succession law specialist can draft or review your will.';

  @override
  String get successionSources =>
      '• CC art. 457–640 — Law of succession\n• CC art. 470–471 — Statutory portions\n• CC art. 498–504 — Forms of will\n• LPP art. 20 — LPP beneficiaries\n• OPP3 art. 2 — Pillar 3a beneficiaries';

  @override
  String naissanceAllocForCanton(String canton, int count, String plural) {
    return 'Family allowances in $canton for $count child$plural';
  }

  @override
  String naissanceAllocContextNote(String canton, int count, String plural) {
    return '($canton, $count child$plural)';
  }

  @override
  String get affordabilityEmotionalPositif => 'You can afford this';

  @override
  String get affordabilityEmotionalNegatif =>
      'A piece of the puzzle is missing';

  @override
  String get affordabilityExploreAlso => 'Explore more';

  @override
  String get affordabilityRelatedAmortTitle =>
      'Direct vs indirect amortization';

  @override
  String get affordabilityRelatedAmortSubtitle => 'Tax impact of each strategy';

  @override
  String get affordabilityRelatedSaronTitle => 'SARON vs fixed rate';

  @override
  String get affordabilityRelatedSaronSubtitle => 'Compare mortgage types';

  @override
  String get affordabilityRelatedValeurTitle => 'Imputed rental value';

  @override
  String get affordabilityRelatedValeurSubtitle =>
      'Understand housing taxation';

  @override
  String get affordabilityRelatedEplTitle => 'EPL — Use my 2nd pillar';

  @override
  String get affordabilityRelatedEplSubtitle => 'Early withdrawal for purchase';

  @override
  String get affordabilityRelatedSimulate => 'Simulate';

  @override
  String get affordabilityRelatedCompare => 'Compare';

  @override
  String get affordabilityRelatedCalculate => 'Calculate';

  @override
  String get affordabilityAdvancedParams => 'More assumptions';

  @override
  String get demenagementTitreV2 => 'Moving cantons — how much do you save?';

  @override
  String get demenagementCtaOptimal => 'Find the best canton for you';

  @override
  String demenagementInsightPositif(String mois) {
    return 'This move boosts your purchasing power. The savings cover about $mois months of average rent.';
  }

  @override
  String get demenagementInsightNegatif =>
      'This move costs more. Check if the quality of life offsets the difference.';

  @override
  String get demenagementBilanTotal =>
      'Total balance (taxes + health insurance)';

  @override
  String divorceTransfertAmount(String amount, String direction) {
    return 'Transfer of $amount ($direction)';
  }

  @override
  String divorceFiscalDelta(String sign, String amount) {
    return 'Difference: $sign$amount/year';
  }

  @override
  String divorcePensionMois(String amount) {
    return '$amount/month';
  }

  @override
  String divorcePensionAnnuel(String amount) {
    return 'i.e. $amount/year';
  }

  @override
  String get divorceConjoint1Label => 'Spouse 1';

  @override
  String get divorceConjoint2Label => 'Spouse 2';

  @override
  String get divorceSplitC1 => 'S1';

  @override
  String get divorceSplitC2 => 'S2';

  @override
  String get unemploymentVague1Label => 'Wave 1 — Administrative urgency';

  @override
  String get unemploymentVague1Text =>
      'Register with the ORP within the first 5 days. Otherwise: lost benefits. Every day of delay = a lost benefit.';

  @override
  String get unemploymentVague2Label => 'Wave 2 — Budget to adjust';

  @override
  String get unemploymentVague2Text =>
      'Immediate income drop. Unemployment insurance does not cover public holidays or the waiting period (5–20 days). Review your budget from day 1.';

  @override
  String get unemploymentVague3Label => 'Wave 3 — Hidden decisions';

  @override
  String get unemploymentVague3Text =>
      'Within 30 days: transfer your LPP (otherwise substitute institution). Before the following month: pause 3a, review health insurance.';

  @override
  String get unemploymentBudgetLoyer => 'Rent';

  @override
  String get unemploymentBudgetLamal => 'Health insurance';

  @override
  String get unemploymentBudgetTransport => 'Transport';

  @override
  String get unemploymentBudgetLoisirs => 'Leisure';

  @override
  String get unemploymentBudgetEpargne3a => '3a savings';

  @override
  String get unemploymentGainMin => 'CHF 0';

  @override
  String get unemploymentGainMax => 'CHF 12,350';

  @override
  String get unemploymentBracket1 => '12–17 months contrib.';

  @override
  String get unemploymentBracket1Value => '200 benefits';

  @override
  String get unemploymentBracket2 => '18–21 months contrib.';

  @override
  String get unemploymentBracket2Value => '260 benefits';

  @override
  String unemploymentBracket3(int age) {
    return '>= 22 months, < $age yrs';
  }

  @override
  String get unemploymentBracket3Value => '400 benefits';

  @override
  String unemploymentBracket4(int age) {
    return '>= 22 months, >= $age yrs';
  }

  @override
  String get unemploymentBracket4Value => '520 benefits';

  @override
  String get allocAnnuelleTitle => 'Where to put your CHF?';

  @override
  String get allocAnnuelleBudgetTitle => 'Your annual budget';

  @override
  String get allocAnnuelleMontantLabel => 'Amount available per year (CHF)';

  @override
  String get allocAnnuelleTauxMarginal => 'Estimated marginal tax rate';

  @override
  String get allocAnnuelleAnneesRetraite => 'Years to retirement';

  @override
  String allocAnnuelleAnneesValue(int years) {
    return '$years years';
  }

  @override
  String get allocAnnuelle3aMaxed => '3a already maxed';

  @override
  String get allocAnnuelleRachatLpp => 'LPP buyback potential';

  @override
  String get allocAnnuelleRachatMontant => 'Possible buyback amount (CHF)';

  @override
  String get allocAnnuelleProprietaire => 'Property owner';

  @override
  String get allocAnnuelleComparer => 'Compare strategies';

  @override
  String get allocAnnuelleTrajectoires => 'Compared trajectories';

  @override
  String get allocAnnuelleGraphHint =>
      'Touch the chart to see values at each year.';

  @override
  String get allocAnnuelleValeurTerminale => 'Estimated terminal value';

  @override
  String allocAnnuelleApresAnnees(int years) {
    return 'After $years years';
  }

  @override
  String get allocAnnuelleHypotheses => 'Assumptions used';

  @override
  String get allocAnnuelleRendementMarche => 'Market return';

  @override
  String get allocAnnuelleRendementLpp => 'LPP return';

  @override
  String get allocAnnuelleRendement3a => '3a return';

  @override
  String get allocAnnuelleAvertissement => 'Disclaimer';

  @override
  String allocAnnuelleSources(String sources) {
    return 'Sources: $sources';
  }

  @override
  String get allocAnnuellePreRempli => 'Values pre-filled from your profile';

  @override
  String get allocAnnuelleEncouragement =>
      'Every franc wisely invested works for you. Compare the options and choose with confidence.';

  @override
  String get expatTab2EduInsert =>
      'Switzerland does not levy an exit tax — unlike the United States or France. Your latent capital gains are not taxed when you leave. This is a major advantage for expats.';

  @override
  String get expatTimelineToday => 'Today';

  @override
  String get expatTimelineTodayDesc => 'Start planning';

  @override
  String get expatTimelineTodayTiming => 'Now';

  @override
  String get expatTimeline2to3Months => '2-3 months before';

  @override
  String get expatTimeline2to3MonthsDesc => 'Notify the commune, cancel LAMal';

  @override
  String expatTimeline2to3MonthsTiming(int months) {
    return 'In ~$months months';
  }

  @override
  String get expatTimeline1Month => '1 month before';

  @override
  String get expatTimeline1MonthDesc => 'Withdraw 3a, transfer LPP';

  @override
  String expatTimeline1MonthTiming(int months) {
    return 'In ~$months months';
  }

  @override
  String get expatTimelineDDay => 'D-Day';

  @override
  String get expatTimelineDDayDesc => 'Effective departure';

  @override
  String expatTimelineDDayTiming(int days) {
    return 'In $days days';
  }

  @override
  String get expatTimeline30After => '30 days after';

  @override
  String get expatTimeline30AfterDesc => 'File prorated taxes';

  @override
  String get expatTimeline30AfterTiming => 'After departure';

  @override
  String get expatTimelineUrgent => 'Urgent!';

  @override
  String get expatTimelinePassed => 'Passed';

  @override
  String expatSavingsBadge(String amount, String percent) {
    return 'Savings: $amount (-$percent%)';
  }

  @override
  String expatForfaitMoreCostly(String amount) {
    return 'Lump-sum more costly: +$amount';
  }

  @override
  String expatForfaitBase(String amount) {
    return 'Base: $amount';
  }

  @override
  String expatAvsReductionExplain(String percent) {
    return 'Each missing year reduces your pension by about $percent%. The reduction is permanent and applies for life.';
  }

  @override
  String expatAvsChiffreChoc(String amount) {
    return '-$amount/year on your AVS pension';
  }

  @override
  String expatDepartChiffreChoc(String amount) {
    return '$amount of capital to secure before departure';
  }

  @override
  String get independantCoveredLabel => 'Covered';

  @override
  String get independantCriticalLabel => 'Not covered — critical';

  @override
  String get independantHighLabel => 'Not covered';

  @override
  String get independantLowLabel => 'Not covered';

  @override
  String fiscalIncomeInfoLabel(String income, String status, String children) {
    return 'Income: $income | $status$children';
  }

  @override
  String get fiscalStatusMarried => 'Married';

  @override
  String get fiscalStatusSingle => 'Single';

  @override
  String fiscalChildrenSuffix(int count) {
    return ' + $count child(ren)';
  }

  @override
  String get fiscalPerMonth => '/month';

  @override
  String get sim3aTitle => 'Your 3rd pillar';

  @override
  String get sim3aExportTooltip => 'Export my report';

  @override
  String get sim3aCoachTitle => 'Mentor\'s advice';

  @override
  String get sim3aCoachBody =>
      'The 3a is one of the most effective optimisation tools in Switzerland. The immediate tax saving is a tangible advantage.';

  @override
  String get sim3aParamsHeader => 'Your parameters';

  @override
  String get sim3aAnnualContribution => 'Annual contribution';

  @override
  String get sim3aAnnualContributionIndep =>
      'Annual contribution (self-employed, no LPP)';

  @override
  String get sim3aMarginalRate => 'Marginal tax rate';

  @override
  String get sim3aYearsToRetirement => 'Years to retirement';

  @override
  String get sim3aExpectedReturn => 'Expected annual return';

  @override
  String sim3aYearsSuffix(int count) {
    return '$count years';
  }

  @override
  String get sim3aAnnualTaxSaved => 'Annual tax saved';

  @override
  String get sim3aFinalCapital => 'Capital at maturity';

  @override
  String get sim3aCumulativeTaxSaved => 'Cumulative tax saved';

  @override
  String get sim3aStrategyHeader => 'Winning strategy';

  @override
  String get sim3aStratBankTitle => 'Bank > Insurance';

  @override
  String get sim3aStratBankBody =>
      'Avoid tied insurance contracts. Stay flexible with an invested bank 3a.';

  @override
  String get sim3aStrat5AccountsTitle => 'The 5-account rule';

  @override
  String get sim3aStrat5AccountsBody =>
      'Open multiple accounts to stagger withdrawals and reduce tax progression.';

  @override
  String get sim3aStrat100ActionsTitle => '100% Equities';

  @override
  String get sim3aStrat100ActionsBody =>
      'If retirement is 15+ years away, an equity strategy could maximise your capital.';

  @override
  String get sim3aExploreAlso => 'Also explore';

  @override
  String get sim3aProviderComparator => 'Provider comparator';

  @override
  String get sim3aProviderComparatorSub => 'VIAC, Finpension, frankly...';

  @override
  String get sim3aRealReturn => 'Real return';

  @override
  String get sim3aRealReturnSub => 'After fees, inflation and taxes';

  @override
  String get sim3aStaggeredWithdrawal => 'Staggered withdrawal';

  @override
  String get sim3aStaggeredWithdrawalSub => 'Spread withdrawals to reduce tax';

  @override
  String get sim3aCtaCompare => 'Compare';

  @override
  String get sim3aCtaCalculate => 'Calculate';

  @override
  String get sim3aCtaPlan => 'Plan';

  @override
  String get sim3aDisclaimer =>
      'Educational estimate. Actual savings depend on your place of residence and family situation. Not financial advice (FinSA).';

  @override
  String get sim3aDebtLockedTitle => 'Debt repayment first';

  @override
  String get sim3aDebtLockedMessage =>
      'In safe mode, 3a action recommendations are disabled. The priority is to stabilise your finances before contributing to 3a.';

  @override
  String get sim3aDebtStrategyTitle => 'Strategy locked';

  @override
  String get sim3aDebtStrategyMessage =>
      '3a investment strategies are disabled while you have active debts. Repaying your debts yields a higher return than any investment.';

  @override
  String get realReturnTitle => 'Real return 3a';

  @override
  String get realReturnChiffreChocLabel => 'Equivalent rate on net effort';

  @override
  String realReturnVsNominal(String rate) {
    return 'vs $rate% net 3a rate (gross − fees)';
  }

  @override
  String realReturnEffortNet(String amount, String pts) {
    return 'Net effort: $amount/yr | Implicit tax premium: +$pts pts';
  }

  @override
  String get realReturnParams => 'Parameters';

  @override
  String get realReturnAnnualPayment => 'Annual contribution';

  @override
  String get realReturnMarginalRate => 'Marginal rate';

  @override
  String get realReturnGrossReturn => 'Gross return';

  @override
  String get realReturnMgmtFees => 'Management fees';

  @override
  String get realReturnDuration => 'Investment duration';

  @override
  String realReturnYearsSuffix(int count) {
    return '$count years';
  }

  @override
  String get realReturnCompared => 'Compared returns';

  @override
  String get realReturnNominal3a => 'Nominal 3a return';

  @override
  String get realReturnRealWithFiscal => 'Real return (incl. tax benefit)';

  @override
  String get realReturnEquivNote =>
      'This is an equivalent rate: it does not represent an expected market return.';

  @override
  String get realReturnSavingsAccount => 'Savings account return';

  @override
  String realReturnFinalCapital(int years) {
    return 'Final capital after $years years';
  }

  @override
  String get realReturn3aFintech => '3a Fintech + tax benefit';

  @override
  String get realReturnSavings15 => 'Savings account 1.5%';

  @override
  String realReturnGainVsSavings(String amount) {
    return 'Gain vs savings: CHF $amount';
  }

  @override
  String get realReturnFiscalDetail => 'Tax saving details';

  @override
  String get realReturnTotalPayments => 'Total contributions';

  @override
  String get realReturnFinalCapital3a => 'Final 3a capital (excl. tax)';

  @override
  String get realReturnCumulativeFiscal => 'Cumulative tax saved';

  @override
  String get realReturnTotalWithFiscal => 'Total with tax benefit';

  @override
  String realReturnAhaMoment(String netAmount) {
    return 'Your real effort: $netAmount/yr. The tax office funds the rest — a rare lever in Switzerland.';
  }

  @override
  String get realReturnPerYear => '/ yr';

  @override
  String get genderGapAppBarTitle => 'Pension gap';

  @override
  String get genderGapHeaderTitle => 'Pension gap';

  @override
  String get genderGapHeaderSubtitle => 'Part-time work impact on retirement';

  @override
  String get genderGapIntro =>
      'The coordination deduction (CHF 26,460) is not prorated for part-time work, which disproportionately affects part-time workers. Move the slider to see the impact.';

  @override
  String get genderGapTauxActivite => 'Activity rate';

  @override
  String get genderGapParametres => 'Parameters';

  @override
  String get genderGapRevenuAnnuel => 'Gross annual income (100%)';

  @override
  String get genderGapAge => 'Age';

  @override
  String genderGapAgeValue(String age) {
    return '$age years';
  }

  @override
  String get genderGapAvoirLpp => 'Current LPP assets';

  @override
  String get genderGapAnneesCotisation => 'Contribution years';

  @override
  String get genderGapCanton => 'Canton';

  @override
  String get genderGapDemoMode =>
      'Demo mode: example profile. Complete your assessment for personalised results.';

  @override
  String get genderGapRenteLppEstimee => 'Estimated LPP pension';

  @override
  String genderGapProjection(String annees) {
    return 'Projection to $annees years (age 65)';
  }

  @override
  String get genderGapAt100 => 'At 100%';

  @override
  String genderGapAtTaux(String taux) {
    return 'At $taux%';
  }

  @override
  String get genderGapPerYear => '/yr';

  @override
  String get genderGapLacuneAnnuelle => 'Annual gap';

  @override
  String get genderGapLacuneTotale => 'Total gap (~20 years)';

  @override
  String get genderGapCoordinationTitle =>
      'Understanding the coordination deduction';

  @override
  String get genderGapCoordinationBody =>
      'The coordination deduction is a fixed amount of CHF 26,460 subtracted from your gross salary to calculate the coordinated salary (LPP base). This amount is the same whether you work 100% or 50%.';

  @override
  String get genderGapSalaireBrut100 => 'Gross salary at 100%';

  @override
  String get genderGapSalaireCoordonne100 => 'Coordinated salary at 100%';

  @override
  String genderGapSalaireBrutTaux(String taux) {
    return 'Gross salary at $taux%';
  }

  @override
  String genderGapSalaireCoordonneTaux(String taux) {
    return 'Coordinated salary at $taux%';
  }

  @override
  String get genderGapDeductionFixe => 'Coordination deduction (fixed)';

  @override
  String get genderGapSourceCoordination => 'Source: LPP art. 8, OPP2 art. 5';

  @override
  String get genderGapStatOfsTitle => 'FSO statistic';

  @override
  String get genderGapRecommandations => 'Recommendations';

  @override
  String get genderGapDisclaimer =>
      'The results shown are simplified estimates for informational purposes only. They do not constitute personalised financial advice. Consult your pension fund and a qualified specialist before making any decisions.';

  @override
  String get genderGapSources => 'Sources';

  @override
  String get genderGapSourcesBody =>
      'LPP art. 8 (coordination deduction) / LPP art. 14 (conversion rate 6.8%) / OPP2 art. 5 / OPP3 art. 7 / LPP art. 79b (voluntary buyback) / FSO 2024 (gender gap statistics)';

  @override
  String get achievementsErrorMessage => 'Loading failed. Try again?';

  @override
  String get documentsEmptyVoice =>
      'Nothing here yet. Scan a certificate and everything becomes clearer.';

  @override
  String documentsConfidenceChoc(String count, String pct) {
    return '$count documents = $pct% confidence';
  }

  @override
  String get lamalFranchiseAppBarTitle => 'LAMal Deductible';

  @override
  String get lamalFranchiseDemoMode => 'DEMO MODE';

  @override
  String get lamalFranchiseHeaderTitle => 'Your LAMal deductible';

  @override
  String get lamalFranchiseHeaderSubtitle =>
      'Find the best deductible for your health costs';

  @override
  String get lamalFranchiseIntro =>
      'A higher deductible lowers your monthly premium but increases your out-of-pocket costs when you see a doctor. Adjust the sliders to find the right balance.';

  @override
  String get lamalFranchiseToggleAdulte => 'Adult';

  @override
  String get lamalFranchiseToggleEnfant => 'Child';

  @override
  String get lamalFranchisePrimeSliderLabel =>
      'Monthly premium (deductible 300)';

  @override
  String get lamalFranchiseDepensesSliderLabel =>
      'Estimated annual health costs';

  @override
  String get lamalFranchiseComparisonHeader => 'DEDUCTIBLE COMPARISON';

  @override
  String get lamalFranchiseRecommandee => 'RECOMMENDED';

  @override
  String lamalFranchiseTotalPrefix(String amount) {
    return 'Total: $amount';
  }

  @override
  String get lamalFranchisePrimeAn => 'Premium/yr';

  @override
  String get lamalFranchiseQuotePart => 'Co-pay';

  @override
  String get lamalFranchiseEconomie => 'Savings';

  @override
  String get lamalFranchiseBreakEvenTitle => 'Break-even thresholds';

  @override
  String lamalFranchiseBreakEvenItem(String seuil, String basse, String haute) {
    return 'Above $seuil in costs, the $basse deductible becomes cheaper than $haute.';
  }

  @override
  String get lamalFranchiseRecommandationsHeader => 'RECOMMENDATIONS';

  @override
  String get lamalFranchiseAlertText =>
      'Reminder: you can change your deductible before November 30 each year for the following year.';

  @override
  String get lamalFranchiseDisclaimer =>
      'Educational estimate. Premiums vary by insurer, region, and plan. Not financial advice (FinSA).';

  @override
  String get lamalFranchiseSourcesHeader => 'Sources';

  @override
  String get lamalFranchiseSourcesBody =>
      'KVG art. 62-64 (deductible and co-pay) / KVV (ordinance) / priminfo.admin.ch (official comparator) / KVG art. 7 (free choice of insurer) / KVG art. 41a (alternative models)';

  @override
  String get lamalFranchisePrimeMin => 'CHF 200';

  @override
  String get lamalFranchisePrimeMax => 'CHF 600';

  @override
  String get lamalFranchiseDepensesMin => 'CHF 0';

  @override
  String get lamalFranchiseDepensesMax => 'CHF 10,000';

  @override
  String get lamalFranchiseSelectAdulte => 'Select adult';

  @override
  String get lamalFranchiseSelectEnfant => 'Select child';

  @override
  String get firstJobCantonLabel => 'Canton';

  @override
  String get firstJobSalaryMin => 'CHF 2,000';

  @override
  String get firstJobSalaryMax => 'CHF 15,000';

  @override
  String get firstJobActivityMin => '10%';

  @override
  String get firstJobActivityMax => '100%';

  @override
  String firstJobFiscalSavings(String amount) {
    return 'Estimated tax savings: ~$amount/yr';
  }

  @override
  String firstJobFranchiseSavings(String amount) {
    return 'Deductible 2,500 vs 300: estimated savings of ~$amount/yr in premiums';
  }

  @override
  String get firstJobTopBadge => 'TOP';

  @override
  String get authLoginSubtitle => 'Access your personal financial space';

  @override
  String get authPasswordRequired => 'Password required';

  @override
  String get authForgotPasswordLink => 'Forgot password?';

  @override
  String get authVerifyEmailLink => 'Verify my email';

  @override
  String get authDateOfBirth => 'Date of birth';

  @override
  String get authDateOfBirthHint => 'dd.mm.yyyy';

  @override
  String get authDateOfBirthRequired => 'Required for AVS/LPP projections';

  @override
  String get authDateOfBirthTooYoung =>
      'You must be at least 18 years old (TOS art. 4.1)';

  @override
  String get authDateOfBirthHelp => 'Date of birth';

  @override
  String get authDateOfBirthCancel => 'Cancel';

  @override
  String get authDateOfBirthConfirm => 'Confirm';

  @override
  String get authPasswordHintFull => '8+ characters, uppercase, digit, symbol';

  @override
  String get authPasswordMinChars => 'Minimum 8 characters';

  @override
  String get authPasswordNeedUppercase =>
      'At least one uppercase letter required';

  @override
  String get authPasswordNeedDigit => 'At least one digit required';

  @override
  String get authPasswordNeedSpecial =>
      'At least one special character required (!@#\$...)';

  @override
  String get authConfirmRequired => 'Confirmation required';

  @override
  String get authPrivacyPolicyText => 'privacy policy';

  @override
  String get slmStatusRunning => 'Ready — the coach uses on-device AI';

  @override
  String get slmStatusReady => 'Model downloaded — initialisation required';

  @override
  String get slmStatusError =>
      'Error — device not compatible or insufficient memory';

  @override
  String get slmStatusDownloading => 'Downloading…';

  @override
  String get slmStatusNotDownloaded => 'Model not downloaded';

  @override
  String get slmStatusModelReady => 'Model ready — start initialisation';

  @override
  String slmSizeLabel(String size) {
    return 'Size: $size';
  }

  @override
  String slmVersionLabel(String version) {
    return 'Version: $version';
  }

  @override
  String slmWifiEstimate(int minutes) {
    return '~$minutes min on WiFi';
  }

  @override
  String slmDownloadButton(String size) {
    return 'Download ($size)';
  }

  @override
  String slmDownloadDialogBody(String size, int minutes, String hint) {
    return 'The model is $size. Make sure you are connected to WiFi to avoid heavy mobile data usage.\n\n~$minutes min on WiFi. Compatible: $hint.';
  }

  @override
  String slmDownloadFailedSnack(String reason) {
    return 'Download failed. $reason';
  }

  @override
  String get slmDownloadFailedDefault =>
      'Check your WiFi and available storage.';

  @override
  String get slmDownloadNotAvailable =>
      'This build does not support model download.';

  @override
  String slmInfoDownload(int minutes) {
    return 'Download the model once (~$minutes min on WiFi)';
  }

  @override
  String get slmInfoOnDevice => 'AI runs directly on your phone';

  @override
  String get slmInfoOffline => 'Works even without internet';

  @override
  String get slmInfoPrivacy => 'Your data never leaves your device';

  @override
  String get slmInfoSpeed => 'Responses in 2-4 seconds on a recent device';

  @override
  String slmInfoSourceModel(String modelId) {
    return 'Model source: $modelId';
  }

  @override
  String get slmInfoAuthConfigured => 'HuggingFace authentication: configured';

  @override
  String get slmInfoAuthNotConfigured =>
      'HuggingFace authentication: not configured (download impossible if Gemma URL is gated)';

  @override
  String slmInfoCompatibility(String hint, String size, int ram) {
    return 'Compatibility: $hint.\nThe model requires $size of disk space and ~$ram GB of RAM.';
  }

  @override
  String get consentErrorMessage => 'Something went wrong. Try again later.';

  @override
  String get adminObsAuthBilling => 'Auth & Billing';

  @override
  String get adminObsOnboardingQuality => 'Onboarding quality';

  @override
  String get adminObsCohorts => 'Cohorts (variant x platform)';

  @override
  String get adminObsNoData => 'No data';

  @override
  String get adminAnalyticsTitle => 'Analytics';

  @override
  String get adminAnalyticsLoadError => 'Unable to load analytics';

  @override
  String get adminAnalyticsRetry => 'Retry';

  @override
  String get adminAnalyticsFunnel => 'Conversion funnel';

  @override
  String get adminAnalyticsByScreen => 'Events by screen';

  @override
  String get adminAnalyticsByCategory => 'Events by category';

  @override
  String get adminAnalyticsNoFunnel => 'No funnel data yet.';

  @override
  String get adminAnalyticsNoData => 'No data yet.';

  @override
  String get adminAnalyticsSessions => 'Sessions';

  @override
  String get adminAnalyticsEvents => 'Events';

  @override
  String get amortizationAppBarTitle => 'Direct vs indirect';

  @override
  String get eplCombinedAppBarTitle => 'EPL multi-sources';

  @override
  String get eplCombinedMinRequired => 'Minimum required: 20%';

  @override
  String get eplCombinedFundsBreakdown => 'Equity breakdown';

  @override
  String get eplCombinedParameters => 'Parameters';

  @override
  String get eplCombinedCanton => 'Canton';

  @override
  String get eplCombinedTargetPrice => 'Target purchase price';

  @override
  String get eplCombinedCashSavings => 'Cash savings';

  @override
  String get eplCombinedAvoir3a => 'Pillar 3a balance';

  @override
  String get eplCombinedAvoirLpp => 'LPP balance';

  @override
  String get eplCombinedSourcesDetail => 'Sources detail';

  @override
  String get eplCombinedTotalEquity => 'Total equity';

  @override
  String get eplCombinedEstimatedTaxes => 'Estimated taxes (3a + LPP)';

  @override
  String get eplCombinedNetTotal => 'Net total amount';

  @override
  String get eplCombinedRequiredEquity => 'Required equity (20%)';

  @override
  String get eplCombinedEstimatedTax => 'Estimated tax';

  @override
  String get eplCombinedNet => 'Net';

  @override
  String get eplCombinedRecommendedOrder => 'Recommended order';

  @override
  String get eplCombinedOrderCashTitle => 'Cash savings';

  @override
  String get eplCombinedOrderCashReason => 'No tax, no impact on pension';

  @override
  String get eplCombinedOrder3aTitle => 'Pillar 3a withdrawal';

  @override
  String get eplCombinedOrder3aReason =>
      'Reduced tax on withdrawal, limited impact on retirement pension';

  @override
  String get eplCombinedOrderLppTitle => 'LPP withdrawal (EPL)';

  @override
  String get eplCombinedOrderLppReason =>
      'Direct impact on risk benefits (disability, death). Use as a last resort.';

  @override
  String get eplCombinedAttentionPoints => 'Points of attention';

  @override
  String get eplCombinedSource =>
      'Source: LPP art. 30c (EPL), OPP3, LIFD art. 38. Cantonal rates estimated for educational purposes.';

  @override
  String get eplCombinedPriceOfProperty => 'of price';

  @override
  String get imputedRentalAppBarTitle => 'Imputed rental value';

  @override
  String get imputedRentalIntroTitle => 'What is imputed rental value?';

  @override
  String get imputedRentalIntroBody =>
      'In Switzerland, homeowners must declare a fictitious income (imputed rental value) corresponding to the rent they could obtain by renting their property. In return, they can deduct mortgage interest and maintenance costs.';

  @override
  String get imputedRentalDecomposition => 'Breakdown';

  @override
  String get imputedRentalBarLocative => 'Imputed rental';

  @override
  String get imputedRentalBarDeductions => 'Deductions';

  @override
  String get imputedRentalAddedIncome => 'Added taxable income';

  @override
  String get imputedRentalLocativeValue => 'Imputed rental value';

  @override
  String get imputedRentalDeductionsLabel => 'Deductions';

  @override
  String get imputedRentalMortgageInterest => 'Mortgage interest';

  @override
  String get imputedRentalMaintenanceCosts => 'Maintenance costs';

  @override
  String get imputedRentalBuildingInsurance => 'Building insurance (estimate)';

  @override
  String get imputedRentalTotalDeductions => 'Total deductions';

  @override
  String get imputedRentalNetImpact => 'Net impact on taxable income';

  @override
  String imputedRentalFiscalImpact(String rate) {
    return 'Estimated fiscal impact (marginal rate $rate%)';
  }

  @override
  String get imputedRentalParameters => 'Parameters';

  @override
  String get imputedRentalCanton => 'Canton';

  @override
  String get imputedRentalPropertyValue => 'Property market value';

  @override
  String get imputedRentalAnnualInterest => 'Annual mortgage interest';

  @override
  String get imputedRentalEffectiveMaintenance => 'Effective maintenance costs';

  @override
  String get imputedRentalOldProperty => 'Older property (>= 10 years)';

  @override
  String get imputedRentalForfaitOld =>
      'Maintenance allowance: 20% of imputed rental value';

  @override
  String get imputedRentalForfaitNew =>
      'Maintenance allowance: 10% of imputed rental value';

  @override
  String get imputedRentalMarginalRate => 'Estimated marginal rate';

  @override
  String get imputedRentalSource =>
      'Source: LIFD art. 21 para. 1 let. b, art. 32. Cantonal rates estimated for educational purposes.';

  @override
  String get saronVsFixedAppBarTitle => 'SARON vs fixed';

  @override
  String saronVsFixedCumulativeCost(int years) {
    return 'Cumulative cost over $years years';
  }

  @override
  String get saronVsFixedLegendFixed => 'Fixed';

  @override
  String get saronVsFixedLegendSaronStable => 'SARON stable';

  @override
  String get saronVsFixedLegendSaronRise => 'SARON rising';

  @override
  String get saronVsFixedParameters => 'Parameters';

  @override
  String get saronVsFixedMortgageAmount => 'Mortgage amount';

  @override
  String get saronVsFixedDuration => 'Duration';

  @override
  String saronVsFixedYears(int years) {
    return '$years years';
  }

  @override
  String get saronVsFixedCostComparison => 'Cost comparison';

  @override
  String saronVsFixedRate(String rate) {
    return 'Rate: $rate';
  }

  @override
  String get saronVsFixedInsightText =>
      'The SARON rising scenario simulates +0.25%/year for the first 3 years. In reality, the evolution depends on the SNB monetary policy.';

  @override
  String get saronVsFixedSource =>
      'Source: indicative Swiss market rates 2026. Does not constitute mortgage advice.';

  @override
  String get avsCotisationsTitle => 'AVS contributions';

  @override
  String get avsCotisationsHeaderInfo =>
      'As a self-employed person, you pay the full AVS/AI/APG contributions yourself. An employee only pays half (5.3%), the employer covering the rest.';

  @override
  String get avsCotisationsRevenuLabel => 'Your annual net income';

  @override
  String get avsCotisationsSliderMin => 'CHF 0';

  @override
  String get avsCotisationsSliderMax250k => 'CHF 250,000';

  @override
  String avsCotisationsChiffreChocCaption(String amount) {
    return 'As self-employed, you pay $amount/yr more than an employee';
  }

  @override
  String get avsCotisationsTauxEffectif => 'Effective rate';

  @override
  String get avsCotisationsCotisationAn => 'Contribution /yr';

  @override
  String get avsCotisationsCotisationMois => 'Contribution /mo';

  @override
  String get avsCotisationsTranche => 'Bracket';

  @override
  String get avsCotisationsComparaisonTitle => 'Annual comparison';

  @override
  String get avsCotisationsIndependant => 'Self-employed';

  @override
  String get avsCotisationsSalarie => 'Employee (employee share)';

  @override
  String avsCotisationsSurcout(String amount) {
    return 'Self-employed surcharge: +$amount/yr';
  }

  @override
  String get avsCotisationsBaremeTitle => 'Your position on the scale';

  @override
  String avsCotisationsTauxEffectifLabel(String taux) {
    return 'Your effective rate: $taux%';
  }

  @override
  String get avsCotisationsBonASavoir => 'Good to know';

  @override
  String get avsCotisationsEduDegressifTitle => 'Degressive scale';

  @override
  String get avsCotisationsEduDegressifBody =>
      'The rate decreases for low incomes (between CHF 10,100 and CHF 60,500). Above CHF 60,500, the full 10.6% rate applies.';

  @override
  String get avsCotisationsEduDoubleChargeTitle => 'Double burden';

  @override
  String get avsCotisationsEduDoubleChargeBody =>
      'An employee only pays 5.3%; the employer covers the other half. As self-employed, you bear the full cost.';

  @override
  String get avsCotisationsEduMinTitle => 'Minimum contribution';

  @override
  String get avsCotisationsEduMinBody =>
      'Even with very low income, the minimum contribution is CHF 530/yr.';

  @override
  String get avsCotisationsDisclaimer =>
      'Amounts shown are estimates based on the current AVS/AI/APG scale. Actual contributions may vary. Contact your compensation office for exact figures.';

  @override
  String get ijmTitle => 'IJM insurance';

  @override
  String get ijmHeaderInfo =>
      'IJM insurance (daily sickness allowance) compensates your income loss in case of illness. As self-employed, no protection is provided by default: it\'s up to you to get insured.';

  @override
  String get ijmRevenuMensuel => 'Monthly income';

  @override
  String get ijmSliderMinChf0 => 'CHF 0';

  @override
  String get ijmSliderMax20k => 'CHF 20,000';

  @override
  String get ijmTonAge => 'Your age';

  @override
  String get ijmAgeMin => '18 yrs';

  @override
  String get ijmAgeMax => '65 yrs';

  @override
  String get ijmDelaiCarence => 'Waiting period';

  @override
  String get ijmDelaiCarenceDesc =>
      'Period during which you receive no benefits';

  @override
  String get ijmJours => 'days';

  @override
  String ijmChiffreChocCaption(String amount, int jours) {
    return 'Without IJM insurance, you lose $amount during the $jours-day waiting period';
  }

  @override
  String get ijmHighRiskTitle => 'High premiums after 50';

  @override
  String get ijmHighRiskBody =>
      'IJM premiums increase significantly with age. After 50, the cost can be 3 to 4 times higher than for a 30-year-old. Consider a longer waiting period to reduce the premium.';

  @override
  String get ijmPrimeMois => 'Premium /mo';

  @override
  String get ijmPrimeAn => 'Premium /yr';

  @override
  String get ijmIndemniteJour => 'Allowance /day';

  @override
  String get ijmTrancheAge => 'Age bracket';

  @override
  String get ijmTimelineTitle => 'Coverage timeline';

  @override
  String get ijmTimelineCouvert => 'Covered';

  @override
  String get ijmTimelineNoCoverage => 'No coverage';

  @override
  String get ijmTimelineCoverageIjm => 'IJM coverage (80%)';

  @override
  String ijmTimelineSummary(int jours, String amount) {
    return 'During the first $jours days of illness, you have no income. Then you receive $amount/day (80% of your monthly income).';
  }

  @override
  String get ijmStrategies => 'Strategies';

  @override
  String get ijmEduFondsTitle => 'Build a waiting period fund';

  @override
  String get ijmEduFondsBody =>
      'Set aside 3 months of income to cover the waiting period. This allows you to choose a 90-day wait and reduce your premium.';

  @override
  String get ijmEduComparerTitle => 'Compare offers';

  @override
  String get ijmEduComparerBody =>
      'Premiums vary greatly between insurers. Request multiple quotes and compare conditions (exclusions, benefit duration, covered amount).';

  @override
  String get ijmEduLamalTitle => 'Insufficient LAMal coverage';

  @override
  String get ijmEduLamalBody =>
      'LAMal only covers medical costs, not income loss. IJM is essential to protect your income.';

  @override
  String get ijmDisclaimer =>
      'Premiums shown are estimates based on market averages. Actual premiums depend on the insurer, your profession, and health. Request a personalized quote from a specialist.';

  @override
  String ijmJoursCarenceLabel(int jours) {
    return '$jours-day waiting period';
  }

  @override
  String get pillar3aIndepTitle => '3rd pillar self-employed';

  @override
  String get pillar3aIndepHeaderInfo =>
      'As self-employed without LPP, you can access the \"big 3a\": deduct up to 20% of net income (max CHF 36,288/yr), instead of CHF 7,258 for employees. A major tax advantage.';

  @override
  String get pillar3aIndepLppToggle => 'Affiliated to voluntary LPP?';

  @override
  String get pillar3aIndepPlafondPetit => '3a cap: CHF 7,258 (small 3a)';

  @override
  String get pillar3aIndepPlafondGrand =>
      '3a cap: 20% of income, max CHF 36,288 (big 3a)';

  @override
  String get pillar3aIndepRevenuLabel => 'Annual net income';

  @override
  String get pillar3aIndepSliderMax300k => 'CHF 300,000';

  @override
  String get pillar3aIndepTauxLabel => 'Marginal tax rate';

  @override
  String get pillar3aIndepChiffreChocCaption =>
      'annual tax savings thanks to the 3rd pillar';

  @override
  String pillar3aIndepChiffreChocAvantageSalarie(String amount) {
    return 'You save $amount/yr more in taxes than an employee thanks to the big 3a';
  }

  @override
  String get pillar3aIndepPlafondApplicable => 'Applicable cap';

  @override
  String get pillar3aIndepEconomieFiscaleAn => 'Tax savings /yr';

  @override
  String get pillar3aIndepPlafondSalarie => 'Employee cap';

  @override
  String get pillar3aIndepEconomieSalarie => 'Employee savings';

  @override
  String get pillar3aIndepPlafondsCompares => 'Compared caps';

  @override
  String pillar3aIndepSuperPouvoir(int multiplier) {
    return '×$multiplier your superpower';
  }

  @override
  String get pillar3aIndepSalarie => 'Employee';

  @override
  String get pillar3aIndepIndependantToi => 'Self-employed (you)';

  @override
  String get pillar3aIndepGrand3aMax => 'Big 3a (legal max)';

  @override
  String get pillar3aIndepEn20ans => 'In 20 years at 4%';

  @override
  String get pillar3aIndepVs => 'vs';

  @override
  String get pillar3aIndepToi => 'You';

  @override
  String pillar3aIndepDifference(String amount) {
    return 'Difference: +$amount';
  }

  @override
  String get pillar3aIndepBonASavoir => 'Good to know';

  @override
  String get pillar3aIndepEduComptesTitle => 'Open multiple 3a accounts';

  @override
  String get pillar3aIndepEduComptesBody =>
      'Even with the big 3a, the multiple accounts strategy (up to 5) is recommended to optimize staggered withdrawal at retirement.';

  @override
  String get pillar3aIndepEduConditionTitle => 'Condition: no LPP';

  @override
  String get pillar3aIndepEduConditionBody =>
      'The big 3a (20% of income, max 36,288) is only available if you\'re not affiliated to a voluntary LPP. With LPP, the cap drops to 7,258.';

  @override
  String get pillar3aIndepEduInvestirTitle => 'Invest rather than save';

  @override
  String get pillar3aIndepEduInvestirBody =>
      'For a long horizon (>10 years), a 3a invested in equities can offer much higher returns than a classic 3a savings account.';

  @override
  String get pillar3aIndepDisclaimer =>
      'Tax savings are calculated based on the indicated marginal rate. The actual rate depends on your canton, municipality, and family situation. Consult a specialist for a personalized calculation.';

  @override
  String get dividendeVsSalaireTitle => 'Dividend vs Salary';

  @override
  String get dividendeVsSalaireHeaderInfo =>
      'If you own an SA or Sàrl, you can pay yourself a combination of salary and dividends. Dividends are taxed at 50% (qualifying participation) and escape AVS contributions. Find the best-adapted split.';

  @override
  String get dividendeVsSalaireBenefice => 'Total profit';

  @override
  String get dividendeVsSalaireSliderMax500k => 'CHF 500,000';

  @override
  String get dividendeVsSalairePartSalaire => 'Salary share';

  @override
  String get dividendeVsSalaireTauxMarginal => 'Marginal tax rate';

  @override
  String dividendeVsSalaireChiffreChocPositive(String amount) {
    return 'The adapted split saves you $amount/yr compared to 100% salary';
  }

  @override
  String get dividendeVsSalaireChiffreChocNeutral =>
      'Adjust the split to find savings';

  @override
  String get dividendeVsSalaireRequalificationTitle => 'Requalification risk';

  @override
  String get dividendeVsSalaireRequalificationBody =>
      'If the salary share is below ~60% of profit, tax authorities may requalify part of the dividends as salary (varies by canton). This triggers retroactive AVS contributions.';

  @override
  String get dividendeVsSalairePartSalaireLabel => 'Salary share';

  @override
  String get dividendeVsSalairePartDividende => 'Dividend share';

  @override
  String dividendeVsSalairePctBenefice(int pct) {
    return '$pct% of profit';
  }

  @override
  String get dividendeVsSalaireChargeSalaire => 'Salary charge';

  @override
  String get dividendeVsSalaireChargeDividende => 'Dividend charge';

  @override
  String get dividendeVsSalaireChargeTotalSplit => 'Total charge (split)';

  @override
  String get dividendeVsSalaireCharge100Salaire => 'Charge if 100% salary';

  @override
  String get dividendeVsSalaireChartTitle => 'Total charge by split';

  @override
  String get dividendeVsSalairePctSalaire0 => '0% salary';

  @override
  String get dividendeVsSalairePctSalaire100 => '100% salary';

  @override
  String get dividendeVsSalaireChargeTotale => 'Total charge';

  @override
  String get dividendeVsSalaireSplitAdapte => 'Adapted split';

  @override
  String get dividendeVsSalairePositionActuelle => 'Current position';

  @override
  String get dividendeVsSalaireARetenir => 'Key takeaways';

  @override
  String get dividendeVsSalaireEduImpotTitle => 'Profit tax';

  @override
  String get dividendeVsSalaireEduImpotBody =>
      'Remember that profit distributed as dividends is taxed first at the company level (corporate tax), then at the personal level (economic double taxation).';

  @override
  String get dividendeVsSalaireEduAvsTitle => 'AVS only on salary';

  @override
  String get dividendeVsSalaireEduAvsBody =>
      'AVS contributions (about 12.5% total) only apply to the salary portion. Dividends escape social charges, hence the interest in adjusting the split.';

  @override
  String get dividendeVsSalaireEduCantonalTitle => 'Cantonal practice';

  @override
  String get dividendeVsSalaireEduCantonalBody =>
      'Tax authorities monitor excessive dividend distributions. A \"market-conform\" salary is expected. The threshold varies by canton.';

  @override
  String get dividendeVsSalaireDisclaimer =>
      'Simplified simulation. Corporate profit tax, personal deductions, and cantonal rules are not included. Consult a specialist for a complete analysis.';

  @override
  String get dividendeVsSalaireCantonalDisclaimer =>
      'The fiscal impact depends on cantonal practice. Requalification thresholds vary from one canton to another.';

  @override
  String get dividendeVsSalaireComplianceFooter =>
      'Educational tool — does not constitute financial advice (FinSA).';

  @override
  String get dividendeVsSalaireSources =>
      'Sources: LIFD art. 18, 20, 33; CO art. 660';

  @override
  String get lppVolontaireTitle => 'Voluntary LPP';

  @override
  String get lppVolontaireHeaderInfo =>
      'As self-employed, you can voluntarily join a pension fund (LPP). Contributions are fully deductible from taxable income, and you build your 2nd pillar retirement.';

  @override
  String get lppVolontaireRevenuLabel => 'Annual net income';

  @override
  String get lppVolontaireSliderMax250k => 'CHF 250,000';

  @override
  String get lppVolontaireTonAge => 'Your age';

  @override
  String get lppVolontaireAgeMin => '25 yrs';

  @override
  String get lppVolontaireAgeMax => '65 yrs';

  @override
  String get lppVolontaireTauxMarginal => 'Marginal tax rate';

  @override
  String lppVolontaireChiffreChocCaption(String amount) {
    return 'Without voluntary LPP, you lose $amount/yr in retirement capitalization';
  }

  @override
  String get lppVolontaireSalaireCoordonne => 'Coordinated salary';

  @override
  String get lppVolontaireTauxBonification => 'Contribution rate';

  @override
  String get lppVolontaireCotisationAn => 'Contribution /yr';

  @override
  String get lppVolontaireEconomieFiscaleAn => 'Tax savings /yr';

  @override
  String get lppVolontaireTrancheAge => 'Age bracket';

  @override
  String get lppVolontaireProjectionTitle => 'Annual retirement projection';

  @override
  String get lppVolontaireSansLpp => 'Without LPP (AVS only)';

  @override
  String get lppVolontaireAvecLpp => 'With voluntary LPP';

  @override
  String lppVolontaireGapLabel(String amount) {
    return 'Voluntary LPP could add $amount/yr to your retirement pension';
  }

  @override
  String get lppVolontaireBonificationTitle => 'Contribution rate by age';

  @override
  String get lppVolontaireToi => 'YOU';

  @override
  String get lppVolontaireBonASavoir => 'Good to know';

  @override
  String get lppVolontaireEduAffiliationTitle => 'Voluntary affiliation';

  @override
  String get lppVolontaireEduAffiliationBody =>
      'Self-employed persons can voluntarily join a LPP via a collective foundation, industry fund, or cantonal fund.';

  @override
  String get lppVolontaireEduFiscalTitle => 'Double tax advantage';

  @override
  String get lppVolontaireEduFiscalBody =>
      'Voluntary LPP contributions are fully deductible from taxable income. Additionally, LPP capital is not subject to wealth tax.';

  @override
  String get lppVolontaireEduImpact3aTitle => 'Impact on 3a';

  @override
  String get lppVolontaireEduImpact3aBody =>
      'If you join a voluntary LPP, your 3a cap drops from the \"big 3a\" (max CHF 36,288) to the \"small 3a\" (CHF 7,258). Evaluate the trade-off.';

  @override
  String get lppVolontaireDisclaimer =>
      'Pension projections are estimates based on a projected return of 1.5%/yr and a conversion rate of 6.8%. Actual benefits depend on the chosen pension fund and market evolution. Consult a pension specialist.';

  @override
  String lppVolontairePerAn(String amount) {
    return '$amount/yr';
  }

  @override
  String get coverageCheckTitle => 'Coverage check-up';

  @override
  String get coverageCheckAppBarTitle => 'Coverage check-up';

  @override
  String get coverageCheckSubtitle => 'Evaluate your insurance protection';

  @override
  String get coverageCheckDemoMode => 'DEMO MODE';

  @override
  String get coverageCheckTonProfil => 'Your profile';

  @override
  String get coverageCheckStatut => 'Professional status';

  @override
  String get coverageCheckSalarie => 'Employee';

  @override
  String get coverageCheckIndependant => 'Self-employed';

  @override
  String get coverageCheckSansEmploi => 'Unemployed';

  @override
  String get coverageCheckHypotheque => 'Current mortgage';

  @override
  String get coverageCheckPersonnesCharge => 'Dependents';

  @override
  String get coverageCheckLocataire => 'Tenant';

  @override
  String get coverageCheckVoyages => 'Frequent travel';

  @override
  String get coverageCheckCouvertureActuelle => 'My current coverage';

  @override
  String get coverageCheckIjm => 'Collective IJM (employer)';

  @override
  String get coverageCheckLaa => 'LAA (accident insurance)';

  @override
  String get coverageCheckRcPrivee => 'Private liability';

  @override
  String get coverageCheckMenage => 'Household insurance';

  @override
  String get coverageCheckProtJuridique => 'Legal protection';

  @override
  String get coverageCheckVoyage => 'Travel insurance';

  @override
  String get coverageCheckDeces => 'Death insurance';

  @override
  String get coverageCheckScore => 'Coverage score';

  @override
  String coverageCheckLacunes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count critical gaps',
      one: '$count critical gap',
    );
    return '$_temp0';
  }

  @override
  String get coverageCheckAnalyseTitle => 'Detailed analysis';

  @override
  String get coverageCheckRecommandationsTitle => 'Recommendations';

  @override
  String get coverageCheckCouvert => 'Covered';

  @override
  String get coverageCheckNonCouvert => 'Not covered';

  @override
  String get coverageCheckAVerifier => 'To verify';

  @override
  String get coverageCheckCritique => 'Critical';

  @override
  String get coverageCheckHaute => 'High';

  @override
  String get coverageCheckMoyenne => 'Medium';

  @override
  String get coverageCheckBasse => 'Low';

  @override
  String get coverageCheckDisclaimer =>
      'This analysis is indicative and does not constitute personalized insurance advice. Premiums vary by insurer and profile. Consult an insurance specialist for a complete evaluation.';

  @override
  String get coverageCheckSources => 'Sources';

  @override
  String get coverageCheckSourcesBody =>
      'CO art. 41 (liability) / CO art. 324a (employer IJM) / LAA art. 4 (accident insurance) / LAMal art. 34 (foreign coverage) / LCA (death insurance) / Cantonal law (household)';

  @override
  String get coverageCheckSlashHundred => '/ 100';

  @override
  String coverageCheckAnsLabel(int age) {
    return '$age yrs';
  }

  @override
  String get eplAppBarTitle => 'EPL Withdrawal';

  @override
  String get eplIntroTitle => 'EPL Withdrawal — Home ownership';

  @override
  String get eplIntroBody =>
      'EPL lets you use your LPP savings to finance a home purchase, repay a mortgage, or fund renovations. Minimum amount: CHF 20,000. This withdrawal directly impacts your risk benefits.';

  @override
  String get eplSectionParametres => 'Parameters';

  @override
  String get eplLabelAvoirTotal => 'Total LPP savings';

  @override
  String get eplLabelAge => 'Age';

  @override
  String eplLabelAgeFormat(int age) {
    return '$age yrs';
  }

  @override
  String get eplLabelMontantSouhaite => 'Desired amount';

  @override
  String get eplLabelCanton => 'Canton';

  @override
  String get eplLabelRachatsRecents => 'Recent LPP buybacks';

  @override
  String get eplLabelRachatsQuestion =>
      'Have you made a LPP buyback in the last 3 years?';

  @override
  String get eplLabelAnneesSDepuisRachat => 'Years since buyback';

  @override
  String eplLabelAnneesSDepuisRachatFormat(int years, String suffix) {
    return '$years yr$suffix';
  }

  @override
  String get eplSectionResultat => 'Result';

  @override
  String get eplMontantMaxRetirable => 'Maximum withdrawable amount';

  @override
  String get eplMontantApplicable => 'Applicable amount';

  @override
  String get eplRetraitImpossible =>
      'Withdrawal is not possible with the current configuration.';

  @override
  String get eplSectionImpactPrestations => 'Impact on benefits';

  @override
  String get eplReductionInvalidite =>
      'Disability pension reduction (annual estimate)';

  @override
  String get eplReductionDeces => 'Death capital reduction (estimate)';

  @override
  String get eplImpactPrestationsNote =>
      'EPL withdrawal proportionally reduces your risk benefits. Check with your pension fund for exact amounts and supplementary insurance options.';

  @override
  String get eplSectionImpactRente => 'Impact on pension';

  @override
  String get eplRenteSansEpl => 'Pension without EPL';

  @override
  String get eplRenteAvecEpl => 'Pension with EPL';

  @override
  String get eplPerteMensuelle => 'Monthly loss';

  @override
  String get eplImpactRenteNote =>
      'Educational estimate based on CHF 100,000 salary, 2% fund return, 6.8% conversion rate. Actual amount depends on your situation.';

  @override
  String get eplSectionFiscale => 'Tax estimate';

  @override
  String get eplMontantRetire => 'Amount withdrawn';

  @override
  String get eplImpotEstime => 'Estimated withdrawal tax';

  @override
  String get eplMontantNet => 'Net amount after tax';

  @override
  String get eplFiscaleNote =>
      'Capital withdrawal is taxed at a reduced rate (about 1/5 of the ordinary scale). The exact rate depends on canton, municipality and personal situation.';

  @override
  String get eplSectionPointsAttention => 'Points of attention';

  @override
  String get librePassageAppBarTitle => 'Vested benefits';

  @override
  String get librePassageSectionSituation => 'Situation';

  @override
  String get librePassageChipChangementEmploi => 'Job change';

  @override
  String get librePassageChipDepartSuisse => 'Leaving Switzerland';

  @override
  String get librePassageChipCessationActivite => 'Cessation of activity';

  @override
  String get librePassageSectionProfil => 'Your profile';

  @override
  String get librePassageLabelAge => 'Your age';

  @override
  String librePassageLabelAgeFormat(int age) {
    return '$age yrs';
  }

  @override
  String get librePassageLabelAvoir => 'Vested benefits amount';

  @override
  String get librePassageLabelNouvelEmployeur => 'New employer';

  @override
  String get librePassageLabelNouvelEmployeurQuestion =>
      'Do you already have a new employer?';

  @override
  String get librePassageSectionAlertes => 'Alerts';

  @override
  String get librePassageSectionChecklist => 'Checklist';

  @override
  String get librePassageUrgenceCritique => 'Critical';

  @override
  String get librePassageUrgenceHaute => 'High';

  @override
  String get librePassageUrgenceMoyenne => 'Medium';

  @override
  String get librePassageSectionRecommandations => 'Recommendations';

  @override
  String get librePassageCentrale2eTitle =>
      '2nd pillar central office (sfbvg.ch)';

  @override
  String get librePassageCentrale2eSubtitle =>
      'Search for forgotten vested benefits';

  @override
  String get librePassagePrivacyNote =>
      'Your data stays on your device. No information is transmitted to third parties. Compliant with nDPA.';

  @override
  String get providerComparatorAppBarTitle => '3a Comparator';

  @override
  String providerComparatorChiffreChocLabel(int duree) {
    return 'Difference over $duree years';
  }

  @override
  String get providerComparatorChiffreChocSubtitle =>
      'between the best and worst performing provider';

  @override
  String get providerComparatorSectionParametres => 'Parameters';

  @override
  String get providerComparatorLabelAge => 'Age';

  @override
  String providerComparatorLabelAgeFormat(int age) {
    return '$age yrs';
  }

  @override
  String get providerComparatorLabelVersement => 'Annual contribution';

  @override
  String get providerComparatorLabelDuree => 'Duration';

  @override
  String providerComparatorLabelDureeFormat(int duree) {
    return '$duree yrs';
  }

  @override
  String get providerComparatorLabelProfilRisque => 'Risk profile';

  @override
  String get providerComparatorProfilPrudent => 'Prudent';

  @override
  String get providerComparatorProfilEquilibre => 'Balanced';

  @override
  String get providerComparatorProfilDynamique => 'Dynamic';

  @override
  String get providerComparatorSectionComparaison => 'Comparison';

  @override
  String get providerComparatorRendement => 'Return';

  @override
  String get providerComparatorFrais => 'Fees';

  @override
  String get providerComparatorCapitalFinal => 'Final capital';

  @override
  String get providerComparatorWarningLabel => 'Warning';

  @override
  String providerComparatorDiffVsPremier(String amount) {
    return '-CHF $amount vs first';
  }

  @override
  String get providerComparatorAssuranceTitle => 'Warning — Insurance 3a';

  @override
  String get providerComparatorAssuranceNote =>
      'Insurance 3a products combine savings and risk coverage, but high fees (often > 1.5%) and contract rigidity make them unfavorable for young savers.';

  @override
  String documentDetailFieldsExtracted(int found, int total) {
    return '$found fields extracted out of $total';
  }

  @override
  String get documentDetailProfileUpdated => 'Profile updated successfully';

  @override
  String get documentDetailCancelButton => 'Cancel';

  @override
  String get portfolioTitle => 'My portfolio';

  @override
  String get portfolioNetWorth => 'Total net worth';

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
  String get timelineTitle => 'My journey';

  @override
  String get timelineHeader => 'Your financial life,\nstep by step.';

  @override
  String get timelineSubheader =>
      'Essential tools and life events — everything is here.';

  @override
  String get timelineSectionTitle => 'Life events';

  @override
  String get timelineSectionSubtitle =>
      'Select an event to simulate its financial impact.';

  @override
  String get confidenceDashboardTitle => 'Profile accuracy';

  @override
  String get confidenceDetailByAxis => 'Detail by axis';

  @override
  String get confidenceFeatureGates => 'Unlocked features';

  @override
  String get confidenceImprove => 'Improve your accuracy';

  @override
  String confidenceRequired(int percent) {
    return '$percent% required';
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
  String get confidenceSources => 'Sources';

  @override
  String get cockpitDetailTitle => 'Detailed cockpit';

  @override
  String get cockpitEmptyMsg =>
      'Complete your profile to access the detailed cockpit.';

  @override
  String get cockpitEnrichCta => 'Enrich my profile';

  @override
  String get cockpitDisclaimer =>
      'Simplified educational tool. Not financial advice (FinSA). Sources: OASI art. 21-29, BVG art. 14, BVV3 art. 7.';

  @override
  String get annualRefreshTitle => 'Annual check-up';

  @override
  String get annualRefreshIntro =>
      'A few quick questions to update your profile.';

  @override
  String get annualRefreshSubmit => 'Update my profile';

  @override
  String get annualRefreshResult => 'Profile updated!';

  @override
  String get annualRefreshDashboard => 'Back to dashboard';

  @override
  String get annualRefreshDisclaimer =>
      'This tool is for educational purposes and does not constitute financial advice within the meaning of FinSA. Consult a specialist for personalised advice.';

  @override
  String get acceptInvitationTitle => 'Join a household';

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
  String get financialReportTitle => 'Your Mint Plan';

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
  String get capKindComplete => 'Complete';

  @override
  String get capKindCorrect => 'Correct';

  @override
  String get capKindOptimize => 'Optimize';

  @override
  String get capKindSecure => 'Secure';

  @override
  String get capKindPrepare => 'Prepare';

  @override
  String get proofSheetSources => 'Sources';

  @override
  String get pulseFeedbackRecalculated => 'Impact recalculated';

  @override
  String get pulseFeedbackAddedRecently => 'Added recently';

  @override
  String get debtRatioTitle => 'Debt diagnostic';

  @override
  String get debtRatioSubLabel => 'Debt / income ratio';

  @override
  String get debtRatioRefineLabel => 'Refine the diagnostic';

  @override
  String get debtRatioMinVital => 'Minimum subsistence (LP art. 93)';

  @override
  String get debtRatioRecommandations => 'Recommendations';

  @override
  String get debtRatioCtaRouge => 'Create your repayment plan';

  @override
  String get debtRatioCtaOrange => 'Optimise your repayments';

  @override
  String get debtRatioAidePro => 'Professional help';

  @override
  String get repaymentTitle => 'Repayment plan';

  @override
  String get repaymentLibereDans => 'Debt-free in';

  @override
  String get repaymentMesDettes => 'My debts';

  @override
  String get repaymentBudgetLabel => 'Repayment budget';

  @override
  String get repaymentComparaisonStrategies => 'Strategy comparison';

  @override
  String get repaymentStrategyNote =>
      'The choice depends on your financial personality, not just the cost.';

  @override
  String get repaymentTimelineTitle => 'Timeline (Avalanche)';

  @override
  String get repaymentTimelineMois => 'Month';

  @override
  String get repaymentTimelinePaiement => 'Payment';

  @override
  String get repaymentTimelineSolde => 'Remaining balance';

  @override
  String get retroactive3aTitle => '3a catch-up';

  @override
  String get retroactive3aHeroTitle => '3a catch-up — New in 2026';

  @override
  String get retroactive3aHeroSubtitle =>
      'Catch up on up to 10 years of missed contributions';

  @override
  String get retroactive3aParametres => 'Parameters';

  @override
  String get retroactive3aAnneesARattraper => 'Years to catch up';

  @override
  String get retroactive3aTauxMarginal => 'Marginal tax rate';

  @override
  String get retroactive3aAffilieLpp => 'Affiliated with a pension fund (LPP)';

  @override
  String get retroactive3aPetit3a => 'Small 3a : CHF 7’258/year';

  @override
  String get retroactive3aGrand3a =>
      'Large 3a : 20 % of net income, max CHF 36’288/year';

  @override
  String get retroactive3aEconomiesFiscales => 'Estimated tax savings';

  @override
  String get retroactive3aDetailParAnnee => 'Breakdown by year';

  @override
  String get retroactive3aHeaderAnnee => 'Year';

  @override
  String get retroactive3aHeaderPlafond => 'Ceiling';

  @override
  String get retroactive3aHeaderDeductible => 'Deductible';

  @override
  String get retroactive3aTotal => 'Total';

  @override
  String get retroactive3aAnneeCourante => 'Current year';

  @override
  String get retroactive3aImpactAvantApres => 'Before / after impact';

  @override
  String get retroactive3aSansRattrapage => 'Without catch-up';

  @override
  String get retroactive3aAnneeCouranteSeule => 'Current year only';

  @override
  String get retroactive3aAvecRattrapage => 'With catch-up';

  @override
  String get retroactive3aEconomieFiscale => 'in tax savings';

  @override
  String get retroactive3aProchainesEtapes => 'Next steps';

  @override
  String get retroactive3aOuvrirCompte => 'Open a 3a account';

  @override
  String get retroactive3aOuvrirCompteSubtitle =>
      'Compare providers and open a dedicated catch-up account.';

  @override
  String get retroactive3aPrepDocuments => 'Prepare documents';

  @override
  String get retroactive3aPrepDocumentsSubtitle =>
      'Salary certificate, AVS contribution statement, proof of absence of 3a for each year.';

  @override
  String get retroactive3aConsulterSpecialiste => 'Consult a specialist';

  @override
  String get retroactive3aConsulterSpecialisteSubtitle =>
      'A tax expert can confirm your marginal rate and optimise the payment schedule.';

  @override
  String get retroactive3aSources => 'Sources';

  @override
  String coverageCriticalGaps(Object count) {
    return 'critical gap$count';
  }

  @override
  String get coverageCriticalGapSingular => 'critical gap';

  @override
  String get coverageCriticalGapPlural => 'critical gaps';

  @override
  String get reportTonPlanMint => 'Your Mint Plan';

  @override
  String get reportCommencer => 'Get started';

  @override
  String get reportOptimise3a => 'Optimize your 3a';

  @override
  String get reportActions => '🎯 Your 3 Priority Actions';

  @override
  String get reportMentionLegale => 'Legal notice';

  @override
  String get reportDisclaimerText =>
      'Educational tool — does not constitute financial advice under FinSA. Amounts are estimates based on declared data.';

  @override
  String get compoundTitle => 'Compound Interest';

  @override
  String get compoundMentorTitle => 'Mentor\'s view';

  @override
  String get compoundMentorIntro => 'Understanding ';

  @override
  String get compoundMentorOutro =>
      ' means understanding how your money works for you while you sleep.';

  @override
  String get compoundConfiguration => 'Configuration';

  @override
  String get compoundCapitalDepart => 'Starting capital';

  @override
  String get compoundEpargneMensuelle => 'Monthly savings';

  @override
  String get compoundTauxRendement => 'Rate (Annual return)';

  @override
  String get compoundHorizonTemps => 'Time horizon';

  @override
  String get compoundValeurFinale => 'Potential Final Value';

  @override
  String compoundGainsPercent(String percent) {
    return '$percent% of this amount comes purely from your investment gains.';
  }

  @override
  String get compoundLeconsTitle => 'Key Lessons';

  @override
  String get compoundTempsRoi => 'Time is king';

  @override
  String get compoundTempsRoiBody =>
      'Waiting 5 years before starting can cost you half your final capital.';

  @override
  String get compoundEffetLevier => 'The leverage effect';

  @override
  String get compoundEffetLevierBody =>
      'Once started, your capital generates its own interest, which in turn generates more.';

  @override
  String get compoundDiscipline => 'Discipline';

  @override
  String get compoundDisciplineBody =>
      'Regular monthly contributions are often more effective than trying to time the market.';

  @override
  String get compoundDisclaimer =>
      'Theoretical calculation based on a constant return. Past performance does not guarantee future results.';

  @override
  String get leasingTitle => 'Anti-Leasing Analysis';

  @override
  String get leasingMentorTitle => 'Mentor\'s reflection';

  @override
  String get leasingMentorBody =>
      'Leasing is often a capital \"leak\". This money could build your wealth instead of financing vehicle depreciation.';

  @override
  String get leasingDonneesContrat => 'Contract Details';

  @override
  String get leasingMensualitePrevue => 'Planned monthly payment';

  @override
  String get leasingDuree => 'Leasing duration';

  @override
  String get leasingRendementAlternatif => 'Expected alternative return';

  @override
  String get leasingCoutOpportunite20 => 'Opportunity cost over 20 years';

  @override
  String get leasingInvestirAuLieu =>
      'If you invested this payment instead of paying a lease, this is the capital you would have built.';

  @override
  String leasingFondsPropres(String amount) {
    return 'That\'s approximately $amount in equity for a property purchase.';
  }

  @override
  String get leasingAlternativesTitle => 'Escaping the Black Hole';

  @override
  String get leasingOccasion => 'Quality Used Car';

  @override
  String get leasingOccasionBody =>
      'Buying a 3-4 year old car in cash drastically reduces value loss.';

  @override
  String get leasingAboGeneral => 'Transit Pass / Public Transport';

  @override
  String get leasingAboGeneralBody =>
      'Train comfort in Switzerland is often more cost-effective and stress-free.';

  @override
  String get leasingMobility => 'Mobility / Car Sharing';

  @override
  String get leasingMobilityBody =>
      'Pay only when you drive. No insurance, no maintenance, no lease.';

  @override
  String get leasingDisclaimer =>
      'Leasing remains an option for some professionals. This analysis aims to raise awareness about long-term costs.';

  @override
  String get creditTitle => 'Consumer Credit';

  @override
  String get creditMentorTitle => 'Mentor\'s attention points';

  @override
  String get creditMentorBody =>
      'In Switzerland, credit costs between 4% and 10%. This money \"lost\" in interest could be invested for your future.';

  @override
  String get creditParametres => 'Parameters';

  @override
  String get creditMontantEmprunter => 'Amount to borrow';

  @override
  String get creditDureeRemboursement => 'Repayment duration';

  @override
  String get creditTauxAnnuel => 'Annual effective rate';

  @override
  String get creditTaMensualite => 'Your Monthly Payment';

  @override
  String get creditCoutInterets => 'Interest cost:';

  @override
  String get creditRateWarning =>
      'Warning: This rate exceeds the Swiss legal maximum of 10%.';

  @override
  String get creditConseilsTitle => 'Mentor\'s Advice';

  @override
  String get creditEpargnerDabord => 'Save first';

  @override
  String creditEpargnerDabordBody(String amount) {
    return 'By saving for 12 months instead of borrowing, you keep $amount in your pocket.';
  }

  @override
  String get creditCercleConfiance => 'Circle of trust';

  @override
  String get creditCercleConfianceBody =>
      'A family loan can often be obtained at 0% interest.';

  @override
  String get creditDettesConseils => 'Debt Counseling Switzerland';

  @override
  String get creditDettesConseilsBody =>
      'Contact them BEFORE signing if your situation is fragile.';

  @override
  String get creditDisclaimer =>
      'Preventive information. Does not constitute legal or financial advice. Swiss Consumer Credit Act (CCA) applied.';

  @override
  String get arbitrageBilanTitle => 'Arbitrage Overview';

  @override
  String get arbitrageBilanEmptyProfile =>
      'Complete your profile to see your arbitrage options';

  @override
  String get arbitrageBilanLeviers => 'Your levers of action';

  @override
  String arbitrageBilanPotentiel(String amount) {
    return '$amount/month of identified potential';
  }

  @override
  String get arbitrageBilanCaveat =>
      'These options don\'t necessarily add up — some are linked to each other.';

  @override
  String get arbitrageBilanDebloquer => 'Unlock more options';

  @override
  String get arbitrageBilanLiens => 'Links between these options';

  @override
  String get arbitrageBilanScenario =>
      'In this simulated scenario — to explore in detail';

  @override
  String get arbitrageBilanDisclaimer =>
      'Educational tool — does not constitute financial advice (FinSA). Sources: LPP art. 14, 79b / LIFD art. 22, 33, 38 / OPP3 art. 7.';

  @override
  String get arbitrageBilanCrossDep1 =>
      'If you withdraw your LPP as capital, the withdrawal schedule changes fundamentally.';

  @override
  String get arbitrageBilanCrossDep2 =>
      'An LPP buyback also increases the capital available for the annuity vs capital choice.';

  @override
  String get annualRefreshSubtitle =>
      'A few quick questions to update your profile.';

  @override
  String get annualRefreshQ1 => 'Has your gross monthly salary changed?';

  @override
  String get annualRefreshQ2 => 'Your professional situation';

  @override
  String get annualRefreshQ3 => 'Your current LPP savings';

  @override
  String get annualRefreshQ3Help =>
      'Check your pension certificate (you receive it every January)';

  @override
  String get annualRefreshQ4 => 'Your approximate 3a balance';

  @override
  String get annualRefreshQ4Help =>
      'Log in to your 3a app to see the exact balance';

  @override
  String get annualRefreshQ5 => 'Any real estate project in sight?';

  @override
  String get annualRefreshQ6 => 'Any family change this year?';

  @override
  String get annualRefreshQ7 => 'Your risk tolerance';

  @override
  String annualRefreshScoreUp(int delta) {
    return 'Your score increased by $delta points!';
  }

  @override
  String annualRefreshScoreDown(int delta) {
    return 'Your score dropped by $delta points — let’s review together';
  }

  @override
  String get annualRefreshScoreStable => 'Your score is stable — keep it up!';

  @override
  String get annualRefreshRetour => 'Back to dashboard';

  @override
  String get annualRefreshAvant => 'Before';

  @override
  String get annualRefreshApres => 'After';

  @override
  String get annualRefreshMontantPositif => 'The amount must be positive';

  @override
  String get annualRefreshMemeEmploi => 'Same job';

  @override
  String get annualRefreshNouvelEmploi => 'New job';

  @override
  String get annualRefreshIndependant => 'Self-employed';

  @override
  String get annualRefreshSansEmploi => 'Unemployed';

  @override
  String get annualRefreshAucun => 'None';

  @override
  String get annualRefreshAchat => 'Purchase';

  @override
  String get annualRefreshVente => 'Sale';

  @override
  String get annualRefreshRefinancement => 'Refinancing';

  @override
  String get annualRefreshMariage => 'Marriage';

  @override
  String get annualRefreshNaissance => 'Birth';

  @override
  String get annualRefreshDivorce => 'Divorce';

  @override
  String get annualRefreshDeces => 'Death';

  @override
  String get annualRefreshConservateur => 'Conservative';

  @override
  String get annualRefreshModere => 'Moderate';

  @override
  String get annualRefreshAgressif => 'Aggressive';

  @override
  String get themeInconnu => 'Unknown theme';

  @override
  String get themeInconnuBody => 'This theme does not exist. Going back.';

  @override
  String get acceptInvitationVoirMenage => 'View my household';

  @override
  String get helpResourceSiteWeb => 'Website';

  @override
  String get locationProjetImmobilier => 'Your real estate project';

  @override
  String get locationCapitalDispo => 'Available capital / equity (CHF)';

  @override
  String get locationLoyerMensuel => 'Current monthly rent (CHF)';

  @override
  String get locationPrixBien => 'Property price (CHF)';

  @override
  String get locationCanton => 'Canton';

  @override
  String get locationMarie => 'Married';

  @override
  String get locationComparer => 'Compare trajectories';

  @override
  String get locationLouerOuAcheter => 'Rent or buy?';

  @override
  String get locationTrajectoires => 'Compared trajectories';

  @override
  String get locationToucheGraphique =>
      'Touch the chart to see values for each year.';

  @override
  String get locationCapaciteFinma => 'Financial capacity check (FINMA)';

  @override
  String locationChargeTheorique(String amount) {
    return 'Annual theoretical charge: $amount (theoretical rate 5% + amortization 1% + maintenance 1%). Banks require this charge not to exceed 1/3 of your gross annual income.';
  }

  @override
  String locationRevenuMinimum(String amount) {
    return 'Minimum gross income required: $amount';
  }

  @override
  String get locationHypotheses => 'Assumptions used';

  @override
  String get locationRendementMarche => 'Market return';

  @override
  String get locationAppreciationImmo => 'Real estate appreciation';

  @override
  String get locationTauxHypo => 'Mortgage rate';

  @override
  String get locationHorizon => 'Horizon';

  @override
  String get locationValeursProfil => 'Values pre-filled from your profile';

  @override
  String get locationAvertissement => 'Warning';

  @override
  String reportBonjour(String name) {
    return 'Hello $name!';
  }

  @override
  String reportProfileSummary(int age, String canton, String civilStatus) {
    return '$age years old • $canton • $civilStatus';
  }

  @override
  String get reportStatusGood => 'Your foundation is solid, keep it up!';

  @override
  String get reportStatusMedium => 'A few adjustments to feel at ease';

  @override
  String get reportStatusLow => 'Priority: stabilise your situation';

  @override
  String get reportReasonDebt => 'Active consumer debt.';

  @override
  String get reportReasonLeasing => 'Active leasing with monthly charge.';

  @override
  String reportReasonPayments(String amount) {
    return 'Debt repayments: CHF $amount / month.';
  }

  @override
  String get reportReasonEmergency =>
      'Emergency fund insufficient (< 3 months).';

  @override
  String get reportReasonFragility =>
      'Fragility signal detected: priority is budget stability.';

  @override
  String get reportBudgetTitle => 'Your Budget';

  @override
  String get reportBudgetKeyLabel => 'Disposable income (after fixed costs)';

  @override
  String get reportBudgetAction => 'Set up my envelopes';

  @override
  String get reportProtectionTitle => 'Your Protection';

  @override
  String get reportProtectionKeyLabel => 'Emergency fund (target: 6 months)';

  @override
  String get reportProtectionSource =>
      'Source: LP art. 93 — Minimum subsistence';

  @override
  String get reportProtectionAction => 'Build my emergency fund';

  @override
  String get reportRetirementTitle => 'Your Retirement';

  @override
  String get reportRetirementKeyLabel => 'Estimated income at 65';

  @override
  String get reportRetirementSource => 'Sources: LPP art. 14, OPP3, LAVS';

  @override
  String get reportRetirement3aNone =>
      'No 3a yet — up to CHF 7’258/year in tax deductions possible';

  @override
  String get reportRetirement3aOne =>
      '1 pillar 3a account — open a 2nd to optimise withdrawal';

  @override
  String reportRetirement3aMulti(int count) {
    return '$count pillar 3a accounts — good diversification';
  }

  @override
  String reportRetirementLppText(String available, String savings) {
    return 'LPP buyback available: CHF $available — estimated tax saving: CHF $savings';
  }

  @override
  String get reportTaxTitle => 'Your Taxes';

  @override
  String reportTaxKeyLabel(String rate) {
    return 'Estimated taxes (effective rate: $rate%)';
  }

  @override
  String get reportTaxAction => 'Compare 26 cantons';

  @override
  String get reportTaxSource => 'Source: LIFD art. 33';

  @override
  String get reportTaxIncome => 'Taxable income';

  @override
  String get reportTaxDeductions => 'Deductions';

  @override
  String get reportTaxEstimated => 'Estimated taxes';

  @override
  String reportTaxSavings(String amount) {
    return 'Potential saving with LPP buyback: CHF $amount/year';
  }

  @override
  String get reportSafeModePriority => 'Priority: debt reduction';

  @override
  String get reportSafeModeActions =>
      'Your priority actions are replaced by a debt reduction plan. Stabilise your situation before exploring recommendations.';

  @override
  String get reportSafeMode3a =>
      'The 3a comparator is disabled while you have active debts. Repaying debts takes priority over any 3a savings.';

  @override
  String get reportSafeModeLpp => 'LPP buyback blocked';

  @override
  String get reportSafeModeLppMessage =>
      'LPP buyback is disabled in protection mode. Repay your debts before locking liquidity in pension savings.';

  @override
  String get reportLppTitle => '💰 LPP Buyback Strategy';

  @override
  String reportLppEconomie(String amount) {
    return 'Total tax saving: CHF $amount';
  }

  @override
  String reportLppYear(int year) {
    return 'Year $year';
  }

  @override
  String reportLppBuyback(String amount) {
    return 'Buyback: CHF $amount';
  }

  @override
  String reportLppSaving(String amount) {
    return 'Saving: CHF $amount';
  }

  @override
  String get reportLppHowTitle => 'How does it work?';

  @override
  String get reportLppHowBody =>
      'Understand why spreading your LPP buybacks saves you thousands of additional francs.';

  @override
  String get reportSoaTitle => 'Transparency and compliance';

  @override
  String get reportSoaNature => 'Nature of service';

  @override
  String reportSoaEduPhases(int count) {
    return 'Financial education — $count phases identified';
  }

  @override
  String get reportSoaEduSimple => 'Personalised financial education';

  @override
  String get reportSoaHypotheses => 'Working assumptions';

  @override
  String get reportSoaHyp1 => 'Declared income stable over the period';

  @override
  String get reportSoaHyp2 => 'Mandatory LPP conversion rate: 6.8%';

  @override
  String get reportSoaHyp3 => 'Pillar 3a cap (employed): CHF 7’258/year';

  @override
  String get reportSoaHyp4 => 'Maximum AVS pension: CHF 30’240/year';

  @override
  String get reportSoaConflicts => 'Conflicts of interest';

  @override
  String get reportSoaNoConflict =>
      'No conflict of interest identified for this report.';

  @override
  String get reportSoaNoCommission =>
      'MINT receives no commission on the products mentioned.';

  @override
  String get reportSoaLimitations => 'Limitations';

  @override
  String get reportSoaLim1 => 'Based on declared information only';

  @override
  String get reportSoaLim2 =>
      'Approximate tax estimate (average cantonal rates)';

  @override
  String get reportSoaLim3 => 'Does not account for movable asset income';

  @override
  String get reportSoaLim4 => 'Projections do not account for inflation';

  @override
  String get checkinEvolution => 'Your evolution';

  @override
  String get portfolioReadinessTitle => 'Readiness Index (Milestones)';

  @override
  String get portfolioPerennite => 'Retirement Sustainability';

  @override
  String get portfolioProjetImmo => 'Real Estate Project';

  @override
  String get portfolioProtectionFamille => 'Family Protection';

  @override
  String get portfolioAllocationSaine =>
      'Your allocation is healthy. Consider rebalancing your 3a soon.';

  @override
  String get portfolioAlerteDettes =>
      'Debt Alert: Your top priority is debt repayment before any reinvestment.';

  @override
  String get dividendeSplitMin => '0% salary';

  @override
  String get dividendeSplitMax => '100% salary';

  @override
  String get disabilityInsAppBarTitle => 'My coverage';

  @override
  String get disabilityInsTitle => 'My disability coverage';

  @override
  String get disabilityInsSubtitle =>
      'Coverage report · LAMal deductible · AI/APG';

  @override
  String get disabilityInsRefineSituation => 'Refine your situation';

  @override
  String get disabilityInsGrossSalary => 'Gross monthly salary';

  @override
  String get disabilityInsSavings => 'Available savings';

  @override
  String get disabilityInsIjmEmployer =>
      'Loss of earnings insurance via employer';

  @override
  String get disabilityInsPrivateLossInsurance =>
      'Private loss of earnings insurance';

  @override
  String get disabilityInsDisclaimer =>
      'Educational tool — does not constitute insurance advice. Deductible and premium amounts are indicative. Compare offers at comparaison.ch or via an independent broker.';

  @override
  String get disabilityInsSources =>
      '• LAMal art. 64-64a (deductible)\n• OAMal art. 93 (premiums)\n• LAI art. 28 (disability pension)\n• LPP art. 23-26 (disability 2nd pillar)';

  @override
  String repaymentDiffStrategies(String amount) {
    return 'Difference between strategies: CHF $amount';
  }

  @override
  String get repaymentAddDebtHint =>
      'Add your debts to generate a repayment plan.';

  @override
  String get repaymentAddDebtTooltip => 'Add a debt';

  @override
  String get repaymentDebtNameHint => 'Debt name';

  @override
  String get repaymentFieldAmount => 'Amount';

  @override
  String get repaymentFieldAmountLabel => 'Debt amount';

  @override
  String get repaymentFieldRate => 'Rate';

  @override
  String get repaymentFieldRateLabel => 'Annual rate';

  @override
  String get repaymentFieldInstallment => 'Installment';

  @override
  String get repaymentFieldInstallmentLabel => 'Minimum installment';

  @override
  String get repaymentNewDebt => 'New debt';

  @override
  String get repaymentBudgetEditorLabel => 'Monthly repayment budget';

  @override
  String repaymentBudgetDisplay(String amount) {
    return 'CHF $amount / month';
  }

  @override
  String get repaymentAvalancheTitle => 'AVALANCHE';

  @override
  String get repaymentAvalancheSubtitle => 'Highest rate first';

  @override
  String get repaymentAvalanchePro => 'Less interest paid';

  @override
  String get repaymentSnowballTitle => 'SNOWBALL';

  @override
  String get repaymentSnowballSubtitle => 'Smallest balance first';

  @override
  String get repaymentSnowballPro => 'Motivated by small wins';

  @override
  String get repaymentRowLiberation => 'Liberation date';

  @override
  String get repaymentRowInterets => 'Total interest';

  @override
  String repaymentDifference(String amount) {
    return 'Difference: CHF $amount';
  }

  @override
  String get repaymentValidate => 'Confirm';

  @override
  String get repaymentEmptyState =>
      'Add your debts and set your monthly repayment budget to see the plan.';

  @override
  String repaymentMinMax(String minVal, String maxVal) {
    return 'Min $minVal · Max $maxVal';
  }

  @override
  String repaymentInteretsDisplay(String amount) {
    return 'CHF $amount interest';
  }

  @override
  String repaymentDurationDisplay(int months) {
    return '$months months';
  }

  @override
  String get debtRatioLevelSain => 'HEALTHY';

  @override
  String get debtRatioLevelAttention => 'ATTENTION';

  @override
  String get debtRatioLevelCritique => 'CRITICAL';

  @override
  String get debtRatioRevenuNet => 'Net income';

  @override
  String get debtRatioChargesDette => 'Debt charges';

  @override
  String get debtRatioLoyer => 'Rent';

  @override
  String get debtRatioAutresCharges => 'Other charges';

  @override
  String get debtRatioRefineSuffix => 'Rent, situation, children';

  @override
  String get debtRatioSituation => 'Situation';

  @override
  String get debtRatioSeul => 'Single';

  @override
  String get debtRatioEnCouple => 'As a couple';

  @override
  String get debtRatioEnfants => 'Children';

  @override
  String get debtRatioMinimumVitalLabel => 'Vital minimum';

  @override
  String get debtRatioMargeDisponible => 'Available margin';

  @override
  String get debtRatioMinVitalWarning =>
      'Your residual margin is below the vital minimum. Contact a professional support service.';

  @override
  String get debtRatioCtaSemantics => 'Create a repayment plan';

  @override
  String get debtRatioCtaDescription =>
      'Compare avalanche and snowball strategies to repay faster.';

  @override
  String get debtRatioDetteConseilNom => 'Dettes Conseils Suisse';

  @override
  String get debtRatioDetteConseilDesc => 'Free and confidential advice';

  @override
  String get debtRatioCaritasNom => 'Caritas — Debt assistance';

  @override
  String get debtRatioCaritasDesc => 'Debt relief assistance and negotiation';

  @override
  String get debtRatioValidate => 'Confirm';

  @override
  String debtRatioMinMaxDisplay(String minVal, String maxVal) {
    return 'Min $minVal · Max $maxVal';
  }

  @override
  String get timelineCatFamille => 'FAMILY';

  @override
  String get timelineCatProfessionnel => 'PROFESSIONAL';

  @override
  String get timelineCatPatrimoine => 'ASSETS';

  @override
  String get timelineCatSante => 'HEALTH';

  @override
  String get timelineCatMobilite => 'MOBILITY';

  @override
  String get timelineCatCrise => 'CRISIS';

  @override
  String get timelineSectionTitleUpper => 'LIFE EVENTS';

  @override
  String get timelineEventMariageTitle => 'Marriage';

  @override
  String get timelineEventMariageSub =>
      'Impact on LPP, AVS, taxes and marital regime';

  @override
  String get timelineEventConcubinageTitle => 'Cohabitation';

  @override
  String get timelineEventConcubitageSub =>
      'Pension, succession and taxation for unmarried couples';

  @override
  String get timelineEventNaissanceTitle => 'Birth';

  @override
  String get timelineEventNaissanceSub =>
      'Allowances, tax deductions and insurance';

  @override
  String get timelineEventDivorceTitle => 'Divorce';

  @override
  String get timelineEventDivorceSub =>
      'LPP split, alimony and financial reorganisation';

  @override
  String get timelineEventSuccessionTitle => 'Succession';

  @override
  String get timelineEventSuccessionSub =>
      'Statutory shares, distribution and taxes (CC art. 457ss)';

  @override
  String get timelineEventPremierEmploiTitle => 'First job';

  @override
  String get timelineEventPremierEmploiSub =>
      'First steps : AVS, LPP, 3a and budget';

  @override
  String get timelineEventChangementEmploiTitle => 'Job change';

  @override
  String get timelineEventChangementEmploiSub =>
      'LPP comparison, vested benefits and negotiation';

  @override
  String get timelineEventIndependantTitle => 'Self-employed';

  @override
  String get timelineEventIndependantSub =>
      'AVS, voluntary LPP, extended 3a and dividend vs salary';

  @override
  String get timelineEventPerteEmploiTitle => 'Job loss';

  @override
  String get timelineEventPerteEmploiSub =>
      'Unemployment, waiting period and pension protection';

  @override
  String get timelineEventRetraiteTitle => 'Retirement';

  @override
  String get timelineEventRetraiteSub =>
      'Pension vs capital, 3a staggering, AVS gap';

  @override
  String get timelineEventAchatImmoTitle => 'Property purchase';

  @override
  String get timelineEventAchatImmoSub =>
      'Borrowing capacity, EPL and imputed rental value tax';

  @override
  String get timelineEventVenteImmoTitle => 'Property sale';

  @override
  String get timelineEventVenteImmoSub =>
      'Capital gain, cantonal tax and reinvestment';

  @override
  String get timelineEventHeritageTitle => 'Inheritance';

  @override
  String get timelineEventHeritageSub =>
      'Valuation, cantonal tax and estate distribution';

  @override
  String get timelineEventDonationTitle => 'Gift';

  @override
  String get timelineEventDonationSub =>
      'Cantonal tax, reserves and available portion';

  @override
  String get timelineEventInvaliditeTitle => 'Disability';

  @override
  String get timelineEventInvaliditeSub =>
      'Coverage gap AI + LPP and prevention';

  @override
  String get timelineEventDemenagementTitle => 'Cantonal move';

  @override
  String get timelineEventDemenagementSub =>
      'Tax impact of changing canton (26 scales)';

  @override
  String get timelineEventExpatriationTitle => 'Expatriation / Cross-border';

  @override
  String get timelineEventExpatriationSub =>
      'Double taxation, 3a and social coverage';

  @override
  String get timelineEventSurendettementTitle => 'Over-indebtedness';

  @override
  String get timelineEventSurendettementSub =>
      'Debt ratio, repayment plan and assistance';

  @override
  String get timelineQuickCheckupTitle => 'Financial check-up';

  @override
  String get timelineQuickCheckupSub => 'Run the full diagnostic';

  @override
  String get timelineQuickBudgetTitle => 'Budget';

  @override
  String get timelineQuickBudgetSub => 'Manage monthly cashflow';

  @override
  String get timelineQuickPilier3aTitle => 'Pillar 3a';

  @override
  String get timelineQuickPilier3aSub => 'Optimise the tax deduction';

  @override
  String get timelineQuickFiscaliteTitle => 'Taxation';

  @override
  String get timelineQuickFiscaliteSub => 'Compare 26 cantons';

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
  String get actionSuccessNext => 'What\'s next';

  @override
  String get actionSuccessDone => 'Got it';

  @override
  String get dividendeBeneficeTotal => 'Total profit';

  @override
  String get dividendePartSalaire => 'Salary share';

  @override
  String get dividendeTauxMarginal => 'Marginal tax rate';

  @override
  String get successionUrgence => 'Immediate urgency';

  @override
  String get successionDemarches => 'Administrative steps';

  @override
  String get successionLegale => 'Legal succession';

  @override
  String get disabilityGapEmployerSub =>
      'CO art. 324a — 3 to 26 weeks depending on seniority';

  @override
  String get disabilityGapAiDelaySub =>
      'Average AI decision delay: 14 months · LAI art. 28 + LPP art. 23';

  @override
  String get indepCaisseLpp => 'Optional LPP fund';

  @override
  String get indepCaisseLppSub => 'Disability pension + retirement coverage';

  @override
  String get indepGrand3a => 'Grand 3a (without LPP)';

  @override
  String get indepAdminUrgent => 'Urgent administrative';

  @override
  String get indepPrevoyance => 'Pension planning';

  @override
  String get indepOptiFiscale => 'Tax optimisation';

  @override
  String get fhsLevelExcellent => 'Excellent';

  @override
  String get fhsLevelBon => 'Good';

  @override
  String get fhsLevelAmeliorer => 'Needs improvement';

  @override
  String get fhsLevelCritique => 'Critical';

  @override
  String fhsDeltaLabel(String delta) {
    return 'Trend: $delta vs yesterday';
  }

  @override
  String fhsDeltaText(String delta) {
    return '$delta vs yesterday';
  }

  @override
  String get fhsBreakdownLiquidite => 'Liquidity';

  @override
  String get fhsBreakdownFiscalite => 'Taxes';

  @override
  String get fhsBreakdownRetraite => 'Retirement';

  @override
  String get fhsBreakdownRisque => 'Risk';

  @override
  String avsGapLifetimeLoss(String amount) {
    return 'Over 20 years of retirement, that\'s $amount less — permanently.';
  }

  @override
  String get avsGapCalculation =>
      'Calculation: monthly pension × 13 months/year (13th AVS pension from Dec. 2026)';

  @override
  String get chiffreChocRenteCalculation =>
      '(calculation: monthly pension × 13 months/year, 13th pension included).';

  @override
  String get coachBriefingFallbackGreeting => 'Hello';

  @override
  String get coachBriefingBadgeLlm => 'AI Coach';

  @override
  String get coachBriefingBadge => 'Coach';

  @override
  String coachBriefingConfidenceLow(String score) {
    return 'Confidence $score % — Enrich';
  }

  @override
  String coachBriefingConfidence(String score) {
    return 'Confidence $score %';
  }

  @override
  String coachBriefingImpactEstimated(String amount) {
    return 'Estimated impact : CHF $amount';
  }

  @override
  String get chiffreChocSectionDisclaimer =>
      'Educational simulation only. Does not constitute investment or retirement advice (FinSA). Adjustable assumptions — results not guaranteed.';

  @override
  String get concubinageTabProtection => 'Protection';

  @override
  String concubinageHeroChiffreChoc(String montant) {
    return 'CHF $montant of exposed assets';
  }

  @override
  String get concubinageHeroChiffreChocDesc =>
      'In cohabitation, your partner is not a legal heir. Without a will, this entire amount is lost to them.';

  @override
  String get concubinageEducationalAvs =>
      'In Switzerland, the 150% cap on couple AVS pensions (OASI art. 35) only applies to married couples. Cohabiting partners each receive their full individual pension — a real advantage when both have contributed the maximum.';

  @override
  String get concubinageEducationalLpp =>
      'The LPP survivor pension (60% of the deceased’s pension, LPP art. 19) is reserved for spouses. In cohabitation, only the pension fund rules may provide a death benefit — and you must apply for it.';

  @override
  String get concubinageEducationalSuccession =>
      'A married spouse is exempt from inheritance tax in most cantons (CC art. 462). A cohabiting partner pays tax at the third-party rate, often between 20% and 40%.';

  @override
  String get concubinageProtectionIntro =>
      'In cohabitation, Switzerland does not protect like marriage. Here is what changes and what you can anticipate.';

  @override
  String get concubinageProtectionAvsSurvivor => 'AVS survivor pension';

  @override
  String get concubinageProtectionAvsSurvivorMarried =>
      '80% of the deceased’s pension (OASI art. 23)';

  @override
  String get concubinageProtectionAvsSurvivorConcubin =>
      'No pension — CHF 0/month';

  @override
  String get concubinageProtectionLppSurvivor => 'LPP survivor pension';

  @override
  String get concubinageProtectionLppSurvivorMarried =>
      '60% of the deceased’s pension (LPP art. 19)';

  @override
  String get concubinageProtectionLppSurvivorConcubin => 'Per fund rules only';

  @override
  String get concubinageProtectionHeritage => 'Legal inheritance';

  @override
  String get concubinageProtectionHeritageMarried => 'Exempt (CC art. 462)';

  @override
  String get concubinageProtectionHeritageConcubin => 'Cantonal tax (20-40%)';

  @override
  String get concubinageProtectionPension => 'Alimony';

  @override
  String get concubinageProtectionPensionMarried => 'Court-protected';

  @override
  String get concubinageProtectionPensionConcubin => 'No legal obligation';

  @override
  String get concubinageProtectionAvsPlafond => 'Couple AVS cap';

  @override
  String get concubinageProtectionAvsPlafondMarried =>
      '150% max (OASI art. 35)';

  @override
  String get concubinageProtectionAvsPlafondConcubin => 'No cap — 2×100%';

  @override
  String get concubinageProtectionMaried => 'Married';

  @override
  String get concubinageProtectionConcubinLabel => 'Cohabiting';

  @override
  String get concubinageProtectionWarning =>
      'In cohabitation, if your partner dies, you receive no AVS pension, no automatic LPP pension, and you are not a legal heir. Every protection must be planned ahead.';

  @override
  String get concubinageProtectionLppSlider => 'Partner’s monthly LPP pension';

  @override
  String concubinageProtectionSurvivorTotal(String montant) {
    return '$montant/month for the married surviving spouse';
  }

  @override
  String get concubinageProtectionSurvivorZero =>
      'CHF 0/month for the surviving cohabiting partner without action';

  @override
  String get concubinageDecisionMatrixTitle => 'Marriage vs Cohabitation';

  @override
  String get concubinageDecisionMatrixSubtitle =>
      'Comparison of rights and obligations';

  @override
  String get concubinageDecisionMatrixColumnMarriage => 'Marriage';

  @override
  String get concubinageDecisionMatrixColumnConcubinage => 'Cohabitation';

  @override
  String get concubinageDecisionMatrixConclusionTitle => 'Neutral conclusion';

  @override
  String get concubinageDecisionMatrixConclusionDesc =>
      'The choice depends on your personal situation. Consult a notary for a complete analysis.';

  @override
  String get mortgageJourneyTitle => 'Home buying journey';

  @override
  String get mortgageJourneySubtitle =>
      '7 steps from “can I afford it?” to “I signed!”';

  @override
  String get mortgageJourneyPrevious => 'Previous';

  @override
  String get mortgageJourneyNextStep => 'Next step';

  @override
  String get mortgageJourneyComplete => '✅ Journey complete!';

  @override
  String get clause3aTitle => 'The forgotten 3a clause';

  @override
  String get clause3aQuestion => 'Have you filed a beneficiary clause?';

  @override
  String get clause3aStepsTitle => 'How to file a clause in 5 minutes:';

  @override
  String clause3aFeedbackOk(String partner) {
    return 'Great! Check that the clause names $partner — and that it’s up to date after each life event.';
  }

  @override
  String get clause3aFeedbackNok =>
      'Priority action: file your beneficiary clause with your 3a foundation — in 5 minutes.';

  @override
  String get fiscalSuperpowerTitle => 'The tax superpower';

  @override
  String get fiscalSuperpowerSubtitle =>
      'The state gives you money back for having a child.';

  @override
  String get fiscalSuperpowerTaxBenefits => 'Your tax benefits';

  @override
  String get babyCostTitle => 'The cost of happiness';

  @override
  String get babyCostBreakdownTitle => 'Monthly breakdown';

  @override
  String get lifeEventSheetTitle => 'Something is happening to me';

  @override
  String get lifeEventSheetSubtitle =>
      'Choose an event to see the financial impact';

  @override
  String get lifeEventSheetSectionFamille => 'Family';

  @override
  String get lifeEventSheetSectionPro => 'Professional';

  @override
  String get lifeEventSheetSectionPatrimoine => 'Wealth';

  @override
  String get lifeEventSheetSectionMobilite => 'Mobility';

  @override
  String get lifeEventSheetSectionSante => 'Health';

  @override
  String get lifeEventSheetSectionCrise => 'Crisis';

  @override
  String get lifeEventLabelMariage => 'Getting married';

  @override
  String get lifeEventLabelDivorce => 'Going through a divorce';

  @override
  String get lifeEventLabelNaissance => 'Expecting a child';

  @override
  String get lifeEventLabelConcubinage => 'Living together';

  @override
  String get lifeEventLabelDeces => 'Death of a loved one';

  @override
  String get lifeEventLabelPremierEmploi => 'First job';

  @override
  String get lifeEventLabelNouveauJob => 'New job';

  @override
  String get lifeEventLabelIndependant => 'Going self-employed';

  @override
  String get lifeEventLabelPerteEmploi => 'Job loss';

  @override
  String get lifeEventLabelRetraite => 'Retiring';

  @override
  String get lifeEventLabelAchatImmo => 'Buying property';

  @override
  String get lifeEventLabelVenteImmo => 'Selling property';

  @override
  String get lifeEventLabelHeritage => 'Receiving an inheritance';

  @override
  String get lifeEventLabelDonation => 'Giving to my children';

  @override
  String get lifeEventLabelDemenagement => 'Moving cantons';

  @override
  String get lifeEventLabelExpatriation => 'Moving abroad';

  @override
  String get lifeEventLabelInvalidite => 'Am I well covered?';

  @override
  String get lifeEventLabelDettes => 'I have debts';

  @override
  String get lifeEventPromptMariage =>
      'Getting married — what impact on my taxes, AVS and pension?';

  @override
  String get lifeEventPromptDivorce =>
      'Divorcing — what happens to my LPP and taxes?';

  @override
  String get lifeEventPromptNaissance =>
      'Expecting a child — what benefits and deductions are available?';

  @override
  String get lifeEventPromptConcubinage =>
      'We’re not married — how do we protect each other if something goes wrong?';

  @override
  String get lifeEventPromptDeces =>
      'Death of a loved one — what financial steps do I need to take?';

  @override
  String get lifeEventPromptPremierEmploi =>
      'It’s my first job — what do I need to know about my pension and contributions?';

  @override
  String get lifeEventPromptNouveauJob =>
      'Changing jobs — how to compare offers and manage my vested benefits?';

  @override
  String get lifeEventPromptIndependant =>
      'Going self-employed — what pension options without LPP?';

  @override
  String get lifeEventPromptPerteEmploi =>
      'I’ve lost my job — what unemployment benefits and for how long?';

  @override
  String get lifeEventPromptRetraite =>
      'When can I retire and how much will I receive?';

  @override
  String get lifeEventPromptAchatImmo =>
      'Can I buy property with my income and down payment?';

  @override
  String get lifeEventPromptVenteImmo =>
      'Selling my property — what capital gains tax should I expect?';

  @override
  String get lifeEventPromptHeritage =>
      'Receiving an inheritance — what are the tax consequences?';

  @override
  String get lifeEventPromptDonation =>
      'Giving to my children — what tax impact and what limits?';

  @override
  String get lifeEventPromptDemenagement =>
      'Moving cantons — what tax impact should I anticipate?';

  @override
  String get lifeEventPromptExpatriation =>
      'Moving abroad — what to do with my AVS, LPP and 3a?';

  @override
  String get lifeEventPromptInvalidite =>
      'Am I well covered in case of disability or accident?';

  @override
  String get lifeEventPromptDettes =>
      'I have debts — how to manage them without touching my pension?';

  @override
  String compoundDisclaimerInflation(String inflation) {
    return 'Educational assumptions (inflation $inflation %). Past performance does not guarantee future results.';
  }

  @override
  String get interactive3aDisclaimer =>
      'Educational assumptions. Past performance does not guarantee future results.';

  @override
  String get milestoneContinueBtn => 'Continue';

  @override
  String get slmAutoPromptTitle => 'On-device AI Coach';

  @override
  String get slmAutoPromptBody =>
      'MINT can install an AI model directly on your phone for personalised advice — 100 % private, no data leaves your device.';

  @override
  String get slmAutoInstalledMsg =>
      'AI Coach installed ! Your advice will be personalised.';

  @override
  String get slmInstallBtn => 'Install AI Coach';

  @override
  String get slmLaterBtn => 'Later';

  @override
  String get rcDisclaimer =>
      'Educational tool — does not constitute financial advice (FinSA art. 3).';

  @override
  String rcPillar3aTitle(String year) {
    return '3a contribution $year';
  }

  @override
  String get rcPillar3aSubtitle => 'Estimated tax saving';

  @override
  String rcPillar3aExplanation(String plafond) {
    return 'Estimated tax saving if you contribute the cap of $plafond CHF';
  }

  @override
  String get rcPillar3aCtaLabel => 'Simulate my 3a';

  @override
  String get rcLppBuybackTitle => 'LPP buyback';

  @override
  String get rcLppBuybackSubtitle => 'Available buyback potential';

  @override
  String rcLppBuybackExplanation(String taxSaving, String rachatSimule) {
    return 'Buyback available. Estimated tax saving of $taxSaving CHF on $rachatSimule CHF';
  }

  @override
  String get rcLppBuybackCtaLabel => 'Simulate a buyback';

  @override
  String get rcReplacementRateTitle => 'Replacement rate';

  @override
  String rcReplacementRateSubtitle(String age) {
    return 'Projection at age $age';
  }

  @override
  String rcReplacementRateExplanation(
      String totalMonthly, String currentMonthly) {
    return 'Estimated retirement income: $totalMonthly CHF/month vs $currentMonthly CHF/month today';
  }

  @override
  String get rcReplacementRateCtaLabel => 'Explore my scenarios';

  @override
  String get rcReplacementRateAlerte =>
      'Rate below the recommended 60 % threshold. Explore your options.';

  @override
  String get rcAvsGapTitle => 'AVS gap';

  @override
  String rcAvsGapSubtitle(String lacunes) {
    return '$lacunes missing contribution years';
  }

  @override
  String get rcAvsGapExplanation =>
      'Estimated reduction in your annual AVS pension due to gaps';

  @override
  String get rcAvsGapCtaLabel => 'View my AVS extract';

  @override
  String get rcCoupleAlertTitle => 'Couple visibility gap';

  @override
  String rcCoupleAlertSubtitle(String name, String score) {
    return '$name at $score %';
  }

  @override
  String rcCoupleAlertExplanation(String gap) {
    return 'Gap of $gap points between your two profiles. Balancing them improves the couple projection.';
  }

  @override
  String get rcCoupleAlertCtaLabel => 'Enrich the couple profile';

  @override
  String get rcIndependantTitle => 'Self-employed pension';

  @override
  String get rcIndependantSubtitle =>
      'Without LPP, your 3a is your main pension';

  @override
  String rcIndependantExplanation(String max3a, String current3a) {
    return '3a cap without LPP: $max3a CHF/yr. Current 3a capital: $current3a CHF';
  }

  @override
  String get rcIndependantCtaLabel => 'Explore my options';

  @override
  String get rcTaxOptTitle => 'Tax optimisation';

  @override
  String get rcTaxOptSubtitle => 'Estimated available deductions';

  @override
  String rcTaxOptExplanation(String plafond3a) {
    return 'Estimated tax saving via 3a ($plafond3a CHF) + LPP buyback';
  }

  @override
  String get rcTaxOptCtaLabel => 'Discover my deductions';

  @override
  String get rcPatrimoineTitle => 'Wealth';

  @override
  String get rcPatrimoineSubtitleLow => 'Insufficient safety cushion';

  @override
  String get rcPatrimoineSubtitleOk => 'Overview';

  @override
  String rcPatrimoineExplanationLow(String epargne, String coussinMin) {
    return 'Liquid savings ($epargne CHF) below 3 months of expenses ($coussinMin CHF)';
  }

  @override
  String rcPatrimoineExplanationOk(String epargne, String investissements) {
    return 'Savings $epargne CHF + investments $investissements CHF';
  }

  @override
  String get rcPatrimoineCtaLabelLow => 'Analyse my budget';

  @override
  String get rcPatrimoineCtaLabelOk => 'View my wealth';

  @override
  String rcPatrimoineAlerte(String coussinMin) {
    return 'Recommended safety cushion: $coussinMin CHF (3 months of expenses)';
  }

  @override
  String get rcMortgageTitle => 'Mortgage';

  @override
  String rcMortgageSubtitle(String ltv) {
    return 'LTV ratio: $ltv %';
  }

  @override
  String rcMortgageExplanation(String propertyValue) {
    return 'Mortgage balance. Property value: $propertyValue CHF';
  }

  @override
  String get rcMortgageCtaLabel => 'Simulate affordability';

  @override
  String get rcCtaDetail => 'See details →';

  @override
  String get rcLibrePassageTitle => 'Vested benefits';

  @override
  String get rcLibrePassageSubtitle =>
      'What to do with your vested benefits account?';

  @override
  String get rcRenteVsCapitalTitle => 'Pension vs Lump sum';

  @override
  String get rcRenteVsCapitalSubtitle =>
      'Pension or lump sum: quantify both options';

  @override
  String get rcFiscalComparatorTitle => 'Canton comparator';

  @override
  String get rcFiscalComparatorSubtitle => 'How much would you gain by moving?';

  @override
  String get rcStaggeredWithdrawalTitle => 'Staggered 3a withdrawal';

  @override
  String get rcStaggeredWithdrawalSubtitle =>
      'Spread withdrawals to reduce tax';

  @override
  String get rcRealReturn3aTitle => 'Real 3a return';

  @override
  String get rcRealReturn3aSubtitle => 'Return after fees, inflation and tax';

  @override
  String get rcComparator3aTitle => '3a comparator';

  @override
  String get rcComparator3aSubtitle => 'Compare 3a providers';

  @override
  String get rcRentVsBuyTitle => 'Rent or buy';

  @override
  String get rcRentVsBuySubtitle => 'Compare both scenarios over the long term';

  @override
  String get rcAmortizationTitle => 'Amortisation';

  @override
  String get rcAmortizationSubtitle => 'Direct vs indirect — what tax impact';

  @override
  String get rcImputedRentalTitle => 'Imputed rental value';

  @override
  String get rcImputedRentalSubtitle => 'Understanding housing taxation';

  @override
  String get rcSaronVsFixedTitle => 'SARON vs fixed rate';

  @override
  String get rcSaronVsFixedSubtitle => 'Which type of mortgage to choose';

  @override
  String get rcEplTitle => 'EPL withdrawal';

  @override
  String get rcEplSubtitle => 'Use your 2nd pillar for real estate';

  @override
  String get rcHousingSaleTitle => 'Property sale';

  @override
  String get rcHousingSaleSubtitle => 'Capital gains tax + reinvestment';

  @override
  String get rcMariageTitle => 'Impact of marriage';

  @override
  String get rcMariageSubtitle => 'Tax, AVS, LPP, succession';

  @override
  String get rcDivorceTitle => 'Divorce simulator';

  @override
  String get rcDivorceSubtitle => 'LPP split, alimony, taxes';

  @override
  String get rcNaissanceTitle => 'Impact of a new child';

  @override
  String get rcNaissanceSubtitle => 'Allowances, deductions, budget';

  @override
  String get rcConcubinageTitle => 'Cohabitation protection';

  @override
  String get rcConcubinageSubtitle => 'Rights, risks and solutions';

  @override
  String get rcSuccessionTitle => 'Succession';

  @override
  String get rcSuccessionSubtitle => 'Simulate wealth transfer';

  @override
  String get rcDonationTitle => 'Gift';

  @override
  String get rcDonationSubtitle => 'Tax impact of a gift';

  @override
  String get rcUnemploymentTitle => 'Job loss';

  @override
  String get rcUnemploymentSubtitle => 'Benefits, duration, steps';

  @override
  String get rcFirstJobTitle => 'First job';

  @override
  String get rcFirstJobSubtitle => 'Understand everything from the start';

  @override
  String get rcExpatriationTitle => 'Expatriation';

  @override
  String get rcExpatriationSubtitle => 'Impact on AVS, LPP, 3a and taxes';

  @override
  String get rcFrontalierTitle => 'Cross-border worker';

  @override
  String get rcFrontalierSubtitle => 'Withholding tax and specifics';

  @override
  String get rcJobComparisonTitle => 'Job offer comparator';

  @override
  String get rcJobComparisonSubtitle =>
      'Net + pension: which offer is really worth more?';

  @override
  String get rcDividendeVsSalaireTitle => 'Dividend vs Salary';

  @override
  String get rcDividendeVsSalaireSubtitle => 'Optimise remuneration in GmbH/AG';

  @override
  String get rcLamalFranchiseTitle => 'LAMal deductible';

  @override
  String get rcLamalFranchiseSubtitle => 'Which deductible to choose?';

  @override
  String get rcCoverageCheckTitle => 'Coverage check';

  @override
  String get rcCoverageCheckSubtitle => 'Verify your coverage';

  @override
  String get rcDisabilityTitle => 'Disability — income gap';

  @override
  String get rcDisabilitySubtitle =>
      'Gap between current income and AI/LPP benefits';

  @override
  String get rcGenderGapTitle => 'Gender gap';

  @override
  String get rcGenderGapSubtitle => 'Impact of part-time work on retirement';

  @override
  String get rcBudgetTitle => 'Budget';

  @override
  String get rcBudgetSubtitle => 'How much is left at the end of the month?';

  @override
  String get rcDebtRatioTitle => 'Debt ratio';

  @override
  String get rcDebtRatioSubtitle =>
      'At what threshold does debt become dangerous?';

  @override
  String get rcCompoundInterestTitle => 'Compound interest';

  @override
  String get rcCompoundInterestSubtitle =>
      'Simulate the growth of your savings';

  @override
  String get rcLeasingTitle => 'Leasing simulator';

  @override
  String get rcLeasingSubtitle => 'True cost of a car lease';

  @override
  String get rcConsumerCreditTitle => 'Consumer credit';

  @override
  String get rcConsumerCreditSubtitle => 'Total cost of a consumer loan';

  @override
  String get rcAllocationAnnuelleTitle => 'Annual allocation';

  @override
  String get rcAllocationAnnuelleSubtitle =>
      'Where to put your savings this year';

  @override
  String get rcSuggestedPrompt50PlusRetirement =>
      'When does retirement become viable?';

  @override
  String get rcSuggestedPromptRenteOuCapital =>
      'Pension or lump sum: which gives me more freedom?';

  @override
  String get rcSuggestedPromptRachatLpp =>
      'What is an LPP buyback worth in my case?';

  @override
  String get rcSuggestedPromptAllegerImpots =>
      'Where can I reduce my taxes this year?';

  @override
  String get rcSuggestedPromptVersement3a =>
      'How much should I contribute to 3a this year?';

  @override
  String get nudgeSalaryBody =>
      'Have you thought about your 3a transfer this month? Every month counts for your retirement savings.';

  @override
  String get nudgeTaxDeadlineTitle => 'Tax filing deadline';

  @override
  String get nudgeTaxDeadlineBody =>
      'Check the tax filing deadline in your canton. Have you reviewed your 3a and LPP deductions?';

  @override
  String get nudge3aDeadlineTitle => 'Final stretch for your 3a';

  @override
  String nudge3aDeadlineBody(String days, String limit, String year) {
    return '$days day(s) left to contribute up to $limit CHF and reduce your $year taxes.';
  }

  @override
  String get nudgeBirthdayBody =>
      'A milestone that could shape your retirement planning. Have you simulated the impact of this year?';

  @override
  String get nudgeProfileTitle => 'Your profile deserves to be enriched';

  @override
  String get nudgeProfileBody =>
      'The more complete your profile, the more relevant insights MINT can offer. Just a few details needed.';

  @override
  String get nudgeInactiveTitle => 'It has been a while!';

  @override
  String get nudgeInactiveBody =>
      'Your financial situation evolves every week. Take 2 minutes to check your dashboard.';

  @override
  String get nudgeGoalProgressTitle => 'Your goal is progressing!';

  @override
  String nudgeGoalProgressBody(String progress) {
    return 'You have reached $progress% of your goal. Keep going!';
  }

  @override
  String get nudgeAnniversaryBody =>
      'You have been using MINT for a year. It is the perfect time to update your profile and measure your progress.';

  @override
  String get nudgeLppBuybackTitle => 'LPP buyback window';

  @override
  String nudgeLppBuybackBody(String year) {
    return 'The end of $year is approaching: this is the last chance to make a tax-deductible LPP buyback.';
  }

  @override
  String get nudgeNewYearTitle => 'New year, fresh start!';

  @override
  String nudgeNewYearBody(String year) {
    return '$year: a new 3a envelope opens. A good time to plan your contributions.';
  }

  @override
  String get rcSuggestedPromptCommencer3a => 'Why start 3a now?';

  @override
  String get rcSuggestedPrompt2ePilier =>
      'What does the 2nd pillar actually do?';

  @override
  String get rcSuggestedPromptIndependant =>
      'Self-employed: what do I need to rebuild?';

  @override
  String get rcSuggestedPromptCouple =>
      'Where does our couple pension fall short?';

  @override
  String get rcSuggestedPromptFatca => 'FATCA: what does it change for my 3a?';

  @override
  String get rcUnitPts => 'pts';

  @override
  String get routeSuggestionCta => 'Open';

  @override
  String get routeSuggestionPartialWarning => 'Estimate — incomplete data';

  @override
  String get routeSuggestionBlocked =>
      'I need a bit more info to take you there';

  @override
  String get routeReturnAcknowledge =>
      'Welcome back! If you adjusted any data, just tell me and I\'ll recalculate.';

  @override
  String get routeReturnCompleted => 'Noted. Your data is up to date.';

  @override
  String get routeReturnAbandoned =>
      'No worries — we can come back to it whenever you like.';

  @override
  String get routeReturnChanged =>
      'Your figures have changed. I\'m recalculating the trajectory.';

  @override
  String get hypothesisEditorTitle => 'Simulation assumptions';

  @override
  String get hypothesisEditorSubtitle =>
      'Adjust the parameters to see the impact on projections.';

  @override
  String get lifecyclePhaseDemarrage => 'Getting started';

  @override
  String get lifecyclePhaseDemarrageDesc =>
      'First steps in working life: budget, 3a and good financial habits.';

  @override
  String get lifecyclePhaseConstruction => 'Building';

  @override
  String get lifecyclePhaseConstructionDesc =>
      'Career acceleration, savings, first home, family planning.';

  @override
  String get lifecyclePhaseAcceleration => 'Accelerating';

  @override
  String get lifecyclePhaseAccelerationDesc =>
      'Peak earning phase: LPP optimization, tax strategy and wealth growth.';

  @override
  String get lifecyclePhaseConsolidation => 'Consolidating';

  @override
  String get lifecyclePhaseConsolidationDesc =>
      'Retirement preparation, LPP buyback, early estate planning.';

  @override
  String get lifecyclePhaseTransition => 'Transition';

  @override
  String get lifecyclePhaseTransitionDesc =>
      'Pre-retirement decisions: pension vs. lump sum, withdrawal sequencing.';

  @override
  String get lifecyclePhaseRetraite => 'Retirement';

  @override
  String get lifecyclePhaseRetraiteDesc =>
      'Living in retirement: budget adjustment, asset drawdown.';

  @override
  String get lifecyclePhaseTransmission => 'Estate planning';

  @override
  String get lifecyclePhaseTransmissionDesc =>
      'Succession planning, donations and wealth transmission.';

  @override
  String get challengeWeeklyTitle => 'Challenge of the week';

  @override
  String get challengeCompleted => 'Challenge completed!';

  @override
  String challengeStreak(int count) {
    return '$count consecutive weeks';
  }

  @override
  String get challengeBudget01Title =>
      'Check your 3 biggest expenses this week';

  @override
  String get challengeBudget01Desc =>
      'Imagine knowing exactly where every franc goes: open your budget and spot the 3 highest categories this week. You might be surprised.';

  @override
  String get challengeBudget02Title =>
      'Calculate your real monthly savings rate';

  @override
  String get challengeBudget02Desc =>
      'Your savings rate is what\'s left after all expenses. Check whether it exceeds 10% of your net income.';

  @override
  String get challengeBudget03Title =>
      'Compare your insurance costs with an alternative offer';

  @override
  String get challengeBudget03Desc =>
      'Insurance premiums can vary by 30% between providers. Check whether you could save by switching.';

  @override
  String get challengeBudget04Title =>
      'Analyse your fixed vs variable expenses';

  @override
  String get challengeBudget04Desc =>
      'Separate fixed costs (rent, insurance) from variable ones (outings, leisure). This is the foundation for optimising your budget.';

  @override
  String get challengeBudget05Title => 'Check your debt ratio';

  @override
  String get challengeBudget05Desc =>
      'Your debt ratio should not exceed 33% of gross income. Calculate it to see where you stand.';

  @override
  String get challengeBudget06Title => 'Simulate the real cost of your lease';

  @override
  String get challengeBudget06Desc =>
      'A lease is more than the monthly payment: insurance, maintenance, residual value. Calculate the total cost.';

  @override
  String get challengeBudget07Title => 'Evaluate your emergency fund in months';

  @override
  String get challengeBudget07Desc =>
      'How many months could you last without income? The ideal is 3 to 6 months of expenses.';

  @override
  String get challengeBudget08Title =>
      'Check whether you could reduce your consumer credit';

  @override
  String get challengeBudget08Desc =>
      'Consumer credit at 8-12% is very expensive. See if you can accelerate repayment or consolidate it.';

  @override
  String get challengeEpargne01Title => 'Set aside CHF 50 this week';

  @override
  String get challengeEpargne01Desc =>
      'Even a small amount counts: CHF 50 per week is CHF 2,600 per year. The hardest part is starting.';

  @override
  String get challengeEpargne02Title => 'Check your 3a balance vs the ceiling';

  @override
  String get challengeEpargne02Desc =>
      'The 3a ceiling for employees is CHF 7,258 per year. Check how much you have already contributed this year.';

  @override
  String get challengeEpargne03Title => 'Simulate an LPP buyback of CHF 5,000';

  @override
  String get challengeEpargne03Desc =>
      'An LPP buyback is tax-deductible. Simulate the impact of a CHF 5,000 buyback on your pension and taxes.';

  @override
  String get challengeEpargne04Title =>
      'Check whether you can still contribute to 3a this year';

  @override
  String get challengeEpargne04Desc =>
      '3a contributions are annual: if you haven\'t reached the maximum yet, there may still be time.';

  @override
  String get challengeEpargne05Title =>
      'Compare the returns on your 3a accounts';

  @override
  String get challengeEpargne05Desc =>
      'Not all 3a accounts are equal. Compare your account returns with the simulator.';

  @override
  String get challengeEpargne06Title =>
      'Calculate the real return on your 3a after inflation';

  @override
  String get challengeEpargne06Desc =>
      'A 1% return with 1.5% inflation is a negative real return. Check your situation.';

  @override
  String get challengeEpargne07Title =>
      'Simulate a staggered withdrawal from your 3a accounts';

  @override
  String get challengeEpargne07Desc =>
      'Withdrawing your 3a over several years can reduce tax. Simulate the staggered withdrawal strategy.';

  @override
  String get challengeEpargne08Title =>
      'Check whether you can contribute retroactively to 3a';

  @override
  String get challengeEpargne08Desc =>
      'Since 2025, you can make up years without contributions. Check whether you are eligible for retroactive 3a.';

  @override
  String get challengeEpargne09Title =>
      'Check your vested benefits if you changed employer';

  @override
  String get challengeEpargne09Desc =>
      'When changing jobs, your LPP capital is transferred to a vested benefits account. Check that nothing was forgotten.';

  @override
  String get challengePrevoyance01Title => 'Request your AVS account extract';

  @override
  String get challengePrevoyance01Desc =>
      'Your AVS extract shows your contribution years and estimated pension. Request it for free at lavs.ch.';

  @override
  String get challengePrevoyance02Title => 'Check your disability coverage';

  @override
  String get challengePrevoyance02Desc =>
      'In case of disability, does your AI + LPP pension cover your expenses? Check the potential gap.';

  @override
  String get challengePrevoyance03Title =>
      'Compare pension vs lump sum for your LPP';

  @override
  String get challengePrevoyance03Desc =>
      'Lifetime pension or lump sum? Each option has its tax and flexibility advantages. Compare the scenarios.';

  @override
  String get challengePrevoyance04Title => 'Check your retirement projection';

  @override
  String get challengePrevoyance04Desc =>
      'Imagine your retirement: AVS + LPP + 3a — how much will you really have? Check whether you\'re on the right track. Every year counts.';

  @override
  String get challengePrevoyance05Title =>
      'Optimise your decumulation sequence';

  @override
  String get challengePrevoyance05Desc =>
      'The order in which you withdraw from your pillars has a major tax impact. Simulate different sequences.';

  @override
  String get challengePrevoyance06Title => 'Check your AVS gaps';

  @override
  String get challengePrevoyance06Desc =>
      'Each year without AVS contributions reduces your pension — the impact can be significant over the long term. Check for any gaps to fill.';

  @override
  String get challengePrevoyance07Title => 'Plan your succession';

  @override
  String get challengePrevoyance07Desc =>
      'Who inherits what under Swiss law? Check the reserved shares and whether a will is needed.';

  @override
  String get challengePrevoyance08Title => 'Check your unemployment coverage';

  @override
  String get challengePrevoyance08Desc =>
      'Losing your job is stressful. Knowing how much you would receive and for how long can reassure you. Simulate your situation.';

  @override
  String get challengePrevoyance09Title =>
      'Check your disability coverage as self-employed';

  @override
  String get challengePrevoyance09Desc =>
      'As self-employed, your AI coverage may be insufficient. Check whether a supplementary daily allowance insurance would be useful.';

  @override
  String get challengeFiscalite01Title => 'Estimate your 3a tax saving';

  @override
  String get challengeFiscalite01Desc =>
      'Every franc contributed to 3a is deductible. Calculate how much you save in taxes this year.';

  @override
  String get challengeFiscalite02Title =>
      'Check whether an LPP buyback would be deductible this year';

  @override
  String get challengeFiscalite02Desc =>
      'LPP buybacks are deductible from taxable income. Check your buyback potential and the tax saving.';

  @override
  String get challengeFiscalite03Title =>
      'Simulate the tax on a capital withdrawal';

  @override
  String get challengeFiscalite03Desc =>
      'Capital withdrawals (LPP/3a) are taxed separately at a reduced rate. Simulate the tax for different amounts.';

  @override
  String get challengeFiscalite04Title =>
      'Compare salary vs dividend if you are self-employed';

  @override
  String get challengeFiscalite04Desc =>
      'The salary/dividend mix for your situation depends on your income and canton. Simulate both scenarios.';

  @override
  String get challengeFiscalite05Title =>
      'Check the imputed rental value of your property';

  @override
  String get challengeFiscalite05Desc =>
      'If you own property, the imputed rental value is added to your taxable income. Check whether it is correct.';

  @override
  String get challengeFiscalite06Title => 'Calculate your total tax burden';

  @override
  String get challengeFiscalite06Desc =>
      'Federal + cantonal + communal tax: calculate your total tax burden as a percentage of your income.';

  @override
  String get challengeFiscalite07Title => 'Check your FATCA compliance';

  @override
  String get challengeFiscalite07Desc =>
      'As a US citizen, your Swiss accounts are subject to FATCA. Check that your situation is in order.';

  @override
  String get challengeFiscalite08Title => 'Check your withholding tax';

  @override
  String get challengeFiscalite08Desc =>
      'As a cross-border commuter, you are taxed at source. Check that the rate applied matches your situation.';

  @override
  String get challengePatrimoine01Title =>
      'Calculate your mortgage borrowing capacity';

  @override
  String get challengePatrimoine01Desc =>
      'Using the 1/3 rule, check how much you could borrow for a property purchase.';

  @override
  String get challengePatrimoine02Title =>
      'Simulate SARON vs fixed rate for your mortgage';

  @override
  String get challengePatrimoine02Desc =>
      'SARON (variable) or fixed rate? Simulate both scenarios over 10 years to see the difference.';

  @override
  String get challengePatrimoine03Title => 'Compare renting vs owning';

  @override
  String get challengePatrimoine03Desc =>
      'Buying is not always better than renting. Compare both options over 20 years with the simulator.';

  @override
  String get challengePatrimoine04Title =>
      'Simulate an EPL (early LPP withdrawal for housing)';

  @override
  String get challengePatrimoine04Desc =>
      'You can use your 2nd pillar to finance your home. Simulate the impact on your retirement.';

  @override
  String get challengePatrimoine05Title =>
      'Review your complete wealth balance sheet';

  @override
  String get challengePatrimoine05Desc =>
      'Assets, liabilities, net worth: take stock of your overall financial situation. An important moment for perspective.';

  @override
  String get challengePatrimoine06Title =>
      'Check your annual savings allocation';

  @override
  String get challengePatrimoine06Desc =>
      'Between 3a, LPP buyback and mortgage amortisation, how should you distribute your savings this year? Each choice has a different tax impact.';

  @override
  String get challengePatrimoine07Title =>
      'Simulate the impact of mortgage amortisation';

  @override
  String get challengePatrimoine07Desc =>
      'Amortise directly or indirectly via 3a? Simulate both options and their tax impact.';

  @override
  String get challengePatrimoine08Title =>
      'Simulate the effect of compound interest over 20 years';

  @override
  String get challengePatrimoine08Desc =>
      'Even a small return creates a snowball effect. Simulate the growth of your savings over 20 years.';

  @override
  String get challengeEducation01Title =>
      'Read the article on the 13th AVS pension';

  @override
  String get challengeEducation01Desc =>
      'Since 2026, the 13th AVS pension increases your annual pension. Discover what this means concretely for you.';

  @override
  String get challengeEducation02Title =>
      'Understand the difference between minimum and supra-mandatory conversion rates';

  @override
  String get challengeEducation02Desc =>
      'The LPP conversion rate of 6.8% only applies to the minimum. Your fund may have a different rate for the supra-mandatory portion.';

  @override
  String get challengeEducation03Title => 'Discover how the 1st pillar works';

  @override
  String get challengeEducation03Desc =>
      'The AVS is a pay-as-you-go system: working people fund retirees. Understand the basics of your future pension.';

  @override
  String get challengeEducation04Title => 'Understand the 3-pillar system';

  @override
  String get challengeEducation04Desc =>
      'AVS + LPP + 3a: each pillar has its role. Understand how they complement each other for your retirement.';

  @override
  String get challengeEducation05Title =>
      'Explore the concept of replacement rate';

  @override
  String get challengeEducation05Desc =>
      'The replacement rate measures the ratio between your pension and your last salary. The common target is 60-80%.';

  @override
  String get challengeEducation06Title =>
      'Understand LPP contributions by age bracket';

  @override
  String get challengeEducation06Desc =>
      'LPP contributions increase with age: 7%, 10%, 15%, 18%. Check which bracket you are in.';

  @override
  String get challengeEducation07Title =>
      'Discover the financial consequences of cohabitation';

  @override
  String get challengeEducation07Desc =>
      'In cohabitation, you do not have the same inheritance rights as a married person. Check the necessary protections.';

  @override
  String get challengeEducation08Title =>
      'Understand the impact of the gender gap on retirement';

  @override
  String get challengeEducation08Desc =>
      'Women receive on average 37% less pension. Understand the causes and possible solutions.';

  @override
  String get challengeArchetypeEu01Title =>
      'Check your EU contribution years for AVS';

  @override
  String get challengeArchetypeEu01Desc =>
      'Thanks to bilateral agreements, your years contributed in the EU count towards your Swiss AVS pension. Request an E205 certificate to verify the totalisation.';

  @override
  String get challengeArchetypeNonEu01Title =>
      'Check whether a social security convention covers your country';

  @override
  String get challengeArchetypeNonEu01Desc =>
      'Without a bilateral agreement, your foreign contributions do not count for AVS. Check whether your home country has an agreement with Switzerland.';

  @override
  String get challengeArchetypeReturning01Title =>
      'Check your LPP buyback potential after returning to Switzerland';

  @override
  String get challengeArchetypeReturning01Desc =>
      'Back in Switzerland after a stay abroad? You may have significant LPP buyback potential, tax-deductible. Simulate the amount.';

  @override
  String get voiceMicLabel => 'Speak to microphone';

  @override
  String get voiceMicListening => 'Listening…';

  @override
  String get voiceMicProcessing => 'Processing…';

  @override
  String get voiceSpeakerLabel => 'Listen to response';

  @override
  String get voiceSpeakerStop => 'Stop reading';

  @override
  String get voiceUnavailable => 'Voice features not available on this device';

  @override
  String get voicePermissionNeeded => 'Allow microphone access to use voice';

  @override
  String get voiceNoSpeech => 'I didn’t hear anything. Try again.';

  @override
  String get voiceError => 'Voice error. Use the keyboard.';

  @override
  String get benchmarkTitle => 'Similar profiles in your canton';

  @override
  String get benchmarkSubtitle => 'Aggregated and anonymised data (FSO)';

  @override
  String get benchmarkOptInBody =>
      'Compare your situation to your canton\'s medians. Anonymised data, never a ranking.';

  @override
  String get benchmarkOptInButton => 'Enable';

  @override
  String get benchmarkOptOutButton => 'Disable';

  @override
  String get benchmarkDisclaimer =>
      'Aggregated FSO data — educational tool, not a ranking. Does not constitute advice (FinSA art. 3).';

  @override
  String benchmarkInsightIncome(String canton, String amount) {
    return 'The median income in the canton of $canton is CHF $amount/year';
  }

  @override
  String benchmarkInsightSavings(String rate) {
    return 'A similar profile saves around $rate% of their income';
  }

  @override
  String benchmarkInsightTax(String canton, String level) {
    return 'The tax burden in $canton is $level compared to the Swiss average';
  }

  @override
  String benchmarkInsightHousing(String amount) {
    return 'The median rent for a 4-room flat is CHF $amount/month';
  }

  @override
  String benchmarkInsight3a(String rate) {
    return 'Around $rate% of workers contribute to pillar 3a';
  }

  @override
  String benchmarkInsightLpp(String rate) {
    return 'The LPP coverage rate is $rate%';
  }

  @override
  String get benchmarkTaxLevelBelow => 'lower';

  @override
  String get benchmarkTaxLevelAverage => 'comparable';

  @override
  String get benchmarkTaxLevelAbove => 'higher';

  @override
  String get benchmarkNoDataCanton => 'Data not available for this canton';

  @override
  String get llmFailoverActive => 'Automatic failover enabled';

  @override
  String get llmProviderClaude => 'Claude (Anthropic)';

  @override
  String get llmProviderOpenai => 'GPT-4o (OpenAI)';

  @override
  String get llmProviderMistral => 'Mistral';

  @override
  String get llmProviderLocal => 'Local model';

  @override
  String get llmCircuitOpen => 'Service temporarily unavailable';

  @override
  String get llmAllProvidersDown =>
      'All AI services are unavailable. Offline mode activated.';

  @override
  String get llmQualityGood => 'Response quality: good';

  @override
  String get llmQualityDegraded => 'Response quality: degraded';

  @override
  String get gamificationCommunityTitle => 'Monthly challenge';

  @override
  String get gamificationSeasonalTitle => 'Seasonal events';

  @override
  String get gamificationMilestonesTitle => 'Your achievements';

  @override
  String get gamificationOptInPrompt => 'Join community challenges';

  @override
  String get communityChallenge01Title => 'Prepare your tax return';

  @override
  String get communityChallenge01Desc =>
      'January is the right time to gather your tax documents. Contact your canton to find out the deadline and required documents.';

  @override
  String get communityChallenge02Title => 'Identify your tax deductions';

  @override
  String get communityChallenge02Desc =>
      'Professional expenses, mortgage interest, donations: list all the deductions you’re entitled to before submitting your return.';

  @override
  String get communityChallenge03Title =>
      'Check your pillar 3a contribution before the deadline';

  @override
  String get communityChallenge03Desc =>
      'Some cantons allow you to complete the previous year’s pillar 3a contribution until March. Check your canton’s rules.';

  @override
  String get communityChallenge04Title => 'Review your LPP pension certificate';

  @override
  String get communityChallenge04Desc =>
      'Your annual LPP certificate has arrived. Take 10 minutes to understand your assets, conversion rate and buyback potential.';

  @override
  String get communityChallenge05Title => 'Simulate an LPP buyback';

  @override
  String get communityChallenge05Desc =>
      'An LPP buyback improves your retirement AND reduces your taxes. Calculate how much you could buy back and the tax impact in your canton.';

  @override
  String get communityChallenge06Title => 'Do your mid-year review';

  @override
  String get communityChallenge06Desc =>
      '6 months have passed: review your financial goals, check if you’re on track and adjust if necessary.';

  @override
  String get communityChallenge07Title => 'Set your summer savings goal';

  @override
  String get communityChallenge07Desc =>
      'Summer can impact your budget. Set a savings goal for July and track your progress until end of August.';

  @override
  String get communityChallenge08Title =>
      'Build or strengthen your emergency fund';

  @override
  String get communityChallenge08Desc =>
      'An emergency fund of 3 to 6 months of fixed expenses protects you from the unexpected. Check where you stand and plan the missing contributions.';

  @override
  String get communityChallenge09Title =>
      'Schedule your autumn pillar 3a contribution';

  @override
  String get communityChallenge09Desc =>
      'September is ideal for scheduling your next pillar 3a payment. Spreading contributions throughout the year reduces December deadline stress.';

  @override
  String get communityChallenge10Title => 'Celebrate retirement planning month';

  @override
  String get communityChallenge10Desc =>
      'October is Switzerland’s official retirement planning month. Check your retirement projection and identify one concrete action to improve your situation.';

  @override
  String get communityChallenge11Title => 'Plan your year-end optimisations';

  @override
  String get communityChallenge11Desc =>
      'A few weeks remain to act: pillar 3a contribution, charitable donation, expense declaration. Identify what you can still do before 31 December.';

  @override
  String get communityChallenge12Title =>
      'Make your pillar 3a contribution before 31 December';

  @override
  String get communityChallenge12Desc =>
      'The 3a deadline is approaching. Contribute up to CHF 7’258 (employed with LPP) before 31 December to benefit from this year’s tax deduction.';

  @override
  String get seasonalTaxSeasonTitle => 'Tax season';

  @override
  String get seasonalTaxSeasonDesc =>
      'February–March: time to prepare your tax return. Gather your receipts and identify your deductions.';

  @override
  String get seasonal3aCountdownTitle => 'Pillar 3a countdown';

  @override
  String get seasonal3aCountdownDesc =>
      'The 31 December deadline for pillar 3a contributions is approaching. Check your balance and plan your contribution to maximise your tax deduction.';

  @override
  String get seasonalNewYearResolutionsTitle => 'Financial resolutions';

  @override
  String get seasonalNewYearResolutionsDesc =>
      'New year, new financial goals. Define 1 or 2 concrete actions you will take this year.';

  @override
  String get seasonalMidYearReviewTitle => 'Mid-year review';

  @override
  String get seasonalMidYearReviewDesc =>
      'The 6-month mark has been reached. Take a moment to check your progress towards your goals and adjust if necessary.';

  @override
  String get seasonalRetirementMonthTitle => 'Retirement planning month';

  @override
  String get seasonalRetirementMonthDesc =>
      'October is Switzerland’s national retirement planning month. Time to check your retirement projection and your replacement rate.';

  @override
  String get milestoneEngagementFirstWeekTitle => 'First week';

  @override
  String get milestoneEngagementFirstWeekDesc =>
      'You’ve been using MINT for 7 days. Building habits starts here.';

  @override
  String get milestoneEngagementOneMonthTitle => 'One loyal month';

  @override
  String get milestoneEngagementOneMonthDesc =>
      '30 days with MINT. Your financial curiosity is showing.';

  @override
  String get milestoneEngagementCitoyenTitle => 'MINT citizen';

  @override
  String get milestoneEngagementCitoyenDesc =>
      '90 days: you’re among the people taking their financial future into their own hands.';

  @override
  String get milestoneEngagementFideleTitle => 'Loyal 6 months';

  @override
  String get milestoneEngagementFideleDesc =>
      '180 days of financial tracking. Your consistency is building a clear picture of your situation.';

  @override
  String get milestoneEngagementVeteranTitle => 'MINT veteran';

  @override
  String get milestoneEngagementVeteranDesc =>
      '365 days with MINT. A full year of financial awareness.';

  @override
  String get milestoneKnowledgeCurieuxTitle => 'Curious';

  @override
  String get milestoneKnowledgeCurieuxDesc =>
      'You’ve explored 5 financial concepts. Knowledge is the starting point of every informed decision.';

  @override
  String get milestoneKnowledgeEclaireTitle => 'Informed';

  @override
  String get milestoneKnowledgeEclaireDesc =>
      '20 insights read. You’re building a solid understanding of the Swiss financial system.';

  @override
  String get milestoneKnowledgeExpertTitle => 'Expert';

  @override
  String get milestoneKnowledgeExpertDesc =>
      '50 concepts explored. You have a firm grasp of Swiss retirement fundamentals.';

  @override
  String get milestoneKnowledgeStrategisteTitle => 'Strategist';

  @override
  String get milestoneKnowledgeStrategisteDesc =>
      '100 insights. You have a strategic long-term view of your finances.';

  @override
  String get milestoneKnowledgeMaitreTitle => 'Master';

  @override
  String get milestoneKnowledgeMaitreDesc =>
      '200 concepts read. Your financial literacy is a real asset for your life decisions.';

  @override
  String get milestoneActionPremierPasTitle => 'First step';

  @override
  String get milestoneActionPremierPasDesc =>
      'You’ve taken your first concrete financial action. Every big change starts with a first step.';

  @override
  String get milestoneActionActeurTitle => 'Actor';

  @override
  String get milestoneActionActeurDesc =>
      '5 financial actions completed. You’re moving from thinking to doing.';

  @override
  String get milestoneActionMaitreDestinTitle => 'Master of your destiny';

  @override
  String get milestoneActionMaitreDestinDesc =>
      '20 concrete actions. You’re actively managing your financial situation.';

  @override
  String get milestoneActionBatisseurTitle => 'Builder';

  @override
  String get milestoneActionBatisseurDesc =>
      '50 financial actions. You’re patiently building a solid foundation.';

  @override
  String get milestoneActionArchitecteTitle => 'Architect';

  @override
  String get milestoneActionArchitecteDesc =>
      '100 actions. You’re the architect of your financial freedom.';

  @override
  String get milestoneConsistencyFlammeNaissanteTitle => 'Rising flame';

  @override
  String get milestoneConsistencyFlammeNaissanteDesc =>
      '2 consecutive weeks. Your consistency is taking shape.';

  @override
  String get milestoneConsistencyFlammeViveTitle => 'Living flame';

  @override
  String get milestoneConsistencyFlammeViveDesc =>
      '4 weeks without interruption. Your financial discipline is underway.';

  @override
  String get milestoneConsistencyFlammeEtermelleTitle => 'Eternal flame';

  @override
  String get milestoneConsistencyFlammeEtermelleDesc =>
      '12 consecutive weeks. Your consistency has become a habit.';

  @override
  String get milestoneConsistencyConfianceTitle => 'Trusted profile';

  @override
  String get milestoneConsistencyConfianceDesc =>
      'Your profile has reached a confidence score of 70%. Your data enables reliable calculations.';

  @override
  String get milestoneConsistencyChallengesTitle => '6 challenges completed';

  @override
  String get milestoneConsistencyChallengesDesc =>
      'You’ve completed 6 monthly challenges. Six months of concrete financial engagement.';

  @override
  String get rcSalaryLabel => 'Your income';

  @override
  String get rcAgeLabel => 'Your age';

  @override
  String get rcCantonLabel => 'Your canton';

  @override
  String get rcCivilStatusLabel => 'Your civil status';

  @override
  String get rcEmploymentStatusLabel => 'Your employment status';

  @override
  String get rcLppLabel => 'Your LPP data';

  @override
  String get expertTitle => 'Consult a specialist';

  @override
  String get expertSubtitle =>
      'MINT prepares your dossier for an efficient appointment';

  @override
  String get expertDisclaimer =>
      'MINT facilitates the connection — does not replace personalised advice (LSFin art. 3)';

  @override
  String get expertSpecRetirement => 'Retirement';

  @override
  String get expertSpecSuccession => 'Succession';

  @override
  String get expertSpecExpatriation => 'Expatriation';

  @override
  String get expertSpecDivorce => 'Divorce';

  @override
  String get expertSpecSelfEmployment => 'Self-employed';

  @override
  String get expertSpecRealEstate => 'Real estate';

  @override
  String get expertSpecTax => 'Taxation';

  @override
  String get expertSpecDebt => 'Debt management';

  @override
  String get expertDossierTitle => 'Your prepared dossier';

  @override
  String expertDossierIncomplete(int count) {
    return 'Incomplete profile — $count data points missing';
  }

  @override
  String get expertRequestSession => 'Request an appointment';

  @override
  String get expertSessionRequested => 'Request sent';

  @override
  String get expertMissingData =>
      'Estimated value — to be confirmed with the specialist';

  @override
  String get expertDossierSectionSituation => 'Personal situation';

  @override
  String get expertDossierSectionPrevoyance => 'Pension provision';

  @override
  String get expertDossierSectionPatrimoine => 'Assets';

  @override
  String get expertDossierSectionFinancement => 'Financing';

  @override
  String get expertDossierSectionDeductions => 'Tax deductions';

  @override
  String get expertDossierSectionBudget => 'Budget & debts';

  @override
  String get expertItemAge => 'Age';

  @override
  String get expertItemSalaryRange => 'Gross annual income';

  @override
  String get expertItemCoupleStatus => 'Family situation';

  @override
  String get expertItemConjointAge => 'Partner\'s age';

  @override
  String get expertItemLppBalance => 'LPP balance';

  @override
  String get expertItem3aStatus => 'Pillar 3a';

  @override
  String get expertItem3aBalance => '3a capital';

  @override
  String get expertItemLppBuybackPotential => 'Possible LPP buyback';

  @override
  String get expertItemAvsYears => 'AVS contribution years';

  @override
  String get expertItemReplacementRate => 'Estimated replacement rate';

  @override
  String get expertItemFamilyStatus => 'Civil status';

  @override
  String get expertItemChildren => 'Children';

  @override
  String get expertItemPatrimoineRange => 'Estimated assets';

  @override
  String get expertItemPropertyStatus => 'Housing';

  @override
  String get expertItemPropertyValue => 'Property value';

  @override
  String get expertItemNationality => 'Nationality';

  @override
  String get expertItemArchetype => 'Tax profile';

  @override
  String get expertItemYearsInCh => 'Years in Switzerland';

  @override
  String get expertItemResidencePermit => 'Residence permit';

  @override
  String get expertItemAvsStatus => 'AVS status';

  @override
  String get expertItemAvsGaps => 'AVS gaps';

  @override
  String get expertItemCivilStatus => 'Civil status';

  @override
  String get expertItemConjointLpp => 'Partner\'s LPP';

  @override
  String get expertItemEmploymentStatus => 'Employment status';

  @override
  String get expertItemLppCoverage => 'LPP coverage';

  @override
  String get expertItemCanton => 'Canton';

  @override
  String get expertItemCurrentHousing => 'Current housing';

  @override
  String get expertItemEquityEstimate => 'Available equity';

  @override
  String get expertItemLppEpl => 'EPL possible';

  @override
  String get expertItemMortgageBalance => 'Outstanding mortgage';

  @override
  String get expertItemDebtRatio => 'Debt ratio';

  @override
  String get expertItemChargesVsIncome => 'Charges vs income';

  @override
  String get expertItemDebtType => 'Debt types';

  @override
  String get expertValueUnknown => 'Not provided';

  @override
  String get expertValueNone => 'None';

  @override
  String get expertValueOwner => 'Owner';

  @override
  String get expertValueTenant => 'Tenant';

  @override
  String get expertValueSingle => 'Single';

  @override
  String get expertValueMarried => 'Married';

  @override
  String get expertValueDivorced => 'Divorced';

  @override
  String get expertValueWidowed => 'Widowed';

  @override
  String get expertValueConcubinage => 'Cohabiting';

  @override
  String get expertValue3aActive => 'Active';

  @override
  String get expertValue3aInactive => 'Inactive';

  @override
  String get expertValueLppYes => 'Covered';

  @override
  String get expertValueLppNo => 'Not covered';

  @override
  String get expertValueLppEplPossible => 'Possible (to be verified)';

  @override
  String get expertValueDebtNone => 'No debts';

  @override
  String get expertValueDebtLow => 'Low (< 50 % of annual income)';

  @override
  String get expertValueDebtMedium => 'Moderate (50–100 % of annual income)';

  @override
  String get expertValueDebtHigh => 'High (> 100 % of annual income)';

  @override
  String get expertValueChargesNone => 'No debt charges';

  @override
  String get expertValueSalarie => 'Employee';

  @override
  String get expertValueIndependant => 'Self-employed';

  @override
  String get expertValueChomage => 'Unemployed';

  @override
  String get expertValueRetraite => 'Retired';

  @override
  String get expertDebtTypeConso => 'Consumer credit';

  @override
  String get expertDebtTypeLeasing => 'Leasing';

  @override
  String get expertDebtTypeHypo => 'Mortgage';

  @override
  String get expertDebtTypeAutre => 'Other debts';

  @override
  String get expertArchetypeSwissNative => 'Swiss resident';

  @override
  String get expertArchetypeExpatEu => 'EU/EFTA expat';

  @override
  String get expertArchetypeExpatNonEu => 'Non-EU expat';

  @override
  String get expertArchetypeExpatUs => 'US resident (FATCA)';

  @override
  String get expertArchetypeIndepWithLpp => 'Self-employed with LPP';

  @override
  String get expertArchetypeIndepNoLpp => 'Self-employed without LPP';

  @override
  String get expertArchetypeCrossBorder => 'Cross-border worker';

  @override
  String get expertArchetypeReturningSwiss => 'Returning Swiss';

  @override
  String get expertMissingLppBalance => 'LPP balance not provided';

  @override
  String get expertMissingAvsYears => 'AVS contribution years not provided';

  @override
  String get expertMissingLppBuyback => 'LPP buyback gap unknown';

  @override
  String get expertMissing3a => '3a capital not provided';

  @override
  String get expertMissingConjoint => 'Partner data missing';

  @override
  String get expertMissingPatrimoine => 'Assets not provided';

  @override
  String get expertMissingHousing => 'Housing situation unknown';

  @override
  String get expertMissingChildren => 'Number of children not provided';

  @override
  String get expertMissingNationality => 'Nationality not provided';

  @override
  String get expertMissingArrivalAge =>
      'Age on arrival in Switzerland not provided';

  @override
  String get expertMissingPermit => 'Residence permit not provided';

  @override
  String get expertMissingConjointLpp => 'Partner LPP not provided';

  @override
  String get expertMissingIndependantStatus =>
      'Self-employed status not confirmed';

  @override
  String get expertMissingLppCoverage => 'LPP coverage not provided';

  @override
  String get expertMissingCanton => 'Canton not provided';

  @override
  String get expertMissingEquity => 'Equity not provided';

  @override
  String get expertMissingHousingStatus => 'Housing status not provided';

  @override
  String get expertMissingDebtDetail => 'Debt detail missing';

  @override
  String get expertMissingMensualites => 'Monthly debt payments not provided';

  @override
  String get agentFormTitle => 'Pre-filled Form';

  @override
  String get agentFormDisclaimer =>
      'Check each field before sending. MINT does not submit anything on your behalf.';

  @override
  String get agentFormValidateAll => 'I confirm I have reviewed';

  @override
  String get agentFormEstimated => 'Estimated — to confirm';

  @override
  String get agentLetterTitle => 'Prepared Letter';

  @override
  String get agentLetterDisclaimer =>
      'Adapt and send yourself. MINT does not transmit anything.';

  @override
  String get agentLetterPensionSubject => 'Request for pension fund extract';

  @override
  String get agentLetterTransferSubject =>
      'Request for vested benefits transfer';

  @override
  String get agentLetterAvsSubject =>
      'Request for AVS individual account extract';

  @override
  String get agentLetterPlaceholderName => '[Your full name]';

  @override
  String get agentLetterPlaceholderAddress => '[Your address]';

  @override
  String get agentLetterPlaceholderSsn => '[Your AVS number]';

  @override
  String get agentLetterPlaceholderDate => '[Date]';

  @override
  String get agentTaxFormTitle => 'Tax Return — Pre-filling';

  @override
  String get agent3aFormTitle => 'Pillar 3a Certificate';

  @override
  String get agentLppFormTitle => 'LPP Buyback Form';

  @override
  String agentFieldSource(String source) {
    return 'Source : $source';
  }

  @override
  String get agentValidationRequired => 'Validation required before any use';

  @override
  String get agentOutputDisclaimer =>
      'Educational tool — does not constitute financial, tax or legal advice. Verify each piece of information. Compliant with LSFin.';

  @override
  String get agentNoAction =>
      'MINT does not automatically submit, transmit or execute anything.';

  @override
  String get agentSpecialistLabel => 'a qualified specialist';

  @override
  String get agentLppBuybackTitle => 'LPP Buyback Request';

  @override
  String get agentPensionFundSubject => 'Request for pension fund certificate';

  @override
  String get agentLppTransferSubject =>
      'Request for pension transfer (vested benefits)';

  @override
  String get agentFormCantonFallback => '[canton]';

  @override
  String get agentFormRevenuBrut => 'Estimated gross income';

  @override
  String get agentFormCanton => 'Canton of residence';

  @override
  String get agentFormSituationFamiliale => 'Family situation';

  @override
  String get agentFormNbEnfants => 'Number of children';

  @override
  String get agentFormDeduction3a => 'Possible 3a deduction';

  @override
  String get agentFormRachatLppDeductible => 'Estimated deductible LPP buyback';

  @override
  String get agentFormStatutProfessionnel => 'Professional status';

  @override
  String get agentFormBeneficiaireNom => 'Beneficiary name';

  @override
  String get agentFormNumeroCompte3a => '3a account number';

  @override
  String agentFormMontantVersement(String plafond, String year) {
    return '~$plafond CHF (ceiling $year)';
  }

  @override
  String get agentFormMontantVersementLabel => 'Annual payment amount';

  @override
  String get agentFormTypeContrat => 'Contract type';

  @override
  String get agentFormTypeContratSalarie => 'Employee with LPP';

  @override
  String get agentFormTypeContratIndependant => 'Self-employed without LPP';

  @override
  String get agentFormToComplete => '[To be completed]';

  @override
  String get agentFormTitulaireNom => 'Account holder name';

  @override
  String get agentFormNumeroPolice => 'Policy number';

  @override
  String get agentFormAvoirLpp => 'Current LPP assets';

  @override
  String get agentFormRachatMax => 'Maximum buyback available';

  @override
  String get agentFormRachatsDeja => 'Buybacks already made';

  @override
  String get agentFormMontantRachatSouhaite => 'Desired buyback amount';

  @override
  String get agentFormToCompleteAupres => '[To be completed with the fund]';

  @override
  String agentFormToCompleteMax(String max) {
    return '[To be entered — max $max CHF]';
  }

  @override
  String get agentFormCivilCelibataire => 'Single';

  @override
  String get agentFormCivilMarie => 'Married';

  @override
  String get agentFormCivilDivorce => 'Divorced';

  @override
  String get agentFormCivilVeuf => 'Widowed';

  @override
  String get agentFormCivilConcubinage => 'Cohabiting';

  @override
  String get agentFormEmplSalarie => 'Employee';

  @override
  String get agentFormEmplIndependant => 'Self-employed';

  @override
  String get agentFormEmplChomage => 'Job-seeking';

  @override
  String get agentFormEmplRetraite => 'Retired';

  @override
  String get agentLetterCaisseFallback => '[Pension fund name]';

  @override
  String get agentLetterPostalCity => '[Postal code and city]';

  @override
  String get agentLetterCaisseAddress => '[Fund address]';

  @override
  String get agentLetterPoliceNumber => '[Policy number : To be completed]';

  @override
  String get agentLetterCaisseCurrentName => '[Current pension fund]';

  @override
  String get agentLetterCaisseCurrentAddress => '[Current fund address]';

  @override
  String get agentLetterToComplete => '[To be completed]';

  @override
  String get agentLetterAvsOrg => 'Competent AVS compensation office';

  @override
  String get agentLetterAvsAddress => '[Address]';

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
    return '$name\n$address\n$postalCity\n\n$caisse\n$caisseAddress\n$postalCity\n\n$date, $dateFormatted\n\nSubject: $subject\n\nDear Sir/Madam,\n\nI hereby wish to submit the following requests regarding my occupational pension file:\n\n1. Updated pension certificate $year (retirement assets, covered benefits, applicable conversion rate)\n\n2. Confirmation of my buyback capacity (maximum amount pursuant to Art. 79b LPP)\n\n3. Early retirement simulation (projection of assets and pension at 63 and 64, if applicable)\n\nThank you in advance for your diligence. I remain at your disposal for any further information.\n\nYours faithfully,\n\n$name\n$policeNumber';
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
    return '$name\n$address\n$postalCity\n\n$caisseSource\n$caisseCurrentAddress\n$postalCity\n\n$date, $dateFormatted\n\nSubject: $subject\n\nDear Sir/Madam,\n\nDue to the termination of my employment / my departure from Switzerland (delete as applicable), I kindly request that you transfer my vested benefits.\n\nAmount to transfer: the full amount of my vested benefits at the date of departure.\n\nDestination institution:\nName: $toComplete\nIBAN or account number: $toComplete\nAddress: $toComplete\n\nDeparture date: $toComplete\n\nThank you for your diligence and please confirm the successful completion of this transfer.\n\nYours faithfully,\n\n$name';
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
    return '$name\n$ssn\n$address\n$postalCity\n\n$avsOrg\n$avsAddress\n$postalCity\n\n$date, $dateFormatted\n\nSubject: $subject\n\nDear Sir/Madam,\n\nI kindly request that you send me an extract of my individual AVS account (CI) in order to verify my contribution record and identify any gaps.\n\nThank you in advance for your diligence.\n\nYours faithfully,\n\n$name';
  }

  @override
  String get seasonalEventCta => 'Discuss with coach';

  @override
  String get communityChallengeCta => 'Take up the challenge';

  @override
  String get dossierExpertSectionTitle => 'Consult a specialist';

  @override
  String get expertPrepareDossierCta => 'Prepare my dossier';

  @override
  String get dossierAgentSectionTitle => 'Prepared documents';

  @override
  String get agentFormsTaxCta => 'Prepare my tax return';

  @override
  String get agentFormsTaxSubtitle => 'Pre-filled from your profile';

  @override
  String get agentFormsAvsCta => 'Request my AVS extract';

  @override
  String get agentFormsAvsSubtitle => 'Letter template ready to send';

  @override
  String get agentFormsLppCta => 'Request LPP transfer';

  @override
  String get agentFormsLppSubtitle => 'Vested benefits transfer letter';
}
