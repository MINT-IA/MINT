import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'startup_route_override_parser.dart';

const _runtimeArgsChannel = MethodChannel('ch.mint.app/runtime_args');

Future<String?> readMintTestInitialRoute() async {
  final localRoute = parseMintTestInitialRoute(
    arguments: Platform.executableArguments,
    environment: Platform.environment,
  );
  if (localRoute != null) return localRoute;

  try {
    final nativeArgs =
        await _runtimeArgsChannel.invokeListMethod<String>('launchArguments');
    return parseMintTestInitialRoute(
      arguments: nativeArgs ?? const [],
      environment: const {},
    );
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

Future<int?> readMintTestPropertyValue() async {
  final localValue = parseMintTestPropertyValue(
    arguments: Platform.executableArguments,
    environment: Platform.environment,
  );
  if (localValue != null) return localValue;

  try {
    final nativeArgs =
        await _runtimeArgsChannel.invokeListMethod<String>('launchArguments');
    return parseMintTestPropertyValue(
      arguments: nativeArgs ?? const [],
      environment: const {},
    );
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

Future<int?> readMintTestRevenueAnnual() async {
  final localValue = parseMintTestRevenueAnnual(
    arguments: Platform.executableArguments,
    environment: Platform.environment,
  );
  if (localValue != null) return localValue;

  try {
    final nativeArgs =
        await _runtimeArgsChannel.invokeListMethod<String>('launchArguments');
    return parseMintTestRevenueAnnual(
      arguments: nativeArgs ?? const [],
      environment: const {},
    );
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

Future<String?> readMintTestCanton() async {
  final localValue = parseMintTestCanton(
    arguments: Platform.executableArguments,
    environment: Platform.environment,
  );
  if (localValue != null) return localValue;

  try {
    final nativeArgs =
        await _runtimeArgsChannel.invokeListMethod<String>('launchArguments');
    return parseMintTestCanton(
      arguments: nativeArgs ?? const [],
      environment: const {},
    );
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

Future<bool> readMintTestPropertyStale() async {
  final localValue = parseMintTestPropertyStale(
    arguments: Platform.executableArguments,
    environment: Platform.environment,
  );
  if (localValue) return true;

  try {
    final nativeArgs =
        await _runtimeArgsChannel.invokeListMethod<String>('launchArguments');
    return parseMintTestPropertyStale(
      arguments: nativeArgs ?? const [],
      environment: const {},
    );
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

Future<String?> readMintTestTransmitPropertyFixture() async {
  final localFixture = parseMintTestTransmitPropertyFixture(
    arguments: Platform.executableArguments,
    environment: Platform.environment,
  );
  if (localFixture != null) return localFixture;

  try {
    final nativeArgs =
        await _runtimeArgsChannel.invokeListMethod<String>('launchArguments');
    return parseMintTestTransmitPropertyFixture(
      arguments: nativeArgs ?? const [],
      environment: const {},
    );
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

Future<String?> readMintTestReportFixture() async {
  final localFixture = parseMintTestReportFixture(
    arguments: Platform.executableArguments,
    environment: Platform.environment,
  );
  if (localFixture != null) return localFixture;

  try {
    final nativeArgs =
        await _runtimeArgsChannel.invokeListMethod<String>('launchArguments');
    return parseMintTestReportFixture(
      arguments: nativeArgs ?? const [],
      environment: const {},
    );
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}

Future<bool> readMintRuntimeProofSemanticsFlag() async {
  final localFlag = parseMintRuntimeProofSemanticsEnabled(
    arguments: Platform.executableArguments,
    environment: Platform.environment,
  );
  if (localFlag) return true;

  try {
    final nativeArgs =
        await _runtimeArgsChannel.invokeListMethod<String>('launchArguments');
    return parseMintRuntimeProofSemanticsEnabled(
      arguments: nativeArgs ?? const [],
      environment: const {},
    );
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}
