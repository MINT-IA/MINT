import 'dart:convert';

const coachProfileOwnerRootKey = '_coach_profile_owner_v1';

final RegExp _canonicalUuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

bool isCanonicalUuidV4(String? value) =>
    value != null && _canonicalUuidV4.hasMatch(value);

class CoachProfileOwnerRoot {
  const CoachProfileOwnerRoot(this.profileOwnerId);

  static const schemaVersion = 1;

  final String profileOwnerId;

  String toJsonString() => jsonEncode(<String, Object>{
        'schemaVersion': schemaVersion,
        'profileOwnerId': profileOwnerId,
      });

  static CoachProfileOwnerRoot? fromJsonString(Object? raw) {
    if (raw is! String || raw == '__secure__') return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map ||
          decoded.length != 2 ||
          decoded['schemaVersion'] != schemaVersion ||
          decoded['profileOwnerId'] is! String) {
        return null;
      }
      final owner = decoded['profileOwnerId'] as String;
      return isCanonicalUuidV4(owner) ? CoachProfileOwnerRoot(owner) : null;
    } on Object {
      return null;
    }
  }
}
