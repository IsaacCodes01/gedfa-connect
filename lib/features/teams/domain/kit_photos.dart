import 'dart:typed_data';

/// The three photos of a real kit (2.13b), in the order they are taken.
enum KitPart {
  shirt('Shirt', 'Square photo', 600, 600),
  shorts('Shorts', 'Wide photo', 600, 360),
  socks('Socks', 'Tall photo', 360, 600);

  const KitPart(this.label, this.shape, this.width, this.height);

  final String label;

  /// "Square photo", shown under the name.
  final String shape;

  /// The size the photo is cut and shrunk to on the phone.
  final int width;
  final int height;

  double get aspect => width / height;
}

/// One photo: already uploaded ([url]) or just picked ([bytes]).
class KitPhoto {
  const KitPhoto({this.url, this.bytes});

  final String? url;

  /// Picked on this phone, uploaded when the registration is sent.
  final Uint8List? bytes;

  bool get isEmpty => url == null && bytes == null;
}

/// Shirt, shorts and socks photos of one kit.
class KitPhotos {
  const KitPhotos({
    this.shirt = const KitPhoto(),
    this.shorts = const KitPhoto(),
    this.socks = const KitPhoto(),
  });

  final KitPhoto shirt;
  final KitPhoto shorts;
  final KitPhoto socks;

  KitPhoto operator [](KitPart part) => switch (part) {
        KitPart.shirt => shirt,
        KitPart.shorts => shorts,
        KitPart.socks => socks,
      };

  KitPhotos withPart(KitPart part, KitPhoto photo) => KitPhotos(
        shirt: part == KitPart.shirt ? photo : shirt,
        shorts: part == KitPart.shorts ? photo : shorts,
        socks: part == KitPart.socks ? photo : socks,
      );

  /// How many of the three are still missing.
  int get missing => KitPart.values.where((part) => this[part].isEmpty).length;

  bool get isComplete => missing == 0;

  /// True while some photo still has to be uploaded.
  bool get hasNewPhotos =>
      KitPart.values.any((part) => this[part].bytes != null);

  /// Only the download links are saved in Firestore.
  Map<String, dynamic> toMap() => {
        for (final part in KitPart.values) part.name: this[part].url,
      };

  static KitPhotos? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    KitPhoto read(KitPart part) => KitPhoto(url: map[part.name] as String?);
    return KitPhotos(
      shirt: read(KitPart.shirt),
      shorts: read(KitPart.shorts),
      socks: read(KitPart.socks),
    );
  }
}
