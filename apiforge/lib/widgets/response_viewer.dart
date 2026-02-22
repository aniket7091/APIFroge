import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../theme/app_theme.dart';

/// Renders an HTTP response: status badge, formatted JSON body, headers, response time.
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

class _ResponseViewerState extends State<ResponseViewer> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() => _selectedTab = _tabCtrl.index));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.isError
        ? AppColors.statusError
        : AppTheme.statusColor(widget.statusCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: statusColor.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.isError ? 'ERR' : '${widget.statusCode}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.isError ? widget.errorMessage : widget.statusText,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              const Icon(Icons.timer_outlined, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${widget.responseTime} ms',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 14),
              const Icon(Icons.data_usage_outlined, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(_sizeLabel(),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),

        if (widget.isError && widget.errorMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.errorMessage, style: const TextStyle(color: Colors.red, fontSize: 13))),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          TabBar(
            controller: _tabCtrl,
            tabs: [
              Tab(text: 'Body (${_contentType()})'),
              Tab(text: 'Headers (${widget.headers.length})'),
            ],
          ),
          const SizedBox(height: 12),
          if (_selectedTab == 0) _buildBody(),
          if (_selectedTab == 1) _buildHeaders(),
        ],
      ],
    );
  }

  Widget _buildBody() {
    final pretty = _prettyBody();
    if (pretty.isEmpty) {
      return const Center(child: Text('Empty response body', style: TextStyle(color: AppColors.textSecondary)));
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: pretty));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied!'), duration: Duration(seconds: 1)),
                  );
                },
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          SelectableText(
            pretty,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaders() {
    if (widget.headers.isEmpty) {
      return const Center(child: Text('No headers', style: TextStyle(color: AppColors.textSecondary)));
    }
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.headers.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, idx) {
          final key = widget.headers.keys.elementAt(idx);
          final val = widget.headers[key].toString();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 180,
                  child: Text(key,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'monospace')),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(val, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
              ],
            ),
          );
        },
      ),
    );
  }

  String _contentType() {
    final ct = widget.headers['content-type']?.toString() ?? widget.headers['Content-Type']?.toString() ?? '';
    if (ct.contains('json')) return 'JSON';
    if (ct.contains('html')) return 'HTML';
    if (ct.contains('xml')) return 'XML';
    if (ct.contains('text')) return 'Text';
    return 'Data';
  }

  String _sizeLabel() {
    final raw = const JsonEncoder().convert(widget.body);
    final bytes = raw.length;
    if (bytes < 1024) return '${bytes}B';
    return '${(bytes / 1024).toStringAsFixed(1)}KB';
  }
}
