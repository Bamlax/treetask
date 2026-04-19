import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'changelog_page.dart';
import 'about_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDynamicHeight = false;
  double _fixedRatio = 0.8;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final mode = await DatabaseHelper.instance.getSetting('height_mode');
    final ratioStr = await DatabaseHelper.instance.getSetting('fixed_ratio');
    setState(() {
      _isDynamicHeight = mode == 'dynamic';
      _fixedRatio = ratioStr != null ? double.parse(ratioStr) : 0.8;
      _isLoading = false;
    });
  }

  Future<void> _saveMode(bool isDynamic) async {
    setState(() => _isDynamicHeight = isDynamic);
    await DatabaseHelper.instance.saveSetting('height_mode', isDynamic ? 'dynamic' : 'fixed');
  }

  Future<void> _saveRatio(double ratio) async {
    setState(() => _fixedRatio = ratio);
    await DatabaseHelper.instance.saveSetting('fixed_ratio', ratio.toString());
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('设置'), elevation: 0),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('看板布局设置', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            title: const Text('集子高度自动拉伸'),
            subtitle: const Text('开启后，瀑布流布局。集子高度将根据代办数量自动伸缩；关闭则保持全屏固定长度。'),
            activeColor: Colors.lightBlue,
            value: _isDynamicHeight,
            onChanged: _saveMode,
          ),
          if (!_isDynamicHeight)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('固定比例: ${_fixedRatio.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14)),
                  Slider(
                    value: _fixedRatio,
                    min: 0.5,
                    max: 1.5,
                    divisions: 20,
                    activeColor: Colors.lightBlue,
                    onChanged: _saveRatio,
                  ),
                  const Text('数值越小，集子越长；数值越大，集子越短。', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('关于', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.history, color: Colors.lightBlue),
            title: const Text('更新日志'),
            trailing: const Icon(Icons.chevron_right, color: Colors.black26),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangelogPage())),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.lightBlue),
            title: const Text('关于作者'),
            trailing: const Icon(Icons.chevron_right, color: Colors.black26),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage())),
          ),
        ],
      ),
    );
  }
}