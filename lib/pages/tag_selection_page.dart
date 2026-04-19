import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../db/database_helper.dart';

class TagNode {
  final Tag tag;
  final List<TagNode> children;
  TagNode(this.tag, this.children);
}

class TagSelectionPage extends StatefulWidget {
  final List<Tag> initiallySelectedTags;
  const TagSelectionPage({super.key, this.initiallySelectedTags = const []});

  @override
  State<TagSelectionPage> createState() => _TagSelectionPageState();
}

class _TagSelectionPageState extends State<TagSelectionPage> {
  late Set<String> _selectedTagIds;
  List<Tag> _allTags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedTagIds = widget.initiallySelectedTags.map((t) => t.id).toSet();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await DatabaseHelper.instance.getAllTags();
    setState(() {
      _allTags = tags;
      _selectedTagIds.removeWhere((id) => !_allTags.any((t) => t.id == id));
      _isLoading = false;
    });
  }

  List<TagNode> _buildTree(String? parentId) {
    return _allTags.where((t) => t.parentId == parentId).map((t) {
      return TagNode(t, _buildTree(t.id));
    }).toList();
  }

  // 核心更改：现在的选择是完全独立的，点谁选谁，不波及父子！
  void _toggleTag(TagNode node, bool? isSelected) {
    setState(() {
      if (isSelected == true) {
        _selectedTagIds.add(node.tag.id);
      } else {
        _selectedTagIds.remove(node.tag.id);
      }
    });
  }

  // 弹窗中快速新建标签
  void _showAddTagDialog([Tag? parentTag]) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(parentTag == null ? '新建顶级标签' : '在【${parentTag.name}】下新建', style: const TextStyle(fontSize: 16)),
        content: TextField(controller: nameController, decoration: const InputDecoration(hintText: '输入标签名称'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue, foregroundColor: Colors.white, elevation: 0),
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final newTag = Tag(id: DateTime.now().millisecondsSinceEpoch.toString(), name: nameController.text, parentId: parentTag?.id);
                await DatabaseHelper.instance.insertTag(newTag);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadTags();
              }
            },
            child: const Text('保存'),
          ),
        ],
      )
    );
  }

  Widget _buildNode(TagNode node, int depth) {
    final isSelected = _selectedTagIds.contains(node.tag.id);
    
    // 核心更改：把删除按钮去掉了，改成了新建子标签的“+”号
    final addSubTagBtn = IconButton(
      icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.lightBlue),
      tooltip: '新建子标签',
      padding: EdgeInsets.zero, constraints: const BoxConstraints(), splashRadius: 16,
      onPressed: () => _showAddTagDialog(node.tag),
    );

    if (node.children.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(left: depth * 20.0, right: 8.0),
        child: Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                visualDensity: VisualDensity.compact,
                contentPadding: EdgeInsets.zero,
                title: Text(node.tag.name, style: const TextStyle(fontSize: 14)),
                value: isSelected,
                activeColor: Colors.lightBlue,
                onChanged: (val) => _toggleTag(node, val),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            addSubTagBtn,
          ],
        ),
      );
    }

    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: EdgeInsets.only(left: depth * 20.0, right: 8.0),
      title: Row(
        children: [
          Expanded(child: Text(node.tag.name, style: const TextStyle(fontSize: 14))),
          addSubTagBtn,
        ],
      ),
      leading: Checkbox(
        visualDensity: VisualDensity.compact,
        value: isSelected,
        activeColor: Colors.lightBlue,
        onChanged: (val) => _toggleTag(node, val),
      ),
      children: node.children.map((c) => _buildNode(c, depth + 1)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const AlertDialog(content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())));

    final tree = _buildTree(null);

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('选择标签', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.lightBlue), tooltip: '新建顶级标签', onPressed: () => _showAddTagDialog(), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
        ],
      ),
      contentPadding: const EdgeInsets.only(top: 8, bottom: 8),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.5,
        child: ListView.builder(itemCount: tree.length, itemBuilder: (context, index) => _buildNode(tree[index], 0)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue, foregroundColor: Colors.white, elevation: 0),
          onPressed: () {
            final selectedTags = _allTags.where((t) => _selectedTagIds.contains(t.id)).toList();
            Navigator.pop(context, selectedTags);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}