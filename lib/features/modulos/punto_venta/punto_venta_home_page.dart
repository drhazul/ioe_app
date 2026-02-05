import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PuntoVentaHomePage extends StatelessWidget {
  const PuntoVentaHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = _buildSections();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Punto de venta'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F2EB), Color(0xFFEFE7DB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(),
                const SizedBox(height: 16),
                for (final section in sections) ...[
                  _SectionTitle(title: section.title, subtitle: section.subtitle),
                  const SizedBox(height: 8),
                  _OptionsGrid(options: section.options),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_Section> _buildSections() {
    return [
      _Section(
        title: 'Cotizaciones',
        subtitle: 'Crea, gestiona y consulta cotizaciones activas',
        options: [
          _PvOption(
            title: 'Panel cotizaciones',
            subtitle: 'Pendientes, aprobadas y vencidas',
            icon: Icons.dashboard,
            tone: const Color(0xFFB25D18),
            route: '/punto-venta/cotizaciones',
          ),
          _PvOption(
            title: 'Visualizar catalogo',
            subtitle: 'Busca y compara productos',
            icon: Icons.menu_book,
            tone: const Color(0xFFDAA15A),
          ),
          _PvOption(
            title: 'Nuevo cliente',
            subtitle: 'Registro rapido y datos fiscales',
            icon: Icons.person_add_alt_1,
            tone: const Color(0xFF8E4D1B),
            route: '/punto-venta/clientes',
          ),
        ],
      ),
      _Section(
        title: 'Devoluciones',
        subtitle: 'Control de devoluciones y seguimiento',
        options: [
          _PvOption(
            title: 'Panel devoluciones',
            subtitle: 'Historial y estatus',
            icon: Icons.rule_folder,
            tone: const Color(0xFF4A7A6C),
          ),
        ],
      ),
      _Section(
        title: 'Servicios',
        subtitle: 'Pagos y apartados del punto de venta',
        options: [
          _PvOption(
            title: 'Panel de servicios',
            subtitle: 'Consulta y administra servicios',
            icon: Icons.view_list,
            tone: const Color(0xFF2B5F63),
          ),
          _PvOption(
            title: 'Panel de apartados',
            subtitle: 'Estatus y liberaciones',
            icon: Icons.bookmarks,
            tone: const Color(0xFF4A9AA0),
          ),
        ],
      ),
      _Section(
        title: 'Opciones terminal',
        subtitle: 'Herramientas de caja y terminal',
        options: [
          _PvOption(
            title: 'Estado de cajon',
            subtitle: 'Revision rapida de caja',
            icon: Icons.point_of_sale,
            tone: const Color(0xFF233A63),
          ),
          _PvOption(
            title: 'Retiro parcial',
            subtitle: 'Salida parcial de efectivo',
            icon: Icons.money_off,
            tone: const Color(0xFF34507C),
          ),
          _PvOption(
            title: 'Reimpresion de ticket',
            subtitle: 'Ultimas ventas y reimpresiones',
            icon: Icons.print,
            tone: const Color(0xFF1C2E4A),
          ),
        ],
      ),
    ];
  }
}

class _HeaderCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF2E2A25), Color(0xFF6F5A47)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF2E6D9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.storefront, size: 32, color: Color(0xFF3E3429)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Centro de operaciones',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Accesos rapidos para cotizaciones, devoluciones y terminal',
                  style: TextStyle(color: Color(0xFFE7D8C8), height: 1.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

class _OptionsGrid extends StatelessWidget {
  const _OptionsGrid({required this.options});

  final List<_PvOption> options;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final cardWidth = width < 360
          ? width
          : width < 680
              ? 240.0
              : width < 980
                  ? 260.0
                  : 280.0;

      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final option in options)
            SizedBox(
              width: cardWidth,
              child: _OptionCard(option: option),
            ),
        ],
      );
    });
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.option});

  final _PvOption option;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _handleTap(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: option.tone.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: option.tone.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(option.icon, color: option.tone, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: TextStyle(color: Colors.grey.shade700, height: 1.2, fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opcion en construccion')),
    );
  }

  void _handleTap(BuildContext context) {
    final route = option.route;
    if (route == null || route.isEmpty) {
      _showComingSoon(context);
      return;
    }
    context.go(route);
  }
}

class _Section {
  const _Section({required this.title, required this.subtitle, required this.options});

  final String title;
  final String subtitle;
  final List<_PvOption> options;
}

class _PvOption {
  const _PvOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tone;
  final String? route;
}
