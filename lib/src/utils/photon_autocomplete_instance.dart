import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_photon/flutter_photon.dart';

import '../base_widget/photon_autocomplete.dart';

///item builder for placeFieldAutocomplete
Widget photonAutocompleteSuggestionItem(BuildContext context, PhotonFeature suggestion) {
  return Padding(
    padding: const EdgeInsets.all(10.0),
    child: getLocationLabelRich(suggestion),
    // child: Text(
    //   getLocationLabel(suggestion),
    //   style: TextStyle(fontSize: 17, color: Colors.blueGrey[500]),
    // ),
  );
}

RichText getLocationLabelRich(PhotonFeature suggestion) {
  return RichText(
    text: TextSpan(
      style: TextStyle(fontSize: 30, color: Colors.blueGrey[500]),
      children: <TextSpan>[
        (suggestion.name != null) ? TextSpan(text: "${suggestion.name!} • ", style: const TextStyle(fontSize: 35, color: Colors.blue)) : const TextSpan(),
        (suggestion.street != null) ? TextSpan(text: "${suggestion.street!} • ", style: const TextStyle()) : const TextSpan(),
        (suggestion.city != null) ? TextSpan(text: "${suggestion.city!} • ", style: const TextStyle()) : const TextSpan(),
        (suggestion.county != null) ? TextSpan(text: "${suggestion.county!} • ", style: const TextStyle()) : const TextSpan(),
        (suggestion.district != null) ? TextSpan(text: "${suggestion.district!} • ", style: const TextStyle()) : const TextSpan(),
        (suggestion.state != null) ? TextSpan(text: "${suggestion.state!} • ", style: const TextStyle()) : const TextSpan(),
        (suggestion.country != null) ? TextSpan(text: suggestion.country, style: const TextStyle(fontWeight: FontWeight.bold)) : const TextSpan(),
        //(suggestion.postcode != null) ? TextSpan(text: "Pin: ${suggestion.postcode}", style: TextStyle(fontStyle: FontStyle.italic)):TextSpan(),
      ],
    ), textScaler: const TextScaler.linear(0.5),
  );
}

String getLocationLabel(PhotonFeature suggestion, {bool newLineBeforeState = false}) {
  String locationLabel = "";
  locationLabel += (suggestion.name != null) ? "${suggestion.name!}, " : "";
  locationLabel += (suggestion.street != null) ? "${suggestion.street!}, " : "";
  locationLabel += (suggestion.city != null) ? "${suggestion.city!}, " : "";
  locationLabel += (suggestion.county != null) ? "${suggestion.county!}, " : "";
  locationLabel += (suggestion.district != null) ? "${suggestion.district!}, " : "";
  locationLabel += (suggestion.state != null) ? "${suggestion.state!}, " : "";
  locationLabel += (suggestion.country != null) ? suggestion.country! : "";
  //locationLabel += (suggestion.postcode != null) ? ", Pin: ${suggestion.postcode}" : "";
  return locationLabel;
}

Widget photonAutocomplete({
  Function? textSubmitted,
  List<PhotonFeature>? suggestions,
  Function? textChanged,
  Function? itemSubmitted,
  TextEditingController? controller,
  List<TextInputFormatter>? inputFormatters,
  fontSize = 40.0,
  label,
  bool isText = false,
  bool? enabled,
}) {
  inputFormatters = inputFormatters ?? [];
  controller = (controller == null) ? TextEditingController() : controller;
  return PhysicalModel(
    elevation: 20.0,
    shadowColor: Colors.black,
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
      child: PhotonAutocomplete<PhotonFeature>(
        key: GlobalKey(),
        textAlign: TextAlign.center,
        textParser: (suggestion) => suggestion.name,
        clearOnSubmit: false,
        itemBuilder: photonAutocompleteSuggestionItem,
        itemSubmitted: (item) => (itemSubmitted == null) ? {} : itemSubmitted(item),
        suggestions: suggestions ?? [],
        textChanged: (value) => (textChanged == null) ? {} : textChanged(value),
        textSubmitted: (value) => (textSubmitted == null) ? {} : textSubmitted(value),
        style: TextStyle(fontSize: fontSize, color: Colors.blueGrey),
        decoration: InputDecoration(
          counterText: '',
          labelText: label ?? '',
          labelStyle: const TextStyle(color: Colors.black45, fontSize: 18),
          floatingLabelBehavior: FloatingLabelBehavior.never,
          // fillColor: Colors.black12,
          // filled: true,
          contentPadding: const EdgeInsets.fromLTRB(15, 10, 15, 0),
          isDense: true,
          border: const OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
        controller: controller,
        inputFormatters: inputFormatters,
        keyboardType: TextInputType.text,
      ),
    ),
  );
}
