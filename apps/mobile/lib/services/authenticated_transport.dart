import 'dart:collection';

enum AuthenticatedHttpMethod { get, post, put, patch, delete }

enum AuthenticatedBodyKind { empty, json, text, multipart, stream }

final class AuthenticatedFilePart {
  const AuthenticatedFilePart.fromPath({
    required this.field,
    required String this.path,
    this.filename,
  }) : bytes = null;

  AuthenticatedFilePart.fromBytes({
    required this.field,
    required List<int> bytes,
    required this.filename,
  })  : path = null,
        bytes = List<int>.unmodifiable(bytes);

  final String field;
  final String? path;
  final List<int>? bytes;
  final String? filename;
}

final class AuthenticatedRequest {
  AuthenticatedRequest._({
    required this.method,
    required this.uri,
    required this.bodyKind,
    Map<String, String> headers = const {},
    this.jsonBody,
    this.textBody,
    Map<String, String> multipartFields = const {},
    List<AuthenticatedFilePart> multipartFiles = const [],
    this.contentType,
    this.contentLength,
    this.streamFactory,
    this.timeout = const Duration(seconds: 30),
  })  : headers = UnmodifiableMapView(Map<String, String>.from(headers)),
        multipartFields = UnmodifiableMapView(
          Map<String, String>.from(multipartFields),
        ),
        multipartFiles = List<AuthenticatedFilePart>.unmodifiable(
          multipartFiles,
        ) {
    if (headers.keys.any((key) => key.toLowerCase() == 'authorization')) {
      throw ArgumentError.value(
        headers,
        'headers',
        'Authorization is owned by AuthenticatedTransport',
      );
    }
  }

  factory AuthenticatedRequest.get(
    Uri uri, {
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 30),
  }) {
    return AuthenticatedRequest.empty(
      AuthenticatedHttpMethod.get,
      uri,
      headers: headers,
      timeout: timeout,
    );
  }

  factory AuthenticatedRequest.empty(
    AuthenticatedHttpMethod method,
    Uri uri, {
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 30),
  }) {
    return AuthenticatedRequest._(
      method: method,
      uri: uri,
      bodyKind: AuthenticatedBodyKind.empty,
      headers: headers,
      timeout: timeout,
    );
  }

  factory AuthenticatedRequest.json(
    AuthenticatedHttpMethod method,
    Uri uri,
    Object? body, {
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 30),
  }) {
    return AuthenticatedRequest._(
      method: method,
      uri: uri,
      bodyKind: AuthenticatedBodyKind.json,
      headers: headers,
      jsonBody: body,
      contentType: 'application/json',
      timeout: timeout,
    );
  }

  factory AuthenticatedRequest.text(
    AuthenticatedHttpMethod method,
    Uri uri,
    String body, {
    String contentType = 'text/plain; charset=utf-8',
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 30),
  }) {
    return AuthenticatedRequest._(
      method: method,
      uri: uri,
      bodyKind: AuthenticatedBodyKind.text,
      headers: headers,
      textBody: body,
      contentType: contentType,
      timeout: timeout,
    );
  }

  factory AuthenticatedRequest.multipart(
    Uri uri, {
    Map<String, String> fields = const {},
    List<AuthenticatedFilePart> files = const [],
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 30),
  }) {
    return AuthenticatedRequest._(
      method: AuthenticatedHttpMethod.post,
      uri: uri,
      bodyKind: AuthenticatedBodyKind.multipart,
      headers: headers,
      multipartFields: fields,
      multipartFiles: files,
      timeout: timeout,
    );
  }

  factory AuthenticatedRequest.stream(
    AuthenticatedHttpMethod method,
    Uri uri, {
    required int contentLength,
    required Stream<List<int>> Function() streamFactory,
    String? contentType,
    Map<String, String> headers = const {},
    Duration timeout = const Duration(seconds: 30),
  }) {
    if (contentLength < 0) {
      throw ArgumentError.value(contentLength, 'contentLength');
    }
    return AuthenticatedRequest._(
      method: method,
      uri: uri,
      bodyKind: AuthenticatedBodyKind.stream,
      headers: headers,
      contentLength: contentLength,
      streamFactory: streamFactory,
      contentType: contentType,
      timeout: timeout,
    );
  }

  final AuthenticatedHttpMethod method;
  final Uri uri;
  final AuthenticatedBodyKind bodyKind;
  final Map<String, String> headers;
  final Object? jsonBody;
  final String? textBody;
  final Map<String, String> multipartFields;
  final List<AuthenticatedFilePart> multipartFiles;
  final String? contentType;
  final int? contentLength;
  final Stream<List<int>> Function()? streamFactory;
  final Duration timeout;
}

final class AuthenticatedResponse {
  AuthenticatedResponse({
    required this.statusCode,
    required this.body,
    required List<int> bodyBytes,
    required Map<String, String> headers,
  })  : bodyBytes = List<int>.unmodifiable(bodyBytes),
        headers = UnmodifiableMapView(Map<String, String>.from(headers));

  final int statusCode;
  final String body;
  final List<int> bodyBytes;
  final Map<String, String> headers;
}

/// One immutable authenticated authority lease.
///
/// The lease is captured synchronously before consumer work can suspend. Its
/// first credential read binds one account identity; every later send/retry
/// must remain in the same session epoch and identity.
abstract interface class AuthenticatedOperation {
  Future<void> requireSession();

  Future<AuthenticatedResponse> send(AuthenticatedRequest request);
}

abstract interface class AuthenticatedTransport {
  AuthenticatedOperation beginOperation();
}
