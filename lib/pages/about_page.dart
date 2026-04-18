import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('无法打开链接: $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('关于作者'), elevation: 0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.person, size: 60, color: Colors.lightBlue),
            ),
            const SizedBox(height: 24),
            const Text('Bamlax', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            const Text('独立开发者 / TreeTask 创造者', style: TextStyle(color: Colors.black54, fontSize: 16)),
            const SizedBox(height: 48),
            
            // GitHub 按钮
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(Icons.code),
                label: const Text('访问 GitHub'),
                onPressed: () => _launchUrl('https://github.com/Bamlax'),
              ),
            ),
            const SizedBox(height: 16),
            
            // 邮箱按钮
            SizedBox(
              width: 200,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.lightBlue, side: const BorderSide(color: Colors.lightBlue), padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(Icons.email_outlined),
                label: const Text('发送邮件联系'),
                onPressed: () => _launchUrl('mailto:your_email@example.com?subject=TreeTask%20Feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}