import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/services/document_parser/lpp_certificate_parser.dart';
import 'package:mint_mobile/services/document_parser/lpp_extraction_adapter.dart';

// Local-only gate (the manifest and source documents stay gitignored):
// MINT_LPP_PRIVATE_MANIFEST=../../test/golden/lpp_private_mobile_manifest.json \
//   flutter test test/services/document_parser/lpp_private_fixture_gate_test.dart
// This is a semantic local-parser oracle only. Backend PDF ingestion is proven
// separately through the real backend endpoint contract.

const _manifestEnvironmentKey = 'MINT_LPP_PRIVATE_MANIFEST';

Never _privateGateFailure(String token, String reason, int factCount) {
  fail('LPP_PRIVATE_GATE token=$token reason=$reason count=$factCount');
}

Future<String> _extractText({
  required File document,
  required String mediaType,
  required String token,
  required int factCount,
}) async {
  final ProcessResult result;
  if (mediaType == 'pdf') {
    result = await Process.run(
      'pdftotext',
      ['-layout', document.path, '-'],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  } else if (mediaType == 'jpeg') {
    result = await Process.run(
      'tesseract',
      [document.path, 'stdout', '-l', 'fra+deu+eng'],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  } else {
    _privateGateFailure(token, 'media_type', factCount);
  }
  if (result.exitCode != 0 || result.stdout is! String) {
    _privateGateFailure(token, 'ocr_tool', factCount);
  }
  return result.stdout as String;
}

Map<String, double> _expectedValues(
  Object? raw,
  String token,
  int factCount,
) {
  if (raw is! Map) _privateGateFailure(token, 'manifest_values', factCount);
  final values = <String, double>{};
  for (final entry in raw.entries) {
    if (entry.key is! String || entry.value is! num) {
      _privateGateFailure(token, 'manifest_values', factCount);
    }
    values[entry.key as String] = (entry.value as num).toDouble();
  }
  return values;
}

List<String> _absentKeys(Object? raw, String token, int factCount) {
  if (raw is! List || raw.any((value) => value is! String)) {
    _privateGateFailure(token, 'manifest_absences', factCount);
  }
  return raw.cast<String>();
}

Future<void> _runPrivateManifest(String manifestLocation) async {
  Map<String, dynamic> manifest;
  Directory manifestDirectory;
  try {
    final manifestFile = File(manifestLocation).absolute;
    manifestDirectory = manifestFile.parent;
    manifest = Map<String, dynamic>.from(
      jsonDecode(await manifestFile.readAsString()) as Map,
    );
  } catch (_) {
    _privateGateFailure('manifest', 'unreadable', 0);
  }
  if (manifest['schemaVersion'] != 1 || manifest['cases'] is! List) {
    _privateGateFailure('manifest', 'schema', 0);
  }

  final cases = manifest['cases'] as List;
  if (cases.isEmpty) _privateGateFailure('manifest', 'empty', 0);
  var positiveCertificates = 0;
  var negativePlans = 0;
  for (var index = 0; index < cases.length; index += 1) {
    final token = 'case_${index + 1}';
    final rawCase = cases[index];
    if (rawCase is! Map) _privateGateFailure(token, 'manifest_case', 0);
    final fixture = Map<String, dynamic>.from(rawCase);
    if (fixture['adapterSource'] != 'localParser') {
      _privateGateFailure(token, 'adapter_source', 0);
    }
    final role = fixture['role'];
    final expectedCount = fixture['expectedFactCount'];
    if (expectedCount is! int || expectedCount < 0) {
      _privateGateFailure(token, 'manifest_count', 0);
    }
    final expectedValues = _expectedValues(
      fixture['expectedValues'],
      token,
      0,
    );
    final absentKeys = _absentKeys(fixture['absentKeys'], token, 0);
    if (role == 'positive_certificate') {
      positiveCertificates += 1;
      if (expectedCount == 0 || expectedValues.isEmpty || absentKeys.isEmpty) {
        _privateGateFailure(token, 'positive_assertions', 0);
      }
    } else if (role == 'negative_plan') {
      negativePlans += 1;
      if (expectedCount != 0 || expectedValues.isNotEmpty) {
        _privateGateFailure(token, 'negative_assertions', 0);
      }
    } else {
      _privateGateFailure(token, 'manifest_role', 0);
    }
    for (final key in <String>{...expectedValues.keys, ...absentKeys}) {
      if (LppEvidenceFactKey.fromWireName(key) == null) {
        _privateGateFailure(token, 'manifest_key', 0);
      }
    }
  }
  if (positiveCertificates < 1 || negativePlans < 2) {
    _privateGateFailure('manifest', 'corpus_roles', 0);
  }

  for (var index = 0; index < cases.length; index += 1) {
    final token = 'case_${index + 1}';
    var factCount = 0;
    try {
      final rawCase = cases[index];
      if (rawCase is! Map) {
        _privateGateFailure(token, 'manifest_case', factCount);
      }
      final fixture = Map<String, dynamic>.from(rawCase);
      final relativeDocument = fixture['document'];
      final mediaType = fixture['mediaType'];
      if (relativeDocument is! String || mediaType is! String) {
        _privateGateFailure(token, 'manifest_case', factCount);
      }
      if (relativeDocument.startsWith(Platform.pathSeparator) ||
          relativeDocument
              .split(RegExp(r'[/\\]'))
              .any((segment) => segment == '..')) {
        _privateGateFailure(token, 'document', factCount);
      }
      final document = File(
        '${manifestDirectory.path}${Platform.pathSeparator}$relativeDocument',
      );
      if (!document.isAbsolute || !await document.exists()) {
        _privateGateFailure(token, 'document', factCount);
      }

      final text = await _extractText(
        document: document,
        mediaType: mediaType,
        token: token,
        factCount: factCount,
      );
      final extraction = LppCertificateParser.parseLppCertificate(text);
      final adaptation = LppExtractionAdapter.adapt(
        source: LppAcquisitionSource.localParser,
        sourceOverallConfidence: extraction.overallConfidence,
        fields: extraction.fields,
      );
      final facts = adaptation.candidate?.facts;
      if (facts == null || adaptation.rejection != null) {
        _privateGateFailure(token, 'adaptation', factCount);
      }
      factCount = facts.length;

      final expectedCount = fixture['expectedFactCount'] as int;
      if (factCount != expectedCount) {
        _privateGateFailure(token, 'fact_count', factCount);
      }
      final tolerance = fixture['tolerance'];
      if (tolerance != null && tolerance is! num) {
        _privateGateFailure(token, 'manifest_tolerance', factCount);
      }
      final maximumError = (tolerance as num?)?.toDouble() ?? 0.01;
      final expectedValues = _expectedValues(
        fixture['expectedValues'],
        token,
        factCount,
      );
      for (final expected in expectedValues.entries) {
        final key = LppEvidenceFactKey.fromWireName(expected.key);
        final actual = key == null ? null : facts[key];
        if (actual == null ||
            (actual.value - expected.value).abs() > maximumError) {
          _privateGateFailure(token, 'expected_value', factCount);
        }
      }
      for (final absent in _absentKeys(
        fixture['absentKeys'],
        token,
        factCount,
      )) {
        final key = LppEvidenceFactKey.fromWireName(absent);
        if (key == null || facts.containsKey(key)) {
          _privateGateFailure(token, 'expected_absence', factCount);
        }
      }

      // ignore: avoid_print
      print('LPP_PRIVATE_GATE token=$token count=$factCount');
    } on TestFailure {
      rethrow;
    } catch (_) {
      _privateGateFailure(token, 'unexpected', factCount);
    }
  }
}

void main() {
  final manifestLocation = Platform.environment[_manifestEnvironmentKey];
  test(
    'private LPP OCR fixtures satisfy the strict local adapter contract',
    () => _runPrivateManifest(manifestLocation!),
    skip: manifestLocation == null
        ? 'Set MINT_LPP_PRIVATE_MANIFEST to run the local-only gate.'
        : false,
  );
}
