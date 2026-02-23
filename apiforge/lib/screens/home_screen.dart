import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/proxy_service.dart';
import '../services/collection_service.dart';
import '../services/request_service.dart';
import '../services/history_service.dart';
import '../services/auth_service.dart';
import '../models/request_model.dart';
import '../models/history_model.dart';
import '../utils/storage_utils.dart';
import '../widgets/response_viewer.dart';
import '../screens/ai_assistant_screen.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF090B10);
  static const surface = Color(0xFF0F1117);
  static const surface2 = Color(0xFF141720);
  static const surface3 = Color(0xFF1A1E2A);
  static const border = Color(0xFF1C2030);
  static const border2 = Color(0xFF242840);
  static const accent = Color(0xFF5B6EF8);
  static const accent2 = Color(0xFF7C8BFF);
  static const accentGlow = Color(0x2D5B6EF8);
  static const text = Color(0xFFE8EAF6);
  static const muted = Color(0xFF5A5F7A);
  static const muted2 = Color(0xFF343750);
  static const green = Color(0xFF22D3A0);
  static const orange = Color(0xFFF5A623);
  static const red = Color(0xFFF45F7B);
  static const blue = Color(0xFF7EC8F7);
  static const purple = Color(0xFFA78BFA);

  static Color method(String m) {
    switch (m.toUpperCase()) {
      case 'GET':
        return green;
      case 'POST':
        return orange;
      case 'PUT':
        return blue;
      case 'PATCH':
        return purple;
      case 'DELETE':
        return red;
      default:
        return muted;
    }
  }

  static Color methodBg(String m) => method(m).withOpacity(0.12);
}

class _T {
  static const mono = TextStyle(fontFamily: 'IBMPlexMono');
  static const display = TextStyle(fontFamily: 'Syne');
  static TextStyle label({
    double size = 10,
    double spacing = 1.2,
    Color? color,
    FontWeight weight = FontWeight.w700,
  }) =>
      TextStyle(
        fontFamily: 'Syne',
        fontSize: size,
        letterSpacing: spacing,
        color: color ?? _C.muted,
        fontWeight: weight,
      );
}

// ── KV Entry ──────────────────────────────────────────────────────────────────
class _KVEntry {
  String key;
  String value;
  String description;
  bool enabled;
  _KVEntry(
      {this.key = '',
      this.value = '',
      this.description = '',
      this.enabled = true});
}

// ── Responsive helpers ────────────────────────────────────────────────────────
double _sidebarW(BuildContext ctx) {
  final w = MediaQuery.of(ctx).size.width;
  if (w < 900) return 180;
  return 240;
}

double _responseW(BuildContext ctx) {
  final w = MediaQuery.of(ctx).size.width;
  if (w < 900) return 0;
  if (w < 1100) return 320;
  return 400;
}

bool _isNarrow(BuildContext ctx) => MediaQuery.of(ctx).size.width < 900;

