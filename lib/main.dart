import 'package:flutter/material.dart';
import 'pages/tag_management_page.dart';
import 'pages/filter_page.dart';
import 'widgets/task_bottom_sheet.dart'; // 引入全新的底部面板
import 'models/filter_model.dart';
import 'models/task_model.dart';
import 'db/database_helper.dart';
import 'pages/settings_page.dart';

void main() => runApp(const TreeTaskApp());

class TreeTaskApp extends StatelessWidget {
  const TreeTaskApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TreeTask',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final groups = await DatabaseHelper.instance.getGroups();
      final filters = await DatabaseHelper.instance.getSavedFilters(_selectedGroupId);
      final Map<String, List<TreeTaskItem>> newTasksMap = {};
      for (var filter in filters) {
        if (filter.id != null) newTasksMap[filter.id!] = await DatabaseHelper.instance.getFilteredTasks(filter);
      }
      if (mounted) {
        setState(() {
          _groups = groups; _filters = filters; _tasksMap = newTasksMap;
        });
      }
    } finally {
      if (mounted && showLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleTaskStatus(String filterId, TreeTaskItem task, bool val) async {
    setState(() {
      final taskIndex = _tasksMap[filterId]?.indexWhere((t) => t.id == task.id) ?? -1;
      if (taskIndex != -1) {
        _tasksMap[filterId]![taskIndex] = TreeTaskItem(
          id: task.id, title: task.title, description: task.description, 
          targetTime: task.targetTime, tags: task.tags, isCompleted: val
        );
      }
    });
    await DatabaseHelper.instance.updateTaskCompletion(task.id, val);
    _loadData(showLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TreeTask'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建集子',
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const FilterPage()));
              if (result == true) _loadData();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.lightBlue), 
            child: SizedBox(width: double.infinity, child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [Icon(Icons.account_tree, color: Colors.white, size: 48), SizedBox(height: 12), Text('TreeTask', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))]))
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.label_outline, color: Colors.lightBlue), 
                  title: const Text('标签管理'), 
                  onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const TagManagementPage())); }
                ),
              ],
            ),
          ),
          // 底部的设置入口
          const Divider(height: 1, color: Colors.black12),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Colors.black54), 
            title: const Text('设置', style: TextStyle(color: Colors.black87)), 
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())); }
          ),
          const SizedBox(height: 16), // 底部留白
        ]),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 50,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(label: const Text('默认'), selected: _selectedGroupId == null, selectedColor: Colors.lightBlue.shade100, side: BorderSide.none, onSelected: (s) { if (s) { setState(() => _selectedGroupId = null); _loadData(); } }),
                ),
                ..._groups.map((g) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(label: Text(g.name), selected: _selectedGroupId == g.id, selectedColor: Colors.lightBlue.shade100, side: BorderSide.none, onSelected: (s) { if (s) { setState(() => _selectedGroupId = g.id); _loadData(); } }),
                )),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator()) :
              _filters.isEmpty ? const Center(child: Text('当前分组没有集子\n点击右上角 + 号新建', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))) :
              Padding(
                // 看板整体边距调整
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
                child: GridView.builder(
                  // 间距缩小 2px (从12变为10)
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.8),
                  itemCount: _filters.length,
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final tasks = _tasksMap[filter.id!] ?? [];

                    return DragTarget<TaskFilter>(
                      onWillAcceptWithDetails: (details) => details.data.id != filter.id,
                      onAcceptWithDetails: (details) async {
                        await DatabaseHelper.instance.swapFilterOrder(details.data, filter);
                        _loadData(showLoading: false);
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isHovered = candidateData.isNotEmpty;
                        return LongPressDraggable<TaskFilter>(
                          delay: const Duration(milliseconds: 150),
                          data: filter,
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width / 2 - 15,
                              height: (MediaQuery.of(context).size.width / 2 - 15) / 0.8,
                              child: Opacity(opacity: 0.85, child: _buildBlockCard(filter, tasks, isHovered: true)),
                            ),
                          ),
                          childWhenDragging: Opacity(opacity: 0.2, child: _buildBlockCard(filter, tasks)),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            transform: isHovered ? Matrix4.translationValues(0, -4, 0) : Matrix4.identity(),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isHovered ? [BoxShadow(color: Colors.lightBlue.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)] : [],
                            ),
                            child: _buildBlockCard(filter, tasks, isHovered: isHovered),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.lightBlue, elevation: 2,
        onPressed: () async {
          // 全局新建面板
          final result = await TaskBottomSheet.show(context);
          if (result == true) _loadData(showLoading: false);
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

    Widget _buildBlockCard(TaskFilter filter, List<TreeTaskItem> tasks, {bool isHovered = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isHovered ? Colors.blue.shade100 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isHovered ? Colors.lightBlue : Colors.blue.shade100, width: isHovered ? 2 : 1),
      ),
      child: Column(
        children: [
          // 【核心修复】：用 SizedBox(height: 24) 严格限制标题行高度，变相把下面的分割线整体上拉 6px
          SizedBox(
            height: 24, 
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
              child: Row(
                children: [
                  const Icon(Icons.drag_indicator, color: Colors.black26, size: 14), 
                  const SizedBox(width: 4),
                  Expanded(child: Text(filter.name ?? '未命名', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)), 
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.black54, size: 16), 
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(), splashRadius: 20,
                    onPressed: () async {
                      final result = await TaskBottomSheet.show(
                        context, 
                        tags: filter.selectedTags, 
                        date: filter.timeFilter == TimeFilter.today ? DateTime.now() : null
                      );
                      if (result == true) _loadData(showLoading: false);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2), // 微调分割线上方的视觉缓冲
          
          // 恢复正常的分割线
          const Divider(height: 1, thickness: 1, indent: 8, endIndent: 8, color: Colors.black12),
          
          Expanded(
            child: tasks.isEmpty ? const Center(child: Text('暂无代办', style: TextStyle(color: Colors.black38, fontSize: 11))) :
              ListView.builder(
                // 【核心修复】：把代办列表的顶部 Padding 加回来，保持舒适间距
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                itemCount: tasks.length,
                itemBuilder: (context, taskIndex) {
                  final task = tasks[taskIndex];
                  return Padding(
                    padding: const EdgeInsets.only(left: 2, right: 6, bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 26, height: 26,
                          child: Checkbox(
                            visualDensity: VisualDensity.compact,
                            value: task.isCompleted, activeColor: Colors.lightBlue,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (val) {
                              if (val != null) _toggleTaskStatus(filter.id!, task, val);
                            },
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () async {
                              final result = await TaskBottomSheet.show(context, task: task);
                              if (result == true) _loadData(showLoading: false);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                task.title, 
                                style: TextStyle(fontSize: 12, color: task.isCompleted ? Colors.black38 : Colors.black87, decoration: task.isCompleted ? TextDecoration.lineThrough : null), 
                                maxLines: 1, overflow: TextOverflow.ellipsis
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ),
        ],
      ),
    );
  }
}