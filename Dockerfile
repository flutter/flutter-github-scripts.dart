FROM google/dart
WORKDIR /app
ADD pubspec.* /app/
RUN pub get
ADD . /app
ADD bin/* /app/bin/
RUN pub get --offline

CMD []
ENTRYPOINT ["/usr/bin/dart", "bin/widw-server.dart"]

