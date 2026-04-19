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
    version: 'v0.2.0',
    date: '2026-04-19',
    changes: [
      '新增点击集子标题可进入集子编辑界面',
      '新增集子编辑界面对标签的增删',
      '新增标签管理界面对标签层级的修改',
      '允许只选择子标签的选择',
      '集子界面允许新建子标签',
      '新增分组栏可拖动排序',
      '优化集子移动逻辑',
      '新增长按代办可排序功能',
      '优化代办完成按键ui',
      '新增分组管理功能',
      '优化日期选择界面',
      '新增集子界面对代办的描述',
      '支持自定义集子长度',
    ],
  ),
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