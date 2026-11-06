import fs from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';
import test from 'node:test';
import assert from 'node:assert/strict';

test('scheduled Android delivery works without Web Push keys; unauthorized calls are rejected', async () => {
  let handler, nativeCalls=0, claimed=false, finished;
  const job={id:'job',lease_id:'lease',announcement_id:'notice',title:'Test',message:'Body',audience:'all'};
  const query=(table)=>({
    select(){return this;},update(){return this;},eq(){return this;},
    then(resolve){return Promise.resolve({count:table==='web_push_subscriptions'?0:1,error:null}).then(resolve);},
  });
  globalThis.__pbhWorkerFixture={
    Deno:{env:{get:(key)=>({ANNOUNCEMENT_CRON_SECRET:'test-secret',SUPABASE_URL:'https://test.invalid',SUPABASE_SERVICE_ROLE_KEY:'test-key'})[key]},serve:(fn)=>handler=fn},
    webpush:{setVapidDetails(){throw Error('Web credentials were not provided');}},
    createClient:()=>({from:query,rpc:async(name,args)=>{
      if(name==='claim_scheduled_announcement_push'){if(claimed)return {data:[]};claimed=true;return {data:[job]};}
      if(name==='finish_scheduled_announcement_push'){finished=args;return {error:null};}
      throw Error('Unexpected RPC');
    }}),
    sendNativeAnnouncement:async(_,notice)=>{nativeCalls++;assert.equal(notice.id,'notice');return {attempted:1,sent:1};},
    isCommunityNotification:()=>false,
  };
  try{
    const source=await fs.readFile(new URL('../supabase/functions/process-announcement-schedules/index.ts',import.meta.url),'utf8');
    const body=source.replace(/^import .*;\r?\n/gm,'');
    const script='const {Deno,webpush,createClient,sendNativeAnnouncement,isCommunityNotification}=globalThis.__pbhWorkerFixture;\n'+stripTypeScriptTypes(body);
    await import(`data:text/javascript;base64,${Buffer.from(script).toString('base64')}`);
    const denied=await handler(new Request('https://test.invalid',{method:'POST'}));
    assert.equal(denied.status,401);assert.equal(nativeCalls,0);
    const result=await handler(new Request('https://test.invalid',{method:'POST',headers:{'x-pbh-cron-secret':'test-secret'}}));
    assert.equal(result.status,200);assert.equal(nativeCalls,1);assert.equal(finished.p_error,null);
  }finally{delete globalThis.__pbhWorkerFixture;}
});