// ── Main Screen ───────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _navIndex = 0;
  String _method = 'GET';
  final _urlCtrl = TextEditingController(text: 'https://api.forge.ai/v1/users');
  List<_KVEntry> _params = [_KVEntry()];
  List<_KVEntry> _headers = [_KVEntry()];
  AuthConfig _auth = const AuthConfig();
  String _bodyType = 'none';
  final _bodyCtrl = TextEditingController();
  String? _activeCollectionId;
  String? _activeRequestId;
  String _filterText = '';
  final _filterCtrl = TextEditingController();
  Map<String, String> _envVars = {};
  final _envKeyCtrl = TextEditingController();
  final _envValCtrl = TextEditingController();
  late TabController _requestTabCtrl;
  bool _showResponsePanel = false;

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
    _requestTabCtrl = TabController(length: 6, vsync: this);
    _envVars = StorageUtils.getEnvVariables();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CollectionService>().fetchCollections();
      context.read<HistoryService>().fetchHistory();
    });
  }

  @override
  void dispose() {
    _requestTabCtrl.dispose();
    _urlCtrl.dispose();
    _bodyCtrl.dispose();
    _filterCtrl.dispose();
    _envKeyCtrl.dispose();
    _envValCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _kvToMap(List<_KVEntry> entries) {
    final m = <String, String>{};
    for (final e in entries) {
      if (e.key.isNotEmpty && e.enabled) m[e.key] = e.value;
    }
    return m;
  }

  void _handleAiRequest(Map<String, dynamic> aiReq) {
    setState(() {
      if (aiReq['method'] != null) {
        final m = aiReq['method'].toString().toUpperCase();
        if (_methods.contains(m)) _method = m;
      }
      if (aiReq['url'] != null) _urlCtrl.text = aiReq['url'].toString();
      if (aiReq['headers'] is Map) {
        _headers = (aiReq['headers'] as Map)
            .entries
            .map((e) =>
                _KVEntry(key: e.key.toString(), value: e.value.toString()))
            .toList();
        if (_headers.isEmpty) _headers.add(_KVEntry());
      }
      if (aiReq['params'] is Map) {
        _params = (aiReq['params'] as Map)
            .entries
            .map((e) =>
                _KVEntry(key: e.key.toString(), value: e.value.toString()))
            .toList();
        if (_params.isEmpty) _params.add(_KVEntry());
      }
      if (aiReq['body'] != null) {
        _bodyType = 'json';
        try {
          _bodyCtrl.text =
              const JsonEncoder.withIndent('  ').convert(aiReq['body']);
        } catch (_) {
          _bodyCtrl.text = aiReq['body'].toString();
        }
      } else {
        _bodyType = 'none';
        _bodyCtrl.clear();
      }
      _navIndex = 0;
    });
  }

  Future<void> _sendRequest() async {
    final proxy = context.read<ProxyService>();
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
      envVars: _envVars,
    );
    if (mounted) {
      context.read<HistoryService>().fetchHistory();
      setState(() => _showResponsePanel = true);
    }
  }

  void _loadRequest(RequestModel req) {
    setState(() {
      _activeRequestId = req.id;
      _method = req.method;
      _urlCtrl.text = req.url;
      _headers = req.headers.entries
          .map((e) => _KVEntry(key: e.key, value: e.value))
          .toList();
      _params = req.params.entries
          .map((e) => _KVEntry(key: e.key, value: e.value))
          .toList();
      if (_headers.isEmpty) _headers.add(_KVEntry());
      if (_params.isEmpty) _params.add(_KVEntry());
      if (req.body != null) {
        _bodyType = req.bodyType;
        if (_bodyType == 'json') {
          try {
            _bodyCtrl.text =
                const JsonEncoder.withIndent('  ').convert(req.body);
          } catch (_) {
            _bodyCtrl.text = req.body.toString();
          }
        } else {
          _bodyCtrl.text = req.body.toString();
        }
      } else {
        _bodyType = 'none';
        _bodyCtrl.clear();
      }
      _auth = req.auth;
      _navIndex = 0;
    });
  }

  // ── Save Request dialog ────────────────────────────────────────────────────
  Future<void> _saveRequest() async {
    final collections = context.read<CollectionService>().collections;
    String? selectedId = _activeCollectionId;
    final nameCtrl = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _CompactDialog(
        title: 'Save Request',
        icon: Icons.bookmark_add_outlined,
        confirmLabel: 'Save',
        confirmIcon: Icons.save_outlined,
        onConfirm: () async {
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
            collectionId: selectedId,
          ));
          if (ctx.mounted) Navigator.pop(ctx);
          if (mounted) {
            context.read<CollectionService>().fetchCollections();
            _snack('✓ Request saved');
          }
        },
        children: [
          _FTextField(
              controller: nameCtrl,
              label: 'Name',
              hint: '$_method ${_urlCtrl.text}'),
          if (collections.isNotEmpty) ...[
            const SizedBox(height: 12),
            _FDropdown<String>(
              label: 'Collection',
              value: selectedId,
              items: collections
                  .map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name,
                          style:
                              _T.mono.copyWith(fontSize: 13, color: _C.text))))
                  .toList(),
              onChanged: (v) => selectedId = v,
            ),
          ],
        ],
      ),
    );
  }

  // ── Create Collection dialog ───────────────────────────────────────────────
  Future<void> _createCollection() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String pickedColor = '#5B6EF8';
    const swatches = [
      '#5B6EF8',
      '#22D3A0',
      '#F5A623',
      '#F45F7B',
      '#7EC8F7',
      '#A78BFA'
    ];
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
          builder: (ctx, ss) => _CompactDialog(
                title: 'New Collection',
                icon: Icons.create_new_folder_outlined,
                confirmLabel: 'Create',
                confirmIcon: Icons.add,
                onConfirm: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  await context.read<CollectionService>().createCollection(
                        nameCtrl.text.trim(),
                        descCtrl.text.trim(),
                        pickedColor,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _snack('✓ Collection created');
                },
                children: [
                  _FTextField(
                      controller: nameCtrl,
                      label: 'Collection Name',
                      hint: 'My API'),
                  const SizedBox(height: 12),
                  _FTextField(
                      controller: descCtrl,
                      label: 'Description',
                      hint: 'Optional'),
                  const SizedBox(height: 12),
                  Text('Color', style: _T.label(size: 11)),
                  const SizedBox(height: 8),
                  Wrap(
                      spacing: 8,
                      children: swatches.map((hex) {
                        final col =
                            Color(int.parse(hex.replaceFirst('#', '0xFF')));
                        final sel = pickedColor == hex;
                        return GestureDetector(
                          onTap: () => ss(() => pickedColor = hex),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: col,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color:
                                      sel ? Colors.white : Colors.transparent,
                                  width: 2),
                              boxShadow: sel
                                  ? [
                                      BoxShadow(
                                          color: col.withOpacity(0.5),
                                          blurRadius: 6)
                                    ]
                                  : null,
                            ),
                            child: sel
                                ? const Icon(Icons.check,
                                    size: 13, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList()),
                ],
              )),
    );
  }

  void _loadHistoryEntry(HistoryModel h) {
    setState(() {
      _method = h.method;
      _urlCtrl.text = h.url;
      _headers = [_KVEntry()];
      _params = [_KVEntry()];
      _bodyType = 'none';
      _bodyCtrl.clear();
      _navIndex = 0;
    });
    context.read<ProxyService>().setResult(ProxyResult(
          statusCode: h.statusCode ?? 0,
          statusText: h.isError ? 'Error' : 'OK',
          body: h.responseBody,
          headers: h.responseHeaders,
          responseTime: h.responseTime,
          isError: h.isError,
          errorMessage: h.errorMessage,
        ));
    setState(() => _showResponsePanel = true);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: _T.mono.copyWith(fontSize: 13, color: _C.text)),
      backgroundColor: _C.surface3,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _C.border2)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  String get _breadcrumb {
    final cols = context.read<CollectionService>().collections;
    if (_activeCollectionId != null) {
      final col = cols.where((c) => c.id == _activeCollectionId);
      if (col.isNotEmpty) {
        final req = col.first.requests.where((r) => r.id == _activeRequestId);
        if (req.isNotEmpty) return '${col.first.name}  ›  ${req.first.name}';
        return 'Workspace  ›  ${col.first.name}';
      }
    }
    return 'My Workspace';
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final proxy = context.watch<ProxyService>();
    final narrow = _isNarrow(context);
    final rw = _responseW(context);

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(children: [
          _TopBar(breadcrumb: _breadcrumb, narrow: narrow),
          Expanded(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Left nav
              _LeftNav(
                  index: _navIndex,
                  onTap: (i) => setState(() => _navIndex = i)),
              // AI assistant full screen
              if (_navIndex == 3)
                Expanded(child: AiAssistantScreen(
                  onLoadInEditor: (req) {
                    _handleAiRequest(req);
                  },
                ))
              else
                // Main 3-column layout
                Expanded(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      // Sidebar
                      SizedBox(
                        width: _sidebarW(context),
                        child: _buildSidePanel(),
                      ),
                      // Editor column
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            _UrlBar(
                              method: _method,
                              methods: _methods,
                              urlCtrl: _urlCtrl,
                              isSending: proxy.isSending,
                              onMethodChanged: (m) =>
                                  setState(() => _method = m),
                              onSend: _sendRequest,
                              onSave: _saveRequest,
                              narrow: narrow,
                              showResp: _showResponsePanel &&
                                  proxy.lastResult != null,
                              onToggleResp: () => setState(() =>
                                  _showResponsePanel = !_showResponsePanel),
                            ),
                            _ReqTabs(
                                ctrl: _requestTabCtrl,
                                headerCount: _kvToMap(_headers).length),
                            Expanded(child: _buildTabContent()),
                          ])),
                      // Response panel
                      if (rw > 0 ||
                          (narrow &&
                              _showResponsePanel &&
                              proxy.lastResult != null))
                        _ResponsePanel(
                          proxy: proxy,
                          width: narrow
                              ? MediaQuery.of(context).size.width * 0.5
                              : rw,
                          onSave: _saveRequest,
                        ),
                    ])),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildSidePanel() {
    switch (_navIndex) {
      case 1:
        return _ColListPanel(
          onCreate: _createCollection,
          onSelect: (id) => setState(() {
            _activeCollectionId = id;
            _navIndex = 0;
          }),
        );
      case 2:
        return _HistPanel(onLoad: _loadHistoryEntry);
      case 4:
        return _SettPanel(
          vars: _envVars,
          kCtrl: _envKeyCtrl,
          vCtrl: _envValCtrl,
          onAdd: (k, v) async {
            setState(() => _envVars[k] = v);
            await StorageUtils.setEnvVariables(_envVars);
          },
          onRm: (k) async {
            setState(() => _envVars.remove(k));
            await StorageUtils.setEnvVariables(_envVars);
          },
        );
      default:
        return _ColTreePanel(
          activeColId: _activeCollectionId,
          activeReqId: _activeRequestId,
          filterCtrl: _filterCtrl,
          filterText: _filterText,
          onFilter: (v) => setState(() => _filterText = v),
          onCreate: _createCollection,
          onSelectCol: (id) => setState(() => _activeCollectionId = id),
          onLoadReq: (req, cId) {
            _activeCollectionId = cId;
            _loadRequest(req);
          },
          onSaveCurrent: _saveRequest,
        );
    }
  }

  Widget _buildTabContent() {
    return TabBarView(controller: _requestTabCtrl, children: [
      // Params
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
            child: _KVEditor(
                entries: _params,
                onChanged: (e) => setState(() => _params = e))),
        _AiCard(
            onAdd: () => setState(() => _params.insert(_params.length - 1,
                _KVEntry(key: 'sort_by', value: 'created_at')))),
        const SizedBox(height: 10),
      ]),
      // Auth
      SingleChildScrollView(
          child: _AuthEdit(
              auth: _auth, onChanged: (a) => setState(() => _auth = a))),
      // Headers
      _KVEditor(
          entries: _headers, onChanged: (e) => setState(() => _headers = e)),
      // Body
      _BodyEdit(
          type: _bodyType,
          ctrl: _bodyCtrl,
          onType: (t) => setState(() => _bodyType = t)),
      // Pre-request
      _SnippetView(
        method: _method,
        url: _urlCtrl.text,
        headers: _kvToMap(_headers),
        params: _kvToMap(_params),
        body: _bodyCtrl.text.isNotEmpty ? _bodyCtrl.text : null,
        auth: _auth,
      ),
      // Tests
      Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                color: _C.surface2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.border2)),
            child:
                const Icon(Icons.science_outlined, color: _C.muted, size: 23)),
        const SizedBox(height: 12),
        Text('Use the AI ✦ tab for test generation',
            style: _T.mono.copyWith(color: _C.muted, fontSize: 12.5)),
      ])),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSE PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _ResponsePanel extends StatelessWidget {
  final ProxyService proxy;
  final double width;
  final VoidCallback onSave;
  const _ResponsePanel(
      {required this.proxy, required this.width, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        decoration: const BoxDecoration(
            color: _C.surface,
            border: Border(left: BorderSide(color: _C.border))),
        child: proxy.lastResult == null
            ? Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                            color: _C.surface2,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _C.border2)),
                        child: const Icon(Icons.send_outlined,
                            color: _C.muted, size: 25)),
                    const SizedBox(height: 14),
                    Text('Send a request',
                        style: _T.display.copyWith(
                            color: _C.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Text('Response appears here',
                        style: _T.mono.copyWith(color: _C.muted, fontSize: 12)),
                  ]))
            : Column(children: [
                Expanded(
                    child: ResponseViewer(
                  statusCode: proxy.lastResult!.statusCode,
                  statusText: proxy.lastResult!.statusText,
                  body: proxy.lastResult!.body,
                  headers: proxy.lastResult!.headers,
                  responseTime: proxy.lastResult!.responseTime,
                  isError: proxy.lastResult!.isError,
                  errorMessage: proxy.lastResult!.errorMessage,
                )),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: _FOutlineBtn(
                      onPressed: onSave,
                      icon: Icons.download_outlined,
                      label: 'Save as Example'),
                ),
              ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String breadcrumb;
  final bool narrow;
  const _TopBar({required this.breadcrumb, required this.narrow});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
          color: _C.bg, border: Border(bottom: BorderSide(color: _C.border))),
      child: Row(children: [
        Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
                color: _C.accent,
                borderRadius: BorderRadius.circular(7),
                boxShadow: const [
                  BoxShadow(
                      color: _C.accentGlow, blurRadius: 10, spreadRadius: 1)
                ]),
            child:  const ImageIcon(AssetImage('assets/logo/logoApp_rm.png'), color: Colors.white, size: 22)),
        const SizedBox(width: 8),
        if (!narrow) ...[
          Text('APIForge',
              style: _T.display.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: _C.text,
                  letterSpacing: -0.3)),
          Container(
              width: 1,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: _C.border2),
        ],
        Expanded(
            child: Text(breadcrumb,
                style: _T.mono.copyWith(color: _C.muted, fontSize: 11.5),
                overflow: TextOverflow.ellipsis)),
        // Env badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: _C.border2)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _C.green,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(color: _C.green.withOpacity(0.4), blurRadius: 4)
                  ],
                )),
            const SizedBox(width: 6),
            if (!narrow)
              Text('Production',
                  style: _T.display.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _C.text)),
            const Icon(Icons.expand_more, size: 13, color: _C.muted),
          ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => showMenu(
              context: context,
              position: const RelativeRect.fromLTRB(1000, 48, 0, 0),
              items: [
                PopupMenuItem(
                    onTap: () => context.read<AuthService>().logout(),
                    child: const Text('Logout'))
              ]),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_C.accent, _C.purple]),
                borderRadius: BorderRadius.circular(14)),
            child: Center(
                child: Text(
              auth.user?.name.isNotEmpty == true
                  ? auth.user!.name[0].toUpperCase()
                  : 'U',
              style: _T.display.copyWith(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            )),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEFT NAV
// ─────────────────────────────────────────────────────────────────────────────
class _LeftNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _LeftNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          color: _C.bg, border: Border(right: BorderSide(color: _C.border))),
      child: Column(children: [
        _NBtn(
            icon: Icons.home_outlined,
            active: Icons.home,
            i: 0,
            cur: index,
            onTap: onTap),
        const SizedBox(height: 2),
        _NBtn(
            icon: Icons.folder_outlined,
            active: Icons.folder,
            i: 1,
            cur: index,
            onTap: onTap),
        const SizedBox(height: 2),
        _NBtn(
            icon: Icons.history_outlined,
            active: Icons.history,
            i: 2,
            cur: index,
            onTap: onTap),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(height: 1, width: 24, color: _C.border)),
        _NBtn(
            icon: Icons.auto_awesome_outlined,
            active: Icons.auto_awesome,
            i: 3,
            cur: index,
            onTap: onTap,
            col: _C.purple),
        const Spacer(),
        _NBtn(
            icon: Icons.settings_outlined,
            active: Icons.settings,
            i: 4,
            cur: index,
            onTap: onTap),
      ]),
    );
  }
}

