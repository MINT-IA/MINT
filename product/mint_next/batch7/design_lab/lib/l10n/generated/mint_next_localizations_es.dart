// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'mint_next_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class MintNextLocalizationsEs extends MintNextLocalizations {
  MintNextLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get brand => 'MINT';

  @override
  String get quit => 'Salir';

  @override
  String get todayEyebrow => 'HOY · PILAR 3A';

  @override
  String get todayTitle => '¿Qué cambia si aporto al pilar 3a este año?';

  @override
  String get todayBody =>
      'Entenderemos los efectos paso a paso. MINT te informa, pero no decide por ti.';

  @override
  String get start => 'Entender';

  @override
  String get orientationEyebrow => 'ANTES DE LOS NÚMEROS';

  @override
  String get orientationTitle =>
      'Ahorrar para tu jubilación también puede reducir tus impuestos.';

  @override
  String get orientationBody =>
      'Una aportación al pilar 3a puede reducir tu renta imponible — el importe sobre el que se calculan tus impuestos. Tu dinero disponible disminuye ahora y el capital 3a queda vinculado hasta la jubilación, salvo en los casos previstos por la ley.';

  @override
  String get orientationNote =>
      'Primero comprobaremos el año y tu situación. No se recomendará ningún importe.';

  @override
  String get continueLabel => 'Continuar';

  @override
  String get backLabel => 'Atrás';

  @override
  String get taxYearEyebrow => 'PASO 1 · AÑO FISCAL';

  @override
  String get taxYearTitle => '¿De qué año hablamos?';

  @override
  String get taxYearBody =>
      'El límite depende del año y de tu situación, incluidos tus ingresos profesionales y tu afiliación a una caja de pensiones. Se propone el año actual, pero nunca se elige por ti.';

  @override
  String currentYearLabel(int year) {
    return 'Año actual: $year';
  }

  @override
  String confirmYear(int year) {
    return 'Elegir $year';
  }

  @override
  String yearChosen(int year) {
    return 'Año $year seleccionado';
  }

  @override
  String get partialBoundary =>
      'La siguiente pantalla se añadirá en el próximo lote pequeño. No se guarda nada.';

  @override
  String get safeExitTitle => '¿Quieres detenerte aquí?';

  @override
  String get safeExitBody =>
      'Este Design Lab no guarda datos financieros personales.';

  @override
  String get resume => 'Continuar aquí';

  @override
  String get leave => 'Salir sin guardar';

  @override
  String get dismissedTitle => 'Recorrido cerrado';

  @override
  String get startShort => 'Empezar';

  @override
  String get keepReferenceUnavailable => 'Referencia local — próximamente';

  @override
  String get lppQuestionEyebrow => 'TU SITUACIÓN';

  @override
  String get lppQuestionTitle => '¿Tienes actualmente una caja de pensiones?';

  @override
  String get lppQuestionBody =>
      'También se llama previsión profesional, LPP o segundo pilar. Puedes estar afiliado por tu trabajo o voluntariamente. Te preguntamos si tienes cobertura actualmente, no cuánto aportas.';

  @override
  String get lppQuestionEvidence =>
      'Para comprobarlo, busca una línea LPP o caja de pensiones en una nómina, consulta un certificado reciente o pregunta a tu caja de pensiones, empleador o recursos humanos.';

  @override
  String get lppChoiceYes => 'Sí';

  @override
  String get lppChoiceNo => 'No';

  @override
  String get lppChoiceUnknown => 'No lo sé';

  @override
  String get lppUnknownEyebrow => 'NO PASA NADA';

  @override
  String get lppUnknownTitle => 'Puedes comprobarlo sin adivinar.';

  @override
  String get lppUnknownBody =>
      'Empieza por lo que te resulte más fácil. Cuando tengas la respuesta, retoma este recorrido y responde de nuevo a la pregunta.';

  @override
  String get lppUnknownListLabel => 'Tres formas de comprobar tu afiliación';

  @override
  String get lppUnknownPayslip =>
      'Busca LPP, segundo pilar o caja de pensiones en una nómina reciente.';

  @override
  String get lppUnknownCertificate =>
      'Busca un certificado de previsión reciente enviado por tu caja de pensiones.';

  @override
  String get lppUnknownAsk =>
      'Pregunta a tu caja de pensiones, empleador o recursos humanos si estás afiliado actualmente.';

  @override
  String get lppBackToQuestion => 'Volver a la pregunta';

  @override
  String get lppKeepChecklist => 'Guardar esta lista en este dispositivo';

  @override
  String get localReferenceUnavailable => 'Próximamente';

  @override
  String get withoutLppEyebrow => 'SE APLICA OTRA REGLA';

  @override
  String get withoutLppTitle =>
      'Quizá puedas aportar al pilar 3a, pero se aplican otras reglas.';

  @override
  String get withoutLppBody =>
      'Tu respuesta no significa que no tengas derecho al pilar 3a. Este primer cálculo simplemente aún no cubre este caso.';

  @override
  String get lppCorrectAnswer => 'Corregir mi respuesta';

  @override
  String get withoutLppKeepExplanation =>
      'Guardar esta explicación en este dispositivo';

  @override
  String get nextStepEyebrow => 'SIGUIENTE PASO';

  @override
  String get nextStepTitle => 'Tu afiliación está clara.';

  @override
  String get nextStepBody =>
      'La siguiente pregunta será sobre lo que ya has aportado este año. Se añadirá en el próximo lote pequeño. No se guarda nada.';

  @override
  String get quitJourney => 'Salir de este recorrido';

  @override
  String contributionEyebrow(int taxYear) {
    return 'TUS APORTACIONES 3A · $taxYear';
  }

  @override
  String contributionTitle(int taxYear) {
    return 'En $taxYear, ¿alguno de tus pilares 3a recibió una nueva aportación?';
  }

  @override
  String get contributionBody =>
      'Responde teniendo en cuenta todos tus pilares 3a, incluido un seguro 3a.';

  @override
  String contributionCreditedNote(int taxYear) {
    return 'Cuenta solo el dinero nuevo recibido para $taxYear. Un pago solo enviado o cargado aún no cuenta; tampoco una transferencia, un rendimiento o un reembolso de gastos.';
  }

  @override
  String get contributionAmountNote =>
      'Todavía no necesitas saber el total. Solo te lo pediremos si respondes que sí.';

  @override
  String get contributionChoiceYes => 'Sí, se recibió una nueva aportación';

  @override
  String get contributionChoiceNo => 'No, ninguna nueva aportación';

  @override
  String get contributionChoiceUnknown => 'No lo sé';

  @override
  String contributionChoiceGroupLabel(int taxYear) {
    return 'Nuevas aportaciones 3a recibidas en $taxYear';
  }

  @override
  String get contributionEdgeHelp => 'Qué cuenta — y qué no';

  @override
  String get contributionEdgePending =>
      'Un pago programado, enviado o cargado solo cuenta cuando llega a tu 3a.';

  @override
  String get contributionEdgeTransfer =>
      'No cuentes una transferencia entre dos pilares 3a: no es dinero nuevo.';

  @override
  String get contributionEdgeBuyback =>
      'Mantén separada una recompra retroactiva para un año anterior.';

  @override
  String get contributionEdgeFullRefund =>
      'Tras un reembolso total, responde no si no queda ninguna aportación ordinaria efectiva.';

  @override
  String get contributionEdgePartialRefund =>
      'Tras un reembolso parcial, responde sí si la entidad confirma que queda un importe neto positivo.';

  @override
  String get contributionEdgeUnclearCorrection =>
      'Si una corrección hace incierto el importe efectivo, elige «No lo sé».';

  @override
  String get contributionEdgeMixedTransfer =>
      'Si llegan juntos una transferencia y dinero nuevo, cuenta solo el dinero nuevo.';

  @override
  String get contributionEdgeReturn =>
      'No cuentes rendimientos ni intereses como aportación.';

  @override
  String get contributionEdgeAdjustment =>
      'No cuentes un reembolso de gastos, bonificación u otro ajuste.';

  @override
  String get contributionUnknownEyebrow => 'NO PASA NADA';

  @override
  String get contributionUnknownTitle =>
      'Puedes comprobarlo sin sumar por tu cuenta.';

  @override
  String contributionUnknownBody(int taxYear) {
    return 'Comprueba en cada uno de tus 3a si se recibió una aportación ordinaria para $taxYear. Si una transferencia, recompra o devolución hace dudosa la respuesta, mantén «No lo sé».';
  }

  @override
  String get contributionUnknownListLabel => 'Cómo comprobarlo sin adivinar';

  @override
  String contributionUnknownProviderStatement(int taxYear) {
    return 'En la app o extracto de cada banco o fintech 3a, busca un abono recibido para $taxYear.';
  }

  @override
  String get contributionUnknownInsuranceCertificate =>
      'Para un seguro 3a, consulta el certificado anual o pregunta qué aportación ordinaria se recibió.';

  @override
  String get contributionUnknownProviderQuestion =>
      'En caso de duda, pregunta a la entidad si el movimiento es una aportación ordinaria, transferencia, recompra o devolución.';

  @override
  String get contributionUnknownTransferWarning =>
      'Nunca sumes una transferencia entre dos 3a. Contarías dos veces el mismo dinero.';

  @override
  String get contributionUnknownEducationLimit =>
      'Puedes continuar sin un importe personal. MINT solo mostrará una explicación general.';

  @override
  String get contributionUnknownContinueEducation =>
      'Continuar con una explicación general';

  @override
  String get contributionBackToQuestion => 'Volver a la pregunta';

  @override
  String contributionAmountBoundaryTitle(int taxYear) {
    return 'Después, MINT pedirá el total ordinario ya recibido para $taxYear.';
  }

  @override
  String contributionAmountBoundaryBody(int taxYear) {
    return 'El total deberá abarcar todas tus cuentas y pólizas 3a. Tras un reembolso parcial, podrás usar el importe neto confirmado por la entidad. Por ahora no se conoce ni calcula ningún importe.';
  }

  @override
  String contributionCantonBoundaryTitle(int taxYear) {
    return 'Según tu respuesta, no se incluye ninguna aportación ordinaria para $taxYear.';
  }

  @override
  String get contributionCantonBoundaryBody =>
      'Aún no se ha calculado ningún resultado fiscal personal. El siguiente paso preguntará tu cantón.';

  @override
  String get contributionBoundaryBack => 'Corregir mi respuesta';

  @override
  String get contributionEducationTitle =>
      'Puedes entender la regla sin indicar un importe.';

  @override
  String get contributionEducationBody =>
      'Esta explicación sigue siendo general: no se calcula ningún importe personal, margen 3a ni ahorro fiscal personal.';

  @override
  String get contributionEducationBack => 'Volver a las comprobaciones';
}
