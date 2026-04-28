import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task_model.dart';
import '../models/filter_model.dart';

class DatabaseHelper {
  static const _databaseName = "TreeTaskDB.db";
  static const _databaseVersion = 12; // 升级为 V12

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
    if (oldVersion < 11) {
      try { await db.execute('ALTER TABLE tasks ADD COLUMN type TEXT DEFAULT "normal"'); } catch (_) {}
      try { await db.execute('ALTER TABLE tasks ADD COLUMN frequency TEXT DEFAULT ""'); } catch (_) {}
      await db.execute('CREATE TABLE IF NOT EXISTS habit_logs (taskId TEXT, date TEXT, PRIMARY KEY (taskId, date), FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE CASCADE)');
    }
    if (oldVersion < 12) {
      try { await db.execute('ALTER TABLE tasks ADD COLUMN duration INTEGER DEFAULT 0'); } catch (_) {}
    }
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, description TEXT, targetTime TEXT, isCompleted INTEGER NOT NULL, sortOrder INTEGER DEFAULT 0, type TEXT DEFAULT "normal", frequency TEXT DEFAULT "", duration INTEGER DEFAULT 0)');
    await db.execute('CREATE TABLE tags (id TEXT PRIMARY KEY, name TEXT NOT NULL, parentId TEXT, sortOrder INTEGER DEFAULT 0)');
    await db.execute('CREATE TABLE task_tags (taskId TEXT, tagId TEXT, PRIMARY KEY (taskId, tagId), FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE CASCADE)');
    await db.execute('CREATE TABLE filter_groups (id TEXT PRIMARY KEY, name TEXT NOT NULL, sortOrder INTEGER DEFAULT 0)');
    await db.execute('CREATE TABLE saved_filters (id TEXT PRIMARY KEY, name TEXT NOT NULL, groupIds TEXT NOT NULL, sortOrder INTEGER DEFAULT 0, timeFilter TEXT NOT NULL, customDaysBefore INTEGER, customDaysAfter INTEGER, tagIds TEXT NOT NULL, showCompleted INTEGER DEFAULT 1, displayTagIds TEXT DEFAULT "")');
    await db.execute('CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)');
    await db.execute('CREATE TABLE habit_logs (taskId TEXT, date TEXT, PRIMARY KEY (taskId, date), FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE CASCADE)');
  }

  // ============ 设置与分组管理 ============
  Future<String?> getSetting(String key) async {
    Database db = await instance.database;
    final res = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return res.isNotEmpty ? res.first['value'] as String : null;
  }
  Future<void> saveSetting(String key, String value) async {
    Database db = await instance.database;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<void> updateGroupOrders(List<FilterGroup> groups) async {
    Database db = await instance.database;
    await db.transaction((txn) async { for (int i = 0; i < groups.length; i++) await txn.update('filter_groups', {'sortOrder': i}, where: 'id = ?', whereArgs: [groups[i].id]); });
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

  // ============ 集子管理 ============
  Future<void> insertSavedFilter(TaskFilter filter) async {
    Database db = await instance.database;
    await db.insert('saved_filters', {
      'id': filter.id ?? DateTime.now().millisecondsSinceEpoch.toString(), 'name': filter.name ?? '未命名', 'groupIds': filter.groupIds.join(','),
      'sortOrder': filter.sortOrder == 0 ? DateTime.now().millisecondsSinceEpoch : filter.sortOrder, 'timeFilter': filter.timeFilter.name,
      'customDaysBefore': filter.customDaysBefore, 'customDaysAfter': filter.customDaysAfter, 'tagIds': filter.selectedTags.map((e) => e.id).join(','),
      'showCompleted': filter.showCompleted ? 1 : 0, 'displayTagIds': filter.displayTags.map((e) => e.id).join(','),
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
        selectedTags: tags.where((t) => tagIds.contains(t.id)).toList(), showCompleted: showComp == null || showComp == 1,
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
  Future<List<TaskFilter>> getAllFiltersUnscoped() async {
    Database db = await instance.database;
    final maps = await db.query('saved_filters', orderBy: 'sortOrder ASC');
    return maps.map((map) => TaskFilter(id: map['id'] as String, name: map['name'] as String)).toList();
  }
  Future<void> updateFiltersDisplayTags(List<String> filterIds, List<String> tagIdsToAdd) async {
    Database db = await instance.database;
    final maps = await db.query('saved_filters', where: 'id IN (${filterIds.map((_) => '?').join(',')})', whereArgs: filterIds);
    for (var map in maps) {
      final dTagsStr = map['displayTagIds'] as String?;
      final currentTags = dTagsStr != null ? dTagsStr.split(',').where((id) => id.isNotEmpty).toList() : <String>[];
      final newTags = {...currentTags, ...tagIdsToAdd}.toList();
      await db.update('saved_filters', {'displayTagIds': newTags.join(',')}, where: 'id = ?', whereArgs: [map['id']]);
    }
  }

  // ============ 标签管理 ============
  Future<List<Tag>> _getAllTagsInternal(Database db) async {
    final maps = await db.query('tags', orderBy: 'sortOrder ASC');
    return maps.map((m) => Tag(id: m['id'] as String, name: m['name'] as String, parentId: m['parentId'] as String?)).toList();
  }
  Future<List<Tag>> getAllTags() async => _getAllTagsInternal(await instance.database);
  Future<void> insertTag(Tag tag) async {
    Database db = await instance.database;
    await db.insert('tags', {'id': tag.id, 'name': tag.name, 'parentId': tag.parentId, 'sortOrder': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<void> updateTagOrders(List<Tag> tags) async {
    Database db = await instance.database;
    await db.transaction((txn) async { for (int i = 0; i < tags.length; i++) await txn.update('tags', {'sortOrder': i}, where: 'id = ?', whereArgs: [tags[i].id]); });
  }
  Future<void> moveTags(List<String> tagIds, String? newParentId) async {
    Database db = await instance.database;
    await db.transaction((txn) async { for (var id in tagIds) await txn.update('tags', {'parentId': newParentId}, where: 'id = ?', whereArgs: [id]); });
  }
  Future<void> deleteTags(List<String> ids) async {
    Database db = await instance.database;
    final allTags = await getAllTags();
    Set<String> idsToDelete = {};
    void findDescendants(String currentId) {
      idsToDelete.add(currentId);
      for (var child in allTags.where((t) => t.parentId == currentId)) findDescendants(child.id);
    }
    for (var id in ids) findDescendants(id);
    if (idsToDelete.isNotEmpty) {
      String placeholders = List.filled(idsToDelete.length, '?').join(',');
      await db.delete('tags', where: 'id IN ($placeholders)', whereArgs: idsToDelete.toList());
    }
  }

  // ============ 任务与习惯核心逻辑 ============
  Future<void> insertTask(TreeTaskItem task) async {
    Database db = await instance.database;
    await db.transaction((txn) async {
      await txn.insert('tasks', {
        'id': task.id, 'title': task.title, 'description': task.description, 'targetTime': task.targetTime?.toIso8601String(),
        'isCompleted': task.isCompleted ? 1 : 0, 'sortOrder': task.sortOrder,
        'type': task.type.name, 'frequency': task.frequency.join(','), 'duration': task.duration ?? 0
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('task_tags', where: 'taskId = ?', whereArgs: [task.id]);
      for (var tag in task.tags) await txn.insert('task_tags', {'taskId': task.id, 'tagId': tag.id});
    });
  }

  Future<void> toggleHabitLog(String taskId, DateTime date, bool isCompleted) async {
    Database db = await instance.database;
    String dateStr = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
    if (isCompleted) {
      await db.insert('habit_logs', {'taskId': taskId, 'date': dateStr}, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete('habit_logs', where: 'taskId = ? AND date = ?', whereArgs: [taskId, dateStr]);
    }
  }

  Future<List<String>> getHabitLogs(String taskId) async {
    Database db = await instance.database;
    final maps = await db.query('habit_logs', where: 'taskId = ?', whereArgs: [taskId]);
    return maps.map((m) => m['date'] as String).toList();
  }

  Future<void> updateTaskOrders(List<TreeTaskItem> tasks) async {
    Database db = await instance.database;
    await db.transaction((txn) async { for (int i = 0; i < tasks.length; i++) await txn.update('tasks', {'sortOrder': i}, where: 'id = ?', whereArgs: [tasks[i].id]); });
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
    String baseWhere = '1=1';
    List<dynamic> baseArgs = [];
    DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    // 提取集子包含的所有日期范围
    List<DateTime> dateRange = [];
    if (filter.timeFilter == TimeFilter.today || filter.timeFilter == TimeFilter.all) {
      dateRange.add(today);
    } else if (filter.timeFilter == TimeFilter.tomorrow) {
      dateRange.add(today.add(const Duration(days: 1)));
    } else if (filter.timeFilter == TimeFilter.week) {
      DateTime start = today.subtract(Duration(days: today.weekday - 1));
      for (int i=0; i<7; i++) dateRange.add(start.add(Duration(days: i)));
    } else if (filter.timeFilter == TimeFilter.nextWeek) {
      DateTime start = today.subtract(Duration(days: today.weekday - 1)).add(const Duration(days: 7));
      for (int i=0; i<7; i++) dateRange.add(start.add(Duration(days: i)));
    } else if (filter.timeFilter == TimeFilter.month) {
      DateTime start = DateTime(today.year, today.month, 1);
      int days = DateTime(today.year, today.month + 1, 0).day;
      for (int i=0; i<days; i++) dateRange.add(start.add(Duration(days: i)));
    } else if (filter.timeFilter == TimeFilter.customDays && filter.customDaysBefore != null && filter.customDaysAfter != null) {
      DateTime start = today.subtract(Duration(days: filter.customDaysBefore!));
      int days = filter.customDaysBefore! + filter.customDaysAfter! + 1;
      for (int i=0; i<days; i++) dateRange.add(start.add(Duration(days: i)));
    }

    // 标签过滤条件
    if (filter.selectedTags.isNotEmpty) {
      List<String> tagIds = filter.selectedTags.map((t) => t.id).toList();
      String placeholders = List.filled(tagIds.length, '?').join(',');
      baseWhere += ' AND id IN (SELECT taskId FROM task_tags WHERE tagId IN ($placeholders))';
      baseArgs.addAll(tagIds);
    }

    List<TreeTaskItem> results = [];
    final allTags = await _getAllTagsInternal(db);

    // ============ 1. 获取并处理普通任务 ============
    String normalWhere = baseWhere + " AND (type = 'normal' OR type IS NULL)";
    List<dynamic> normalArgs = List.from(baseArgs);
    
    if (filter.timeFilter == TimeFilter.overdue) {
      normalWhere += ' AND targetTime < ? AND isCompleted = 0'; normalArgs.add(today.toIso8601String());
    } else if (dateRange.isNotEmpty) {
      normalWhere += ' AND targetTime >= ? AND targetTime < ?'; 
      normalArgs.addAll([dateRange.first.toIso8601String(), dateRange.last.add(const Duration(days: 1)).toIso8601String()]);
    }
    if (!filter.showCompleted) normalWhere += ' AND isCompleted = 0';

    final normalMaps = await db.query('tasks', where: normalWhere, whereArgs: normalArgs);
    for (Map<String, Object?> map in normalMaps) {
      String taskId = map['id'] as String;
      final tagMaps = await db.rawQuery('SELECT tId.tagId FROM task_tags tId WHERE tId.taskId = ?', [taskId]);
      List<String> myTagIds = tagMaps.map((e) => e['tagId'] as String).toList();
      List<Tag> taskTags = allTags.where((t) => myTagIds.contains(t.id)).toList();
      results.add(TreeTaskItem(
        id: taskId, type: TaskType.normal, title: map['title'] as String, description: map['description'] as String, 
        targetTime: map['targetTime'] != null ? DateTime.parse(map['targetTime'] as String) : null, 
        tags: taskTags, isCompleted: (map['isCompleted'] as int) == 1, sortOrder: map['sortOrder'] as int
      ));
    }

    // ============ 2. 获取并处理习惯 (严格校验日期边界) ============
    if (filter.timeFilter != TimeFilter.overdue && dateRange.isNotEmpty) {
      String habitWhere = baseWhere + " AND type = 'habit'";
      final habitMaps = await db.query('tasks', where: habitWhere, whereArgs: baseArgs);
      
      for (Map<String, Object?> map in habitMaps) {
        String taskId = map['id'] as String;
        List<int> freq = (map['frequency'] as String).split(',').where((e) => e.isNotEmpty).map(int.parse).toList();
        
        final tagMaps = await db.rawQuery('SELECT tId.tagId FROM task_tags tId WHERE tId.taskId = ?', [taskId]);
        List<String> myTagIds = tagMaps.map((e) => e['tagId'] as String).toList();
        List<Tag> taskTags = allTags.where((t) => myTagIds.contains(t.id)).toList();
        final logs = await getHabitLogs(taskId);

        // 计算生命周期边界
        DateTime habitStart = map['targetTime'] != null ? DateTime.parse(map['targetTime'] as String) : today;
        habitStart = DateTime(habitStart.year, habitStart.month, habitStart.day);
        int duration = (map['duration'] as int?) ?? 21;
        DateTime habitEnd = habitStart.add(Duration(days: duration > 0 ? duration - 1 : 0));

        for (DateTime day in dateRange) {
          // 核心校验：这一天必须在习惯的生命周期 [startDate, endDate] 之内！
          if (day.isBefore(habitStart) || day.isAfter(habitEnd)) continue;
          
          if (freq.contains(day.weekday)) {
            String dayStr = "${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}";
            bool isComp = logs.contains(dayStr);
            if (!filter.showCompleted && isComp) continue;

            results.add(TreeTaskItem(
              id: taskId, type: TaskType.habit, title: map['title'] as String, description: map['description'] as String, 
              targetTime: day, tags: taskTags, isCompleted: isComp, sortOrder: map['sortOrder'] as int, 
              frequency: freq, duration: duration
            ));
          }
        }
      }
    }

    results.sort((a, b) {
      int sortCmp = a.sortOrder.compareTo(b.sortOrder);
      if (sortCmp != 0) return sortCmp;
      if (a.targetTime == null && b.targetTime == null) return 0;
      if (a.targetTime == null) return 1;
      if (b.targetTime == null) return -1;
      return a.targetTime!.compareTo(b.targetTime!);
    });

    return results;
  }
}