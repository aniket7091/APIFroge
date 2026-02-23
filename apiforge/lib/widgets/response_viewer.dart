import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../theme/app_theme.dart';

/// Renders an HTTP response: status badge, formatted JSON body, headers, cookies.
/// Matches the Postman-style layout with line numbers, format selector,
/// Body / Cookies / Headers tabs, and JSON / Pretty / Raw / Preview sub-formats.
class ResponseViewer extends StatefulWidget {
  final int statusCode;
  final String statusText;
  final dynamic body;
  final Map<String, dynamic> headers;
  final int responseTime;
  final bool isError;
  final String errorMessage;

  const ResponseViewer({
    super.key,
    required this.statusCode,
    required this.statusText,
    this.body,
    this.headers = const {},
    this.responseTime = 0,
    this.isError = false,
    this.errorMessage = '',
  });

  @override
  State<ResponseViewer> createState() => _ResponseViewerState();
}

class _ResponseViewerState extends State<ResponseViewer> {
  // Outer tab: 0 = Body, 1 = Cookies, 2 = Headers
  int _tab = 0;
  // Body sub-format: 'json', 'pretty', 'raw', 'preview'
  String _bodyFormat = 'json';
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _prettyBody() {
    if (widget.body == null) return '';
    if (widget.body is String) {
      try {
        final decoded = json.decode(widget.body as String);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        return widget.body as String;
      }
    }
    return const JsonEncoder.withIndent('  ').convert(widget.body);
  }

  String _rawBody() {
    if (widget.body == null) return '';
    if (widget.body is String) return widget.body as String;
    return json.encode(widget.body);
  }

  String _contentType() {
    final ct = widget.headers['content-type']?.toString() ??
        widget.headers['Content-Type']?.toString() ??
        '';
    if (ct.contains('json')) return 'JSON';
    if (ct.contains('html')) return 'HTML';
    if (ct.contains('xml')) return 'XML';
    if (ct.contains('text')) return 'Text';
    return 'Data';
  }

  String _sizeLabel() {
    try {
      final raw = json.encode(widget.body);
      final bytes = raw.length;
      if (bytes < 1024) return '${bytes}B';
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } catch (_) {
      return '—';
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.isError
        ? AppColors.statusError
        : AppTheme.statusColor(widget.statusCode);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkBg,
        border: Border(left: BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top toolbar ─────────────────────────────────────────────────────
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: AppColors.darkBg,
              border: Border(bottom: BorderSide(color: AppColors.darkBorder)),
            ),
            child: Row(
              children: [
                const Text('Response',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                if (widget.isError)
                  _statusBadge('Error', AppColors.statusError)
                else if (widget.statusCode > 0)
                  _statusBadge(
                      '${widget.statusCode} ${widget.statusText}', statusColor),
                const Spacer(),
                if (!widget.isError && widget.statusCode > 0) ...[
                  Text('${widget.responseTime}ms',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace')),
                  _vDivider(),
                  Text(_sizeLabel(),
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontFamily: 'monospace')),
                  _vDivider(),
                ],
                // Toolbar icons
                _toolbarIcon(Icons.copy_outlined, 'Copy', () {
                  Clipboard.setData(ClipboardData(text: _prettyBody()));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Copied!'),
                      duration: Duration(seconds: 1)));
                }),
                _toolbarIcon(Icons.search, 'Search', () {
                  setState(() => _showSearch = !_showSearch);
                }),
                _toolbarIcon(Icons.filter_list, 'Filter', null),
              ],
            ),
          ),

