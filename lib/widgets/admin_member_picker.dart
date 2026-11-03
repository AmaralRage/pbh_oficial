import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';

class AdminMemberPicker extends StatefulWidget {
  const AdminMemberPicker({super.key, this.client});
  final SupabaseClient? client;
  @override
  State<AdminMemberPicker> createState() => _AdminMemberPickerState();
}

class _AdminMemberPickerState extends State<AdminMemberPicker> {
  late final _client = widget.client ?? Supabase.instance.client;
  final _search = TextEditingController();
  final _members = <Map<String, dynamic>>[];
  Timer? _debounce;
  int _version = 0;
  bool _loading = false, _more = true, _failed = false;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _version++;
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || !_more)) return;
    final version = ++_version, viewer = _client.auth.currentUser?.id;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) _members.clear();
    });
    try {
      final rows =
          await _client
                  .rpc(
                    'admin_search_members',
                    params: {
                      'p_query': _search.text.trim(),
                      'p_offset': reset ? 0 : _members.length,
                    },
                  )
                  .timeout(const Duration(seconds: 15))
              as List;
      if (!mounted || version != _version) return;
      if (viewer != _client.auth.currentUser?.id) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        final known = _members.map((m) => m['user_id']).toSet();
        _members.addAll(
          rows
              .map((r) => Map<String, dynamic>.from(r as Map))
              .where((m) => known.add(m['user_id'])),
        );
        _more = rows.length == 30;
      });
    } catch (_) {
      if (mounted && version == _version) setState(() => _failed = true);
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  void _queryChanged(String _) {
    _debounce?.cancel();
    _version++;
    setState(() {
      _members.clear();
      _loading = true;
    });
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _load(reset: true),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: FractionallySizedBox(
      heightFactor: .85,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Escolher membro',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _search,
                onChanged: _queryChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  _debounce?.cancel();
                  _load(reset: true);
                },
                decoration: InputDecoration(
                  hintText: 'Buscar pelo nome ou ID',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Limpar busca',
                    onPressed: () {
                      _search.clear();
                      _queryChanged('');
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Selecione a pessoa pela foto, nome e data de entrada.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.pbhColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: _loading && _members.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _failed && _members.isEmpty
                  ? Center(
                      child: TextButton(
                        onPressed: () => _load(reset: true),
                        child: const Text('Falha ao buscar. Tentar novamente'),
                      ),
                    )
                  : _members.isEmpty
                  ? const Center(child: Text('Nenhum membro encontrado.'))
                  : ListView.builder(
                      itemCount: _members.length + 1,
                      itemBuilder: (_, index) {
                        if (index == _members.length)
                          return _loading
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : _more || _failed
                              ? TextButton(
                                  onPressed: () => _load(),
                                  child: Text(
                                    _failed
                                        ? 'Tentar carregar mais'
                                        : 'Carregar mais membros',
                                  ),
                                )
                              : const SizedBox(height: 16);
                        final member = _members[index],
                            id = member['user_id'] as String;
                        final date = DateTime.tryParse(
                          member['joined_at'] as String? ?? '',
                        )?.toLocal();
                        final photo = member['avatar_url'] as String?;
                        return ListTile(
                          leading: ClipOval(
                            child: SizedBox.square(
                              dimension: 40,
                              child: photo == null || photo.isEmpty
                                  ? const ColoredBox(
                                      color: Color(0xFF252525),
                                      child: Icon(Icons.person_outline),
                                    )
                                  : Image.network(
                                      photo,
                                      cacheWidth: 96,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.person_outline),
                                    ),
                            ),
                          ),
                          title: Text(
                            member['name'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'ID: ${id.substring(id.length > 8 ? id.length - 8 : 0)}${date == null ? '' : ' · Desde ${date.day}/${date.month}/${date.year}'}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, member),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
