import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/excel_exporter.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_models.dart';
import 'package:ioe_app/features/masterdata/sucursales/sucursales_providers.dart';
import 'datart_models.dart';
import 'datart_providers.dart';
import '../punto_venta/cotizaciones/detalle_cot/jrq_models.dart';
import '../punto_venta/cotizaciones/detalle_cot/jrq_providers.dart';

class DatArtUiConfig {
  static const double fontSize = 11;
  static const EdgeInsets pagePadding = EdgeInsets.all(12);
  static const EdgeInsets cardPadding = EdgeInsets.all(12);
  static const double columnSpacing = 8;
  static const double detailPanelWidth = 520;
  static const double dataRowHeight = 28;
  static const double headingRowHeight = 28;
  static const double horizontalMargin = 8;

  static double get tableWidth {
    const columnCount = 10;
    final totalColumns =
        colSuc +
        colArt +
        colUpc +
        colDes +
        colTipo +
        colStock +
        colStockMin +
        colPvta +
        colCtop +
        colEstatus;
    return totalColumns +
        (columnSpacing * (columnCount - 1)) +
        (horizontalMargin * 2);
  }

  static const double colSuc = 30;
  static const double colArt = 50;
  static const double colUpc = 80;
  static const double colDes = 200;
  static const double colTipo = 50;
  static const double colStock = 60;
  static const double colStockMin = 60;
  static const double colPvta = 60;
  static const double colCtop = 60;
  static const double colEstatus = 110;
}

class DatArtPage extends ConsumerStatefulWidget {
  const DatArtPage({super.key});

  @override
  ConsumerState<DatArtPage> createState() => _DatArtPageState();
}

class _DatArtPageState extends ConsumerState<DatArtPage> {
  final _searchCtrl = TextEditingController();
  final _sphCtrl = TextEditingController();
  final _cylCtrl = TextEditingController();
  final _adicCtrl = TextEditingController();
  final ScrollController _horizontalScrollCtrl = ScrollController();

  String? _selectedSuc;
  String _searchBy = 'ART';
  double? _selectedDepa;
  double? _selectedSubd;
  double? _selectedClas;
  double? _selectedScla;
  double? _selectedScla2;

  static const int _limit = 50;
  int _page = 1;
  List<DatArtModel> _items = [];
  bool _loading = false;
  String? _error;
  bool _hasSearched = false;
  bool _hasMore = false;
  int _totalCount = 0;
  Timer? _debounce;
  static const Duration _debounceDuration = Duration(milliseconds: 450);
  DatArtModel? _detailItem;
  bool _detailLoading = false;
  String? _detailError;
  String? _selectedKey;
  bool _exporting = false;
  bool _uploadingMassive = false;
  bool _uploadingAltaMasiva = false;
  String? _massiveLoteId;

  static const List<String> _exportHeaders = [
    'SUC',
    'TIPO',
    'ART',
    'UPC',
    'CLAVESAT',
    'UNIMEDSAT',
    'DES',
    'STOCK',
    'STOCK_MIN',
    'ESTATUS',
    'DIA_REABASTO',
    'PVTA',
    'CTOP',
    'PROV_1',
    'CTO_PROV1',
    'PROV_2',
    'CTO_PROV2',
    'PROV_3',
    'CTO_PROV3',
    'UN_COMP',
    'FACT_COMP',
    'UN_VTA',
    'FACT_VTA',
    'BASE',
    'SPH',
    'CYL',
    'ADIC',
    'DEPA',
    'SUBD',
    'CLAS',
    'SCLA',
    'SCLA2',
    'UMUE',
    'UTRA',
    'UNIV',
    'UFRE',
    'BLOQ',
    'MARCA',
    'MODELO',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _sphCtrl.dispose();
    _cylCtrl.dispose();
    _adicCtrl.dispose();
    _horizontalScrollCtrl.dispose();
    super.dispose();
  }

