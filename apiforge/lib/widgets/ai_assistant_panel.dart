import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/ai_service.dart';
import '../services/proxy_service.dart';
import '../services/collection_service.dart';
import '../utils/storage_utils.dart';
import 'response_viewer.dart';

class AiAssistantPanel extends StatefulWidget {
  final void Function(Map<String, dynamic> aiReq)? onAiRequestGenerated;

  const AiAssistantPanel({super.key, this.onAiRequestGenerated});

  @override
  State<AiAssistantPanel> createState() => _AiAssistantPanelState();
}

class _AiAssistantPanelState extends State<AiAssistantPanel> {
  final _promptCtrl = TextEditingController();

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _executePrompt() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;

    final aiService = context.read<AiService>();
    final collections = context.read<CollectionService>().collections;
    final envVars = StorageUtils.getEnvVariables();

    final contextData = {
      'envVars': envVars,
      'collections': collections
          .map((c) => {'id': c.id, 'name': c.name})
          .toList(),
    };

    final result = await aiService.executePrompt(prompt, contextData);

    if (result != null && mounted) {
      _promptCtrl.clear();
      // Push the proxy result to the global ProxyService so the right panel updates
      context.read<ProxyService>().setResult(result.proxyResponse);

      // Notify parent to update UI fields
      if (widget.onAiRequestGenerated != null) {
        widget.onAiRequestGenerated!(result.aiRequest);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiService = context.watch<AiService>();
    final cs = Theme.of(context).colorScheme;

    return SizedBox.expand(
      child: Column(
        children: [

          // =========================
          // 🔥 AI INPUT BAR
          // =========================
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptCtrl,
                    minLines: 1,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText:
                      'Ask AI to perform API task (e.g., Create a user named Aniket)',
                      prefixIcon: const Icon(Icons.auto_awesome),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _executePrompt(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed:
                    aiService.isProcessing ? null : _executePrompt,
                    icon: aiService.isProcessing
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.send),
                    label: Text(
                        aiService.isProcessing ? "Thinking..." : "Execute"),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // =========================
          // 🔥 MAIN CONTENT AREA
          // =========================
          Expanded(
            child: Builder(
              builder: (context) {

                if (aiService.isProcessing) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "AI is generating and executing request...",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (aiService.lastResult == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 60,
                          color: cs.primary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Ask AI to automate your API testing",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final result = aiService.lastResult!;
                final aiReq = result.aiRequest;

                // Show only the request preview here. The response will show in the global Response panel.
                return _buildRequestPreview(aiReq);
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // 🔥 REQUEST PREVIEW PANEL
  // =========================
  Widget _buildRequestPreview(Map<String, dynamic> aiReq) {

    String prettyBody = '';
    if (aiReq['body'] != null) {
      try {
        prettyBody =
            const JsonEncoder.withIndent('  ').convert(aiReq['body']);
      } catch (_) {
        prettyBody = aiReq['body'].toString();
      }
    }

    return SizedBox.expand(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1e1e2e),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // METHOD + URL
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _methodColor(
                          aiReq['method'] ?? 'GET')
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (aiReq['method'] ?? 'GET').toString().toUpperCase(),
                      style: TextStyle(
                        color: _methodColor(
                            aiReq['method'] ?? 'GET'),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      aiReq['url'] ?? '',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

              // HEADERS
              if (aiReq['headers'] != null &&
                  (aiReq['headers'] as Map).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text("Headers:",
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                ...((aiReq['headers'] as Map).entries.map(
                      (e) => SelectableText(
                    "${e.key}: ${e.value}",
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Colors.lightBlueAccent),
                  ),
                )),
              ],

              // BODY
              if (prettyBody.isNotEmpty &&
                  prettyBody != "null") ...[
                const SizedBox(height: 16),
                const Text("Body:",
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    prettyBody,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _methodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return Colors.green;
      case 'POST':
        return Colors.orange;
      case 'PUT':
        return Colors.blue;
      case 'PATCH':
        return Colors.purple;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}