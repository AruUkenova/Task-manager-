import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/app_dao.dart';

class JsonService {
  Future<File> defaultJsonFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'backup.json'));
  }

  Future<File> export(AppDao dao) async {
    final file = await defaultJsonFile();
    return dao.exportToJsonFile(file);
  }

  Future<void> import(AppDao dao) async {
    final file = await defaultJsonFile();
    if (await file.exists()) {
      await dao.importFromJsonFile(file);
    } else {
      throw Exception("Файл backup.json не найден");
    }
  }
}