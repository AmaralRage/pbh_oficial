import { createClient } from 'npm:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';
import { credentials } from '../_shared/native-push.ts';

// This endpoint is called only by the private database scheduler.
// Notification content deliberately contains neither names nor message text.
Deno.serve(async (request) => {
  if(request.method!=='POST') return new Response('',{status:405});
  const secret=Deno.env.get('ANNOUNCEMENT_CRON_SECRET');
  if(!secret || request.headers.get('x-pbh-cron-secret')!==secret) return new Response('',{status:401});
  const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  async function checked<T>(result:PromiseLike<{data:T;error:unknown}>):Promise<T>{const {data,error}=await result;if(error)throw Error('Database operation failed');return data;}
  try {
    const cleanup=await checked(admin.rpc('chat_claim_cleanup'));
    for(const item of cleanup??[]){
      const {error}=await admin.storage.from('chat-photos').remove([item.path]);
      if(!error) await checked(admin.rpc('chat_ack_cleanup',{p_path:item.path,p_claim:item.claim_token}));
    }
    const publicKey=Deno.env.get('VAPID_PUBLIC_KEY'),privateKey=Deno.env.get('VAPID_PRIVATE_KEY');
    if(publicKey&&privateKey)webpush.setVapidDetails(Deno.env.get('VAPID_SUBJECT')??'https://pbh-oficial.vercel.app',publicKey,privateKey);
    for(let count=0;count<10;count++){
      const job=await checked(admin.rpc('chat_claim_push'));if(!job)break;if(job.skipped)continue;
      let success=true;
      try {
        const recipient=job.recipient_id,message=job.message_id;
        const receipts=await checked(admin.from('chat_push_receipts').select('endpoint').eq('message_id',message));
        const done=new Set((receipts??[]).map((r)=>r.endpoint));
        const url=`https://pbh-oficial.vercel.app/?chat=${job.thread_id}`;
        const title='Nova mensagem',body='Você recebeu uma nova mensagem no PBH.';
        const devices=await checked(admin.from('native_push_tokens').select('installation_id,token,sound_enabled').eq('user_id',recipient).limit(100));
        for(const device of devices??[]){
          const endpoint=`fcm:${device.token}`;if(done.has(endpoint))continue;
          // A logout/account switch invalidates ownership of an installation.
          const current=await checked(admin.from('native_push_tokens').select('token,sound_enabled').eq('installation_id',device.installation_id).eq('user_id',recipient).maybeSingle());
          if(!current||current.token!==device.token)continue;
          const auth=await credentials(),silent=current.sound_enabled===false;
          const response=await fetch(`https://fcm.googleapis.com/v1/projects/${auth.project}/messages:send`,{method:'POST',headers:{Authorization:`Bearer ${auth.token}`,'Content-Type':'application/json'},body:JSON.stringify({message:{token:device.token,notification:{title,body},data:{chat_id:job.thread_id,recipient_id:recipient,destination_url:url,silent:String(silent)},android:{ttl:'300s',notification:{channel_id:silent?'pbh_private_chat_silent':'pbh_private_chat',icon:'ic_stat_pbh_prominent',color:'#6D28D9',tag:`chat-${job.thread_id}`}}}}),signal:AbortSignal.timeout(10000)});
          if(!response.ok){const result=await response.json();if(result?.error?.details?.some((d:{errorCode?:string})=>d.errorCode==='UNREGISTERED'))await checked(admin.from('native_push_tokens').delete().eq('installation_id',device.installation_id).eq('user_id',recipient).eq('token',device.token));else{success=false;continue;}}
          await checked(admin.from('chat_push_receipts').upsert({message_id:message,endpoint}));
        }
        const subscriptions=await checked(admin.from('web_push_subscriptions').select('endpoint,p256dh,auth').eq('user_id',recipient).limit(100));
        if(subscriptions?.length&&(!publicKey||!privateKey))success=false;
        if(publicKey&&privateKey)for(const subscription of subscriptions??[]){
          if(done.has(subscription.endpoint))continue;
          const current=await checked(admin.from('web_push_subscriptions').select('endpoint').eq('user_id',recipient).eq('endpoint',subscription.endpoint).maybeSingle());if(!current)continue;
          try{await webpush.sendNotification({endpoint:subscription.endpoint,keys:{p256dh:subscription.p256dh,auth:subscription.auth}},JSON.stringify({title,body,url,tag:`chat-${job.thread_id}`,icon:'/icons/Icon-192.png'}),{timeout:10000,TTL:300});}
          catch(error){const status=(error as {statusCode?:number}).statusCode;if(status!==404&&status!==410){success=false;continue;}await checked(admin.from('web_push_subscriptions').delete().eq('user_id',recipient).eq('endpoint',subscription.endpoint));}
          await checked(admin.from('chat_push_receipts').upsert({message_id:message,endpoint:subscription.endpoint}));
        }
      }catch(_){success=false;}
      await checked(admin.rpc('chat_finish_push',{p_message:job.message_id,p_lease:job.lease_id,p_success:success}));
    }
    return Response.json({ok:true});
  }catch(_){return Response.json({error:'Unable to process private chat'},{status:500});}
});
