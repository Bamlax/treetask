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
      _isLoading = false;
    });
  }

  List<TagNode> _buildTree(String? parentId) {
    return _allTags.where((t) => t.parentId == parentId).map((t) {
      return TagNode(t, _buildTree(t.id));
    }).toList();
  }

  void _selectAllDescendants(TagNode node) {
    _selectedTagIds.add(node.tag.id);
    for (var child in node.children) _selectAllDescendants(child);
  }

  void _deselectAllDescendants(TagNode node) {
    _selectedTagIds.remove(node.tag.id);
    for (var child in node.children) _deselectAllDescendants(child);
  }

  void _selectAncestors(String? parentId) {
    if (parentId == null) return;
    _selectedTagIds.add(parentId);
    final parent = _allTags.firstWhere((t) => t.id == parentId, orElse: () => Tag(id: '', name: ''));
    if (parent.id.isNotEmpty) _selectAncestors(parent.parentId);
  }

  void _toggleTag(TagNode node, bool? isSelected) {
    setState(() {
      if (isSelected == true) {
        _selectAllDescendants(node);
        _selectAncestors(node.tag.parentId);
      } else {
        _deselectAllDescendants(node);
      }
    });
  }

  Widget _buildNode(TagNode node, int depth) {
    final isSelected = _selectedTagIds.contains(node.tag.id);

    if (node.children.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(left: depth * 20.0),
        child: CheckboxListTile(
          visualDensity: VisualDensity.compact,
          title: Text(node.tag.name, style: const TextStyle(fontSize: 14)),
          value: isSelected,
          activeColor: Colors.lightBlue,
          onChanged: (val) => _toggleTag(node, val),
        ),
      );
    }

    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: EdgeInsets.only(left: 8.0 + depth * 20.0, right: 8.0),
      title: Text(node.tag.name, style: const TextStyle(fontSize: 14)),
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
    if (_isLoading) {
      return const AlertDialog(content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())));
    }

    final tree = _buildTree(null);

    // 将原本的全屏 Scaffold 改为了小巧的 AlertDialog
    return AlertDialog(
      title: const Text('选择标签', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      contentPadding: const EdgeInsets.only(top: 8, bottom: 8),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.5, // 限制最大高度
        child: ListView.builder(
          itemCount: tree.length,
          itemBuilder: (context, index) {
            return _buildNode(tree[index], 0);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(color: Colors.grey)),
        ),
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