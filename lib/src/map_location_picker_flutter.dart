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

class MapLocationPicker extends StatefulWidget {
  final LatLng? initialLocation;
  final double? initialZoom;

  const MapLocationPicker({Key? key, this.initialLocation, this.initialZoom}) : super(key: key);

  @override
  State<StatefulWidget> createState() => new MapLocationPickerState(
        initialLocation ?? LatLng(12.975788790299323, 77.58728327670923),
        initialZoom ?? 10,
      );
}

class MapLocationPickerState extends State<MapLocationPicker> with TickerProviderStateMixin {
  ///CONSTANTS
  static const double labelHeight = 56;
  static const double labelRoundness = 30;
  static const double zoomButtonPadding = 5;
  static const double maxZoomOfMap = 18.0;
  static const double minZoomOfMap = 3.0;

  static const int rotationResetDurationMillis = 500;
  static const int zoomDurationMillis = 500;
  static const int mapMoveDurationMillis = 1000;
  static const int deBouncerIntervalMillis = 300;

  ///LATE FINAL VARIABLES
  late final MapController mapController;
  late final TextEditingController searchController;

  ///FINAL VARIABLES
  final _deBouncer = Debouncer(milliseconds: deBouncerIntervalMillis);
  final api = PhotonApi();
  final Location _locationService = Location();
  final LatLng initialLocation;
  final double initialZoom;

  ///LATE VARIABLES
  late CancelableOperation connectOperation;
  late LocationResult _locationResult;
  late StreamController<String> _placeDetails;

  ///GLOBAL STATE VARIABLES
  LocationData? _currentLocation;
  bool _permission = false;
  bool _liveUpdate = false;
  String? _serviceError = '';
  double mapControllerRotationRad = 0;
  var markers = <Marker>[];
  bool isLoading = false;

  ///CONSTRUCTORS
  MapLocationPickerState(this.initialLocation, this.initialZoom);

