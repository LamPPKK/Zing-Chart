import 'dart:async';
import 'dart:io';

/// Controlled HTTP responses for real Flutter image decode tests.
class ArtworkHttpClient implements HttpClient {
  final responses = <String, Completer<HttpClientResponse>>{};
  final requests = <String>[];

  void respond(String url, {int statusCode = HttpStatus.ok}) {
    responses[url]!.complete(_ArtworkResponse(statusCode));
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests.add(url.toString());
    return _ArtworkRequest(
      responses.putIfAbsent(url.toString(), Completer<HttpClientResponse>.new),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ArtworkRequest implements HttpClientRequest {
  _ArtworkRequest(this.response);
  final Completer<HttpClientResponse> response;

  @override
  Future<HttpClientResponse> close() => response.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ArtworkResponse extends Stream<List<int>> implements HttpClientResponse {
  _ArtworkResponse(this.statusCode);

  final _bytes = File('web/favicon.png').readAsBytesSync();

  @override
  final int statusCode;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
