import 'package:intl/intl.dart';

final _money = NumberFormat.currency(locale: 'en_US', symbol: '€');

String eur(num v) => _money.format(v);
