import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task_model.dart';
import '../models/filter_model.dart';

class DatabaseHelper {
  static const _databaseName = "TreeTaskDB.db";
  static const _databaseVersion = 9; // 升级为 V9

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(path, version: _databaseVersion, onUpgrade: _onUpgrade, onCreate: _onCreate);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.execute('DROP TABLE IF EXISTS tasks');
    await db.execute('DROP TABLE IF EXISTS tags');
    await db.execute('DROP TABLE IF EXISTS task_tags');
    await db.execute('DROP TABLE IF EXISTS saved_filters');
    await db.execute('DROP TABLE IF EXISTS filter_groups');
    await db.execute('DROP TABLE IF EXISTS settings'); // 清理设置表
    await _onCreate(db, newVersion);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT, targetTime TEXT, isCompleted INTEGER NOT NULL, sortOrder INTEGER DEFAULT 0)');
    await db.execute('CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT NOT NULL, parentId TEXT)');
    await db.execute('CREATE TABLE task_tags (taskId TEXT, tagId TEXT, PRIMARY KEY (taskId, tagId), FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE filter_groups (id TEXT PRIMARY KEY, name TEXT NOT NULL, sortOrder INTEGER DEFAULT 0)');
    await db.execute('CREATE TABLE saved_filters (id TEXT PRIMARY KEY, name TEXT NOT NULL, groupIds TEXT NOT NULL, sortOrder INTEGER DEFAULT 0, timeFilter TEXT NOT NULL, customDaysBefore INTEGER, customDaysAfter INTEGER, tagIds TEXT NOT NULL, showCompleted INTEGER DEFAULT 1, displayTagIds TEXT DEFAULT "")');
    
    // 新增：设置表
    await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)');
  }

  // ================= 存取系统设置 =================
  Future<String?> getSetting(String key) async {
    Database db = await instance.database;
    final res = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (res.isNotEmpty) return res.first['value'] as String;
    return null;
  }

  Future<void> saveSetting(String key, String value) async {
    Database db = await instance.database;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  // ===============================================

  Future<void> updateGroupOrders(List<FilterGroup> groups) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      for (int i = 0; i < groups.length; i++) {
        await txn.update('filter_groups', {'sortOrder': i}, where: 'id = ?', whereArgs: [groups[i].id]);
      }
    });
  }

  Future<List<FilterGroup>> getGroups() async {
    Database db = await instance.database;
    final maps = await db.query('filter_groups', orderBy: 'sortOrder ASC');
    return maps.map((m) => FilterGroup(id: m['id'] as String, name: m['name'] as String, sortOrder: m['sortOrder'] as int)).toList();
  }

  Future<String> createGroup(String groupName) async {
    Database db = await instance.database;
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    await db.insert('filter_groups', {'id': newId, 'name': groupName, 'sortOrder': DateTime.now().millisecondsSinceEpoch});
    return newId;
  }

  Future<void> deleteGroup(String groupId) async {
    Database db = await instance.database;
    await db.delete('filter_groups', where: 'id = ?', whereArgs: [groupId]);
    final filters = await db.query('saved_filters');
    for (var map in filters) {
      final gIds = (map['groupIds'] as String).split(',').where((e) => e.isNotEmpty).toList();
      if (gIds.contains(groupId)) {
        gIds.remove(groupId);
        await db.update('saved_filters', {'groupIds': gIds.join(',')}, where: 'id = ?', whereArgs: [map['id']]);
      }
    }
  }

  Future<void> insertSavedFilter(TaskFilter filter) async {
    Database db = await instance.database;
    await db.insert('saved_filters', {
      'id': filter.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'name': filter.name ?? '未命名',
      'groupIds': filter.groupIds.join(','),
      'sortOrder': filter.sortOrder == 0 ? DateTime.now().millisecondsSinceEpoch : filter.sortOrder,
      'timeFilter': filter.timeFilter.name,
      'customDaysBefore': filter.customDaysBefore,
      'customDaysAfter': filter.customDaysAfter,
      'tagIds': filter.selectedTags.map((e) => e.id).join(','),
      'showCompleted': filter.showCompleted ? 1 : 0,
      'displayTagIds': filter.displayTags.map((e) => e.id).join(','),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TaskFilter>> getSavedFilters(String? targetGroupId) async {
    Database db = await instance.database;
    final maps = await db.query('saved_filters', orderBy: 'sortOrder ASC');
    final tags = await _getAllTagsInternal(db);
    
    List<TaskFilter> allFilters = maps.map((map) {
      final tagIds = (map['tagIds'] as String).split(',').where((id) => id.isNotEmpty).toList();
      final gIds = (map['groupIds'] as String).split(',').where((id) => id.isNotEmpty).toList();
      final dTagsStr = map['displayTagIds'] as String?;
      final displayTagIds = dTagsStr != null ? dTagsStr.split(',').where((id) => id.isNotEmpty).toList() : [];
      final showComp = map['showCompleted'] as int?;

      return TaskFilter(
        id: map['id'] as String, name: map['name'] as String, groupIds: gIds, sortOrder: map['sortOrder'] as int,
        timeFilter: TimeFilter.values.firstWhere((e) => e.name == map['timeFilter'], orElse: () => TimeFilter.all),
        customDaysBefore: map['customDaysBefore'] as int?, customDaysAfter: map['customDaysAfter'] as int?,
        selectedTags: tags.where((t) => tagIds.contains(t.id)).toList(),
        showCompleted: showComp == null || showComp == 1,
        displayTags: tags.where((t) => displayTagIds.contains(t.id)).toList(),
      );
    }).toList();

    if (targetGroupId == null) return allFilters.where((f) => f.groupIds.isEmpty).toList();
    return allFilters.where((f) => f.groupIds.contains(targetGroupId)).toList();
  }

  Future<void> swapFilterOrder(TaskFilter f1, TaskFilter f2) async {
    Database db = await instance.database;
    await db.update('saved_filters', {'sortOrder': f2.sortOrder}, where: 'id = ?', whereArgs: [f1.id]);
    await db.update('saved_filters', {'sortOrder': f1.sortOrder}, where: 'id = ?', whereArgs: [f2.id]);
  }

  Future<void> deleteSavedFilter(String id) async {
    Database db = await instance.database;
    await db.delete('saved_filters', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Tag>> _getAllTagsInternal(Database db) async {
    final maps = await db.query('tags');
    return maps.map((m) => Tag(id: m['id'] as String, name: m['name'] as String, parentId: m['parentId'] as String?)).toList();
  }
  
  Future<List<Tag>> getAllTags() async => _getAllTagsInternal(await instance.database);

  Future<void> insertTag(Tag tag) async {
    Database db = await instance.database;
    await db.insert('tags', {'id': tag.id, 'name': tag.name, 'parentId': tag.parentId}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTag(String id) async {
    Database db = await instance.database;
    final allTags = await getAllTags();
    List<String> idsToDelete = [];
    void findDescendants(String currentId) {
      idsToDelete.add(currentId);
      for (var child in allTags.where((t) => t.parentId == currentId)) findDescendants(child.id);
    }
    findDescendants(id);
    if (idsToDelete.isNotEmpty) {
      String placeholders = List.filled(idsToDelete.length, '?').join(',');
      await db.delete('tags', where: 'id IN ($placeholders)', whereArgs: idsToDelete);
    }
  }

  Future<void> insertTask(TreeTaskItem task) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      await txn.insert('tasks', {'id': task.id, 'title': task.title, 'description': task.description, 'targetTime': task.targetTime?.toIso8601String(), 'isCompleted': task.isCompleted ? 1 : 0, 'sortOrder': task.sortOrder}, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('task_tags', where: 'taskId = ?', whereArgs: [task.id]);
      for (var tag in task.tags) await txn.insert('task_tags', {'taskId': task.id, 'tagId': tag.id});
    });
  }

  Future<void> updateTaskOrders(List<TreeTaskItem> tasks) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      for (int i = 0; i < tasks.length; i++) {
        await txn.update('tasks', {'sortOrder': i}, where: 'id = ?', whereArgs: [tasks[i].id]);
      }
    });
  }

  Future<void> deleteTask(String taskId) async {
    Database db = await instance.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [taskId]);
  }

  Future<void> updateTaskCompletion(String taskId, bool isCompleted) async {
    Database db = await instance.database;
    await db.update('tasks', {'isCompleted': isCompleted ? 1 : 0}, where: 'id = ?', whereArgs: [taskId]);
  }

  Future<List<TreeTaskItem>> getFilteredTasks(TaskFilter filter) async {
    Database db = await instance.database;
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    if (!filter.showCompleted) whereClause += ' AND isCompleted = 0';

    if (filter.timeFilter == TimeFilter.overdue) {
      whereClause += ' AND targetTime < ? AND isCompleted = 0'; whereArgs.add(today.toIso8601String());
    } else if (filter.timeFilter == TimeFilter.today) {
      final end = today.add(const Duration(days: 1)); whereClause += ' AND targetTime >= ? AND targetTime < ?'; whereArgs.addAll([today.toIso8601String(), end.toIso8601String()]);
    } else if (filter.timeFilter == TimeFilter.tomorrow) {
      final start = today.add(const Duration(days: 1)); final end = start.add(const Duration(days: 1)); whereClause += ' AND targetTime >= ? AND targetTime < ?'; whereArgs.addAll([start.toIso8601String(), end.toIso8601String()]);
    } else if (filter.timeFilter == TimeFilter.week) {
      final start = today.subtract(Duration(days: today.weekday - 1)); final end = start.add(const Duration(days: 7)); whereClause += ' AND targetTime >= ? AND targetTime < ?'; whereArgs.addAll([start.toIso8601String(), end.toIso8601String()]);
    } else if (filter.timeFilter == TimeFilter.nextWeek) {
      final start = today.subtract(Duration(days: today.weekday - 1)).add(const Duration(days: 7)); final end = start.add(const Duration(days: 7)); whereClause += ' AND targetTime >= ? AND targetTime < ?'; whereArgs.addAll([start.toIso8601String(), end.toIso8601String()]);
    } else if (filter.timeFilter == TimeFilter.month) {
      final start = DateTime(today.year, today.month, 1); final end = DateTime(today.year, today.month + 1, 1); whereClause += ' AND targetTime >= ? AND targetTime < ?'; whereArgs.addAll([start.toIso8601String(), end.toIso8601String()]);
    } else if (filter.timeFilter == TimeFilter.nextMonth) {
      final start = DateTime(today.year, today.month + 1, 1); final end = DateTime(today.year, today.month + 2, 1); whereClause += ' AND targetTime >= ? AND targetTime < ?'; whereArgs.addAll([start.toIso8601String(), end.toIso8601String()]);
    } else if (filter.timeFilter == TimeFilter.customDays && filter.customDaysBefore != null && filter.customDaysAfter != null) {
      final start = today.subtract(Duration(days: filter.customDaysBefore!)); final end = today.add(Duration(days: filter.customDaysAfter! + 1)); whereClause += ' AND targetTime >= ? AND targetTime < ?'; whereArgs.addAll([start.toIso8601String(), end.toIso8601String()]);
    }

    if (filter.selectedTags.isNotEmpty) {
      List<String> tagIds = filter.selectedTags.map((t) => t.id).toList();
      String placeholders = List.filled(tagIds.length, '?').join(',');
      whereClause += ' AND id IN (SELECT taskId FROM task_tags WHERE tagId IN ($placeholders))';
      whereArgs.addAll(tagIds);
    }

    final taskMaps = await db.query('tasks', where: whereClause, whereArgs: whereArgs, orderBy: 'sortOrder ASC, targetTime ASC');
    List<TreeTaskItem> tasks = [];
    for (Map<String, Object?> map in taskMaps) {
      String taskId = map['id'] as String;
      final tagMaps = await db.rawQuery('SELECT t.* FROM tags t INNER JOIN task_tags tt ON t.id = tt.tagId WHERE tt.taskId = ?', [taskId]);
      List<Tag> taskTags = tagMaps.map((t) => Tag(id: t['id'] as String, name: t['name'] as String, parentId: t['parentId'] as String?)).toList();
      tasks.add(TreeTaskItem(
        id: taskId, title: map['title'] as String, description: map['description'] as String, 
        targetTime: map['targetTime'] != null ? DateTime.parse(map['targetTime'] as String) : null, 
        tags: taskTags, isCompleted: (map['isCompleted'] as int) == 1, sortOrder: map['sortOrder'] as int
      ));
    }
    return tasks;
  }
}