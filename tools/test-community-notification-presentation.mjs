import fs from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import test from 'node:test';
import assert from 'node:assert/strict';

test('leader notifications use PBH branding and preserve silent delivery',async()=>{
  const source=await fs.readFile(new URL('../supabase/functions/_shared/community-notification.ts',import.meta.url),'utf8');
  const module=await import(`data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(source)).toString('base64')}`);
  const destination='https://pbh-oficial.vercel.app/?community_post=bc500000-0000-4000-8000-000000000003';
  const normal=module.communityNotificationPresentation(destination);
  assert.equal(normal.channel,'pbh_community_posts');
  assert.equal(normal.icon,'ic_stat_pbh_prominent');assert.equal(normal.color,'#6D28D9');
  assert.equal(normal.title,'Mensagem do Líder 👑');
  assert.equal(module.communityNotificationPresentation(destination,true).channel,'pbh_community_posts_silent');
  const general=module.communityNotificationPresentation('https://other.invalid/');
  assert.equal(general.community,false);assert.equal(general.channel,'pbh_announcements');
  assert.equal(general.color,'#6D28D9');
  assert.equal(general.title,null);
  assert.equal(module.isCommunityNotification('https://other.invalid/?community_post=bc500000-0000-4000-8000-000000000003'),false);
});
