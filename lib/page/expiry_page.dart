import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mjeshtri/data/db.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LicenseDurationType {
  minutes,
  months,
}

class LicenseOption {
  final String label;
  final LicenseDurationType type;
  final int value;

  const LicenseOption.minutes(this.label, this.value)
      : type = LicenseDurationType.minutes;

  const LicenseOption.months(this.label, this.value)
      : type = LicenseDurationType.months;

  String get historyText {
    switch (type) {
      case LicenseDurationType.minutes:
        return '$value minutë';
      case LicenseDurationType.months:
        return '$value muaj';
    }
  }
}

class LicenseHistoryEntry {
  final int? id;
  final String actionType;
  final int amountAdded;
  final String amountUnit;
  final DateTime? previousExpiryDate;
  final DateTime? newExpiryDate;
  final DateTime createdAt;
  final String note;

  const LicenseHistoryEntry({
    this.id,
    required this.actionType,
    required this.amountAdded,
    required this.amountUnit,
    required this.previousExpiryDate,
    required this.newExpiryDate,
    required this.createdAt,
    required this.note,
  });

  factory LicenseHistoryEntry.fromMap(Map<String, Object?> map) {
    return LicenseHistoryEntry(
      id: map['id'] as int?,
      actionType: (map['actionType'] as String?) ?? '',
      amountAdded: ((map['monthsAdded'] as num?) ?? 0).toInt(),
      amountUnit: (map['amountUnit'] as String?) ?? 'months',
      previousExpiryDate: map['previousExpiryDate'] == null
          ? null
          : DateTime.tryParse(map['previousExpiryDate'] as String),
      newExpiryDate: map['newExpiryDate'] == null
          ? null
          : DateTime.tryParse(map['newExpiryDate'] as String),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now(),
      note: (map['note'] as String?) ?? '',
    );
  }
}

class AppLicenseService {
  AppLicenseService._();

  static const String _legacyInstallDateKey = 'license_install_date';
  static const String _legacyExpiryDateKey = 'license_expiry_date';

  static const String developerUsername = 'fikshi';
  static const String developerPassword = 'fikshifiksh2026';

  static const List<LicenseOption> licenseOptions = [
    LicenseOption.minutes('1 minutë', 1),
    LicenseOption.months('1 muaj', 1),
    LicenseOption.months('2 muaj', 2),
    LicenseOption.months('3 muaj', 3),
    LicenseOption.months('6 muaj', 6),
    LicenseOption.months('1 vit', 12),
    LicenseOption.months('2 vite', 24),
  ];

