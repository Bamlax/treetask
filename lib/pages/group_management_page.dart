import 'package:flutter/material.dart';
import '../models/filter_model.dart';
import '../db/database_helper.dart';

class GroupManagementPage extends StatefulWidget {
  const GroupManagementPage({super.key});
  @override
  State<GroupManagementPage> createState() => _GroupManagementPageState();
}

class _GroupManagementPageState extends State<GroupManagementPage> {
  List<FilterGroup> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final groups = await DatabaseHelper.instance.getGroups();
    setState(() { _groups = groups; _isLoading = false; });
  }

  void _showAddGroupDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建分组', style: TextStyle(fontSize: 16)),
        content: TextField(controller: nameController, decoration: const InputDecoration(hintText: '输入分组名称'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue, foregroundColor: Colors.white, elevation: 0),
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await DatabaseHelper.instance.createGroup(nameController.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                _loadGroups();
              }
            },
            child: const Text('保存'),
          ),
        ],
      )
    );
  }

  void _deleteGroup(FilterGroup group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分组', style: TextStyle(color: Colors.red, fontSize: 16)),
        content: Text('确定要删除分组【${group.name}】吗？\n集子不会被删除，只会从该分组中移出。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0),
            onPressed: () async {
              await DatabaseHelper.instance.deleteGroup(group.id);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadGroups();
            },
            child: const Text('删除'),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('分组管理'), elevation: 0),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _groups.length,
        itemBuilder: (context, index) {
          final g = _groups[index];
          return ListTile(
            leading: const Icon(Icons.folder_outlined, color: Colors.lightBlue),
            title: Text(g.name),
            trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteGroup(g)),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.lightBlue, elevation: 2,
        onPressed: _showAddGroupDialog,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}