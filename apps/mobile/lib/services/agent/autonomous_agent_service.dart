/// Autonomous Agent Service — Sprint S68 (Agent Autonome v1).
///
/// Form pre-fill (tax declaration, 3a forms), letter generation
/// (caisse de pension requests), fiscal dossier prep.
/// ALL read-only, ALL require user validation before submission.
///
/// Safety invariant: 0 unauthorized actions, user validation gate
/// on 100% of outputs. [requiresValidation] ALWAYS returns true.
///
/// References:
///   - LIFD art. 38 (impot sur retrait en capital)
///   - LPP art. 14-16 (prevoyance professionnelle)
///   - OPP3 art. 7 (3e pilier)
///   - LSFin art. 3/8 (qualite de l'information financiere)
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/coach_profile.dart';

// ════════════════════════════════════════════════════════════════
//  ENUMS
// ════════════════════════════════════════════════════════════════

/// Types of autonomous agent tasks.
enum AgentTaskType {
  taxDeclarationPreFill,
  threeAFormPreFill,
  caisseLetterGeneration,
  fiscalDossierPrep,
  avsExtractRequest,
  lppCertificateRequest,
}

/// Lifecycle status of an agent task.
enum AgentTaskStatus {
  draft,
  pendingValidation,
  validated,
  rejected,
  expired,
}

// ════════════════════════════════════════════════════════════════
//  AGENT TASK MODEL
// ════════════════════════════════════════════════════════════════

/// A single autonomous agent task with mandatory validation gate.
class AgentTask {
  final String id;
  final AgentTaskType type;
  final AgentTaskStatus status;
  final DateTime createdAt;
  final DateTime? validatedAt;
  final String title;
  final String description;
  final Map<String, String> preFilledFields;
  final List<String> fieldsNeedingReview;
  final String? generatedDocument;
  final String disclaimer;
  final List<String> sources;
  final String validationPrompt;

  const AgentTask({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.validatedAt,
    required this.title,
    required this.description,
    required this.preFilledFields,
    required this.fieldsNeedingReview,
    this.generatedDocument,
    required this.disclaimer,
    required this.sources,
    required this.validationPrompt,
  });

