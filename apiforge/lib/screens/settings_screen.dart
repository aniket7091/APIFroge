import 'package:flutter/material.dart';
import '../utils/storage_utils.dart';

/// Settings screen: environment variables management and theme toggle.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, String> _envVars = {};
  final _keyCtrl = TextEditingController();
  final _valCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _envVars = StorageUtils.getEnvVariables();
  }

  Future<void> _addVar() async {
    final key = _keyCtrl.text.trim();
    final val = _valCtrl.text.trim();
    if (key.isEmpty) return;
    setState(() => _envVars[key] = val);
    _keyCtrl.clear();
    _valCtrl.clear();
    await StorageUtils.setEnvVariables(_envVars);
  }

  Future<void> _removeVar(String key) async {
    setState(() => _envVars.remove(key));
    await StorageUtils.setEnvVariables(_envVars);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _valCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Environment & Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Environment Variables',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Use {{VAR_NAME}} in your request URL, headers, or body to interpolate values.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),

            // Add new variable
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _keyCtrl,
                            decoration: const InputDecoration(labelText: 'Variable Name', hintText: 'BASE_URL'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _valCtrl,
                            decoration: const InputDecoration(labelText: 'Value', hintText: 'https://api.example.com'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _addVar,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Variable list
            if (_envVars.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('No environment variables yet.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                ),
              )
            else
              ...(_envVars.entries.map((entry) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('{{${entry.key}}}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                      subtitle: Text(entry.value, style: const TextStyle(fontFamily: 'monospace')),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removeVar(entry.key),
                      ),
                    ),
                  ))),
          ],
        ),
      ),
    );
  }
}
