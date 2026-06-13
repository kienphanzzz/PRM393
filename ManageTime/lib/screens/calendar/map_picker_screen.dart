import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
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

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();

  bool _isDark = ThemeController.isDark;
  bool _isLoading = true;

  LatLng _selectedPoint = const LatLng(21.0136, 105.5259);

  @override
  void initState() {
    super.initState();
    ThemeController.themeNotifier.addListener(_updateTheme);
    _loadDefaultLocation();
  }

  void _updateTheme() {
    if (mounted) {
      setState(() => _isDark = ThemeController.isDark);
    }
  }

  @override
  void dispose() {
    ThemeController.themeNotifier.removeListener(_updateTheme);
    super.dispose();
  }

  Future<void> _loadDefaultLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _isLoading = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedPoint = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      _mapController.move(_selectedPoint, 16);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _confirmLocation() {
    final result = MapPickerResult(
      latitude: _selectedPoint.latitude,
      longitude: _selectedPoint.longitude,
      addressText:
      'Lat: ${_selectedPoint.latitude.toStringAsFixed(6)}, Lng: ${_selectedPoint.longitude.toStringAsFixed(6)}',
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = _isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: _isDark ? AppColors.background : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: _isDark ? AppColors.background : Colors.white,
        elevation: 0,
        title: Text(
          'Chọn vị trí trên bản đồ',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPoint,
              initialZoom: 15,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedPoint = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.manage_time',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedPoint,
                    width: 60,
                    height: 60,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.redAccent,
                      size: 46,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.25),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isDark ? AppColors.cardBg : Colors.white,
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
                    'Chạm vào bản đồ để chọn vị trí',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lat: ${_selectedPoint.latitude.toStringAsFixed(6)}, Lng: ${_selectedPoint.longitude.toStringAsFixed(6)}',
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
                      icon: const Icon(Icons.check, color: AppColors.background),
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