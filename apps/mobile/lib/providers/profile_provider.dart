import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:mint_mobile/models/recommendation.dart';

class ProfileProvider extends ChangeNotifier {
  Profile? _profile;
  List<Recommendation> _recommendations = [];
  bool _isLoading = false;

  Profile? get profile => _profile;
  List<Recommendation> get recommendations => _recommendations;
  bool get isLoading => _isLoading;
  bool get hasProfile => _profile != null;

  void setProfile(Profile profile) {
    _profile = profile;
    notifyListeners();
  }

  void setRecommendations(List<Recommendation> recs) {
    _recommendations = recs;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void updateProfile({
    int? birthYear,
    String? canton,
    HouseholdType? householdType,
    double? incomeNetMonthly,
    double? savingsMonthly,
    Goal? goal,
  }) {
    if (_profile == null) return;
    _profile = _profile!.copyWith(
      birthYear: birthYear,
      canton: canton,
      householdType: householdType,
      incomeNetMonthly: incomeNetMonthly,
      savingsMonthly: savingsMonthly,
      goal: goal,
    );
    notifyListeners();
  }
}
