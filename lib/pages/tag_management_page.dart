import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../db/database_helper.dart';

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
          title: Text(parentTag == null ? '新建顶级标签' : '在【${parentTag.name}】下新建', style: const TextStyle(fontSize: 18)),
          content: TextField(controller: nameController, decoration: const InputDecoration(hintText: '输入标签名称'), autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue, foregroundColor: Colors.white, elevation: 0),
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final newTag = Tag(id: DateTime.now().millisecondsSinceEpoch.toString(), name: nameController.text, parentId: parentTag?.id);
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

  // 移动标签 (修改父级)
  void _showMoveTagDialog(Tag tag) {
    String? selectedParentId = tag.parentId;
    
    // 判断是否是它的子孙，防止出现循环嵌套
    bool isDescendant(String potentialParentId, String nodeId) {
      if (potentialParentId == nodeId) return true;
      final p = _allTags.where((t) => t.id == potentialParentId).firstOrNull;
      if (p?.parentId == null) return false;
      return isDescendant(p!.parentId!, nodeId);
    }

    // 过滤出合法的父级 (不能是自己，也不能是自己的子孙)
    final validParents = _allTags.where((t) => t.id != tag.id && !isDescendant(t.id, tag.id)).toList();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('移动标签【${tag.name}】', style: const TextStyle(fontSize: 18)),
              content: DropdownButtonFormField<String?>(
                decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                value: selectedParentId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('无 (设为顶级标签)', style: TextStyle(color: Colors.grey))),
                  ...validParents.map((t) => DropdownMenuItem(value: t.id, child: Text(t.name))),
                ],
                onChanged: (val) => setModalState(() => selectedParentId = val),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue, foregroundColor: Colors.white, elevation: 0),
                  onPressed: () async {
                    final updatedTag = Tag(id: tag.id, name: tag.name, parentId: selectedParentId);
                    await DatabaseHelper.instance.insertTag(updatedTag); 
                    if (context.mounted) Navigator.pop(context);
                    _loadTags();
                  },
                  child: const Text('确认移动'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // 删除二次确认
  void _showDeleteConfirm(Tag tag) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认删除', style: TextStyle(fontSize: 18, color: Colors.red)),
          content: Text('确认要删除标签【${tag.name}】吗？\n删除后，其包含的所有子标签也将被级联删除！'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
              onPressed: () async {
                await DatabaseHelper.instance.deleteTag(tag.id);
                if (context.mounted) Navigator.pop(context);
                _loadTags();
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNode(TagNode node, int depth) {
    // 核心更改：把下拉菜单换成了紧凑的 3 个直接操作图标
    Widget actionButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.lightBlue),
          tooltip: '添加子标签',
          iconSize: 20,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          constraints: const BoxConstraints(),
          splashRadius: 18,
          onPressed: () => _showAddTagDialog(node.tag),
        ),
        IconButton(
          icon: const Icon(Icons.drive_file_move_outline, color: Colors.orange),
          tooltip: '修改层级',
          iconSize: 20,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          constraints: const BoxConstraints(),
          splashRadius: 18,
          onPressed: () => _showMoveTagDialog(node.tag),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: '删除标签',
          iconSize: 20,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          constraints: const BoxConstraints(),
          splashRadius: 18,
          onPressed: () => _showDeleteConfirm(node.tag),
        ),
      ],
    );

    if (node.children.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.only(left: 16.0 + depth * 24.0, right: 8.0),
        title: Text(node.tag.name),
        trailing: actionButtons, // 替换这里
      );
    }

    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: EdgeInsets.only(left: 16.0 + depth * 24.0, right: 8.0),
      title: Text(node.tag.name, style: TextStyle(fontWeight: depth == 0 ? FontWeight.bold : FontWeight.normal)),
      trailing: actionButtons, // 替换这里
      children: node.children.map((c) => _buildNode(c, depth + 1)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final tree = _buildTree(null);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('标签管理'), elevation: 0),
      body: ListView.builder(
        itemCount: tree.length,
        itemBuilder: (context, index) {
          return _buildNode(tree[index], 0);
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.lightBlue,
        elevation: 2,
        onPressed: () => _showAddTagDialog(), 
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}