class _NBtn extends StatelessWidget {
  final IconData icon, active;
  final int i, cur;
  final ValueChanged<int> onTap;
  final Color? col;
  const _NBtn(
      {required this.icon,
      required this.active,
      required this.i,
      required this.cur,
      required this.onTap,
      this.col});

  @override
  Widget build(BuildContext context) {
    final on = i == cur;
    return SizedBox(
      width: 50,
      height: 40,
      child: Stack(alignment: Alignment.center, children: [
        if (on)
          Positioned(
              left: 0,
              top: 7,
              bottom: 7,
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  color: _C.accent,
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(2)),
                  boxShadow: [
                    BoxShadow(color: _C.accent.withOpacity(0.5), blurRadius: 4)
                  ],
                ),
              )),
        Tooltip(
          message: [
            'Home',
            'Collections',
            'History',
            'AI Assistant',
            'Settings'
          ][i],
          child: InkWell(
            onTap: () => onTap(i),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: on ? _C.surface2 : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: on ? Border.all(color: _C.border2) : null,
              ),
              child: Icon(on ? active : icon,
                  size: 18,
                  color: on ? (col ?? _C.accent2) : (col ?? _C.muted)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COLLECTION TREE PANEL  (Home sidebar)
// ─────────────────────────────────────────────────────────────────────────────
class _ColTreePanel extends StatelessWidget {
  final String? activeColId, activeReqId;
  final TextEditingController filterCtrl;
  final String filterText;
  final ValueChanged<String> onFilter;
  final VoidCallback onCreate, onSaveCurrent;
  final ValueChanged<String> onSelectCol;
  final void Function(RequestModel, String) onLoadReq;
  const _ColTreePanel({
    required this.activeColId,
    required this.activeReqId,
    required this.filterCtrl,
    required this.filterText,
    required this.onFilter,
    required this.onCreate,
    required this.onSelectCol,
    required this.onLoadReq,
    required this.onSaveCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final cols = context.watch<CollectionService>().collections;
    final list = filterText.isEmpty
        ? cols
        : cols
            .where((c) =>
                c.name.toLowerCase().contains(filterText.toLowerCase()) ||
                c.requests.any((r) =>
                    r.name.toLowerCase().contains(filterText.toLowerCase())))
            .toList();

    return Container(
      decoration: const BoxDecoration(
          color: _C.surface,
          border: Border(right: BorderSide(color: _C.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _C.border))),
          child: Row(children: [
            Expanded(child: Text('COLLECTIONS', style: _T.label(size: 10.5))),
            Tooltip(
                message: 'Save current request',
                child: _IBtn(
                    icon: Icons.bookmark_add_outlined, onTap: onSaveCurrent)),
            const SizedBox(width: 5),
            Tooltip(
                message: 'New collection',
                child: _IBtn(
                    icon: Icons.create_new_folder_outlined, onTap: onCreate)),
          ]),
        ),
        // Tree
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const Icon(Icons.folder_open_outlined,
                          size: 32, color: _C.muted2),
                      const SizedBox(height: 10),
                      Text('No collections',
                          style:
                              _T.mono.copyWith(color: _C.muted, fontSize: 12)),
                      const SizedBox(height: 7),
                      GestureDetector(
                          onTap: onCreate,
                          child: Text('+ Create one',
                              style: _T.mono
                                  .copyWith(color: _C.accent, fontSize: 12))),
                    ]))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    Color fc;
                    try {
                      fc = Color(int.parse(c.color.replaceFirst('#', '0xFF')));
                    } catch (_) {
                      fc = _C.orange;
                    }
                    return Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                        minTileHeight: 36,
                        leading:
                            Icon(Icons.folder_rounded, color: fc, size: 15),
                        title: Text(c.name,
                            style: _T.display.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _C.text),
                            overflow: TextOverflow.ellipsis),
                        trailing: _IBtn(
                            icon: Icons.delete_outline,
                            onTap: () => context
                                .read<CollectionService>()
                                .deleteCollection(c.id)),
                        initiallyExpanded: c.id == activeColId,
                        onExpansionChanged: (exp) {
                          if (exp) onSelectCol(c.id);
                        },
                        children: c.requests.isEmpty
                            ? [
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: Text('No saved requests',
                                        style: _T.mono.copyWith(
                                            color: _C.muted2, fontSize: 11)))
                              ]
                            : c.requests.map((req) {
                                final on = req.id == activeReqId;
                                final mc = _C.method(req.method);
                                final label = req.method.length > 3
                                    ? req.method.substring(0, 3)
                                    : req.method;
                                return InkWell(
                                  onTap: () => onLoadReq(req, c.id),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 120),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: on
                                          ? _C.accentGlow
                                          : Colors.transparent,
                                      border: Border(
                                          left: BorderSide(
                                              color: on
                                                  ? _C.accent
                                                  : Colors.transparent,
                                              width: 2)),
                                    ),
                                    child: Row(children: [
                                      const SizedBox(width: 14),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: _C.methodBg(req.method),
                                            borderRadius:
                                                BorderRadius.circular(3)),
                                        child: Text(label.toUpperCase(),
                                            style: _T.mono.copyWith(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: mc)),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                          child: Text(req.name,
                                              style: _T.mono.copyWith(
                                                  fontSize: 11.5,
                                                  color:
                                                      on ? _C.text : _C.muted,
                                                  fontWeight: on
                                                      ? FontWeight.w500
                                                      : FontWeight.normal),
                                              overflow: TextOverflow.ellipsis)),
                                    ]),
                                  ),
                                );
                              }).toList(),
                      ),
                    );
                  },
                ),
        ),
        // Filter
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _C.border))),
          child: TextField(
            controller: filterCtrl,
            onChanged: onFilter,
            style: _T.mono.copyWith(fontSize: 12, color: _C.text),
            decoration: InputDecoration(
              hintText: 'Filter…',
              hintStyle: _T.mono.copyWith(color: _C.muted2, fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 14, color: _C.muted),
              isDense: true,
              filled: true,
              fillColor: _C.surface2,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _C.border2)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _C.border2)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _C.accent)),
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COLLECTION LIST PANEL  (nav index 1)
// ─────────────────────────────────────────────────────────────────────────────
class _ColListPanel extends StatelessWidget {
  final VoidCallback onCreate;
  final ValueChanged<String> onSelect;
  const _ColListPanel({required this.onCreate, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<CollectionService>();
    return Container(
      decoration: const BoxDecoration(
          color: _C.surface,
          border: Border(right: BorderSide(color: _C.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _C.border))),
          child: Row(children: [
            Expanded(
                child: Text('ALL COLLECTIONS', style: _T.label(size: 10.5))),
            _IBtn(icon: Icons.add, onTap: onCreate),
          ]),
        ),
        Expanded(
          child: svc.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _C.accent))
              : svc.collections.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          const Icon(Icons.folder_open_outlined,
                              size: 32, color: _C.muted2),
                          const SizedBox(height: 10),
                          Text('No collections',
                              style: _T.mono
                                  .copyWith(color: _C.muted, fontSize: 12)),
                          const SizedBox(height: 7),
                          GestureDetector(
                              onTap: onCreate,
                              child: Text('+ Create one',
                                  style: _T.mono.copyWith(
                                      color: _C.accent, fontSize: 12))),
                        ]))
                  : ListView.builder(
                      padding: const EdgeInsets.all(6),
                      itemCount: svc.collections.length,
                      itemBuilder: (_, i) {
                        final c = svc.collections[i];
                        Color col;
                        try {
                          col = Color(
                              int.parse(c.color.replaceFirst('#', '0xFF')));
                        } catch (_) {
                          col = _C.accent;
                        }
                        return InkWell(
                          onTap: () => onSelect(c.id),
                          borderRadius: BorderRadius.circular(7),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 8),
                            child: Row(children: [
                              Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                      color: col.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(7)),
                                  child: Icon(Icons.folder_rounded,
                                      color: col, size: 14)),
                              const SizedBox(width: 9),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(c.name,
                                        style: _T.display.copyWith(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: _C.text),
                                        overflow: TextOverflow.ellipsis),
                                    Text('${c.requests.length} req',
                                        style: _T.mono.copyWith(
                                            fontSize: 10.5, color: _C.muted)),
                                  ])),
                              _IBtn(
                                  icon: Icons.delete_outline,
                                  onTap: () => svc.deleteCollection(c.id)),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _HistPanel extends StatelessWidget {
  final ValueChanged<HistoryModel> onLoad;
  const _HistPanel({required this.onLoad});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<HistoryService>();
    return Container(
      decoration: const BoxDecoration(
          color: _C.surface,
          border: Border(right: BorderSide(color: _C.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _C.border))),
          child: Row(children: [
            Expanded(child: Text('HISTORY', style: _T.label(size: 10.5))),
            if (svc.history.isNotEmpty)
              _IBtn(icon: Icons.delete_sweep_outlined, onTap: svc.clearHistory),
          ]),
        ),
        Expanded(
          child: svc.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _C.accent))
              : svc.history.isEmpty
                  ? Center(
                      child: Text('No history',
                          style:
                              _T.mono.copyWith(color: _C.muted, fontSize: 12)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(5),
                      itemCount: svc.history.length,
                      itemBuilder: (_, i) {
                        final h = svc.history[i];
                        final mc = _C.method(h.method);
                        return InkWell(
                          onTap: () => onLoad(h),
                          borderRadius: BorderRadius.circular(5),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 7),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                    color: mc.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(3)),
                                child: Text(h.method,
                                    style: _T.mono.copyWith(
                                        color: mc,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 9)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(h.url,
                                      style: _T.mono.copyWith(
                                          fontSize: 11, color: _C.muted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                              if (h.statusCode != null)
                                Text('${h.statusCode}',
                                    style: _T.mono.copyWith(
                                        fontSize: 10,
                                        color:
                                            AppTheme.statusColor(h.statusCode!),
                                        fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _SettPanel extends StatelessWidget {
  final Map<String, String> vars;
  final TextEditingController kCtrl, vCtrl;
  final void Function(String, String) onAdd;
  final ValueChanged<String> onRm;
  const _SettPanel(
      {required this.vars,
      required this.kCtrl,
      required this.vCtrl,
      required this.onAdd,
      required this.onRm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: _C.surface,
          border: Border(right: BorderSide(color: _C.border))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _C.border))),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text('ENV VARIABLES', style: _T.label(size: 10.5))),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _FTextField(controller: kCtrl, label: 'Variable', hint: 'BASE_URL'),
            const SizedBox(height: 8),
            _FTextField(
                controller: vCtrl,
                label: 'Value',
                hint: 'https://api.example.com'),
            const SizedBox(height: 10),
            SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: () async {
                    if (kCtrl.text.trim().isEmpty) return;
                    onAdd(kCtrl.text.trim(), vCtrl.text.trim());
                    kCtrl.clear();
                    vCtrl.clear();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7)),
                    elevation: 0,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text('Add',
                      style: _T.mono.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                )),
          ]),
        ),
        const Divider(color: _C.border, height: 1),
        Expanded(
          child: vars.isEmpty
              ? Center(
                  child: Text('No variables',
                      style: _T.mono.copyWith(color: _C.muted, fontSize: 12)))
              : ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  children: vars.entries
                      .map((e) => Container(
                            margin: const EdgeInsets.only(bottom: 5),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                                color: _C.surface2,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: _C.border)),
                            child: Row(children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text('{{${e.key}}}',
                                        style: _T.mono.copyWith(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _C.accent2)),
                                    Text(e.value,
                                        style: _T.mono.copyWith(
                                            fontSize: 10, color: _C.muted)),
                                  ])),
                              _IBtn(
                                  icon: Icons.close, onTap: () => onRm(e.key)),
                            ]),
                          ))
                      .toList(),
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// URL BAR
// ─────────────────────────────────────────────────────────────────────────────
class _UrlBar extends StatelessWidget {
  final String method;
  final List<String> methods;
  final TextEditingController urlCtrl;
  final bool isSending, narrow, showResp;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback onSend, onSave, onToggleResp;
  const _UrlBar({
    required this.method,
    required this.methods,
    required this.urlCtrl,
    required this.isSending,
    required this.onMethodChanged,
    required this.onSend,
    required this.onSave,
    required this.narrow,
    required this.showResp,
    required this.onToggleResp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
          color: _C.surface,
          border: Border(bottom: BorderSide(color: _C.border))),
      child: Row(children: [
        // Method + URL field
        Expanded(
            child: Container(
          height: 40,
          decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.border2)),
          child: Row(children: [
            Container(
              decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: _C.border2))),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: method,
                  dropdownColor: _C.surface2,
                  icon:
                      const Icon(Icons.expand_more, size: 13, color: _C.muted),
                  items: methods
                      .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m,
                              style: _T.mono.copyWith(
                                  color: _C.method(m),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12))))
                      .toList(),
                  onChanged: (v) => onMethodChanged(v!),
                ),
              ),
            ),
            Expanded(
                child: TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                hintText: 'Enter URL…',
                hintStyle: _T.mono.copyWith(color: _C.muted2, fontSize: 12.5),
                border: InputBorder.none,
                filled: true,
                fillColor: AppColors.darkSurface,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              style: _T.mono.copyWith(fontSize: 13, color: _C.text),
              onSubmitted: (_) => onSend(),
            )),
          ]),
        )),
        const SizedBox(width: 7),
        // Send
        SizedBox(
          height: 40,
          child: ElevatedButton.icon(
            onPressed: isSending ? null : onSend,
            icon: isSending
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 13),
            label: Text(narrow ? '' : 'Send',
                style: _T.display.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: narrow ? 11 : 16),
            ),
          ),
        ),
        const SizedBox(width: 5),
        // Save
        SizedBox(
          height: 40,
          width: 38,
          child: OutlinedButton(
            onPressed: onSave,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _C.border2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: EdgeInsets.zero,
            ),
            child:
                const Icon(Icons.bookmark_outline, size: 16, color: _C.muted),
          ),
        ),
        // Toggle response (narrow only)
        if (narrow) ...[
          const SizedBox(width: 5),
          SizedBox(
            height: 40,
            width: 38,
            child: OutlinedButton(
              onPressed: onToggleResp,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: showResp ? _C.accent : _C.border2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                backgroundColor: showResp ? _C.accentGlow : null,
                padding: EdgeInsets.zero,
              ),
              child: Icon(Icons.terminal,
                  size: 16, color: showResp ? _C.accent2 : _C.muted),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REQUEST TABS
// ─────────────────────────────────────────────────────────────────────────────
class _ReqTabs extends StatelessWidget {
  final TabController ctrl;
  final int headerCount;
  const _ReqTabs({required this.ctrl, required this.headerCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: _C.surface,
          border: Border(bottom: BorderSide(color: _C.border))),
      child: TabBar(
        controller: ctrl,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: _C.accent,
        indicatorWeight: 2,
        labelStyle:
            _T.mono.copyWith(fontWeight: FontWeight.w500, fontSize: 12.5),
        unselectedLabelStyle: _T.mono.copyWith(fontSize: 12.5),
        labelColor: _C.accent2,
        unselectedLabelColor: _C.muted,
        dividerColor: Colors.transparent,
        tabs: [
          const Tab(text: 'Params'),
          const Tab(text: 'Auth'),
          Tab(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Headers'),
            if (headerCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                    color: _C.accent, borderRadius: BorderRadius.circular(3)),
                child: Text('$headerCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ])),
          const Tab(text: 'Body'),
          const Tab(text: 'Pre-request'),
          const Tab(text: 'Tests'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI CARD
// ─────────────────────────────────────────────────────────────────────────────
class _AiCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _AiCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_C.accent.withOpacity(0.06), _C.purple.withOpacity(0.03)]),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _C.accent.withOpacity(0.22)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
                color: _C.accentGlow, borderRadius: BorderRadius.circular(7)),
            child: const Icon(Icons.auto_awesome, color: _C.accent2, size: 13)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AI SUGGESTION',
              style: _T.label(color: _C.accent2, spacing: 0.8, size: 10)),
          const SizedBox(height: 5),
          RichText(
              text: TextSpan(
            style: _T.mono.copyWith(color: _C.muted, fontSize: 12, height: 1.5),
            children: const [
              TextSpan(text: 'You often use '),
              TextSpan(
                  text: 'sort_by=created_at',
                  style: TextStyle(
                      color: _C.text, backgroundColor: Color(0xFF1A1E2A))),
              TextSpan(text: ' when fetching. Add it?'),
            ],
          )),
          const SizedBox(height: 8),
          SizedBox(
            height: 27,
            child: ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                elevation: 0,
              ),
              child: Text('Add Parameter',
                  style: _T.mono.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KV EDITOR
// ─────────────────────────────────────────────────────────────────────────────
class _KVEditor extends StatefulWidget {
  final List<_KVEntry> entries;
  final ValueChanged<List<_KVEntry>> onChanged;
  const _KVEditor({super.key, required this.entries, required this.onChanged});
  @override
  State<_KVEditor> createState() => _KVEditorState();
}

class _KVEditorState extends State<_KVEditor> {
  late List<_KVEntry> _rows;
  @override
  void initState() {
    super.initState();
    _rows = List.from(widget.entries);
  }

  void _notify() => widget.onChanged(List.from(_rows));

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      decoration: BoxDecoration(
          border: Border.all(color: _C.border),
          borderRadius: BorderRadius.circular(8),
          color: _C.surface),
      child: Column(children: [
        // Header
        Container(
          decoration: const BoxDecoration(
              color: _C.surface2,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: _C.border))),
          child: Row(children: [
            const SizedBox(width: 36),
            _kH('Key', 3),
            _vDiv(),
            _kH('Value', 3),
            _vDiv(),
            _kH('Description', 4),
            const SizedBox(width: 32),
          ]),
        ),
        // Rows
        Expanded(
            child: ListView.builder(
          itemCount: _rows.length,
          itemBuilder: (_, idx) {
            final e = _rows[idx];
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: e.enabled ? 1.0 : 0.4,
              child: Container(
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: _C.border.withOpacity(0.4)))),
                child: Row(children: [
                  SizedBox(
                      width: 36,
                      child: Center(
                          child: Checkbox(
                        value: e.enabled,
                        activeColor: _C.accent,
                        side: const BorderSide(color: _C.muted2),
                        onChanged: (v) {
                          setState(() => e.enabled = v!);
                          _notify();
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))),
                  Expanded(
                      flex: 3,
                      child: _fld(
                        e.key,
                        'Key',
                        (v) {
                          e.key = v;
                          _notify();
                        },
                      )),
                  _vDiv(),
                  Expanded(
                      flex: 3,
                      child: _fld(e.value, 'Value', (v) {
                        e.value = v;
                        _notify();
                      })),
                  _vDiv(),
                  Expanded(
                      flex: 4,
                      child: _fld(e.description, 'Description', (v) {
                        e.description = v;
                        _notify();
                      }, sec: true)),
                  SizedBox(
                      width: 32,
                      child: IconButton(
                        icon:
                            const Icon(Icons.close, size: 12, color: _C.muted2),
                        onPressed: () {
                          setState(() => _rows.removeAt(idx));
                          _notify();
                        },
                        padding: EdgeInsets.zero,
                      )),
                ]),
              ),
            );
          },
        )),
        // Add row
        InkWell(
          onTap: () {
            setState(() => _rows.add(_KVEntry()));
            _notify();
          },
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add, size: 12, color: _C.accent),
              const SizedBox(width: 4),
              Text('Add Row',
                  style: _T.mono.copyWith(
                      color: _C.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _kH(String t, int flex) => Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Text(t, style: _T.label(size: 10)),
      ));

  Widget _vDiv() =>
      Container(width: 1, height: 38, color: _C.border.withOpacity(0.4));

  Widget _fld(String val, String hint, ValueChanged<String> cb,
          {bool sec = false}) =>
      TextField(
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: _C.muted2.withOpacity(0.5),
              fontSize: sec ? 11 : 12,
              fontFamily: 'IBMPlexMono'),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          isDense: true,
        ),
        style: TextStyle(
            fontSize: sec ? 11 : 12,
            fontFamily: 'IBMPlexMono',
            color: sec ? _C.muted : _C.bg),
        onChanged: cb,
        controller: TextEditingController(text: val)
          ..selection = TextSelection.collapsed(offset: val.length),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY EDITOR
// ─────────────────────────────────────────────────────────────────────────────
class _BodyEdit extends StatelessWidget {
  final String type;
  final TextEditingController ctrl;
  final ValueChanged<String> onType;
  const _BodyEdit(
      {required this.type, required this.ctrl, required this.onType});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
        child: Wrap(
            spacing: 6,
            children: ['none', 'json', 'form-data', 'raw'].map((t) {
              final on = type == t;
              return GestureDetector(
                onTap: () => onType(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: on ? _C.accentGlow : _C.surface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: on ? _C.accent : _C.border2),
                  ),
                  child: Text(t,
                      style: _T.mono.copyWith(
                          fontSize: 12,
                          color: on ? _C.accent2 : _C.muted,
                          fontWeight:
                              on ? FontWeight.w600 : FontWeight.normal)),
                ),
              );
            }).toList()),
      ),
      if (type != 'none')
        Expanded(
            child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          decoration: BoxDecoration(
              color: _C.surface,
              border: Border.all(color: _C.border2),
              borderRadius: BorderRadius.circular(8)),
          child: TextField(
            controller: ctrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: _T.mono.copyWith(
                fontFamily: 'IBMPlexMono',
                fontSize: 13,
                height: 1.6,
                color: _C.muted2),
            decoration: InputDecoration(
              hintText:
                  type == 'json' ? '{\n  "key": "value"\n}' : 'Enter body…',
              hintStyle: _T.mono.copyWith(color: _C.muted2, fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(11),
            ),
          ),
        )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH EDITOR
// ─────────────────────────────────────────────────────────────────────────────
class _AuthEdit extends StatelessWidget {
  final AuthConfig auth;
  final ValueChanged<AuthConfig> onChanged;
  const _AuthEdit({required this.auth, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 7, children: [
          for (final t in ['none', 'bearer', 'basic'])
            GestureDetector(
              onTap: () => onChanged(auth.copyWith(type: t)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: auth.type == t ? _C.accentGlow : _C.surface2,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                      color: auth.type == t ? _C.accent : _C.border2),
                ),
                child: Text(
                    t == 'bearer'
                        ? 'Bearer Token'
                        : t == 'basic'
                            ? 'Basic Auth'
                            : 'None',
                    style: _T.mono.copyWith(
                        fontSize: 12,
                        color: auth.type == t ? _C.accent2 : _C.muted,
                        fontWeight: auth.type == t
                            ? FontWeight.w600
                            : FontWeight.normal)),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        if (auth.type == 'bearer')
          _FTextField(
              label: 'Bearer Token',
              onChanged: (v) => onChanged(auth.copyWith(token: v)),
              prefix: const Icon(Icons.vpn_key_outlined,
                  size: 15, color: _C.muted)),
        if (auth.type == 'basic') ...[
          _FTextField(
              label: 'Username',
              onChanged: (v) => onChanged(auth.copyWith(username: v)),
              prefix:
                  const Icon(CupertinoIcons.person, size: 15, color: _C.muted)),
          const SizedBox(height: 10),
          _FTextField(
              label: 'Password',
              obscure: true,
              onChanged: (v) => onChanged(auth.copyWith(password: v)),
              prefix:
                  const Icon(CupertinoIcons.lock, size: 15, color: _C.muted)),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SNIPPET VIEW
// ─────────────────────────────────────────────────────────────────────────────
class _SnippetView extends StatefulWidget {
  final String method, url;
  final Map<String, String> headers, params;
  final String? body;
  final AuthConfig auth;
  const _SnippetView(
      {required this.method,
      required this.url,
      required this.headers,
      required this.params,
      this.body,
      required this.auth});
  @override
  State<_SnippetView> createState() => _SnippetViewState();
}

class _SnippetViewState extends State<_SnippetView> {
  String _type = 'curl';
  bool _loading = false;
  String _snippet = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final proxy = context.read<ProxyService>();
    await proxy.fetchSnippet(
        type: _type,
        method: widget.method,
        url: widget.url,
        headers: widget.headers,
        params: widget.params,
        body: widget.body,
        auth: widget.auth);
    if (mounted) {
      setState(() {
        _snippet = proxy.snippet;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
        child: Wrap(
            spacing: 6,
            children: ['curl', 'fetch'].map((t) {
              final on = _type == t;
              return GestureDetector(
                onTap: () {
                  setState(() => _type = t);
                  _load();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: on ? _C.accentGlow : _C.surface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: on ? _C.accent : _C.border2),
                  ),
                  child: Text(t == 'fetch' ? 'JS fetch' : 'cURL',
                      style: _T.mono.copyWith(
                          fontSize: 12,
                          color: on ? _C.accent2 : _C.muted,
                          fontWeight:
                              on ? FontWeight.w600 : FontWeight.normal)),
                ),
              );
            }).toList()),
      ),
      Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _C.accent))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                        color: const Color(0xFF0D0F16),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: _C.border2)),
                    child: Stack(children: [
                      SingleChildScrollView(
                          child: SelectableText(_snippet,
                              style: _T.mono.copyWith(
                                  fontFamily: 'IBMPlexMono',
                                  color: const Color(0xFFA8FF95),
                                  fontSize: 13,
                                  height: 1.7))),
                      Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.copy_outlined,
                                color: _C.muted, size: 14),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _snippet));
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Copied!'),
                                      duration: Duration(seconds: 1)));
                            },
                          )),
                    ]),
                  ),
                )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Small icon button
