class Tag {
  final String id;
  final String name;
  final String? parentId;
  final int sortOrder;
  Tag({required this.id, required this.name, this.parentId, this.sortOrder = 0});
}

enum TaskType { normal, habit }

class TreeTaskItem {
  final String id;
  final TaskType type; 
  final String title;
  final String description;
  final DateTime? targetTime; // 普通代办的目标时间 / 习惯的开始时间
  final int? duration;        // 新增：习惯的持续天数
  final List<Tag> tags; 
  final bool isCompleted;
  final int sortOrder;
  final List<int> frequency; 

  TreeTaskItem({
    required this.id,
    this.type = TaskType.normal,
    required this.title,
    required this.description,
    this.targetTime,
    this.duration,
    this.tags = const [],
    this.isCompleted = false,
    this.sortOrder = 0,
    this.frequency = const [],
  });
}