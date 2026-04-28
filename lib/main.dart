import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/tag_management_page.dart';
import 'pages/group_management_page.dart';
import 'pages/filter_page.dart';
import 'pages/settings_page.dart';
import 'pages/habit_detail_page.dart';
import 'widgets/task_bottom_sheet.dart';
import 'widgets/habit_bottom_sheet.dart';
import 'models/filter_model.dart';
import 'models/task_model.dart';
import 'db/database_helper.dart';

void main() => runApp(const TreeTaskApp());

class TreeTaskApp extends StatelessWidget {
  const TreeTaskApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TreeTask',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: const [Locale('zh', 'CN')],
      theme: ThemeData(
        useMaterial3: true, scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue, primary: Colors.lightBlue),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.lightBlue, foregroundColor: Colors.white, centerTitle: true, elevation: 0),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<FilterGroup> _groups = [];
  String? _selectedGroupId; 
  List<TaskFilter> _filters = [];
  Map<String, List<TreeTaskItem>> _tasksMap = {};
  
  bool _isLoading = false;
  bool _isDynamicHeight = false; 
  double _fixedRatio = 0.8;      

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final mode = await DatabaseHelper.instance.getSetting('height_mode');
      final ratioStr = await DatabaseHelper.instance.getSetting('fixed_ratio');
      final dynamicMode = mode == 'dynamic';
      final ratio = ratioStr != null ? double.parse(ratioStr) : 0.8;

      final groups = await DatabaseHelper.instance.getGroups();
      final filters = await DatabaseHelper.instance.getSavedFilters(_selectedGroupId);
      final Map<String, List<TreeTaskItem>> newTasksMap = {};
      for (var filter in filters) {
        if (filter.id != null) newTasksMap[filter.id!] = await DatabaseHelper.instance.getFilteredTasks(filter);
      }
      
      if (mounted) { setState(() { _isDynamicHeight = dynamicMode; _fixedRatio = ratio; _groups = groups; _filters = filters; _tasksMap = newTasksMap; }); }
    } finally { if (mounted && showLoading) setState(() => _isLoading = false); }
  }

  Future<void> _toggleTaskStatus(String filterId, TreeTaskItem task, bool val) async {
    // 乐观更新 UI
    setState(() {
      final taskIndex = _tasksMap[filterId]?.indexWhere((t) => t.id == task.id && t.targetTime == task.targetTime) ?? -1;
      if (taskIndex != -1) {
        _tasksMap[filterId]![taskIndex] = TreeTaskItem(
          id: task.id, type: task.type, title: task.title, description: task.description, 
          targetTime: task.targetTime, tags: task.tags, isCompleted: val, sortOrder: task.sortOrder, frequency: task.frequency
        );
      }
    });

    // 根据任务类型分发不同的完成逻辑
    if (task.type == TaskType.habit && task.targetTime != null) {
      await DatabaseHelper.instance.toggleHabitLog(task.id, task.targetTime!, val);
    } else {
      await DatabaseHelper.instance.updateTaskCompletion(task.id, val);
    }
    _loadData(showLoading: false);
  }

  Widget _buildDraggableFilterCard(TaskFilter filter, bool isDynamic) {
    final tasks = _tasksMap[filter.id!] ?? [];
    return DragTarget<TaskFilter>(
      onWillAcceptWithDetails: (details) => details.data.id != filter.id,
      onAcceptWithDetails: (details) async { await DatabaseHelper.instance.swapFilterOrder(details.data, filter); _loadData(showLoading: false); },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return LongPressDraggable<TaskFilter>(
          delay: const Duration(seconds: 1), data: filter,
          feedback: Material(color: Colors.transparent, child: SizedBox(width: MediaQuery.of(context).size.width / 2 - 15, height: isDynamic ? null : (MediaQuery.of(context).size.width / 2 - 15) / _fixedRatio, child: Opacity(opacity: 0.85, child: _buildBlockCard(filter, tasks, isHovered: true, isDynamicHeight: isDynamic)))),
          childWhenDragging: Opacity(opacity: 0.2, child: _buildBlockCard(filter, tasks, isDynamicHeight: isDynamic)),
          child: AnimatedContainer(duration: const Duration(milliseconds: 200), transform: isHovered ? Matrix4.translationValues(0, -4, 0) : Matrix4.identity(), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: isHovered ? [BoxShadow(color: Colors.lightBlue.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)] : []), child: _buildBlockCard(filter, tasks, isHovered: isHovered, isDynamicHeight: isDynamic)),
        );
      },
    );
  }

  Widget _buildBoardContent() {
    if (_filters.isEmpty) return const Center(child: Text('当前分组没有集子\n点击右上角 + 号新建', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
    
    if (_isDynamicHeight) {
      List<Widget> leftCol = []; List<Widget> rightCol = [];
      for (int i = 0; i < _filters.length; i++) {
        Widget card = Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildDraggableFilterCard(_filters[i], true));
        if (i % 2 == 0) leftCol.add(card); else rightCol.add(card);
      }
      return SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Column(children: leftCol)), const SizedBox(width: 10), Expanded(child: Column(children: rightCol))]));
    } else {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0), child: GridView.builder(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: _fixedRatio), itemCount: _filters.length, itemBuilder: (context, index) => _buildDraggableFilterCard(_filters[index], false)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TreeTask'), actions: [IconButton(icon: const Icon(Icons.add), tooltip: '新建集子', onPressed: () async { final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const FilterPage())); if (result == true) _loadData(); })]),
      drawer: Drawer(child: Column(children: [
        const DrawerHeader(decoration: BoxDecoration(color: Colors.lightBlue), child: SizedBox(width: double.infinity, child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [Icon(Icons.account_tree, color: Colors.white, size: 48), SizedBox(height: 12), Text('TreeTask', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))]))),
        Expanded(child: ListView(padding: EdgeInsets.zero, children: [ListTile(leading: const Icon(Icons.label_outline, color: Colors.lightBlue), title: const Text('标签管理'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const TagManagementPage())); }), ListTile(leading: const Icon(Icons.folder_outlined, color: Colors.lightBlue), title: const Text('分组管理'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupManagementPage())).then((_) => _loadData()); })])),
        const Divider(height: 1, color: Colors.black12), ListTile(leading: const Icon(Icons.settings_outlined, color: Colors.black54), title: const Text('设置', style: TextStyle(color: Colors.black87)), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())).then((_) => _loadData(showLoading: false)); }), const SizedBox(height: 16),
      ])),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 50, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              children: [
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: ChoiceChip(label: const Text('默认'), selected: _selectedGroupId == null, selectedColor: Colors.lightBlue.shade100, side: BorderSide.none, onSelected: (s) { if (s) { setState(() => _selectedGroupId = null); _loadData(); } })),
                Expanded(child: ReorderableListView(scrollDirection: Axis.horizontal, proxyDecorator: (Widget child, int index, Animation<double> animation) { return Material(color: Colors.transparent, child: child); }, onReorder: (oldIndex, newIndex) async { if (newIndex > oldIndex) newIndex -= 1; final item = _groups.removeAt(oldIndex); _groups.insert(newIndex, item); setState(() {}); await DatabaseHelper.instance.updateGroupOrders(_groups); _loadData(showLoading: false); }, children: _groups.map((g) => Padding(key: ValueKey(g.id), padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8), child: ChoiceChip(label: Text(g.name), selected: _selectedGroupId == g.id, selectedColor: Colors.lightBlue.shade100, side: BorderSide.none, onSelected: (s) { if (s) { setState(() => _selectedGroupId = g.id); _loadData(); } }))).toList())),
              ],
            ),
          ),
          Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildBoardContent()),
        ],
      ),
      floatingActionButton: GestureDetector(
        // 新增：长按悬浮按钮新建习惯
        onLongPress: () async {
          final result = await HabitBottomSheet.show(context); 
          if (result == true) _loadData(showLoading: false); 
        },
        child: FloatingActionButton(
          backgroundColor: Colors.lightBlue, elevation: 2,
          onPressed: () async { final result = await TaskBottomSheet.show(context); if (result == true) _loadData(showLoading: false); },
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBlockCard(TaskFilter filter, List<TreeTaskItem> tasks, {bool isHovered = false, required bool isDynamicHeight}) {
    Widget listWidget = tasks.isEmpty ? const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('暂无代办', style: TextStyle(color: Colors.black38, fontSize: 11)))) :
      ReorderableListView.builder(
        shrinkWrap: isDynamicHeight, physics: isDynamicHeight ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 4), itemCount: tasks.length, proxyDecorator: (Widget child, int index, Animation<double> animation) { return Material(color: Colors.transparent, child: child); },
        onReorder: (oldIndex, newIndex) async { if (newIndex > oldIndex) newIndex -= 1; final item = tasks.removeAt(oldIndex); tasks.insert(newIndex, item); setState(() { _tasksMap[filter.id!] = tasks; }); await DatabaseHelper.instance.updateTaskOrders(tasks); _loadData(showLoading: false); },
        itemBuilder: (context, taskIndex) {
          final task = tasks[taskIndex];
          String? dateText; Color dateColor = Colors.blue.shade800; Color dateBgColor = Colors.blue.shade50;
          
          if (task.targetTime != null) {
            final now = DateTime.now(); final today = DateTime(now.year, now.month, now.day);
            final target = DateTime(task.targetTime!.year, task.targetTime!.month, task.targetTime!.day);
            final diffDays = target.difference(today).inDays;

            if (!task.isCompleted && target.isBefore(today)) {
              dateText = target.year == today.year ? '${target.month}/${target.day}' : '${target.year}/${target.month}/${target.day}';
              dateColor = Colors.red; dateBgColor = Colors.red.shade50;
            } else if (diffDays == 0) { dateText = '今天'; dateColor = Colors.orange.shade800; dateBgColor = Colors.orange.shade50; } 
            else if (diffDays == 1) { dateText = '明天'; dateColor = Colors.lightBlue.shade800; dateBgColor = Colors.blue.shade50; } 
            else if (target.year == today.year) { dateText = '${target.month}/${target.day}'; } 
            else { dateText = '${target.year}/${target.month}/${target.day}'; }
          }

          return Padding(
            // 因为习惯会在不同的日期生成多个相同的 ID，为了 ReorderableListView 不崩溃，需要复合 Key
            key: ValueKey("${task.id}_${task.targetTime?.millisecondsSinceEpoch}"), 
            padding: const EdgeInsets.only(left: 2, right: 6, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 25, height: 25,
                  child: Transform.scale(
                    scale: 0.95, 
                    child: Checkbox(
                      visualDensity: VisualDensity.compact, value: task.isCompleted, 
                      activeColor: task.type == TaskType.habit ? Colors.orange : Colors.lightBlue, // 习惯用橙色框
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), onChanged: (val) { if (val != null) _toggleTaskStatus(filter.id!, task, val); }
                    )
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async { 
                      if (task.type == TaskType.habit) {
                        final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => HabitDetailPage(habit: task)));
                        if (result == true) _loadData(showLoading: false);
                      } else {
                        final result = await TaskBottomSheet.show(context, task: task); 
                        if (result == true) _loadData(showLoading: false); 
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              // 习惯加上专有的循环小图标
                              if (task.type == TaskType.habit) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.loop, size: 12, color: Colors.orange)),
                              Expanded(child: Text(task.title, style: TextStyle(fontSize: 12, color: task.isCompleted ? Colors.black38 : Colors.black87, decoration: task.isCompleted ? TextDecoration.lineThrough : null), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          if (task.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2.0), child: Text(task.description, style: TextStyle(fontSize: 10, color: task.isCompleted ? Colors.black26 : Colors.black54, decoration: task.isCompleted ? TextDecoration.lineThrough : null), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Builder(
                            builder: (context) {
                              final visibleTags = task.tags.where((t) => filter.displayTags.any((dt) => dt.id == t.id)).toList();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (visibleTags.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4.0), child: Wrap(spacing: 4, runSpacing: 4, children: visibleTags.map((t) => Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: task.isCompleted ? Colors.grey.shade100 : Colors.blue.shade50, borderRadius: BorderRadius.circular(4)), child: Text(t.name, style: TextStyle(fontSize: 9, color: task.isCompleted ? Colors.grey : Colors.blue.shade800)))).toList())),
                                  if (dateText != null) Padding(padding: const EdgeInsets.only(top: 4.0), child: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: task.isCompleted ? Colors.grey.shade100 : dateBgColor, borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.calendar_today, size: 8, color: task.isCompleted ? Colors.grey : dateColor), const SizedBox(width: 2), Text(dateText!, style: TextStyle(fontSize: 9, color: task.isCompleted ? Colors.grey : dateColor))]))),
                                ],
                              );
                            }
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

    return Container(
      decoration: BoxDecoration(color: isHovered ? Colors.blue.shade100 : Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: isHovered ? Colors.lightBlue : Colors.blue.shade100, width: isHovered ? 2 : 1)),
      child: Column(
        mainAxisSize: isDynamicHeight ? MainAxisSize.min : MainAxisSize.max,
        children: [
          SizedBox(
            height: 24, 
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 4, 0),
              child: Row(
                children: [
                  Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () async { final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => FilterPage(existingFilter: filter))); if (result == true) _loadData(showLoading: false); }, child: Text(filter.name ?? '未命名', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis))), 
                  IconButton(icon: const Icon(Icons.add, color: Colors.black54, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(), splashRadius: 20, onPressed: () async { final result = await TaskBottomSheet.show(context, tags: filter.selectedTags, date: filter.timeFilter == TimeFilter.today ? DateTime.now() : null); if (result == true) _loadData(showLoading: false); }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2), const Divider(height: 1, thickness: 1, indent: 8, endIndent: 8, color: Colors.black12),
          isDynamicHeight ? listWidget : Expanded(child: listWidget),
        ],
      ),
    );
  }
}