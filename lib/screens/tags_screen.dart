import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/app_dao.dart';

class TagsScreen extends StatelessWidget {
  const TagsScreen({super.key});

  Future<void> _addTagDialog(BuildContext context) async {
    final dao = context.read<AppDao>();
    final controller = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Новый тег'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Например: School'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Добавить')),
        ],
      ),
    );

    if (ok == true && controller.text.trim().isNotEmpty) {
      await dao.addTag(controller.text);
    }
  }

  Future<void> _renameTagDialog(BuildContext context, int id, String oldName) async {
    final dao = context.read<AppDao>();
    final controller = TextEditingController(text: oldName);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Переименовать тег'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Сохранить')),
        ],
      ),
    );

    if (ok == true && controller.text.trim().isNotEmpty) {
      await dao.updateTag(id, controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dao = context.read<AppDao>();

    return Scaffold(
      appBar: AppBar(title: const Text('Теги')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTagDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder(
        stream: dao.watchTags(),
        builder: (context, snap) {
          final tags = snap.data ?? [];
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (tags.isEmpty) return const Center(child: Text('Тегов нет. Добавь первый.'));

          return ListView.separated(
            itemCount: tags.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final t = tags[i];
              return ListTile(
                title: Text(t.name),
                onTap: () => _renameTagDialog(context, t.id, t.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    try {
                      await dao.deleteTag(t.id);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Нельзя удалить: есть задачи с этим тегом')),
                        );
                      }
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}