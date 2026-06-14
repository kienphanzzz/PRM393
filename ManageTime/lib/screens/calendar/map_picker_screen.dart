import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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
  GoogleMapController? _mapController;

  bool _isDark = ThemeController.isDark;
  bool _isLoading = true;
  bool _hasLocationPermission = false;

  LatLng _selectedPoint = const LatLng(21.0136, 105.5259);

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
    ThemeController.themeNotifier.removeListener(_updateTheme);
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _hasLocationPermission = false;
        });
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
          _isLoading = false;
          _hasLocationPermission = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final currentPoint = LatLng(position.latitude, position.longitude);

      if (!mounted) return;
      setState(() {
        _selectedPoint = currentPoint;
        _isLoading = false;
        _hasLocationPermission = true;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentPoint, 16),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _goToMyLocation() async {
    setState(() {
      _isLoading = true;
    });
    await _loadDefaultLocation();
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
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedPoint,
                zoom: 15,
              ),
              onMapCreated: (controller) async {
                _mapController = controller;
                await _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_selectedPoint, 15),
                );
              },
              mapType: MapType.normal,
              myLocationEnabled: _hasLocationPermission,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              markers: {
                Marker(
                  markerId: const MarkerId('selected_location'),
                  position: _selectedPoint,
                  draggable: true,
                  onDragEnd: (point) {
                    setState(() {
                      _selectedPoint = point;
                    });
                  },
                ),
              },
              onTap: (point) {
                setState(() {
                  _selectedPoint = point;
                });
              },
            ),
          ),

          Positioned(
            right: 16,
            top: 16,
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
                    'Chạm bản đồ hoặc kéo pin để chọn vị trí',
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