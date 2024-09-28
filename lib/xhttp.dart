import 'dart:async';
import 'dart:io';
import 'dart:convert';

enum XMethod {
  get,
  post,
  put;

  static XMethod convert(String inp) {
    return XMethod.values.firstWhere((e) => e.name == inp);
  }  
}

class XResponse {
  int statusCode;
  Map<String, String> headers;
  String body;

  XResponse(
    this.statusCode,
    this.headers,
    this.body,
  );
}

Future<XResponse> xhttp(String path,
    {XMethod method = XMethod.get,
    Map<String, String>? headers,
    String? body,
    int connectionTimeout = 10,
    int readTimeout = 120}) async {
  var client = HttpClient();
  try {
    client.connectionTimeout = Duration(seconds: connectionTimeout);

    Uri uri = Uri.parse(path);

    var request = await client.openUrl(method.name, uri);
    if (body != null) request.add(utf8.encode(body));
    if (headers != null) {
      for (var e in headers.entries) {
        request.headers.add(e.key, e.value);
      }
    }
    HttpClientResponse resp = await request.close().timeout(Duration(seconds: readTimeout));
    Map<String, String> respHeaders = {};
    resp.headers.forEach((k,v)=>respHeaders[k]=v.first);
    String respBody = await readResponseBody(resp);
    return Future.value(XResponse(resp.statusCode, respHeaders, respBody));
  } on TimeoutException {
    return Future.value(XResponse(-1, {}, "Timeout"));
  } finally {
    client.close();
  }
}

Future<String> readResponseBody(HttpClientResponse response) {
  final completer = Completer<String>();
  final contents = StringBuffer();
  response.transform(utf8.decoder).listen((data) {
    contents.write(data);
  }, onDone: () => completer.complete(contents.toString()));
  return completer.future;
}