  bool _hasSearchCriteria() {
    return _searchCtrl.text.trim().isNotEmpty ||
        _selectedDepa != null ||
        _selectedSubd != null ||
        _selectedClas != null ||
        _selectedScla != null ||
        _selectedScla2 != null ||
        _sphCtrl.text.trim().isNotEmpty ||
        _cylCtrl.text.trim().isNotEmpty ||
        _adicCtrl.text.trim().isNotEmpty;
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (!mounted) return;
      final loteId = (_massiveLoteId ?? '').trim();
      if ((_selectedSuc ?? '').trim().isEmpty && loteId.isEmpty) return;
      if (!_hasSearchCriteria() && loteId.isEmpty) return;
      _search(resetPage: true);
    });
  }

  double? _parseDouble(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _excelCellText(xls.Data? cell) {
    if (cell == null) return '';
    final value = cell.value;
    if (value == null) return '';
    return value.toString().trim();
  }

  _AltaMasivaPreview _buildAltaPreview(List<int> bytes) {
    try {
      final excel = xls.Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) {
        return const _AltaMasivaPreview(headers: [], rows: []);
      }
      final sheet = excel.tables.values.first;
      if (sheet.rows.isEmpty) {
        return const _AltaMasivaPreview(headers: [], rows: []);
      }

      final firstRow = sheet.rows.first;
      final headerValues = firstRow.map(_excelCellText).toList();
      final headerHasData = headerValues.any((h) => h.trim().isNotEmpty);
      final maxLen = sheet.rows.fold<int>(
        0,
        (prev, row) => row.length > prev ? row.length : prev,
      );

      final headers = headerHasData
          ? List.generate(
              headerValues.length,
              (i) => headerValues[i].trim().isEmpty
                  ? 'COL${i + 1}'
                  : headerValues[i].trim(),
            )
          : List.generate(maxLen, (i) => 'COL${i + 1}');

      final rows = <List<String>>[];
      final startIndex = headerHasData ? 1 : 0;
      for (var i = startIndex; i < sheet.rows.length; i += 1) {
        if (rows.length >= 8) break;
        final row = sheet.rows[i];
        final values = List.generate(
          headers.length,
          (idx) => idx < row.length ? _excelCellText(row[idx]) : '',
        );
        if (values.every((v) => v.trim().isEmpty)) continue;
        rows.add(values);
      }

      return _AltaMasivaPreview(headers: headers, rows: rows);
    } catch (_) {
      return const _AltaMasivaPreview(headers: [], rows: []);
    }
  }

  Map<String, String?> _resolveTermFilters(String term) {
    String? art;
    String? upc;
    String? des;
    if (term.isNotEmpty) {
      switch (_searchBy) {
        case 'ART':
          art = term;
          break;
        case 'UPC':
          upc = term;
          break;
        case 'DES':
          des = term;
          break;
      }
    }
    return {'art': art, 'upc': upc, 'des': des};
  }

  Future<void> _search({bool resetPage = false, String? forceLoteId}) async {
    final loteId = (forceLoteId ?? _massiveLoteId ?? '').trim();
    final useLoteFilter = loteId.isNotEmpty;
    final selectedSuc = (_selectedSuc ?? '').trim();
    if (selectedSuc.isEmpty && !useLoteFilter) {
      _showSnack('Selecciona una sucursal para buscar.');
      return;
    }

    final sph = _parseDouble(_sphCtrl.text);
    final cyl = _parseDouble(_cylCtrl.text);
    final adic = _parseDouble(_adicCtrl.text);

    bool invalidNumber(String raw, double? parsed) =>
        raw.trim().isNotEmpty && parsed == null;
    if (invalidNumber(_sphCtrl.text, sph) ||
        invalidNumber(_cylCtrl.text, cyl) ||
        invalidNumber(_adicCtrl.text, adic)) {
      _showSnack('Revisa los campos numéricos de filtros.');
      return;
    }

    final term = _searchCtrl.text.trim();
    final termFilters = _resolveTermFilters(term);
    final art = termFilters['art'];
    final upc = termFilters['upc'];
    final des = termFilters['des'];

    setState(() {
      _loading = true;
      _error = null;
      _hasSearched = true;
      if (resetPage) _page = 1;
    });

    try {
      final result = await ref
          .read(datArtApiProvider)
          .fetchArticulosPaged(
            suc: useLoteFilter ? null : selectedSuc,
            loteId: useLoteFilter ? loteId : null,
            art: art,
            upc: upc,
            des: des,
            depa: _selectedDepa,
            subd: _selectedSubd,
            clas: _selectedClas,
            scla: _selectedScla,
            scla2: _selectedScla2,
            sph: sph,
            cyl: cyl,
            adic: adic,
            page: _page,
            limit: _limit,
            view: 'lite',
          );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _totalCount = result.total;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportExcel() async {
    if (_exporting) return;
    final selectedSuc = (_selectedSuc ?? '').trim();
    if (selectedSuc.isEmpty) {
      _showSnack('Selecciona una sucursal para exportar.');
      return;
    }

    final sph = _parseDouble(_sphCtrl.text);
    final cyl = _parseDouble(_cylCtrl.text);
    final adic = _parseDouble(_adicCtrl.text);
    bool invalidNumber(String raw, double? parsed) =>
        raw.trim().isNotEmpty && parsed == null;
    if (invalidNumber(_sphCtrl.text, sph) ||
        invalidNumber(_cylCtrl.text, cyl) ||
        invalidNumber(_adicCtrl.text, adic)) {
      _showSnack('Revisa los campos numéricos de filtros.');
      return;
    }

    setState(() => _exporting = true);
    final status = ValueNotifier<String>('Preparando exportación...');
    var dialogShown = false;
    if (mounted) {
      _showExportDialog(status);
      dialogShown = true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 16));
    try {
      final term = _searchCtrl.text.trim();
      final termFilters = _resolveTermFilters(term);
      status.value = 'Descargando datos...';
      final items = await _fetchAllForExport(
        suc: selectedSuc,
        art: termFilters['art'],
        upc: termFilters['upc'],
        des: termFilters['des'],
        depa: _selectedDepa,
        subd: _selectedSubd,
        clas: _selectedClas,
        scla: _selectedScla,
        scla2: _selectedScla2,
        sph: sph,
        cyl: cyl,
        adic: adic,
        onProgress: (page, totalPages) {
          status.value = totalPages > 0
              ? 'Descargando página $page de $totalPages...'
              : 'Descargando página $page...';
        },
      );

      if (items.isEmpty) {
        _showSnack('No hay resultados para exportar.');
        return;
      }

      status.value = 'Construyendo Excel...';
      final rows = <List<dynamic>>[_exportHeaders, ...items.map(_exportRow)];
      final bytes = await _buildExcelBytes(rows, status);
      final filename = _buildExportFilename(selectedSuc);
      final saved = await getExcelExporter().save(bytes, filename);
      if (!saved) {
        _showSnack('Exportación cancelada.');
        return;
      }
      _showSnack('Exportación lista: $filename');
    } catch (e) {
      _showSnack('Error al exportar: $e');
    } finally {
      if (dialogShown &&
          mounted &&
          Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      status.dispose();
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<List<DatArtModel>> _fetchAllForExport({
    required String suc,
    String? art,
    String? upc,
    String? des,
    double? depa,
    double? subd,
    double? clas,
    double? scla,
    double? scla2,
    double? sph,
    double? cyl,
    double? adic,
    void Function(int page, int totalPages)? onProgress,
  }) async {
    final items = <DatArtModel>[];
    var page = 1;
    var totalPages = 1;

    while (page <= totalPages) {
      final result = await ref
          .read(datArtApiProvider)
          .fetchArticulosPaged(
            suc: suc,
            art: art,
            upc: upc,
            des: des,
            depa: depa,
            subd: subd,
            clas: clas,
            scla: scla,
            scla2: scla2,
            sph: sph,
            cyl: cyl,
            adic: adic,
            page: page,
            limit: _limit,
            view: null,
          );
      items.addAll(result.items);
      totalPages = result.total > 0
          ? ((result.total + _limit - 1) ~/ _limit)
          : 0;
      if (totalPages == 0) break;
      onProgress?.call(page, totalPages);
      page += 1;
    }

    return items;
  }

  Future<Uint8List> _buildExcelBytes(
    List<List<dynamic>> rows,
    ValueNotifier<String> status,
  ) async {
    final excel = xls.Excel.createExcel();
    final sheet = excel['DAT_ART'];
    final totalRows = rows.length;
    for (var i = 0; i < totalRows; i += 1) {
      sheet.appendRow(rows[i].map(_excelValue).toList());
      if (i % 200 == 0) {
        final percent = totalRows > 0
            ? ((i + 1) / totalRows * 100).clamp(0, 100).floor()
            : 100;
        status.value = 'Construyendo Excel... $percent%';
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    excel.setDefaultSheet('DAT_ART');
    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('No se pudo generar el archivo.');
    }
    return Uint8List.fromList(bytes);
  }

  List<dynamic> _exportRow(DatArtModel item) {
    return [
      item.suc,
      item.tipo,
      item.art,
      item.upc,
      item.clavesat,
      item.unimedsat,
      item.des,
      item.stock,
      item.stockMin,
      item.estatus,
      item.diaReabasto,
      item.pvta,
      item.ctop,
      item.prov1,
      item.ctoProv1,
      item.prov2,
      item.ctoProv2,
      item.prov3,
      item.ctoProv3,
      item.unComp,
      item.factComp,
      item.unVta,
      item.factVta,
      item.base,
      item.sph,
      item.cyl,
      item.adic,
      item.depa,
      item.subd,
      item.clas,
      item.scla,
      item.scla2,
      item.umue,
      item.utra,
      item.univ,
      item.ufre,
      item.bloq,
      item.marca,
      item.modelo,
    ];
  }

  xls.CellValue _excelValue(dynamic value) {
    if (value == null) return xls.TextCellValue('');
    if (value is xls.CellValue) return value;
    if (value is int) return xls.IntCellValue(value);
    if (value is double) return xls.DoubleCellValue(value);
    if (value is num) return xls.DoubleCellValue(value.toDouble());
    if (value is bool) return xls.BoolCellValue(value);
    return xls.TextCellValue(value.toString());
  }

  String _buildExportFilename(String suc) {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return 'DAT_ART_${suc}_$y$m$d-$hh$mm.xlsx';
  }

  void _showExportDialog(ValueNotifier<String> status) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Exportando'),
            content: Row(
              children: [
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ValueListenableBuilder<String>(
                    valueListenable: status,
                    builder: (context, value, _) => Text(value),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadMassiveExcel() async {
    if (_uploadingMassive) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls'],
      withData: true,
    );
    if (!mounted || result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showSnack('No se pudo leer el archivo seleccionado.');
      return;
    }

    setState(() => _uploadingMassive = true);
    try {
      final response = await ref
          .read(datArtApiProvider)
          .uploadModificacionMasiva(bytes: bytes, filename: file.name);

      final resumen =
          'Procesados ${response.procesados}/${response.totalCargados} · '
          'UK inválidos ${response.invalidosUk} · '
          'No existen ${response.noExistenCatalogo} · '
          'Duplicados ${response.duplicados}';
      _showSnack('Modificacion masiva finalizada. $resumen');

      setState(() {
        _massiveLoteId = response.loteId;
        _searchCtrl.clear();
        _selectedDepa = null;
        _selectedSubd = null;
        _selectedClas = null;
        _selectedScla = null;
        _selectedScla2 = null;
        _sphCtrl.clear();
        _cylCtrl.clear();
        _adicCtrl.clear();
      });

      if (response.invalidosUk > 0 || response.noExistenCatalogo > 0) {
        _showMassiveResultDialog(response);
      }
      await _search(resetPage: true, forceLoteId: response.loteId);
    } on DioException catch (e) {
      _showSnack('Error al subir: ${apiErrorMessage(e)}');
    } catch (e) {
      _showSnack('Error al subir: $e');
    } finally {
      if (mounted) setState(() => _uploadingMassive = false);
    }
  }

  Future<void> _openAltaMasivaDialog() async {
    if (_uploadingAltaMasiva) return;
    setState(() => _uploadingAltaMasiva = true);

    final commitResult = await showDialog<AltaMasivaCommitResult?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        String? fileName;
        List<int>? fileBytes;
        _AltaMasivaPreview preview = const _AltaMasivaPreview(
          headers: [],
          rows: [],
        );
        AltaMasivaUploadResult? uploadResult;
        AltaMasivaValidationResult? validationResult;
        AltaMasivaCommitResult? commitResult;
        String? errorMsg;
        bool validating = false;
        bool committing = false;
        bool previewLoading = false;

        Future<void> pickFile(StateSetter setDialogState) async {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: const ['xlsx', 'xls'],
            withData: true,
          );
          if (result == null || result.files.isEmpty) return;
          final file = result.files.single;
          final bytes = file.bytes;
          if (bytes == null || bytes.isEmpty) {
            setDialogState(() => errorMsg = 'No se pudo leer el archivo.');
            return;
          }

          setDialogState(() {
            fileName = file.name;
            fileBytes = bytes;
            preview = _buildAltaPreview(bytes);
            previewLoading = true;
            uploadResult = null;
            validationResult = null;
            commitResult = null;
            errorMsg = null;
          });

          final localPreview = preview;
          final lowerName = file.name.toLowerCase();
          final needServerPreview =
              localPreview.headers.isEmpty ||
              localPreview.rows.isEmpty ||
              lowerName.endsWith('.xls');

          if (needServerPreview) {
            try {
              final serverPreview = await ref
                  .read(datArtApiProvider)
                  .previewAltaMasiva(bytes: bytes, filename: file.name);
              setDialogState(() {
                preview = _AltaMasivaPreview(
                  headers: serverPreview.headers,
                  rows: serverPreview.rows,
                );
              });
            } catch (e) {
              setDialogState(() {
                if (preview.headers.isEmpty || preview.rows.isEmpty) {
                  errorMsg = 'No se pudo generar la vista previa.';
                }
              });
            }
          }

          setDialogState(() {
            previewLoading = false;
          });
        }

        Future<void> validateBatch(StateSetter setDialogState) async {
          if (fileBytes == null || fileName == null) {
            setDialogState(() => errorMsg = 'Selecciona un archivo primero.');
            return;
          }
          setDialogState(() {
            validating = true;
            errorMsg = null;
            validationResult = null;
            commitResult = null;
          });

          try {
            final upload = await ref.read(datArtApiProvider).uploadAltaMasiva(
                  bytes: fileBytes!,
                  filename: fileName!,
                );
            final validation = await ref
                .read(datArtApiProvider)
                .validateAltaMasiva(batchId: upload.batchId);
            setDialogState(() {
              uploadResult = upload;
              validationResult = validation;
            });
          } on DioException catch (e) {
            setDialogState(
              () => errorMsg = 'Error al validar: ${apiErrorMessage(e)}',
            );
          } catch (e) {
            setDialogState(() => errorMsg = 'Error al validar: $e');
          } finally {
            setDialogState(() => validating = false);
          }
        }

        Future<void> commitBatch(StateSetter setDialogState) async {
          final batchId = uploadResult?.batchId ?? '';
          if (batchId.isEmpty) {
            setDialogState(() => errorMsg = 'Valida el archivo primero.');
            return;
          }
          setDialogState(() {
            committing = true;
            errorMsg = null;
            commitResult = null;
          });
          try {
            final result = await ref
                .read(datArtApiProvider)
                .commitAltaMasiva(batchId: batchId);
            setDialogState(() => commitResult = result);
            _showSnack(
              'Alta masiva completada. Insertados: ${result.insertedRows}.',
            );
          } on DioException catch (e) {
            setDialogState(
              () => errorMsg = 'Error al procesar: ${apiErrorMessage(e)}',
            );
          } catch (e) {
            setDialogState(() => errorMsg = 'Error al procesar: $e');
          } finally {
            setDialogState(() => committing = false);
          }
        }

        Widget buildPreviewTable() {
          if (previewLoading) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (preview.headers.isEmpty || preview.rows.isEmpty) {
            return const Text('Sin vista previa disponible.');
          }
          final columns =
              preview.headers.map((h) => DataColumn(label: Text(h))).toList();
          final rows = preview.rows
              .map(
                (r) => DataRow(
                  cells: r.map((v) => DataCell(Text(v))).toList(),
                ),
              )
              .toList();
          return SizedBox(
            height: 220,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: columns,
                  rows: rows,
                  headingRowHeight: 28,
                  dataRowMinHeight: 24,
                  dataRowMaxHeight: 28,
                ),
              ),
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final processed = commitResult != null;
            final canSelect = !processed && !validating && !committing;
            final canValidate =
                !processed && !validating && !committing && fileBytes != null;
            final hasErrors = (validationResult?.errorRows ?? 0) > 0;
            final canCommit = !committing &&
                !validating &&
                !processed &&
                validationResult != null &&
                !hasErrors;

            return AlertDialog(
              title: const Text('Alta Masiva de Artículos'),
              content: SizedBox(
                width: 900,
                child: SelectionArea(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                fileName == null
                                    ? 'Archivo: sin seleccionar'
                                    : 'Archivo: $fileName',
                              ),
                            ),
                            TextButton.icon(
                              onPressed:
                                  canSelect ? () => pickFile(setDialogState) : null,
                              icon: const Icon(Icons.attach_file),
                              label: const Text('Seleccionar Excel'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(commitResult),
                              child: const Text('Cerrar'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: canValidate
                                  ? () => validateBatch(setDialogState)
                                  : null,
                              icon: validating
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child:
                                          CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: const Text('Validar'),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: canCommit
                                  ? () => commitBatch(setDialogState)
                                  : null,
                              icon: committing
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child:
                                          CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.play_circle_outline),
                              label: const Text('Procesar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (errorMsg != null) ...[
                          Text(
                            errorMsg!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const Text(
                          'Vista previa (primeros renglones)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        buildPreviewTable(),
                        const SizedBox(height: 12),
                        if (uploadResult != null) ...[
                          Text('BatchId: ${uploadResult!.batchId}'),
                          Text(
                            'Total filas: ${uploadResult!.totalRows}',
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (validationResult != null) ...[
                          Text(
                            'Validación -> Total: ${validationResult!.totalRows} · '
                            'Válidos: ${validationResult!.validRows} · '
                            'Errores: ${validationResult!.errorRows}',
                          ),
                          if (validationResult!.errors.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Errores (top 200):',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 160,
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: validationResult!.errors
                                      .map(
                                        (err) => Text(
                                          'Renglon ${err.rowNum}: '
                                          'SUC=${err.suc ?? '-'} '
                                          'ART=${err.art ?? '-'} '
                                          'UPC=${err.upc ?? '-'} '
                                          '-> ${err.errorMsg ?? ''}',
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ],
                        if (commitResult != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Insertados: ${commitResult!.insertedRows}',
                          ),
                          if (commitResult!.inserted.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            const Text(
                              'Insertados (top 50):',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 160,
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: commitResult!.inserted
                                      .take(50)
                                      .map(
                                        (row) => Text(
                                          'ART=${row.art} UPC=${row.upc} '
                                          'SUC=${row.suc ?? '-'} '
                                          'DES=${row.des ?? '-'}',
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (mounted) setState(() => _uploadingAltaMasiva = false);
    if (commitResult != null) {
      _applyAltaMasivaResult(commitResult);
    }
  }

  void _applyAltaMasivaResult(AltaMasivaCommitResult result) {
    final rows = result.inserted;
    if (rows.isEmpty) return;
    final items = rows
        .map(
          (row) => DatArtModel(
            suc: row.suc ?? '',
            art: row.art,
            upc: row.upc,
            tipo: row.tipo,
            clavesat: null,
            unimedsat: null,
            des: row.des,
            stock: null,
            stockMin: null,
            estatus: null,
            diaReabasto: null,
            pvta: null,
            ctop: null,
            prov1: null,
            ctoProv1: null,
            prov2: null,
            ctoProv2: null,
            prov3: null,
            ctoProv3: null,
            unComp: null,
            factComp: null,
            unVta: null,
            factVta: null,
            base: null,
            sph: null,
            cyl: null,
            adic: null,
            depa: null,
            subd: null,
            clas: null,
            scla: null,
            scla2: null,
            umue: null,
            utra: null,
            univ: null,
            ufre: null,
            bloq: null,
            marca: null,
            modelo: null,
          ),
        )
        .toList();

    setState(() {
      _massiveLoteId = null;
      _items = items;
      _totalCount = result.insertedRows;
      _hasMore = false;
      _hasSearched = true;
      _page = 1;
      _selectedKey = null;
      _detailItem = null;
      _detailError = null;
    });
  }

  void _showMassiveResultDialog(DatArtMassiveUploadResult result) {
    showDialog<void>(
      context: context,
      builder: (context) {
        final invalidos = result.invalidos;
        final noExistentes = result.noExistentes;
        return AlertDialog(
          title: const Text('Resultado Modificacion Masiva'),
          content: SizedBox(
            width: 760,
            child: SelectionArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Lote: ${result.loteId}'),
                    const SizedBox(height: 8),
                    Text('Total cargados: ${result.totalCargados}'),
                    Text('Procesados: ${result.procesados}'),
                    Text('UK invalido (SUC/ART/UPC): ${result.invalidosUk}'),
                    Text(
                      'No existentes en catalogo sucursal: ${result.noExistenCatalogo}',
                    ),
                    Text('Duplicados en archivo: ${result.duplicados}'),
                    if (invalidos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Articulos con UK invalido',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      ...invalidos.map((issue) => Text(_issueLine(issue))),
                    ],
                    if (noExistentes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Articulos no dados de alta en sucursal',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      ...noExistentes.map((issue) => Text(_issueLine(issue))),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  String _issueLine(DatArtMassiveIssue issue) {
    final suc = (issue.suc ?? '').trim().isEmpty ? '-' : issue.suc!.trim();
    final art = (issue.art ?? '').trim().isEmpty ? '-' : issue.art!.trim();
    final upc = (issue.upc ?? '').trim().isEmpty ? '-' : issue.upc!.trim();
    final msg = (issue.mensaje ?? '').trim();
    if (msg.isEmpty) {
      return 'Renglon ${issue.renglon}: SUC=$suc ART=$art UPC=$upc';
    }
    return 'Renglon ${issue.renglon}: SUC=$suc ART=$art UPC=$upc -> $msg';
  }

  Widget _buildMassiveFilterMessage({required bool compact}) {
    final loteShort = (_massiveLoteId ?? '').trim().split('-').first;
    final text = 'Mostrando artículos modificados del lote $loteShort.';
    return Container(
      width: compact ? null : double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _clearMassiveFilter,
                    child: const Text('Quitar filtro'),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: Text(text)),
                TextButton(
                  onPressed: _clearMassiveFilter,
                  child: const Text('Quitar filtro'),
                ),
              ],
            ),
    );
  }

  void _clearMassiveFilter() {
    setState(() {
      _massiveLoteId = null;
      _items = [];
      _totalCount = 0;
      _hasMore = false;
      _hasSearched = false;
      _page = 1;
      _selectedKey = null;
      _detailItem = null;
      _detailError = null;
    });
  }

  void _clearFilters() {
    _searchCtrl.clear();
    _selectedSuc = null;
    _searchBy = 'ART';
    _selectedDepa = null;
    _selectedSubd = null;
    _selectedClas = null;
    _selectedScla = null;
    _selectedScla2 = null;
    _sphCtrl.clear();
    _cylCtrl.clear();
    _adicCtrl.clear();
    setState(() {
      _massiveLoteId = null;
      _items = [];
      _error = null;
      _hasSearched = false;
      _hasMore = false;
      _page = 1;
      _totalCount = 0;
      _detailItem = null;
      _detailError = null;
      _selectedKey = null;
    });
  }

  Future<void> _selectItem(DatArtModel item) async {
    final key = _rowKey(item);
    setState(() {
      _selectedKey = key;
      _detailLoading = true;
      _detailError = null;
    });
    try {
      final full = await ref
          .read(datArtApiProvider)
          .fetchArticulo(item.suc, item.art, item.upc);
      if (!mounted) return;
      setState(() {
        _detailItem = full;
        _detailLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _detailError = e.toString();
        _detailLoading = false;
      });
    }
  }

  String _rowKey(DatArtModel item) => '${item.suc}|${item.art}|${item.upc}';

  @override
  Widget build(BuildContext context) {
    final sucAsync = ref.watch(sucursalesListProvider);
    final depaAsync = ref.watch(jrqDepaListProvider);
    final subdAsync = ref.watch(jrqSubdListProvider(_selectedDepa));
    final clasAsync = ref.watch(jrqClasListProvider(_selectedSubd));
    final sclaAsync = ref.watch(jrqSclaListProvider(_selectedClas));
    final scla2Async = ref.watch(jrqScla2ListProvider(_selectedScla));
    final baseTheme = Theme.of(context);
    final baseFontSize = baseTheme.textTheme.bodyMedium?.fontSize ?? 14;
    final fontFactor = DatArtUiConfig.fontSize / baseFontSize;
    final localTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontSizeFactor: fontFactor),
      inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
        labelStyle: baseTheme.textTheme.bodySmall?.copyWith(
          fontSize: DatArtUiConfig.fontSize,
        ),
        hintStyle: baseTheme.textTheme.bodySmall?.copyWith(
          fontSize: DatArtUiConfig.fontSize,
        ),
      ),
    );

    return Theme(
      data: localTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catálogo DAT_ART'),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextButton.icon(
                onPressed:
                    _uploadingAltaMasiva ? null : _openAltaMasivaDialog,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFB4D4FF),
                  foregroundColor: Colors.black87,
                ),
                icon: _uploadingAltaMasiva
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add),
                label: const Text('Alta Masiva'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextButton.icon(
                onPressed: _uploadingMassive
                    ? null
                    : _pickAndUploadMassiveExcel,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFC1E1A7),
                  foregroundColor: Colors.black87,
                ),
                icon: _uploadingMassive
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: const Text('Modificacion Masiva'),
              ),
            ),
            IconButton(
              onPressed: _exporting ? null : _exportExcel,
              tooltip: 'Exportar Excel',
              icon: _exporting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
            ),
            IconButton(
              onPressed: () => _search(),
              icon: const Icon(Icons.refresh),
              tooltip: 'Refrescar',
            ),
          ],
        ),
        body: Padding(
          padding: DatArtUiConfig.pagePadding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;
              final gap = 12.0;
              final targetLeftWidth =
                  DatArtUiConfig.tableWidth +
                  DatArtUiConfig.cardPadding.horizontal;
              final availableLeftWidth =
                  (constraints.maxWidth - DatArtUiConfig.detailPanelWidth - gap)
                      .clamp(0.0, constraints.maxWidth);
              final leftPanelWidth = isWide
                  ? min(availableLeftWidth, targetLeftWidth)
                  : constraints.maxWidth;

              final leftPanel = Card(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                child: Padding(
                  padding: DatArtUiConfig.cardPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, topConstraints) {
                          final hasMassiveFilter = (_massiveLoteId ?? '')
                              .trim()
                              .isNotEmpty;
                          final showInlineMassive =
                              hasMassiveFilter &&
                              topConstraints.maxWidth >= 900;

                          final filtersCard = _FiltersCard(
                            sucAsync: sucAsync,
                            selectedSuc: _selectedSuc,
                            onSucChanged: (value) {
                              setState(() => _selectedSuc = value);
                              if (_hasSearchCriteria()) _scheduleSearch();
                            },
                            canSearch:
                                (_selectedSuc ?? '').trim().isNotEmpty ||
                                (_massiveLoteId ?? '').trim().isNotEmpty,
                            searchBy: _searchBy,
                            onSearchByChanged: (value) {
                              setState(() => _searchBy = value ?? 'ART');
                              _scheduleSearch();
                            },
                            searchCtrl: _searchCtrl,
                            depaAsync: depaAsync,
                            subdAsync: subdAsync,
                            clasAsync: clasAsync,
                            sclaAsync: sclaAsync,
                            scla2Async: scla2Async,
                            selectedDepa: _selectedDepa,
                            selectedSubd: _selectedSubd,
                            selectedClas: _selectedClas,
                            selectedScla: _selectedScla,
                            selectedScla2: _selectedScla2,
                            onDepaChanged: (value) {
                              setState(() {
                                _selectedDepa = value;
                                _selectedSubd = null;
                                _selectedClas = null;
                                _selectedScla = null;
                                _selectedScla2 = null;
                              });
                              _scheduleSearch();
                            },
                            onSubdChanged: (value) {
                              setState(() {
                                _selectedSubd = value;
                                _selectedClas = null;
                                _selectedScla = null;
                                _selectedScla2 = null;
                              });
                              _scheduleSearch();
                            },
                            onClasChanged: (value) {
                              setState(() {
                                _selectedClas = value;
                                _selectedScla = null;
                                _selectedScla2 = null;
                              });
                              _scheduleSearch();
                            },
                            onSclaChanged: (value) {
                              setState(() {
                                _selectedScla = value;
                                _selectedScla2 = null;
                              });
                              _scheduleSearch();
                            },
                            onScla2Changed: (value) {
                              setState(() => _selectedScla2 = value);
                              _scheduleSearch();
                            },
                            sphCtrl: _sphCtrl,
                            cylCtrl: _cylCtrl,
                            adicCtrl: _adicCtrl,
                            onFilterChanged: _scheduleSearch,
                            onSearch: () => _search(resetPage: true),
                            onClear: _clearFilters,
                          );

                          if (!hasMassiveFilter) return filtersCard;
                          if (showInlineMassive) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: filtersCard),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 220,
                                  child: _buildMassiveFilterMessage(
                                    compact: true,
                                  ),
                                ),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              filtersCard,
                              const SizedBox(height: 8),
                              _buildMassiveFilterMessage(compact: false),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(child: _buildResults()),
                      if (_hasSearched)
                        _PaginationBar(
                          page: _page,
                          limit: _limit,
                          count: _items.length,
                          totalCount: _totalCount,
                          totalPages: _totalCount > 0
                              ? ((_totalCount + _limit - 1) ~/ _limit)
                              : 0,
                          hasMore: _hasMore,
                          isLoading: _loading,
                          onPrev: _page > 1 && !_loading
                              ? () {
                                  setState(() => _page -= 1);
                                  _search();
                                }
                              : null,
                          onNext: _hasMore && !_loading
                              ? () {
                                  setState(() => _page += 1);
                                  _search();
                                }
                              : null,
                          onFirst: _page > 1 && !_loading
                              ? () {
                                  setState(() => _page = 1);
                                  _search();
                                }
                              : null,
                          onLast:
                              (_totalCount > 0 &&
                                  !_loading &&
                                  _page <
                                      ((_totalCount + _limit - 1) ~/ _limit))
                              ? () {
                                  setState(
                                    () => _page =
                                        ((_totalCount + _limit - 1) ~/ _limit),
                                  );
                                  _search();
                                }
                              : null,
                        ),
                    ],
                  ),
                ),
              );

              final detailPanel = _DatArtDetailPanel(
                item: _detailItem,
                loading: _detailLoading,
                error: _detailError,
                onReload: _detailItem == null
                    ? null
                    : () => _selectItem(_detailItem!),
                onSaved: () => _search(),
                height: isWide ? constraints.maxHeight : null,
              );

              if (!isWide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: leftPanel),
                    const SizedBox(height: 12),
                    detailPanel,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: leftPanelWidth, child: leftPanel),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: DatArtUiConfig.detailPanelWidth,
                    child: detailPanel,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_items.isEmpty) {
      final msg = _hasSearched
          ? (_massiveLoteId != null && _massiveLoteId!.trim().isNotEmpty
                ? 'No se encontraron artículos modificados para el lote actual.'
                : (_page > 1
                      ? 'Sin resultados en esta página.'
                      : 'Sin resultados.'))
          : 'Realice una búsqueda para mostrar artículos.';
      return Center(child: Text(msg));
    }

    final horizontalTable = SingleChildScrollView(
      controller: _horizontalScrollCtrl,
      scrollDirection: Axis.horizontal,
      child: SelectionArea(
        child: DataTableTheme(
          data: DataTableThemeData(
            dataTextStyle: const TextStyle(fontSize: DatArtUiConfig.fontSize),
            headingTextStyle: const TextStyle(
              fontSize: DatArtUiConfig.fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: DataTable(
            showCheckboxColumn: false,
            columnSpacing: DatArtUiConfig.columnSpacing,
            dataRowMinHeight: DatArtUiConfig.dataRowHeight,
            dataRowMaxHeight: DatArtUiConfig.dataRowHeight,
            headingRowHeight: DatArtUiConfig.headingRowHeight,
            horizontalMargin: DatArtUiConfig.horizontalMargin,
            columns: [
              DataColumn(label: _colLabel('SUC', DatArtUiConfig.colSuc)),
              DataColumn(label: _colLabel('ART', DatArtUiConfig.colArt)),
              DataColumn(label: _colLabel('UPC', DatArtUiConfig.colUpc)),
              DataColumn(label: _colLabel('DES', DatArtUiConfig.colDes)),
              DataColumn(label: _colLabel('TIPO', DatArtUiConfig.colTipo)),
              DataColumn(label: _colLabel('STOCK', DatArtUiConfig.colStock)),
              DataColumn(
                label: _colLabel('STOCK_MIN', DatArtUiConfig.colStockMin),
              ),
              DataColumn(label: _colLabel('PVTA', DatArtUiConfig.colPvta)),
              DataColumn(label: _colLabel('CTOP', DatArtUiConfig.colCtop)),
              DataColumn(
                label: _colLabel('ESTATUS', DatArtUiConfig.colEstatus),
              ),
            ],
            rows: _items.map((item) {
              final key = _rowKey(item);
              return DataRow(
                selected: _selectedKey == key,
                onSelectChanged: (_) => _selectItem(item),
                cells: [
                  DataCell(_cellText(item.suc, DatArtUiConfig.colSuc)),
                  DataCell(_cellText(item.art, DatArtUiConfig.colArt)),
                  DataCell(_cellText(item.upc, DatArtUiConfig.colUpc)),
                  DataCell(_cellText(item.des ?? '-', DatArtUiConfig.colDes)),
                  DataCell(_cellText(item.tipo ?? '-', DatArtUiConfig.colTipo)),
                  DataCell(
                    _cellText(_fmtNumber(item.stock), DatArtUiConfig.colStock),
                  ),
                  DataCell(
                    _cellText(
                      _fmtNumber(item.stockMin),
                      DatArtUiConfig.colStockMin,
                    ),
                  ),
                  DataCell(
                    _cellText(_fmtMoney(item.pvta), DatArtUiConfig.colPvta),
                  ),
                  DataCell(
                    _cellText(_fmtMoney(item.ctop), DatArtUiConfig.colCtop),
                  ),
                  DataCell(
                    _cellText(item.estatus ?? '-', DatArtUiConfig.colEstatus),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );

    final hasScrollPosition = _horizontalScrollCtrl.hasClients;
    if (!hasScrollPosition) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_horizontalScrollCtrl.hasClients) {
          setState(() {});
        }
      });
    }

    final tableBody = hasScrollPosition
        ? Scrollbar(
            controller: _horizontalScrollCtrl,
            thumbVisibility: true,
            trackVisibility: true,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: horizontalTable,
          )
        : horizontalTable;

    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(child: tableBody),
    );
  }

  String _fmtNumber(double? value) {
    if (value == null) return '-';
    final text = value.toString();
    return text;
  }

  String _fmtMoney(double? value) {
    if (value == null) return '-';
    return value.toStringAsFixed(2);
  }

  Widget _colLabel(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(text, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _cellText(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(text, overflow: TextOverflow.ellipsis),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.limit,
    required this.count,
    required this.totalCount,
    required this.totalPages,
    required this.hasMore,
    required this.isLoading,
    required this.onPrev,
    required this.onNext,
    required this.onFirst,
    required this.onLast,
  });

  final int page;
  final int limit;
  final int count;
  final int totalCount;
  final int totalPages;
  final bool hasMore;
  final bool isLoading;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onFirst;
  final VoidCallback? onLast;

  @override
  Widget build(BuildContext context) {
    final countLabel = totalCount > 0
        ? totalCount.toString()
        : (hasMore && count >= limit ? '$count+' : '$count');
    final pagesLabel = totalPages > 0 ? totalPages.toString() : '-';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onFirst,
                tooltip: 'Primera',
                icon: const Icon(Icons.first_page),
              ),
              IconButton(
                onPressed: onPrev,
                tooltip: 'Anterior',
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: onNext,
                tooltip: 'Siguiente',
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                onPressed: onLast,
                tooltip: 'Última',
                icon: const Icon(Icons.last_page),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Text('Página $page de $pagesLabel'),
          const SizedBox(width: 16),
          Expanded(child: Text('Resultados: $countLabel · Límite $limit')),
        ],
      ),
    );
  }
}

class _DatArtDetailPanel extends ConsumerStatefulWidget {
  const _DatArtDetailPanel({
    required this.item,
    required this.loading,
    required this.error,
    required this.onReload,
    required this.onSaved,
    this.height,
  });

  final DatArtModel? item;
  final bool loading;
  final String? error;
  final VoidCallback? onReload;
  final VoidCallback onSaved;
  final double? height;

  @override
  ConsumerState<_DatArtDetailPanel> createState() => _DatArtDetailPanelState();
}

class _DatArtDetailPanelState extends ConsumerState<_DatArtDetailPanel> {
  final _upcCtrl = TextEditingController();
  final _desCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _estatusCtrl = TextEditingController();
  final _stockMinCtrl = TextEditingController();
  final _diaReabastoCtrl = TextEditingController();
  final _pvtaCtrl = TextEditingController();
  final _unCompCtrl = TextEditingController();
  final _factCompCtrl = TextEditingController();
  final _unVtaCtrl = TextEditingController();
  final _factVtaCtrl = TextEditingController();
  final _clavesatCtrl = TextEditingController();
  final _unimedsatCtrl = TextEditingController();
  final _prov1Ctrl = TextEditingController();
  final _ctoProv1Ctrl = TextEditingController();
  final _prov2Ctrl = TextEditingController();
  final _ctoProv2Ctrl = TextEditingController();
  final _prov3Ctrl = TextEditingController();
  final _ctoProv3Ctrl = TextEditingController();
  final _umueCtrl = TextEditingController();
  final _utraCtrl = TextEditingController();
  final _univCtrl = TextEditingController();
  final _ufreCtrl = TextEditingController();
  final _baseCtrl = TextEditingController();
  final _sphCtrl = TextEditingController();
  final _cylCtrl = TextEditingController();
  final _adicCtrl = TextEditingController();

  bool _bloq = false;
  bool _saving = false;
  String? _currentKey;

  double? _depa;
  double? _subd;
  double? _clas;
  double? _scla;
  double? _scla2;

  @override
  void dispose() {
    _upcCtrl.dispose();
    _desCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _estatusCtrl.dispose();
    _stockMinCtrl.dispose();
    _diaReabastoCtrl.dispose();
    _pvtaCtrl.dispose();
    _unCompCtrl.dispose();
    _factCompCtrl.dispose();
    _unVtaCtrl.dispose();
    _factVtaCtrl.dispose();
    _clavesatCtrl.dispose();
    _unimedsatCtrl.dispose();
    _prov1Ctrl.dispose();
    _ctoProv1Ctrl.dispose();
    _prov2Ctrl.dispose();
    _ctoProv2Ctrl.dispose();
    _prov3Ctrl.dispose();
    _ctoProv3Ctrl.dispose();
    _umueCtrl.dispose();
    _utraCtrl.dispose();
    _univCtrl.dispose();
    _ufreCtrl.dispose();
    _baseCtrl.dispose();
    _sphCtrl.dispose();
    _cylCtrl.dispose();
    _adicCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _DatArtDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final item = widget.item;
    if (item == null) {
      _currentKey = null;
      return;
    }
    final key = '${item.suc}|${item.art}|${item.upc}';
    if (key != _currentKey) {
      _currentKey = key;
      _applyItem(item);
    }
  }

  void _applyItem(DatArtModel item) {
    _upcCtrl.text = item.upc;
    _desCtrl.text = item.des ?? '';
    _marcaCtrl.text = item.marca ?? '';
    _modeloCtrl.text = item.modelo ?? '';
    _estatusCtrl.text = item.estatus ?? '';
    _stockMinCtrl.text = _fmtNum(item.stockMin);
    _diaReabastoCtrl.text = _fmtNum(item.diaReabasto);
    _pvtaCtrl.text = _fmtNum(item.pvta);
    _unCompCtrl.text = item.unComp ?? '';
    _factCompCtrl.text = _fmtNum(item.factComp);
    _unVtaCtrl.text = item.unVta ?? '';
    _factVtaCtrl.text = _fmtNum(item.factVta);
    _clavesatCtrl.text = _fmtNum(item.clavesat);
    _unimedsatCtrl.text = item.unimedsat ?? '';
    _prov1Ctrl.text = _fmtNum(item.prov1);
    _ctoProv1Ctrl.text = _fmtNum(item.ctoProv1);
    _prov2Ctrl.text = _fmtNum(item.prov2);
    _ctoProv2Ctrl.text = _fmtNum(item.ctoProv2);
    _prov3Ctrl.text = _fmtNum(item.prov3);
    _ctoProv3Ctrl.text = _fmtNum(item.ctoProv3);
    _umueCtrl.text = _fmtNum(item.umue);
    _utraCtrl.text = _fmtNum(item.utra);
    _univCtrl.text = _fmtNum(item.univ);
    _ufreCtrl.text = _fmtNum(item.ufre);
    _baseCtrl.text = item.base ?? '';
    _sphCtrl.text = _fmtNum(item.sph);
    _cylCtrl.text = _fmtNum(item.cyl);
    _adicCtrl.text = _fmtNum(item.adic);
    _bloq = (item.bloq ?? 0) != 0;
    _depa = item.depa;
    _subd = item.subd;
    _clas = item.clas;
    _scla = item.scla;
    _scla2 = item.scla2;
    setState(() {});
  }

  String _fmtNum(double? value) => value?.toString() ?? '';

  double? _parseDouble(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final normalized = trimmed.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  String? _parseString(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _save() async {
    final item = widget.item;
    if (item == null) return;
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'DES': _parseString(_desCtrl.text),
      'MARCA': _parseString(_marcaCtrl.text),
      'MODELO': _parseString(_modeloCtrl.text),
      'ESTATUS': _parseString(_estatusCtrl.text),
      'BLOQ': _bloq ? 1 : 0,
      'STOCK_MIN': _parseDouble(_stockMinCtrl.text),
      'DIA_REABASTO': _parseDouble(_diaReabastoCtrl.text),
      'PVTA': _parseDouble(_pvtaCtrl.text),
      'UN_COMP': _parseString(_unCompCtrl.text),
      'FACT_COMP': _parseDouble(_factCompCtrl.text),
      'UN_VTA': _parseString(_unVtaCtrl.text),
      'FACT_VTA': _parseDouble(_factVtaCtrl.text),
      'CLAVESAT': _parseDouble(_clavesatCtrl.text),
      'UNIMEDSAT': _parseString(_unimedsatCtrl.text),
      'PROV_1': _parseDouble(_prov1Ctrl.text),
      'CTO_PROV1': _parseDouble(_ctoProv1Ctrl.text),
      'PROV_2': _parseDouble(_prov2Ctrl.text),
      'CTO_PROV2': _parseDouble(_ctoProv2Ctrl.text),
      'PROV_3': _parseDouble(_prov3Ctrl.text),
      'CTO_PROV3': _parseDouble(_ctoProv3Ctrl.text),
      'DEPA': _depa,
      'SUBD': _subd,
      'CLAS': _clas,
      'SCLA': _scla,
      'SCLA2': _scla2,
      'UMUE': _parseDouble(_umueCtrl.text),
      'UTRA': _parseDouble(_utraCtrl.text),
      'UNIV': _parseDouble(_univCtrl.text),
      'UFRE': _parseDouble(_ufreCtrl.text),
      'BASE': _parseString(_baseCtrl.text),
      'SPH': _parseDouble(_sphCtrl.text),
      'CYL': _parseDouble(_cylCtrl.text),
      'ADIC': _parseDouble(_adicCtrl.text),
    };

    try {
      final updated = await ref
          .read(datArtApiProvider)
          .updateArticulo(item.suc, item.art, item.upc, payload);
      if (!mounted) return;
      _applyItem(updated);
      widget.onSaved();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Artículo actualizado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    if (widget.loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (widget.error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Error: ${widget.error}'),
              const SizedBox(height: 8),
              if (widget.onReload != null)
                OutlinedButton.icon(
                  onPressed: widget.onReload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
            ],
          ),
        ),
      );
    }
    if (item == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Selecciona un artículo para ver/editar sus detalles.'),
        ),
      );
    }

    final depaAsync = ref.watch(jrqDepaListProvider);
    final subdAsync = ref.watch(jrqSubdListProvider(_depa));
    final clasAsync = ref.watch(jrqClasListProvider(_subd));
    final sclaAsync = ref.watch(jrqSclaListProvider(_clas));
    final scla2Async = ref.watch(jrqScla2ListProvider(_scla));

    final content = Card(
      child: DefaultTabController(
        length: 6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Detalle ${item.art} · ${item.upc}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: Text(_saving ? 'Guardando...' : 'Guardar'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const TabBar(
              isScrollable: true,
              labelStyle: TextStyle(fontSize: DatArtUiConfig.fontSize),
              unselectedLabelStyle: TextStyle(
                fontSize: DatArtUiConfig.fontSize,
              ),
              tabs: [
                Tab(text: 'GENERAL'),
                Tab(text: 'SAT'),
                Tab(text: 'PROVEEDOR'),
                Tab(text: 'JERARQUIA'),
                Tab(text: 'CENSO'),
                Tab(text: 'GRAD'),
              ],
            ),
            if (widget.height == null)
              SizedBox(
                height: 420,
                child: TabBarView(
                  children: [
                    _buildGeneralTab(),
                    _buildSatTab(),
                    _buildProveedorTab(),
                    _buildJerarquiaTab(
                      depaAsync,
                      subdAsync,
                      clasAsync,
                      sclaAsync,
                      scla2Async,
                    ),
                    _buildCensoTab(),
                    _buildGradTab(),
                  ],
                ),
              )
            else
              Expanded(
                child: TabBarView(
                  children: [
                    _buildGeneralTab(),
                    _buildSatTab(),
                    _buildProveedorTab(),
                    _buildJerarquiaTab(
                      depaAsync,
                      subdAsync,
                      clasAsync,
                      sclaAsync,
                      scla2Async,
                    ),
                    _buildCensoTab(),
                    _buildGradTab(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    if (widget.height == null) {
      return content;
    }
    return SizedBox(height: widget.height, child: content);
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: DatArtUiConfig.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Datos generales'),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _DetailFieldBox(
                label: 'UPC',
                width: 180,
                child: _readOnlyField(_upcCtrl),
              ),
              _DetailCheckboxBox(
                label: 'Bloqueado',
                value: _bloq,
                onChanged: (v) => setState(() => _bloq = v),
              ),
              _DetailFieldBox(
                label: 'ESTATUS',
                width: 160,
                child: _textField(_estatusCtrl),
              ),
              _DetailFieldBox(
                label: 'DES',
                width: 300,
                child: _textField(_desCtrl),
              ),
              _DetailFieldBox(
                label: 'MARCA',
                width: 200,
                child: _textField(_marcaCtrl),
              ),
              _DetailFieldBox(
                label: 'MODELO',
                width: 220,
                child: _textField(_modeloCtrl),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SectionTitle('Datos Resurtido'),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _DetailFieldBox(
                label: 'STOCK_MIN',
                width: 140,
                child: _numberField(_stockMinCtrl),
              ),
              _DetailFieldBox(
                label: 'DIA_REABASTO',
                width: 160,
                child: _numberField(_diaReabastoCtrl),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _SectionTitle('Datos Precios'),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _DetailFieldBox(
                label: 'PVTA',
                width: 120,
                child: _numberField(_pvtaCtrl),
              ),
              _DetailFieldBox(
                label: 'UN_COMP',
                width: 120,
                child: _textField(_unCompCtrl),
              ),
              _DetailFieldBox(
                label: 'FACT_COMP',
                width: 120,
                child: _numberField(_factCompCtrl),
              ),
              _DetailFieldBox(
                label: 'UN_VTA',
                width: 120,
                child: _textField(_unVtaCtrl),
              ),
              _DetailFieldBox(
                label: 'FACT_VTA',
                width: 120,
                child: _numberField(_factVtaCtrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSatTab() {
    return SingleChildScrollView(
      padding: DatArtUiConfig.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Datos SAT'),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _DetailFieldBox(
                label: 'CLAVESAT',
                width: 140,
                child: _numberField(_clavesatCtrl),
              ),
              _DetailFieldBox(
                label: 'UNIMEDSAT',
                width: 160,
                child: _textField(_unimedsatCtrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProveedorTab() {
    return SingleChildScrollView(
      padding: DatArtUiConfig.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Datos Proveedor'),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _DetailFieldBox(
                label: 'PROV_1',
                width: 120,
                child: _numberField(_prov1Ctrl),
              ),
              _DetailFieldBox(
                label: 'CTO_PROV1',
                width: 140,
                child: _numberField(_ctoProv1Ctrl),
              ),
              _DetailFieldBox(
                label: 'PROV_2',
                width: 120,
                child: _numberField(_prov2Ctrl),
              ),
              _DetailFieldBox(
                label: 'CTO_PROV2',
                width: 140,
                child: _numberField(_ctoProv2Ctrl),
              ),
              _DetailFieldBox(
                label: 'PROV_3',
                width: 120,
                child: _numberField(_prov3Ctrl),
              ),
              _DetailFieldBox(
                label: 'CTO_PROV3',
                width: 140,
                child: _numberField(_ctoProv3Ctrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildJerarquiaTab(
    AsyncValue<List<JrqDepaModel>> depaAsync,
    AsyncValue<List<JrqSubdModel>> subdAsync,
    AsyncValue<List<JrqClasModel>> clasAsync,
    AsyncValue<List<JrqSclaModel>> sclaAsync,
    AsyncValue<List<JrqScla2Model>> scla2Async,
  ) {
    return SingleChildScrollView(
      padding: DatArtUiConfig.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Selecciona la jerarquía'),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _JrqDropdown<JrqDepaModel>(
                label: 'DEPA',
                width: 120,
                asyncItems: depaAsync,
                value: _depa,
                enabled: true,
                itemValue: (item) => item.depa,
                itemLabel: (item) =>
                    _FiltersCard._formatOption(item.depa, item.ddepa),
                onChanged: (value) {
                  setState(() {
                    _depa = value;
                    _subd = null;
                    _clas = null;
                    _scla = null;
                    _scla2 = null;
                  });
                },
              ),
              _JrqDropdown<JrqSubdModel>(
                label: 'SUBD',
                width: 120,
                asyncItems: subdAsync,
                value: _subd,
                enabled: _depa != null,
                itemValue: (item) => item.subd,
                itemLabel: (item) =>
                    _FiltersCard._formatOption(item.subd, item.dsubd),
                onChanged: (value) {
                  setState(() {
                    _subd = value;
                    _clas = null;
                    _scla = null;
                    _scla2 = null;
                  });
                },
              ),
              _JrqDropdown<JrqClasModel>(
                label: 'CLAS',
                width: 120,
                asyncItems: clasAsync,
                value: _clas,
                enabled: _subd != null,
                itemValue: (item) => item.clas,
                itemLabel: (item) =>
                    _FiltersCard._formatOption(item.clas, item.dclas),
                onChanged: (value) {
                  setState(() {
                    _clas = value;
                    _scla = null;
                    _scla2 = null;
                  });
                },
              ),
              _JrqDropdown<JrqSclaModel>(
                label: 'SCLA',
                width: 120,
                asyncItems: sclaAsync,
                value: _scla,
                enabled: _clas != null,
                itemValue: (item) => item.scla,
                itemLabel: (item) =>
                    _FiltersCard._formatOption(item.scla, item.dscla),
                onChanged: (value) {
                  setState(() {
                    _scla = value;
                    _scla2 = null;
                  });
                },
              ),
              _JrqDropdown<JrqScla2Model>(
                label: 'SCLA2',
                width: 120,
                asyncItems: scla2Async,
                value: _scla2,
                enabled: _scla != null,
                itemValue: (item) => item.scla2,
                itemLabel: (item) =>
                    _FiltersCard._formatOption(item.scla2, item.dscla2),
                onChanged: (value) => setState(() => _scla2 = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCensoTab() {
    return SingleChildScrollView(
      padding: DatArtUiConfig.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Ubicación física del artículo'),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _DetailFieldBox(
                label: 'UMUE',
                width: 120,
                child: _numberField(_umueCtrl),
              ),
              _DetailFieldBox(
                label: 'UTRA',
                width: 120,
                child: _numberField(_utraCtrl),
              ),
              _DetailFieldBox(
                label: 'UNIV',
                width: 120,
                child: _numberField(_univCtrl),
              ),
              _DetailFieldBox(
                label: 'UFRE',
                width: 120,
                child: _numberField(_ufreCtrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGradTab() {
    return SingleChildScrollView(
      padding: DatArtUiConfig.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Otros datos para control'),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _DetailFieldBox(
                label: 'BASE',
                width: 160,
                child: _textField(_baseCtrl),
              ),
              _DetailFieldBox(
                label: 'SPH',
                width: 120,
                child: _numberField(_sphCtrl),
              ),
              _DetailFieldBox(
                label: 'CYL',
                width: 120,
                child: _numberField(_cylCtrl),
              ),
              _DetailFieldBox(
                label: 'ADIC',
                width: 120,
                child: _numberField(_adicCtrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _readOnlyField(TextEditingController controller) {
    return TextField(
      controller: controller,
      enabled: false,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _textField(TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _numberField(TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.-]'))],
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: DatArtUiConfig.fontSize,
        ),
      ),
    );
  }
}

class _DetailFieldBox extends StatelessWidget {
  const _DetailFieldBox({
    required this.label,
    required this.width,
    required this.child,
  });

  final String label;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: DatArtUiConfig.fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _DetailCheckboxBox extends StatelessWidget {
  const _DetailCheckboxBox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: DatArtUiConfig.fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.sucAsync,
    required this.selectedSuc,
    required this.onSucChanged,
    required this.canSearch,
    required this.searchBy,
    required this.onSearchByChanged,
    required this.searchCtrl,
    required this.depaAsync,
    required this.subdAsync,
    required this.clasAsync,
    required this.sclaAsync,
    required this.scla2Async,
    required this.selectedDepa,
    required this.selectedSubd,
    required this.selectedClas,
    required this.selectedScla,
    required this.selectedScla2,
    required this.onDepaChanged,
    required this.onSubdChanged,
    required this.onClasChanged,
    required this.onSclaChanged,
    required this.onScla2Changed,
    required this.sphCtrl,
    required this.cylCtrl,
    required this.adicCtrl,
    required this.onFilterChanged,
    required this.onSearch,
    required this.onClear,
  });

  final AsyncValue<List<SucursalModel>> sucAsync;
  final String? selectedSuc;
  final ValueChanged<String?> onSucChanged;
  final bool canSearch;
  final String searchBy;
  final ValueChanged<String?> onSearchByChanged;
  final TextEditingController searchCtrl;
  final AsyncValue<List<JrqDepaModel>> depaAsync;
  final AsyncValue<List<JrqSubdModel>> subdAsync;
  final AsyncValue<List<JrqClasModel>> clasAsync;
  final AsyncValue<List<JrqSclaModel>> sclaAsync;
  final AsyncValue<List<JrqScla2Model>> scla2Async;
  final double? selectedDepa;
  final double? selectedSubd;
  final double? selectedClas;
  final double? selectedScla;
  final double? selectedScla2;
  final ValueChanged<double?> onDepaChanged;
  final ValueChanged<double?> onSubdChanged;
  final ValueChanged<double?> onClasChanged;
  final ValueChanged<double?> onSclaChanged;
  final ValueChanged<double?> onScla2Changed;
  final TextEditingController sphCtrl;
  final TextEditingController cylCtrl;
  final TextEditingController adicCtrl;
  final VoidCallback onFilterChanged;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  static const double _filterHeight = 32;
  static const double _filterFontSize = DatArtUiConfig.fontSize;
  static const EdgeInsets _filterPadding = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 6,
  );
  static const double _filterMenuWidth = 260;

  @override
  Widget build(BuildContext context) {
    const denseDecoration = InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
      contentPadding: _filterPadding,
      constraints: BoxConstraints.tightFor(height: _filterHeight),
    );
    final numberFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9,.-]')),
    ];

    return Card(
      child: Padding(
        padding: DatArtUiConfig.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtros de búsqueda',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _SucDropdown(
                  label: 'SUC',
                  width: 180,
                  asyncItems: sucAsync,
                  value: selectedSuc,
                  onChanged: onSucChanged,
                ),
                _SearchByDropdown(
                  width: 120,
                  value: searchBy,
                  onChanged: onSearchByChanged,
                ),
                _FilterField(
                  label: 'Buscar',
                  controller: searchCtrl,
                  width: 200,
                  decoration: denseDecoration,
                  onChanged: (_) => onFilterChanged(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _JrqDropdown<JrqDepaModel>(
                  label: 'DEPA',
                  width: 90,
                  asyncItems: depaAsync,
                  value: selectedDepa,
                  enabled: true,
                  itemValue: (item) => item.depa,
                  itemLabel: (item) => _formatOption(item.depa, item.ddepa),
                  onChanged: onDepaChanged,
                ),
                _JrqDropdown<JrqSubdModel>(
                  label: 'SUBD',
                  width: 90,
                  asyncItems: subdAsync,
                  value: selectedSubd,
                  enabled: selectedDepa != null,
                  itemValue: (item) => item.subd,
                  itemLabel: (item) => _formatOption(item.subd, item.dsubd),
                  onChanged: onSubdChanged,
                ),
                _JrqDropdown<JrqClasModel>(
                  label: 'CLAS',
                  width: 90,
                  asyncItems: clasAsync,
                  value: selectedClas,
                  enabled: selectedSubd != null,
                  itemValue: (item) => item.clas,
                  itemLabel: (item) => _formatOption(item.clas, item.dclas),
                  onChanged: onClasChanged,
                ),
                _JrqDropdown<JrqSclaModel>(
                  label: 'SCLA',
                  width: 90,
                  asyncItems: sclaAsync,
                  value: selectedScla,
                  enabled: selectedClas != null,
                  itemValue: (item) => item.scla,
                  itemLabel: (item) => _formatOption(item.scla, item.dscla),
                  onChanged: onSclaChanged,
                ),
                _JrqDropdown<JrqScla2Model>(
                  label: 'SCLA2',
                  width: 90,
                  asyncItems: scla2Async,
                  value: selectedScla2,
                  enabled: selectedScla != null,
                  itemValue: (item) => item.scla2,
                  itemLabel: (item) => _formatOption(item.scla2, item.dscla2),
                  onChanged: onScla2Changed,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniField(
                  label: 'SPH',
                  controller: sphCtrl,
                  inputFormatters: numberFormatters,
                  onChanged: (_) => onFilterChanged(),
                ),
                _MiniField(
                  label: 'CYL',
                  controller: cylCtrl,
                  inputFormatters: numberFormatters,
                  onChanged: (_) => onFilterChanged(),
                ),
                _MiniField(
                  label: 'ADIC',
                  controller: adicCtrl,
                  inputFormatters: numberFormatters,
                  onChanged: (_) => onFilterChanged(),
                ),
                ElevatedButton.icon(
                  onPressed: canSearch ? onSearch : null,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                ),
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Limpiar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatOption(double value, String? description) {
    final id = _formatNumber(value);
    final desc = (description ?? '').trim();
    if (desc.isEmpty) return id;
    return '$id - $desc';
  }

  static String _formatNumber(double value) {
    final intValue = value.toInt();
    if (value == intValue) return intValue.toString();
    return value.toString();
  }
}

class _AltaMasivaPreview {
  const _AltaMasivaPreview({
    required this.headers,
    required this.rows,
  });

  final List<String> headers;
  final List<List<String>> rows;
}

class _FilterField extends StatelessWidget {
  const _FilterField({
    required this.label,
    required this.controller,
    required this.width,
    required this.decoration,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final double width;
  final InputDecoration decoration;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: DatArtUiConfig.fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            decoration: decoration,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SearchByDropdown extends StatelessWidget {
  const _SearchByDropdown({
    required this.width,
    required this.value,
    required this.onChanged,
  });

  final double width;
  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        key: ValueKey<String>(value),
        initialValue: value,
        isExpanded: true,
        iconSize: 16,
        style: const TextStyle(fontSize: _FiltersCard._filterFontSize),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: _FiltersCard._filterPadding,
          constraints: BoxConstraints.tightFor(
            height: _FiltersCard._filterHeight,
          ),
          labelText: 'Buscar por',
        ),
        items: const [
          DropdownMenuItem(
            value: 'ART',
            child: Text(
              'ART',
              style: TextStyle(fontSize: _FiltersCard._filterFontSize),
            ),
          ),
          DropdownMenuItem(
            value: 'UPC',
            child: Text(
              'UPC',
              style: TextStyle(fontSize: _FiltersCard._filterFontSize),
            ),
          ),
          DropdownMenuItem(
            value: 'DES',
            child: Text(
              'DES',
              style: TextStyle(fontSize: _FiltersCard._filterFontSize),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _SucDropdown extends StatelessWidget {
  const _SucDropdown({
    required this.label,
    required this.width,
    required this.asyncItems,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double width;
  final AsyncValue<List<SucursalModel>> asyncItems;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: asyncItems.when(
        data: (items) {
          final sorted = [...items]..sort((a, b) => a.suc.compareTo(b.suc));
          final menuItems = <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text(
                '',
                style: TextStyle(fontSize: _FiltersCard._filterFontSize),
              ),
            ),
            ...sorted.map((item) {
              final desc = (item.desc ?? '').trim();
              final label = desc.isEmpty ? item.suc : '${item.suc} - $desc';
              return DropdownMenuItem<String?>(
                value: item.suc,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: _FiltersCard._filterFontSize,
                  ),
                ),
              );
            }),
          ];
          final hasValue =
              value != null && menuItems.any((item) => item.value == value);
          final initialValue = hasValue ? value : null;
          return DropdownButtonFormField<String?>(
            key: ValueKey<String?>(initialValue),
            initialValue: initialValue,
            isExpanded: true,
            iconSize: 16,
            style: const TextStyle(fontSize: _FiltersCard._filterFontSize),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: _FiltersCard._filterPadding,
              constraints: const BoxConstraints.tightFor(
                height: _FiltersCard._filterHeight,
              ),
              labelText: label,
            ),
            items: menuItems,
            onChanged: onChanged,
          );
        },
        loading: () => _buildPlaceholder(),
        error: (_, _) => _buildPlaceholder(message: 'Error'),
      ),
    );
  }

  Widget _buildPlaceholder({String message = '...'}) {
    return InputDecorator(
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: _FiltersCard._filterPadding,
        constraints: const BoxConstraints.tightFor(
          height: _FiltersCard._filterHeight,
        ),
        labelText: label,
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: _FiltersCard._filterFontSize),
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.label,
    required this.controller,
    this.inputFormatters,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: _FiltersCard._filterPadding,
          labelStyle: const TextStyle(fontSize: _FiltersCard._filterFontSize),
          constraints: const BoxConstraints.tightFor(
            height: _FiltersCard._filterHeight,
          ),
          border: const OutlineInputBorder(),
        ),
        style: const TextStyle(fontSize: _FiltersCard._filterFontSize),
      ),
    );
  }
}

class _JrqDropdown<T> extends StatelessWidget {
  const _JrqDropdown({
    required this.label,
    required this.width,
    required this.asyncItems,
    required this.value,
    required this.enabled,
    required this.itemValue,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final double width;
  final AsyncValue<List<T>> asyncItems;
  final double? value;
  final bool enabled;
  final double Function(T) itemValue;
  final String Function(T) itemLabel;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxMenuWidth = screenWidth - 24;
    final menuWidth = min(
      maxMenuWidth,
      max(width, _FiltersCard._filterMenuWidth),
    );
    return SizedBox(
      width: width,
      child: asyncItems.when(
        data: (items) {
          final menuItems = <DropdownMenuItem<double?>>[
            const DropdownMenuItem<double?>(
              value: null,
              child: Text(
                '',
                style: TextStyle(fontSize: _FiltersCard._filterFontSize),
              ),
            ),
            ...items.map(
              (item) => DropdownMenuItem<double?>(
                value: itemValue(item),
                child: Text(
                  itemLabel(item),
                  overflow: TextOverflow.visible,
                  softWrap: true,
                  style: const TextStyle(
                    fontSize: _FiltersCard._filterFontSize,
                  ),
                ),
              ),
            ),
          ];
          final selectedWidgets = <Widget>[
            const Text(
              '',
              style: TextStyle(fontSize: _FiltersCard._filterFontSize),
            ),
            ...items.map(
              (item) => Text(
                itemLabel(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: _FiltersCard._filterFontSize),
              ),
            ),
          ];
          final hasValue =
              value != null && menuItems.any((item) => item.value == value);
          return _buildDropdown(
            context: context,
            menuItems: menuItems,
            selectedItemBuilder: (context) => selectedWidgets,
            value: hasValue ? value : null,
            enabled: enabled,
            menuWidth: menuWidth,
          );
        },
        loading: () => _buildDropdown(
          context: context,
          menuItems: const [
            DropdownMenuItem<double?>(
              value: null,
              child: Text(
                '...',
                style: TextStyle(fontSize: _FiltersCard._filterFontSize),
              ),
            ),
          ],
          value: null,
          enabled: false,
          menuWidth: menuWidth,
        ),
        error: (_, _) => _buildDropdown(
          context: context,
          menuItems: const [
            DropdownMenuItem<double?>(
              value: null,
              child: Text(
                'Err',
                style: TextStyle(fontSize: _FiltersCard._filterFontSize),
              ),
            ),
          ],
          value: null,
          enabled: false,
          menuWidth: menuWidth,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required BuildContext context,
    required List<DropdownMenuItem<double?>> menuItems,
    DropdownButtonBuilder? selectedItemBuilder,
    required double? value,
    required bool enabled,
    required double menuWidth,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: _FiltersCard._filterPadding,
        labelStyle: const TextStyle(fontSize: _FiltersCard._filterFontSize),
        constraints: const BoxConstraints.tightFor(
          height: _FiltersCard._filterHeight,
        ),
      ),
      isEmpty: value == null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double?>(
          key: ValueKey<double?>(value),
          isExpanded: true,
          iconSize: 16,
          value: value,
          items: menuItems,
          selectedItemBuilder: selectedItemBuilder,
          onChanged: enabled ? onChanged : null,
          style: const TextStyle(fontSize: _FiltersCard._filterFontSize),
          itemHeight: null,
          menuWidth: menuWidth,
          isDense: true,
        ),
      ),
    );
  }
}
