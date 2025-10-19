import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';

  // MOCK: sugerencias que “filtran” por contiene
  final List<String> _mockSugs = const [
    'Estadio 7 de Octubre',
    'Terminal Terrestre de Quevedo',
    'Paseo Shopping Quevedo',
    'La parroquia Venus',
    'Parque del Río',
    'Hospital Sagrado Corazón',
  ];

  // MOCK: últimos destinos
  final List<_RecentItem> _recents = const [
    _RecentItem(title: 'San Jose 120301', subtitle: 'Hace 2 días'),
    _RecentItem(title: 'Paseo Shopping Quevedo', subtitle: 'Ayer'),
  ];

  @override
  void initState() {
    super.initState();
    // autofocus suave
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
    });
    _ctrl.addListener(() {
      setState(() => _query = _ctrl.text.trim());
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    // Prototipo: navegar directo a resultados
    context.push('/results');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // filtra sugerencias
    final sugs = _query.isEmpty
        ? <String>[]
        : _mockSugs
              .where((e) => e.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('Ingresa tu dirección'),
      ),
      body: Column(
        children: [
          // ====== SEARCH BAR FLOTANTE ======
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(16),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Buscar dirección',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),
          ),

          // ====== ACCIÓN "PRECISAR EN EL MAPA" ======
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.place_outlined),
                title: const Text('Precisar en el mapa'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/select-on-map'),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ====== CONTENIDO DINÁMICO ======
          Expanded(
            child: _query.isEmpty
                ? _RecentsSection(recents: _recents)
                : _SuggestionsList(
                    items: sugs,
                    onTapItem: (value) {
                      _ctrl.text = value;
                      _submit();
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onTapItem;
  const _SuggestionsList({required this.items, required this.onTapItem});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Empieza a escribir para ver sugerencias'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final text = items[i];
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => onTapItem(text),
          ),
        );
      },
    );
  }
}

class _RecentsSection extends StatelessWidget {
  final List<_RecentItem> recents;
  const _RecentsSection({required this.recents});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Colors.black54,
      fontWeight: FontWeight.w700,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Text('Tus últimos destinos', style: titleStyle),
        ),
        ...recents.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.history_rounded),
                title: Text(
                  e.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(e.subtitle),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/results'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RecentItem {
  final String title;
  final String subtitle;
  const _RecentItem({required this.title, required this.subtitle});
}
