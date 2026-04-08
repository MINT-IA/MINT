// GENERATED — DO NOT EDIT — source: tools/contracts/voice_cursor.json
// Run `bash tools/contracts/regenerate.sh` to refresh.
// Edits to this file will be reverted by the contracts-drift CI gate.

const String voiceCursorContractVersion = "0.5.0";

enum VoiceLevel { n1, n2, n3, n4, n5 }
enum Gravity { g1, g2, g3 }
enum Relation { relNew, established, intimate }
enum VoicePreference { soft, direct, unfiltered }

const Map<Gravity, Map<Relation, Map<VoicePreference, VoiceLevel>>> voiceCursorMatrix = {
  Gravity.g1: {
    Relation.established: {
      VoicePreference.direct: VoiceLevel.n2,
      VoicePreference.soft: VoiceLevel.n2,
      VoicePreference.unfiltered: VoiceLevel.n2,
    },
    Relation.intimate: {
      VoicePreference.direct: VoiceLevel.n3,
      VoicePreference.soft: VoiceLevel.n2,
      VoicePreference.unfiltered: VoiceLevel.n3,
    },
    Relation.relNew: {
      VoicePreference.direct: VoiceLevel.n1,
      VoicePreference.soft: VoiceLevel.n1,
      VoicePreference.unfiltered: VoiceLevel.n2,
    },
  },
  Gravity.g2: {
    Relation.established: {
      VoicePreference.direct: VoiceLevel.n4,
      VoicePreference.soft: VoiceLevel.n3,
      VoicePreference.unfiltered: VoiceLevel.n4,
    },
    Relation.intimate: {
      VoicePreference.direct: VoiceLevel.n4,
      VoicePreference.soft: VoiceLevel.n3,
      VoicePreference.unfiltered: VoiceLevel.n4,
    },
    Relation.relNew: {
      VoicePreference.direct: VoiceLevel.n2,
      VoicePreference.soft: VoiceLevel.n2,
      VoicePreference.unfiltered: VoiceLevel.n2,
    },
  },
  Gravity.g3: {
    Relation.established: {
      VoicePreference.direct: VoiceLevel.n5,
      VoicePreference.soft: VoiceLevel.n4,
      VoicePreference.unfiltered: VoiceLevel.n5,
    },
    Relation.intimate: {
      VoicePreference.direct: VoiceLevel.n5,
      VoicePreference.soft: VoiceLevel.n4,
      VoicePreference.unfiltered: VoiceLevel.n5,
    },
    Relation.relNew: {
      VoicePreference.direct: VoiceLevel.n4,
      VoicePreference.soft: VoiceLevel.n4,
      VoicePreference.unfiltered: VoiceLevel.n4,
    },
  },
};

const List<String> sensitiveTopics = <String>["deuil", "divorce", "perteEmploi", "maladieGrave", "suicide", "violenceConjugale", "faillitePersonnelle", "endettementAbusif", "dependance", "handicapAcquis"];
const List<String> narratorWallExemptions = <String>["settings", "errorToasts", "networkFailures", "legalDisclaimers", "onboardingSystemText", "compliance", "consentDialogs", "permissionPrompts"];
const List<String> voiceCursorPrecedenceCascade = <String>["sensitivityGuard", "fragilityCap", "n5WeeklyBudget", "gravityFloor", "preferenceCap", "matrixDefault"];

const int n5PerWeekMax = 1;
const int fragileModeDurationDays = 30;
const VoiceLevel fragileModeCapLevel = VoiceLevel.n3;
const VoiceLevel sensitiveTopicCapLevel = VoiceLevel.n3;
const VoiceLevel g3FloorLevel = VoiceLevel.n2;
