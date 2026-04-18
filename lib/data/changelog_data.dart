class ChangelogEntry {
  final String version;
  final String date;
  final List<String> changes;

  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });
}

const List<ChangelogEntry> changelogData = [
  ChangelogEntry(
    version: 'v0.1.0',
    date: '2026-04-18',
    changes: [
      '首个正式版本发布',
      '引入全新的「集子」看板模式',
      '支持多级标签管理与筛选',
      '支持自定义动态时间段（往前/往后推算）',
      '支持看板集子的长按拖拽排序与悬停动画',
      '极致紧凑的底部弹出式任务编辑器',
    ],
  ),
];