          // ── Search bar (hidden by default) ──────────────────────────────────
          if (_showSearch)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: AppColors.darkBorder))),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search in response…',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.darkSurface,
                  prefixIcon: const Icon(Icons.search,
                      size: 16, color: AppColors.textSecondary),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close,
                        size: 14, color: AppColors.textSecondary),
                    onPressed: () =>
                        setState(() {
                          _showSearch = false;
                          _searchQuery = '';
                          _searchCtrl.clear();
                        }),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),

          if (widget.isError && widget.errorMessage.isNotEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(widget.errorMessage,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 14),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // ── Outer tabs: Body | Cookies | Headers ─────────────────────────
            Container(
              decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: AppColors.darkBorder))),
              child: Row(
                children: [
                  _outerTab('Body', 0),
                  _outerTab('Cookies', 1),
                  _outerTab('Headers (${widget.headers.length})', 2),
                ],
              ),
            ),

            // ── Body sub-format row ───────────────────────────────────────────
            if (_tab == 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: AppColors.darkBorder))),
                child: Row(
                  children: [
                    _formatChip('JSON', 'json'),
                    const SizedBox(width: 2),
                    _formatChip('Pretty', 'pretty'),
                    const SizedBox(width: 2),
                    _formatChip('Raw', 'raw'),
                    const SizedBox(width: 2),
                    _formatChip('Preview', 'preview'),
                    const Spacer(),
                    Text(_contentType(),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontFamily: 'monospace')),
                  ],
                ),
              ),

            // ── Content ───────────────────────────────────────────────────────
            Expanded(
              child: Container(
                color: AppColors.darkSurface,
                width: double.infinity,
                child: _tab == 0
                    ? _buildBodyContent()
                    : _tab == 1
                        ? _buildCookiesContent()
                        : _buildHeadersContent(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tab widgets ───────────────────────────────────────────────────────────────

  Widget _outerTab(String label, int index) {
    final isActive = _tab == index;
    return InkWell(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive
                ? AppColors.accent
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _formatChip(String label, String value) {
    final isSelected = _bodyFormat == value;
    return InkWell(
      onTap: () => setState(() => _bodyFormat = value),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.w400,
            color:
                isSelected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12)),
    );
  }

  Widget _vDivider() {
    return Container(
        width: 1,
        height: 12,
        color: AppColors.darkBorder,
        margin: const EdgeInsets.symmetric(horizontal: 10));
  }

  Widget _toolbarIcon(
      IconData icon, String tooltip, VoidCallback? onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  // ── Content builders ──────────────────────────────────────────────────────────

  Widget _buildBodyContent() {
    final pretty = _prettyBody();
    final raw = _rawBody();

    if (pretty.isEmpty && raw.isEmpty) {
      return const Center(
          child: Text('Empty response body',
              style: TextStyle(color: AppColors.textSecondary)));
    }

    switch (_bodyFormat) {
      case 'raw':
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            raw,
            style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.6,
                color: AppColors.textPrimary),
          ),
        );
      case 'pretty':
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildColorizedJson(pretty),
        );
      case 'preview':
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(pretty,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary)),
          ),
        );
      default: // 'json' — colorized with line numbers
        return _buildLinedColorizedJson(pretty);
    }
  }

  Widget _buildLinedColorizedJson(String src) {
    final lines = src.split('\n');

    // Apply search filter highlight
    final filtered = _searchQuery.isEmpty
        ? lines
        : lines
            .where((l) =>
                l.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(filtered.length, (i) {
            final lineNum = _searchQuery.isEmpty
                ? i + 1
                : lines.indexOf(filtered[i]) + 1;
            return _JsonLine(
                lineNumber: lineNum, src: filtered[i]);
          }),
        ),
      ),
    );
  }

  Widget _buildCookiesContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cookie_outlined,
              size: 40, color: AppColors.darkBorder),
          SizedBox(height: 10),
          Text('No cookies',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          SizedBox(height: 4),
          Text('Cookies set by the response will appear here.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildHeadersContent() {
    if (widget.headers.isEmpty) {
      return const Center(
          child: Text('No headers',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: widget.headers.entries.map((entry) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
                border: Border(
                    bottom:
                        BorderSide(color: AppColors.darkBorder))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 180,
                  child: SelectableText(
                    entry.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Color(0xFFD078FF), // purple key
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    entry.value.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Color(0xFF4EC994), // green value
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── JSON colorizer ────────────────────────────────────────────────────────────

  Widget _buildColorizedJson(String src) {
    return SelectableText.rich(
      TextSpan(children: _tokenize(src)),
      style: const TextStyle(
          fontFamily: 'monospace', fontSize: 13, height: 1.6),
    );
  }

  List<TextSpan> _tokenize(String src) {
    const keyColor = Color(0xFFD078FF);
    const strColor = Color(0xFF4EC994);
    const numColor = Color(0xFF79B8FF);
    const boolColor = Color(0xFFFFAB70);
    const nullColor = Color(0xFFE06C75);
    const punctColor = Color(0xFFABB2BF);

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
      if (m.start > pos) {
        spans.add(TextSpan(
            text: src.substring(pos, m.start),
            style: const TextStyle(color: punctColor)));
      }
      pos = m.end;
      if (m.group(1) != null) {
        spans.add(TextSpan(
            text: m.group(0),
            style: const TextStyle(color: keyColor)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
            text: m.group(0),
            style: const TextStyle(color: strColor)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
            text: m.group(0),
            style: const TextStyle(color: numColor)));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(
            text: m.group(0),
            style: const TextStyle(color: boolColor)));
      } else if (m.group(5) != null) {
        spans.add(TextSpan(
            text: m.group(0),
            style: const TextStyle(color: nullColor)));
      } else if (m.group(6) != null) {
        spans.add(TextSpan(
            text: m.group(0),
            style: const TextStyle(color: punctColor)));
      } else {
        spans.add(TextSpan(text: m.group(0)));
      }
    }
    if (pos < src.length) {
      spans.add(TextSpan(
          text: src.substring(pos),
          style: const TextStyle(color: punctColor)));
    }
    return spans;
  }
}

// ── Single line with line-number gutter ───────────────────────────────────────

class _JsonLine extends StatelessWidget {
  final int lineNumber;
  final String src;

  const _JsonLine({required this.lineNumber, required this.src});

  @override
  Widget build(BuildContext context) {
    const keyColor = Color(0xFFD078FF);
    const strColor = Color(0xFF4EC994);
    const numColor = Color(0xFF79B8FF);
    const boolColor = Color(0xFFFFAB70);
    const nullColor = Color(0xFFE06C75);
    const punctColor = Color(0xFFABB2BF);

    final re = RegExp(
      r'"((?:[^"\\]|\\.)*)"\s*:'
      r'|"((?:[^"\\]|\\.)*)"'
      r'|(-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)'
      r'|(true|false)'
      r'|(null)'
      r'|([{}\[\],:])'
      r'|(\s+)',
    );

    final spans = <TextSpan>[];
    int pos = 0;
    for (final m in re.allMatches(src)) {
      if (m.start > pos) {
        spans.add(TextSpan(
            text: src.substring(pos, m.start),
            style: const TextStyle(color: punctColor)));
      }
      pos = m.end;
      if (m.group(1) != null) {
        spans.add(TextSpan(
            text: m.group(0),
            style: const TextStyle(color: keyColor)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
            text: m.group(0),
            style: const TextStyle(color: strColor)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
            text: m.group(0),
            style: const TextStyle(color: numColor)));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(
            text: m.group(0),
            style: const TextStyle(color: boolColor)));
      } else if (m.group(5) != null) {
        spans.add(TextSpan(
            text: m.group(0),
            style: const TextStyle(color: nullColor)));
      } else if (m.group(6) != null) {
        spans.add(TextSpan(
            text: m.group(0),
            style: const TextStyle(color: punctColor)));
      } else {
        spans.add(TextSpan(text: m.group(0)));
      }
    }
    if (pos < src.length) {
      spans.add(TextSpan(
          text: src.substring(pos),
          style: const TextStyle(color: punctColor)));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Line number gutter
        SizedBox(
          width: 44,
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '$lineNumber',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Color(0xFF4A5568),
                height: 1.6,
              ),
            ),
          ),
        ),
        // Gutter divider
        Container(
            width: 1,
            color: AppColors.darkBorder,
            margin: const EdgeInsets.only(right: 12)),
        // Code content
        Expanded(
          child: SelectableText.rich(
            TextSpan(children: spans),
            style: const TextStyle(
                fontFamily: 'monospace', fontSize: 12, height: 1.6),
          ),
        ),
      ],
    );
  }
}
