import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/app_dao.dart';
import '../db/app_database.dart';

class EditTaskScreen extends StatefulWidget {
  final int? taskId;
  final String? initialTitle;
  final DateTime? initialDueDate;
  final int? initialPriority;
  final int? initialTagId;

  const EditTaskScreen({
    super.key,
    this.taskId,
    this.initialTitle,
    this.initialDueDate,
    this.initialPriority,
    this.initialTagId,
  });

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  late final TextEditingController titleCtrl;
  DateTime? dueDate;
  int priority = 3;
  int? tagId;

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.initialTitle ?? '');
    dueDate = widget.initialDueDate ?? DateTime.now().add(const Duration(days: 1));
    priority = widget.initialPriority ?? 3;
    tagId = widget.initialTagId;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: dueDate ?? now,
    );
    if (picked != null) {
      setState(() {
        dueDate = DateTime(picked.year, picked.month, picked.day, dueDate?.hour ?? 12);
      });
    }
  }

  Future<void> _save() async {
    final dao = context.read<AppDao>();
    final title = titleCtrl.text.trim();
    if (title.isEmpty || dueDate == null || tagId == null) return;

    if (widget.taskId == null) {
      await dao.addTask(
        title: title,
        dueDate: dueDate!,
        priority: priority,
        tagId: tagId!,
      );
    } else {
      await dao.updateTask(
        id: widget.taskId!,
        title: title,
        dueDate: dueDate,
        priority: priority,
        tagId: tagId,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dao = context.read<AppDao>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.taskId == null ? 'Добавить задачу' : 'Редактировать')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text(dueDate == null ? 'Дата не выбрана' : 'Дата: ${dueDate!.toLocal()}'.split('.').first),
                ),
                TextButton(onPressed: _pickDate, child: const Text('Выбрать дату')),
              ],
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Приоритет:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: priority,
                  items: [1, 2, 3, 4, 5]
                      .map((p) => DropdownMenuItem(value: p, child: Text('$p')))
                      .toList(),
                  onChanged: (v) => setState(() => priority = v ?? 3),
                ),
              ],
            ),

            const SizedBox(height: 12),
            StreamBuilder<List<Tag>>(
              stream: dao.watchTags(),
              builder: (context, snap) {
                final tags = snap.data ?? [];
                if (!snap.hasData) return const LinearProgressIndicator();

                // если нет тегов — подсказка
                if (tags.isEmpty) {
                  return const Text('Сначала добавь теги на экране "Теги".');
                }

                tagId ??= tags.first.id;

                return Row(
                  children: [
                    const Text('Тег:'),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: tagId,
                      items: tags
                          .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                          .toList(),
                      onChanged: (v) => setState(() => tagId = v),
                    ),
                  ],
                );
              },
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}