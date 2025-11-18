import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:quevebus/core/services/address_suggest_service.dart'; // Nominatim (solo Ecuador)

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';

  // Plazas / lugares frecuentes por defecto (Quevedo)
  final List<_RecommendedPlace> _popularPlaces = const [
    _RecommendedPlace(
      title: 'Universidad Técnica Estatal de Quevedo',
      subtitle: 'Campus universitario principal',
      lat: -1.012613,
      lon: -79.467593,
      label: 'Universidad Técnica Estatal de Quevedo',
    ),
    _RecommendedPlace(
      title: 'Paseo Shopping Quevedo',
      subtitle: 'Centro comercial y zona de servicios',
      lat: -1.010385,
      lon: -79.467803,
      label: 'Paseo Shopping Quevedo',
    ),
    _RecommendedPlace(
      title: 'Terminal Terrestre de Quevedo',
      subtitle: 'Terminal de buses urbanos e interparroquiales',
      lat: -1.0177569801759832,
      lon: -79.47114693122683,
      label: 'Terminal Terrestre de Quevedo',
    ),
    _RecommendedPlace(
      title: 'Parque Central de Quevedo',
      subtitle: 'Referencia frecuente en el centro de la ciudad',
      lat: -1.024282,
      lon: -79.466664,
      label: 'Parque Central de Quevedo',
    ),
    _RecommendedPlace(
      title: 'Complejo Municipal',
      subtitle: 'Zona deportiva y recreativa municipal',
      lat: -1.024282,
      lon: -79.466664,
      label: 'Complejo Municipal',
    ),
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

  bool _isFromQuevedo(AddressSuggestion s) {
    final label = s.label.toLowerCase();
    final secondary = (s.secondary ?? '').toLowerCase();
    return label.contains('quevedo') || secondary.contains('quevedo');
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

        // 👉 Priorizar resultados que sean de Quevedo
        final sorted = List<AddressSuggestion>.from(items);
        sorted.sort((a, b) {
          final aQ = _isFromQuevedo(a) ? 0 : 1;
          final bQ = _isFromQuevedo(b) ? 0 : 1;
          if (aQ != bQ) return aQ - bQ;
          return a.label.toLowerCase().compareTo(b.label.toLowerCase());
        });

        setState(() {
          _sugs = sorted;
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
    context.push(
      '/select-on-map',
      extra: {
        'initialLat': s.lat,
        'initialLon': s.lon,
        'initialLabel': s.label,
      },
    );
  }

  void _goSelectFromPlace(_RecommendedPlace p) {
    context.push(
      '/select-on-map',
      extra: {
        'initialLat': p.lat,
        'initialLon': p.lon,
        'initialLabel': p.label,
      },
    );
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
          // ====== SEARCH BAR ======
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 56,
                child: Center(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      if (_sugs.isNotEmpty) {
                        _goSelectFromSuggestion(_sugs.first);
                      }
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
                      if (_loadingSugs)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_sugs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'Sin coincidencias. Prueba con otro término.',
                          ),
                        )
                      else
                        ..._sugs.map(
                          (s) => _SuggestionTile(
                            text: s.label,
                            subText: s.secondary,
                            onTap: () => _goSelectFromSuggestion(s),
                          ),
                        ),

                      const SizedBox(height: 14),

                      _Separator(label: 'o'),

                      const SizedBox(height: 8),

                      _PrecisarCard(onTap: _goSelectOnMap),
                    ],
                  )
                // --------- MODO: SIN TEXTO (Plazas frecuentes + Precisar) ---------
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
                    children: [
                      _PrecisarCard(onTap: _goSelectOnMap),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.place_rounded,
                            size: 20,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Plazas más frecuentes',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._popularPlaces.map(
                        (e) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.star_rounded),
                            title: Text(
                              e.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              e.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _goSelectFromPlace(e),
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

/// Tarjeta “Precisar en el mapa”
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
        subtitle: const Text(
          'Toca para mover el pin sobre el mapa.',
          style: TextStyle(fontSize: 12.5),
        ),
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
        const Expanded(child: Divider(color: Colors.black12)),
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
        const Expanded(child: Divider(color: Colors.black12)),
      ],
    );
  }
}

class _RecommendedPlace {
  final String title;
  final String subtitle;
  final double lat;
  final double lon;
  final String label;

  const _RecommendedPlace({
    required this.title,
    required this.subtitle,
    required this.lat,
    required this.lon,
    required this.label,
  });
}
