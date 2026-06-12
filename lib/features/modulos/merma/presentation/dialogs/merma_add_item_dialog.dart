import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ioe_app/core/api_error.dart';
import 'package:ioe_app/core/dio_provider.dart';
import 'package:ioe_app/features/modulos/catalogo/datart_models.dart';
import 'package:ioe_app/features/modulos/catalogo/datart_providers.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/detalle_cot/jrq_api.dart';
import 'package:ioe_app/features/modulos/punto_venta/cotizaciones/detalle_cot/jrq_models.dart';

import '../../domain/merma_models.dart';

class MermaAddItemDialog extends ConsumerStatefulWidget {
  const MermaAddItemDialog({
    super.key,
    required this.motivos,
    required this.areas,
    required this.suc,
    this.initialArt,
    this.initialCtd,
    this.initialMotM,
    this.initialAreaM,
    this.initialRespM,
    this.initialObsM,
    this.initialHasEvidence = false,
  });

  final List<MermaCatalogOptionModel> motivos;
  final List<MermaCatalogOptionModel> areas;
  final String suc;
  final String? initialArt;
  final double? initialCtd;
  final int? initialMotM;
  final String? initialAreaM;
  final String? initialRespM;
  final String? initialObsM;
  final bool initialHasEvidence;

  @override
  ConsumerState<MermaAddItemDialog> createState() => _MermaAddItemDialogState();
}

class _MermaAddItemDialogState extends ConsumerState<MermaAddItemDialog> {
  late final TextEditingController _artCtrl;
  late final TextEditingController _ctdCtrl;
  late final TextEditingController _respCtrl;
  late final TextEditingController _obsCtrl;
  int? _motM;
  String? _areaM;
  bool _searchingArticulo = false;
  bool _pickingEvidence = false;
  bool _hadExistingEvidence = false;
  Uint8List? _evidenceBytes;
  String? _evidenceMime;
  String? _evidenceName;
  final ImagePicker _imagePicker = ImagePicker();
  static const int _maxEvidenceBytes = 500 * 1024;

  @override
  void initState() {
    super.initState();
    _artCtrl = TextEditingController(text: widget.initialArt ?? '');
    _ctdCtrl = TextEditingController(
      text: (widget.initialCtd ?? 1).toStringAsFixed(2),
    );
    _respCtrl = TextEditingController(text: widget.initialRespM ?? '');
    _obsCtrl = TextEditingController(text: widget.initialObsM ?? '');
    _motM = _normalizeDropdownValue(widget.initialMotM, widget.motivos);
    _areaM = _normalizeAreaValue(widget.initialAreaM, widget.areas);
    _hadExistingEvidence = widget.initialHasEvidence;
  }

