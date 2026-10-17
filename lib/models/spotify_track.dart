class SpotifyTrack {
  const SpotifyTrack({
    required this.uri,
    required this.name,
    required this.artists,
    required this.album,
    required this.imageUrl,
    required this.spotifyUrl,
    this.playlistPosition,
  });

  final String uri;
  final String name;
  final String artists;
  final String album;
  final String imageUrl;
  final String spotifyUrl;
  final int? playlistPosition;

  factory SpotifyTrack.fromMap(Map<String, dynamic> map) => SpotifyTrack(
        uri: map['uri'] as String? ?? '',
        name: map['name'] as String? ?? '',
        artists: map['artists'] as String? ?? '',
        album: map['album'] as String? ?? '',
        imageUrl: map['imageUrl'] as String? ?? '',
        spotifyUrl: map['spotifyUrl'] as String? ?? '',
        playlistPosition: (map['playlistPosition'] as num?)?.toInt(),
      );
}
