(function () {
  const callbackParams = new URLSearchParams(window.location.search);
  if (window.opener && !window.opener.closed && (callbackParams.has('code') || callbackParams.has('error'))) {
    window.opener.postMessage({
      type: 'pbh-spotify-oauth-callback',
      code: callbackParams.get('code'),
      state: callbackParams.get('state'),
      error: callbackParams.get('error'),
    }, window.location.origin);
    window.close();
    return;
  }

  const apiBase = 'https://api.spotify.com/v1';
  const tokenUrl = 'https://accounts.spotify.com/api/token';
  const scopes = [
    'streaming',
    'user-read-email',
    'user-read-private',
    'user-read-playback-state',
    'user-modify-playback-state',
    'playlist-read-private',
  ].join(' ');

  let clientId = '';
  let player = null;
  let deviceId = null;
  let playbackPoll = null;
  let authPopup = null;
  let authPopupMonitor = null;
  let sdkReadyResolve;
  const sdkReady = new Promise((resolve) => { sdkReadyResolve = resolve; });

  window.onSpotifyWebPlaybackSDKReady = () => sdkReadyResolve();
  if (window.Spotify) sdkReadyResolve();

  function emit(name, detail = {}) {
    window.dispatchEvent(new CustomEvent(`pbh-spotify-${name}`, { detail: JSON.stringify(detail) }));
  }

  function redirectUri() {
    return `${window.location.origin}${window.location.pathname}`;
  }

  function randomString(length) {
    const bytes = new Uint8Array(length);
    crypto.getRandomValues(bytes);
    return base64Url(bytes);
  }

  function base64Url(bytes) {
    return btoa(String.fromCharCode(...new Uint8Array(bytes)))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
  }

  async function tokenRequest(body) {
    const response = await fetch(tokenUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams(body),
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error_description || data.error || 'Falha ao autenticar com o Spotify.');
    return data;
  }

  let token = null;
  let tokenExpiresAt = 0;
  let refreshToken = null;

  function stopAuthPopupMonitor() {
    if (authPopupMonitor) window.clearInterval(authPopupMonitor);
    authPopupMonitor = null;
  }

  async function completeAuthorization(code, returnedState) {
    const verifier = sessionStorage.getItem('pbh.spotify.verifier');
    const expectedState = sessionStorage.getItem('pbh.spotify.state');
    if (!verifier || !expectedState || expectedState !== returnedState) {
      throw new Error('N\u00e3o foi poss\u00edvel validar o retorno do Spotify. Tente conectar novamente.');
    }

    const data = await tokenRequest({
      client_id: clientId,
      grant_type: 'authorization_code',
      code,
      redirect_uri: redirectUri(),
      code_verifier: verifier,
    });
    sessionStorage.removeItem('pbh.spotify.verifier');
    sessionStorage.removeItem('pbh.spotify.state');
    token = data.access_token;
    tokenExpiresAt = Date.now() + data.expires_in * 1000;
    refreshToken = data.refresh_token;
    if (refreshToken) sessionStorage.setItem('pbh.spotify.refresh', refreshToken);
    emit('auth', { authenticated: true });
    await createPlayer();
  }

  window.addEventListener('message', async (event) => {
    if (event.origin !== window.location.origin || event.source !== authPopup) return;
    const data = event.data;
    if (!data || data.type !== 'pbh-spotify-oauth-callback') return;

    authPopup = null;
    stopAuthPopupMonitor();
    try {
      if (data.error) throw new Error('A conex\u00e3o com o Spotify foi cancelada.');
      if (!data.code) throw new Error('O Spotify n\u00e3o retornou o c\u00f3digo de acesso. Tente novamente.');
      await completeAuthorization(data.code, data.state);
    } catch (error) {
      sessionStorage.removeItem('pbh.spotify.verifier');
      sessionStorage.removeItem('pbh.spotify.state');
      emit('error', { message: error.message || 'N\u00e3o foi poss\u00edvel conectar ao Spotify.' });
    }
  });

  async function getToken(forceRefresh = false) {
    if (!forceRefresh && token && Date.now() < tokenExpiresAt - 60000) return token;
    if (!refreshToken) throw new Error('Conecte sua conta Spotify para continuar.');
    const data = await tokenRequest({
      client_id: clientId,
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
    });
    token = data.access_token;
    tokenExpiresAt = Date.now() + data.expires_in * 1000;
    refreshToken = data.refresh_token || refreshToken;
    sessionStorage.setItem('pbh.spotify.refresh', refreshToken);
    emit('auth', { authenticated: true });
    return token;
  }

  async function finishAuthorization() {
    const params = new URLSearchParams(window.location.search);
    const code = params.get('code');
    if (params.has('error')) {
      history.replaceState({}, document.title, redirectUri());
      emit('error', { message: 'A conex\u00e3o com o Spotify foi cancelada.' });
      return false;
    }
    if (!code) return false;

    const returnedState = params.get('state');
    history.replaceState({}, document.title, redirectUri());
    await completeAuthorization(code, returnedState);
    return true;
  }

  function publishState(state) {
    if (!state) return;
    const track = state.track_window && state.track_window.current_track;
    const image = track && track.album && track.album.images && track.album.images[0];
    emit('state', {
      isPlaying: !state.paused,
      shuffleEnabled: state.shuffle === true,
      repeatMode: Number.isInteger(state.repeat_mode) ? state.repeat_mode : 0,
      position: state.position || 0,
      duration: state.duration || (track && track.duration_ms) || 0,
      track: track ? {
        uri: track.uri || '',
        name: track.name || '',
        artists: (track.artists || []).map((artist) => artist.name).join(', '),
        album: (track.album && track.album.name) || '',
        imageUrl: (image && image.url) || '',
        spotifyUrl: track.external_urls && track.external_urls.spotify,
      } : null,
    });
  }

  async function createPlayer() {
    if (player) return;
    await sdkReady;
    player = new Spotify.Player({
      name: 'PBH Oficial',
      volume: 0.7,
      getOAuthToken: (callback) => getToken().then(callback).catch((error) => emit('error', { message: error.message })),
    });
    player.addListener('ready', ({ device_id }) => {
      deviceId = device_id;
      emit('ready', { ready: true });
      if (playbackPoll) window.clearInterval(playbackPoll);
      playbackPoll = window.setInterval(() => {
        player.getCurrentState().then(publishState).catch(() => {});
      }, 900);
    });
    player.addListener('not_ready', () => {
      deviceId = null;
      emit('ready', { ready: false });
    });
    player.addListener('player_state_changed', publishState);
    player.addListener('account_error', () => emit('error', { message: 'A reprodução pelo Spotify exige uma conta Premium.' }));
    player.addListener('authentication_error', () => emit('error', { message: 'A sessão do Spotify expirou. Conecte novamente.' }));
    player.addListener('initialization_error', ({ message }) => emit('error', { message: message || 'Este navegador não conseguiu iniciar o player do Spotify.' }));
    player.addListener('playback_error', ({ message }) => emit('error', { message: message || 'O Spotify não conseguiu iniciar esta faixa.' }));
    player.addListener('autoplay_failed', () => emit('error', { message: 'Toque em reproduzir para liberar o áudio neste navegador.' }));
    const connected = await player.connect();
    if (!connected) emit('error', { message: 'Não foi possível conectar o player Spotify neste navegador.' });
  }

  async function spotifyFetch(path, options = {}) {
    let accessToken = await getToken();
    let response = await fetch(`${apiBase}${path}`, {
      ...options,
      headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json', ...(options.headers || {}) },
    });
    if (response.status === 401) {
      accessToken = await getToken(true);
      response = await fetch(`${apiBase}${path}`, {
        ...options,
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json', ...(options.headers || {}) },
      });
    }
    if (!response.ok && response.status !== 204) {
      const payload = await response.json().catch(() => ({}));
      const message = payload.error && payload.error.message ? payload.error.message : 'O Spotify recusou este comando.';
      throw new Error(`${message} (HTTP ${response.status})`);
    }
    return response;
  }

  window.pbhSpotifyInitialize = async (id) => {
    clientId = id || '';
    if (!clientId) {
      emit('config', { configured: false });
      return;
    }
    emit('config', { configured: true });
    try {
      const authorized = await finishAuthorization();
      if (!authorized) {
        refreshToken = sessionStorage.getItem('pbh.spotify.refresh');
        if (refreshToken) await getToken(true);
      }
      if (refreshToken) await createPlayer();
    } catch (error) {
      emit('error', { message: error.message || 'Não foi possível conectar ao Spotify.' });
    }
  };

  window.pbhSpotifyLogin = async (forceConsent = false) => {
    if (!clientId) throw new Error('O Spotify ainda n\u00e3o foi configurado para este app.');
    const popup = window.open('about:blank', 'pbhSpotifyAuth', 'popup,width=520,height=720');
    if (!popup) throw new Error('Permita pop-ups neste site para conectar ao Spotify.');
    authPopup = popup;

    try {
      const verifier = randomString(64);
      const challenge = base64Url(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier)));
      const state = randomString(24);
      sessionStorage.setItem('pbh.spotify.verifier', verifier);
      sessionStorage.setItem('pbh.spotify.state', state);
      const query = new URLSearchParams({
        client_id: clientId,
        response_type: 'code',
        redirect_uri: redirectUri(),
        code_challenge_method: 'S256',
        code_challenge: challenge,
        state,
        scope: scopes,
      });
      if (forceConsent) query.set('show_dialog', 'true');
      popup.location.href = 'https://accounts.spotify.com/authorize?' + query;
      stopAuthPopupMonitor();
      authPopupMonitor = window.setInterval(() => {
        if (authPopup !== popup || !popup.closed) return;
        authPopup = null;
        stopAuthPopupMonitor();
        sessionStorage.removeItem('pbh.spotify.verifier');
        sessionStorage.removeItem('pbh.spotify.state');
        emit('error', { message: 'A janela de conex\u00e3o do Spotify foi fechada antes de concluir o acesso.' });
      }, 700);
    } catch (error) {
      popup.close();
      authPopup = null;
      throw error;
    }
  };

  window.pbhSpotifyStartPlaylist = async (playlistId) => {
    if (!player) await createPlayer();
    player.activateElement();
    if (!deviceId) throw new Error('O player está conectando. Tente novamente em alguns segundos.');
    await spotifyFetch(`/me/player/play?device_id=${encodeURIComponent(deviceId)}`, {
      method: 'PUT',
      body: JSON.stringify({ context_uri: `spotify:playlist:${playlistId}` }),
    });
    emit('playing_context', { playlistId });
  };

  window.pbhSpotifyGetPlaylistTracks = async (playlistId) => {
    const tracks = [];
    const limit = 50;
    let offset = 0;
    let total = 0;

    do {
      const params = new URLSearchParams({ limit: String(limit), offset: String(offset), market: 'BR' });
      const response = await spotifyFetch(`/playlists/${encodeURIComponent(playlistId)}/items?${params.toString()}`);
      const payload = await response.json();
      const items = payload.items || [];

      for (let index = 0; index < items.length; index++) {
        const entry = items[index];
        const track = entry && (entry.item || entry.track);
        if (!track || track.type !== 'track' || !track.uri) continue;
        tracks.push({
          uri: track.uri,
          name: track.name || '',
          artists: (track.artists || []).map((artist) => artist.name).join(', '),
          album: (track.album && track.album.name) || '',
          imageUrl: (track.album && track.album.images && track.album.images[0] && track.album.images[0].url) || '',
          spotifyUrl: (track.external_urls && track.external_urls.spotify) || '',
          playlistPosition: offset + index,
        });
      }

      total = Number(payload.total) || 0;
      offset += items.length;
      if (items.length === 0) break;
    } while (offset < total);

    return JSON.stringify(tracks);
  };

  window.pbhSpotifyPlayPlaylistTrack = async (playlistId, position, uri) => {
    if (!deviceId) throw new Error('O player Spotify ainda está conectando.');
    if (player) player.activateElement();
    await spotifyFetch(`/me/player/play?device_id=${encodeURIComponent(deviceId)}`, {
      method: 'PUT',
      body: JSON.stringify({
        context_uri: `spotify:playlist:${playlistId}`,
        offset: Number.isInteger(position) ? { position } : { uri },
      }),
    });
  };

  window.pbhSpotifyToggle = () => player && player.togglePlay();
  window.pbhSpotifyNext = () => player && player.nextTrack();
  window.pbhSpotifyPrevious = () => player && player.previousTrack();
  window.pbhSpotifySeek = (position) => player && player.seek(position);
  window.pbhSpotifySetShuffle = async (enabled) => {
    if (!deviceId) throw new Error('O player Spotify ainda estÃ¡ conectando.');
    await spotifyFetch(`/me/player/shuffle?state=${Boolean(enabled)}&device_id=${encodeURIComponent(deviceId)}`, { method: 'PUT' });
  };
  window.pbhSpotifySetRepeat = async (mode) => {
    if (!deviceId) throw new Error('O player Spotify ainda estÃ¡ conectando.');
    const repeatMode = ['off', 'context', 'track'][mode] || 'off';
    await spotifyFetch(`/me/player/repeat?state=${repeatMode}&device_id=${encodeURIComponent(deviceId)}`, { method: 'PUT' });
  };
  window.pbhSpotifyOpenTrack = (uri) => uri && window.open(uri.replace('spotify:track:', 'https://open.spotify.com/track/'), '_blank', 'noopener');
  window.pbhSpotifyLogout = () => {
    if (player) player.disconnect();
    if (playbackPoll) window.clearInterval(playbackPoll);
    playbackPoll = null;
    player = null;
    deviceId = null;
    token = null;
    tokenExpiresAt = 0;
    refreshToken = null;
    sessionStorage.removeItem('pbh.spotify.refresh');
    emit('auth', { authenticated: false });
    emit('state', { isPlaying: false, position: 0, duration: 0, track: null });
  };
})();
