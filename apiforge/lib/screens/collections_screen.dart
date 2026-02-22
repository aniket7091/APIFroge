import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/collection_model.dart';
import '../services/collection_service.dart';
import '../widgets/sidebar_drawer.dart';

/// Collections management screen.
class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CollectionService>().fetchCollections();
    });
  }

  Future<void> _showCreateDialog([CollectionModel? existing]) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String selectedColor = existing?.color ?? '#6C63FF';

    final colors = ['#6C63FF', '#F44336', '#4CAF50', '#2196F3', '#FF9800', '#9C27B0', '#00BCD4'];

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'New Collection' : 'Edit Collection'),
        content: StatefulBuilder(
          builder: (context, setSt) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: colors.map((c) {
                  final hexColor = Color(int.parse(c.replaceFirst('#', '0xFF')));
                  return GestureDetector(
                    onTap: () => setSt(() => selectedColor = c),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: hexColor,
                        shape: BoxShape.circle,
                        border: selectedColor == c
                            ? Border.all(color: Colors.white, width: 2.5)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final svc = context.read<CollectionService>();
              if (existing == null) {
                await svc.createCollection(nameCtrl.text.trim(), descCtrl.text.trim(), selectedColor);
              } else {
                await svc.updateCollection(existing.id, nameCtrl.text.trim(), descCtrl.text.trim());
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Collection',
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      drawer: const SidebarDrawer(),
      body: Consumer<CollectionService>(
        builder: (_, svc, __) {
          if (svc.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (svc.collections.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open_outlined,
                      size: 64, color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  const Text('No collections yet', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Collection'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: svc.collections.length,
            itemBuilder: (ctx, idx) {
              final col = svc.collections[idx];
              final color = Color(int.parse(col.color.replaceFirst('#', '0xFF')));
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.folder_rounded, color: color),
                  ),
                  title: Text(col.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    col.description.isNotEmpty ? col.description : '${col.requests.length} request(s)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'edit') {
                        _showCreateDialog(col);
                      } else if (action == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete Collection'),
                            content: Text('Delete "${col.name}" and all its requests?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) svc.deleteCollection(col.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                      PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)))),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
