import 'package:flutter/material.dart';
import '../data/changelog_data.dart';

class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('更新日志'), elevation: 0),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: changelogData.length,
        itemBuilder: (context, index) {
          final entry = changelogData[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(entry.version, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.lightBlue)),
                    const SizedBox(width: 8),
                    Text(entry.date, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 12),
                ...entry.changes.map((change) => Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: Colors.black54, fontSize: 16)),
                      Expanded(child: Text(change, style: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.4))),
                    ],
                  ),
                )),
              ],
            ),
          );
        },
      ),
    );
  }
}