import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../models/task_with_tag.dart';
import 'app_database.dart';

part 'app_dao.g.dart';

enum TaskSort { byDate, byPriority }

@DriftAccessor(tables: [Tasks, Tags])
class AppDao extends DatabaseAccessor<AppDatabase> with _$AppDaoMixin {
  AppDao(super.db);

  //  TAGS CRUD 

  Future<int> addTag(String name) {
    return into(tags).insert(TagsCompanion(name: Value(name.trim())));
  }

  Future<void> updateTag(int id, String name) async {
    await (update(tags)..where((t) => t.id.equals(id)))
        .write(TagsCompanion(name: Value(name.trim())));
  }

  Future<void> deleteTag(int id) async {
    // если есть задачи с таким tagId — SQLite не даст удалить (FK)
    await (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<Tag>> watchTags() => select(tags).watch();
  Future<List<Tag>> getTagsOnce() => select(tags).get();

  // TASKS CRUD 

  Future<int> addTask({
    required String title,
    required DateTime dueDate,
    required int priority,
    required int tagId,
  }) {
    return into(tasks).insert(TasksCompanion(
      title: Value(title.trim()),
      dueDate: Value(dueDate),
      priority: Value(priority),
      tagId: Value(tagId),
      // isDone default false
    ));
  }

  Future<void> updateTask({
    required int id,
    String? title,
    DateTime? dueDate,
    int? priority,
    int? tagId,
    bool? isDone,
  }) async {
    await (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        title: title == null ? const Value.absent() : Value(title.trim()),
        dueDate: dueDate == null ? const Value.absent() : Value(dueDate),
        priority: priority == null ? const Value.absent() : Value(priority),
        tagId: tagId == null ? const Value.absent() : Value(tagId),
        isDone: isDone == null ? const Value.absent() : Value(isDone),
      ),
    );
  }

  Future<void> deleteTask(int id) async {
    await (delete(tasks)..where((t) => t.id.equals(id))).go();
  }

  //  WATCH / GET 

  Stream<List<TaskWithTag>> watchTasks(TaskSort sort) {
    final q = select(tasks).join([
      innerJoin(tags, tags.id.equalsExp(tasks.tagId)),
    ]);

    if (sort == TaskSort.byDate) {
      q.orderBy([OrderingTerm.asc(tasks.dueDate)]);
    } else {
      q.orderBy([
        OrderingTerm.desc(tasks.priority),
        OrderingTerm.asc(tasks.dueDate),
      ]);
    }

    return q.watch().map((rows) {
      return rows
          .map((r) => TaskWithTag(
                task: r.readTable(tasks),
                tag: r.readTable(tags),
              ))
          .toList();
    });
  }

  Future<List<TaskWithTag>> getTasksOnce(TaskSort sort) => watchTasks(sort).first;

  // JSON EXPORT / IMPORT

  Future<Map<String, dynamic>> exportToJsonMap() async {
    final allTags = await getTagsOnce();
    final allTasks = await select(tasks).get();

    return {
      "tags": allTags.map((t) => {"id": t.id, "name": t.name}).toList(),
      // чтобы импорт был проще — кладём tagName (а не только tagId)
      "tasks": allTasks.map((t) {
        final tagName =
            allTags.firstWhere((x) => x.id == t.tagId, orElse: () => const Tag(id: 0, name: "Unknown")).name;

        return {
          "id": t.id,
          "title": t.title,
          "dueDate": t.dueDate.toIso8601String(),
          "priority": t.priority,
          "tagName": tagName,
          "isDone": t.isDone,
        };
      }).toList(),
    };
  }

  Future<File> exportToJsonFile(File file) async {
    final map = await exportToJsonMap();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(map);
    return file.writeAsString(jsonStr);
  }

  Future<void> importFromJsonMap(Map<String, dynamic> json) async {
    await transaction(() async {
      final tagsJson = (json["tags"] as List).cast<Map<String, dynamic>>();
      final tasksJson = (json["tasks"] as List).cast<Map<String, dynamic>>();

      // очистка (простая версия)
      await delete(tasks).go();
      await delete(tags).go();

      // импорт тегов
      for (final t in tagsJson) {
        await addTag((t["name"] as String));
      }

      final allTags = await getTagsOnce();
      final nameToId = {for (final t in allTags) t.name: t.id};

      // импорт задач
      for (final t in tasksJson) {
        final tagName = (t["tagName"] as String?) ?? "General";
        final tagId = nameToId[tagName] ?? (await addTag(tagName));

        await addTask(
          title: (t["title"] as String),
          dueDate: DateTime.parse(t["dueDate"] as String),
          priority: (t["priority"] as num).toInt(),
          tagId: tagId,
        );

        
      }
    });
  }

  Future<void> importFromJsonFile(File file) async {
    final text = await file.readAsString();
    final jsonMap = jsonDecode(text) as Map<String, dynamic>;
    await importFromJsonMap(jsonMap);
  }
}
