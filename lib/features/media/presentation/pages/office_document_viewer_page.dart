import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../../../../core/theme/app_theme.dart';
import '../widgets/save_to_device_button.dart';

/// Read-only local Office preview. Document parsing runs in a background
/// isolate so large ZIP/XML work never blocks the Telegram feed's UI thread.
/// Complex Word layouts/charts/macros are not executed or reproduced.
class OfficeDocumentViewerPage extends StatefulWidget {
  const OfficeDocumentViewerPage({
    required this.path,
    required this.fileName,
    super.key,
  });

  final String path;
  final String fileName;

  @override
  State<OfficeDocumentViewerPage> createState() =>
      _OfficeDocumentViewerPageState();
}

class _OfficeDocumentViewerPageState extends State<OfficeDocumentViewerPage> {
  late final bool _word;
  late final Future<Object> _content;

  @override
  void initState() {
    super.initState();
    _word = widget.fileName.toLowerCase().endsWith('.docx');
    _content = _word
        ? compute(decodeDocxForPreview, widget.path)
        : compute(decodeXlsxForPreview, widget.path);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.fileName,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            SaveToDeviceButton(
              localPath: widget.path,
              fileName: widget.fileName,
            ),
          ],
        ),
        body: FutureBuilder<Object>(
          future: _content,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('پیش‌نمایش سند ممکن نیست:\n${snapshot.error}',
                      textAlign: TextAlign.center),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_word) {
              return _WordContent(text: snapshot.data! as String);
            }
            return _WorkbookContent(
              sheets: snapshot.data! as Map<String, List<List<String>>>,
            );
          },
        ),
      );
}

class _WordContent extends StatelessWidget {
  const _WordContent({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.primary.withValues(alpha: 0.08),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Text(
                text.isEmpty ? 'این سند متن قابل نمایش ندارد.' : text,
                style: AppTypography.newsBody.copyWith(
                  fontSize: 18,
                  height: 1.7,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'پیش‌نمایش فقط‌خواندنی متن؛ چیدمان‌های پیچیده Word ممکن است متفاوت باشند.',
              style: AppTypography.secondary.copyWith(fontSize: 12),
            ),
          ],
        ),
      );
}

class _WorkbookContent extends StatelessWidget {
  const _WorkbookContent({required this.sheets});
  final Map<String, List<List<String>>> sheets;

  @override
  Widget build(BuildContext context) {
    if (sheets.isEmpty) {
      return const Center(child: Text('هیچ برگه قابل نمایشی پیدا نشد.'));
    }
    final entries = sheets.entries.toList();
    return DefaultTabController(
      length: entries.length,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final entry in entries) Tab(text: entry.key)],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final entry in entries)
                  _SheetTable(key: ValueKey(entry.key), rows: entry.value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetTable extends StatelessWidget {
  const _SheetTable({required this.rows, super.key});
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Center(child: Text('این برگه خالی است.'));
    final columnCount = rows.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    ).clamp(1, 32);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            'پیش‌نمایش ${rows.length} ردیف (حداکثر ۵۰۰) و $columnCount ستون (حداکثر ۳۲)',
            style: AppTypography.secondary.copyWith(fontSize: 12),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: columnCount * 156.0 + 54,
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: index.isEven
                          ? Colors.white
                          : const Color(0xFFF1F6FC),
                      border: const Border(
                        bottom: BorderSide(color: AppPalette.outline),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 54,
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: AppTypography.secondary.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        for (var col = 0; col < columnCount; col++)
                          Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            width: 156,
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: AppPalette.outline),
                              ),
                            ),
                            child: Text(
                              col < row.length ? row[col] : '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.ui.copyWith(fontSize: 12),
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Text-only DOCX reader. The original file is never modified.
Future<String> decodeDocxForPreview(String path) async {
  final input = File(path);
  if (await input.length() > 16 * 1024 * 1024) {
    throw const FormatException('فایل Word برای پیش‌نمایش بسیار بزرگ است.');
  }
  final zip = ZipDecoder().decodeBytes(await input.readAsBytes());
  final document = zip.findFile('word/document.xml');
  if (document == null) {
    throw const FormatException('این فایل Word معتبر نیست.');
  }
  final data = document.content as List<int>;
  final xml = XmlDocument.parse(utf8.decode(data));
  final paragraphs = <String>[];
  for (final paragraph in xml.findAllElements('w:p').take(3000)) {
    final value = paragraph
        .findAllElements('w:t')
        .map((node) => node.innerText)
        .join();
    if (value.trim().isNotEmpty) paragraphs.add(value);
  }
  return paragraphs.join('\n\n');
}

/// Extracts the first 500 rows and 32 columns per sheet for smooth preview.
Future<Map<String, List<List<String>>>> decodeXlsxForPreview(String path) async {
  final input = File(path);
  if (await input.length() > 16 * 1024 * 1024) {
    throw const FormatException('فایل Excel برای پیش‌نمایش بسیار بزرگ است.');
  }
  final workbook = Excel.decodeBytes(await input.readAsBytes());
  final result = <String, List<List<String>>>{};
  for (final entry in workbook.tables.entries) {
    final rows = <List<String>>[];
    for (final row in entry.value.rows.take(500)) {
      rows.add([
        for (final cell in row.take(32)) _valueToString(cell?.value),
      ]);
    }
    result[entry.key] = rows;
  }
  return result;
}

String _valueToString(CellValue? cell) {
  return switch (cell) {
    null => '',
    TextCellValue() => '${cell.value}',
    IntCellValue() => '${cell.value}',
    DoubleCellValue() => '${cell.value}',
    BoolCellValue() => cell.value ? 'TRUE' : 'FALSE',
    FormulaCellValue() => '=${cell.formula}',
    DateCellValue() => '${cell.asDateTimeLocal()}',
    TimeCellValue() => '${cell.asDuration()}',
    DateTimeCellValue() => '${cell.asDateTimeLocal()}',
  };
}
