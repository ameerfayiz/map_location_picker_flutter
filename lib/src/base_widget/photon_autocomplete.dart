import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/services/text_formatter.dart';
import 'package:flutter_photon/flutter_photon.dart';

typedef StringCallback = Function(String data);
typedef InputEventCallback<T> = Function(T data);

class PhotonAutocomplete<T> extends StatefulWidget {
  @override
  final GlobalKey<PhotonAutocompleteState<T>> key;
  final TextAlign? textAlign;
  final bool clearOnSubmit;
  final itemBuilder;
  final InputEventCallback<T>? itemSubmitted;
  final List<PhotonFeature> suggestions;
  final StringCallback? textChanged, textSubmitted;
  final TextStyle? style;
  final ValueSetter<bool>? onFocusChanged;
  final InputDecoration decoration;
  final TextEditingController? controller;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final Function? textParser;

  const PhotonAutocomplete({
    required this.itemSubmitted, //Callback on item selected, this is the item selected of type <T>
    required this.key, //GlobalKey used to enable addSuggestion etc
    required this.suggestions, //Suggestions that will be displayed
    required this.itemBuilder, //Callback to build each item, return a Widget
    this.inputFormatters,
    this.style,
    this.decoration = const InputDecoration(),
    this.textChanged, //Callback on input text changed, this is a string
    this.textSubmitted, //Callback on input text submitted, this is also a string
    this.onFocusChanged,
    this.keyboardType = TextInputType.text,
    this.clearOnSubmit = true, //Clear autoCompleteTextfield on submit
    this.textInputAction = TextInputAction.done,
    this.controller,
    this.focusNode,
    this.textAlign,
    this.textCapitalization = TextCapitalization.sentences,
    this.textParser,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => PhotonAutocompleteState<T>(
        textAlign,
        clearOnSubmit,
        itemBuilder,
        itemSubmitted,
        suggestions,
        textChanged,
        textSubmitted,
        style,
        onFocusChanged,
        decoration,
        controller,
        inputFormatters,
        textCapitalization,
        keyboardType,
        textInputAction,
        focusNode,
        textParser,
      );
}

class PhotonAutocompleteState<T> extends State<PhotonAutocomplete> {
  ///FOR LOCAL USAGE
  OverlayEntry? listSuggestionsEntry;
  TextField? textField;
  String currentText = "";
  late List<T> filteredSuggestions;
  final LayerLink _layerLink = LayerLink();
  final api = PhotonApi();
  late CancelableOperation connectOperation;

  ///FOR CONSTRUCTOR
  final TextAlign? textAlign;
  final bool clearOnSubmit;
  final itemBuilder;
  final InputEventCallback<T>? itemSubmitted;
  final List<PhotonFeature> suggestions;
  final StringCallback? textChanged, textSubmitted;
  final TextStyle? style;
  final ValueSetter<bool>? onFocusChanged;
  final InputDecoration decoration;
  final TextEditingController? controller;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  Function? textParser;

  PhotonAutocompleteState(this.textAlign, this.clearOnSubmit, this.itemBuilder, this.itemSubmitted, this.suggestions, this.textChanged, this.textSubmitted, this.style, this.onFocusChanged, this.decoration, this.controller, this.inputFormatters,
      this.textCapitalization, this.keyboardType, this.textInputAction, this.focusNode, this.textParser) {
    filteredSuggestions = [];
    textField = TextField(
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      decoration: decoration,
      style: style,
      keyboardType: keyboardType,
      focusNode: focusNode ?? FocusNode(),
      controller: controller ?? TextEditingController(),
      textInputAction: textInputAction,
      onChanged: (newText) {
        currentText = newText;
        updateOverlay(newText);

        if (textChanged != null) {
          textChanged!(newText);
        }
      },
      onTap: () async {
        await updateOverlay(currentText);
      },
      onSubmitted: (submittedText) => triggerSubmitted(submittedText: submittedText),
    );

    if (this.controller != null) {
      currentText = this.controller!.text;
    }

    textField!.focusNode!.addListener(() async {
      if (onFocusChanged != null) {
        onFocusChanged!(textField!.focusNode!.hasFocus);
      }

      if (!textField!.focusNode!.hasFocus) {
        updateOverlay();
      } else if (!(currentText == "")) {
        updateOverlay(currentText);
      }
    });
  }

  void clear() {
    textField!.controller!.clear();
    currentText = "";
    updateOverlay();
  }

  void triggerSubmitted({submittedText}) {
    submittedText == null ? textSubmitted!(currentText) : textSubmitted!(submittedText);
  }

  Future<void> updateOverlay([String? query]) async {
    if (listSuggestionsEntry == null) {
      final Size textFieldSize = (context.findRenderObject() as RenderBox).size;
      final width = textFieldSize.width;
      final height = textFieldSize.height;
      listSuggestionsEntry = OverlayEntry(builder: (context) {
        return Positioned(
            width: width,
            child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0.0, height + 10),
                child: SizedBox(
                    width: width,
                    height: (filteredSuggestions.length > 6) ? 60 * 5 : null,
                    child: Card(
                        child: SingleChildScrollView(
                            child: Column(
                      children: filteredSuggestions.map((suggestion) {
                        return Row(children: [
                          Expanded(
                              child: InkWell(
                                  child: itemBuilder!(context, suggestion),
                                  onTap: () {
                                    setState(() {
                                      String newText = textParser!(suggestion);
                                      textField!.controller!.text = newText;
                                      textField!.focusNode!.unfocus();
                                      itemSubmitted!(suggestion);
                                    });
                                  }))
                        ]);
                      }).toList(),
                    ))))));
      });
      Overlay.of(context).insert(listSuggestionsEntry!);
    }

    filteredSuggestions = await getSuggestionsCancellable(query);

    listSuggestionsEntry!.markNeedsBuild();
  }

  Future<List<T>> getSuggestions(String? query) async {
    if (query != null) {
      if (query.length > 2) {
        List<T> result = (await api.forwardSearch(query)).cast<T>();
        return result;
      }
    }
    return [];
  }

  Future<List<T>> getSuggestionsCancellable(String? query) async {
    try {
      connectOperation.cancel();
    } catch (e) {}
    connectOperation = CancelableOperation.fromFuture(getSuggestions(query),
        onCancel: () => {
              // print(
              //     "CAANCELLED================================================>>>>>>>>$query")
            });
    return await connectOperation.value;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
        link: _layerLink,
        child: Row(
          children: [
            Expanded(child: textField!),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => {
                setState(() {
                  clear();
                }),
              },
              icon: const Icon(Icons.clear, color: Colors.blueGrey),
            ),
          ],
        ));
  }
}
