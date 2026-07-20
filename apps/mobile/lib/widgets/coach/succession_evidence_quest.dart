import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/swiss_civil_time.dart';
import 'package:provider/provider.dart';

/// Bounded, progressive consumer of the strict succession reference ledger.
class SuccessionEvidenceQuest extends StatefulWidget {
  const SuccessionEvidenceQuest({super.key});

  @override
  State<SuccessionEvidenceQuest> createState() =>
      _SuccessionEvidenceQuestState();
}

class _SuccessionEvidenceQuestState extends State<SuccessionEvidenceQuest> {
  bool _inFlight = false;
  bool _saved = false;
  bool _editingPresent = false;
  String _sourceDate = '';
  String _legalYear = '';
  _QuestError? _error;
  MatrimonialRegimeKind? _marriage;
  RegisteredPartnershipPropertyRegimeKind? _lpart;
  EstateInstrumentKind? _reviewKind;

  Future<void> _run(
    CoachProfileProvider provider,
    Future<void> Function() write,
  ) async {
    setState(() {
      _inFlight = true;
      _error = null;
    });
    try {
      await write();
      if (mounted) setState(() => _saved = true);
    } on StateError {
      try {
        await provider.loadFromWizard();
      } catch (_) {
        // The changed-data state remains explicit even if reload also fails.
      }
      if (mounted) setState(() => _error = _QuestError.changed);
    } on ArgumentError {
      if (mounted) setState(() => _error = _QuestError.validation);
    } catch (_) {
      if (mounted) setState(() => _error = _QuestError.persistence);
    } finally {
      if (mounted) setState(() => _inFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final provider = context.watch<CoachProfileProvider>();
    final profile = provider.profile;
    return Card(
      key: const Key('succession_reference_quest'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: profile == null
            ? _message(
                l.successionQuestUnloaded,
                buttonKey: 'succession_reference_retry',
                button: l.successionQuestReload,
                onPressed: provider.isLoading ? null : provider.loadFromWizard,
              )
            : _content(provider, profile, l),
      ),
    );
  }

  Widget _content(
    CoachProfileProvider provider,
    CoachProfile profile,
    S l,
  ) {
    if (profile.civilStatusNeedsConfirmation) {
      return _message(
        l.successionQuestCivilGuard,
        key: 'succession_civil_status_guard',
        buttonKey: 'succession_civil_status_confirm',
        button: l.successionQuestConfirm,
        onPressed: () => context.push(
          '/data-block/composition_menage?inputKey=q_civil_status&returnUri=/succession',
        ),
      );
    }
    final state = profile.estateReferenceStateAt(DateTime.now());
    if (state == EstateReferenceState.invalid) {
      return _message(
        l.successionQuestInvalidRoot,
        key: 'succession_reference_invalid',
        buttonKey: 'succession_reference_reload',
        button: l.successionQuestReload,
        onPressed: provider.isLoading ? null : provider.loadFromWizard,
      );
    }
    if (_saved) {
      return _message(
        l.successionQuestSaved,
        key: 'succession_answer_saved',
        buttonKey: 'succession_next_question',
        button: l.successionQuestNext,
        onPressed: () => setState(() {
          _saved = false;
          _editingPresent = false;
          _sourceDate = '';
          _legalYear = '';
          _reviewKind = null;
        }),
      );
    }
    if (profile.currentEstateArrangementApplicability ==
        EstateArrangementApplicability.unknown) {
      return _arrangement(provider, profile, l);
    }

    final priorUnion = profile.etatCivil == CoachCivilStatus.divorce ||
        profile.etatCivil == CoachCivilStatus.veuf;
    final slots = [...profile.estateInstrumentSlots]..sort((a, b) {
        int rank(EstateInstrumentSlotState state) =>
            state == EstateInstrumentSlotState.stale
                ? 0
                : state == EstateInstrumentSlotState.unknown
                    ? 1
                    : 2;
        final byState = rank(a.state).compareTo(rank(b.state));
        return byState != 0 ? byState : a.kind.index.compareTo(b.kind.index);
      });
    final pending = slots
        .where(
          (slot) =>
              slot.state == EstateInstrumentSlotState.stale ||
              slot.state == EstateInstrumentSlotState.unknown,
        )
        .firstOrNull;
    final reviewed = _reviewKind == null
        ? null
        : slots.where((slot) => slot.kind == _reviewKind).single;
    final question = reviewed != null
        ? _instrument(provider, reviewed, l)
        : pending != null
            ? _instrument(provider, pending, l)
            : _terminalSummary(slots, l);
    if (!priorUnion) return question;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.successionQuestPriorUnion,
          key: const Key('succession_prior_union_specialist_question'),
        ),
        const SizedBox(height: 12),
        question,
      ],
    );
  }

  Widget _arrangement(
    CoachProfileProvider provider,
    CoachProfile profile,
    S l,
  ) {
    final married = profile.etatCivil == CoachCivilStatus.marie;
    final previousId = married
        ? profile.matrimonialRegimeConfirmation?.confirmationId
        : profile.registeredPartnershipPropertyRegime?.confirmationId;
    return Column(
      key: const Key('succession_arrangement_question'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          married
              ? l.successionQuestMarriageQuestion
              : l.successionQuestLpartQuestion,
        ),
        DropdownButton<Enum>(
          key: const Key('succession_arrangement_enum'),
          value: married ? _marriage : _lpart,
          isExpanded: true,
          items: (married
                  ? MatrimonialRegimeKind.values
                  : RegisteredPartnershipPropertyRegimeKind.values)
              .map(
                (value) => DropdownMenuItem<Enum>(
                  value: value,
                  child: Text(_arrangementLabel(value, l)),
                ),
              )
              .toList(),
          onChanged: _inFlight
              ? null
              : (value) => setState(() {
                    if (value is MatrimonialRegimeKind) _marriage = value;
                    if (value is RegisteredPartnershipPropertyRegimeKind) {
                      _lpart = value;
                    }
                  }),
        ),
        ElevatedButton(
          key: const Key('succession_arrangement_save'),
          onPressed: _inFlight || (married ? _marriage == null : _lpart == null)
              ? null
              : () => _run(
                    provider,
                    () => married
                        ? provider.confirmMatrimonialRegime(
                            _marriage!,
                            expectedPreviousConfirmationId: previousId,
                          )
                        : provider.confirmRegisteredPartnershipPropertyRegime(
                            kind: _lpart!,
                            expectedPreviousConfirmationId: previousId,
                          ),
                  ),
          child: Text(l.successionQuestSave),
        ),
        _errorWidget(l),
      ],
    );
  }

  Widget _instrument(
    CoachProfileProvider provider,
    EstateInstrumentSlot slot,
    S l,
  ) {
    final prefix = 'succession_instrument_${slot.kind.name}';
    final evidenceId = slot.evidenceId;
    final stale = slot.state == EstateInstrumentSlotState.stale;
    final reviewing =
        slot.state == EstateInstrumentSlotState.confirmedPresent ||
            slot.state == EstateInstrumentSlotState.confirmedAbsent;
    return Column(
      key: Key('${prefix}_question'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_instrumentLabel(slot.kind, l)),
        if (stale) Text(l.successionQuestStale, key: Key('${prefix}_stale')),
        if (stale || reviewing) _priorState(slot, l, prefix),
        if (!stale && !reviewing) Text(l.successionQuestUnknown),
        Text(l.successionQuestGuidance),
        if (stale)
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                key: Key('${prefix}_reconfirm'),
                onPressed: _inFlight
                    ? null
                    : () => _run(
                          provider,
                          () => slot.evidence != null
                              ? provider.confirmEstateInstrumentPresent(
                                  kind: slot.kind,
                                  sourceDate: slot.evidence!.sourceDate,
                                  legalYear: slot.evidence!.legalYear,
                                  expectedPreviousEvidenceId: evidenceId,
                                )
                              : provider.confirmEstateInstrumentAbsent(
                                  kind: slot.kind,
                                  expectedPreviousEvidenceId: evidenceId,
                                ),
                        ),
                child: Text(l.successionQuestReconfirm),
              ),
              OutlinedButton(
                key: Key('${prefix}_present'),
                onPressed: _inFlight
                    ? null
                    : () => setState(() => _editingPresent = true),
                child: Text(l.successionQuestModify),
              ),
            ],
          )
        else
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                key: Key('${prefix}_absent'),
                onPressed: _inFlight
                    ? null
                    : () => _run(
                          provider,
                          () => provider.confirmEstateInstrumentAbsent(
                            kind: slot.kind,
                            expectedPreviousEvidenceId: evidenceId,
                          ),
                        ),
                child: Text(l.successionQuestAbsent),
              ),
              OutlinedButton(
                key: Key('${prefix}_present'),
                onPressed: _inFlight
                    ? null
                    : () => setState(() => _editingPresent = true),
                child: Text(
                  reviewing
                      ? l.successionQuestModify
                      : l.successionQuestPresent,
                ),
              ),
            ],
          ),
        if (_editingPresent) ...[
          if (stale)
            OutlinedButton(
              key: Key('${prefix}_absent'),
              onPressed: _inFlight
                  ? null
                  : () => _run(
                        provider,
                        () => provider.confirmEstateInstrumentAbsent(
                          kind: slot.kind,
                          expectedPreviousEvidenceId: evidenceId,
                        ),
                      ),
              child: Text(l.successionQuestAbsent),
            ),
          TextField(
            key: Key('${prefix}_source_date'),
            decoration: InputDecoration(labelText: l.successionQuestDateLabel),
            onChanged: (value) => _sourceDate = value,
          ),
          TextField(
            key: Key('${prefix}_legal_year'),
            decoration: InputDecoration(labelText: l.successionQuestYearLabel),
            keyboardType: TextInputType.number,
            onChanged: (value) => _legalYear = value,
          ),
          ElevatedButton(
            key: Key('${prefix}_save'),
            onPressed: _inFlight
                ? null
                : () {
                    final date =
                        SwissCivilTime.parseCanonicalCivilDate(_sourceDate);
                    final year = int.tryParse(_legalYear);
                    if (date == null || year == null) {
                      setState(() => _error = _QuestError.validation);
                      return;
                    }
                    _run(
                      provider,
                      () => provider.confirmEstateInstrumentPresent(
                        kind: slot.kind,
                        sourceDate: date,
                        legalYear: year,
                        expectedPreviousEvidenceId: evidenceId,
                      ),
                    );
                  },
            child: Text(l.successionQuestSave),
          ),
        ],
        _errorWidget(l, prefix: prefix),
      ],
    );
  }

  Widget _priorState(EstateInstrumentSlot slot, S l, String prefix) {
    final evidence = slot.evidence;
    final absence = slot.absenceConfirmation;
    return Column(
      key: Key('${prefix}_prior_state'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          evidence != null
              ? l.successionQuestPriorPresent
              : l.successionQuestPriorAbsent,
        ),
        if (evidence != null) ...[
          Text(evidence.sourceDate.toIso8601String().split('T').first),
          Text('${evidence.legalYear}'),
          Text(l.successionQuestPriorEffectsCaveat),
        ],
        if (absence != null) ...[
          Text(absence.confirmedAt.toIso8601String().split('T').first),
          Text(l.successionQuestPriorAbsenceCaveat),
        ],
      ],
    );
  }

  Widget _terminalSummary(List<EstateInstrumentSlot> slots, S l) {
    return Column(
      key: const Key('succession_reference_survey_recorded'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.successionQuestSurveyRecorded),
        Text(l.successionQuestTerminalCaveat),
        for (final slot in slots)
          Card(
            key: Key('succession_instrument_${slot.kind.name}_summary'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_instrumentLabel(slot.kind, l)),
                  _priorState(
                    slot,
                    l,
                    'succession_instrument_${slot.kind.name}_summary',
                  ),
                  TextButton(
                    key: Key(
                      'succession_instrument_${slot.kind.name}_modify',
                    ),
                    onPressed: () => setState(() {
                      _reviewKind = slot.kind;
                      _editingPresent = false;
                    }),
                    child: Text(l.successionQuestModifySlot),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _arrangementLabel(Enum value, S l) => switch (value) {
        MatrimonialRegimeKind.participationInAcquests =>
          l.successionQuestMarriageParticipation,
        MatrimonialRegimeKind.communityOfProperty =>
          l.successionQuestMarriageCommunity,
        MatrimonialRegimeKind.separationOfProperty =>
          l.successionQuestMarriageSeparation,
        MatrimonialRegimeKind.other => l.successionQuestMarriageOther,
        RegisteredPartnershipPropertyRegimeKind.statutorySeparationOfProperty =>
          l.successionQuestLpartStatutory,
        RegisteredPartnershipPropertyRegimeKind
              .agreedParticipationInAcquestsDivision =>
          l.successionQuestLpartParticipation,
        RegisteredPartnershipPropertyRegimeKind.otherPropertyAgreement =>
          l.successionQuestLpartOther,
        _ => throw StateError('Unsupported arrangement enum'),
      };

  String _instrumentLabel(EstateInstrumentKind kind, S l) => switch (kind) {
        EstateInstrumentKind.will => l.successionQuestInstrumentWill,
        EstateInstrumentKind.inheritancePact =>
          l.successionQuestInstrumentInheritancePact,
        EstateInstrumentKind.incapacityMandate =>
          l.successionQuestInstrumentIncapacityMandate,
        EstateInstrumentKind.advanceCareDirective =>
          l.successionQuestInstrumentAdvanceCareDirective,
      };

  Widget _errorWidget(S l, {String? prefix}) {
    final error = _error;
    if (error == null) return const SizedBox.shrink();
    final key = error == _QuestError.validation
        ? '${prefix ?? 'succession'}_validation_error'
        : '${prefix ?? 'succession'}_save_error';
    final text = switch (error) {
      _QuestError.changed => l.successionQuestChanged,
      _QuestError.validation => l.successionQuestValidation,
      _QuestError.persistence => l.successionQuestSaveError,
    };
    return Text(text, key: Key(key));
  }

  Widget _message(
    String text, {
    String? key,
    String? buttonKey,
    String? button,
    VoidCallback? onPressed,
  }) =>
      Column(
        key: key == null ? null : Key(key),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          if (button != null)
            ElevatedButton(
              key: buttonKey == null ? null : Key(buttonKey),
              onPressed: onPressed,
              child: Text(button),
            ),
        ],
      );
}

enum _QuestError { changed, validation, persistence }