  static DateTime addMonths(DateTime date, int monthsToAdd) {
    final totalMonths = date.month + monthsToAdd;
    final year = date.year + ((totalMonths - 1) ~/ 12);
    final month = ((totalMonths - 1) % 12) + 1;
    final day = date.day;

    final lastDayOfTargetMonth = DateTime(year, month + 1, 0).day;
    final safeDay = day > lastDayOfTargetMonth ? lastDayOfTargetMonth : day;

    return DateTime(
      year,
      month,
      safeDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  static DateTime applyOption(DateTime base, LicenseOption option) {
    switch (option.type) {
      case LicenseDurationType.minutes:
        return base.add(Duration(minutes: option.value));
      case LicenseDurationType.months:
        return addMonths(base, option.value);
    }
  }

  static bool validateDeveloper(String username, String password) {
    return username.trim() == developerUsername &&
        password.trim() == developerPassword;
  }

  static Future<void> _ensureHistorySchema() async {
    final db = await AppDb.I.database;

    try {
      await db.execute(
        "ALTER TABLE license_history ADD COLUMN amountUnit TEXT DEFAULT 'months'",
      );
    } catch (_) {
      // kolona ekziston
    }
  }

  static Future<void> initializeIfNeeded({
    int initialMonths = 12,
  }) async {
    await AppDb.I.init();
    final db = await AppDb.I.database;
    await _ensureHistorySchema();

    final existing = await db.query(
      'app_license',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (existing.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    final legacyInstallStr = prefs.getString(_legacyInstallDateKey);
    final legacyExpiryStr = prefs.getString(_legacyExpiryDateKey);

    final now = DateTime.now();

    final installDate = DateTime.tryParse(legacyInstallStr ?? '') ?? now;
    final expiryDate = DateTime.tryParse(legacyExpiryStr ?? '') ??
        addMonths(installDate, initialMonths);

    await db.insert('app_license', {
      'id': 1,
      'installDate': installDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'lastUpdatedAt': now.toIso8601String(),
    });

    await db.insert('license_history', {
      'actionType': 'init',
      'monthsAdded': initialMonths,
      'amountUnit': 'months',
      'previousExpiryDate': null,
      'newExpiryDate': expiryDate.toIso8601String(),
      'createdAt': now.toIso8601String(),
      'note': legacyExpiryStr != null
          ? 'Migrim nga SharedPreferences'
          : 'Licencë fillestare',
    });

    if (legacyInstallStr != null || legacyExpiryStr != null) {
      await prefs.remove(_legacyInstallDateKey);
      await prefs.remove(_legacyExpiryDateKey);
    }
  }

  static Future<Map<String, DateTime?>> getLicenseInfo({
    int initialMonths = 12,
  }) async {
    await initializeIfNeeded(initialMonths: initialMonths);

    final db = await AppDb.I.database;
    final rows = await db.query(
      'app_license',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (rows.isEmpty) {
      return {
        'installDate': null,
        'expiryDate': null,
      };
    }

    final row = rows.first;

    return {
      'installDate': row['installDate'] == null
          ? null
          : DateTime.tryParse(row['installDate'] as String),
      'expiryDate': row['expiryDate'] == null
          ? null
          : DateTime.tryParse(row['expiryDate'] as String),
    };
  }

  static Future<DateTime?> getInstallDate() async {
    final map = await getLicenseInfo();
    return map['installDate'];
  }

  static Future<DateTime?> getExpiryDate() async {
    final map = await getLicenseInfo();
    return map['expiryDate'];
  }

  static Future<bool> isExpired() async {
    await initializeIfNeeded();
    final expiry = await getExpiryDate();
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry);
  }

  static Future<void> extendFromCurrentOrNow(
    LicenseOption option, {
    String note = '',
  }) async {
    await initializeIfNeeded();
    final db = await AppDb.I.database;
    await _ensureHistorySchema();

    final now = DateTime.now();

    final rows = await db.query(
      'app_license',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (rows.isEmpty) {
      final expiry = applyOption(now, option);

      await db.insert('app_license', {
        'id': 1,
        'installDate': now.toIso8601String(),
        'expiryDate': expiry.toIso8601String(),
        'lastUpdatedAt': now.toIso8601String(),
      });

      await db.insert('license_history', {
        'actionType': 'extend',
        'monthsAdded': option.value,
        'amountUnit':
            option.type == LicenseDurationType.minutes ? 'minutes' : 'months',
        'previousExpiryDate': null,
        'newExpiryDate': expiry.toIso8601String(),
        'createdAt': now.toIso8601String(),
        'note': note,
      });

      return;
    }

    final row = rows.first;
    final currentExpiry = row['expiryDate'] == null
        ? null
        : DateTime.tryParse(row['expiryDate'] as String);

    final base = (currentExpiry != null && currentExpiry.isAfter(now))
        ? currentExpiry
        : now;

    final newExpiry = applyOption(base, option);

    await db.update(
      'app_license',
      {
        'expiryDate': newExpiry.toIso8601String(),
        'lastUpdatedAt': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [1],
    );

    await db.insert('license_history', {
      'actionType': 'extend',
      'monthsAdded': option.value,
      'amountUnit':
          option.type == LicenseDurationType.minutes ? 'minutes' : 'months',
      'previousExpiryDate': currentExpiry?.toIso8601String(),
      'newExpiryDate': newExpiry.toIso8601String(),
      'createdAt': now.toIso8601String(),
      'note': note,
    });
  }

  static Future<void> deleteLicense({
    String note = 'Licenca u bë delete nga developer panel',
  }) async {
    await initializeIfNeeded();
    final db = await AppDb.I.database;
    await _ensureHistorySchema();

    final now = DateTime.now();

    final rows = await db.query(
      'app_license',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    DateTime? currentExpiry;
    DateTime? installDate;

    if (rows.isNotEmpty) {
      final row = rows.first;
      installDate = row['installDate'] == null
          ? now
          : DateTime.tryParse(row['installDate'] as String);
      currentExpiry = row['expiryDate'] == null
          ? null
          : DateTime.tryParse(row['expiryDate'] as String);
    }

    final deletedExpiry = now.subtract(const Duration(seconds: 1));

    if (rows.isEmpty) {
      await db.insert('app_license', {
        'id': 1,
        'installDate': now.toIso8601String(),
        'expiryDate': deletedExpiry.toIso8601String(),
        'lastUpdatedAt': now.toIso8601String(),
      });
    } else {
      await db.update(
        'app_license',
        {
          'installDate': (installDate ?? now).toIso8601String(),
          'expiryDate': deletedExpiry.toIso8601String(),
          'lastUpdatedAt': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [1],
      );
    }

    await db.insert('license_history', {
      'actionType': 'delete',
      'monthsAdded': 0,
      'amountUnit': 'months',
      'previousExpiryDate': currentExpiry?.toIso8601String(),
      'newExpiryDate': deletedExpiry.toIso8601String(),
      'createdAt': now.toIso8601String(),
      'note': note,
    });
  }

  static Future<List<LicenseHistoryEntry>> getHistory() async {
    await initializeIfNeeded();
    final db = await AppDb.I.database;
    await _ensureHistorySchema();

    final rows = await db.query(
      'license_history',
      orderBy: 'createdAt DESC, id DESC',
    );

    return rows.map(LicenseHistoryEntry.fromMap).toList();
  }
}

class ExpiryPage extends StatefulWidget {
  final Widget childWhenActive;
  final int initialLicenseMonths;
  final int developerDefaultMonths;

  const ExpiryPage({
    super.key,
    required this.childWhenActive,
    this.initialLicenseMonths = 12,
    this.developerDefaultMonths = 12,
  });

  @override
  State<ExpiryPage> createState() => _ExpiryPageState();
}

class _ExpiryPageState extends State<ExpiryPage> {
  bool loading = true;
  bool expired = false;
  DateTime? installDate;
  DateTime? expiryDate;
  Timer? timer;

  final userC = TextEditingController();
  final passC = TextEditingController();

  bool obscure = true;
  bool loginLoading = false;
  bool extendLoading = false;
  bool deleteLoading = false;
  bool devLoggedIn = false;
  String? errorText;

  Timer? devSessionTimer;
  DateTime? devSessionExpiresAt;

  late LicenseOption selectedOption;
  List<LicenseHistoryEntry> history = [];

  @override
  void initState() {
    super.initState();

    selectedOption = AppLicenseService.licenseOptions.firstWhere(
      (e) => e.value == widget.developerDefaultMonths,
      orElse: () => AppLicenseService.licenseOptions.first,
    );

    _load();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _refreshTimeOnly();
      }
    });
  }

  Future<void> _load() async {
    await AppLicenseService.initializeIfNeeded(
      initialMonths: widget.initialLicenseMonths,
    );

    final info = await AppLicenseService.getLicenseInfo(
      initialMonths: widget.initialLicenseMonths,
    );
    final isExpired = await AppLicenseService.isExpired();
    final rows = await AppLicenseService.getHistory();

    if (!mounted) return;
    setState(() {
      installDate = info['installDate'];
      expiryDate = info['expiryDate'];
      expired = isExpired;
      history = rows;
      loading = false;
    });
  }

  Future<void> _refreshTimeOnly() async {
    final exp = await AppLicenseService.getExpiryDate();
    final isExpired = await AppLicenseService.isExpired();

    if (!mounted) return;
    setState(() {
      expiryDate = exp;
      expired = isExpired;
    });
  }

  void _startDevSession({int seconds = 30}) {
    devSessionTimer?.cancel();

    setState(() {
      devLoggedIn = true;
      devSessionExpiresAt = DateTime.now().add(Duration(seconds: seconds));
      errorText = null;
    });

    devSessionTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      _logoutDev(showMessage: true);
    });
  }

  void _logoutDev({bool showMessage = false}) {
    devSessionTimer?.cancel();

    if (!mounted) return;

    setState(() {
      devLoggedIn = false;
      devSessionExpiresAt = null;
      obscure = true;
      userC.clear();
      passC.clear();
    });

    if (showMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Developer session përfundoi. Bëje login përsëri.'),
        ),
      );
    }
  }

  String _devSessionText() {
    if (devSessionExpiresAt == null) return '';
    final diff = devSessionExpiresAt!.difference(DateTime.now());
    if (diff.isNegative) return '0 sekonda';
    return '${diff.inSeconds} sekonda';
  }

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}:'
        '${d.second.toString().padLeft(2, '0')}';
  }

  Duration _remaining() {
    if (expiryDate == null) return Duration.zero;
    final diff = expiryDate!.difference(DateTime.now());
    if (diff.isNegative) return Duration.zero;
    return diff;
  }

  String _remainingText(Duration d) {
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    return '$days ditë  $hours orë  $minutes minuta  $seconds sekonda';
  }

  String _historyAmountText(LicenseHistoryEntry e) {
    if (e.actionType == 'delete') return '-';

    if (e.amountUnit == 'minutes') {
      return e.actionType == 'init'
          ? '${e.amountAdded} minutë (fillestare)'
          : '${e.amountAdded} minutë';
    }

    return e.actionType == 'init'
        ? '${e.amountAdded} muaj (fillestare)'
        : '${e.amountAdded} muaj';
  }

  String _actionText(LicenseHistoryEntry e) {
    switch (e.actionType) {
      case 'init':
        return 'Krijim';
      case 'delete':
        return 'Delete licence';
      default:
        return 'Vazhdim licence';
    }
  }

  Future<void> _loginDev() async {
    setState(() {
      loginLoading = true;
      errorText = null;
    });

    final ok = AppLicenseService.validateDeveloper(
      userC.text,
      passC.text,
    );

    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    if (!ok) {
      setState(() {
        loginLoading = false;
        devLoggedIn = false;
        errorText = 'Username ose password gabim.';
      });
      return;
    }

    setState(() {
      loginLoading = false;
      errorText = null;
    });

    _startDevSession(seconds: 30);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Login me sukses. Session aktiv 30 sekonda.'),
      ),
    );
  }

  Future<void> _extendLicense() async {
    if (!devLoggedIn) {
      setState(() {
        errorText = 'Së pari bëje login si developer.';
      });
      return;
    }

    setState(() {
      extendLoading = true;
      errorText = null;
    });

    await AppLicenseService.extendFromCurrentOrNow(
      selectedOption,
      note: 'Vazhduar nga ExpiryPage',
    );

    await _load();

    if (!mounted) return;
    setState(() {
      extendLoading = false;
      obscure = true;
    });

    _logoutDev();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Licenca u vazhdua me sukses për ${selectedOption.label}. Login u mbyll automatikisht.',
        ),
      ),
    );
  }

  Future<void> _deleteLicense() async {
    if (!devLoggedIn) {
      setState(() {
        errorText = 'Së pari bëje login si developer.';
      });
      return;
    }

    setState(() {
      deleteLoading = true;
      errorText = null;
    });

    await AppLicenseService.deleteLicense(
      note: 'Delete nga ExpiryPage',
    );

    await _load();

    if (!mounted) return;
    setState(() {
      deleteLoading = false;
    });

    _logoutDev();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Licenca u bë delete. Login u mbyll automatikisht.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    devSessionTimer?.cancel();
    userC.dispose();
    passC.dispose();
    super.dispose();
  }

  Widget _buildHistoryTable() {
    if (history.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: const Text('Nuk ka histori ende.'),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 46,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('Data')),
            DataColumn(label: Text('Veprimi')),
            DataColumn(label: Text('Sa u vazhdu')),
            DataColumn(label: Text('Skadimi i vjetër')),
            DataColumn(label: Text('Skadimi i ri')),
            DataColumn(label: Text('Shënim')),
          ],
          rows: history.map((e) {
            return DataRow(
              cells: [
                DataCell(Text(_fmtDateTime(e.createdAt))),
                DataCell(Text(_actionText(e))),
                DataCell(Text(_historyAmountText(e))),
                DataCell(Text(_fmtDateTime(e.previousExpiryDate))),
                DataCell(Text(_fmtDateTime(e.newExpiryDate))),
                DataCell(Text(e.note.isEmpty ? '-' : e.note)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDeveloperPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
        color: Colors.white.withOpacity(0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Developer Login',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: userC,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            enabled: !devLoggedIn,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: passC,
            obscureText: obscure,
            enabled: !devLoggedIn,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => obscure = !obscure);
                },
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            onSubmitted: (_) {
              if (!devLoggedIn) {
                _loginDev();
              }
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: devLoggedIn || loginLoading ? null : _loginDev,
              icon: loginLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(
                devLoggedIn
                    ? 'Session aktive'
                    : loginLoading
                        ? 'Duke verifikuar...'
                        : 'Login',
              ),
            ),
          ),
          if (devLoggedIn) ...[
            const SizedBox(height: 10),
            Text(
              'Session aktiv edhe ${_devSessionText()}',
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<LicenseOption>(
            value: selectedOption,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Zgjatja e licencës',
              prefixIcon: Icon(Icons.schedule_outlined),
            ),
            items: AppLicenseService.licenseOptions
                .map(
                  (e) => DropdownMenuItem<LicenseOption>(
                    value: e,
                    child: Text(e.label),
                  ),
                )
                .toList(),
            onChanged: devLoggedIn
                ? (value) {
                    if (value == null) return;
                    setState(() {
                      selectedOption = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: (!devLoggedIn || extendLoading || deleteLoading)
                        ? null
                        : _extendLicense,
                    icon: extendLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.update),
                    label: Text(
                      extendLoading ? 'Duke vazhduar...' : 'Vazhdo licencën',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: (!devLoggedIn || deleteLoading || extendLoading)
                        ? null
                        : _deleteLicense,
                    icon: deleteLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(
                      deleteLoading ? 'Duke fshirë...' : 'Delete License',
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              errorText!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (devLoggedIn) ...[
            const SizedBox(height: 20),
            const Text(
              'Historia e vazhdimeve',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildHistoryTable(),
          ],
        ],
      ),
    );
  }

  Widget _fullWidthWrapper({required Widget child}) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final remaining = _remaining();

    if (!expired) {
      return Scaffold(
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.green.withOpacity(0.12),
              child: Wrap(
                runSpacing: 8,
                spacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Licenca aktive',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Text('Instaluar: ${_fmtDateTime(installDate)}'),
                  Text('Skadon: ${_fmtDateTime(expiryDate)}'),
                  Text(
                    'Mbeten: ${_remainingText(remaining)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Expanded(child: widget.childWhenActive),
          ],
        ),
      );
    }

    return Scaffold(
      body: _fullWidthWrapper(
        child: Card(
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_clock_rounded,
                  size: 74,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Licenca ka skaduar',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Të dhënat nuk janë fshirë. Për të vazhduar përdorimin, bëje login si developer dhe pastaj aktivizohet dropdown-i për zgjatje.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white12),
                    color: Colors.white.withOpacity(0.04),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Data e instalimit: ${_fmtDateTime(installDate)}'),
                      const SizedBox(height: 8),
                      Text('Data e skadimit: ${_fmtDateTime(expiryDate)}'),
                      const SizedBox(height: 8),
                      const Text(
                        'Koha e mbetur: 0 ditë  0 orë  0 minuta  0 sekonda',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildDeveloperPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LicenseManagePage extends StatefulWidget {
  const LicenseManagePage({super.key});

  @override
  State<LicenseManagePage> createState() => _LicenseManagePageState();
}

class _LicenseManagePageState extends State<LicenseManagePage> {
  DateTime? installDate;
  DateTime? expiryDate;
  bool loading = true;

  final userC = TextEditingController();
  final passC = TextEditingController();

  bool obscure = true;
  bool saving = false;
  bool deleteLoading = false;
  bool loginLoading = false;
  bool devLoggedIn = false;
  String? errorText;

  Timer? devSessionTimer;
  DateTime? devSessionExpiresAt;

  LicenseOption selectedOption = AppLicenseService.licenseOptions[0];
  List<LicenseHistoryEntry> history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AppLicenseService.initializeIfNeeded();
    final info = await AppLicenseService.getLicenseInfo();
    final rows = await AppLicenseService.getHistory();

    if (!mounted) return;
    setState(() {
      installDate = info['installDate'];
      expiryDate = info['expiryDate'];
      history = rows;
      loading = false;
    });
  }

  void _startDevSession({int seconds = 30}) {
    devSessionTimer?.cancel();

    setState(() {
      devLoggedIn = true;
      devSessionExpiresAt = DateTime.now().add(Duration(seconds: seconds));
      errorText = null;
    });

    devSessionTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      _logoutDev(showMessage: true);
    });
  }

  void _logoutDev({bool showMessage = false}) {
    devSessionTimer?.cancel();

    if (!mounted) return;

    setState(() {
      devLoggedIn = false;
      devSessionExpiresAt = null;
      obscure = true;
      userC.clear();
      passC.clear();
    });

    if (showMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Developer session përfundoi. Bëje login përsëri.'),
        ),
      );
    }
  }

  String _devSessionText() {
    if (devSessionExpiresAt == null) return '';
    final diff = devSessionExpiresAt!.difference(DateTime.now());
    if (diff.isNegative) return '0 sekonda';
    return '${diff.inSeconds} sekonda';
  }

  String _fmtDateTime(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}:'
        '${d.second.toString().padLeft(2, '0')}';
  }

  String _historyAmountText(LicenseHistoryEntry e) {
    if (e.actionType == 'delete') return '-';

    if (e.amountUnit == 'minutes') {
      return e.actionType == 'init'
          ? '${e.amountAdded} minutë (fillestare)'
          : '${e.amountAdded} minutë';
    }

    return e.actionType == 'init'
        ? '${e.amountAdded} muaj (fillestare)'
        : '${e.amountAdded} muaj';
  }

  String _actionText(LicenseHistoryEntry e) {
    switch (e.actionType) {
      case 'init':
        return 'Krijim';
      case 'delete':
        return 'Delete licence';
      default:
        return 'Vazhdim licence';
    }
  }

  Future<void> _loginDev() async {
    setState(() {
      loginLoading = true;
      errorText = null;
    });

    final ok = AppLicenseService.validateDeveloper(
      userC.text,
      passC.text,
    );

    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    if (!ok) {
      setState(() {
        loginLoading = false;
        devLoggedIn = false;
        errorText = 'Username ose password gabim.';
      });
      return;
    }

    setState(() {
      loginLoading = false;
      errorText = null;
    });

    _startDevSession(seconds: 30);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Login me sukses. Session aktiv 30 sekonda.'),
      ),
    );
  }

  Future<void> _extend() async {
    if (!devLoggedIn) {
      setState(() {
        errorText = 'Së pari bëje login si developer.';
      });
      return;
    }

    setState(() {
      saving = true;
      errorText = null;
    });

    await AppLicenseService.extendFromCurrentOrNow(
      selectedOption,
      note: 'Vazhduar nga LicenseManagePage',
    );

    await _load();

    if (!mounted) return;
    setState(() {
      saving = false;
      obscure = true;
    });

    _logoutDev();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Licenca u zgjat për ${selectedOption.label}. Login u mbyll automatikisht.',
        ),
      ),
    );
  }

  Future<void> _deleteLicense() async {
    if (!devLoggedIn) {
      setState(() {
        errorText = 'Së pari bëje login si developer.';
      });
      return;
    }

    setState(() {
      deleteLoading = true;
      errorText = null;
    });

    await AppLicenseService.deleteLicense(
      note: 'Delete nga LicenseManagePage',
    );

    await _load();

    if (!mounted) return;
    setState(() {
      deleteLoading = false;
    });

    _logoutDev();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Licenca u bë delete. Login u mbyll automatikisht.'),
      ),
    );
  }

  Widget _buildHistoryTable() {
    if (history.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: const Text('Nuk ka histori ende.'),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Data')),
            DataColumn(label: Text('Veprimi')),
            DataColumn(label: Text('Sa u vazhdu')),
            DataColumn(label: Text('Skadimi i vjetër')),
            DataColumn(label: Text('Skadimi i ri')),
            DataColumn(label: Text('Shënim')),
          ],
          rows: history.map((e) {
            return DataRow(
              cells: [
                DataCell(Text(_fmtDateTime(e.createdAt))),
                DataCell(Text(_actionText(e))),
                DataCell(Text(_historyAmountText(e))),
                DataCell(Text(_fmtDateTime(e.previousExpiryDate))),
                DataCell(Text(_fmtDateTime(e.newExpiryDate))),
                DataCell(Text(e.note.isEmpty ? '-' : e.note)),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    devSessionTimer?.cancel();
    userC.dispose();
    passC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 60,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Menaxhimi i Licencës',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white12),
                        color: Colors.white.withOpacity(0.04),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data e instalimit: ${_fmtDateTime(installDate)}',
                          ),
                          const SizedBox(height: 8),
                          Text('Data e skadimit: ${_fmtDateTime(expiryDate)}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: userC,
                      enabled: !devLoggedIn,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passC,
                      enabled: !devLoggedIn,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => obscure = !obscure);
                          },
                          icon: Icon(
                            obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      onSubmitted: (_) {
                        if (!devLoggedIn) {
                          _loginDev();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed:
                            devLoggedIn || loginLoading ? null : _loginDev,
                        icon: loginLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          devLoggedIn
                              ? 'Session aktive'
                              : loginLoading
                                  ? 'Duke verifikuar...'
                                  : 'Login',
                        ),
                      ),
                    ),
                    if (devLoggedIn) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Session aktiv edhe ${_devSessionText()}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<LicenseOption>(
                      value: selectedOption,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Zgjatja e licencës',
                        prefixIcon: Icon(Icons.date_range_outlined),
                      ),
                      items: AppLicenseService.licenseOptions
                          .map(
                            (e) => DropdownMenuItem<LicenseOption>(
                              value: e,
                              child: Text(e.label),
                            ),
                          )
                          .toList(),
                      onChanged: devLoggedIn
                          ? (value) {
                              if (value == null) return;
                              setState(() {
                                selectedOption = value;
                              });
                            }
                          : null,
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed:
                                  (!devLoggedIn || saving || deleteLoading)
                                      ? null
                                      : _extend,
                              icon: saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.update),
                              label: Text(
                                saving ? 'Duke ruajtur...' : 'Vazhdo licencën',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed:
                                  (!devLoggedIn || deleteLoading || saving)
                                      ? null
                                      : _deleteLicense,
                              icon: deleteLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline),
                              label: Text(
                                deleteLoading
                                    ? 'Duke fshirë...'
                                    : 'Delete License',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Historia e vazhdimeve',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildHistoryTable(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}