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
      'Mantén separada una aportación retroactiva para cubrir una laguna de un año anterior.';

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
    return 'Comprueba en cada uno de tus 3a si se recibió una aportación ordinaria para $taxYear. Si una transferencia, una aportación retroactiva para cubrir una laguna de un año anterior o una devolución hace dudosa la respuesta, mantén «No lo sé».';
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
      'En caso de duda, pregunta a la entidad si el movimiento es una aportación ordinaria, una transferencia, una aportación retroactiva para cubrir una laguna de un año anterior o una devolución.';

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

  @override
  String batch11AmountEyebrow(int taxYear) {
    return 'TUS APORTACIONES AL 3A · $taxYear';
  }

  @override
  String batch11AmountTitle(int taxYear) {
    return '¿Cuánto recibieron realmente en total todos tus proveedores 3a en $taxYear?';
  }

  @override
  String get batch11AmountBody =>
      'Empieza por tu proveedor 3a. Si tienes más de uno, indica después de este primer importe que falta uno.';

  @override
  String get batch11ProviderNameLabel => 'Proveedor 3a';

  @override
  String get batch11ProviderNamePrivacy =>
      'No introduzcas números de cuenta, póliza, seguridad social suiza ni IBAN.';

  @override
  String batch11OrdinaryAmountLabel(int taxYear) {
    return 'Aportaciones ordinarias abonadas · $taxYear';
  }

  @override
  String get batch11NotTaxResult =>
      'Este total todavía no es un resultado fiscal.';

  @override
  String batch11AllProvidersReviewed(int taxYear) {
    return 'Solo tengo un proveedor 3a y he comprobado su total de $taxYear';
  }

  @override
  String get batch11WhereFindTitle => '¿Dónde encuentro el importe?';

  @override
  String get batch11WhereFindBody =>
      'En el certificado de cada proveedor, busca el total de aportaciones al pilar 3a. Úsalo una sola vez, aunque incluya varios contratos.';

  @override
  String get batch11UnknownAmount => 'Todavía no conozco ningún importe';

  @override
  String get batch11Continue => 'Continuar';

  @override
  String get batch11CorrectPrevious => 'Corregir mi respuesta anterior';

  @override
  String get batch11ProviderNameEmpty => 'Introduce el nombre del proveedor.';

  @override
  String get batch11ProviderNameSensitive =>
      'Usa solo el nombre del proveedor, sin números de cuenta, póliza, seguridad social suiza ni IBAN.';

  @override
  String get batch11AmountInvalid => 'Introduce un importe CHF válido.';

  @override
  String get batch11AmountZero => 'El importe debe ser superior a cero.';

  @override
  String get batch11ReviewAllRequired =>
      'Confirma que has comprobado todos tus proveedores 3a.';

  @override
  String get batch11HelpTitle => 'Primero encuentra un importe confirmado.';

  @override
  String get batch11HelpUnknownBody =>
      'Empieza por el certificado de un proveedor 3a. Busca el total de aportaciones ordinarias del año, sin añadir transferencias, aportaciones retroactivas ni reembolsos.';

  @override
  String get batch11HelpFoundFirst => 'He encontrado un primer importe';

  @override
  String get batch11HelpEducationOnly =>
      'Continuar con una explicación general';

  @override
  String get batch11HelpBack => 'Volver a la entrada';

  @override
  String get batch11MissingAmount => 'Tengo varios proveedores 3a';

  @override
  String get batch11HelpPartialBody =>
      'Este primer recorrido todavía no puede sumar varios proveedores. No confirmes aquí este total. Si te equivocaste y solo tienes uno, corrige tu declaración; si no, continúa con información general.';

  @override
  String get batch11HelpFoundPartial => 'En realidad, solo tengo un proveedor';

  @override
  String batch12PositiveCantonTitle(int taxYear) {
    return 'El total de tus aportaciones ordinarias de $taxYear está listo.';
  }

  @override
  String get batch12PositiveCantonBody =>
      'Todavía no se ha calculado ningún resultado fiscal. El siguiente paso preguntará tu cantón.';

  @override
  String get batch12CorrectAmounts => 'Corregir mis importes';

  @override
  String get batch14AmountBody =>
      'Añade por separado cada proveedor del pilar 3a. MINT suma los importes localmente sin calcular todavía un resultado fiscal.';

  @override
  String get batch14AddProvider => 'Añadir un proveedor 3a';

  @override
  String batch14ProviderRowLabel(int index) {
    return 'Proveedor 3a n.º $index';
  }

  @override
  String batch14ProvisionalSubtotal(String amount) {
    return 'Suma provisional — sin resultado fiscal calculado: $amount';
  }

  @override
  String batch14AllReviewed(int taxYear) {
    return 'Confirmo que, para $taxYear, solo he incluido las aportaciones ordinarias realmente abonadas en todos mis proveedores del pilar 3a';
  }

  @override
  String get batch14RemoveEmpty => 'Eliminar esta fila vacía';

  @override
  String get batch14Duplicate =>
      'Este proveedor ya está incluido. Corrige su fila para evitar contarlo dos veces.';

  @override
  String get batch14AggregateOverflow =>
      'La suma es demasiado grande. Comprueba los importes introducidos.';

  @override
  String get batch14EmptyBeforeAdd =>
      'Empieza o elimina la fila vacía antes de añadir otra.';

  @override
  String batch14ClassificationGuide(int taxYear) {
    return 'Para $taxYear, una fila corresponde al total anual de un proveedor, aunque tengas allí varios contratos o pólizas. Introduce solo las aportaciones ordinarias realmente abonadas y cuenta cada importe una sola vez. No incluyas transferencias, aportaciones retroactivas, pagos aún pendientes o solo cargados, ni rendimientos. Tras una corrección o reembolso, usa el importe neto confirmado por el proveedor.';
  }

  @override
  String get batch14Privacy =>
      'Entrada local y temporal: no se guarda ni se envía nada. No indiques números de cuenta, póliza, AVS o IBAN. Al salir se borran nombres e importes.';

  @override
  String get batch14RemovedAnnouncement =>
      'Fila vacía eliminada. El foco se ha movido a la fila contigua.';

  @override
  String get batch14ProviderCapacity =>
      'Esta entrada admite como máximo 50 proveedores. Revisa la lista antes de continuar.';

  @override
  String get batch15RemoveProvider => 'Quitar esta fila de mi registro';

  @override
  String batch15TombstoneLabel(int rowNumber) {
    return 'Fila $rowNumber retirada de este registro';
  }

  @override
  String batch15UndoRemoval(int rowNumber) {
    return 'Deshacer la retirada de la fila $rowNumber';
  }

  @override
  String batch15FinalizeRemoval(int rowNumber) {
    return 'Borrar definitivamente la fila $rowNumber de este registro';
  }

  @override
  String batch15TombstonedAnnouncement(String subtotal) {
    return 'Fila retirada de este registro. Nuevo subtotal provisional: $subtotal.';
  }

  @override
  String batch15RestoredAnnouncement(String subtotal) {
    return 'Fila restaurada en este registro. Nuevo subtotal provisional: $subtotal.';
  }

  @override
  String get batch15FinalizedAnnouncement =>
      'La fila retirada se ha borrado definitivamente de este registro.';

  @override
  String get batch15NoProvisionalSubtotal =>
      'ningún importe positivo introducido';

  @override
  String get batch15ResolveTombstoneError =>
      'Deshaz la retirada o borra definitivamente esta fila antes de continuar.';
}
