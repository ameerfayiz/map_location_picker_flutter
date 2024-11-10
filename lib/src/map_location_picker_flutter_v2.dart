import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_photon/flutter_photon.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:map_location_picker_flutter/src/utils/location_result.dart';

import 'utils/animated_static_widget.dart';
import 'utils/debouncer.dart';
import 'utils/photon_autocomplete_instance.dart';

class MapLocationPickerV2 extends StatefulWidget {
  // Map Configuration
  final LatLng? initialLocation;
  final double? initialZoom;
  final double? maxZoom;
  final double? minZoom;
  final String? mapTileUrl;

  // UI Customization
  final Color? primaryColor;
  final Color? secondaryColor;
  final Color? markerColor;
  final Color? markerOutlineColor;
  final double? markerSize;
  final IconData? markerIcon;
  final double? buttonSize;
  final double? labelHeight;
  final double? labelRoundness;
  final TextStyle? labelTextStyle;
  final String? searchHintText;
  final TextStyle? searchTextStyle;

  // Animation Configuration
  final Duration? mapMoveDuration;
  final Duration? zoomDuration;
  final Duration? rotationResetDuration;
  final Curve? animationCurve;

  // Search Configuration
  final int? searchDebounceTime;
  final int? reverseGeocodeRadius;

  // Callback Functions
  final Function(LocationResult)? onLocationSelected;
  final Function(LatLng)? onMapMove;
  final Function(String)? onSearchTextChanged;

