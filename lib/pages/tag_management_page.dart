import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../db/database_helper.dart';

// 辅助类：用于构建多级标签树
class TagNode {
  final Tag tag;
  final List<TagNode> children;
  TagNode(this.tag, this.children);
}

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  List<Tag> _allTags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await DatabaseHelper.instance.getAllTags();
    setState(() {
      _allTags = tags;
      _isLoading = false;
    });
  }

  // 递归构建多级树形数据
  List<TagNode> _buildTree(String? parentId) {
    return _allTags.where((t) => t.parentId == parentId).map((t) {
      return TagNode(t, _buildTree(t.id));
    }).toList();
  }

  void _showAddTagDialog([Tag? parentTag]) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(parentTag == null ? '新建顶级标签' : '在【${parentTag.name}】下新建'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: '输入标签名称'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue, foregroundColor: Colors.white),
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final newTag = Tag(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    parentId: parentTag?.id,
                  );
                  await DatabaseHelper.instance.insertTag(newTag);
                  if (context.mounted) Navigator.pop(context);
                  _loadTags();
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTag(String id) async {
    await DatabaseHelper.instance.deleteTag(id);
    _loadTags();
  }

  // 递归渲染多级 UI 组件
  Widget _buildNode(TagNode node, int depth) {
    // 操作按钮区域
    Widget actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.add, color: Colors.lightBlue, size: 20),
          onPressed: () => _showAddTagDialog(node.tag),
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          onPressed: () => _deleteTag(node.tag.id),
        ),
      ],
    );

    if (node.children.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: 16.0 + depth * 24.0, right: 8.0),
        title: Text(node.tag.name),
        trailing: actions,
      );
    }

    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: EdgeInsets.only(left: 16.0 + depth * 24.0, right: 8.0),
      title: Text(node.tag.name, style: TextStyle(fontWeight: depth == 0 ? FontWeight.bold : FontWeight.normal)),
      trailing: actions, // 为了保留操作按钮，这里覆盖了默认的折叠箭头（点击整行依然可以折叠）
      children: node.children.map((c) => _buildNode(c, depth + 1)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tree = _buildTree(null);

    return Scaffold(
      appBar: AppBar(title: const Text('标签管理')),
      body: ListView.builder(
        itemCount: tree.length,
        itemBuilder: (context, index) {
          return _buildNode(tree[index], 0);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTagDialog(), // 添加顶级标签
        child: const Icon(Icons.add),
      ),
    );
  }
}