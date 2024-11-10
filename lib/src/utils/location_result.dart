import 'package:flutter_photon/flutter_photon.dart';
import 'package:latlong2/latlong.dart';
import 'package:map_location_picker_flutter/src/utils/photon_autocomplete_instance.dart';

class LocationResult {
  LatLng? coordinates;
  PhotonFeature? nearBy;
  String? userDescription;
  String? locationDescription;

  LocationResult();

  LocationResult.withData(this.coordinates, this.nearBy) {
    locationDescription = getNearByString;
  }

  void setData(LatLng? coordinates, PhotonFeature? nearBy, {String? locationDescription}) {
    this.coordinates = coordinates;
    this.nearBy = nearBy;
    this.locationDescription = locationDescription ?? getNearByString;
  }

  String? get getNearByString {
    if (nearBy != null) {
      return getLocationLabel(nearBy!, newLineBeforeState: true);
    } else {
      return null;
    }
  }
}
