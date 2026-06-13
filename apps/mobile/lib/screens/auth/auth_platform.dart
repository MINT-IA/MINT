import 'package:flutter/foundation.dart';

bool get canShowAppleSignIn =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
