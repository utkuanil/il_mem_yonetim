import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:il_mem_yonetim/core/data/json_providers.dart';

class OkullarHaritaPage extends ConsumerStatefulWidget {
  const OkullarHaritaPage({super.key});

  @override
  ConsumerState<OkullarHaritaPage> createState() => _OkullarHaritaPageState();
}

class _OkullarHaritaPageState extends ConsumerState<OkullarHaritaPage> {
  // GitHub path (repo: /data/tunceli_okullar.json)
  static const String _remotePath = 'tunceli_okullar.json';

  bool _loading = true;
  String? _error;

  Set<Marker> _markers = <Marker>{};
  int _total = 0;
  int _withCoords = 0;

  GoogleMapController? _mapController;
  LatLng? _firstPoint;

  // Tunceli merkez (Varsayılan Kamera)
  CameraPosition _initialCamera = const CameraPosition(
    target: LatLng(39.107986, 39.548977),
    zoom: 8.5,
  );

  @override
  void initState() {
    super.initState();
    _load(); // ilk açılış
  }

  List<dynamic> _extractRecords(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final r = decoded['records'];
      if (r is List) return r;
      return const [];
    }
    if (decoded is List) return decoded;
    return const [];
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      _markers = <Marker>{};
      _total = 0;
      _withCoords = 0;
      _firstPoint = null;
    });

    try {
      // ✅ GitHub → cache → JSON
      final decoded = await ref.read(jsonRepositoryProvider).getJson(
        _remotePath,
        forceRefresh: forceRefresh,
        cacheBust: forceRefresh,
      );

      final List<dynamic> records = _extractRecords(decoded);
      _total = records.length;

      final markers = <Marker>{};
      LatLng? firstPoint;
      int withCoords = 0;

      int idx = 0;
      for (final r in records) {
        idx++;
        if (r is! Map<String, dynamic>) continue;

        final okulAdi = (r['okul_adi'] ?? r['OKUL_ADI'] ?? '').toString().trim();
        final kurumKodu = (r['kurum_kodu'] ?? r['KURUM_KODU'] ?? '').toString().trim();
        final il = (r['il'] ?? r['IL'] ?? '').toString().trim();
        final ilce = (r['ilce'] ?? r['ILCE'] ?? '').toString().trim();

        final konum = r['konum'];
        final double? lat = _toDouble(
          r['latitude'] ??
              r['lat'] ??
              r['LATITUDE'] ??
              (konum is Map ? konum['latitude'] : null),
        );

        final double? lng = _toDouble(
          r['longitude'] ??
              r['lng'] ??
              r['lon'] ??
              r['LONGITUDE'] ??
              (konum is Map ? konum['longitude'] : null),
        );

        if (lat == null || lng == null) continue;
        if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;

        withCoords++;
        final pos = LatLng(lat, lng);
        firstPoint ??= pos;

        final id = kurumKodu.isNotEmpty ? kurumKodu : 'okul_$idx';

        markers.add(
          Marker(
            markerId: MarkerId(id),
            position: pos,
            icon: BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(
              title: okulAdi.isEmpty ? 'Okul' : okulAdi,
              snippet: [
                if (ilce.isNotEmpty) ilce,
                if (il.isNotEmpty) il,
                if (kurumKodu.isNotEmpty) 'Kod: $kurumKodu',
              ].where((e) => e.trim().isNotEmpty).join(' • '),
              onTap: () => _showSchoolDetails(r),
            ),
            onTap: () => _showSchoolDetails(r),
          ),
        );
      }

      setState(() {
        _firstPoint = firstPoint;
        _withCoords = withCoords;
        _markers = markers;
        _loading = false;

        if (_firstPoint != null) {
          _initialCamera = CameraPosition(target: _firstPoint!, zoom: 8.5);
        }
      });

      // Harita hazırsa ilk noktaya zoomla
      if (_firstPoint != null && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_firstPoint!, 9),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Veri hatası: $e';
      });
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim().replaceAll(',', '.');
    return double.tryParse(s);
  }

  void _showSchoolDetails(Map<String, dynamic> school) {
    if (!mounted) return;

    final okulAdi =
    (school['okul_adi'] ?? school['OKUL_ADI'] ?? 'Okul Detayı').toString().trim();

    final kurumKodu =
    (school['kurum_kodu'] ?? school['KURUM_KODU'] ?? '-').toString();
    final ilce = (school['ilce'] ?? school['ILCE'] ?? '-').toString();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              okulAdi,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text("Kurum Kodu: $kurumKodu"),
            Text("İlçe: $ilce"),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // (İstersen burada _total ve _withCoords'u appbar subtitle olarak da gösterebiliriz)
    return Scaffold(
      appBar: AppBar(
        title: const Text('Okullar Haritası'),
        actions: [
          IconButton(
            onPressed: () => _load(forceRefresh: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : GoogleMap(
        initialCameraPosition: _initialCamera,
        markers: _markers,
        onMapCreated: (controller) {
          _mapController = controller;
          if (_firstPoint != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_firstPoint!, 9),
            );
          }
        },
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
      ),
    );
  }
}
