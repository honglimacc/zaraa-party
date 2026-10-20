import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api.dart';
import '../../theme.dart';

enum _T { text, number, boolean, json, kind }

class _Field {
  final String key, label;
  final _T type;
  const _Field(this.key, this.label, [this.type = _T.text]);
}

class _Resource {
  final String path, label, titleKey;
  final List<_Field> fields;
  const _Resource(this.path, this.label, this.titleKey, this.fields);
}

/// Semua isi aplikasi yang bisa diatur Developer. Menambah jenis konten baru
/// cukup menambah satu entri di sini dan di backend (routes/catalog.js).
const _resources = [
  _Resource('banners', 'Banner', 'title', [
    _Field('title', 'Judul'),
    _Field('image_url', 'URL gambar'),
    _Field('link_url', 'URL tautan'),
    _Field('sort_order', 'Urutan', _T.number),
    _Field('active', 'Aktif', _T.boolean),
  ]),
  _Resource('gifts', 'Gift', 'name', [
    _Field('name', 'Nama'),
    _Field('icon_url', 'URL ikon'),
    _Field('animation_url', 'URL animasi'),
    _Field('price', 'Harga (koin)', _T.number),
    _Field('active', 'Aktif', _T.boolean),
  ]),
  _Resource('frames', 'Bingkai', 'name', [
    _Field('name', 'Nama'),
    _Field('image_url', 'URL gambar'),
    _Field('price', 'Harga (koin)', _T.number),
    _Field('active', 'Aktif', _T.boolean),
  ]),
  _Resource('badges', 'Lencana', 'name', [
    _Field('name', 'Nama'),
    _Field('icon_url', 'URL ikon'),
    _Field('description', 'Deskripsi'),
    _Field('active', 'Aktif', _T.boolean),
  ]),
  _Resource('vip-tiers', 'VIP / SVIP', 'name', [
    _Field('name', 'Nama'),
    _Field('kind', 'Jenis', _T.kind),
    _Field('price_coins', 'Harga (koin)', _T.number),
    _Field('duration_days', 'Durasi (hari)', _T.number),
    _Field('perks', 'Keistimewaan (JSON)', _T.json),
    _Field('badge_url', 'URL lencana'),
    _Field('active', 'Aktif', _T.boolean),
  ]),
  _Resource('coin-packages', 'Paket Koin', 'name', [
    _Field('name', 'Nama'),
    _Field('coins', 'Jumlah koin', _T.number),
    _Field('price_idr', 'Harga (Rp)', _T.number),
    _Field('active', 'Aktif', _T.boolean),
  ]),
];

class DeveloperPanel extends StatelessWidget {
  const DeveloperPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _resources.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Developer Panel'),
          bottom: TabBar(isScrollable: true, tabs: [for (final r in _resources) Tab(text: r.label)]),
        ),
        body: TabBarView(children: [for (final r in _resources) _ResourceTab(res: r)]),
      ),
    );
  }
}

class _ResourceTab extends StatefulWidget {
  final _Resource res;
  const _ResourceTab({required this.res});

  @override
  State<_ResourceTab> createState() => _ResourceTabState();
}

class _ResourceTabState extends State<_ResourceTab> with AutomaticKeepAliveClientMixin {
  List items = [];
  bool loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Api.i.get('/catalog/${widget.res.path}') as List;
      if (mounted) setState(() {
        items = r;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        toast(context, '$e');
      }
    }
  }

  Future<void> _edit([Map? item]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditSheet(res: widget.res, item: item),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus item?'),
        content: Text('"${item[widget.res.titleKey]}" akan dihapus permanen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.i.delete('/catalog/${widget.res.path}/${item['id']}');
      _load();
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(),
        backgroundColor: Z.mint,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Z.mint))
          : RefreshIndicator(
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(children: const [SizedBox(height: 120), Center(child: Text('Belum ada data. Tekan + untuk menambah.', style: TextStyle(color: Z.muted)))])
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final it = items[i] as Map;
                        final active = it['active'] == true;
                        return ListTile(
                          title: Text('${it[widget.res.titleKey]}', style: TextStyle(fontWeight: FontWeight.w700, color: active ? null : Z.muted)),
                          subtitle: Text(active ? 'Aktif' : 'Nonaktif'),
                          onTap: () => _edit(it),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red), onPressed: () => _delete(it)),
                        );
                      },
                    ),
            ),
    );
  }
}

class _EditSheet extends StatefulWidget {
  final _Resource res;
  final Map? item;
  const _EditSheet({required this.res, this.item});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final Map<String, TextEditingController> ctl = {};
  final Map<String, dynamic> vals = {};
  bool saving = false;

  @override
  void initState() {
    super.initState();
    for (final f in widget.res.fields) {
      final v = widget.item?[f.key];
      switch (f.type) {
        case _T.boolean:
          vals[f.key] = v ?? true;
        case _T.kind:
          vals[f.key] = v ?? 'VIP';
        case _T.json:
          ctl[f.key] = TextEditingController(text: v == null ? '{}' : jsonEncode(v));
        default:
          ctl[f.key] = TextEditingController(text: v == null ? '' : '$v');
      }
    }
  }

  Future<void> _save() async {
    final body = <String, dynamic>{};
    try {
      for (final f in widget.res.fields) {
        switch (f.type) {
          case _T.boolean:
          case _T.kind:
            body[f.key] = vals[f.key];
          case _T.number:
            final t = ctl[f.key]!.text.trim();
            if (t.isNotEmpty) body[f.key] = int.parse(t);
          case _T.json:
            body[f.key] = jsonDecode(ctl[f.key]!.text.trim().isEmpty ? '{}' : ctl[f.key]!.text);
          case _T.text:
            final t = ctl[f.key]!.text.trim();
            body[f.key] = t.isEmpty && f.key != widget.res.titleKey ? null : t;
        }
      }
    } on FormatException {
      return toast(context, 'Ada isian angka / JSON yang tidak valid');
    }
    setState(() => saving = true);
    try {
      if (widget.item == null) {
        await Api.i.post('/catalog/${widget.res.path}', body);
      } else {
        await Api.i.put('/catalog/${widget.res.path}/${widget.item!['id']}', body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        toast(context, '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            Text(widget.item == null ? 'Tambah ${widget.res.label}' : 'Ubah ${widget.res.label}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            for (final f in widget.res.fields) _input(f),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: Z.mint, minimumSize: const Size.fromHeight(48)),
              child: Text(saving ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(_Field f) {
    switch (f.type) {
      case _T.boolean:
        return SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(f.label), value: vals[f.key] as bool, onChanged: (v) => setState(() => vals[f.key] = v));
      case _T.kind:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            value: vals[f.key] as String,
            decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()),
            items: const [DropdownMenuItem(value: 'VIP', child: Text('VIP')), DropdownMenuItem(value: 'SVIP', child: Text('SVIP'))],
            onChanged: (v) => setState(() => vals[f.key] = v),
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: ctl[f.key],
            keyboardType: f.type == _T.number ? TextInputType.number : null,
            maxLines: f.type == _T.json ? 3 : 1,
            decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()),
          ),
        );
    }
  }
}
