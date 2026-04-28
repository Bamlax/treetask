import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../db/database_helper.dart';
import '../widgets/habit_bottom_sheet.dart';

class HabitDetailPage extends StatefulWidget {
  final TreeTaskItem habit;
  const HabitDetailPage({super.key, required this.habit});

  @override
  State<HabitDetailPage> createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends State<HabitDetailPage> {
  late TreeTaskItem _habit;
  List<String> _logs = [];
  
  // 当前查阅的日历月份（默认当前月）
  DateTime _selectedMonth = DateTime.now();
  // 真实的“今天”，用于高亮当日
  final DateTime _actualNow = DateTime.now();

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await DatabaseHelper.instance.getHabitLogs(_habit.id);
    if (mounted) {
      setState(() => _logs = logs);
    }
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    DateTime firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    int daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    int firstWeekday = firstDayOfMonth.weekday;

    // 计算习惯生命周期
    DateTime habitStart = _habit.targetTime ?? _actualNow;
    habitStart = DateTime(habitStart.year, habitStart.month, habitStart.day);
    int duration = _habit.duration ?? 21;
    DateTime habitEnd = habitStart.add(Duration(days: duration > 0 ? duration - 1 : 0));

    // 计算理论上应该打卡的总天数
    int requiredDays = 0;
    for (int i = 0; i < duration; i++) {
      if (_habit.frequency.contains(habitStart.add(Duration(days: i)).weekday)) {
        requiredDays++;
      }
    }
    
    int checkedDays = _logs.length;
    double rate = requiredDays > 0 ? (checkedDays / requiredDays) : 0.0;
    String rateStr = (rate * 100).toStringAsFixed(1) + '%';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('习惯详情'), elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit), tooltip: '编辑习惯',
            onPressed: () async {
              final result = await HabitBottomSheet.show(context, habit: _habit);
              if (result == true) {
                Navigator.pop(context, true); 
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.loop, color: Colors.lightBlue, size: 28),
                const SizedBox(width: 8),
                Expanded(child: Text(_habit.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87))),
              ],
            ),
            const SizedBox(height: 8),
            if (_habit.description.isNotEmpty)
              Text(_habit.description, style: const TextStyle(color: Colors.black54, fontSize: 15)),
            
            const SizedBox(height: 24),
            
            // 核心统计卡片
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('开始日期', '${habitStart.month}/${habitStart.day}'),
                  _buildStatItem('目标坚持', '$duration 天'),
                  _buildStatItem('已打卡', '$checkedDays 天'),
                  _buildStatItem('打卡率', rateStr, color: Colors.blue.shade800),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            Wrap(
              spacing: 6,
              children: _habit.tags.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text(t.name, style: TextStyle(color: Colors.blue.shade800, fontSize: 12)),
              )).toList(),
            ),
            const SizedBox(height: 32),
            
            // 日历头部：支持左右切换月份
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.lightBlue),
                  onPressed: _prevMonth,
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                Text(
                  '${_selectedMonth.year}年 ${_selectedMonth.month}月', 
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.lightBlue),
                  onPressed: _nextMonth,
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['一', '二', '三', '四', '五', '六', '日'].map((w) => Text(w, style: const TextStyle(color: Colors.grey, fontSize: 13))).toList(),
            ),
            const SizedBox(height: 8),
            
            GridView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
              itemCount: daysInMonth + firstWeekday - 1,
              itemBuilder: (context, index) {
                if (index < firstWeekday - 1) {
                  return const SizedBox.shrink();
                }
                
                int day = index - firstWeekday + 2;
                DateTime currentCellDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                String dayStr = "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2,'0')}-${day.toString().padLeft(2,'0')}";
                
                bool isCompleted = _logs.contains(dayStr);
                // 判断是否是真实的“今天”
                bool isToday = day == _actualNow.day && _selectedMonth.year == _actualNow.year && _selectedMonth.month == _actualNow.month;
                
                bool isValidLifeCycle = !currentCellDate.isBefore(habitStart) && !currentCellDate.isAfter(habitEnd);
                bool isFreqMatch = _habit.frequency.contains(currentCellDate.weekday);
                bool isActiveDay = isValidLifeCycle && isFreqMatch;

                return Container(
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.lightBlue : (isActiveDay ? Colors.grey.shade100 : Colors.transparent),
                    shape: BoxShape.circle,
                    border: isToday ? Border.all(color: Colors.blue.shade800, width: 2) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    day.toString(), 
                    style: TextStyle(
                      color: isCompleted ? Colors.white : (isActiveDay ? Colors.black87 : Colors.black26), 
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal
                    )
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {Color color = Colors.black87}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }
}