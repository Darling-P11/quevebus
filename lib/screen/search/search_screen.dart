import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:quevebus/core/services/address_suggest_service.dart'; // Nominatim (solo Ecuador)
import 'package:quevebus/core/services/recents_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';

  final List<_RecentItem> _recentsMock = const [
    _RecentItem(title: 'San Jose 120301', subtitle: 'Hace 2 días'),
    _RecentItem(title: 'Paseo Shopping Quevedo', subtitle: 'Ayer'),
  ];

  // Autocomplete
  final AddressSuggestService _svc = AddressSuggestService();
  List<AddressSuggestion> _sugs = [];
  bool _loadingSugs = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final q = _ctrl.text.trim();
    setState(() => _query = q);

    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() {
        _sugs = [];
        _loadingSugs = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _loadingSugs = true);
      try {
        final items = await _svc.search(q);
        if (!mounted) return;
        setState(() {
          _sugs = items;
          _loadingSugs = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _sugs = [];
          _loadingSugs = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _goSelectFromSuggestion(AddressSuggestion s) {
    // Enviar posición inicial y label para que el banner lo muestre
    context.push('/select-on-map', extra: {
      'initialLat': s.lat,
      'initialLon': s.lon,
      'initialLabel': s.label,
    });
  }

  void _goSelectOnMap() => context.push('/select-on-map');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
          // ====== SEARCH BAR (misma altura/estilo que el Card de "Precisar") ======
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 56, // misma altura que el ListTile
                child: Center(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      // si hay sugerencias, tomamos la primera
                      if (_sugs.isNotEmpty) _goSelectFromSuggestion(_sugs.first);
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar dirección',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _ctrl.clear();
                                setState(() {
                                  _sugs = [];
                                  _loadingSugs = false;
                                });
                              },
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ====== CUERPO DINÁMICO ======
          Expanded(
            child: _query.isNotEmpty
                // --------- MODO: AUTOCOMPLETE ---------
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    children: [
                      // Dropdown de sugerencias inmediatamente debajo del buscador
                      if (_loadingSugs)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      else if (_sugs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text('Sin coincidencias. Prueba con otro término.'),
                        )
                      else
                        ..._sugs.map((s) => _SuggestionTile(
                              text: s.label,
                              subText: s.secondary,
                              onTap: () => _goSelectFromSuggestion(s),
                            )),

                      const SizedBox(height: 14),

                      // Separador visual claro entre opciones
                      _Separator(label: 'o'),

                      const SizedBox(height: 8),

                      // “Precisar en el mapa” con la MISMA anchura que el buscador
                      _PrecisarCard(onTap: _goSelectOnMap),
                    ],
                  )
                // --------- MODO: VACÍO (Recientes + Precisar) ---------
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    children: [
                      _PrecisarCard(onTap: _goSelectOnMap),
                      const SizedBox(height: 16),
                      Text(
                        'Tus últimos destinos',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._recentsMock.map(
                        (e) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
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
                            onTap: () {
                              // demo: abrir selector sin coords (usuario confirma allí)
                              context.push('/select-on-map');
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta “Precisar en el mapa” (coincide en altura/estética con el buscador)
class _PrecisarCard extends StatelessWidget {
  final VoidCallback onTap;
  const _PrecisarCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        dense: true,
        minVerticalPadding: 10,
        leading: const Icon(Icons.place_outlined),
        title: const Text('Precisar en el mapa'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

/// Ítem de sugerencia (dropdown)
class _SuggestionTile extends StatelessWidget {
  final String text;
  final String? subText;
  final VoidCallback onTap;
  const _SuggestionTile({
    required this.text,
    required this.onTap,
    this.subText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subText == null
            ? null
            : Text(subText!, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: onTap,
      ),
    );
  }
}

/// Separador “o”
class _Separator extends StatelessWidget {
  final String label;
  const _Separator({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.black12)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: CircleAvatar(
            radius: 14,
            backgroundColor: cs.primary.withOpacity(.08),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.black12)),
      ],
    );
  }
}

class _RecentItem {
  final String title;
  final String subtitle;
  const _RecentItem({required this.title, required this.subtitle});
}
