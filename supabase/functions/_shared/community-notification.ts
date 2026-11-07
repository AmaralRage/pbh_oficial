export function isCommunityNotification(destination?: string | null): boolean {
  try {
    const url = new URL(destination ?? '');
    return url.protocol === 'https:' && url.hostname === 'pbh-oficial.vercel.app'
      && /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(url.searchParams.get('community_post') ?? '');
  } catch { return false; }
}

export function communityNotificationPresentation(destination?: string | null, silent = false) {
  const community = isCommunityNotification(destination);
  return {
    community,
    channel: community ? silent ? 'pbh_community_posts_silent' : 'pbh_community_posts'
      : silent ? 'pbh_announcements_silent' : 'pbh_announcements',
    icon: 'ic_stat_pbh_prominent',
    image: community
      ? 'https://pbh-oficial.vercel.app/icons/Icon-192.png'
      : 'https://pbh-oficial.vercel.app/icons/Icon-512.png',
    color: '#6D28D9',
    title: community ? 'Mensagem do Líder 👑' : null,
  };
}
