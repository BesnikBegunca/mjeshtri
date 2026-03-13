import '../models/parameters.dart';
import 'db.dart';

class ParametersDao {
  ParametersDao._();
  static final ParametersDao I = ParametersDao._();

  Future<Parameters> get() async {
    final rows = await AppDb.I.db.query('parameters', where: 'id=1', limit: 1);
    return Parameters.fromMap(rows.first);
  }

  Future<void> save(Parameters p) async {
    await AppDb.I.db.update('parameters', p.toMap(), where: 'id=1');
  }
}
