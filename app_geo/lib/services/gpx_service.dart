import 'dart:io';

import 'package:gpx/gpx.dart';

import '../models/track_point.dart';
import '../models/trail.dart';

class GpxService {
  /// Serialize a [Trail] to a GPX 1.1 XML document.
  String buildGpx(Trail trail) {
    final gpx = Gpx()
      ..creator = 'app_geo'
      ..version = '1.1'
      ..metadata = Metadata(
        name: trail.name,
        time: trail.startedAt,
      )
      ..trks = [
        Trk(
          name: trail.name,
          trksegs: [
            Trkseg(
              trkpts: trail.points
                  .map(
                    (p) => Wpt(
                      lat: p.latitude,
                      lon: p.longitude,
                      ele: p.altitude,
                      time: p.timestamp,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ];
    return GpxWriter().asString(gpx, pretty: true);
  }

  /// Parse a GPX XML string into a [Trail].
  Trail parseGpx(String xml, {required String fallbackName}) {
    final gpx = GpxReader().fromString(xml);

    final points = <TrackPoint>[];
    for (final trk in gpx.trks) {
      for (final seg in trk.trksegs) {
        for (final pt in seg.trkpts) {
          if (pt.lat == null || pt.lon == null) continue;
          points.add(
            TrackPoint(
              latitude: pt.lat!,
              longitude: pt.lon!,
              altitude: pt.ele,
              timestamp: pt.time ?? DateTime.now(),
            ),
          );
        }
      }
    }

    final firstName = gpx.trks.isNotEmpty ? gpx.trks.first.name : null;
    final name = (firstName != null && firstName.isNotEmpty)
        ? firstName
        : (gpx.metadata?.name ?? fallbackName);

    final start = points.isNotEmpty
        ? points.first.timestamp
        : (gpx.metadata?.time ?? DateTime.now());
    final end = points.isNotEmpty ? points.last.timestamp : start;

    return Trail(
      id: 'imported-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      startedAt: start,
      endedAt: end,
      points: points,
    );
  }

  Future<Trail> parseGpxFile(File file) async {
    final content = await file.readAsString();
    return parseGpx(content, fallbackName: file.uri.pathSegments.last);
  }
}