  AgentTask copyWith({
    AgentTaskStatus? status,
    DateTime? validatedAt,
  }) {
    return AgentTask(
      id: id,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
      validatedAt: validatedAt ?? this.validatedAt,
      title: title,
      description: description,
      preFilledFields: preFilledFields,
      fieldsNeedingReview: fieldsNeedingReview,
      generatedDocument: generatedDocument,
      disclaimer: disclaimer,
      sources: sources,
      validationPrompt: validationPrompt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'validatedAt': validatedAt?.toIso8601String(),
        'title': title,
        'description': description,
        'preFilledFields': preFilledFields,
        'fieldsNeedingReview': fieldsNeedingReview,
        'generatedDocument': generatedDocument,
        'disclaimer': disclaimer,
        'sources': sources,
        'validationPrompt': validationPrompt,
      };

  factory AgentTask.fromJson(Map<String, dynamic> json) {
    return AgentTask(
      id: json['id'] as String,
      type: AgentTaskType.values.firstWhere(
        (t) => t.name == json['type'],
      ),
      status: AgentTaskStatus.values.firstWhere(
        (s) => s.name == json['status'],
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      validatedAt: json['validatedAt'] != null
          ? DateTime.parse(json['validatedAt'] as String)
          : null,
      title: json['title'] as String,
      description: json['description'] as String,
      preFilledFields:
          Map<String, String>.from(json['preFilledFields'] as Map),
      fieldsNeedingReview:
          List<String>.from(json['fieldsNeedingReview'] as List),
      generatedDocument: json['generatedDocument'] as String?,
      disclaimer: json['disclaimer'] as String,
      sources: List<String>.from(json['sources'] as List),
      validationPrompt: json['validationPrompt'] as String,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  SAFETY GATE
// ════════════════════════════════════════════════════════════════

/// Result of a safety validation check.
class SafetyResult {
  final bool passed;
  final List<String> violations;

  const SafetyResult({required this.passed, this.violations = const []});
}

/// Immutable audit log entry for every agent action.
class AgentAuditEntry {
  final DateTime timestamp;
  final String taskId;
  final String action; // 'generated', 'validated', 'rejected', 'blocked', 'expired'
  final List<String> details;

  const AgentAuditEntry({
    required this.timestamp,
    required this.taskId,
    required this.action,
    this.details = const [],
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'taskId': taskId,
        'action': action,
        'details': details,
      };

  factory AgentAuditEntry.fromJson(Map<String, dynamic> json) {
    return AgentAuditEntry(
      timestamp: DateTime.parse(json['timestamp'] as String),
      taskId: json['taskId'] as String,
      action: json['action'] as String,
      details: List<String>.from(json['details'] as List? ?? []),
    );
  }
}

/// Safety gate that validates every agent output before it reaches the user.
/// NON-NEGOTIABLE: every task must pass all checks.
///
/// Checks (11 rules):
///   1. Status must be pendingValidation
///   2. Disclaimer present and non-empty
///   3. No PII (IBAN, SSN/AVS, email, phone)
///   4. validationPrompt present
///   5. fieldsNeedingReview non-empty
///   6. Legal sources present
///   7. No banned terms (MINT compliance: "garanti", "optimal", etc.)
///   8. No money movement / write operation keywords
///   9. No prompt injection patterns
///  10. Disclaimer must reference educational nature
///  11. Safe mode: block optimization tasks when toxic debt detected
class AgentSafetyGate {
  AgentSafetyGate._();

  /// PII patterns that must NEVER appear in pre-filled fields.
  static final RegExp _ibanPattern = RegExp(
    r'[A-Z]{2}\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{0,2}',
  );
  static final RegExp _ssnPattern = RegExp(
    r'756\.\d{4}\.\d{4}\.\d{2}',
  );
  static final RegExp _emailPattern = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );
  static final RegExp _phonePattern = RegExp(
    r'(?:\+41|0)[\s.-]?(?:76|77|78|79|[1-4]\d)[\s.-]?\d{3}[\s.-]?\d{2}[\s.-]?\d{2}',
  );

  /// Banned terms — absolute promises forbidden by MINT compliance.
  static const List<String> _bannedTerms = [
    'garanti',
    'certain',
    'assuré',
    'sans risque',
    'optimal',
    'meilleur',
    'parfait',
    'conseiller',
    'garantie',
    'assurée',
    'optimale',
    'meilleure',
    'parfaite',
    'conseillère',
  ];

  /// Write-operation / money-movement keywords that MUST NEVER appear.
  static const List<String> _bannedActions = [
    'virement',
    'transfert bancaire',
    'paiement',
    'débiter',
    'créditer',
    'exécuter le transfert',
    'soumettre automatiquement',
    'envoyer automatiquement',
    'acheter',
    'vendre',
    'ordre de bourse',
    'ISIN',
    'ticker',
  ];

  /// Prompt injection patterns — attempts to override agent behavior.
  static final List<RegExp> _injectionPatterns = [
    RegExp(r'ignore\s+(previous|all|above)\s+instructions', caseSensitive: false),
    RegExp(r'you\s+are\s+now\s+', caseSensitive: false),
    RegExp(r'system\s*:\s*', caseSensitive: false),
    RegExp(r'<\s*system\s*>', caseSensitive: false),
    RegExp(r'override\s+(safety|compliance|rules)', caseSensitive: false),
    RegExp(r'disregard\s+(safety|compliance|rules)', caseSensitive: false),
    RegExp(r'jailbreak', caseSensitive: false),
    RegExp(r'DAN\s+mode', caseSensitive: false),
  ];

  /// Task types that are blocked in safe mode (toxic debt detected).
  static const List<AgentTaskType> _safeModeBlockedTypes = [
    AgentTaskType.threeAFormPreFill,
    AgentTaskType.fiscalDossierPrep,
    AgentTaskType.lppCertificateRequest,
    AgentTaskType.taxDeclarationPreFill,
  ];

  /// Validate an agent task against all safety rules.
  static SafetyResult validate(AgentTask task, {bool isSafeMode = false}) {
    final violations = <String>[];

    // 1. Status check — must be pendingValidation
    if (task.status == AgentTaskStatus.validated ||
        task.status == AgentTaskStatus.draft) {
      violations
          .add('Task must be in pendingValidation status before user review');
    }

    // 2. Disclaimer check
    if (task.disclaimer.trim().isEmpty) {
      violations.add('Disclaimer is missing or empty');
    }

    // Collect all text for scanning
    final allText = [
      task.title,
      task.description,
      task.disclaimer,
      task.validationPrompt,
      ...task.preFilledFields.values,
      if (task.generatedDocument != null) task.generatedDocument!,
    ].join(' ');

    // 3. PII check in pre-filled fields
    for (final entry in task.preFilledFields.entries) {
      final value = entry.value;
      if (_ibanPattern.hasMatch(value)) {
        violations.add('PII detected (IBAN) in field "${entry.key}"');
      }
      if (_ssnPattern.hasMatch(value)) {
        violations.add('PII detected (SSN/AVS) in field "${entry.key}"');
      }
      if (_emailPattern.hasMatch(value)) {
        violations.add('PII detected (email) in field "${entry.key}"');
      }
      if (_phonePattern.hasMatch(value)) {
        violations.add('PII detected (phone) in field "${entry.key}"');
      }
    }

    // Also check generated document for PII
    if (task.generatedDocument != null) {
      final doc = task.generatedDocument!;
      if (_ibanPattern.hasMatch(doc)) {
        violations.add('PII detected (IBAN) in generated document');
      }
      if (_ssnPattern.hasMatch(doc)) {
        violations.add('PII detected (SSN/AVS) in generated document');
      }
      if (_emailPattern.hasMatch(doc)) {
        violations.add('PII detected (email) in generated document');
      }
      if (_phonePattern.hasMatch(doc)) {
        violations.add('PII detected (phone) in generated document');
      }
    }

    // 4. Validation prompt check
    if (task.validationPrompt.trim().isEmpty) {
      violations.add('Validation prompt is missing or empty');
    }

    // 5. Fields needing review check
    if (task.fieldsNeedingReview.isEmpty) {
      violations.add('fieldsNeedingReview must not be empty');
    }

    // 6. Sources check
    if (task.sources.isEmpty) {
      violations.add('Legal sources must be provided');
    }

    // 7. Banned terms check (MINT compliance)
    final lowerText = allText.toLowerCase();
    for (final banned in _bannedTerms) {
      final pattern = RegExp('\\b${RegExp.escape(banned)}\\b');
      if (pattern.hasMatch(lowerText)) {
        violations.add('Banned term "$banned" detected in task output');
      }
    }

    // 8. Write-operation / money-movement check
    for (final action in _bannedActions) {
      final pattern = RegExp('\\b${RegExp.escape(action)}\\b',
          caseSensitive: false);
      if (pattern.hasMatch(lowerText)) {
        violations.add('Banned action "$action" detected — read-only violation');
      }
    }

    // 9. Prompt injection check
    for (final injectionRe in _injectionPatterns) {
      if (injectionRe.hasMatch(allText)) {
        violations.add(
            'Prompt injection pattern detected: ${injectionRe.pattern}');
      }
    }

    // 10. Disclaimer must reference educational nature
    if (task.disclaimer.isNotEmpty &&
        !task.disclaimer.contains('éducatif') &&
        !task.disclaimer.contains('educatif')) {
      violations.add('Disclaimer must reference educational nature');
    }

    // 11. Safe mode check — block optimization tasks when toxic debt detected
    if (isSafeMode && _safeModeBlockedTypes.contains(task.type)) {
      violations.add(
          'Task type ${task.type.name} blocked in safe mode '
          '(toxic debt detected — priority is debt reduction)');
    }

    return SafetyResult(
      passed: violations.isEmpty,
      violations: violations,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  MAIN SERVICE
// ════════════════════════════════════════════════════════════════

/// Autonomous Agent Service — generates tasks that ALWAYS require
/// user validation before any action is taken.
///
/// Read-only, education-first. No money movement. No submission.
class AutonomousAgentService {
  AutonomousAgentService._();

  static const String _storageKey = 'agent_task_history';
  static const String _auditKey = 'agent_audit_log';

  /// Duration after which unvalidated tasks expire.
  static const Duration expirationDuration = Duration(days: 30);

  static const String _defaultDisclaimerFr =
      'Cet outil est purement éducatif et ne constitue pas un conseil '
      'financier, fiscal ou juridique. Les montants affichés sont des '
      'estimations indicatives. Consultez un·e spécialiste agréé·e '
      'avant toute décision. Conforme à\u00a0la LSFin.';

  static const String _defaultValidationPromptFr =
      'Vérifie attentivement chaque information avant toute utilisation. '
      'Tous les champs sont des estimations à\u00a0confirmer.';

  static const String _letterValidationPromptFr =
      "Vérifie les informations et complète les champs entre crochets "
      "avant d'envoyer cette lettre.";

  static const String _requestValidationPromptFr =
      "Vérifie les informations et complète les champs entre crochets "
      "avant d'envoyer cette demande.";

  // ─────────────────────────────────────────────────────────────
  //  PUBLIC API
  // ─────────────────────────────────────────────────────────────

  /// Generate a task. ALWAYS returns in [pendingValidation] status.
  ///
  /// If [isSafeMode] is true, optimization tasks (3a, fiscal dossier)
  /// are blocked — priority is debt reduction.
  /// [l] — localizations instance; when provided all user-facing strings are
  ///        i18n'd. When null (unit tests without BuildContext) falls back to
  ///        hardcoded French strings.
  static Future<AgentTask> generateTask({
    required AgentTaskType type,
    required CoachProfile profile,
    DateTime? now,
    SharedPreferences? prefs,
    bool isSafeMode = false,
    S? l,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final id =
        '${type.name}_${effectiveNow.millisecondsSinceEpoch}';

    final task = switch (type) {
      AgentTaskType.taxDeclarationPreFill =>
        _generateTaxDeclaration(id, profile, effectiveNow, l),
      AgentTaskType.threeAFormPreFill =>
        _generateThreeAForm(id, profile, effectiveNow, l),
      AgentTaskType.caisseLetterGeneration =>
        _generateCaisseLetter(id, profile, effectiveNow, l),
      AgentTaskType.fiscalDossierPrep =>
        _generateFiscalDossier(id, profile, effectiveNow, l),
      AgentTaskType.avsExtractRequest =>
        _generateAvsExtractRequest(id, profile, effectiveNow, l),
      AgentTaskType.lppCertificateRequest =>
        _generateLppCertificateRequest(id, profile, effectiveNow, l),
    };

    // Safety gate — block if violations detected
    final safety = AgentSafetyGate.validate(task, isSafeMode: isSafeMode);
    if (!safety.passed) {
      final effectivePrefs = prefs ?? await SharedPreferences.getInstance();
      await _appendAudit(
        AgentAuditEntry(
          timestamp: effectiveNow,
          taskId: id,
          action: 'blocked',
          details: safety.violations,
        ),
        effectivePrefs,
      );
      throw StateError(
        'SafetyGate blocked task $id: ${safety.violations.join('; ')}',
      );
    }

    // Persist
    final effectivePrefs = prefs ?? await SharedPreferences.getInstance();
    await _persistTask(task, effectivePrefs);

    // Audit trail
    await _appendAudit(
      AgentAuditEntry(
        timestamp: effectiveNow,
        taskId: id,
        action: 'generated',
        details: ['type=${type.name}'],
      ),
      effectivePrefs,
    );

    return task;
  }

  /// User validates (approve or reject) a task.
  /// Audit entry is logged for every validation action.
  static Future<AgentTask> validateTask({
    required String taskId,
    required bool approved,
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final effectivePrefs = prefs ?? await SharedPreferences.getInstance();
    final effectiveNow = now ?? DateTime.now();
    final history = await _loadHistory(effectivePrefs);

    final index = history.indexWhere((t) => t.id == taskId);
    if (index == -1) {
      throw StateError('Task $taskId not found in history');
    }

    final updated = history[index].copyWith(
      status:
          approved ? AgentTaskStatus.validated : AgentTaskStatus.rejected,
      validatedAt: effectiveNow,
    );

    history[index] = updated;
    await _saveHistory(history, effectivePrefs);

    // Audit trail
    await _appendAudit(
      AgentAuditEntry(
        timestamp: effectiveNow,
        taskId: taskId,
        action: approved ? 'validated' : 'rejected',
      ),
      effectivePrefs,
    );

    return updated;
  }

  /// Get task history, marking expired tasks.
  static Future<List<AgentTask>> getHistory({
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final effectivePrefs = prefs ?? await SharedPreferences.getInstance();
    final effectiveNow = now ?? DateTime.now();
    final history = await _loadHistory(effectivePrefs);

    // Mark expired tasks
    var changed = false;
    for (var i = 0; i < history.length; i++) {
      if (history[i].status == AgentTaskStatus.pendingValidation &&
          effectiveNow.difference(history[i].createdAt) >
              expirationDuration) {
        history[i] = history[i].copyWith(status: AgentTaskStatus.expired);
        changed = true;
        await _appendAudit(
          AgentAuditEntry(
            timestamp: effectiveNow,
            taskId: history[i].id,
            action: 'expired',
          ),
          effectivePrefs,
        );
      }
    }
    if (changed) {
      await _saveHistory(history, effectivePrefs);
    }

    return history;
  }

  /// Retrieve the full audit log. Every agent action is recorded.
  static Future<List<AgentAuditEntry>> getAuditLog({
    SharedPreferences? prefs,
  }) async {
    final effectivePrefs = prefs ?? await SharedPreferences.getInstance();
    return _loadAuditLog(effectivePrefs);
  }

  /// SAFETY: check if task requires validation. ALWAYS true.
  /// NON-NEGOTIABLE.
  static bool requiresValidation(AgentTask task) => true;

  // ─────────────────────────────────────────────────────────────
  //  TASK GENERATORS
  // ─────────────────────────────────────────────────────────────

  static AgentTask _generateTaxDeclaration(
    String id,
    CoachProfile profile,
    DateTime now,
    S? l,
  ) {
    final revenuBrut = profile.revenuBrutAnnuel;
    final revenuRange = _toRange(revenuBrut);
    final canton = profile.canton.isNotEmpty
        ? profile.canton
        : (l?.agentFormCantonFallback ?? '[canton]');
    final civilStatus = _civilStatusLabel(profile.etatCivil, l);

    final deduction3a = _plafond3a(profile);
    final rachatLpp = profile.prevoyance.lacuneRachatRestante;
    final rachatRange = rachatLpp > 0 ? _toRange(rachatLpp) : '0';

    final fields = <String, String>{
      l?.agentFormRevenuBrut ?? 'Revenu brut estimé':
          l?.agentFieldRevenuBrutValue(revenuRange) ??
              '~$revenuRange\u00a0CHF/an',
      l?.agentFormCanton ?? 'Canton de domicile': canton,
      l?.agentFormSituationFamiliale ?? 'Situation familiale': civilStatus,
      l?.agentFormNbEnfants ?? "Nombre d'enfants":
          '${profile.nombreEnfants}',
      l?.agentFormDeduction3a ?? 'Déduction 3a possible':
          '~${_formatAmount(deduction3a)}\u00a0CHF',
      l?.agentFormRachatLppDeductible ?? 'Rachat LPP déductible estimé':
          l?.agentFieldRachatLppValue(rachatRange) ??
              '~$rachatRange\u00a0CHF',
      l?.agentFormStatutProfessionnel ?? 'Statut professionnel':
          _employmentStatusLabel(profile.employmentStatus, l),
    };

    return AgentTask(
      id: id,
      type: AgentTaskType.taxDeclarationPreFill,
      status: AgentTaskStatus.pendingValidation,
      createdAt: now,
      title: l?.agentTaskTaxDeclarationTitle ??
          'Pré-remplissage déclaration fiscale',
      description: l?.agentTaskTaxDeclarationDesc ??
          "Estimation des champs principaux de ta déclaration d'impôts "
              'basée sur ton profil MINT. Tous les montants sont approximatifs.',
      preFilledFields: fields,
      fieldsNeedingReview: fields.keys.toList(),
      disclaimer: l?.agentTaskDisclaimer ?? _defaultDisclaimerFr,
      sources: [
        'LIFD art.\u00a021-33 (revenu imposable)',
        'LIFD art.\u00a033 (déductions)',
        'OPP3 art.\u00a07 (plafond 3a)',
        'LPP art.\u00a079b (rachat)',
      ],
      validationPrompt:
          l?.agentTaskValidationPromptDefault ?? _defaultValidationPromptFr,
    );
  }

  static AgentTask _generateThreeAForm(
    String id,
    CoachProfile profile,
    DateTime now,
    S? l,
  ) {
    final plafond = _plafond3a(profile);
    final isIndependantSansLpp =
        profile.employmentStatus == 'independant' && !_hasLpp(profile);
    final typeContrat = isIndependantSansLpp
        ? (l?.agentFormTypeContratIndependant ?? 'Indépendant·e sans LPP')
        : (l?.agentFormTypeContratSalarie ?? 'Salarié·e avec LPP');

    final fields = <String, String>{
      l?.agentFormBeneficiaireNom ?? 'Nom du/de la bénéficiaire':
          l?.agentFormToComplete ?? '[À compléter]',
      l?.agentFormNumeroCompte3a ?? 'Numéro de compte 3a':
          l?.agentFormToComplete ?? '[À compléter]',
      l?.agentFormMontantVersementLabel ?? 'Montant versement annuel':
          '~${_formatAmount(plafond)}\u00a0CHF (plafond applicable)',
      l?.agentFormTypeContrat ?? 'Type de contrat': typeContrat,
    };

    return AgentTask(
      id: id,
      type: AgentTaskType.threeAFormPreFill,
      status: AgentTaskStatus.pendingValidation,
      createdAt: now,
      title: l?.agentTaskThreeAFormTitle ?? 'Pré-remplissage formulaire 3a',
      description: l?.agentTaskThreeAFormDesc ??
          'Informations de base pour un versement 3e\u00a0pilier. '
              'Le plafond est calculé selon ton statut professionnel.',
      preFilledFields: fields,
      fieldsNeedingReview: fields.keys.toList(),
      disclaimer: l?.agentTaskDisclaimer ?? _defaultDisclaimerFr,
      sources: [
        'OPP3 art.\u00a07 (plafond 3a)',
        "LPP art.\u00a07 (seuil d'accès)",
      ],
      validationPrompt:
          l?.agentTaskValidationPromptDefault ?? _defaultValidationPromptFr,
    );
  }

  static AgentTask _generateCaisseLetter(
    String id,
    CoachProfile profile,
    DateTime now,
    S? l,
  ) {
    final caisse =
        profile.prevoyance.nomCaisse ?? '[Nom de la caisse de pension]';
    final year = now.year;

    // Formal "vous" — outgoing correspondence
    final letter = '''
[Votre prénom et nom]
[Votre adresse]
[Code postal et ville]

$caisse
[Adresse de la caisse]
[Code postal et ville]

[Lieu], le ${now.day}.${now.month}.$year

Objet\u00a0: Demande de certificat de prévoyance et simulation

Madame, Monsieur,

Par la présente, je me permets de vous adresser les demandes suivantes concernant mon dossier de prévoyance professionnelle\u00a0:

1. Certificat de prévoyance actuel (avoir de vieillesse, prestations couvertes, taux de conversion applicable)

2. Confirmation de ma capacité de rachat (montant maximal de rachat selon l'art.\u00a079b LPP)

3. Simulation de retraite anticipée (projection de l'avoir et de la rente à\u00a063 et 64\u00a0ans, le cas échéant)

Je vous remercie par avance de votre diligence et reste à votre disposition pour tout complément d'information.

Veuillez agréer, Madame, Monsieur, mes salutations distinguées.

[Votre signature]
[Numéro de police\u00a0: À compléter]''';

    final fields = <String, String>{
      l?.agentFieldCaissePension ?? 'Caisse de pension': caisse,
      l?.agentFieldAnneRef ?? 'Année de référence': '$year',
    };

    return AgentTask(
      id: id,
      type: AgentTaskType.caisseLetterGeneration,
      status: AgentTaskStatus.pendingValidation,
      createdAt: now,
      title: l?.agentTaskCaisseLetterTitle ?? 'Lettre à la caisse de pension',
      description: l?.agentTaskCaisseLetterDesc ??
          'Modèle de lettre formelle pour demander un certificat LPP, '
              'une confirmation de rachat et une simulation de retraite anticipée.',
      preFilledFields: fields,
      fieldsNeedingReview: [
        ...fields.keys,
        l?.agentFieldAddressPerso ?? 'Adresse personnelle',
        l?.agentFieldAddresseCaisse ?? 'Adresse de la caisse',
        l?.agentFieldNumeroPolice ?? 'Numéro de police',
      ],
      generatedDocument: letter,
      disclaimer: l?.agentTaskDisclaimer ?? _defaultDisclaimerFr,
      sources: [
        'LPP art.\u00a079b (rachat)',
        'LPP art.\u00a013 (retraite anticipée)',
        'LPP art.\u00a014 (taux de conversion)',
      ],
      validationPrompt:
          l?.agentTaskValidationPromptLetter ?? _letterValidationPromptFr,
    );
  }

  static AgentTask _generateFiscalDossier(
    String id,
    CoachProfile profile,
    DateTime now,
    S? l,
  ) {
    final revenuRange = _toRange(profile.revenuBrutAnnuel);
    final canton = profile.canton.isNotEmpty ? profile.canton : '[canton]';
    final plafond3a = _plafond3a(profile);
    final rachat = profile.prevoyance.lacuneRachatRestante;
    final epargne3a = profile.prevoyance.totalEpargne3a;

    final dossier = '''
═══════════════════════════════════════════
  DOSSIER FISCAL ÉDUCATIF — Estimations
  Généré le ${now.day}.${now.month}.${now.year}
═══════════════════════════════════════════

1. SITUATION FISCALE ESTIMÉE
   • Revenu brut annuel\u00a0: ~$revenuRange\u00a0CHF
   • Canton\u00a0: $canton
   • Situation familiale\u00a0: ${_civilStatusLabel(profile.etatCivil, l)}
   • Enfants\u00a0: ${profile.nombreEnfants}

2. DÉDUCTIONS POSSIBLES
   • 3e\u00a0pilier (3a)\u00a0: jusqu'à ~${_formatAmount(plafond3a)}\u00a0CHF/an
   • Rachat LPP estimé\u00a0: ~${_formatAmount(rachat)}\u00a0CHF disponibles
   • Frais professionnels\u00a0: selon barème cantonal ($canton)

3. POINTS D'ATTENTION
   • Capital 3a accumulé\u00a0: ~${_formatAmount(epargne3a)}\u00a0CHF
     → Planifier l'échelonnement des retraits sur plusieurs années
   • Retrait en capital = imposé séparément (LIFD art.\u00a038)
   • Rente LPP = revenu imposable annuel (LIFD art.\u00a022)

4. QUESTIONS POUR LE/LA SPÉCIALISTE FISCAL·E
   • Quel est l'impact fiscal d'un rachat LPP cette année\u00a0?
   • Faut-il échelonner les retraits 3a sur combien d'années\u00a0?
   • Y a-t-il des déductions cantonales ($canton) non exploitées\u00a0?

═══════════════════════════════════════════
  ESTIMATION INDICATIVE — Ne constitue pas
  un conseil fiscal. Consultez un·e
  spécialiste agréé·e. (LSFin)
═══════════════════════════════════════════''';

    final fields = <String, String>{
      l?.agentFiscalDossierRevenu ?? 'Revenu brut estimé':
          l?.agentFieldRevenuBrutValue(revenuRange) ??
              '~$revenuRange\u00a0CHF/an',
      l?.agentFormCanton ?? 'Canton': canton,
      l?.agentFiscalDossierPlafond3a ?? 'Plafond 3a applicable':
          '~${_formatAmount(plafond3a)}\u00a0CHF',
      l?.agentFiscalDossierRachat ?? 'Rachat LPP disponible':
          '~${_formatAmount(rachat)}\u00a0CHF',
      l?.agentFiscalDossierCapital3a ?? 'Capital 3a accumulé':
          '~${_formatAmount(epargne3a)}\u00a0CHF',
    };

    return AgentTask(
      id: id,
      type: AgentTaskType.fiscalDossierPrep,
      status: AgentTaskStatus.pendingValidation,
      createdAt: now,
      title:
          l?.agentTaskFiscalDossierTitle ?? 'Préparation dossier fiscal',
      description: l?.agentTaskFiscalDossierDesc ??
          'Résumé éducatif de ta situation fiscale estimée avec les '
              "déductions possibles et les questions à poser à un·e spécialiste.",
      preFilledFields: fields,
      fieldsNeedingReview: fields.keys.toList(),
      generatedDocument: dossier,
      disclaimer: l?.agentTaskDisclaimer ?? _defaultDisclaimerFr,
      sources: [
        'LIFD art.\u00a021-33 (revenu imposable)',
        'LIFD art.\u00a022 (rente LPP)',
        'LIFD art.\u00a033 (déductions)',
        'LIFD art.\u00a038 (retrait en capital)',
        'OPP3 art.\u00a07 (plafond 3a)',
        'LPP art.\u00a079b (rachat)',
      ],
      validationPrompt:
          l?.agentTaskValidationPromptDefault ?? _defaultValidationPromptFr,
    );
  }

  static AgentTask _generateAvsExtractRequest(
    String id,
    CoachProfile profile,
    DateTime now,
    S? l,
  ) {
    final year = now.year;

    final letter = '''
[Votre prénom et nom]
[Votre numéro AVS\u00a0: 756.XXXX.XXXX.XX]
[Votre adresse]
[Code postal et ville]

Caisse de compensation AVS compétente
[Adresse]
[Code postal et ville]

[Lieu], le ${now.day}.${now.month}.$year

Objet\u00a0: Demande d'extrait de compte individuel (CI)

Madame, Monsieur,

Je vous prie de bien vouloir m'adresser un extrait de mon compte individuel AVS (CI) afin de vérifier l'état de mes cotisations et d'identifier d'éventuelles lacunes.

Je vous remercie par avance de votre diligence.

Veuillez agréer, Madame, Monsieur, mes salutations distinguées.

[Votre signature]''';

    final canton = profile.canton.isNotEmpty
        ? profile.canton
        : (l?.agentFormCantonFallback ?? '[canton]');
    final fields = <String, String>{
      l?.agentFormCanton ?? 'Canton de domicile': canton,
      l?.agentFieldAnneRef ?? 'Année de référence': '$year',
    };

    return AgentTask(
      id: id,
      type: AgentTaskType.avsExtractRequest,
      status: AgentTaskStatus.pendingValidation,
      createdAt: now,
      title: l?.agentTaskAvsExtractTitle ?? "Demande d'extrait AVS",
      description: l?.agentTaskAvsExtractDesc ??
          'Modèle de lettre pour demander un extrait de compte individuel '
              '(CI) auprès de ta caisse de compensation AVS.',
      preFilledFields: fields,
      fieldsNeedingReview: [
        ...fields.keys,
        l?.agentFieldNumeroAvs ?? 'Numéro AVS',
        l?.agentFieldAddressPerso ?? 'Adresse personnelle',
        l?.agentFieldAddresseCaisseAvs ?? 'Adresse de la caisse AVS',
      ],
      generatedDocument: letter,
      disclaimer: l?.agentTaskDisclaimer ?? _defaultDisclaimerFr,
      sources: [
        'LAVS art.\u00a030ter (compte individuel)',
        'RAVS art.\u00a0139 (extrait CI)',
      ],
      validationPrompt:
          l?.agentTaskValidationPromptRequest ?? _requestValidationPromptFr,
    );
  }

  static AgentTask _generateLppCertificateRequest(
    String id,
    CoachProfile profile,
    DateTime now,
    S? l,
  ) {
    final caisse =
        profile.prevoyance.nomCaisse ?? '[Nom de la caisse de pension]';
    final year = now.year;

    final letter = '''
[Votre prénom et nom]
[Votre adresse]
[Code postal et ville]

$caisse
[Adresse de la caisse]
[Code postal et ville]

[Lieu], le ${now.day}.${now.month}.$year

Objet\u00a0: Demande de certificat de prévoyance $year

Madame, Monsieur,

Je souhaite recevoir mon certificat de prévoyance professionnelle actualisé pour l'année $year, comprenant\u00a0:

• L'avoir de vieillesse acquis (part obligatoire et surobligatoire)
• Les prestations couvertes (invalidité, décès, vieillesse)
• Le taux de conversion applicable
• La capacité de rachat disponible

Je vous remercie de votre diligence.

Veuillez agréer, Madame, Monsieur, mes salutations distinguées.

[Votre signature]
[Numéro de police\u00a0: À compléter]''';

    final fields = <String, String>{
      l?.agentFieldCaissePension ?? 'Caisse de pension': caisse,
      l?.agentFieldAnneRef ?? 'Année de référence': '$year',
    };

    return AgentTask(
      id: id,
      type: AgentTaskType.lppCertificateRequest,
      status: AgentTaskStatus.pendingValidation,
      createdAt: now,
      title: l?.agentTaskLppCertificateTitle ?? 'Demande certificat LPP',
      description: l?.agentTaskLppCertificateDesc ??
          'Modèle de lettre pour demander un certificat de prévoyance '
              'professionnelle actualisé à ta caisse de pension.',
      preFilledFields: fields,
      fieldsNeedingReview: [
        ...fields.keys,
        l?.agentFieldAddressPerso ?? 'Adresse personnelle',
        l?.agentFieldAddresseCaisse ?? 'Adresse de la caisse',
        l?.agentFieldNumeroPolice ?? 'Numéro de police',
      ],
      generatedDocument: letter,
      disclaimer: l?.agentTaskDisclaimer ?? _defaultDisclaimerFr,
      sources: [
        "LPP art.\u00a086b (obligation d'informer)",
        'OPP2 art.\u00a0148 (certificat de prévoyance)',
      ],
      validationPrompt:
          l?.agentTaskValidationPromptRequest ?? _requestValidationPromptFr,
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────

  /// Round to nearest 5'000 range to avoid exposing exact salary.
  static String _toRange(double value) {
    if (value <= 0) return '0';
    const step = 5000;
    final lower = (value / step).floor() * step;
    final upper = lower + step;
    return '${_formatAmount(lower.toDouble())}-${_formatAmount(upper.toDouble())}';
  }

  /// Format amount with Swiss apostrophe thousands separator.
  static String _formatAmount(double amount) {
    final rounded = amount.round();
    if (rounded == 0) return '0';
    final str = rounded.toString();
    final buffer = StringBuffer();
    var count = 0;
    for (var i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0 && str[i - 1] != '-') {
        buffer.write("'");
      }
    }
    return buffer.toString().split('').reversed.join();
  }

  /// Determine 3a plafond based on employment status and LPP.
  static double _plafond3a(CoachProfile profile) {
    if (profile.employmentStatus == 'independant' && !_hasLpp(profile)) {
      return reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp);
    }
    return reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp);
  }

  /// Check if profile has LPP.
  static bool _hasLpp(CoachProfile profile) {
    final avoir = profile.prevoyance.avoirLppTotal ?? 0;
    return avoir > 0 || profile.prevoyance.nomCaisse != null;
  }

  static String _civilStatusLabel(
    CoachCivilStatus status,
    S? l,
  ) {
    return switch (status) {
      CoachCivilStatus.celibataire =>
        l?.agentFormCivilCelibataire ?? 'Célibataire',
      CoachCivilStatus.marie => l?.agentFormCivilMarie ?? 'Marié·e',
      CoachCivilStatus.divorce => l?.agentFormCivilDivorce ?? 'Divorcé·e',
      CoachCivilStatus.veuf => l?.agentFormCivilVeuf ?? 'Veuf·ve',
      CoachCivilStatus.concubinage =>
        l?.agentFormCivilConcubinage ?? 'Concubinage',
    };
  }

  static String _employmentStatusLabel(String status, S? l) {
    return switch (status) {
      'salarie' => l?.agentFormEmplSalarie ?? 'Salarié·e',
      'independant' => l?.agentFormEmplIndependant ?? 'Indépendant·e',
      'chomage' =>
        l?.agentFormEmplChomage ?? "En recherche d'emploi",
      'retraite' => l?.agentFormEmplRetraite ?? 'Retraité·e',
      _ => status,
    };
  }

  // ─────────────────────────────────────────────────────────────
  //  PERSISTENCE
  // ─────────────────────────────────────────────────────────────

  static Future<void> _persistTask(
    AgentTask task,
    SharedPreferences prefs,
  ) async {
    final history = await _loadHistory(prefs);
    history.add(task);
    await _saveHistory(history, prefs);
  }

  static Future<List<AgentTask>> _loadHistory(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => AgentTask.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> _saveHistory(
    List<AgentTask> history,
    SharedPreferences prefs,
  ) async {
    final json = jsonEncode(history.map((t) => t.toJson()).toList());
    await prefs.setString(_storageKey, json);
  }

  // ─────────────────────────────────────────────────────────────
  //  AUDIT LOG PERSISTENCE
  // ─────────────────────────────────────────────────────────────

  static Future<void> _appendAudit(
    AgentAuditEntry entry,
    SharedPreferences prefs,
  ) async {
    final log = await _loadAuditLog(prefs);
    log.add(entry);
    final json = jsonEncode(log.map((e) => e.toJson()).toList());
    await prefs.setString(_auditKey, json);
  }

  static Future<List<AgentAuditEntry>> _loadAuditLog(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_auditKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => AgentAuditEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
