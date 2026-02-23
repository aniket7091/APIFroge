import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/ai_service.dart';
import '../services/proxy_service.dart';
import '../services/collection_service.dart';
import '../utils/storage_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/response_viewer.dart';

// ── Message model
enum _MsgRole { user, assistant }

class _ChatMessage {
  final _MsgRole role;
  final String text;
  final Map<String, dynamic>? aiRequest;
  final ProxyResult? proxyResult;
  final DateTime timestamp;

  _ChatMessage({
    required this.role,
    required this.text,
    this.aiRequest,
    this.proxyResult,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ── Saved chat session (for history) ─────────────────────────────────────────
class _ChatSession {
  final String id; // unique key for upsert
  final String title; // user's first prompt
  final List<_ChatMessage> messages;
  final DateTime savedAt;

  _ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.savedAt,
  });
}

// ── Main Screen ───────────────────────────────────────────────────────────────
class AiAssistantScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> aiReq)? onLoadInEditor;
  const AiAssistantScreen({super.key, this.onLoadInEditor});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with TickerProviderStateMixin {
  final _promptCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  final List<_ChatMessage> _messages = [];
  _ChatMessage? _selectedMessage;
  bool _isThinking = false;

  // Response panel drag-resize state
  double _responseHeight = 320;
  static const double _responseMinHeight = 120;
  static const double _responseMaxHeight = 700;

  // History — keyed sessions; current session is upserted live
  final List<_ChatSession> _history = [];
  String _currentSessionId = '';

  static _ChatMessage _makeWelcome() => _ChatMessage(
        role: _MsgRole.assistant,
        text:
            'Ready to build. Describe the API endpoint you need help with today, or select a template to get started.',
      );

  @override
  void initState() {
    super.initState();
    _messages.add(_makeWelcome());
    _currentSessionId = DateTime.now().toIso8601String();
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Scroll ─────────────────────────────────────────────────────────────────
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Send ───────────────────────────────────────────────────────────────────
  Future<void> _sendPrompt() async {
    final text = _promptCtrl.text.trim();
    if (text.isEmpty || _isThinking) return;

    final userMsg = _ChatMessage(role: _MsgRole.user, text: text);
    setState(() {
      _messages.add(userMsg);
      _isThinking = true;
      _promptCtrl.clear();
    });
    _scrollToBottom();

    final aiSvc = context.read<AiService>();
    final envVars = StorageUtils.getEnvVariables();
    final collections = context.read<CollectionService>().collections;
    final contextData = {
      'envVars': envVars,
      'collections':
          collections.map((c) => {'id': c.id, 'name': c.name}).toList(),
    };

    final result = await aiSvc.executePrompt(text, contextData);

    setState(() {
      _isThinking = false;
      if (result != null) {
        final aiMsg = _ChatMessage(
          role: _MsgRole.assistant,
          text:
              "I've generated a ${result.aiRequest['method']} request for the "
              "`${_trimUrl(result.aiRequest['url'] ?? '')}` endpoint"
              "${result.aiRequest['body'] != null ? ' with a JSON body template' : ''}.",
          aiRequest: result.aiRequest,
          proxyResult: result.proxyResponse,
        );
        _messages.add(aiMsg);
        _selectedMessage = aiMsg;
        context.read<ProxyService>().setResult(result.proxyResponse);
        // Auto-snapshot current session into history after every AI reply
        _upsertCurrentSession();
      } else {
        _messages.add(_ChatMessage(
          role: _MsgRole.assistant,
          text: aiSvc.error ?? 'Something went wrong. Please try again.',
        ));
      }
    });
    _scrollToBottom();
  }

  String _trimUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.path.isEmpty ? url : uri.path;
    } catch (_) {
      return url;
    }
  }

  // ── Upsert current session into history ───────────────────────────────────
  void _upsertCurrentSession() {
    final userMsgs = _messages.where((m) => m.role == _MsgRole.user).toList();
    if (userMsgs.isEmpty) return;
    final title = userMsgs.first.text;
    final snapshot = _ChatSession(
      id: _currentSessionId,
      title: title,
      messages: List.from(_messages),
      savedAt: DateTime.now(),
    );
    final idx = _history.indexWhere((s) => s.id == _currentSessionId);
    if (idx >= 0) {
      _history[idx] = snapshot;
    } else {
      _history.insert(0, snapshot);
    }
  }

  // ── New Chat (archives current and starts fresh) ────────────────────────────
  void _newChat() {
    _upsertCurrentSession();
    _currentSessionId = DateTime.now().toIso8601String();
    setState(() {
      _messages.clear();
      _messages.add(_makeWelcome());
      _selectedMessage = null;
    });
  }

  // ── Restore session from history ───────────────────────────────────────────
  void _restoreSession(_ChatSession session) {
    setState(() {
      _messages.clear();
      _messages.addAll(List.from(session.messages));
      _currentSessionId = session.id;
      // Find the last AI message with a request
      _ChatMessage? last;
      for (final m in _messages.reversed) {
        if (m.role == _MsgRole.assistant && m.aiRequest != null) {
          last = m;
          break;
        }
      }
      _selectedMessage = last;
    });
    _scrollToBottom();
  }

  // ── Delete history entry ────────────────────────────────────────────────────
  void _deleteHistoryEntry(String id) {
    setState(() => _history.removeWhere((s) => s.id == id));
  }

  void _clearAllHistory() => setState(() => _history.clear());

  // ── Show history dialog ────────────────────────────────────────────────────
  void _showHistoryDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding:
                const EdgeInsets.only(left: 0, top: 0, bottom: 0, right: 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 380,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.darkSurface,
                  border:
                      Border(right: BorderSide(color: AppColors.darkBorder)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: AppColors.darkBorder))),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFF7C3AED),
                                Color(0xFF2563EB)
                              ]),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.history,
                                color: Colors.white, size: 17),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Chat History',
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                Text('Tap a session to restore it',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          if (_history.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: ctx,
                                  builder: (c) => AlertDialog(
                                    backgroundColor: AppColors.darkSurface,
                                    title: const Text('Clear All',
                                        style: TextStyle(
                                            color: AppColors.textPrimary)),
                                    content: const Text(
                                        'Delete all chat history? This cannot be undone.',
                                        style: TextStyle(
                                            color: AppColors.textSecondary)),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(c),
                                          child: const Text('Cancel')),
                                      ElevatedButton(
                                        onPressed: () {
                                          _clearAllHistory();
                                          setDialogState(() {});
                                          Navigator.pop(c);
                                        },
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red),
                                        child: const Text('Delete All'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.delete_sweep,
                                          size: 13, color: Colors.red),
                                      SizedBox(width: 4),
                                      Text('Clear All',
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500)),
                                    ]),
                              ),
                            ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: AppColors.darkBg,
                                  borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.close,
                                  size: 16, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Sessions list
                    Expanded(
                      child: _history.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_outline,
                                      size: 48, color: AppColors.darkBorder),
                                  SizedBox(height: 12),
                                  Text('No history yet',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500)),
                                  SizedBox(height: 4),
                                  Text(
                                      'Ask Forge AI something to start building history',
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11),
                                      textAlign: TextAlign.center),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _history.length,
                              itemBuilder: (_, i) {
                                final s = _history[i];
                                final isActive = s.id == _currentSessionId;
                                return _HistorySessionTile(
                                  session: s,
                                  isActive: isActive,
                                  onTap: () {
                                    _restoreSession(s);
                                    Navigator.pop(ctx);
                                  },
                                  onDelete: () {
                                    _deleteHistoryEntry(s.id);
                                    setDialogState(() {});
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Copy cURL ──────────────────────────────────────────────────────────────
  void _copyCurl(_ChatMessage msg) {
    final req = msg.aiRequest;
    if (req == null) return;
    final method = (req['method'] ?? 'GET').toString().toUpperCase();
    final url = req['url'] ?? '';
    final headers = (req['headers'] as Map?)
            ?.entries
            .map((e) => "-H '${e.key}: ${e.value}'")
            .join(' ') ??
        '';
    final body = req['body'] != null
        ? "-d '${const JsonEncoder().convert(req['body'])}'"
        : '';
    final curl = "curl -X $method '$url' $headers $body".trim();
    Clipboard.setData(ClipboardData(text: curl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('cURL copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _saveToCollection(_ChatMessage msg) {
    if (msg.aiRequest != null && widget.onLoadInEditor != null) {
      widget.onLoadInEditor!(msg.aiRequest!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request loaded into the editor!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Row(
              children: [
                _buildChatPanel(),
                _buildPreviewPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('AI Assistant',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              Row(children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                const Text('ONLINE',
                    style: TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
              ]),
            ],
          ),
          const Spacer(),
          // Export History button → opens history modal
          OutlinedButton.icon(
            onPressed: _showHistoryDialog,
            icon: const Icon(Icons.history, size: 14),
            label: const Text('History', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.darkBorder),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _newChat,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('New Chat', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ── LEFT CHAT PANEL ────────────────────────────────────────────────────────
  Widget _buildChatPanel() {
    return Container(
      width: 480,
      decoration: const BoxDecoration(
        color: AppColors.darkBg,
        border: Border(right: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _DateChip(label: _todayLabel()),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: _messages.length + (_isThinking ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _messages.length) {
                  return _buildAssistantBubble(
                      _ChatMessage(role: _MsgRole.assistant, text: ''),
                      isThinking: true);
                }
                final msg = _messages[i];
                return msg.role == _MsgRole.user
                    ? _buildUserBubble(msg)
                    : _buildAssistantBubble(msg);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    final hr = now.hour.toString().padLeft(2, '0');
    final mn = now.minute.toString().padLeft(2, '0');
    return 'Today, $hr:$mn ${now.hour < 12 ? 'AM' : 'PM'}';
  }

  Widget _buildUserBubble(_ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(msg.text,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.4)),
            ),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFF374151),
            child: Icon(Icons.person, size: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(_ChatMessage msg, {bool isThinking = false}) {
    final isSelected = _selectedMessage == msg;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.auto_awesome, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Forge AI',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: msg.aiRequest != null
                      ? () => setState(() => _selectedMessage = msg)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accent.withValues(alpha: 0.5)
                            : AppColors.darkBorder,
                      ),
                    ),
                    child: isThinking
                        ? _ThinkingIndicator()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (msg.text.isNotEmpty)
                                _RichAiText(text: msg.text),
                              if (msg.aiRequest != null) ...[
                                const SizedBox(height: 10),
                                _ActionButtons(
                                  onTestRequest: () =>
                                      setState(() => _selectedMessage = msg),
                                  onCopyCurl: () => _copyCurl(msg),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.darkBorder))),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: TextField(
                      controller: _promptCtrl,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 7,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Ask Forge AI to modify the request...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: AppColors.darkSurface, // ← gray background

                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,

                        contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendPrompt(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: _isThinking
                      ? Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.darkBorder,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(9),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                        )
                      : GestureDetector(
                          onTap: _sendPrompt,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.arrow_upward,
                                color: Colors.white, size: 18),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _QuickAction(
                  label: 'Add Validation',
                  onTap: () =>
                      _quickPrompt('Add input validation to this request')),
              const SizedBox(width: 8),
              _QuickAction(
                  label: 'Generate Docs',
                  onTap: () => _quickPrompt(
                      'Generate documentation for this API endpoint')),
              const SizedBox(width: 8),
              _QuickAction(
                  label: 'Save to Collection',
                  onTap: () {
                    if (_selectedMessage != null) {
                      _saveToCollection(_selectedMessage!);
                    }
                  }),
            ],
          ),
        ],
      ),
    );
  }

  void _quickPrompt(String text) {
    _promptCtrl.text = text;
    _sendPrompt();
  }

  // ── RIGHT PREVIEW PANEL ────────────────────────────────────────────────────
  Widget _buildPreviewPanel() {
    if (_selectedMessage == null || _selectedMessage!.aiRequest == null) {
      return Expanded(child: _buildEmptyPreview());
    }
    final req = _selectedMessage!.aiRequest!;
    final proxy = _selectedMessage!.proxyResult;

    return Expanded(child: _buildRequestPreviewPanel(req, proxy));
  }

  Widget _buildEmptyPreview() {
    return Container(
      color: AppColors.darkBg,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
              ).createShader(bounds),
              child:
                  const Icon(Icons.auto_awesome, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Text('Ask Forge AI to build a request',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            const Text('The request preview will appear here.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TemplateChip(
                    label: 'Login with email & password',
                    onTap: () => _quickPrompt(
                        'Create a POST request to login with email and password')),
                _TemplateChip(
                    label: 'Fetch user list',
                    onTap: () => _quickPrompt(
                        'Create a GET request to fetch all users')),
                _TemplateChip(
                    label: 'Create a product',
                    onTap: () => _quickPrompt(
                        'Create a POST request to create a new product with name, price and stock')),
                _TemplateChip(
                    label: 'Delete item by ID',
                    onTap: () => _quickPrompt(
                        'Create a DELETE request to remove an item by its ID')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestPreviewPanel(
      Map<String, dynamic> req, ProxyResult? proxy) {
    final method = (req['method'] ?? 'GET').toString().toUpperCase();
    final url = req['url'] ?? '';
    final headers = req['headers'] as Map? ?? {};
    final body = req['body'];

    String prettyBody = '';
    if (body != null) {
      try {
        prettyBody = const JsonEncoder.withIndent('  ').convert(body);
      } catch (_) {
        prettyBody = body.toString();
      }
    }

    return Column(
      children: [
        // URL bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppColors.darkSurface,
            border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
          ),
          child: Row(
            children: [
              _MethodBadge(method: method),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.darkBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.darkBorder),
                  ),
                  child: Text(url,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  if (widget.onLoadInEditor != null) {
                    widget.onLoadInEditor!(req);
                  }
                },
                icon: const Icon(Icons.play_arrow, size: 14),
                label: const Text('Send', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 36,
                child: OutlinedButton(
                  onPressed: () => _copyCurl(_selectedMessage!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.darkBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Icon(Icons.copy, size: 16),
                ),
              ),
            ],
          ),
        ),

        // Body / Params / Headers / Auth tabs (flex)
        Expanded(
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.darkSurface,
                    border:
                        Border(bottom: BorderSide(color: AppColors.darkBorder)),
                  ),
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: AppColors.accent,
                    labelStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                    unselectedLabelColor: AppColors.textSecondary,
                    labelColor: AppColors.accent,
                    tabs: [
                      const Tab(text: 'Body'),
                      const Tab(text: 'Params'),
                      Tab(
                          text:
                              'Headers${headers.isNotEmpty ? " (${headers.length})" : ""}'),
                      const Tab(text: 'Auth'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildCodeView(prettyBody.isEmpty ? 'null' : prettyBody),
                      _KVPreview(
                          map: (req['params'] as Map?)
                                  ?.cast<String, dynamic>() ??
                              {}),
                      _KVPreview(map: headers.cast<String, dynamic>()),
                      const Center(
                        child: Text('No auth configured',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── RESIZABLE RESPONSE PANEL ─────────────────────────────────────────
        if (proxy != null) _buildResizableResponsePanel(proxy),
      ],
    );
  }

  // ── RESIZABLE RESPONSE SECTION ─────────────────────────────────────────────
  Widget _buildResizableResponsePanel(ProxyResult proxy) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) {
            setState(() {
              _responseHeight = (_responseHeight - details.delta.dy)
                  .clamp(_responseMinHeight, _responseMaxHeight);
            });
          },
          child: Container(
            height: 10,
            color: AppColors.darkSurface,
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),

        // Response content
        SizedBox(
          height: _responseHeight,
          child: Column(
            children: [
              // Response header bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: AppColors.darkSurface,
                child: Row(
                  children: [
                    const Text('RESPONSE',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    const SizedBox(width: 12),
                    if (!proxy.isError) ...[
                      _StatusPill(statusCode: proxy.statusCode),
                      const SizedBox(width: 8),
                      Text('${proxy.responseTime}ms',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                      const SizedBox(width: 8),
                      Text('${(proxy.size / 1024).toStringAsFixed(1)}KB',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ] else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('ERROR',
                            style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    const Spacer(),
                    // Reset height
                    GestureDetector(
                      onTap: () => setState(() => _responseHeight = 320),
                      child: const Icon(Icons.unfold_more,
                          size: 16, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ResponseViewer(
                  statusCode: proxy.statusCode,
                  statusText: proxy.statusText,
                  body: proxy.body,
                  headers: proxy.headers,
                  responseTime: proxy.responseTime,
                  isError: proxy.isError,
                  errorMessage: proxy.errorMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCodeView(String code) {
    return Container(
      color: AppColors.darkBg,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: _JsonColorizer(rawJson: code),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.copy, size: 12, color: AppColors.textSecondary),
                  SizedBox(width: 4),
                  Text('Copy',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// JSON COLORIZER — purple keys, green values
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _JsonColorizer extends StatelessWidget {
  final String rawJson;
  static const _keyColor = Color(0xFFD078FF); // purple
  static const _stringColor = Color(0xFF4EC994); // green
  static const _numberColor = Color(0xFF79B8FF); // blue
  static const _boolColor = Color(0xFFFFAB70); // orange
  static const _nullColor = Color(0xFFE06C75); // red
  static const _punctColor = Color(0xFFABB2BF); // grey

  const _JsonColorizer({required this.rawJson});

  @override
  Widget build(BuildContext context) {
    final spans = _tokenize(rawJson);
    return SelectableText.rich(
      TextSpan(children: spans),
      style:
          const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.6),
    );
  }

  List<TextSpan> _tokenize(String src) {
    // Regex-based tokenizer for JSON
    final spans = <TextSpan>[];
    final re = RegExp(
      r'"((?:[^"\\]|\\.)*)"\s*:' // key
      r'|"((?:[^"\\]|\\.)*)"' // string value
      r'|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)' // number
      r'|(true|false)' // bool
      r'|(null)' // null
      r'|([{}\[\],])' // punctuation
      r'|(\s+)', // whitespace
    );

    int pos = 0;
    for (final m in re.allMatches(src)) {
      // Any unmatched text before this token
      if (m.start > pos) {
        spans.add(TextSpan(
            text: src.substring(pos, m.start),
            style: const TextStyle(color: _punctColor)));
      }
      pos = m.end;

      if (m.group(1) != null) {
        // Key (with surrounding quotes and colon)
        final full = m.group(0)!;
        final colonIdx = full.lastIndexOf(':');
        spans.add(TextSpan(
            text: full.substring(0, colonIdx + 1),
            style: const TextStyle(color: _keyColor)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
            text: m.group(0), style: const TextStyle(color: _stringColor)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
            text: m.group(0), style: const TextStyle(color: _numberColor)));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(
            text: m.group(0), style: const TextStyle(color: _boolColor)));
      } else if (m.group(5) != null) {
        spans.add(TextSpan(
            text: m.group(0), style: const TextStyle(color: _nullColor)));
      } else if (m.group(6) != null) {
        spans.add(TextSpan(
            text: m.group(0), style: const TextStyle(color: _punctColor)));
      } else {
        // whitespace
        spans.add(TextSpan(text: m.group(0)));
      }
    }
    // Remaining
    if (pos < src.length) {
      spans.add(TextSpan(
          text: src.substring(pos),
          style: const TextStyle(color: _punctColor)));
    }
    return spans;
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// HISTORY SESSION TILE
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class _HistorySessionTile extends StatelessWidget {
  final _ChatSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistorySessionTile({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accent.withValues(alpha: 0.08)
                  : AppColors.darkBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? AppColors.accent.withValues(alpha: 0.5)
                    : AppColors.darkBorder,
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.accent.withValues(alpha: 0.15)
                        : AppColors.darkSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 15,
                    color:
                        isActive ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isActive
                                    ? AppColors.accent
                                    : AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isActive)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Active',
                                  style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${session.messages.where((m) => m.role == _MsgRole.user).length} prompts  •  ${_formatDate(session.savedAt)}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.delete_outline,
                        size: 14, color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SHARED HELPER WIDGETS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _DateChip extends StatelessWidget {
  final String label;
  const _DateChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Text(label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
    );
  }
}

class _ThinkingIndicator extends StatefulWidget {
  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
                color: AppColors.accent, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _RichAiText extends StatelessWidget {
  final String text;
  const _RichAiText({required this.text});

  @override
  Widget build(BuildContext context) {
    final parts = text.split(RegExp(r'`([^`]+)`'));
    final matches = RegExp(r'`([^`]+)`').allMatches(text).toList();
    final spans = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(
            text: parts[i],
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13, height: 1.5)));
      }
      if (i < matches.length) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(matches[i].group(1) ?? '',
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppColors.accentLight)),
          ),
        ));
      }
    }
    return RichText(text: TextSpan(children: spans));
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onTestRequest;
  final VoidCallback onCopyCurl;
  const _ActionButtons({required this.onTestRequest, required this.onCopyCurl});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _SmallActionBtn(
          icon: Icons.play_arrow,
          label: 'Test Request',
          onTap: onTestRequest,
          primary: true),
      const SizedBox(width: 8),
      _SmallActionBtn(
          icon: Icons.content_copy, label: 'Copy cURL', onTap: onCopyCurl),
    ]);
  }
}

class _SmallActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  const _SmallActionBtn(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.primary = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: primary
              ? AppColors.accent.withValues(alpha: 0.12)
              : AppColors.darkBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: primary
                ? AppColors.accent.withValues(alpha: 0.4)
                : AppColors.darkBorder,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 13,
              color: primary ? AppColors.accent : AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: primary ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TemplateChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.flash_on, size: 13, color: AppColors.accent),
          const SizedBox(width: 5),
          Text(label,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  final String method;
  const _MethodBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.methodColor(method);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(method,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(width: 4),
        Icon(Icons.expand_more, size: 14, color: color),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final int statusCode;
  const _StatusPill({required this.statusCode});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(statusCode);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('● $statusCode',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _KVPreview extends StatelessWidget {
  final Map<String, dynamic> map;
  const _KVPreview({required this.map});

  @override
  Widget build(BuildContext context) {
    if (map.isEmpty) {
      return const Center(
        child: Text('No data',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(14),
      children: map.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: const BoxDecoration(
                  color: AppColors.accent, shape: BoxShape.circle),
            ),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12, height: 1.5),
                  children: [
                    TextSpan(
                        text: '${e.key}: ',
                        style: const TextStyle(
                            color: Color(0xFFD078FF), // purple key
                            fontWeight: FontWeight.w600)),
                    TextSpan(
                        text: e.value.toString(),
                        style: const TextStyle(
                            color: Color(0xFF4EC994))), // green value
                  ],
                ),
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }
}
