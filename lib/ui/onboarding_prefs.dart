import 'package:shared_preferences/shared_preferences.dart';

/// Persists that the user has seen the “data stays on device” warning (first-run only).
class OnboardingPrefs {
  static const _kLocalOnlyRiskAck = 'lanlock_local_only_risk_ack_v1';

  static Future<bool> hasAcknowledgedLocalOnlyRisk() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kLocalOnlyRiskAck) ?? false;
  }

  static Future<void> setAcknowledgedLocalOnlyRisk() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kLocalOnlyRiskAck, true);
  }
}
