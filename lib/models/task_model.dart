class Tag {
  final String id;
  final String name;
  final String? parentId;
  Tag({required this.id, required this.name, this.parentId});
}

class TreeTaskItem {
  final String id;
  final String title;
  final String description;
  final DateTime? targetTime; // 允许为空
  final List<Tag> tags; // 允许为空列表
  final bool isCompleted;

  TreeTaskItem({
    required this.id,
    required this.title,
    required this.description,
    this.targetTime,
    this.tags = const [],
    this.isCompleted = false,
  });
}