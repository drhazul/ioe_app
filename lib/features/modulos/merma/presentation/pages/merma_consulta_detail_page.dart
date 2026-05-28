import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/merma_provider.dart';
import '../widgets/merma_readonly_detail.dart';

class MermaConsultaDetailPage extends ConsumerWidget {
  const MermaConsultaDetailPage({super.key, required this.docmer});

  final String docmer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDoc = ref.watch(mermaDetalleConsultaProvider(docmer));
    return Scaffold(
      appBar: AppBar(title: Text('Consulta merma $docmer')),
      body: asyncDoc.when(
        data: (doc) => SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: MermaReadonlyDetail(doc: doc),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
