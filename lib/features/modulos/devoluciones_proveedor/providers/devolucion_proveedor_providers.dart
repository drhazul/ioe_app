import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/dio_provider.dart';
import '../data/devolucion_proveedor_api.dart';
import '../domain/devolucion_proveedor_models.dart';

final devolucionProveedorApiProvider = Provider(
  (ref) => DevolucionProveedorApi(ref.read(dioProvider)),
);
final devTypesProvider = FutureProvider.autoDispose<List<DevOption>>(
  (ref) => ref.read(devolucionProveedorApiProvider).types(),
);
final devReasonsProvider = FutureProvider.autoDispose<List<DevOption>>(
  (ref) => ref.read(devolucionProveedorApiProvider).reasons(),
);
final devProvidersProvider = FutureProvider.autoDispose<List<DevProvider>>(
  (ref) => ref.read(devolucionProveedorApiProvider).providers(),
);
final devBranchesProvider = FutureProvider.autoDispose<List<DevBranch>>(
  (ref) => ref.read(devolucionProveedorApiProvider).branches(),
);
final devDocumentProvider = FutureProvider.autoDispose
    .family<DevDocument, String>(
      (ref, doc) => ref.read(devolucionProveedorApiProvider).fetchOne(doc),
    );

class DevFilters {
  const DevFilters({
    this.page = 1,
    this.document = '',
    this.suc = '',
    this.provider,
    this.status = '',
    this.date = '',
  });
  final int page;
  final String document;
  final String suc;
  final int? provider;
  final String status;
  final String date;
  @override
  bool operator ==(Object other) =>
      other is DevFilters &&
      other.page == page &&
      other.document == document &&
      other.suc == suc &&
      other.provider == provider &&
      other.status == status &&
      other.date == date;
  @override
  int get hashCode => Object.hash(page, document, suc, provider, status, date);
}

final devDocumentsProvider = FutureProvider.autoDispose
    .family<DevPaged<DevDocument>, DevFilters>(
      (ref, f) => ref
          .read(devolucionProveedorApiProvider)
          .fetch(
            page: f.page,
            document: f.document,
            suc: f.suc,
            provider: f.provider,
            status: f.status,
            date: f.date,
          ),
    );
