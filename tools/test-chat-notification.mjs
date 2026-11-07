import fs from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import test from 'node:test';
import assert from 'node:assert/strict';
const source=await fs.readFile(new URL('../supabase/functions/_shared/chat-notification.ts',import.meta.url),'utf8');
const {chatNotificationPresentation:present}=await import(`data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(source)).toString('base64')}`);
const project='https://fixture.supabase.co',sender='cc070000-0000-4000-8000-000000000001';
test('private previews preserve the sender and text and bound notification size',()=>{
  const result=present({sender_name:'Arthur Morgan',content:'Olá, irmão!'},project);
  assert.equal(result.title,'Arthur Morgan');assert.equal(result.body,'Olá, irmão!');
  assert.equal(present({sender_name:'',content:''},project).title,'Membro');
  assert.equal(present({content:'x'.repeat(300)},project).body.length,240);
  assert.equal(present({has_image:true,content:'Minha foto'},project).body,'Foto: Minha foto');
});
test('voice previews show seconds and minutes instead of raw content',()=>{
  for(const [ms,label] of [[500,'1 s'],[35000,'35 s'],[60000,'1 min'],[65000,'1 min 5 s'],[120000,'2 min']])assert.equal(present({audio_duration_ms:ms,content:'not used'},project).body,`Mensagem de áudio · ${label}`);
});
test('only a public avatar belonging to this sender can be fetched',()=>{
  const avatar=`${project}/storage/v1/object/public/profile-avatars/${sender}/photo.jpg`;
  assert.equal(present({sender_id:sender,sender_avatar:avatar},project).avatar,avatar);
  for(const url of ['http://private.invalid/', 'https://tracker.invalid/photo',`${project}/storage/v1/object/sign/profile-avatars/${sender}/photo.jpg?token=private`,`${project}/storage/v1/object/public/profile-avatars/another-user/photo.jpg`])assert.equal(present({sender_id:sender,sender_avatar:url},project).avatar,null);
  assert.equal(present({sender_founder:true},project).avatar,'https://pbh-oficial.vercel.app/assets/assets/images/perfil.png');
});
