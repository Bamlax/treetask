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
  customDays('自定义天数段');
  
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
  final List<String> groupIds; 
  final int sortOrder;
  final TimeFilter timeFilter;
  final int? customDaysBefore;
  final int? customDaysAfter;
  final List<Tag> selectedTags;
  
  final bool showCompleted;
  final List<Tag> displayTags;

  TaskFilter({
    this.id,
    this.name,
    this.groupIds = const [], 
    this.sortOrder = 0,
    this.timeFilter = TimeFilter.all,
    this.customDaysBefore,
    this.customDaysAfter,
    this.selectedTags = const [],
    this.showCompleted = true, 
    this.displayTags = const [], 
  });
}