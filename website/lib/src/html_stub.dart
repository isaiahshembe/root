// Minimal stub for `dart:html` APIs used in `crowdsource.dart`.
// This file is used on non-web platforms via conditional imports so the
// code can compile. All methods are no-ops or throw when invoked.

// Keep class names and signatures similar to dart:html so code using them
// doesn't need heavy platform-specific changes.

class File {
  int size = 0;

  get name => null;

  get type => null;
}

class FileUploadInputElement {
  String accept = '';
  List<File>? get files => null;
  void click() {}
  // Minimal stream-like fields used in the code; on non-web they won't be used.
  final EventStream onChange = EventStream();
}

class FileReader {
  dynamic result;
  final EventStream onLoadEnd = EventStream();
  final EventStream onError = EventStream();
  void readAsArrayBuffer(File file) {}
}

class Url {
  static String createObjectUrl(File file) => '';
  static void revokeObjectUrl(String url) {}
}

class PositionError {
  int code = 0;
  String? message;
}

class Geolocation {
  /// Mimic browser API: getCurrentPosition(success, [error, options])
  void getCurrentPosition(
    Function success, [
    Function? error,
    PositionOptions? options,
  ]) {
    // Not available on non-web; call error if provided.
    if (error != null) {
      error(Exception('Geolocation not available'));
    }
  }

  void callMethod(String s, List<Object> list) {}
}

class NavigatorJs {
  final Geolocation? geolocation = null;
}

class Window {
  final NavigatorJs navigator = NavigatorJs();
}

final Window window = Window();

class EventStream {
  void listen(void Function(dynamic) _) {}
}

class GeolocationOptions {
  GeolocationOptions();
}

class PositionOptions {
  final bool? enableHighAccuracy;
  final int? timeout;
  final int? maximumAge;

  PositionOptions({this.enableHighAccuracy, this.timeout, this.maximumAge});
}
