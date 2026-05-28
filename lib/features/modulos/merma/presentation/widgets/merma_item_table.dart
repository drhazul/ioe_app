import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../domain/merma_models.dart';

class MermaItemTable extends StatelessWidget {
  const MermaItemTable({
    super.key,
    required this.items,
    this.documentArea,
    this.onEdit,
    this.onDelete,
    this.readOnly = false,
    this.showEvidenceColumn = false,
    this.showAreaColumn = true,
    this.showDescriptionColumn = true,
    this.showObservacionesColumn = true,
    this.showActionsColumn = true,
  });

  final List<MermaDetalleModel> items;
  final String? documentArea;
  final void Function(MermaDetalleModel item)? onEdit;
  final void Function(MermaDetalleModel item)? onDelete;
  final bool readOnly;
  final bool showEvidenceColumn;
  final bool showAreaColumn;
  final bool showDescriptionColumn;
  final bool showObservacionesColumn;
  final bool showActionsColumn;

  @override
  Widget build(BuildContext context) {
    final showEvidence = showEvidenceColumn || readOnly;
    final showActions = showActionsColumn && !readOnly;
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('Sin art\u00EDculos')),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            columnSpacing: 12,
            horizontalMargin: 8,
            columns: [
              const DataColumn(label: Text('ART')),
              if (showDescriptionColumn)
                const DataColumn(label: Text('Descripci\u00F3n')),
              const DataColumn(label: Text('Motivo')),
              const DataColumn(label: Text('CTD')),
              const DataColumn(label: Text('Costo')),
              const DataColumn(label: Text('Total')),
              if (showAreaColumn) const DataColumn(label: Text('Área')),
              const DataColumn(label: Text('Responsable')),
              if (showEvidence) const DataColumn(label: Text('Evidencia')),
              if (showObservacionesColumn)
                const DataColumn(label: Text('Observaciones')),
              if (showActions) const DataColumn(label: Text('Acciones')),
            ],
            rows: items.map((item) {
              final areaText = (item.areaM ?? '').trim().isNotEmpty
                  ? (item.areaM ?? '').trim()
                  : (documentArea ?? '').trim();
              return DataRow(
                cells: [
                  DataCell(Text(item.art)),
                  if (showDescriptionColumn)
                    DataCell(_textCell(item.des, width: 220)),
                  DataCell(_textCell(item.motivo, width: 110)),
                  DataCell(Text(item.ctd.toStringAsFixed(2))),
                  DataCell(Text(item.cto.toStringAsFixed(2))),
                  DataCell(Text(item.ctot.toStringAsFixed(2))),
                  if (showAreaColumn) DataCell(_textCell(areaText, width: 95)),
                  DataCell(_textCell(item.respM, width: 105)),
                  if (showEvidence)
                    DataCell(
                      _EvidenceCell(
                        count: item.evidencias,
                        imageUrl: item.evidenciaUrl,
                        mimeType: item.evidenciaMime,
                      ),
                    ),
                  if (showObservacionesColumn)
                    DataCell(_textCell(item.obsM, width: 190)),
                  if (showActions)
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: onEdit == null ? null : () => onEdit!(item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: onDelete == null
                                ? null
                                : () => onDelete!(item),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _textCell(String? value, {required double width}) {
    final text = (value ?? '').trim();
    return SizedBox(
      width: width,
      child: Tooltip(
        message: text.isEmpty ? '-' : text,
        child: Text(
          text.isEmpty ? '-' : text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _EvidenceCell extends StatelessWidget {
  const _EvidenceCell({required this.count, this.imageUrl, this.mimeType});

  final int count;
  final String? imageUrl;
  final String? mimeType;

  @override
  Widget build(BuildContext context) {
    final hasEvidence = count > 0;
    final url = (imageUrl ?? '').trim();
    final isDataImage = url.startsWith('data:image/');
    final isImageExtension =
        url.toLowerCase().contains('.jpg') ||
        url.toLowerCase().contains('.jpeg') ||
        url.toLowerCase().contains('.png') ||
        url.toLowerCase().contains('.webp') ||
        url.toLowerCase().contains('.gif');
    final isImage =
        isDataImage ||
        (url.isNotEmpty &&
            ((mimeType ?? '').toLowerCase().startsWith('image/') ||
                isImageExtension));
    final bgColor = hasEvidence
        ? Colors.teal.withValues(alpha: 0.12)
        : Colors.grey.withValues(alpha: 0.12);
    final fgColor = hasEvidence ? Colors.teal.shade800 : Colors.grey.shade700;
    final dataBytes = isDataImage ? _decodeDataUrlImage(url) : null;
    final canPreview = isImage && ((isDataImage && dataBytes != null) || url.isNotEmpty);

    if (canPreview) {
      return GestureDetector(
        onTap: () => _openPreview(context, url, imageBytes: dataBytes),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.teal.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: dataBytes != null
                ? Image.memory(
                    dataBytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => _fallbackChip(
                      bgColor: bgColor,
                      fgColor: fgColor,
                      hasEvidence: hasEvidence,
                    ),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) => _fallbackChip(
                      bgColor: bgColor,
                      fgColor: fgColor,
                      hasEvidence: hasEvidence,
                    ),
                  ),
          ),
        ),
      );
    }

    return _fallbackChip(
      bgColor: bgColor,
      fgColor: fgColor,
      hasEvidence: hasEvidence,
    );
  }

  Widget _fallbackChip({
    required Color bgColor,
    required Color fgColor,
    required bool hasEvidence,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: hasEvidence ? Colors.teal.shade200 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasEvidence ? Icons.photo_camera : Icons.photo_camera_outlined,
            size: 16,
            color: fgColor,
          ),
          const SizedBox(width: 6),
          Text(
            hasEvidence ? '$count foto${count == 1 ? '' : 's'}' : 'Sin foto',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }

  Uint8List? _decodeDataUrlImage(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (comma <= 0 || comma >= dataUrl.length - 1) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  void _openPreview(
    BuildContext context,
    String url, {
    Uint8List? imageBytes,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                automaticallyImplyLeading: false,
                title: const Text('Evidencia'),
                actions: [
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: imageBytes != null
                      ? Image.memory(
                          imageBytes,
                          fit: BoxFit.contain,
                          errorBuilder: (_, error, stackTrace) => const Center(
                            child: Text('No se pudo cargar la imagen'),
                          ),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, error, stackTrace) => const Center(
                            child: Text('No se pudo cargar la imagen'),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
