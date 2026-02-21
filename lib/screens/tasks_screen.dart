import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/app_dao.dart';
import '../models/task_with_tag.dart';
import '../services/json_service.dart';
import 'edit_task_screen.dart';
import 'tags_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  TaskSort sort = TaskSort.byDate;
  final jsonService = JsonService();

  Future<void> _openAdd() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditTaskScreen()),
    );
  }

  Future<void> _openEdit(TaskWithTag item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditTaskScreen(
          taskId: item.task.id,
          initialTitle: item.task.title,
          initialDueDate: item.task.dueDate,
          initialPriority: item.task.priority,
          initialTagId: item.task.tagId,
        ),
      ),
    );
  }

  Future<void> _showGetOnceDialog() async {
    final dao = context.read<AppDao>();
    final list = await dao.getTasksOnce(sort);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('get() — разовая загрузка'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: list.length,
            itemBuilder: (_, i) {
              final t = list[i];
              return ListTile(
                title: Text(t.task.title),
                subtitle: Text('${t.tag.name} • p=${t.task.priority}'),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _exportJson() async {
    final dao = context.read<AppDao>();
    try {
      final File file = await jsonService.export(dao);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Экспортировано: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка экспорта: $e')),
      );
    }
  }

  Future<void> _importJson() async {
    final dao = context.read<AppDao>();
    try {
      await jsonService.import(dao);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Импорт выполнен')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка импорта: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dao = context.read<AppDao>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks (Drift)'),
        actions: [
          IconButton(
            tooltip: 'Теги',
            icon: const Icon(Icons.sell),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TagsScreen())),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'get') await _showGetOnceDialog();
              if (v == 'export') await _exportJson();
              if (v == 'import') await _importJson();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'get', child: Text('Сравнить: get()')),
              PopupMenuItem(value: 'export', child: Text('Экспорт JSON')),
              PopupMenuItem(value: 'import', child: Text('Импорт JSON')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('Сортировка:'),
                const SizedBox(width: 12),
                DropdownButton<TaskSort>(
                  value: sort,
                  items: const [
                    DropdownMenuItem(value: TaskSort.byDate, child: Text('По дате')),
                    DropdownMenuItem(value: TaskSort.byPriority, child: Text('По приоритету')),
                  ],
                  onChanged: (v) => setState(() => sort = v ?? TaskSort.byDate),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<TaskWithTag>>(
              stream: dao.watchTasks(sort), // <-- STREAM watch()
              builder: (context, snap) {
                final items = snap.data ?? [];
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());

                if (items.isEmpty) {
                  return const Center(child: Text('Задач нет. Нажми + чтобы добавить.'));
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final t = item.task;
                    return ListTile(
                      title: Text(
                        t.title,
                        style: TextStyle(
                          decoration: t.isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Text('${item.tag.name} • due: ${t.dueDate.toLocal().toString().split('.').first} • p=${t.priority}'),
                      leading: Checkbox(
                        value: t.isDone,
                        onChanged: (v) => dao.updateTask(id: t.id, isDone: v ?? false),
                      ),
                      onTap: () => _openEdit(item),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => dao.deleteTask(t.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}