  @override
  void dispose() {
    _artCtrl.dispose();
    _ctdCtrl.dispose();
    _respCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motivos = _dedupeOptionsById(widget.motivos);
    final selectedMotivo = _normalizeDropdownValue(_motM, motivos);
    final motivoRequiereEvidencia = _motivoRequiereEvidencia(
      motivos,
      selectedMotivo,
    );
    final areas = _dedupeAreaOptions(widget.areas);
    final selectedArea = _normalizeAreaValue(_areaM, areas);
    return AlertDialog(
      title: const Text('Artículo merma'),
      content: SizedBox(
        width: 500,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _artCtrl,
                  decoration: InputDecoration(
                    labelText: 'Artículo',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: 'Buscar artículo',
                      onPressed: _searchingArticulo
                          ? null
                          : _openBuscarArticuloDialog,
                      icon: _searchingArticulo
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ctdCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: selectedMotivo,
                  decoration: const InputDecoration(
                    labelText: 'Motivo',
                    border: OutlineInputBorder(),
                  ),
                  items: motivos
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(
                            '${m.id} - ${m.desc}${_readMotivoRequiresEvidence(m) ? ' (EVIDENCIA OBLIGATORIA)' : ''}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _motM = value),
                ),
                if (selectedMotivo != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      motivoRequiereEvidencia
                          ? 'Este motivo requiere evidencia obligatoria.'
                          : 'Este motivo no requiere evidencia obligatoria.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: motivoRequiereEvidencia
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedArea,
                  hint: const Text('Seleccionar área'),
                  decoration: const InputDecoration(
                    labelText: 'Área responsable',
                    border: OutlineInputBorder(),
                  ),
                  items: areas
                      .map(
                        (a) => DropdownMenuItem<String>(
                          value: a.desc,
                          child: Text('${a.id} - ${a.desc}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _areaM = value?.trim()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _respCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Responsable (persona)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _obsCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                _buildEvidenceInput(context),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final art = _artCtrl.text.trim();
            final ctd =
                double.tryParse(_ctdCtrl.text.trim().replaceAll(',', '.')) ?? 0;
            if (art.isEmpty || ctd <= 0 || (_motM ?? 0) <= 0) return;
            final evidenceDataUrl = _buildEvidenceDataUrl();
            final hasEvidence =
                (evidenceDataUrl ?? '').trim().isNotEmpty ||
                _hadExistingEvidence;
            if (motivoRequiereEvidencia && !hasEvidence) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'El motivo seleccionado requiere evidencia. Adjunta una imagen para continuar.',
                  ),
                ),
              );
              return;
            }
            Navigator.of(context).pop({
              'art': art,
              'ctd': ctd,
              'motM': _motM,
              'areaM': (_areaM ?? '').trim(),
              'respM': _respCtrl.text.trim(),
              'obsM': _obsCtrl.text.trim(),
              if (evidenceDataUrl != null) 'eviM': evidenceDataUrl,
            });
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _openBuscarArticuloDialog() async {
    setState(() => _searchingArticulo = true);
    try {
      final selected = await _showBuscarArticuloDialog(suc: widget.suc);
      if (!mounted || selected == null) return;
      setState(() => _artCtrl.text = selected.art.trim());
    } finally {
      if (mounted) setState(() => _searchingArticulo = false);
    }
  }

  int? _normalizeDropdownValue(
    int? value,
    List<MermaCatalogOptionModel> options,
  ) {
    if (value == null || value <= 0) return null;
    var matches = 0;
    for (final option in options) {
      if (option.id == value) matches++;
    }
    return matches == 1 ? value : null;
  }

  bool _motivoRequiereEvidencia(
    List<MermaCatalogOptionModel> motivos,
    int? motivoId,
  ) {
    if (motivoId == null) return false;
    for (final motivo in motivos) {
      if (motivo.id == motivoId) {
        return _readMotivoRequiresEvidence(motivo);
      }
    }
    return false;
  }

  bool _readMotivoRequiresEvidence(MermaCatalogOptionModel motivo) {
    final dynamic raw =
        motivo.meta['requiereEvidencia'] ?? motivo.meta['REQUIERE_EVIDENCIA'];
    if (raw is bool) return raw;
    if (raw is num) return raw > 0;
    final text = (raw ?? '').toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'si' || text == 'yes';
  }

  List<MermaCatalogOptionModel> _dedupeOptionsById(
    List<MermaCatalogOptionModel> options,
  ) {
    final seen = <int>{};
    final result = <MermaCatalogOptionModel>[];
    for (final option in options) {
      if (option.id <= 0) continue;
      if (seen.add(option.id)) result.add(option);
    }
    return result;
  }

  List<MermaCatalogOptionModel> _dedupeAreaOptions(
    List<MermaCatalogOptionModel> options,
  ) {
    final seen = <String>{};
    final result = <MermaCatalogOptionModel>[];
    for (final option in options) {
      final area = option.desc.trim();
      if (area.isEmpty) continue;
      final key = area.toUpperCase();
      if (seen.add(key)) result.add(option);
    }
    return result;
  }

  String? _normalizeAreaValue(
    String? value,
    List<MermaCatalogOptionModel> options,
  ) {
    final area = (value ?? '').trim();
    if (area.isEmpty) return null;
    for (final option in options) {
      if (option.desc.trim().toUpperCase() == area.toUpperCase()) {
        return option.desc.trim();
      }
    }
    return null;
  }

  Widget _buildEvidenceInput(BuildContext context) {
    final hasNewEvidence = _evidenceBytes != null;
    final hasExistingEvidence = _hadExistingEvidence && !hasNewEvidence;
    final evidenceText = hasNewEvidence
        ? (_evidenceName?.trim().isNotEmpty == true
              ? _evidenceName!.trim()
              : 'Evidencia seleccionada')
        : hasExistingEvidence
        ? 'Ya existe evidencia para este articulo'
        : 'Sin evidencia';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickingEvidence ? null : _pickEvidence,
                icon: _pickingEvidence
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera_outlined),
                label: const Text('Adjuntar evidencia'),
              ),
            ),
            if (hasNewEvidence) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Quitar evidencia nueva',
                onPressed: () {
                  setState(() {
                    _evidenceBytes = null;
                    _evidenceMime = null;
                    _evidenceName = null;
                  });
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(evidenceText, style: Theme.of(context).textTheme.bodySmall),
        if (hasNewEvidence) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _evidenceBytes!,
              width: double.infinity,
              height: 140,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) => Container(
                width: double.infinity,
                height: 100,
                alignment: Alignment.center,
                color: Colors.grey.shade200,
                child: const Text('No se pudo previsualizar la imagen'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickEvidence() async {
    final source = await showModalBottomSheet<_EvidenceInputSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(ctx).pop(_EvidenceInputSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galeria'),
              onTap: () => Navigator.of(ctx).pop(_EvidenceInputSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Elegir archivo de imagen'),
              onTap: () => Navigator.of(ctx).pop(_EvidenceInputSource.file),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _pickingEvidence = true);
    try {
      final picked = switch (source) {
        _EvidenceInputSource.camera => await _pickFromCamera(),
        _EvidenceInputSource.gallery => await _pickFromGallery(),
        _EvidenceInputSource.file => await _pickFromFile(),
      };
      if (picked == null || !mounted) return;
      setState(() {
        _evidenceBytes = picked.bytes;
        _evidenceMime = picked.mimeType;
        _evidenceName = picked.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo adjuntar evidencia: $e')),
      );
    } finally {
      if (mounted) setState(() => _pickingEvidence = false);
    }
  }

  Future<_PickedEvidence?> _pickFromCamera() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file == null) return null;
    final raw = await file.readAsBytes();
    return _prepareEvidence(
      bytes: raw,
      suggestedName: file.name,
      extensionHint: _extractExtension(file.name),
    );
  }

  Future<_PickedEvidence?> _pickFromGallery() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return null;
    final raw = await file.readAsBytes();
    return _prepareEvidence(
      bytes: raw,
      suggestedName: file.name,
      extensionHint: _extractExtension(file.name),
    );
  }

  Future<_PickedEvidence?> _pickFromFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final file = picked.files.first;
    final data = file.bytes;
    if (data == null || data.isEmpty) return null;
    return _prepareEvidence(
      bytes: data,
      suggestedName: file.name,
      extensionHint: _extractExtension(file.name),
    );
  }

  Future<_PickedEvidence> _prepareEvidence({
    required Uint8List bytes,
    required String suggestedName,
    String? extensionHint,
  }) async {
    final ext = (extensionHint ?? '').toLowerCase();
    final compressed = await _compressImage(bytes, ext);
    return _PickedEvidence(
      bytes: compressed.bytes,
      mimeType: compressed.mimeType,
      name: _normalizeEvidenceName(suggestedName, compressed.mimeType),
    );
  }

  Future<_CompressedEvidence> _compressImage(
    Uint8List bytes,
    String extension,
  ) async {
    final originalMime = _mimeForExtension(extension);
    var bestBytes = bytes;
    var bestMime = originalMime;
    const widths = [1280, 1024, 800, 640];
    const qualities = [78, 68, 58, 48];

    for (final width in widths) {
      for (final quality in qualities) {
        try {
          final compressed = await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: width,
            minHeight: width,
            quality: quality,
            format: CompressFormat.jpeg,
          );
          if (compressed.isEmpty) continue;
          if (compressed.length < bestBytes.length ||
              bestBytes.length > _maxEvidenceBytes) {
            bestBytes = compressed;
            bestMime = 'image/jpeg';
          }
          if (bestBytes.length <= _maxEvidenceBytes) {
            return _CompressedEvidence(bestBytes, bestMime);
          }
        } catch (_) {}
      }
    }

    if (bestBytes.length <= _maxEvidenceBytes) {
      return _CompressedEvidence(bestBytes, bestMime);
    }

    throw Exception(
      'La imagen supera 500 KB aun despues de comprimirla. Intenta con otra foto mas ligera.',
    );
  }

  String _mimeForExtension(String extension) {
    if (extension == 'png') return 'image/png';
    if (extension == 'webp') return 'image/webp';
    if (extension == 'gif') return 'image/gif';
    return 'image/jpeg';
  }

  String _normalizeEvidenceName(String suggestedName, String mimeType) {
    final cleanName = suggestedName.trim().isEmpty
        ? 'evidencia'
        : suggestedName.trim();
    if (mimeType != 'image/jpeg') return cleanName;
    final index = cleanName.lastIndexOf('.');
    final base = index <= 0 ? cleanName : cleanName.substring(0, index);
    return '$base.jpg';
  }

  String _extractExtension(String name) {
    final index = name.lastIndexOf('.');
    if (index <= 0 || index >= name.length - 1) return '';
    return name.substring(index + 1);
  }

  String? _buildEvidenceDataUrl() {
    final bytes = _evidenceBytes;
    if (bytes == null || bytes.isEmpty) return null;
    final mime = (_evidenceMime ?? 'image/jpeg').trim();
    final encoded = base64Encode(bytes);
    return 'data:$mime;base64,$encoded';
  }

  Future<DatArtModel?> _showBuscarArticuloDialog({required String suc}) async {
    final searchCtrl = TextEditingController();
    final searchFocus = FocusNode();
    final sphCtrl = TextEditingController();
    final cylCtrl = TextEditingController();
    final adicCtrl = TextEditingController();
    final datArtApi = ref.read(datArtApiProvider);
    final jrqApi = JrqApi(ref.read(dioProvider));

    var searchBy = 'DES';
    var loadingResults = false;
    var loadingFilters = false;
    var initialized = false;
    String? errorText;
    String? filterError;
    var hasAppliedSearch = false;
    List<DatArtModel> items = const <DatArtModel>[];
    List<JrqDepaModel> depaItems = const <JrqDepaModel>[];
    List<JrqSubdModel> subdItems = const <JrqSubdModel>[];
    List<JrqClasModel> clasItems = const <JrqClasModel>[];
    List<JrqSclaModel> sclaItems = const <JrqSclaModel>[];
    List<JrqScla2Model> scla2Items = const <JrqScla2Model>[];
    double? selectedDepa;
    double? selectedSubd;
    double? selectedClas;
    double? selectedScla;
    double? selectedScla2;

    double? parseFilterNumber(String value) {
      final normalized = value.trim().replaceAll(',', '.');
      if (normalized.isEmpty) return null;
      return double.tryParse(normalized);
    }

    bool hasCriteria() {
      return searchCtrl.text.trim().isNotEmpty ||
          selectedDepa != null ||
          selectedSubd != null ||
          selectedClas != null ||
          selectedScla != null ||
          selectedScla2 != null ||
          parseFilterNumber(sphCtrl.text) != null ||
          parseFilterNumber(cylCtrl.text) != null ||
          parseFilterNumber(adicCtrl.text) != null;
    }

    Future<void> loadDepa(StateSetter setDialogState) async {
      setDialogState(() {
        loadingFilters = true;
        filterError = null;
      });
      try {
        final found = await jrqApi.fetchDepa();
        if (!mounted) return;
        setDialogState(() => depaItems = found);
      } catch (e) {
        if (!mounted) return;
        setDialogState(
          () => filterError = apiErrorMessage(
            e,
            fallback: 'No se pudieron cargar los filtros de articulos.',
          ),
        );
      } finally {
        if (mounted) setDialogState(() => loadingFilters = false);
      }
    }

    Future<void> loadSubd(StateSetter setDialogState, double? depa) async {
      if (depa == null) {
        setDialogState(() {
          subdItems = const <JrqSubdModel>[];
          clasItems = const <JrqClasModel>[];
          sclaItems = const <JrqSclaModel>[];
          scla2Items = const <JrqScla2Model>[];
          selectedSubd = null;
          selectedClas = null;
          selectedScla = null;
          selectedScla2 = null;
        });
        return;
      }
      setDialogState(() {
        loadingFilters = true;
        filterError = null;
        selectedSubd = null;
        selectedClas = null;
        selectedScla = null;
        selectedScla2 = null;
        subdItems = const <JrqSubdModel>[];
        clasItems = const <JrqClasModel>[];
        sclaItems = const <JrqSclaModel>[];
        scla2Items = const <JrqScla2Model>[];
      });
      try {
        final found = await jrqApi.fetchSubd(depa: depa);
        if (!mounted) return;
        setDialogState(() => subdItems = found);
      } catch (e) {
        if (!mounted) return;
        setDialogState(
          () => filterError = apiErrorMessage(
            e,
            fallback: 'No se pudo cargar SDEP.',
          ),
        );
      } finally {
        if (mounted) setDialogState(() => loadingFilters = false);
      }
    }

    Future<void> loadClas(StateSetter setDialogState, double? subd) async {
      if (subd == null) {
        setDialogState(() {
          clasItems = const <JrqClasModel>[];
          sclaItems = const <JrqSclaModel>[];
          scla2Items = const <JrqScla2Model>[];
          selectedClas = null;
          selectedScla = null;
          selectedScla2 = null;
        });
        return;
      }
      setDialogState(() {
        loadingFilters = true;
        filterError = null;
        selectedClas = null;
        selectedScla = null;
        selectedScla2 = null;
        clasItems = const <JrqClasModel>[];
        sclaItems = const <JrqSclaModel>[];
        scla2Items = const <JrqScla2Model>[];
      });
      try {
        final found = await jrqApi.fetchClas(subd: subd);
        if (!mounted) return;
        setDialogState(() => clasItems = found);
      } catch (e) {
        if (!mounted) return;
        setDialogState(
          () => filterError = apiErrorMessage(
            e,
            fallback: 'No se pudo cargar CLS.',
          ),
        );
      } finally {
        if (mounted) setDialogState(() => loadingFilters = false);
      }
    }

    Future<void> loadScla(StateSetter setDialogState, double? clas) async {
      if (clas == null) {
        setDialogState(() {
          sclaItems = const <JrqSclaModel>[];
          scla2Items = const <JrqScla2Model>[];
          selectedScla = null;
          selectedScla2 = null;
        });
        return;
      }
      setDialogState(() {
        loadingFilters = true;
        filterError = null;
        selectedScla = null;
        selectedScla2 = null;
        sclaItems = const <JrqSclaModel>[];
        scla2Items = const <JrqScla2Model>[];
      });
      try {
        final found = await jrqApi.fetchScla(clas: clas);
        if (!mounted) return;
        setDialogState(() => sclaItems = found);
      } catch (e) {
        if (!mounted) return;
        setDialogState(
          () => filterError = apiErrorMessage(
            e,
            fallback: 'No se pudo cargar SCLS.',
          ),
        );
      } finally {
        if (mounted) setDialogState(() => loadingFilters = false);
      }
    }

    Future<void> loadScla2(StateSetter setDialogState, double? scla) async {
      if (scla == null) {
        setDialogState(() {
          scla2Items = const <JrqScla2Model>[];
          selectedScla2 = null;
        });
        return;
      }
      setDialogState(() {
        loadingFilters = true;
        filterError = null;
        selectedScla2 = null;
        scla2Items = const <JrqScla2Model>[];
      });
      try {
        final found = await jrqApi.fetchScla2(scla: scla);
        if (!mounted) return;
        setDialogState(() => scla2Items = found);
      } catch (e) {
        if (!mounted) return;
        setDialogState(
          () => filterError = apiErrorMessage(
            e,
            fallback: 'No se pudo cargar SCLS2.',
          ),
        );
      } finally {
        if (mounted) setDialogState(() => loadingFilters = false);
      }
    }

    Future<void> clearSearch(StateSetter setDialogState) async {
      setDialogState(() {
        searchBy = 'DES';
        searchCtrl.clear();
        sphCtrl.clear();
        cylCtrl.clear();
        adicCtrl.clear();
        selectedDepa = null;
        selectedSubd = null;
        selectedClas = null;
        selectedScla = null;
        selectedScla2 = null;
        subdItems = const <JrqSubdModel>[];
        clasItems = const <JrqClasModel>[];
        sclaItems = const <JrqSclaModel>[];
        scla2Items = const <JrqScla2Model>[];
        items = const <DatArtModel>[];
        hasAppliedSearch = false;
        errorText = null;
        filterError = null;
      });
    }

    Future<void> runSearch(StateSetter setDialogState) async {
      final term = searchCtrl.text.trim();
      final sph = parseFilterNumber(sphCtrl.text);
      final cyl = parseFilterNumber(cylCtrl.text);
      final adic = parseFilterNumber(adicCtrl.text);

      if (!hasCriteria()) {
        setDialogState(
          () => errorText =
              'Captura un criterio o selecciona filtros para buscar articulos.',
        );
        return;
      }

      setDialogState(() {
        loadingResults = true;
        errorText = null;
        hasAppliedSearch = true;
      });

      try {
        final found = await datArtApi.fetchArticulos(
          suc: suc,
          sucExact: true,
          art: searchBy == 'ART' && term.isNotEmpty ? term : null,
          upc: searchBy == 'UPC' && term.isNotEmpty ? term : null,
          des: searchBy == 'DES' && term.isNotEmpty ? term : null,
          modelo: searchBy == 'MODELO' && term.isNotEmpty ? term : null,
          depa: selectedDepa,
          subd: selectedSubd,
          clas: selectedClas,
          scla: selectedScla,
          scla2: selectedScla2,
          sph: sph,
          cyl: cyl,
          adic: adic,
          limit: 200,
          view: 'lite',
        );
        if (!mounted) return;
        setDialogState(() {
          items = found;
          if (items.isEmpty) {
            errorText = 'Sin articulos para el criterio capturado.';
          }
        });
      } catch (e) {
        if (!mounted) return;
        setDialogState(
          () => errorText = apiErrorMessage(
            e,
            fallback: 'No se pudo consultar DAT_ART.',
          ),
        );
      } finally {
        if (mounted) setDialogState(() => loadingResults = false);
      }
    }

    final selected = await showDialog<DatArtModel>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (!initialized) {
            initialized = true;
            unawaited(loadDepa(setDialogState));
          }
          final enabled = !loadingResults;
          return AlertDialog(
            title: const Text('Buscar articulo'),
            contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            content: SizedBox(
              width: 1080,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MermaArticuloSearchFilters(
                    searchCtrl: searchCtrl,
                    searchFocus: searchFocus,
                    sphCtrl: sphCtrl,
                    cylCtrl: cylCtrl,
                    adicCtrl: adicCtrl,
                    searchBy: searchBy,
                    enabled: enabled,
                    loadingFilters: loadingFilters,
                    depaItems: depaItems,
                    subdItems: subdItems,
                    clasItems: clasItems,
                    sclaItems: sclaItems,
                    scla2Items: scla2Items,
                    selectedDepa: selectedDepa,
                    selectedSubd: selectedSubd,
                    selectedClas: selectedClas,
                    selectedScla: selectedScla,
                    selectedScla2: selectedScla2,
                    onSearchByChanged: (value) {
                      setDialogState(() => searchBy = value ?? 'DES');
                    },
                    onDepaChanged: (value) async {
                      setDialogState(() => selectedDepa = value);
                      await loadSubd(setDialogState, value);
                    },
                    onSubdChanged: (value) async {
                      setDialogState(() => selectedSubd = value);
                      await loadClas(setDialogState, value);
                    },
                    onClasChanged: (value) async {
                      setDialogState(() => selectedClas = value);
                      await loadScla(setDialogState, value);
                    },
                    onSclaChanged: (value) async {
                      setDialogState(() => selectedScla = value);
                      await loadScla2(setDialogState, value);
                    },
                    onScla2Changed: (value) {
                      setDialogState(() => selectedScla2 = value);
                    },
                    onSearchApply: () => runSearch(setDialogState),
                    onClearSearch: () => clearSearch(setDialogState),
                  ),
                  if ((filterError ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        filterError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Consulta clonada de cotizaciones para sucursal $suc.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (loadingResults) const LinearProgressIndicator(),
                  if ((errorText ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        errorText!,
                        style: TextStyle(
                          color: items.isEmpty ? Colors.black54 : Colors.red,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Flexible(
                    child: _MermaArticuloResultsTable(
                      items: items,
                      loading: loadingResults,
                      hasSearchCriteria: hasAppliedSearch || hasCriteria(),
                      onSelect: (item) => Navigator.of(ctx).pop(item),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          );
        },
      ),
    );

    searchCtrl.dispose();
    searchFocus.dispose();
    sphCtrl.dispose();
    cylCtrl.dispose();
    adicCtrl.dispose();
    return selected;
  }
}

class _MermaArticuloSearchFilters extends StatelessWidget {
  const _MermaArticuloSearchFilters({
    required this.searchCtrl,
    required this.searchFocus,
    required this.sphCtrl,
    required this.cylCtrl,
    required this.adicCtrl,
    required this.searchBy,
    required this.enabled,
    required this.loadingFilters,
    required this.depaItems,
    required this.subdItems,
    required this.clasItems,
    required this.sclaItems,
    required this.scla2Items,
    required this.selectedDepa,
    required this.selectedSubd,
    required this.selectedClas,
    required this.selectedScla,
    required this.selectedScla2,
    required this.onSearchByChanged,
    required this.onDepaChanged,
    required this.onSubdChanged,
    required this.onClasChanged,
    required this.onSclaChanged,
    required this.onScla2Changed,
    required this.onSearchApply,
    required this.onClearSearch,
  });

  static const double _filterHeight = 36;
  static const double _filterFontSize = 11;
  static const EdgeInsets _filterPadding = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 8,
  );

  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final TextEditingController sphCtrl;
  final TextEditingController cylCtrl;
  final TextEditingController adicCtrl;
  final String searchBy;
  final bool enabled;
  final bool loadingFilters;
  final List<JrqDepaModel> depaItems;
  final List<JrqSubdModel> subdItems;
  final List<JrqClasModel> clasItems;
  final List<JrqSclaModel> sclaItems;
  final List<JrqScla2Model> scla2Items;
  final double? selectedDepa;
  final double? selectedSubd;
  final double? selectedClas;
  final double? selectedScla;
  final double? selectedScla2;
  final ValueChanged<String?> onSearchByChanged;
  final ValueChanged<double?> onDepaChanged;
  final ValueChanged<double?> onSubdChanged;
  final ValueChanged<double?> onClasChanged;
  final ValueChanged<double?> onSclaChanged;
  final ValueChanged<double?> onScla2Changed;
  final VoidCallback onSearchApply;
  final VoidCallback onClearSearch;

  static String _formatOption(double value, String? description) {
    final intValue = value.toInt();
    final left = value == intValue ? intValue.toString() : value.toString();
    final desc = (description ?? '').trim();
    return desc.isEmpty ? left : '$left - $desc';
  }

  @override
  Widget build(BuildContext context) {
    final filtersEnabled = enabled && !loadingFilters;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFD5EEF9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buscar por:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  initialValue: searchBy,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: _filterPadding,
                    constraints: BoxConstraints.tightFor(height: _filterHeight),
                  ),
                  style: const TextStyle(
                    fontSize: _filterFontSize,
                    color: Colors.black87,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ART', child: Text('ART')),
                    DropdownMenuItem(value: 'UPC', child: Text('UPC')),
                    DropdownMenuItem(value: 'DES', child: Text('DES')),
                    DropdownMenuItem(value: 'MODELO', child: Text('MODELO')),
                  ],
                  onChanged: filtersEnabled ? onSearchByChanged : null,
                ),
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: searchCtrl,
                  focusNode: searchFocus,
                  enabled: filtersEnabled,
                  onSubmitted: filtersEnabled ? (_) => onSearchApply() : null,
                  style: const TextStyle(fontSize: _filterFontSize),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: _filterPadding,
                    constraints: BoxConstraints.tightFor(height: _filterHeight),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MermaJrqDropdown<JrqDepaModel>(
                label: 'DEP',
                width: 82,
                items: depaItems,
                value: selectedDepa,
                enabled: filtersEnabled,
                itemValue: (item) => item.depa,
                itemLabel: (item) => _formatOption(item.depa, item.ddepa),
                onChanged: onDepaChanged,
              ),
              _MermaJrqDropdown<JrqSubdModel>(
                label: 'SDEP',
                width: 82,
                items: subdItems,
                value: selectedSubd,
                enabled: filtersEnabled && selectedDepa != null,
                itemValue: (item) => item.subd,
                itemLabel: (item) => _formatOption(item.subd, item.dsubd),
                onChanged: onSubdChanged,
              ),
              _MermaJrqDropdown<JrqClasModel>(
                label: 'CLS',
                width: 82,
                items: clasItems,
                value: selectedClas,
                enabled: filtersEnabled && selectedSubd != null,
                itemValue: (item) => item.clas,
                itemLabel: (item) => _formatOption(item.clas, item.dclas),
                onChanged: onClasChanged,
              ),
              _MermaJrqDropdown<JrqSclaModel>(
                label: 'SCLS',
                width: 82,
                items: sclaItems,
                value: selectedScla,
                enabled: filtersEnabled && selectedClas != null,
                itemValue: (item) => item.scla,
                itemLabel: (item) => _formatOption(item.scla, item.dscla),
                onChanged: onSclaChanged,
              ),
              _MermaJrqDropdown<JrqScla2Model>(
                label: 'SCLS2',
                width: 92,
                items: scla2Items,
                value: selectedScla2,
                enabled: filtersEnabled && selectedScla != null,
                itemValue: (item) => item.scla2,
                itemLabel: (item) => _formatOption(item.scla2, item.dscla2),
                onChanged: onScla2Changed,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MermaMiniField(
                label: 'SPH',
                controller: sphCtrl,
                enabled: filtersEnabled,
              ),
              _MermaMiniField(
                label: 'CYL',
                controller: cylCtrl,
                enabled: filtersEnabled,
              ),
              _MermaMiniField(
                label: 'ADIC',
                controller: adicCtrl,
                enabled: filtersEnabled,
              ),
              IconButton(
                tooltip: 'Buscar',
                onPressed: filtersEnabled ? onSearchApply : null,
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: 'Limpiar',
                onPressed: filtersEnabled ? onClearSearch : null,
                icon: const Icon(Icons.clear),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MermaMiniField extends StatelessWidget {
  const _MermaMiniField({
    required this.label,
    required this.controller,
    required this.enabled,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: _MermaArticuloSearchFilters._filterPadding,
        ).copyWith(labelText: label),
        style: const TextStyle(
          fontSize: _MermaArticuloSearchFilters._filterFontSize,
        ),
      ),
    );
  }
}

class _MermaJrqDropdown<T> extends StatelessWidget {
  const _MermaJrqDropdown({
    required this.label,
    required this.width,
    required this.items,
    required this.value,
    required this.enabled,
    required this.itemValue,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final double width;
  final List<T> items;
  final double? value;
  final bool enabled;
  final double Function(T item) itemValue;
  final String Function(T item) itemLabel;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final menuItems = <DropdownMenuItem<double?>>[
      const DropdownMenuItem<double?>(value: null, child: Text('')),
      ...items.map(
        (item) => DropdownMenuItem<double?>(
          value: itemValue(item),
          child: Text(
            itemLabel(item),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: _MermaArticuloSearchFilters._filterFontSize,
            ),
          ),
        ),
      ),
    ];
    final selectedValue =
        value != null && menuItems.any((item) => item.value == value)
        ? value
        : null;
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<double?>(
        key: ValueKey<double?>(selectedValue),
        initialValue: selectedValue,
        isExpanded: true,
        style: const TextStyle(
          fontSize: _MermaArticuloSearchFilters._filterFontSize,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: _MermaArticuloSearchFilters._filterPadding,
          constraints: const BoxConstraints.tightFor(
            height: _MermaArticuloSearchFilters._filterHeight,
          ),
        ),
        items: menuItems,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _MermaArticuloResultsTable extends StatelessWidget {
  const _MermaArticuloResultsTable({
    required this.items,
    required this.loading,
    required this.hasSearchCriteria,
    required this.onSelect,
  });

  final List<DatArtModel> items;
  final bool loading;
  final bool hasSearchCriteria;
  final ValueChanged<DatArtModel> onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _MermaResultHeader(),
            const Divider(height: 1),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : !hasSearchCriteria
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Ingresa un criterio o selecciona filtros para ver articulos.',
                      ),
                    )
                  : items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Sin resultados para mostrar.'),
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final item = items[index];
                        final stock = item.stock == null
                            ? '-'
                            : item.stock!.toStringAsFixed(2);
                        final pvta = item.pvta == null
                            ? '-'
                            : '\$${item.pvta!.toStringAsFixed(2)}';
                        return SizedBox(
                          height: 34,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: IconButton(
                                  tooltip: 'Seleccionar',
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                  ),
                                  onPressed: () => onSelect(item),
                                ),
                              ),
                              _MermaResultCell(width: 90, text: item.art),
                              _MermaResultCell(width: 120, text: item.upc),
                              Expanded(
                                child: _MermaResultCell(
                                  width: null,
                                  text: item.des ?? '-',
                                ),
                              ),
                              _MermaResultCell(width: 100, text: stock),
                              _MermaResultCell(width: 90, text: pvta),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MermaResultHeader extends StatelessWidget {
  const _MermaResultHeader();

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(fontWeight: FontWeight.w600);
    return const SizedBox(
      height: 30,
      child: Row(
        children: [
          SizedBox(width: 40),
          _MermaResultCell(width: 90, text: 'ART', style: headerStyle),
          _MermaResultCell(width: 120, text: 'UPC', style: headerStyle),
          Expanded(
            child: _MermaResultCell(
              width: null,
              text: 'DES',
              style: headerStyle,
            ),
          ),
          _MermaResultCell(width: 100, text: 'STOCK', style: headerStyle),
          _MermaResultCell(width: 90, text: 'PVTA', style: headerStyle),
        ],
      ),
    );
  }
}

class _MermaResultCell extends StatelessWidget {
  const _MermaResultCell({required this.width, required this.text, this.style});

  final double? width;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
    if (width == null) return child;
    return SizedBox(width: width, child: child);
  }
}

enum _EvidenceInputSource { camera, gallery, file }

class _CompressedEvidence {
  const _CompressedEvidence(this.bytes, this.mimeType);

  final Uint8List bytes;
  final String mimeType;
}

class _PickedEvidence {
  const _PickedEvidence({
    required this.bytes,
    required this.mimeType,
    required this.name,
  });

  final Uint8List bytes;
  final String mimeType;
  final String name;
}
