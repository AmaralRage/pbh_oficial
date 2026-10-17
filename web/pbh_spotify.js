(function () {
  const apiBase = 'https://api.spotify.com/v1';
  const tokenUrl = 'https://accounts.spotify.com/api/token';
  const scopes = [
    'streaming',
    'user-read-email',
    'user-read-private',
    'user-read-playback-state',
    'user-modify-playback-state',
  ].join(' ');

  let clientId = '';
  let player = null;
  let deviceId = null;
  let sdkReadyResolve;
  const sdkReady = new Promise((resolve) => { sdkReadyResolve = resolve; });

  window.onSpotifyWebPlaybackSDKReady = () => sdkReadyResolve();
  if (window.Spotify) sdkReadyResolve();

  function emit(name, detail = {}) {
    window.dispatchEvent(new CustomEvent(`pbh-spotify-${name}`, { detail }));
  }

  function redirectUri() {
    return `${window.location.origin}${window.location.pathname}`;
  }

  function randomString(length) {
    const bytes = new Uint8Array(length);
    crypto.getRandomValues(bytes);
    return Array.from(bytes, (byte) => String.fromCharCode(byte)).join('');
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
      emit('error', { message: 'A conexão com o Spotify foi cancelada.' });
      return false;
    }
    if (!code) return false;

    const verifier = sessionStorage.getItem('pbh.spotify.verifier');
    const expectedState = sessionStorage.getItem('pbh.spotify.state');
    const returnedState = params.get('state');
    history.replaceState({}, document.title, redirectUri());
    if (!verifier || !expectedState || expectedState !== returnedState) {
      throw new Error('Não foi possível validar o retorno do Spotify. Tente conectar novamente.');
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
    return true;
  }

  function publishState(state) {
    if (!state) return;
    const track = state.track_window && state.track_window.current_track;
    const image = track && track.album && track.album.images && track.album.images[0];
    emit('state', {
      isPlaying: !state.paused,
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
    await player.connect();
    emit('ready', { ready: true });
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
      throw new Error(payload.error && payload.error.message ? payload.error.message : 'O Spotify recusou este comando.');
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

  window.pbhSpotifyLogin = async () => {
    if (!clientId) throw new Error('O Spotify ainda não foi configurado para este app.');
    const verifier = base64Url(new TextEncoder().encode(randomString(64)));
    const challenge = base64Url(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier)));
    const state = base64Url(new TextEncoder().encode(randomString(24)));
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
    window.location.assign(`https://accounts.spotify.com/authorize?${query}`);
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

  window.pbhSpotifyToggle = () => player && player.togglePlay();
  window.pbhSpotifyNext = () => player && player.nextTrack();
  window.pbhSpotifyPrevious = () => player && player.previousTrack();
  window.pbhSpotifySeek = (position) => player && player.seek(position);
  window.pbhSpotifyOpenTrack = (uri) => uri && window.open(uri.replace('spotify:track:', 'https://open.spotify.com/track/'), '_blank', 'noopener');
  window.pbhSpotifyLogout = () => {
    if (player) player.disconnect();
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
