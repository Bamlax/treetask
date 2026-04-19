import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/filter_model.dart';
import '../models/task_model.dart';
import '../db/database_helper.dart';
import 'tag_selection_page.dart';

class FilterPage extends StatefulWidget {
  final TaskFilter? existingFilter; 
  const FilterPage({super.key, this.existingFilter});
  
  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  late TimeFilter _timeFilter;
  final TextEditingController _daysBeforeController = TextEditingController(text: '0');
  final TextEditingController _daysAfterController = TextEditingController(text: '0');

  List<Tag> _selectedTags = [];
  final TextEditingController _nameController = TextEditingController();
  
  List<FilterGroup> _allGroups = [];
  List<String> _selectedGroupIds = [];

  bool _showCompleted = true;
  List<Tag> _displayTags = [];

  @override
  void initState() {
    super.initState();
    _timeFilter = widget.existingFilter?.timeFilter ?? TimeFilter.all;
    _nameController.text = widget.existingFilter?.name ?? '';
    if (widget.existingFilter?.customDaysBefore != null) _daysBeforeController.text = widget.existingFilter!.customDaysBefore.toString();
    if (widget.existingFilter?.customDaysAfter != null) _daysAfterController.text = widget.existingFilter!.customDaysAfter.toString();
    _selectedTags = widget.existingFilter != null ? List.from(widget.existingFilter!.selectedTags) : [];
    _selectedGroupIds = widget.existingFilter != null ? List.from(widget.existingFilter!.groupIds) : [];
    
    _showCompleted = widget.existingFilter?.showCompleted ?? true;
    _displayTags = widget.existingFilter != null ? List.from(widget.existingFilter!.displayTags) : [];
    
    DatabaseHelper.instance.getGroups().then((groups) {
      if (mounted) setState(() => _allGroups = groups);
    });
  }

  void _applyAndSave() async {
    if (_nameController.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请给集子命名'))); return; }
    int? beforeDays, afterDays;
    if (_timeFilter == TimeFilter.customDays) {
      beforeDays = int.tryParse(_daysBeforeController.text); afterDays = int.tryParse(_daysAfterController.text);
      if (beforeDays == null || afterDays == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效的天数'))); return; }
    }

    final newFilter = TaskFilter(
      id: widget.existingFilter?.id, sortOrder: widget.existingFilter?.sortOrder ?? 0, 
      name: _nameController.text.trim(), groupIds: _selectedGroupIds, timeFilter: _timeFilter,
      customDaysBefore: beforeDays, customDaysAfter: afterDays, selectedTags: _selectedTags,
      showCompleted: _showCompleted, displayTags: _displayTags,
    );
    await DatabaseHelper.instance.insertSavedFilter(newFilter);
    if (mounted) Navigator.pop(context, true);
  }

  void _deleteFilter() async {
    if (widget.existingFilter?.id != null) {
      await DatabaseHelper.instance.deleteSavedFilter(widget.existingFilter!.id!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.existingFilter == null ? '新建集子' : '编辑集子'), elevation: 0,
        actions: widget.existingFilter != null ? [IconButton(icon: const Icon(Icons.delete), onPressed: _deleteFilter, tooltip: '删除此集子')] : [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: '集子名称 (如: 近期必做)', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            
            const Text('所属分组 (可多选，不选则在默认分组)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _allGroups.map((g) => FilterChip(
                label: Text(g.name), selected: _selectedGroupIds.contains(g.id), selectedColor: Colors.blue.shade100,
                onSelected: (val) { setState(() { if (val) _selectedGroupIds.add(g.id); else _selectedGroupIds.remove(g.id); }); }
              )).toList(),
            ),
            if (_allGroups.isEmpty) const Text('暂无自定义分组，可前往左侧菜单"分组管理"中创建。', style: TextStyle(color: Colors.black38, fontSize: 12)),
            const Divider(height: 40),
            
            const Text('时间筛选', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: TimeFilter.values.map((time) => ChoiceChip(label: Text(time.label), selected: _timeFilter == time, selectedColor: Colors.lightBlue.shade100, onSelected: (s) { if (s) setState(() => _timeFilter = time); })).toList()),
            if (_timeFilter == TimeFilter.customDays) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Text('往前', style: TextStyle(color: Colors.black87)), const SizedBox(width: 8),
                    SizedBox(width: 50, height: 32, child: TextField(controller: _daysBeforeController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], textAlign: TextAlign.center, decoration: const InputDecoration(contentPadding: EdgeInsets.zero, border: OutlineInputBorder(), fillColor: Colors.white, filled: true))),
                    const Text(' 天，至往后 ', style: TextStyle(color: Colors.black87)),
                    SizedBox(width: 50, height: 32, child: TextField(controller: _daysAfterController, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], textAlign: TextAlign.center, decoration: const InputDecoration(contentPadding: EdgeInsets.zero, border: OutlineInputBorder(), fillColor: Colors.white, filled: true))),
                    const Text(' 天', style: TextStyle(color: Colors.black87)),
                  ],
                ),
              )
            ],

            const Divider(height: 40),
            const Text('标签筛选', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ..._selectedTags.map((tag) => Chip(label: Text(tag.name), onDeleted: () => setState(() => _selectedTags.remove(tag)))),
              ActionChip(avatar: const Icon(Icons.add, color: Colors.lightBlue), label: const Text('选择标签'), onPressed: () async {
                final result = await showDialog<List<Tag>>(context: context, builder: (_) => TagSelectionPage(initiallySelectedTags: _selectedTags));
                if (result != null) setState(() => _selectedTags = result);
              }),
            ]),
            
            const Divider(height: 40),
            
            // 展示控制项（移到了最下面）
            const Text('展示控制', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SwitchListTile(
              title: const Text('显示已完成代办', style: TextStyle(fontSize: 14)),
              contentPadding: EdgeInsets.zero,
              activeColor: Colors.lightBlue,
              value: _showCompleted,
              onChanged: (val) => setState(() => _showCompleted = val),
            ),
            const SizedBox(height: 8),
            const Text('代办条目中显示的标签', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ..._displayTags.map((tag) => Chip(label: Text(tag.name), onDeleted: () => setState(() => _displayTags.remove(tag)))),
              ActionChip(avatar: const Icon(Icons.add, color: Colors.lightBlue), label: const Text('指定标签'), onPressed: () async {
                final result = await showDialog<List<Tag>>(context: context, builder: (_) => TagSelectionPage(initiallySelectedTags: _displayTags));
                if (result != null) setState(() => _displayTags = result);
              }),
            ]),

            const SizedBox(height: 60),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue, foregroundColor: Colors.white, elevation: 0), onPressed: _applyAndSave, child: Text(widget.existingFilter == null ? '保存集子' : '保存修改', style: const TextStyle(fontSize: 16)))),
          ],
        ),
      ),
    );
  }
}