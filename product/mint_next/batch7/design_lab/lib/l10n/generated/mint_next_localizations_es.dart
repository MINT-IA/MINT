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
}
