class JobProject {
  int? id;
  String name;
  String? clientName;
  double contractAmount;
  String? note;
  DateTime createdAt;

  bool isCompleted;
  DateTime? completedAt;

  List<JobWorkerEntry> workerEntries;
  List<JobExpense> expenses;

  JobProject({
    this.id,
    required this.name,
    this.clientName,
    required this.contractAmount,
    this.note,
    required this.createdAt,
    this.isCompleted = false,
    this.completedAt,
    this.workerEntries = const [],
    this.expenses = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'clientName': clientName,
      'contractAmount': contractAmount,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory JobProject.fromMap(Map<String, dynamic> map) {
    return JobProject(
      id: map['id'] as int?,
      name: (map['name'] ?? '') as String,
      clientName: map['clientName'] as String?,
      contractAmount: ((map['contractAmount'] ?? 0) as num).toDouble(),
      note: map['note'] as String?,
      createdAt:
          DateTime.tryParse('${map['createdAt'] ?? ''}') ?? DateTime.now(),
      isCompleted: ((map['isCompleted'] ?? 0) as num).toInt() == 1,
      completedAt: map['completedAt'] == null
          ? null
          : DateTime.tryParse('${map['completedAt']}'),
      workerEntries: const [],
      expenses: const [],
    );
  }
}

class JobWorkerEntry {
  int? id;
  int jobId;
  int workerId;
  String workerName;
  String? workerPosition;
  int days;
  double dailyRate;
  String? note;

  JobWorkerEntry({
    this.id,
    required this.jobId,
    required this.workerId,
    required this.workerName,
    this.workerPosition,
    required this.days,
    required this.dailyRate,
    this.note,
  });

  double get total => days * dailyRate;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'workerId': workerId,
      'workerName': workerName,
      'workerPosition': workerPosition,
      'days': days,
      'dailyRate': dailyRate,
      'note': note,
    };
  }

  factory JobWorkerEntry.fromMap(Map<String, dynamic> map) {
    return JobWorkerEntry(
      id: map['id'] as int?,
      jobId: map['jobId'] as int,
      workerId: map['workerId'] as int,
      workerName: (map['workerName'] ?? '') as String,
      workerPosition: map['workerPosition'] as String?,
      days: (map['days'] ?? 0) as int,
      dailyRate: ((map['dailyRate'] ?? 0) as num).toDouble(),
      note: map['note'] as String?,
    );
  }
}

class JobExpense {
  int? id;
  int jobId;
  String title;
  double amount;
  String? note;

  JobExpense({
    this.id,
    required this.jobId,
    required this.title,
    required this.amount,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'title': title,
      'amount': amount,
      'note': note,
    };
  }

  factory JobExpense.fromMap(Map<String, dynamic> map) {
    return JobExpense(
      id: map['id'] as int?,
      jobId: map['jobId'] as int,
      title: (map['title'] ?? '') as String,
      amount: ((map['amount'] ?? 0) as num).toDouble(),
      note: map['note'] as String?,
    );
  }
}
