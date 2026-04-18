import 'task_model.dart';

enum TimeFilter {
  all('全部'),
  overdue('已过期'),
  today('今天'),
  tomorrow('明天'),
  week('本周'),
  nextWeek('下周'),
  month('本月'),
  nextMonth('下月'),
  customDays('自定义天数段'); // 新增：指定前后几天

  final String label;
  const TimeFilter(this.label);
}

class FilterGroup {
  final String id;
  final String name;
  final int sortOrder;
  FilterGroup({required this.id, required this.name, this.sortOrder = 0});
}

class TaskFilter {
  final String? id;
  final String? name;
  final String? groupId;
  final int sortOrder;
  final TimeFilter timeFilter;
  final int? customDaysBefore; // 往前几天
  final int? customDaysAfter;  // 往后几天
  final List<Tag> selectedTags;

  TaskFilter({
    this.id,
    this.name,
    this.groupId,
    this.sortOrder = 0,
    this.timeFilter = TimeFilter.all,
    this.customDaysBefore,
    this.customDaysAfter,
    this.selectedTags = const [],
  });
}