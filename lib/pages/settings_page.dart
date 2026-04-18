import 'package:flutter/material.dart';
import 'changelog_page.dart';
import 'about_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('设置'), elevation: 0),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.history, color: Colors.lightBlue),
            title: const Text('更新日志'),
            trailing: const Icon(Icons.chevron_right, color: Colors.black26),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangelogPage()));
            },
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.lightBlue),
            title: const Text('关于作者'),
            trailing: const Icon(Icons.chevron_right, color: Colors.black26),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage()));
            },
          ),
        ],
      ),
    );
  }
}