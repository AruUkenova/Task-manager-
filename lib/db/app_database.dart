import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_dao.dart';

part 'app_database.g.dart';

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
}

/// Tasks.tagId -> Tags.id (1 задача = 1 тег)
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 200)();
  DateTimeColumn get dueDate => dateTime()();

  /// 1..5 (по умолчанию 3)
  IntColumn get priority => integer().withDefault(const Constant(3))();

  IntColumn get tagId => integer().references(Tags, #id)();

  /// добавим миграцией (schemaVersion 2)
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.sqlite'));
    return NativeDatabase(file);
  });
}

@DriftDatabase(tables: [Tasks, Tags], daos: [AppDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 2
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Пример миграции: v1 -> v2 (добавили isDone)
          if (from == 1) {
            await m.addColumn(tasks, tasks.isDone);
            await (update(tasks)).write(const TasksCompanion(isDone: Value(false)));
          }
        },
      );
}
