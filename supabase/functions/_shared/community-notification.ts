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
    icon: community ? 'ic_stat_pbh_community' : 'ic_stat_pbh_prominent',
    color: community ? '#FF6B2C' : '#6D28D9',
  };
}
