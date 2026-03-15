import 'package:mjeshtri/data/db.dart';

import '../models/job_project.dart';

class JobsDao {
  JobsDao._();
  static final JobsDao I = JobsDao._();

  Future<List<JobProject>> listJobs() async {
    final db = await AppDb.I.database;

    final jobMaps = await db.query(
      'jobs',
      orderBy: 'id DESC',
    );

    final jobs = <JobProject>[];

    for (final jm in jobMaps) {
      final job = JobProject.fromMap(jm);

      final workerMaps = await db.query(
        'job_worker_entries',
        where: 'jobId = ?',
        whereArgs: [job.id],
        orderBy: 'id DESC',
      );

      final expenseMaps = await db.query(
        'job_expenses',
        where: 'jobId = ?',
        whereArgs: [job.id],
        orderBy: 'id DESC',
      );

      jobs.add(
        JobProject(
          id: job.id,
          name: job.name,
          clientName: job.clientName,
          contractAmount: job.contractAmount,
          note: job.note,
          createdAt: job.createdAt,
          workerEntries:
              workerMaps.map((e) => JobWorkerEntry.fromMap(e)).toList(),
          expenses: expenseMaps.map((e) => JobExpense.fromMap(e)).toList(),
        ),
      );
    }

    return jobs;
  }

  Future<int> insertJob(JobProject job) async {
    final db = await AppDb.I.database;
    final id = await db.insert('jobs', {
      'name': job.name,
      'clientName': job.clientName,
      'contractAmount': job.contractAmount,
      'note': job.note,
      'createdAt': job.createdAt.toIso8601String(),
    });
    return id;
  }

  Future<void> updateJob(JobProject job) async {
    final db = await AppDb.I.database;
    await db.update(
      'jobs',
      {
        'name': job.name,
        'clientName': job.clientName,
        'contractAmount': job.contractAmount,
        'note': job.note,
        'createdAt': job.createdAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [job.id],
    );
  }

  Future<void> deleteJob(int jobId) async {
    final db = await AppDb.I.database;
    await db.delete(
      'jobs',
      where: 'id = ?',
      whereArgs: [jobId],
    );
  }

  Future<int> insertWorkerEntry(JobWorkerEntry entry) async {
    final db = await AppDb.I.database;
    return await db.insert('job_worker_entries', {
      'jobId': entry.jobId,
      'workerId': entry.workerId,
      'workerName': entry.workerName,
      'workerPosition': entry.workerPosition,
      'days': entry.days,
      'dailyRate': entry.dailyRate,
      'note': entry.note,
    });
  }

  Future<void> updateWorkerEntry(JobWorkerEntry entry) async {
    final db = await AppDb.I.database;
    await db.update(
      'job_worker_entries',
      {
        'jobId': entry.jobId,
        'workerId': entry.workerId,
        'workerName': entry.workerName,
        'workerPosition': entry.workerPosition,
        'days': entry.days,
        'dailyRate': entry.dailyRate,
        'note': entry.note,
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteWorkerEntry(int id) async {
    final db = await AppDb.I.database;
    await db.delete(
      'job_worker_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertExpense(JobExpense expense) async {
    final db = await AppDb.I.database;
    return await db.insert('job_expenses', {
      'jobId': expense.jobId,
      'title': expense.title,
      'amount': expense.amount,
      'note': expense.note,
    });
  }

  Future<void> updateExpense(JobExpense expense) async {
    final db = await AppDb.I.database;
    await db.update(
      'job_expenses',
      {
        'jobId': expense.jobId,
        'title': expense.title,
        'amount': expense.amount,
        'note': expense.note,
      },
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<void> deleteExpense(int id) async {
    final db = await AppDb.I.database;
    await db.delete(
      'job_expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
