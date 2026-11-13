/// Модели данных WayPoint AI.
library;

class WpUser {
  final String id;
  final String? email;
  final String name;
  final String role;
  final bool isGuest;
  final String avatarColor;
  final List<String> interests;

  WpUser({
    required this.id,
    this.email,
    required this.name,
    required this.role,
    required this.isGuest,
    required this.avatarColor,
    required this.interests,
  });

  factory WpUser.fromJson(Map<String, dynamic> j) => WpUser(
        id: j['id'] as String,
        email: j['email'] as String?,
        name: (j['name'] ?? 'Путешественник') as String,
        role: (j['role'] ?? 'user') as String,
        isGuest: (j['isGuest'] ?? false) as bool,
        avatarColor: (j['avatarColor'] ?? '#007AFF') as String,
        interests: List<String>.from(j['interests'] ?? const []),
      );
}

class Place {
  final String name;
  final double lat;
  final double lon;
  final String? address;
  final double? stars;
  final String? photo;
  final String? website;
  final String? phone;

  Place({
    required this.name,
    required this.lat,
    required this.lon,
    this.address,
    this.stars,
    this.photo,
    this.website,
    this.phone,
  });

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: (j['name'] ?? '') as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        address: j['address'] as String?,
        stars: (j['stars'] as num?)?.toDouble(),
        photo: j['photo'] as String?,
        website: j['website'] as String?,
        phone: j['phone'] as String?,
      );
}

class TripItem {
  final String id;
  final String time;
  final String category;
  final String title;
  final String description;
  final int? durationMin;
  final Place? place;
  final String? googleMapsUrl;

  TripItem({
    required this.id,
    required this.time,
    required this.category,
    required this.title,
    required this.description,
    this.durationMin,
    this.place,
    this.googleMapsUrl,
  });

  factory TripItem.fromJson(Map<String, dynamic> j) => TripItem(
        id: (j['id'] ?? '') as String,
        time: (j['time'] ?? '') as String,
        category: (j['category'] ?? 'other') as String,
        title: (j['title'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        durationMin: (j['durationMin'] as num?)?.toInt(),
        place: j['place'] != null ? Place.fromJson(j['place'] as Map<String, dynamic>) : null,
        googleMapsUrl: j['googleMapsUrl'] as String?,
      );
}

class DayWeather {
  final int? tempMax;
  final int? tempMin;
  final String description;
  final String icon;
  final int? precipProb;

  DayWeather({this.tempMax, this.tempMin, required this.description, required this.icon, this.precipProb});

  factory DayWeather.fromJson(Map<String, dynamic> j) => DayWeather(
        tempMax: (j['tempMax'] as num?)?.toInt(),
        tempMin: (j['tempMin'] as num?)?.toInt(),
        description: (j['description'] ?? '') as String,
        icon: (j['icon'] ?? 'cloudy') as String,
        precipProb: (j['precipProb'] as num?)?.toInt(),
      );
}

class DayRoute {
  final List<List<double>> polyline;
  final double? distanceKm;
  final int? durationMin;
  final String? googleMapsUrl;

  DayRoute({required this.polyline, this.distanceKm, this.durationMin, this.googleMapsUrl});

  factory DayRoute.fromJson(Map<String, dynamic>? j) {
    if (j == null) return DayRoute(polyline: const []);
    return DayRoute(
      polyline: (j['polyline'] as List? ?? const [])
          .map((p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()])
          .toList(),
      distanceKm: (j['distanceKm'] as num?)?.toDouble(),
      durationMin: (j['durationMin'] as num?)?.toInt(),
      googleMapsUrl: j['googleMapsUrl'] as String?,
    );
  }
}

class TripDay {
  final int index;
  final String date;
  final String title;
  final String summary;
  final DayWeather? weather;
  final List<TripItem> items;
  final DayRoute route;

  TripDay({
    required this.index,
    required this.date,
    required this.title,
    required this.summary,
    this.weather,
    required this.items,
    required this.route,
  });

  factory TripDay.fromJson(Map<String, dynamic> j) => TripDay(
        index: (j['index'] ?? 0) as int,
        date: (j['date'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        summary: (j['summary'] ?? '') as String,
        weather: j['weather'] != null ? DayWeather.fromJson(j['weather'] as Map<String, dynamic>) : null,
        items: (j['items'] as List? ?? const []).map((e) => TripItem.fromJson(e as Map<String, dynamic>)).toList(),
        route: DayRoute.fromJson(j['route'] as Map<String, dynamic>?),
      );
}

class Trip {
  final String id;
  final String title;
  final String destination;
  final String? country;
  final double centerLat;
  final double centerLon;
  final String startDate;
  final String endDate;
  final String? coverPhoto;
  final List<String> photos;
  final List<TripDay> days;

  Trip({
    required this.id,
    required this.title,
    required this.destination,
    this.country,
    required this.centerLat,
    required this.centerLon,
    required this.startDate,
    required this.endDate,
    this.coverPhoto,
    required this.photos,
    required this.days,
  });

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: (j['_id'] ?? j['id']) as String,
        title: (j['title'] ?? '') as String,
        destination: (j['destination'] ?? '') as String,
        country: j['country'] as String?,
        centerLat: ((j['center']?['lat'] ?? 0) as num).toDouble(),
        centerLon: ((j['center']?['lon'] ?? 0) as num).toDouble(),
        startDate: (j['startDate'] ?? '') as String,
        endDate: (j['endDate'] ?? '') as String,
        coverPhoto: j['coverPhoto'] as String?,
        photos: List<String>.from(j['photos'] ?? const []),
        days: (j['days'] as List? ?? const []).map((e) => TripDay.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class TripProposal {
  final String title;
  final String destination;
  final double lat;
  final double lon;
  final int days;
  final List<String> highlights;
  final String summary;
  final Map<String, dynamic> raw;

  TripProposal({
    required this.title,
    required this.destination,
    required this.lat,
    required this.lon,
    required this.days,
    required this.highlights,
    required this.summary,
    required this.raw,
  });

  factory TripProposal.fromJson(Map<String, dynamic> j) => TripProposal(
        title: (j['title'] ?? '') as String,
        destination: (j['destination'] ?? '') as String,
        lat: ((j['lat'] ?? 0) as num).toDouble(),
        lon: ((j['lon'] ?? 0) as num).toDouble(),
        days: ((j['days'] ?? 1) as num).toInt(),
        highlights: List<String>.from(j['highlights'] ?? const []),
        summary: (j['summary'] ?? '') as String,
        raw: j,
      );
}

class ChatMessage {
  final String role; // user | model
  final String text;
  final TripProposal? proposal;
  final String? tripId;
  final bool hasImage;
  final DateTime? createdAt;

  ChatMessage({
    required this.role,
    required this.text,
    this.proposal,
    this.tripId,
    this.hasImage = false,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: (j['role'] ?? 'model') as String,
        text: (j['text'] ?? '') as String,
        proposal: j['proposal'] != null ? TripProposal.fromJson(j['proposal'] as Map<String, dynamic>) : null,
        tripId: j['tripId']?.toString(),
        hasImage: j['imageUrl'] != null,
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'] as String) : null,
      );
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String kind;
  final bool read;
  final DateTime createdAt;
  final Map<String, dynamic> data;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.read,
    required this.createdAt,
    required this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'].toString(),
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        kind: (j['kind'] ?? 'system') as String,
        read: (j['read'] ?? false) as bool,
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
        data: Map<String, dynamic>.from(j['data'] ?? const {}),
      );
}
