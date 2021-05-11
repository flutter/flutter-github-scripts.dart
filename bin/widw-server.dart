import 'dart:io';
import 'dart:isolate';
import 'dart:async';

File targetFile = File('widw.html');

Future main() async {
  late Stream<HttpRequest> server;

  await Isolate.spawn(_updateContent, null);

  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 8080);
  } catch (e) {
    print("Couldn't bind to port 8080: $e");
    exit(-1);
  }

  await for (HttpRequest req in server) {
    if (await targetFile.exists()) {
      print("Serving ${targetFile.path}.");
      req.response.headers.contentType = ContentType.html;
      try {
        await req.response.addStream(targetFile.openRead());
      } catch (e) {
        print("Couldn't read file: $e");
        exit(-1);
      }
    } else {
      print("Can't open ${targetFile.path}.");
      req.response.statusCode = HttpStatus.notFound;
    }
    await req.response.close();
  }
}

void _updateContent(dynamic argument) {
  int counter = 0;
  Timer.periodic(new Duration(seconds: 1), (t) {
    counter++;
    String msg = 'Ticks: ${counter}\n';
    if (!targetFile.existsSync()) {
      targetFile.createSync();
    }
    var opened = targetFile.openSync(mode: FileMode.write);
    opened.writeStringSync(msg);
    opened.close();
  });
}
