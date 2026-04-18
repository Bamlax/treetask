import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/filter_model.dart';
import '../models/task_model.dart';
import '../db/database_helper.dart';
import 'tag_selection_page.dart';

class FilterPage extends StatefulWidget {
  const FilterPage({super.key});
  @override
  State<FilterPage> createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  TimeFilter _timeFilter = TimeFilter.all;
  
  // 自定义天数控制
  final TextEditingController _daysBeforeController = TextEditingController(text: '0');
  final TextEditingController _daysAfterController = TextEditingController(text: '0');

  List<Tag> _selectedTags = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _groupController = TextEditingController(); 

  void _applyAndSave() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请给集子命名')));
      return;
    }

    int? beforeDays;
    int? afterDays;

    if (_timeFilter == TimeFilter.customDays) {
      beforeDays = int.tryParse(_daysBeforeController.text);
      afterDays = int.tryParse(_daysAfterController.text);
      if (beforeDays == null || afterDays == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效的天数')));
        return;
      }
    }

    String? groupId;
    if (_groupController.text.isNotEmpty) {
      groupId = await DatabaseHelper.instance.getOrCreateGroupId(_groupController.text.trim());
    }

    final newFilter = TaskFilter(
      name: _nameController.text.trim(),
      groupId: groupId,
      timeFilter: _timeFilter,
      customDaysBefore: beforeDays,
      customDaysAfter: afterDays,
      selectedTags: _selectedTags,
    );

    await DatabaseHelper.instance.insertSavedFilter(newFilter);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('新建集子'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: '集子名称 (如: 近期必做)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _groupController, decoration: const InputDecoration(labelText: '所属分组 (如: 工作。不填则在默认分组)', border: OutlineInputBorder())),
            const Divider(height: 40),
            
            const Text('时间筛选', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8, 
              children: TimeFilter.values.map((time) => ChoiceChip(
                label: Text(time.label), 
                selected: _timeFilter == time,
                selectedColor: Colors.lightBlue.shade100, 
                onSelected: (s) { if (s) setState(() => _timeFilter = time); }
              )).toList()
            ),
            
            // 当选中“自定义天数段”时，展示输入框
            if (_timeFilter == TimeFilter.customDays) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Text('往前', style: TextStyle(color: Colors.black87)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50, height: 32,
                      child: TextField(
                        controller: _daysBeforeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.zero, border: OutlineInputBorder(), fillColor: Colors.white, filled: true),
                      ),
                    ),
                    const Text(' 天，至往后 ', style: TextStyle(color: Colors.black87)),
                    SizedBox(
                      width: 50, height: 32,
                      child: TextField(
                        controller: _daysAfterController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.zero, border: OutlineInputBorder(), fillColor: Colors.white, filled: true),
                      ),
                    ),
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
                final result = await showDialog<List<Tag>>(
                  context: context, 
                  builder: (_) => TagSelectionPage(initiallySelectedTags: _selectedTags)
                );
                if (result != null) setState(() => _selectedTags = result);
              }),
            ]),
            const SizedBox(height: 60),
            
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue, foregroundColor: Colors.white, elevation: 0),
                onPressed: _applyAndSave,
                child: const Text('保存集子', style: TextStyle(fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}