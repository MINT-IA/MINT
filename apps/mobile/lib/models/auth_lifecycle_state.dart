import 'package:flutter/foundation.dart';

enum AuthLifecycleKind {
  sessionRestoring,
  freshVisitor,
  guestEmpty,
  guestHasLocalData,
  migrationOffered,
  migrationConflict,
  signedInProfileLoading,
  signedInProfileMissing,
  signedInIncomplete,
  signedInReady,
  syncOffAccount,
  cloudSyncOnAccount,
  offlineSignedInStale,
  sessionExpired,
  credentialRevoked,
  deletionConfirming,
  deletionPending,
  deletionFailed,
  deletedLocalCleanup,
  deletedSignedOut,
}

enum AuthAccessMode { visitor, guestLocal, account }

enum AuthSyncMode { none, localOnly, cloudSyncOff, cloudSyncOn }

enum AuthDataScopeKind { none, guest, user }

@immutable
class AuthDataScope {
  const AuthDataScope._(this.kind, [this.ownerId]);

  static const none = AuthDataScope._(AuthDataScopeKind.none);

  factory AuthDataScope.guest(String installId) {
    return AuthDataScope._(AuthDataScopeKind.guest, installId);
  }

  factory AuthDataScope.user(String userId) {
    return AuthDataScope._(AuthDataScopeKind.user, userId);
  }

  final AuthDataScopeKind kind;
  final String? ownerId;

  @override
  bool operator ==(Object other) {
    return other is AuthDataScope &&
        other.kind == kind &&
        other.ownerId == ownerId;
  }

  @override
  int get hashCode => Object.hash(kind, ownerId);

  @override
  String toString() {
    final wireKind = kind.name;
    if (ownerId == null) return wireKind;
    return '$wireKind:$ownerId';
  }
}

@immutable
class AuthLifecycleState {
  const AuthLifecycleState({
    required this.state,
    required this.accessMode,
    required this.activeDataScope,
    required this.syncMode,
    this.userId,
  });

  factory AuthLifecycleState.sessionRestoring() {
    return const AuthLifecycleState(
      state: AuthLifecycleKind.sessionRestoring,
      accessMode: AuthAccessMode.visitor,
      activeDataScope: AuthDataScope.none,
      syncMode: AuthSyncMode.none,
    );
  }

  factory AuthLifecycleState.freshVisitor() {
    return const AuthLifecycleState(
      state: AuthLifecycleKind.freshVisitor,
      accessMode: AuthAccessMode.visitor,
      activeDataScope: AuthDataScope.none,
      syncMode: AuthSyncMode.none,
    );
  }

  factory AuthLifecycleState.guestEmpty({required String installId}) {
    return AuthLifecycleState(
      state: AuthLifecycleKind.guestEmpty,
      accessMode: AuthAccessMode.guestLocal,
      activeDataScope: AuthDataScope.guest(installId),
      syncMode: AuthSyncMode.localOnly,
    );
  }

  factory AuthLifecycleState.signedInProfileLoading({
    required String userId,
    required bool cloudSyncEnabled,
  }) {
    return AuthLifecycleState(
      state: AuthLifecycleKind.signedInProfileLoading,
      accessMode: AuthAccessMode.account,
      activeDataScope: AuthDataScope.user(userId),
      syncMode: cloudSyncEnabled
          ? AuthSyncMode.cloudSyncOn
          : AuthSyncMode.cloudSyncOff,
      userId: userId,
    );
  }

  factory AuthLifecycleState.signedInProfileMissing({
    required String userId,
    required bool cloudSyncEnabled,
  }) {
    return AuthLifecycleState(
      state: AuthLifecycleKind.signedInProfileMissing,
      accessMode: AuthAccessMode.account,
      activeDataScope: AuthDataScope.user(userId),
      syncMode: cloudSyncEnabled
          ? AuthSyncMode.cloudSyncOn
          : AuthSyncMode.cloudSyncOff,
      userId: userId,
    );
  }

  factory AuthLifecycleState.syncOffAccount({required String userId}) {
    return AuthLifecycleState(
      state: AuthLifecycleKind.syncOffAccount,
      accessMode: AuthAccessMode.account,
      activeDataScope: AuthDataScope.user(userId),
      syncMode: AuthSyncMode.cloudSyncOff,
      userId: userId,
    );
  }

  factory AuthLifecycleState.cloudSyncOnAccount({required String userId}) {
    return AuthLifecycleState(
      state: AuthLifecycleKind.cloudSyncOnAccount,
      accessMode: AuthAccessMode.account,
      activeDataScope: AuthDataScope.user(userId),
      syncMode: AuthSyncMode.cloudSyncOn,
      userId: userId,
    );
  }

  factory AuthLifecycleState.sessionExpired() {
    return const AuthLifecycleState(
      state: AuthLifecycleKind.sessionExpired,
      accessMode: AuthAccessMode.account,
      activeDataScope: AuthDataScope.none,
      syncMode: AuthSyncMode.none,
    );
  }

  final AuthLifecycleKind state;
  final AuthAccessMode accessMode;
  final AuthDataScope activeDataScope;
  final AuthSyncMode syncMode;
  final String? userId;

  bool get allowsMainNavigation {
    if (activeDataScope == AuthDataScope.none) return false;
    switch (state) {
      case AuthLifecycleKind.guestEmpty:
      case AuthLifecycleKind.guestHasLocalData:
      case AuthLifecycleKind.signedInReady:
      case AuthLifecycleKind.syncOffAccount:
      case AuthLifecycleKind.cloudSyncOnAccount:
      case AuthLifecycleKind.offlineSignedInStale:
        return accessMode == AuthAccessMode.guestLocal ||
            accessMode == AuthAccessMode.account;
      case AuthLifecycleKind.sessionRestoring:
      case AuthLifecycleKind.freshVisitor:
      case AuthLifecycleKind.migrationOffered:
      case AuthLifecycleKind.migrationConflict:
      case AuthLifecycleKind.signedInProfileLoading:
      case AuthLifecycleKind.signedInProfileMissing:
      case AuthLifecycleKind.signedInIncomplete:
      case AuthLifecycleKind.sessionExpired:
      case AuthLifecycleKind.credentialRevoked:
      case AuthLifecycleKind.deletionConfirming:
      case AuthLifecycleKind.deletionPending:
      case AuthLifecycleKind.deletionFailed:
      case AuthLifecycleKind.deletedLocalCleanup:
      case AuthLifecycleKind.deletedSignedOut:
        return false;
    }
  }

  bool get hasAccountSession {
    return accessMode == AuthAccessMode.account &&
        activeDataScope.kind == AuthDataScopeKind.user &&
        userId != null;
  }
}
