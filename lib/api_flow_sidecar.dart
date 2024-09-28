import 'dart:async';

import 'package:logging/logging.dart';
import 'package:semaphore/semaphore.dart';

import 'xhttp.dart';

final _logger = Logger('YourClassName');

Future<void> startSidecar(Sidecar sidecar) async {

  var maxCount = sidecar.concurrency;
  try {
    if (maxCount < 1 || maxCount > 50) throw Exception("invalid value");
  } catch (e) {
    print("ignore concurrency $maxCount, set to 1");
    maxCount = 1;
  }
  final semaphore = LocalSemaphore(maxCount);
  await Future.delayed(Duration(seconds: 5));

  while (true) {
    await semaphore.acquire();
    Event? event = await sidecar.checkQueue();
    if (event != null) {
      sidecar.runTask(event).whenComplete(() {
        semaphore.release();
      });
    } else {
      semaphore.release();
    }
  }
}

class Sidecar {
  final int concurrency;
  final String workerPathPrefix;
  final String gatewayUrl;
  final String? gatewayApiKey;
  final String appUrl;
  final String workerName;

  Sidecar({required this.concurrency, 
  required this.workerPathPrefix, 
  required this.gatewayUrl, 
  this.gatewayApiKey, 
  required this.appUrl,
  required this.workerName});

  Future<Event?> checkQueue() async {
    try {
      return await callWorker();
    } catch (e) {
      _logger.info("error step ${e.toString()}");
      return Future.delayed(Duration(seconds: 10), () => null);
    }
  }

  Future<void> runTask(Event event) async {
    _logger.info('read task ${event.id}');
    Future.delayed(Duration(seconds: 120)).then((_) {
      if (event.finished == false) {
        callWorkerResponse(event, 504, "");
      }
    });
    XResponse resp = await callApp(event);
    event.finished = true;
    _logger.info('task response ${resp.statusCode}');
    var resp2 =
        await callWorkerResponse(event, resp.statusCode, resp.body);
    _logger.info("call worker response ${resp2.statusCode}");
  }

  Future<Event?> callWorker() async {
    var path = "$gatewayUrl/.queue/worker?path=$workerPathPrefix&workerId=$workerName";
    var headers = <String, String>{};
    if (gatewayApiKey != null) {
      headers['X-Api-Key'] = gatewayApiKey!;
    }
    _logger.info('call $path');
    var resp = await xhttp(path, headers: headers);
    _logger.info("call worker ${resp.statusCode}");
    if (resp.statusCode == 204 || resp.body=='') return null;
    if (resp.statusCode != 200) {
      throw Exception("call gateway error ${resp.body}");
    }
    var id = resp.headers["fw-event-id"];
    if(id==null) throw Exception("call gateway, response without event id");
    var method = resp.headers["fw-method"] ?? 'post';
    var uri = resp.headers["fw-uri"] ?? workerPathPrefix;
    var eventHeaders = <String,String>{};
    resp.headers.forEach((k,v) {
      if(k.startsWith("fw-header-")) eventHeaders[k.substring(10)]=v;
      if(k.toLowerCase()=='content-type') eventHeaders[k]=v;
    });
    return Event(id, method, uri, eventHeaders, resp.body);
  }

  Future<XResponse> callWorkerResponse(Event event, int status, String body) async {
    var headers = <String, String>{};
    headers['Content-Type'] = "application/json";
    headers['fw-status'] = status.toString();
    if (gatewayApiKey != null) headers['X-Api-Key'] = gatewayApiKey!;
    var path = "$gatewayUrl/.queue/${event.id}";
    _logger.info('call $path');
    var response = await xhttp(path, method: 'post', headers: headers, body:body);
    return response;
  }

  Future<XResponse> callApp(Event event) async {
    var sufix = event.path.startsWith(workerPathPrefix) ? event.path.substring(workerPathPrefix.length) : event.path;
    var path = Uri.parse(appUrl).resolve(sufix).toString();
    _logger.info('call $path');
    var response =
        await xhttp(path, method: event.method, headers: event.headers, body: event.body);
    return response;
  }
}

class Event {
  final String id;
  final String method;
  final String path;
  final Map<String, String> headers;
  final String body;

  bool finished = false;

  Event(this.id, this.method, this.path, this.headers, this.body);
}