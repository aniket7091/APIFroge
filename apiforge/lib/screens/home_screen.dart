import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/proxy_service.dart';
import '../services/collection_service.dart';
import '../services/request_service.dart';
import '../models/request_model.dart';
import '../utils/storage_utils.dart';
import '../widgets/sidebar_drawer.dart';
import '../widgets/response_viewer.dart';

/// The main request builder screen — the heart of APIForge.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Request state
  String _method = 'GET';
  final _urlCtrl = TextEditingController(
      text: 'https://jsonplaceholder.typicode.com/todos/1');
  List<_KVEntry> _params = [_KVEntry()];
  List<_KVEntry> _headers = [_KVEntry()];
  AuthConfig _auth = const AuthConfig();
  String _bodyType = 'none';
  final _bodyCtrl = TextEditingController();

  late TabController _requestTabCtrl;
  late TabController _responseTabCtrl;

  static const _methods = [
    'GET',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'HEAD',
    'OPTIONS'
  ];

  @override
  void initState() {
    super.initState();
    _requestTabCtrl = TabController(
        length: 5, vsync: this); // Params|Headers|Body|Auth|Snippets
    _responseTabCtrl = TabController(length: 1, vsync: this);
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CollectionService>().fetchCollections();
    });
  }

  @override
  void dispose() {
    _requestTabCtrl.dispose();
    _responseTabCtrl.dispose();
    _urlCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _kvToMap(List<_KVEntry> entries) {
    final m = <String, String>{};
    for (final e in entries) {
      if (e.key.isNotEmpty) m[e.key] = e.value;
    }
    return m;
  }

  Future<void> _sendRequest() async {
    final proxy = context.read<ProxyService>();
    final envVars = StorageUtils.getEnvVariables();

    dynamic body;
    if (_bodyType == 'json' && _bodyCtrl.text.isNotEmpty) {
      try {
        body = json.decode(_bodyCtrl.text);
      } catch (_) {
        body = _bodyCtrl.text;
      }
    } else if (_bodyType == 'raw') {
      body = _bodyCtrl.text;
    }

    await proxy.sendRequest(
      method: _method,
      url: _urlCtrl.text.trim(),
      headers: _kvToMap(_headers),
      params: _kvToMap(_params),
      body: body,
      bodyType: _bodyType,
      auth: _auth,
      envVars: envVars,
    );
  }

  Future<void> _saveRequest() async {
    final collections = context.read<CollectionService>().collections;
    String? selectedCollectionId;
    final nameCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Request Name')),
            const SizedBox(height: 14),
            if (collections.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration:
                    const InputDecoration(labelText: 'Collection (optional)'),
                items: collections
                    .map((c) =>
                        DropdownMenuItem(value: c.id, child: Text(c.name)))
                    .toList(),
                onChanged: (v) => selectedCollectionId = v,
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final svc = context.read<RequestService>();
              dynamic body;
              if (_bodyType == 'json' && _bodyCtrl.text.isNotEmpty) {
                try {
                  body = json.decode(_bodyCtrl.text);
                } catch (_) {
                  body = _bodyCtrl.text;
                }
              }
              await svc.saveRequest(RequestModel(
                id: '',
                name: nameCtrl.text.trim().isEmpty
                    ? '$_method ${_urlCtrl.text}'
                    : nameCtrl.text.trim(),
                method: _method,
                url: _urlCtrl.text.trim(),
                headers: _kvToMap(_headers),
                params: _kvToMap(_params),
                body: body,
                bodyType: _bodyType,
                auth: _auth,
                collectionId: selectedCollectionId,
              ));
              if (mounted) {
                Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Request saved!')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSnippets() async {
    final proxy = context.read<ProxyService>();
    String snippetType = 'curl';
    String snippetText = '';

    Future<void> loadSnippet(StateSetter setSt) async {
      await proxy.fetchSnippet(
        type: snippetType,
        method: _method,
        url: _urlCtrl.text.trim(),
        headers: _kvToMap(_headers),
        params: _kvToMap(_params),
        body: _bodyCtrl.text.isNotEmpty ? _bodyCtrl.text : null,
        auth: _auth,
      );
      setSt(() => snippetText = proxy.snippet);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          if (snippetText.isEmpty) loadSnippet(setSt);
          return DraggableScrollableSheet(
            initialChildSize: 0.65,
            maxChildSize: 0.9,
            builder: (_, ctrl) => Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                      height: 4,
                      width: 40,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2))),
                  const Text('Code Snippet',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                          label: const Text('curl'),
                          selected: snippetType == 'curl',
                          onSelected: (_) {
                            setSt(() => snippetType = 'curl');
                            loadSnippet(setSt);
                          }),
                      ChoiceChip(
                          label: const Text('JS fetch'),
                          selected: snippetType == 'fetch',
                          onSelected: (_) {
                            setSt(() => snippetType = 'fetch');
                            loadSnippet(setSt);
                          }),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1e1e2e),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          children: [
                            SingleChildScrollView(
                              controller: ctrl,
                              child: SelectableText(snippetText,
                                  style: const TextStyle(
                                      fontFamily: 'monospace',
                                      color: Colors.greenAccent,
                                      fontSize: 13,
                                      height: 1.6)),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.copy,
                                    color: Colors.white70, size: 18),
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: snippetText));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Copied!'),
                                          duration: Duration(seconds: 1)));
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final proxy = context.watch<ProxyService>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ImageIcon(
              const AssetImage("assets/logo/logoApp_rm.png"),
              size: 60,
              color: Colors.orange[700],
            ),
            const Text('APIForge',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.doc_fill),
            tooltip: 'Save Request',
            onPressed: _saveRequest,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: IconButton(
              icon: const Icon(CupertinoIcons.arrow_right_arrow_left),
              tooltip: 'Code Snippets',
              onPressed: _showSnippets,
            ),
          ),
        ],
      ),
      drawer: const SidebarDrawer(),
      body: Column(
        children: [
          // ── URL Bar ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: Row(
              children: [
                // Method dropdown
                Container(
                  decoration: BoxDecoration(
                    color:
                        AppTheme.methodColor(_method).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.methodColor(_method)
                            .withValues(alpha: 0.3)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _method,
                      items: _methods
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m,
                                    style: TextStyle(
                                        color: AppTheme.methodColor(m),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _method = v!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // URL field
                Expanded(
                  child: TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Enter URL or use {{ENV_VAR}}',
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                    onSubmitted: (_) => _sendRequest(),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: proxy.isSending ? null : _sendRequest,
                      icon: proxy.isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(CupertinoIcons.paperplane_fill, size: 18),
                      label: Text(proxy.isSending ? 'Sending...' : 'Send',style: GoogleFonts.roboto(),),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Request Tabs ──────────────────────────────────────────────────
          Container(
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: TabBar(
              controller: _requestTabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                _badgeTab('Params', _kvToMap(_params).length),
                _badgeTab('Headers', _kvToMap(_headers).length),
                const Tab(text: 'Body'),
                const Tab(text: 'Auth'),
                const Tab(text: 'Snippets'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Tab content + Response (expandable split)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                if (isWide) {
                  // Side-by-side on wide screens (desktop)
                  return Row(
                    children: [
                      Expanded(child: _buildRequestTabContent()),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildResponsePanel(proxy)),
                    ],
                  );
                }
                // Stacked on narrow screens (web mobile)
                return Column(
                  children: [
                    Flexible(flex: 2, child: _buildRequestTabContent()),
                    const Divider(height: 1),
                    if (proxy.lastResult != null)
                      Flexible(flex: 3, child: _buildResponsePanel(proxy)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: const TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestTabContent() {
    return TabBarView(
      controller: _requestTabCtrl,
      children: [
        // Params tab
        _KVEditor(
          entries: _params,
          keyHint: 'param',
          valueHint: 'value',
          onChanged: (entries) => setState(() => _params = entries),
        ),
        // Headers tab
        _KVEditor(
          entries: _headers,
          keyHint: 'Header-Name',
          valueHint: 'value',
          onChanged: (entries) => setState(() => _headers = entries),
        ),
        // Body tab
        _BodyEditor(
          bodyType: _bodyType,
          controller: _bodyCtrl,
          onTypeChanged: (t) => setState(() => _bodyType = t),
        ),
        // Auth tab
        _AuthEditor(
          auth: _auth,
          onChanged: (a) => setState(() => _auth = a),
        ),
        // Snippets tab (inline)
        _InlineSnippetView(
          method: _method,
          url: _urlCtrl.text,
          headers: _kvToMap(_headers),
          params: _kvToMap(_params),
          body: _bodyCtrl.text.isNotEmpty ? _bodyCtrl.text : null,
          auth: _auth,
        ),
      ],
    );
  }

  Widget _buildResponsePanel(ProxyService proxy) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: proxy.lastResult != null
          ? ResponseViewer(
              statusCode: proxy.lastResult!.statusCode,
              statusText: proxy.lastResult!.statusText,
              body: proxy.lastResult!.body,
              headers: proxy.lastResult!.headers,
              responseTime: proxy.lastResult!.responseTime,
              isError: proxy.lastResult!.isError,
              errorMessage: proxy.lastResult!.errorMessage,
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 60),
                  Icon(CupertinoIcons.paperplane_fill,
                      size: 56,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3)),
                  const SizedBox(height: 14),
                  const Text('Send a request to see the response',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            ),
    );
  }
}

// ── Key-Value Entry ───────────────────────────────────────────────────────────
class _KVEntry {
  String key;
  String value;
  bool enabled;
  _KVEntry({this.key = '', this.value = '', this.enabled = true});
}

class _KVEditor extends StatefulWidget {
  final List<_KVEntry> entries;
  final String keyHint;
  final String valueHint;
  final ValueChanged<List<_KVEntry>> onChanged;

  const _KVEditor(
      {required this.entries,
      required this.keyHint,
      required this.valueHint,
      required this.onChanged});

  @override
  State<_KVEditor> createState() => _KVEditorState();
}

class _KVEditorState extends State<_KVEditor> {
  late List<_KVEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = List.from(widget.entries);
  }

  void _notify() => widget.onChanged(List.from(_entries));

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _entries.length,
            itemBuilder: (_, idx) {
              final e = _entries[idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Checkbox(
                        value: e.enabled,
                        onChanged: (v) {
                          setState(() => e.enabled = v!);
                          _notify();
                        }),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                            hintText: widget.keyHint, isDense: true),
                        style: const TextStyle(fontSize: 13),
                        onChanged: (v) {
                          e.key = v;
                          _notify();
                        },
                        controller: TextEditingController(text: e.key)
                          ..selection =
                              TextSelection.collapsed(offset: e.key.length),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                            hintText: widget.valueHint, isDense: true),
                        style: const TextStyle(fontSize: 13),
                        onChanged: (v) {
                          e.value = v;
                          _notify();
                        },
                        controller: TextEditingController(text: e.value)
                          ..selection =
                              TextSelection.collapsed(offset: e.value.length),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () {
                        setState(() => _entries.removeAt(idx));
                        _notify();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add'),
            onPressed: () {
              setState(() => _entries.add(_KVEntry()));
              _notify();
            },
          ),
        ),
      ],
    );
  }
}

// ── Body Editor ───────────────────────────────────────────────────────────────
class _BodyEditor extends StatelessWidget {
  final String bodyType;
  final TextEditingController controller;
  final ValueChanged<String> onTypeChanged;

  const _BodyEditor(
      {required this.bodyType,
      required this.controller,
      required this.onTypeChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Wrap(
            spacing: 8,
            children: ['none', 'json', 'form-data', 'raw'].map((t) {
              return ChoiceChip(
                label: Text(t),
                selected: bodyType == t,
                onSelected: (_) => onTypeChanged(t),
              );
            }).toList(),
          ),
        ),
        if (bodyType != 'none')
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: InputDecoration(
                  hintText: bodyType == 'json'
                      ? '{"key": "value"}'
                      : 'Enter request body...',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Auth Editor ───────────────────────────────────────────────────────────────
class _AuthEditor extends StatelessWidget {
  final AuthConfig auth;
  final ValueChanged<AuthConfig> onChanged;

  const _AuthEditor({required this.auth, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            children: ['none', 'bearer', 'basic'].map((t) {
              return ChoiceChip(
                label: Text(t == 'bearer'
                    ? 'Bearer Token'
                    : t == 'basic'
                        ? 'Basic Auth'
                        : 'None'),
                selected: auth.type == t,
                onSelected: (_) => onChanged(auth.copyWith(type: t)),
              );
            }).toList(),
          ),
        ),
        if (auth.type == 'bearer')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Bearer Token',
                prefixText: 'Bearer ',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
              onChanged: (v) => onChanged(auth.copyWith(token: v)),
              controller: TextEditingController(text: auth.token)
                ..selection =
                    TextSelection.collapsed(offset: auth.token.length),
            ),
          ),
        if (auth.type == 'basic') ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(CupertinoIcons.person)),
              onChanged: (v) => onChanged(auth.copyWith(username: v)),
              controller: TextEditingController(text: auth.username)
                ..selection =
                    TextSelection.collapsed(offset: auth.username.length),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: 'Password', prefixIcon: Icon(CupertinoIcons.lock)),
              onChanged: (v) => onChanged(auth.copyWith(password: v)),
              controller: TextEditingController(text: auth.password)
                ..selection =
                    TextSelection.collapsed(offset: auth.password.length),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Inline Snippet View ───────────────────────────────────────────────────────
class _InlineSnippetView extends StatefulWidget {
  final String method;
  final String url;
  final Map<String, String> headers;
  final Map<String, String> params;
  final String? body;
  final AuthConfig auth;

  const _InlineSnippetView({
    required this.method,
    required this.url,
    required this.headers,
    required this.params,
    this.body,
    required this.auth,
  });

  @override
  State<_InlineSnippetView> createState() => _InlineSnippetViewState();
}

class _InlineSnippetViewState extends State<_InlineSnippetView> {
  String _type = 'curl';
  bool _loading = false;
  String _snippet = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final proxy = context.read<ProxyService>();
    await proxy.fetchSnippet(
      type: _type,
      method: widget.method,
      url: widget.url,
      headers: widget.headers,
      params: widget.params,
      body: widget.body,
      auth: widget.auth,
    );
    if (mounted) {
      setState(() {
        _snippet = proxy.snippet;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Wrap(
              spacing: 8,
              children: ['curl', 'fetch']
                  .map((t) => ChoiceChip(
                        label: Text(t == 'fetch' ? 'JS fetch' : 'curl'),
                        selected: _type == t,
                        onSelected: (_) {
                          setState(() => _type = t);
                          _load();
                        },
                      ))
                  .toList()),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1e1e2e),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(children: [
                      SingleChildScrollView(
                        child: SelectableText(_snippet,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                color: Colors.greenAccent,
                                fontSize: 13,
                                height: 1.6)),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.copy,
                              color: Colors.white70, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _snippet));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Copied!'),
                                    duration: Duration(seconds: 1)));
                          },
                        ),
                      ),
                    ]),
                  ),
                ),
        ),
      ],
    );
  }
}
