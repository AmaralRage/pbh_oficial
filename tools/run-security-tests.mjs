import fs from 'node:fs/promises';
import { pathToFileURL, fileURLToPath } from 'node:url';

// The same migration tests run in CI and locally, without a remote database.
const root = new URL('../', import.meta.url);
const moduleUrl = process.env.PBH_PGLITE_MODULE || new URL('build/security-deps/node_modules/@electric-sql/pglite/dist/index.js', root).href;
await import(moduleUrl); // Fail before claiming any tests ran if the dependency is absent.
const selected = [
  'private_chat_test',
  'private_chat_audio_test',
  'chat_notification_previews_test',
  'idempotent_comments_test',
  'member_data_isolation_test', 'private_support_replies_test',
  'support_reply_notifications_test', 'journey_privacy_test',
  'member_badge_awards_test', 'progression_member_badges_test',
  'community_photo_feed_test', 'community_comment_likes_test',
  'profile_backgrounds_test', 'community_profile_refinements_test',
  'leader_post_broadcasts_test', 'leader_message_notification_design_test',
];
const tests = [];
globalThis.Deno = {
  readTextFile: (path) => fs.readFile(path, 'utf8'),
  test: (name, run) => tests.push({ name, run }),
};
const output = new URL('build/security-tests/', root);
await fs.mkdir(output, { recursive: true });
for (const name of selected) {
  const sourceUrl = new URL(`supabase/tests/${name}.ts`, root);
  const source = (await fs.readFile(sourceUrl, 'utf8'))
    .replace(/(['"])npm:@electric-sql\/pglite@[^'"]+\1/g, JSON.stringify(moduleUrl))
    .replaceAll('import.meta.url', JSON.stringify(sourceUrl.href));
  const target = new URL(`${name}.mts`, output);
  await fs.writeFile(target, source);
  await import(pathToFileURL(fileURLToPath(target)).href);
}
for (const { name, run } of tests) {
  try { await run(); console.log(`PASS ${name}`); }
  catch (error) { console.error(`FAIL ${name}: ${error.message}`); process.exitCode = 1; }
}