  @override
  void dispose() {
    _placeDetails.close();

    ///Cancel network calls
    try {
      connectOperation.cancel();
    } catch (e) {}

    ///Cancel debounced updates to ui
    _deBouncer.run(() {});
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    searchController = TextEditingController();
    _placeDetails = new StreamController<String>();
    _locationResult = LocationResult();
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

  double nextZoom(bool isIncreaseZoom) {
    double nextZoom = mapController.camera.zoom + (isIncreaseZoom ? 3 : -3);
    if (nextZoom > maxZoomOfMap) {
      return maxZoomOfMap;
    }
    if (nextZoom < minZoomOfMap) {
      return minZoomOfMap;
    }
    return nextZoom;
  }

  void animatedMapZoom(bool isIncreaseZoom) {
    final _zoomTween = Tween<double>(begin: mapController.camera.zoom, end: nextZoom(isIncreaseZoom));

    var controller = AnimationController(duration: const Duration(milliseconds: zoomDurationMillis), vsync: this);
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

  void animatedMapRotationReset() {
    final _rotationTween = Tween<double>(begin: transform360to180(mapController.camera.rotation % 360), end: 0);
    var controller = AnimationController(duration: const Duration(milliseconds: rotationResetDurationMillis), vsync: this);
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

  void animatedMapMove(LatLng destLocation, double destZoom) {
    // Create some tweens. These serve to split up the transition from one location to another.
    // In our case, we want to split the transition be<tween> our current map center and the destination.
    final _latTween = Tween<double>(begin: mapController.camera.center.latitude, end: destLocation.latitude);
    final _lngTween = Tween<double>(begin: mapController.camera.center.longitude, end: destLocation.longitude);
    final _zoomTween = Tween<double>(begin: mapController.camera.zoom, end: destZoom);

    // Create a animation controller that has a duration and a TickerProvider.
    var controller = AnimationController(duration: const Duration(milliseconds: mapMoveDurationMillis), vsync: this);
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
        params: PhotonReverseParams(radius: radius),
      );
    } on Exception catch (e) {
      result = [];
    }
    return result;
  }

  double transform360to180(double inDegree) {
    if (inDegree.abs() >= 0 && inDegree.abs() <= 180) {
      return inDegree;
    } else {
      return inDegree + ((inDegree > 0) ? -360 : 360);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: initialLocation,
              initialZoom: initialZoom,
              maxZoom: maxZoomOfMap,
              minZoom: minZoomOfMap,
              onPositionChanged: (MapCamera position, bool hasGesture) {
                _locationResult.coordinates = null;
                _locationResult.nearBy = null;
                _deBouncer.run(() async {
                  setState(() {
                    mapControllerRotationRad = transform360to180(mapController.camera.rotation % 360) * 0.01745329252;
                  });
                  print("LOCATION : ${position.center!.longitude}, ${position.center!.latitude}");
                  _placeDetails.add("Loading...");
                  isLoading = true;
                  _locationResult.coordinates = (LatLng(position.center!.latitude, position.center!.longitude));
                  List<PhotonFeature> places = await getPlaceDetailsCancellable(position.center!.latitude, position.center!.longitude, radius: 10);
                  isLoading = false;
                  if (places.isNotEmpty) {
                    PhotonFeature place = places.first;
                    _locationResult.nearBy = place;
                    _placeDetails.add("${getLocationLabel(place)}");
                    places.forEach((place) {
                      print("${place.name} ,${place.coordinates.latitude},${place.coordinates.longitude}, ${place.street},${place.city},${place.county},${place.district},${place.state}\n");
                    });
                  } else {
                    _placeDetails.add("Unknown Location : ${position.center!.latitude} ,  ${position.center!.longitude}");
                  }
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              MarkerLayer(
                markers: markers,
              ),
              // Custom location marker
              Center(
                child: AnimatedStaticWidget(
                  child: Stack(
                    children: const [
                      Icon(
                        Icons.location_on,
                        size: 100,
                        color: Color(0xFFBF0000),
                      ),
                      Icon(
                        Icons.location_on_outlined,
                        size: 100,
                        color: Color(0xFF7A0000),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    InkWell(
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
                    ),
                    Expanded(
                      child: photonAutocomplete(
                        label: "Type the Place",
                        controller: searchController,
                        itemSubmitted: (PhotonFeature photonFeature) {
                          print("Item Submitted totally (name) : ${photonFeature.name}"); //No L10n
                          animatedMapMove(LatLng(photonFeature.coordinates.latitude.toDouble(),photonFeature.coordinates.longitude.toDouble()), 16);
                        },
                        textChanged: (text) => {},
                        fontSize: 20.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: labelRoundness, right: 13),
                        height: labelHeight,
                        decoration: BoxDecoration(color: Colors.blueGrey.withAlpha(200), borderRadius: BorderRadius.only(topLeft: Radius.circular(labelRoundness), bottomLeft: Radius.circular(labelRoundness))),
                        child: StreamBuilder<String>(
                          stream: _placeDetails.stream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Text(
                                "Loading...",
                                style: TextStyle(color: Colors.blueGrey.shade100, fontSize: 15),
                              );
                            } else if (snapshot.connectionState == ConnectionState.done) {
                              return Text(
                                "Done !",
                                style: TextStyle(color: Colors.blueGrey.shade100, fontSize: 15),
                              );
                            } else if (snapshot.hasError) {
                              return Text(
                                "Failed",
                                style: TextStyle(color: Colors.blueGrey.shade100, fontSize: 15),
                              );
                            } else if (snapshot.hasData) {
                              return Text(
                                '${snapshot.data}',
                                style: TextStyle(color: Colors.blueGrey.shade100, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              );
                            } else {
                              return Text(
                                "Waiting..",
                                style: TextStyle(color: Colors.blueGrey.shade100, fontSize: 15),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 2,
                    ),
                    Column(
                      children: [
                        PhysicalModel(
                          borderRadius: BorderRadius.only(topRight: Radius.circular(labelRoundness), topLeft: Radius.circular(labelRoundness)),
                          color: Color(0xFF20292E),
                          child: InkWell(
                            onTap: () {
                              animatedMapZoom(true);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(zoomButtonPadding),
                              child: Icon(
                                Icons.add,
                                color: Colors.blueGrey.shade50,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 2,
                        ),
                        PhysicalModel(
                          borderRadius: BorderRadius.only(bottomRight: Radius.circular(labelRoundness), bottomLeft: Radius.circular(labelRoundness)),
                          color: Color(0xFF20292E),
                          child: InkWell(
                            onTap: () {
                              animatedMapZoom(false);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(zoomButtonPadding),
                              child: Icon(
                                Icons.remove,
                                color: Colors.blueGrey.shade50,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        FloatingActionButton(
                          heroTag: "mapRotation" /*No L10n*/,
                          backgroundColor: Color(0xFF20292E),
                          foregroundColor: Colors.blueGrey.shade50,
                          onPressed: () {
                            setState(() {
                              mapControllerRotationRad = 0;
                            });
                            animatedMapRotationReset();
                          },
                          child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: mapControllerRotationRad),
                              duration: const Duration(milliseconds: rotationResetDurationMillis),
                              curve: Curves.decelerate,
                              builder: (BuildContext context, double rotation, Widget? child) {
                                return Transform.rotate(
                                    angle: rotation,
                                    child: Icon(
                                      Icons.navigation,
                                      size: 30,
                                    ));
                              }),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        FloatingActionButton(
                          heroTag: "myLocation" /*No L10n*/,
                          backgroundColor: Color(0xFF20292E),
                          foregroundColor: Colors.blueGrey.shade50,
                          onPressed: () {
                            _liveUpdate = !_liveUpdate;
                            if (_liveUpdate) {
                              gotoMyLocation();
                            }
                          },
                          child: Icon(Icons.my_location),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints.tightFor(width: 56, height: labelHeight),
                          child: ElevatedButton(
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                              ),
                              style: ButtonStyle(
                                  backgroundColor: MaterialStateProperty.all(Color(0xFF20292E)),
                                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(RoundedRectangleBorder(
                                    borderRadius: BorderRadius.only(topRight: Radius.circular(labelRoundness), bottomRight: Radius.circular(labelRoundness)),
                                  ))),
                              onPressed: () => {
                                    if (_locationResult.coordinates != null && isLoading == false) //&& _locationResult.nearBy != null)
                                      {Navigator.pop(context, _locationResult)}
                                  }),
                        )
                      ],
                    ),
                    SizedBox(
                      width: 10,
                    )
                  ],
                ),
                SizedBox(
                  height: 10,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HorizontalLineLayer extends StatelessWidget {
  const HorizontalLineLayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Divider(
        thickness: 2,
        color: Colors.black,
      ),
    );
  }
}

class LocationMarkerLayer extends StatelessWidget {
  const LocationMarkerLayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedStaticWidget(
        child: Stack(
          children: const [
            Icon(
              Icons.location_on,
              size: 100,
              color: Color(0xFFBF0000),
            ),
            Icon(
              Icons.location_on_outlined,
              size: 100,
              color: Color(0xFF7A0000),
            ),
          ],
        ),
      ),
    );
  }
}
