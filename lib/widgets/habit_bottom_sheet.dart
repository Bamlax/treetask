import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../db/database_helper.dart';
import '../pages/tag_selection_page.dart';

class HabitBottomSheet extends StatefulWidget {
  final TreeTaskItem? existingHabit; 
  const HabitBottomSheet({super.key, this.existingHabit});

  static Future<bool?> show(BuildContext context, {TreeTaskItem? habit}) {
    return showModalBottomSheet<bool>(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => HabitBottomSheet(existingHabit: habit),
    );
  }

  @override
  State<HabitBottomSheet> createState() => _HabitBottomSheetState();
}

class _HabitBottomSheetState extends State<HabitBottomSheet> {
  late TextEditingController _titleController; 
  late TextEditingController _descController;
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 20)); // 默认21天
  
  List<Tag> _selectedTags = [];
  List<int> _selectedDays = []; 
  final List<String> _weekDays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingHabit?.title ?? '');
    _descController = TextEditingController(text: widget.existingHabit?.description ?? '');
    
    _startDate = widget.existingHabit?.targetTime ?? DateTime.now();
    int duration = widget.existingHabit?.duration ?? 21;
    _endDate = _startDate.add(Duration(days: duration > 0 ? duration - 1 : 0));
    
    _selectedTags = widget.existingHabit != null ? List.from(widget.existingHabit!.tags) : [];
    _selectedDays = widget.existingHabit != null ? List.from(widget.existingHabit!.frequency) : [1, 2, 3, 4, 5, 6, 7];
  }

  @override
  void dispose() { 
    _titleController.dispose(); 
    _descController.dispose(); 
    super.dispose(); 
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context, 
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)), 
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // 如果开始时间晚于结束时间，自动将结束时间往后顺延
        if (_startDate.isAfter(_endDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context, 
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate, // 结束时间不能早于开始时间
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _saveHabit() async {
    if (_titleController.text.isEmpty) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入习惯名称'))); 
      return; 
    }
    if (_selectedDays.isEmpty) { 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请至少选择一天'))); 
      return; 
    }
    
    // 自动计算持续天数
    int duration = _endDate.difference(_startDate).inDays + 1;

    final habitToSave = TreeTaskItem(
      id: widget.existingHabit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(), 
      type: TaskType.habit,
      title: _titleController.text, 
      description: _descController.text, 
      targetTime: _startDate, 
      duration: duration, 
      frequency: _selectedDays, 
      tags: _selectedTags, 
      sortOrder: widget.existingHabit?.sortOrder ?? 0,
    );
    
    await DatabaseHelper.instance.insertTask(habitToSave);
    if (mounted) {
      Navigator.pop(context, true); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('坚持习惯', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
              if (widget.existingHabit != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20), 
                  color: Colors.red, 
                  padding: EdgeInsets.zero, 
                  constraints: const BoxConstraints(), 
                  splashRadius: 20, 
                  onPressed: () async {
                    await DatabaseHelper.instance.deleteTask(widget.existingHabit!.id);
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
                  }
                ),
            ],
          ),
          
          TextField(
            controller: _titleController, 
            autofocus: widget.existingHabit == null, 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87), 
            decoration: const InputDecoration(hintText: '想养成什么习惯？', hintStyle: TextStyle(color: Colors.black26), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8))
          ),
          
          TextField(
            controller: _descController, 
            maxLines: 2, 
            minLines: 1, 
            style: const TextStyle(fontSize: 14, color: Colors.black87), 
            decoration: const InputDecoration(hintText: '添加备注...', hintStyle: TextStyle(color: Colors.black26), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.only(bottom: 0))
          ),
          
          const SizedBox(height: 12),
          
          // 开始时间和结束时间选择
          Row(
            children: [
              InkWell(
                onTap: _pickStartDate, 
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      const Icon(Icons.flag, size: 14, color: Colors.lightBlue), 
                      const SizedBox(width: 4),
                      Text('开始: ${_startDate.year}-${_startDate.month}-${_startDate.day}', style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('至', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
              InkWell(
                onTap: _pickEndDate, 
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      const Icon(Icons.outlined_flag, size: 14, color: Colors.lightBlue), 
                      const SizedBox(width: 4),
                      Text('结束: ${_endDate.year}-${_endDate.month}-${_endDate.day}', style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          const Text('打卡频率', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: List.generate(7, (index) {
              int day = index + 1;
              bool isSelected = _selectedDays.contains(day);
              return ChoiceChip(
                label: Text(_weekDays[index]), 
                selected: isSelected, 
                selectedColor: Colors.lightBlue.shade100, 
                backgroundColor: Colors.grey.shade100, 
                side: BorderSide.none, 
                visualDensity: VisualDensity.compact, 
                onSelected: (val) { 
                  setState(() { 
                    if (val) {
                      _selectedDays.add(day);
                    } else {
                      _selectedDays.remove(day);
                    }
                  }); 
                }
              );
            }),
          ),

          const Divider(height: 16, color: Colors.black12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6, runSpacing: 6,
                  children: [
                    ..._selectedTags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)), 
                      child: Row(
                        mainAxisSize: MainAxisSize.min, 
                        children: [
                          Text(tag.name, style: TextStyle(fontSize: 11, color: Colors.blue.shade800)), 
                          const SizedBox(width: 4), 
                          GestureDetector(
                            onTap: () => setState(() => _selectedTags.remove(tag)), 
                            child: Icon(Icons.close, size: 12, color: Colors.blue.shade800)
                          )
                        ]
                      )
                    )),
                    GestureDetector(
                      onTap: () async { 
                        final result = await showDialog<List<Tag>>(
                          context: context, 
                          builder: (_) => TagSelectionPage(initiallySelectedTags: _selectedTags)
                        ); 
                        if (result != null) {
                          setState(() => _selectedTags = result); 
                        }
                      }, 
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)), 
                        child: const Row(
                          mainAxisSize: MainAxisSize.min, 
                          children: [
                            Icon(Icons.local_offer_outlined, size: 12, color: Colors.black54), 
                            SizedBox(width: 4), 
                            Text('标签', style: TextStyle(fontSize: 11, color: Colors.black54))
                          ]
                        )
                      )
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, 4), 
                child: IconButton(
                  icon: const Icon(Icons.check), 
                  color: Colors.white, 
                  style: IconButton.styleFrom(backgroundColor: Colors.lightBlue, padding: const EdgeInsets.all(12)), 
                  onPressed: _saveHabit
                )
              )
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}