  const MapLocationPickerV2({
    Key? key,
    this.initialLocation,
    this.initialZoom,
    this.maxZoom,
    this.minZoom,
    this.mapTileUrl,
    this.primaryColor,
    this.secondaryColor,
    this.markerColor,
    this.markerOutlineColor,
    this.markerSize,
    this.markerIcon,
    this.buttonSize,
    this.labelHeight,
    this.labelRoundness,
    this.labelTextStyle,
    this.searchHintText,
    this.searchTextStyle,
    this.mapMoveDuration,
    this.zoomDuration,
    this.rotationResetDuration,
    this.animationCurve,
    this.searchDebounceTime,
    this.reverseGeocodeRadius,
    this.onLocationSelected,
    this.onMapMove,
    this.onSearchTextChanged,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => MapLocationPickerV2State();
}

class MapLocationPickerV2State extends State<MapLocationPickerV2> with TickerProviderStateMixin {
  // Default values
  static const defaultInitialLocation = LatLng(12.975788790299323, 77.58728327670923);
  static const defaultInitialZoom = 10.0;
  static const defaultMaxZoom = 18.0;
  static const defaultMinZoom = 3.0;
  static const defaultLabelHeight = 56.0;
  static const defaultLabelRoundness = 30.0;
  static const defaultMarkerSize = 100.0;
  static const defaultButtonSize = 56.0;
  static const defaultMapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const defaultSearchDebounceTime = 300;
  static const defaultReverseGeocodeRadius = 10;
  static const defaultMapMoveDuration = Duration(milliseconds: 1000);
  static const defaultRotationResetDuration = Duration(milliseconds: 500);
  static const defaultZoomDuration = Duration(milliseconds: 500);

  late final MapController mapController;
  late final TextEditingController searchController;
  late CancelableOperation connectOperation;
  late LocationResult _locationResult;
  late StreamController<String> _placeDetails;

  final Location _locationService = Location();
  final api = PhotonApi();

  LocationData? _currentLocation;
  bool _permission = false;
  bool _liveUpdate = false;
  String? _serviceError = '';
  double mapControllerRotationRad = 0;
  late Debouncer _deBouncer;
  var markers = <Marker>[];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    searchController = TextEditingController();
    _placeDetails = StreamController<String>();
    _locationResult = LocationResult();

    // Initialize the debouncer with custom or default time
    _deBouncer = Debouncer(
      milliseconds: widget.searchDebounceTime ?? defaultSearchDebounceTime,
    );
  }

  @override
  void dispose() {
    _placeDetails.close();
    searchController.dispose();
    try {
      connectOperation.cancel();
    } catch (e) {}
    _deBouncer.run(() {});
    super.dispose();
  }

  // Helper getters for customization
  Color get primaryColor => widget.primaryColor ?? const Color(0xFF20292E);

  Color get secondaryColor => widget.secondaryColor ?? Colors.blueGrey.shade50;

  Color get markerColor => widget.markerColor ?? const Color(0xFFBF0000);

  Color get markerOutlineColor => widget.markerOutlineColor ?? const Color(0xFF7A0000);

  double get markerSize => widget.markerSize ?? defaultMarkerSize;

  IconData get markerIcon => widget.markerIcon ?? Icons.location_on;

  double get labelHeight => widget.labelHeight ?? defaultLabelHeight;

  double get labelRoundness => widget.labelRoundness ?? defaultLabelRoundness;

  double get buttonSize => widget.buttonSize ?? defaultButtonSize;

  TextStyle get labelTextStyle => widget.labelTextStyle ?? TextStyle(color: Colors.blueGrey.shade100, fontSize: 15);

  TextStyle get searchTextStyle => widget.searchTextStyle ?? const TextStyle(fontSize: 20.0);

  Duration get mapMoveDuration => widget.mapMoveDuration ?? const Duration(milliseconds: 1000);

  Duration get zoomDuration => widget.zoomDuration ?? const Duration(milliseconds: 500);

  Duration get rotationResetDuration => widget.rotationResetDuration ?? const Duration(milliseconds: 500);

  Curve get animationCurve => widget.animationCurve ?? Curves.fastOutSlowIn;

  // Rest of the existing methods with customization applied...
  // (Keep all existing methods but update them to use the customization getters)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: widget.initialLocation ?? defaultInitialLocation,
              initialZoom: widget.initialZoom ?? defaultInitialZoom,
              maxZoom: widget.maxZoom ?? defaultMaxZoom,
              minZoom: widget.minZoom ?? defaultMinZoom,
              onPositionChanged: _handlePositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: widget.mapTileUrl ?? defaultMapTileUrl,
              ),
              MarkerLayer(markers: markers),
              _buildLocationMarker(),
            ],
          ),
          _buildSearchBar(),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildLocationMarker() {
    return Center(
      child: AnimatedStaticWidget(
        child: Stack(
          children: [
            Icon(
              markerIcon,
              size: markerSize,
              color: markerColor,
            ),
            Icon(
              markerIcon,
              size: markerSize,
              color: markerOutlineColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              _buildBackButton(),
              Expanded(
                child: photonAutocomplete(
                  label: widget.searchHintText ?? "Type the Place",
                  controller: searchController,
                  itemSubmitted: _handleSearchItemSubmitted,
                  textChanged: widget.onSearchTextChanged ?? (_) {},
                  fontSize: searchTextStyle.fontSize!,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePositionChanged(MapCamera position, bool hasGesture) {
    _locationResult.coordinates = null;
    _locationResult.nearBy = null;

    _deBouncer.run(() async {
      setState(() {
        mapControllerRotationRad = transform360to180(mapController.camera.rotation % 360) * 0.01745329252;
      });

      final currentPosition = position.center!;
      if (widget.onMapMove != null) {
        widget.onMapMove!(LatLng(currentPosition.latitude, currentPosition.longitude));
      }

      _placeDetails.add("Loading...");
      isLoading = true;
      _locationResult.coordinates = LatLng(currentPosition.latitude, currentPosition.longitude);

      List<PhotonFeature> places = await getPlaceDetailsCancellable(
        currentPosition.latitude,
        currentPosition.longitude,
        radius: widget.reverseGeocodeRadius ?? defaultReverseGeocodeRadius,
      );

      isLoading = false;
      if (places.isNotEmpty) {
        PhotonFeature place = places.first;
        _locationResult.nearBy = place;
        _placeDetails.add(getLocationLabel(place));
      } else {
        _placeDetails.add("Unknown Location: ${currentPosition.latitude}, ${currentPosition.longitude}");
      }
    });
  }

  Widget _buildBottomControls() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 10),
              _buildLocationLabel(),
              const SizedBox(width: 2),
              _buildControlButtons(),
              const SizedBox(width: 10),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildLocationLabel() {
    return Expanded(
      child: Container(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.only(left: labelRoundness, right: 13),
        height: labelHeight,
        decoration: BoxDecoration(
          color: Colors.blueGrey.withAlpha(200),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(labelRoundness),
            bottomLeft: Radius.circular(labelRoundness),
          ),
        ),
        child: StreamBuilder<String>(
          stream: _placeDetails.stream,
          builder: (context, snapshot) {
            String displayText = "Waiting...";
            if (snapshot.connectionState == ConnectionState.waiting) {
              displayText = "Loading...";
            } else if (snapshot.connectionState == ConnectionState.done) {
              displayText = "Done!";
            } else if (snapshot.hasError) {
              displayText = "Failed";
            } else if (snapshot.hasData) {
              displayText = snapshot.data!;
            }

            return Text(
              displayText,
              style: labelTextStyle,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Column(
      children: [
        _buildZoomButtons(),
        const SizedBox(height: 10),
        _buildRotationButton(),
        const SizedBox(height: 10),
        _buildLocationButton(),
        const SizedBox(height: 10),
        _buildConfirmButton(),
      ],
    );
  }

  Widget _buildZoomButtons() {
    return Column(
      children: [
        _buildControlButton(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(labelRoundness),
            topLeft: Radius.circular(labelRoundness),
          ),
          onTap: () => animatedMapZoom(true),
          icon: Icons.add,
        ),
        const SizedBox(height: 2),
        _buildControlButton(
          borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(labelRoundness),
            bottomLeft: Radius.circular(labelRoundness),
          ),
          onTap: () => animatedMapZoom(false),
          icon: Icons.remove,
        ),
      ],
    );
  }

  Widget _buildRotationButton() {
    return FloatingActionButton(
      heroTag: "mapRotation",
      backgroundColor: primaryColor,
      foregroundColor: secondaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(labelRoundness))),
      onPressed: () {
        setState(() {
          mapControllerRotationRad = 0;
        });
        animatedMapRotationReset();
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: mapControllerRotationRad),
        duration: rotationResetDuration,
        curve: animationCurve,
        builder: (context, rotation, child) {
          return Transform.rotate(
            angle: rotation,
            child: Icon(
              Icons.navigation,
              size: 30,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationButton() {
    return FloatingActionButton(
      heroTag: "myLocation",
      backgroundColor: primaryColor,
      foregroundColor: secondaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(labelRoundness))),
      onPressed: () {
        _liveUpdate = !_liveUpdate;
        if (_liveUpdate) {
          gotoMyLocation();
        }
      },
      child: Icon(Icons.my_location),
    );
  }

  Widget _buildConfirmButton() {
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(width: buttonSize, height: labelHeight),
      child: ElevatedButton(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(primaryColor),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(labelRoundness),
                bottomRight: Radius.circular(labelRoundness),
              ),
            ),
          ),
          // Add padding to remove default padding
          padding: MaterialStateProperty.all(EdgeInsets.zero),
        ),
        onPressed: () {
          if (_locationResult.coordinates != null && !isLoading) {
            if (widget.onLocationSelected != null) {
              widget.onLocationSelected!(_locationResult);
            }
            Navigator.pop(context, _locationResult);
          }
        },
        child: Center(
          // Wrap Icon with Center widget
          child: Icon(
            Icons.check,
            color: secondaryColor,
            size: 24, // Optional: specify size for better control
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return InkWell(
      onTap: () {
        try {
          connectOperation.cancel();
        } catch (e) {
          print(e);
        }
        Navigator.pop(context, null);
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Icon(
          Icons.arrow_back_ios,
          size: 30,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required BorderRadius borderRadius,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return PhysicalModel(
      borderRadius: borderRadius,
      color: primaryColor,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            icon,
            color: secondaryColor,
          ),
        ),
      ),
    );
  }

  void _handleSearchItemSubmitted(PhotonFeature photonFeature) {
    print("Location selected: ${photonFeature.name}");
    animatedMapMove(photonFeature.coordinates, 16);
    if (widget.onLocationSelected != null) {
      _locationResult.coordinates = photonFeature.coordinates;
      _locationResult.nearBy = photonFeature;
      widget.onLocationSelected!(_locationResult);
    }
  }

  void animatedMapMove(LatLng destLocation, double destZoom) {
    // Create some tweens. These serve to split up the transition from one location to another.
    // In our case, we want to split the transition be<tween> our current map center and the destination.
    final _latTween = Tween<double>(begin: mapController.camera.center.latitude, end: destLocation.latitude);
    final _lngTween = Tween<double>(begin: mapController.camera.center.longitude, end: destLocation.longitude);
    final _zoomTween = Tween<double>(begin: mapController.camera.zoom, end: destZoom);

    // Create a animation controller that has a duration and a TickerProvider.
    var controller = AnimationController(duration: widget.mapMoveDuration ?? defaultMapMoveDuration, vsync: this);
    // The animation determines what path the animation will take. You can try different Curves values, although I found
    // fastOutSlowIn to be my favorite.
    Animation<double> animation = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      mapController.move(LatLng(_latTween.evaluate(animation), _lngTween.evaluate(animation)), _zoomTween.evaluate(animation));
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  Future<void> gotoMyLocation() async {
    LocationData? location;
    bool serviceEnabled;
    bool serviceRequestResult;

    try {
      serviceEnabled = await _locationService.serviceEnabled();
      if (serviceEnabled) {
        var permission = await _locationService.requestPermission();
        _permission = permission == PermissionStatus.granted;
        if (_permission) {
          location = await _locationService.getLocation();
          _currentLocation = location;
          if (mounted) {
            if (_liveUpdate) {
              setState(() {
                _currentLocation = location;
                // If Live Update is enabled, move map center
                animatedMapMove(
                  LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
                  16,
                );
                _liveUpdate = false;
              });
            }
          }
        }
      } else {
        serviceRequestResult = await _locationService.requestService();
        if (serviceRequestResult) {
          await _locationService.changeSettings(accuracy: LocationAccuracy.high);
          gotoMyLocation();
          return;
        }
      }
    } on PlatformException catch (e) {
      print(e);
      if (e.code == 'PERMISSION_DENIED') /*No L10n*/ {
        //No L10n
        _serviceError = e.message;
      } else if (e.code == 'SERVICE_STATUS_ERROR') /*No L10n*/ {
        //No L10n
        _serviceError = e.message;
      }
      location = null;
    }
  }

  double transform360to180(double inDegree) {
    if (inDegree.abs() >= 0 && inDegree.abs() <= 180) {
      return inDegree;
    } else {
      return inDegree + ((inDegree > 0) ? -360 : 360);
    }
  }

  void animatedMapRotationReset() {
    final _rotationTween = Tween<double>(begin: transform360to180(mapController.camera.rotation % 360), end: 0);
    var controller = AnimationController(duration: widget.rotationResetDuration ?? defaultRotationResetDuration, vsync: this);
    Animation<double> animation = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      mapController.rotate(_rotationTween.evaluate(animation));
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          mapControllerRotationRad = 0;
        });
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        setState(() {
          mapControllerRotationRad = 0;
        });
        controller.dispose();
      }
    });
    controller.forward();
  }

  Future<List<PhotonFeature>> getPlaceDetailsCancellable(double latitude, double longitude, {int radius = 10}) async {
    try {
      connectOperation.cancel();
    } catch (e) {}
    connectOperation = CancelableOperation.fromFuture(
      getPlaceDetails(latitude, longitude, radius: radius),
      // onCancel: () => {print("CANCELLED================================================>>>>>>>>")}
    );
    return await connectOperation.value;
  }

  Future<List<PhotonFeature>> getPlaceDetails(double latitude, double longitude, {int radius = 10}) async {
    List<PhotonFeature> result;
    try {
      result = await api.reverseSearch(
        latitude,
        longitude,
        radius: radius,
      );
    } on Exception catch (e) {
      result = [];
    }
    return result;
  }

  void animatedMapZoom(bool isIncreaseZoom) {
    final _zoomTween = Tween<double>(begin: mapController.camera.zoom, end: nextZoom(isIncreaseZoom));

    var controller = AnimationController(duration: widget.zoomDuration ?? defaultZoomDuration, vsync: this);
    Animation<double> animation = CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      mapController.move(mapController.camera.center, _zoomTween.evaluate(animation));
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });
    controller.forward();
  }

  double nextZoom(bool isIncreaseZoom) {
    double nextZoom = mapController.camera.zoom + (isIncreaseZoom ? 3 : -3);
    if (nextZoom > defaultMaxZoom) {
      return defaultMaxZoom;
    }
    if (nextZoom < defaultMinZoom) {
      return defaultMinZoom;
    }
    return nextZoom;
  }
}
