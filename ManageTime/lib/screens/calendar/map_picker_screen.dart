import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import '../../main.dart';

class MapPickerResult {
  final double latitude;
  final double longitude;
  final String addressText;

  MapPickerResult({
    required this.latitude,
    required this.longitude,
    required this.addressText,
  });
}

class _GeoSearchResult {
  final String address;
  final double latitude;
  final double longitude;

  _GeoSearchResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  LatLng get point => LatLng(latitude, longitude);
}

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final TextEditingController _searchController = TextEditingController();

  GoogleMapController? _mapController;

  bool _isDark = ThemeController.isDark;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _canShowMyLocation = false;

  LatLng _selectedPoint = const LatLng(21.0136, 105.5259);

  String _selectedAddressText = 'Lat: 21.013600, Lng: 105.525900';

  List<_GeoSearchResult> _searchResults = [];

  @override
  void initState() {
    super.initState();
    ThemeController.themeNotifier.addListener(_updateTheme);
    _loadDefaultLocation();
  }

  void _updateTheme() {
    if (!mounted) return;

    setState(() {
      _isDark = ThemeController.isDark;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    ThemeController.themeNotifier.removeListener(_updateTheme);
    _mapController?.dispose();
    super.dispose();
  }

  String _latLngText(LatLng point) {
    return 'Lat: ${point.latitude.toStringAsFixed(6)}, Lng: ${point.longitude.toStringAsFixed(6)}';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _moveCamera(
      LatLng point, {
        double zoom = 16,
      }) async {
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(point, zoom),
    );
  }

  Future<void> _loadDefaultLocation() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          _selectedPoint = const LatLng(21.0136, 105.5259);
          _selectedAddressText = _latLngText(_selectedPoint);
          _isLoading = false;
          _canShowMyLocation = false;
        });

        await _moveCamera(_selectedPoint);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _selectedPoint = const LatLng(21.0136, 105.5259);
          _selectedAddressText = _latLngText(_selectedPoint);
          _isLoading = false;
          _canShowMyLocation = false;
        });

        await _moveCamera(_selectedPoint);
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      LatLng currentPoint = LatLng(position.latitude, position.longitude);

      final bool isEmulatorGooglePlex =
          (position.latitude - 37.421998).abs() < 0.01 &&
              (position.longitude + 122.084000).abs() < 0.01;

      if (isEmulatorGooglePlex) {
        currentPoint = const LatLng(21.0136, 105.5259);
      }

      if (!mounted) return;

      setState(() {
        _selectedPoint = currentPoint;
        _selectedAddressText = _latLngText(currentPoint);
        _isLoading = false;
        _canShowMyLocation = true;
      });

      await _moveCamera(currentPoint);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _selectedPoint = const LatLng(21.0136, 105.5259);
        _selectedAddressText = _latLngText(_selectedPoint);
        _isLoading = false;
        _canShowMyLocation = false;
      });

      await _moveCamera(_selectedPoint);
    }
  }

  Future<void> _goToMyLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    await _loadDefaultLocation();
  }

  Future<void> _searchLocation() async {
    final String rawQuery = _searchController.text.trim();

    if (rawQuery.isEmpty) {
      _showMessage('Nhập địa điểm cần tìm');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      String query = rawQuery;

      final String lowerQuery = query.toLowerCase();

      if (!lowerQuery.contains('việt nam') &&
          !lowerQuery.contains('viet nam') &&
          !lowerQuery.contains('vietnam')) {
        query = '$query, Việt Nam';
      }

      final Uri uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': query,
          'format': 'json',
          'addressdetails': '1',
          'limit': '6',
          'accept-language': 'vi',
        },
      );

      final http.Response response = await http.get(
        uri,
        headers: {
          'User-Agent': 'ManageTimeFlutterApp/1.0',
        },
      );

      if (response.statusCode != 200) {
        _showMessage('Lỗi kết nối tìm kiếm địa điểm');
        return;
      }

      final dynamic decodedData = jsonDecode(response.body);

      if (decodedData is! List) {
        _showMessage('Dữ liệu tìm kiếm không hợp lệ');
        return;
      }

      if (decodedData.isEmpty) {
        _showMessage('Không tìm thấy địa điểm: $rawQuery');
        return;
      }

      final List<_GeoSearchResult> parsedResults = [];

      for (final dynamic item in decodedData) {
        if (item is! Map<String, dynamic>) continue;

        final String address = item['display_name']?.toString() ?? rawQuery;

        final double? lat = double.tryParse(item['lat']?.toString() ?? '');
        final double? lng = double.tryParse(item['lon']?.toString() ?? '');

        if (lat == null || lng == null) continue;

        parsedResults.add(
          _GeoSearchResult(
            address: address,
            latitude: lat,
            longitude: lng,
          ),
        );
      }

      if (parsedResults.isEmpty) {
        _showMessage('Không lấy được tọa độ từ kết quả tìm kiếm');
        return;
      }

      setState(() {
        _searchResults = parsedResults;
      });

      await _selectSearchResult(
        parsedResults.first,
        closeResultPanel: false,
      );
    } catch (e) {
      _showMessage('Lỗi tìm kiếm địa điểm: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _selectSearchResult(
      _GeoSearchResult result, {
        bool closeResultPanel = true,
      }) async {
    final LatLng point = result.point;

    setState(() {
      _selectedPoint = point;
      _selectedAddressText = '${result.address} | ${_latLngText(point)}';

      if (closeResultPanel) {
        _searchResults = [];
      }
    });

    await _moveCamera(point, zoom: 15);
  }

  void _selectPointFromMap(LatLng point) {
    setState(() {
      _selectedPoint = point;
      _selectedAddressText = _latLngText(point);
      _searchResults = [];
    });
  }

  void _confirmLocation() {
    final result = MapPickerResult(
      latitude: _selectedPoint.latitude,
      longitude: _selectedPoint.longitude,
      addressText: _selectedAddressText,
    );

    Navigator.pop(context, result);
  }

  Widget _buildSearchBox({
    required Color textColor,
    required Color cardColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: textColor),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _searchLocation(),
        decoration: InputDecoration(
          hintText: 'Tìm Long Biên, Hòa Bình, Nghệ An...',
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textMuted,
          ),
          suffixIcon: _isSearching
              ? const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          )
              : IconButton(
            icon: const Icon(
              Icons.send_rounded,
              color: AppColors.primary,
            ),
            onPressed: _searchLocation,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults({
    required Color textColor,
    required Color cardColor,
  }) {
    if (_searchResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: AppColors.textMuted.withOpacity(0.15),
        ),
        itemBuilder: (context, index) {
          final _GeoSearchResult result = _searchResults[index];

          return ListTile(
            dense: true,
            leading: const Icon(
              Icons.place_rounded,
              color: AppColors.primary,
            ),
            title: Text(
              result.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            subtitle: Text(
              _latLngText(result.point),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
            onTap: () => _selectSearchResult(result),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color textColor = _isDark ? Colors.white : Colors.black87;
    final Color cardColor = _isDark ? AppColors.cardBg : Colors.white;

    return Scaffold(
      backgroundColor: _isDark ? AppColors.background : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: _isDark ? AppColors.background : Colors.white,
        elevation: 0,
        title: Text(
          'Chọn vị trí trên Google Maps',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedPoint,
              zoom: 16,
            ),
            onMapCreated: (controller) async {
              _mapController = controller;
              await _moveCamera(_selectedPoint);
            },
            myLocationEnabled: _canShowMyLocation,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            markers: {
              Marker(
                markerId: const MarkerId('selected_location'),
                position: _selectedPoint,
                draggable: true,
                onDragEnd: _selectPointFromMap,
              ),
            },
            onTap: _selectPointFromMap,
          ),

          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Column(
              children: [
                _buildSearchBox(
                  textColor: textColor,
                  cardColor: cardColor,
                ),
                const SizedBox(height: 8),
                _buildSearchResults(
                  textColor: textColor,
                  cardColor: cardColor,
                ),
              ],
            ),
          ),

          if (_searchResults.isEmpty)
            Positioned(
              right: 16,
              top: 86,
              child: FloatingActionButton(
                heroTag: 'my_location_btn',
                mini: true,
                backgroundColor: AppColors.primary,
                onPressed: _goToMyLocation,
                child: const Icon(
                  Icons.my_location,
                  color: AppColors.background,
                ),
              ),
            ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.25),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
            ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tìm kiếm, chạm bản đồ hoặc kéo pin để chọn vị trí',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedAddressText,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _confirmLocation,
                      icon: const Icon(
                        Icons.check,
                        color: AppColors.background,
                      ),
                      label: const Text(
                        'Chọn vị trí này',
                        style: TextStyle(
                          color: AppColors.background,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}