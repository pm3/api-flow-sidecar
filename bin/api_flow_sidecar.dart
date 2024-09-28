import 'dart:io';

import 'package:api_flow_sidecar/api_flow_sidecar.dart';
import 'package:args/args.dart';
import 'package:logging/logging.dart';


Future<void> main(List<String> arguments) async {

  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  var workerName = Platform.environment['WORKER_NAME'];
  if(workerName==null){
    print('env WORKER_NAME is required');
    return Future.value(1);
  }

  var parser = ArgParser();
  parser.addOption('concurrency', abbr: 'c', defaultsTo: "1", help: "max concurrency");
  parser.addOption('workerPathPrefix', abbr: 'n', help: "worker path prefix", mandatory: true);
  parser.addOption('gatewayUrl', help: "gateway url", mandatory: true);
  parser.addOption('gatewayApiKey', defaultsTo: null);
  parser.addOption('appUrl', help: "app url", mandatory: true);
  var results = parser.parse(arguments);

  startSidecar(Sidecar(
    concurrency: results['concurrency'], 
    workerPathPrefix: results['workerPathPrefix'], 
    gatewayUrl: results['gatewayUrl'], 
    gatewayApiKey: results['gatewayApiKey'], 
    appUrl: results['appUrl'],
    workerName : workerName));
}