class _IBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
                color: _C.surface2,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: _C.border2)),
            child: Icon(icon, size: 12, color: _C.muted)),
      );
}

/// Forge text field
class _FTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint, initialValue;
  final ValueChanged<String>? onChanged;
  final bool obscure;
  final Widget? prefix;

  const _FTextField({
    this.controller,
    required this.label,
    this.hint,
    this.initialValue,
    this.onChanged,
    this.obscure = false,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      style: _T.mono.copyWith(fontSize: 13, color: _C.text),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: _T.mono.copyWith(color: _C.muted, fontSize: 11),
        hintStyle: _T.mono.copyWith(color: _C.muted2, fontSize: 12),
        prefixIcon: prefix,

        // ✅ Dark background, no white fill
        filled: true,
        fillColor: _C.surface2,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _C.border2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _C.border2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _C.accent, width: 1.5),
        ),

        contentPadding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        isDense: true,
      ),
    );
  }
}

/// Forge dropdown
class _FDropdown<T> extends StatefulWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _FDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<_FDropdown<T>> createState() => _FDropdownState<T>();
}

class _FDropdownState<T> extends State<_FDropdown<T>> {
  late T? _v;

  @override
  void initState() {
    super.initState();
    _v = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: _v,
      dropdownColor: _C.surface2,
      style: _T.mono.copyWith(fontSize: 13, color: _C.text),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: _T.mono.copyWith(color: _C.muted, fontSize: 11),

        // ✅ Dark background, no white fill
        filled: true,
        fillColor: _C.surface2,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _C.border2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _C.border2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _C.accent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        isDense: true,
      ),
      items: widget.items,
      onChanged: (v) {
        setState(() => _v = v);
        widget.onChanged(v);
      },
    );
  }
}

