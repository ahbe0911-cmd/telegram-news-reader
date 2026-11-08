import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telegram_news_reader/features/media/presentation/pages/office_document_viewer_page.dart';

void main() {
  test('a DOCX file renders Persian paragraphs internally', () async {
    final dir = await Directory.systemTemp.createTemp('telepulse_docx_test_');
    try {
      final wordXml = utf8.encode(
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body><w:p><w:r><w:t>خبر آزمایشی</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>متن دوم</w:t></w:r></w:p></w:body></w:document>',
      );
      final archive = Archive()
        ..addFile(ArchiveFile('word/document.xml', wordXml.length, wordXml));
      final bytes = ZipEncoder().encode(archive)!;
      final path = '${dir.path}/article.docx';
      await File(path).writeAsBytes(bytes);
      final text = await decodeDocxForPreview(path);
      expect(text, contains('خبر آزمایشی'));
      expect(text, contains('متن دوم'));
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('an XLSX file previews actual cell values by sheet', () async {
    final dir = await Directory.systemTemp.createTemp('telepulse_xlsx_test_');
    try {
      final workbook = Excel.createExcel();
      workbook['Sheet1']
          .cell(CellIndex.indexByString('A1'))
          .value = TextCellValue('Market');
      workbook['Sheet1']
          .cell(CellIndex.indexByString('B1'))
          .value = IntCellValue(1405);
      final bytes = workbook.save();
      expect(bytes, isNotNull);
      final path = '${dir.path}/market.xlsx';
      await File(path).writeAsBytes(bytes!);
      final pages = await decodeXlsxForPreview(path);
      expect(pages['Sheet1'], isNotNull);
      expect(pages['Sheet1']!.first.take(2).toList(), ['Market', '1405']);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
