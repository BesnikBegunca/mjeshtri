import 'package:flutter/material.dart';
import 'data/db.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDb.I.init();
  runApp(const MjeshtriApp());
}
