import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../db/database_helper.dart';
import '../pages/tag_selection_page.dart';

class TaskBottomSheet extends StatefulWidget {
  final TreeTaskItem? existingTask; 
  final List<Tag>? initialTags;     
  final DateTime? initialDate;      

  const TaskBottomSheet({super.key, this.existingTask, this.initialTags, this.initialDate});

  static Future<bool?> show(BuildContext context, {TreeTaskItem? task, List<Tag>? tags, DateTime? date}) {
    return showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => TaskBottomSheet(existingTask: task, initialTags: tags, initialDate: date),
    );
  }

  @override
  State<TaskBottomSheet> createState() => _TaskBottomSheetState();
}

class _TaskBottomSheetState extends State<TaskBottomSheet> {
  late TextEditingController _titleController; late TextEditingController _descController;
  DateTime? _selectedDate; List<Tag> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingTask?.title ?? '');
    _descController = TextEditingController(text: widget.existingTask?.description ?? '');
    _selectedDate = widget.existingTask?.targetTime ?? widget.initialDate;
    _selectedTags = widget.existingTask != null ? List.from(widget.existingTask!.tags) : (widget.initialTags != null ? List.from(widget.initialTags!) : []);
  }

  @override
  void dispose() { _titleController.dispose(); _descController.dispose(); super.dispose(); }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context, initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveTask() async {
    if (_titleController.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入待办标题'))); return; }
    final taskToSave = TreeTaskItem(
      id: widget.existingTask?.id ?? DateTime.now().millisecondsSinceEpoch.toString(), 
      title: _titleController.text, description: _descController.text, targetTime: _selectedDate,
      tags: _selectedTags, isCompleted: widget.existingTask?.isCompleted ?? false, sortOrder: widget.existingTask?.sortOrder ?? 0,
    );
    await DatabaseHelper.instance.insertTask(taskToSave);
    if (mounted) Navigator.pop(context, true); 
  }

  Future<void> _deleteTask() async {
    if (widget.existingTask != null) { await DatabaseHelper.instance.deleteTask(widget.existingTask!.id); if (mounted) Navigator.pop(context, true); }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InkWell(
                onTap: _pickDate, borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: _selectedDate == null ? Colors.grey : Colors.lightBlue), const SizedBox(width: 6),
                      Text(_selectedDate == null ? '设置日期' : '${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day}', style: TextStyle(fontSize: 13, color: _selectedDate == null ? Colors.grey : Colors.lightBlue, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
              if (widget.existingTask != null)
                IconButton(icon: const Icon(Icons.delete_outline, size: 20), color: Colors.red, padding: EdgeInsets.zero, constraints: const BoxConstraints(), splashRadius: 20, onPressed: _deleteTask),
            ],
          ),
          TextField(controller: _titleController, autofocus: widget.existingTask == null, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87), decoration: const InputDecoration(hintText: '准备做什么？', hintStyle: TextStyle(color: Colors.black26), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8))),
          TextField(controller: _descController, maxLines: 2, minLines: 1, style: const TextStyle(fontSize: 14, color: Colors.black87), decoration: const InputDecoration(hintText: '添加描述...', hintStyle: TextStyle(color: Colors.black26), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.only(bottom: 0))),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 2), 
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6, runSpacing: 6,
                  children: [
                    ..._selectedTags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [Text(tag.name, style: TextStyle(fontSize: 11, color: Colors.blue.shade800)), const SizedBox(width: 4), GestureDetector(onTap: () => setState(() => _selectedTags.remove(tag)), child: Icon(Icons.close, size: 12, color: Colors.blue.shade800))]),
                    )),
                    GestureDetector(
                      onTap: () async {
                        final result = await showDialog<List<Tag>>(context: context, builder: (_) => TagSelectionPage(initiallySelectedTags: _selectedTags));
                        if (result != null) setState(() => _selectedTags = result);
                      },
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.local_offer_outlined, size: 12, color: Colors.black54), SizedBox(width: 4), Text('标签', style: TextStyle(fontSize: 11, color: Colors.black54))])),
                    ),
                  ],
                ),
              ),
              // 发送按钮再次下移2px（Offset(0,4)）
              Transform.translate(
                offset: const Offset(0, 4),
                child: IconButton(icon: const Icon(Icons.send), color: Colors.white, style: IconButton.styleFrom(backgroundColor: Colors.lightBlue, padding: const EdgeInsets.all(12)), onPressed: _saveTask),
              )
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}