// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'mint_next_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class MintNextLocalizationsEn extends MintNextLocalizations {
  MintNextLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get brand => 'MINT';

  @override
  String get quit => 'Exit';

  @override
  String get todayEyebrow => 'TODAY · PILLAR 3A';

  @override
  String get todayTitle => 'What changes if I pay into 3a this year?';

  @override
  String get todayBody =>
      'We will understand the effects one step at a time. MINT informs you, but does not decide for you.';

  @override
  String get start => 'Understand';

  @override
  String get orientationEyebrow => 'BEFORE THE NUMBERS';

  @override
  String get orientationTitle =>
      'Saving for retirement may also reduce your tax.';

  @override
  String get orientationBody =>
      'A 3a payment may lower your taxable income — the amount on which your tax is calculated. Your available cash falls now and the 3a capital remains tied until retirement, except in cases allowed by law.';

  @override
  String get orientationNote =>
      'We will first check the year and your situation. No amount will be recommended.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get backLabel => 'Back';

  @override
  String get taxYearEyebrow => 'STEP 1 · TAX YEAR';

  @override
  String get taxYearTitle => 'Which year are we talking about?';

  @override
  String get taxYearBody =>
      'The maximum depends on the year and your situation, including your earned income and pension-fund affiliation. The current year is suggested, never chosen for you.';

  @override
  String currentYearLabel(int year) {
    return 'Current year: $year';
  }

  @override
  String confirmYear(int year) {
    return 'Choose $year';
  }

  @override
  String yearChosen(int year) {
    return 'Year $year selected';
  }

  @override
  String get partialBoundary =>
      'The next screen will be added in the next batch. Nothing is saved.';

  @override
  String get safeExitTitle => 'Would you like to stop here?';

  @override
  String get safeExitBody =>
      'No personal financial data is saved in this Design Lab.';

  @override
  String get resume => 'Continue here';

  @override
  String get leave => 'Leave without saving';

  @override
  String get dismissedTitle => 'Journey closed';

  @override
  String get startShort => 'Start';

  @override
  String get keepReferenceUnavailable => 'Local marker — coming soon';

  @override
  String get lppQuestionEyebrow => 'YOUR SITUATION';

  @override
  String get lppQuestionTitle => 'Do you currently have a pension fund?';

  @override
  String get lppQuestionBody =>
      'This is also called occupational pension or second pillar. You may be covered through work or voluntarily. We are asking whether you are currently covered, not how much you pay.';

  @override
  String get lppQuestionEvidence =>
      'To check, look for a pension-fund line on a payslip, check a recent pension certificate, or ask your pension fund, employer or HR.';

  @override
  String get lppChoiceYes => 'Yes';

  @override
  String get lppChoiceNo => 'No';

  @override
  String get lppChoiceUnknown => 'I don’t know';

  @override
  String get lppUnknownEyebrow => 'NO PROBLEM';

  @override
  String get lppUnknownTitle => 'You can check without guessing.';

  @override
  String get lppUnknownBody =>
      'Start with whatever feels easiest. Once you know, restart this journey and answer the question again.';

  @override
  String get lppUnknownListLabel =>
      'Three ways to check your pension-fund affiliation';

  @override
  String get lppUnknownPayslip =>
      'Look for an occupational pension, second pillar or pension-fund line on a recent payslip.';

  @override
  String get lppUnknownCertificate =>
      'Look for a recent pension certificate sent by your pension fund.';

  @override
  String get lppUnknownAsk =>
      'Ask your pension fund, employer or HR whether you are currently affiliated.';

  @override
  String get lppBackToQuestion => 'Back to the question';

  @override
  String get lppKeepChecklist => 'Keep this list on this device';

  @override
  String get localReferenceUnavailable => 'Coming soon';

  @override
  String get withoutLppEyebrow => 'A DIFFERENT RULE APPLIES';

  @override
  String get withoutLppTitle =>
      'You may still be able to pay into pillar 3a, but different rules apply.';

  @override
  String get withoutLppBody =>
      'Your answer does not mean you are ineligible for pillar 3a. This first calculation simply does not cover this case yet.';

  @override
  String get lppCorrectAnswer => 'Correct my answer';

  @override
  String get withoutLppKeepExplanation =>
      'Keep this explanation on this device';

  @override
  String get nextStepEyebrow => 'NEXT STEP';

  @override
  String get nextStepTitle => 'Your affiliation is clear.';

  @override
  String get nextStepBody =>
      'The next question will ask what you have already paid this year. It will be added in the next small batch. Nothing is saved.';

  @override
  String get quitJourney => 'Leave this journey';

  @override
  String contributionEyebrow(int taxYear) {
    return 'YOUR 3A CONTRIBUTIONS · $taxYear';
  }

  @override
  String contributionTitle(int taxYear) {
    return 'In $taxYear, did one of your pillar 3a accounts receive a new contribution?';
  }

  @override
  String get contributionBody =>
      'Answer for all your pillar 3a accounts, including a 3a insurance policy.';

  @override
  String contributionCreditedNote(int taxYear) {
    return 'Count only new money received for $taxYear. A payment merely sent or debited does not count yet; nor do a transfer, investment return or fee refund.';
  }

  @override
  String get contributionAmountNote =>
      'You do not need the total yet. We will ask for it only if you answer yes.';

  @override
  String get contributionChoiceYes => 'Yes, a new contribution was received';

  @override
  String get contributionChoiceNo => 'No, no new contribution';

  @override
  String get contributionChoiceUnknown => 'I don’t know';

  @override
  String contributionChoiceGroupLabel(int taxYear) {
    return 'New pillar 3a contributions received in $taxYear';
  }

  @override
  String get contributionEdgeHelp => 'What counts — and what does not';

  @override
  String get contributionEdgePending =>
      'A scheduled, sent or debited payment counts only once your pillar 3a receives it.';

  @override
  String get contributionEdgeTransfer =>
      'Do not count a transfer between two pillar 3a providers: it is not new money.';

  @override
  String get contributionEdgeBuyback =>
      'Keep a retroactive buyback for a past year separate.';

  @override
  String get contributionEdgeFullRefund =>
      'After a full refund, answer no if no effective ordinary contribution remains.';

  @override
  String get contributionEdgePartialRefund =>
      'After a partial refund, answer yes if the provider confirms a positive net amount remains.';

  @override
  String get contributionEdgeUnclearCorrection =>
      'If a correction makes the effective amount unclear, choose “I don’t know”.';

  @override
  String get contributionEdgeMixedTransfer =>
      'If a transfer and new money arrive together, count only the new money.';

  @override
  String get contributionEdgeReturn =>
      'Do not count investment returns or interest as a contribution.';

  @override
  String get contributionEdgeAdjustment =>
      'Do not count a fee refund, rebate or other adjustment.';

  @override
  String get contributionUnknownEyebrow => 'NO PROBLEM';

  @override
  String get contributionUnknownTitle =>
      'You can check without adding it up yourself.';

  @override
  String contributionUnknownBody(int taxYear) {
    return 'Check whether an ordinary contribution was received for $taxYear on each of your pillar 3a accounts. If a transfer, buyback or refund makes the answer unclear, keep “I don’t know”.';
  }

  @override
  String get contributionUnknownListLabel => 'How to check without guessing';

  @override
  String contributionUnknownProviderStatement(int taxYear) {
    return 'In each bank or fintech app or statement, look for a credit received for $taxYear.';
  }

  @override
  String get contributionUnknownInsuranceCertificate =>
      'For a pillar 3a insurance policy, check the annual certificate or ask which ordinary contribution was received.';

  @override
  String get contributionUnknownProviderQuestion =>
      'If unsure, ask the provider whether the movement is an ordinary contribution, transfer, buyback or refund.';

  @override
  String get contributionUnknownTransferWarning =>
      'Never add a transfer between two pillar 3a accounts. That would count the same money twice.';

  @override
  String get contributionUnknownEducationLimit =>
      'You may continue without a personal amount. MINT will show only a general explanation.';

  @override
  String get contributionUnknownContinueEducation =>
      'Continue with a general explanation';

  @override
  String get contributionBackToQuestion => 'Back to the question';

  @override
  String contributionAmountBoundaryTitle(int taxYear) {
    return 'Next, MINT will ask for the ordinary total already received for $taxYear.';
  }

  @override
  String contributionAmountBoundaryBody(int taxYear) {
    return 'The total must cover all your pillar 3a accounts and policies. After a partial refund, you can use the net amount confirmed by the provider. For now, no amount is known or calculated.';
  }

  @override
  String contributionCantonBoundaryTitle(int taxYear) {
    return 'Based on your answer, no ordinary contribution is included for $taxYear.';
  }

  @override
  String get contributionCantonBoundaryBody =>
      'No personal tax result has been calculated. The next step will ask for your canton.';

  @override
  String get contributionBoundaryBack => 'Correct my answer';

  @override
  String get contributionEducationTitle =>
      'You can understand the rule without giving an amount.';

  @override
  String get contributionEducationBody =>
      'This explanation remains general: no personal amount, pillar 3a room or personal tax saving is calculated.';

  @override
  String get contributionEducationBack => 'Back to the checks';
}
