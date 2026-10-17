import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

import '../core/config/spotify_playlist.dart';

class SpotifyPlaylistPlayer extends StatefulWidget {
  const SpotifyPlaylistPlayer({super.key});

  @override
  State<SpotifyPlaylistPlayer> createState() => _SpotifyPlaylistPlayerState();
}

class _SpotifyPlaylistPlayerState extends State<SpotifyPlaylistPlayer> {
  static int _nextViewId = 0;
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'pbh-spotify-playlist-${_nextViewId++}';
    ui.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return html.IFrameElement()
        ..src = 'https://open.spotify.com/embed/playlist/$officialSpotifyPlaylistId?utm_source=generator&theme=0'
        ..title = 'Player da playlist oficial do Projeto Bom Homem'
        ..allow = 'autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture'
        ..allowFullscreen = true
        ..width = '100%'
        ..height = '352'
        ..style.border = '0'
        ..style.borderRadius = '12px';
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 352,
        child: HtmlElementView(viewType: _viewType),
      );
}