/// Outline button
class _FOutlineBtn extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  const _FOutlineBtn(
      {required this.onPressed, required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 35,
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 13),
          label: Text(label, style: _T.mono.copyWith(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: _C.muted,
            side: const BorderSide(color: _C.border2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPACT DIALOG  — smaller, no overflow
// ─────────────────────────────────────────────────────────────────────────────
class _CompactDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final String confirmLabel;
  final IconData confirmIcon;
  final VoidCallback onConfirm;
  const _CompactDialog({
    required this.title,
    required this.icon,
    required this.children,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _C.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: const BorderSide(color: _C.border2)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title row
                Row(children: [
                  Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                          color: _C.accentGlow,
                          borderRadius: BorderRadius.circular(7)),
                      child: Icon(icon, color: _C.accent2, size: 14)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(title,
                          style: _T.display.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _C.text))),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(5),
                    child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 16, color: _C.muted)),
                  ),
                ]),
                const SizedBox(height: 16),
                // Scrollable content
                Flexible(
                    child: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: children))),
                const SizedBox(height: 16),
                // Actions
                Row(children: [
                  Expanded(
                      child: SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: _C.muted,
                          side: const BorderSide(color: _C.border2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7))),
                      child: Text('Cancel',
                          style: _T.mono.copyWith(fontSize: 12.5)),
                    ),
                  )),
                  const SizedBox(width: 9),
                  Expanded(
                      child: SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: onConfirm,
                      icon: Icon(confirmIcon, size: 13),
                      label: Text(confirmLabel,
                          style: _T.mono.copyWith(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _C.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7)),
                          elevation: 0),
                    ),
                  )),
                ]),
              ]),
        ),
      ),
    );
  }
}
