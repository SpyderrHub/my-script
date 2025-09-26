import 'dart:math';
import 'package:flutter/material.dart';
import '../widgets/rounded_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  Widget _projectCard(BuildContext ctx, int index) {
    final colors = [Color(0xFF6C63FF), Color(0xFF00D1FF), Color(0xFFFFC857)];
    final rng = Random(index);
    final color = colors[index % colors.length].withOpacity(0.12);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(width: 84, height: 64, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.play_circle_fill, size: 36)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Project ${index + 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Edited • ${(rng.nextInt(10) + 1)}m • ${rng.nextBool() ? 'Draft' : 'Saved'}', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.7))),
                ]),
              ),
              RoundedButton(label: 'Open', icon: Icons.open_in_new, onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Responsive grid: 1 column on narrow phones, 2 on tablets
    final width = MediaQuery.of(context).size.width;
    final cross = width > 720 ? 2 : 1;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cross, childAspectRatio: 3.6, crossAxisSpacing: 12, mainAxisSpacing: 12),
          itemCount: 8,
          itemBuilder: (context, i) => _projectCard(context, i),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        label: const Text('New Project'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
