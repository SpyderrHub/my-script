import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  Widget _buildProjectTile(BuildContext context, String title, String subtitle) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        leading: Container(
          width: 64,
          height: 64,
          color: Colors.grey.shade300,
          child: const Icon(Icons.play_circle_outline, size: 36),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: IconButton(
          icon: const Icon(Icons.more_horiz),
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Responsive grid of recent projects for wider screens
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 720;
      return Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Recent Projects', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add),
                      label: const Text('New Project'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isWide
                    ? GridView.count(
                        crossAxisCount: 2,
                        childAspectRatio: 3.5,
                        children: List.generate(
                            6, (i) => _buildProjectTile(context, 'Project ${i + 1}', 'Duration: ${i + 1}m')),
                      )
                    : ListView(
                        children: List.generate(
                            6, (i) => _buildProjectTile(context, 'Project ${i + 1}', 'Duration: ${i + 1}m')),
                      ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
