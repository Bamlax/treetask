import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/task_model.dart';
import '../models/filter_model.dart';
import '../db/database_helper.dart';

class FlatTagNode {
  final Tag tag;
  final int depth;
  bool isExpanded;
  FlatTagNode(this.tag, this.depth, {this.isExpanded = true});
}

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});
  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  List<Tag> _allTags = [];
  bool _isLoading = true;
  
  // 状态控制
  bool _isSortingMode = false;
  bool _isMultiSelectMode = false;
  Set<String> _selectedTagIds = {};
  Set<String> _expandedTagIds = {}; // 记录折叠状态，默认全都存入

  @override
  void initState() {
    super.initState();
    _loadTags(initExpand: true);
  }

  Future<void> _loadTags({bool initExpand = false}) async {
    final tags = await DatabaseHelper.instance.getAllTags();
    if (initExpand) {
      _expandedTagIds = tags.map((t) => t.id).toSet();
    }
    setState(() {
      _allTags = tags;
      _isLoading = false;
    });
  }

  // 扁平化树形结构
  List<FlatTagNode> _getFlatList() {
    List<FlatTagNode> result = [];
    void traverse(String? parentId, int depth) {
      final children = _allTags.where((t) => t.parentId == parentId).toList();
      for (var child in children) {
        final isExpanded = _expandedTagIds.contains(child.id);
        result.add(FlatTagNode(child, depth, isExpanded: isExpanded));
        if (isExpanded) {
          traverse(child.id, depth + 1);
        }
      }
    }
    traverse(null, 0);
    return result;
  }

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedTagIds.contains(id)) _expandedTagIds.remove(id);
      else _expandedTagIds.add(id);
    });
  }

  // 批量选择逻辑
  void _toggleSelect(String id) {
    setState(() {
      if (_selectedTagIds.contains(id)) {
        _selectedTagIds.remove(id);
        if (_selectedTagIds.isEmpty) _isMultiSelectMode = false;
      } else {
        _selectedTagIds.add(id);
      }
    });
  }

  // ---------------- 对话框操作 ----------------

  void _showAddTagDialog([Tag? parentTag]) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(parentTag == null ? '新建顶级标签' : '在【${parentTag.name}】下新建', style: const TextStyle(fontSize: 16)),
        content: TextField(controller: nameController, decoration: const InputDecoration(hintText: '输入标签名称'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue, foregroundColor: Colors.white, elevation: 0),
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final newTag = Tag(id: DateTime.now().millisecondsSinceEpoch.toString(), name: nameController.text, parentId: parentTag?.id);
                await DatabaseHelper.instance.insertTag(newTag);
                if (parentTag != null) _expandedTagIds.add(parentTag.id); // 自动展开
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

  void _showMoveDialog(List<String> targetIds) {
    String? selectedParentId;
    
    bool isDescendant(String potentialParentId, String nodeId) {
      if (potentialParentId == nodeId) return true;
      final p = _allTags.where((t) => t.id == potentialParentId).firstOrNull;
      if (p?.parentId == null) return false;
      return isDescendant(p!.parentId!, nodeId);
    }

    final validParents = _allTags.where((t) => !targetIds.contains(t.id) && !targetIds.any((targetId) => isDescendant(t.id, targetId))).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: Text('移动 ${targetIds.length} 个标签至...', style: const TextStyle(fontSize: 16)),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, elevation: 0),
              onPressed: () async {
                await DatabaseHelper.instance.moveTags(targetIds, selectedParentId);
                setState(() { _isMultiSelectMode = false; _selectedTagIds.clear(); });
                if (ctx.mounted) Navigator.pop(ctx);
                _loadTags();
              },
              child: const Text('确认移动'),
            ),
          ],
        )
      )
    );
  }

  void _showDeleteDialog(List<String> targetIds) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除', style: TextStyle(color: Colors.red, fontSize: 16)),
        content: Text('确认删除这 ${targetIds.length} 个标签吗？\n所有子标签也会被级联删除！'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () async {
              await DatabaseHelper.instance.deleteTags(targetIds);
              setState(() { _isMultiSelectMode = false; _selectedTagIds.clear(); });
              if (ctx.mounted) Navigator.pop(ctx);
              _loadTags();
            },
            child: const Text('删除'),
          ),
        ],
      )
    );
  }

  // 跨表配置集子的显示标签
  void _showLinkToFiltersDialog(List<String> targetTagIds) async {
    final filters = await DatabaseHelper.instance.getAllFiltersUnscoped();
    if (filters.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('尚未创建任何集子')));
      return;
    }
    
    List<String> selectedFilterIds = [];
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setModalState) => AlertDialog(
            title: const Text('配置到集子显示', style: TextStyle(fontSize: 16)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: filters.map((f) => CheckboxListTile(
                  title: Text(f.name ?? ''),
                  value: selectedFilterIds.contains(f.id),
                  onChanged: (val) {
                    setModalState(() {
                      if (val == true) selectedFilterIds.add(f.id!);
                      else selectedFilterIds.remove(f.id);
                    });
                  },
                )).toList(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue, foregroundColor: Colors.white, elevation: 0),
                onPressed: () async {
                  if (selectedFilterIds.isNotEmpty) {
                    await DatabaseHelper.instance.updateFiltersDisplayTags(selectedFilterIds, targetTagIds);
                  }
                  setState(() { _isMultiSelectMode = false; _selectedTagIds.clear(); });
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已更新集子的显示标签')));
                  }
                },
                child: const Text('确定'),
              ),
            ],
          )
        )
      );
    }
  }

  // ---------------- UI 构建 ----------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final flatList = _getFlatList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_isMultiSelectMode ? '已选 ${_selectedTagIds.length} 项' : '标签管理'),
        elevation: 0,
        leading: _isMultiSelectMode 
          ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _isMultiSelectMode = false; _selectedTagIds.clear(); }))
          : const BackButton(),
        actions: [
          if (_isMultiSelectMode) ...[
            IconButton(icon: const Icon(Icons.visibility), tooltip: '显示在集子', onPressed: () => _showLinkToFiltersDialog(_selectedTagIds.toList())),
            IconButton(icon: const Icon(Icons.drive_file_move_outline), tooltip: '批量移动', onPressed: () => _showMoveDialog(_selectedTagIds.toList())),
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: '批量删除', onPressed: () => _showDeleteDialog(_selectedTagIds.toList())),
          ] else ...[
            // 排序开关
            IconButton(
              icon: Icon(_isSortingMode ? Icons.check : Icons.sort),
              tooltip: _isSortingMode ? '完成排序' : '拖动排序',
              onPressed: () => setState(() { _isSortingMode = !_isSortingMode; }),
            ),
          ]
        ],
      ),
      body: SlidableAutoCloseBehavior(
        child: _isSortingMode 
          ? ReorderableListView.builder(
              itemCount: flatList.length,
              proxyDecorator: (child, index, animation) => Material(color: Colors.transparent, child: child),
              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex -= 1;
                final item = _allTags.removeAt(oldIndex);
                _allTags.insert(newIndex, item);
                setState(() {});
                await DatabaseHelper.instance.updateTagOrders(_allTags);
              },
              itemBuilder: (context, index) => _buildListItem(flatList[index], true),
            )
          : ListView.builder(
              itemCount: flatList.length,
              itemBuilder: (context, index) => _buildListItem(flatList[index], false),
            ),
      ),
      floatingActionButton: (!_isSortingMode && !_isMultiSelectMode)
        ? FloatingActionButton(
            backgroundColor: Colors.lightBlue, elevation: 2,
            onPressed: () => _showAddTagDialog(), 
            child: const Icon(Icons.add, color: Colors.white),
          ) : null,
    );
  }

    Widget _buildListItem(FlatTagNode node, bool isSorting) {
    final tag = node.tag;
    final hasChildren = _allTags.any((t) => t.parentId == tag.id);
    final isSelected = _selectedTagIds.contains(tag.id);

    Widget tile = ListTile(
      // 核心调整：缩小基础左边距，减小每一层级的缩进量 (16 -> 8, 24 -> 16)
      contentPadding: EdgeInsets.only(left: 8.0 + node.depth * 16.0, right: 8.0),
      horizontalTitleGap: 0, // 减小图标和文本之间的间距
      
      leading: _isMultiSelectMode
        ? Checkbox(
            visualDensity: VisualDensity.compact,
            value: isSelected, activeColor: Colors.lightBlue, 
            onChanged: (_) => _toggleSelect(tag.id)
          )
        : (hasChildren 
            // 将箭头按钮变小并消除自带的内边距，让排版更紧凑
            ? IconButton(
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: Icon(node.isExpanded ? Icons.expand_more : Icons.chevron_right, color: Colors.black54), 
                onPressed: () => _toggleExpand(tag.id)
              )
            // 没有子节点时，使用 32 宽度的占位符，与箭头按钮完美对齐
            : const SizedBox(width: 32)), 
            
      title: Text(tag.name, style: TextStyle(fontWeight: node.depth == 0 ? FontWeight.bold : FontWeight.normal)),
      
      onLongPress: (!_isSortingMode) ? () {
        setState(() {
          _isMultiSelectMode = true;
          _selectedTagIds.add(tag.id);
        });
      } : null,
      onTap: () {
        if (_isMultiSelectMode) _toggleSelect(tag.id);
        else if (hasChildren) _toggleExpand(tag.id);
      },
      trailing: isSorting ? const Icon(Icons.drag_handle, color: Colors.grey) : null,
    );

    if (isSorting || _isMultiSelectMode) {
      return Container(key: ValueKey(tag.id), color: isSelected ? Colors.blue.shade50 : Colors.white, child: tile);
    }

    return Slidable(
      key: ValueKey(tag.id),
      groupTag: '0',
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.6,
        children: [
          SlidableAction(onPressed: (_) => _showAddTagDialog(tag), backgroundColor: Colors.lightBlue, foregroundColor: Colors.white, icon: Icons.add, label: '添加'),
          SlidableAction(onPressed: (_) => _showMoveDialog([tag.id]), backgroundColor: Colors.orange, foregroundColor: Colors.white, icon: Icons.drive_file_move_outline, label: '移动'),
          SlidableAction(onPressed: (_) => _showDeleteDialog([tag.id]), backgroundColor: Colors.red, foregroundColor: Colors.white, icon: Icons.delete_outline, label: '删除'),
        ],
      ),
      child: Container(color: Colors.white, child: tile),
    );
  }
}