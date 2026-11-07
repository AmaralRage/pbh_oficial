import fs from 'node:fs/promises';
import vm from 'node:vm';
import {stripTypeScriptTypes} from 'node:module';
import test from 'node:test';
import assert from 'node:assert/strict';

test('private worker authenticates before database access and acknowledges only removed media',async()=>{
  const source=(await fs.readFile(new URL('../supabase/functions/process-private-chat/index.ts',import.meta.url),'utf8')).replace(/^import .*;\r?\n/gm,'');
  let handler,created=0,ack=[];
  const admin={rpc:async(name,args)=>{
    if(name==='chat_claim_cleanup')return {data:[{path:'ok.jpg',claim_token:'one'},{path:'retry.jpg',claim_token:'two'}]};
    if(name==='chat_ack_cleanup'){ack.push(args);return {data:null};}
    if(name==='chat_claim_push')return {data:null};
    throw Error('Unexpected RPC '+name);
  },storage:{from:(bucket)=>{assert.equal(bucket,'chat-photos');return {remove:async([path])=>({error:path==='retry.jpg'?'temporary':null})};}}};
  vm.runInNewContext(stripTypeScriptTypes(source),{Response,AbortSignal,Set,Error,JSON,Deno:{env:{get:(key)=>key==='ANNOUNCEMENT_CRON_SECRET'?'fixture-secret':undefined},serve:(fn)=>handler=fn},createClient:()=>{created++;return admin;}});
  assert.equal((await handler(new Request('https://test.invalid',{method:'POST'}))).status,401);
  assert.equal((await handler(new Request('https://test.invalid'))).status,405);
  assert.equal(created,0);
  assert.equal((await handler(new Request('https://test.invalid',{method:'POST',headers:{'x-pbh-cron-secret':'fixture-secret'}}))).status,200);
  assert.deepEqual(JSON.parse(JSON.stringify(ack)),[{p_path:'ok.jpg',p_claim:'one'}]);
});

test('private push targets only the recipient and contains no conversation text',async()=>{
  const source=(await fs.readFile(new URL('../supabase/functions/process-private-chat/index.ts',import.meta.url),'utf8')).replace(/^import .*;\r?\n/gm,'');
  let handler,claim=0,finished=false;const sent=[],scopes=[];
  const query=(table)=>{
    const filters=[];const q={select:()=>q,eq:(key,value)=>{filters.push([key,value]);return q;},limit:()=>q,maybeSingle:()=>q,upsert:()=>Promise.resolve({data:null}),then:(resolve)=>{
      scopes.push({table,filters});
      if(table==='chat_push_receipts')return Promise.resolve(resolve({data:[]}));
      if(table==='web_push_subscriptions')return Promise.resolve(resolve({data:[]}));
      if(table==='native_push_tokens'){assert.ok(filters.some(([key,value])=>key==='user_id'&&value==='recipient'));return Promise.resolve(resolve({data:filters.some(([key])=>key==='installation_id')?{token:'device',sound_enabled:false}:[{installation_id:'installation',token:'device',sound_enabled:false}]}));}
      throw Error('Unexpected table '+table);
    }};return q;
  };
  const admin={from:query,rpc:async(name,args)=>{
    if(name==='chat_claim_cleanup')return {data:[]};
    if(name==='chat_claim_push')return {data:claim++===0?{message_id:'message',thread_id:'thread',recipient_id:'recipient',lease_id:'lease'}:null};
    if(name==='chat_finish_push'){assert.equal(args.p_success,true);finished=true;return {data:null};}
    throw Error(name);
  }};
  vm.runInNewContext(stripTypeScriptTypes(source),{Response,AbortSignal,Set,Error,JSON,Deno:{env:{get:(key)=>key==='ANNOUNCEMENT_CRON_SECRET'?'fixture':undefined},serve:(fn)=>handler=fn},createClient:()=>admin,credentials:async()=>({project:'fixture',token:'private'}),fetch:async(_,options)=>{sent.push(JSON.parse(options.body));return Response.json({name:'accepted'});}});
  assert.equal((await handler(new Request('https://test.invalid',{method:'POST',headers:{'x-pbh-cron-secret':'fixture'}}))).status,200);
  assert.equal(sent.length,1);assert.equal(sent[0].message.token,'device');
  assert.equal(sent[0].message.data.recipient_id,'recipient');
  assert.equal(sent[0].message.notification.body,'Você recebeu uma nova mensagem no PBH.');
  assert.equal(sent[0].message.android.notification.channel_id,'pbh_private_chat_silent');
  assert.ok(finished);assert.ok(scopes.every(({table})=>!table.includes('announcement')));
});
