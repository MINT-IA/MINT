import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/data_spine/coach_context_packet_service.dart';
import 'package:mint_mobile/services/data_spine/data_spine_service.dart';

abstract final class CoachContextPacketAdapter {
  static Map<String, dynamic> fromProfile(CoachProfile profile) {
    try {
      final spine = DataSpineService.fromProfile(profile);
      return CoachContextPacketService.fromSpine(spine).toSafeMap();
    } catch (e) {
      debugPrint('[CoachContextPacketAdapter] $e');
      return const <String, dynamic>{};
    }
  }
}
