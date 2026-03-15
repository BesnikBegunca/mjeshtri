import 'package:shared_preferences/shared_preferences.dart';

import '../models/firma_info.dart';

class FirmaDao {
  FirmaDao._();
  static final FirmaDao I = FirmaDao._();

  static const _kEmri = 'firma_emri';
  static const _kDescription = 'firma_description';
  static const _kNrTel = 'firma_nr_tel';

  Future<FirmaInfo> get() async {
    final prefs = await SharedPreferences.getInstance();

    return FirmaInfo(
      emri: prefs.getString(_kEmri) ?? '',
      description: prefs.getString(_kDescription) ?? '',
      nrTel: prefs.getString(_kNrTel) ?? '',
    );
  }

  Future<void> save(FirmaInfo item) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_kEmri, item.emri);
    await prefs.setString(_kDescription, item.description);
    await prefs.setString(_kNrTel, item.nrTel);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_kEmri);
    await prefs.remove(_kDescription);
    await prefs.remove(_kNrTel);
  }
}
