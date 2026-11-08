import { createClient } from 'npm:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';
import { credentials } from '../_shared/native-push.ts';
import { chatNotificationPresentation } from '../_shared/chat-notification.ts';

// This endpoint is called only by the private database scheduler.
// Previews are delivered only to the recipient's currently registered devices.
Deno.serve(async (request) => {
  if(request.method!=='POST') return new Response('',{status:405});
  const secret=Deno.env.get('ANNOUNCEMENT_CRON_SECRET');
  if(!secret || request.headers.get('x-pbh-cron-secret')!==secret) return new Response('',{status:401});
  const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  async function checked<T>(result:PromiseLike<{data:T;error:unknown}>):Promise<T>{const {data,error}=await result;if(error)throw Error('Database operation failed');return data;}
  try {
    // Authenticated operational probe: FCM validates only, never delivers.
    const input=await request.json().catch(()=>({}));
    if(input?.diagnostic===true){
      let stage='database';
      try{
        const rows=await checked(admin.from('chat_messages').select('id,thread_id,sender_id').order('created_at',{ascending:false}).limit(1));
        if(rows?.length){
          const m=rows[0];
          const thread=await checked(admin.from('chat_threads').select('member_a,member_b').eq('id',m.thread_id).single());
          const recipient=m.sender_id===thread.member_a?thread.member_b:thread.member_a;
          stage='delivery_policy';
          await checked(admin.rpc('chat_push_delivery_allowed',{p_message:m.id,p_recipient:recipient}));
          stage='receipts';
          await checked(admin.from('chat_push_receipts').select('endpoint').eq('message_id',m.id));
          stage='device_lookup';
          await checked(admin.from('native_push_tokens').select('installation_id,token,sound_enabled,chat_style_version').eq('user_id',recipient).limit(100));
        }
        stage='native_auth';
        const auth=await credentials();
        const devices=await checked(admin.from('native_push_tokens').select('token').order('updated_at',{ascending:false}).limit(1));
        if(!devices?.length)return Response.json({stage:'registration',code:'NO_DEVICE'});
        stage='native_delivery';
        const response=await fetch(`https://fcm.googleapis.com/v1/projects/${auth.project}/messages:send`,{method:'POST',headers:{Authorization:`Bearer ${auth.token}`,'Content-Type':'application/json'},body:JSON.stringify({validate_only:true,message:{token:devices[0].token,notification:{title:'PBH',body:'Diagnóstico sem envio',image:'https://pbh-oficial.vercel.app/assets/assets/images/perfil.png'},data:{chat_id:'cc070000-0000-4000-8000-000000000003',message_id:'cc070000-0000-4000-8000-000000000004',recipient_id:'cc070000-0000-4000-8000-000000000001',destination_url:'https://pbh-oficial.vercel.app/?chat=cc070000-0000-4000-8000-000000000003',silent:'false',sender_id:'cc070000-0000-4000-8000-000000000002',sender_name:'PBH',preview:'Diagnóstico sem envio',avatar_url:'',sender_founder:'false',sent_at:new Date().toISOString(),expires_at:new Date(Date.now()+60000).toISOString()},android:{ttl:'300s',priority:'high',notification:{channel_id:'pbh_private_chat',icon:'ic_stat_pbh_prominent',color:'#6D28D9',tag:'chat-diagnostic',image:'https://pbh-oficial.vercel.app/assets/assets/images/perfil.png'}}}}),signal:AbortSignal.timeout(10000)});
        const result=await response.json();
        const raw=result?.error?.details?.find((d:{errorCode?:string})=>d.errorCode)?.errorCode??result?.error?.status;
        const code=['INVALID_ARGUMENT','SENDER_ID_MISMATCH','UNAVAILABLE','INTERNAL','QUOTA_EXCEEDED','THIRD_PARTY_AUTH_ERROR','UNAUTHENTICATED','PERMISSION_DENIED','UNREGISTERED'].includes(raw)?raw:response.ok?'VALID':'UNKNOWN';
        return Response.json({stage,status:response.status,code});
      }catch(_){return Response.json({stage,code:'FAILED'});}
    }
    const cleanup=await checked(admin.rpc('chat_claim_cleanup'));
    for(const item of cleanup??[]){
      const bucket=item.bucket??'chat-photos';
      if(bucket!=='chat-photos'&&bucket!=='chat-audio')throw Error('Invalid cleanup bucket');
      const {error}=await admin.storage.from(bucket).remove([item.path]);
      if(!error) await checked(admin.rpc('chat_ack_cleanup',{p_path:item.path,p_claim:item.claim_token}));
    }
    const publicKey=Deno.env.get('VAPID_PUBLIC_KEY'),privateKey=Deno.env.get('VAPID_PRIVATE_KEY');
    if(publicKey&&privateKey)webpush.setVapidDetails(Deno.env.get('VAPID_SUBJECT')??'https://pbh-oficial.vercel.app',publicKey,privateKey);
    for(let count=0;count<10;count++){
      const job=await checked(admin.rpc('chat_claim_push'));if(!job)break;if(job.skipped)continue;
      let success=true;
      let stage='database',failure:string|null=null;
      try {
        const recipient=job.recipient_id,message=job.message_id;
        if(!await checked(admin.rpc('chat_push_delivery_allowed',{p_message:message,p_recipient:recipient}))){
          await checked(admin.rpc('chat_finish_push',{p_message:message,p_lease:job.lease_id,p_success:true}));
          continue;
        }
        const receipts=await checked(admin.from('chat_push_receipts').select('endpoint').eq('message_id',message));
        const done=new Set((receipts??[]).map((r)=>r.endpoint));
        const url=`https://pbh-oficial.vercel.app/?chat=${job.thread_id}`;
        const {title,body,avatar}=chatNotificationPresentation(job,Deno.env.get('SUPABASE_URL')!);
        const devices=await checked(admin.from('native_push_tokens').select('installation_id,token,sound_enabled,chat_style_version').eq('user_id',recipient).limit(100));
        for(const device of devices??[]){
          const endpoint=`fcm:${device.token}`;if(done.has(endpoint))continue;
          // A logout/account switch invalidates ownership of an installation.
          const current=await checked(admin.from('native_push_tokens').select('token,sound_enabled,chat_style_version').eq('installation_id',device.installation_id).eq('user_id',recipient).maybeSingle());
          if(!current||current.token!==device.token)continue;
          if(!await checked(admin.rpc('chat_push_delivery_allowed',{p_message:message,p_recipient:recipient})))continue;
          stage='native_auth';
          const auth=await credentials(),silent=current.sound_enabled===false;
          stage='native_delivery';
          const messagingStyle=current.chat_style_version>=1;
          const response=await fetch(`https://fcm.googleapis.com/v1/projects/${auth.project}/messages:send`,{method:'POST',headers:{Authorization:`Bearer ${auth.token}`,'Content-Type':'application/json'},body:JSON.stringify({message:{token:device.token,
            ...(!messagingStyle?{notification:{title,body,...(avatar?{image:avatar}:{})}}:{}),
            data:{chat_id:job.thread_id,message_id:message,recipient_id:recipient,destination_url:url,silent:String(silent),sender_id:String(job.sender_id??''),sender_name:title,preview:body,avatar_url:avatar??'',sender_founder:String(job.sender_founder===true),sent_at:String(job.sent_at??''),expires_at:String(job.expires_at??'')},
            android:{ttl:'300s',priority:'high',...(!messagingStyle?{notification:{channel_id:silent?'pbh_private_chat_silent':'pbh_private_chat',icon:'ic_stat_pbh_prominent',color:'#6D28D9',tag:`chat-${job.thread_id}`,...(avatar?{image:avatar}:{})}}:{})}}}),signal:AbortSignal.timeout(10000)});
          if(!response.ok){const result=await response.json();if(result?.error?.details?.some((d:{errorCode?:string})=>d.errorCode==='UNREGISTERED'))await checked(admin.from('native_push_tokens').delete().eq('installation_id',device.installation_id).eq('user_id',recipient).eq('token',device.token));else{const code=result?.error?.details?.find((d:{errorCode?:string})=>d.errorCode)?.errorCode??result?.error?.status;failure=['INVALID_ARGUMENT','SENDER_ID_MISMATCH','UNAVAILABLE','INTERNAL','QUOTA_EXCEEDED','THIRD_PARTY_AUTH_ERROR','UNAUTHENTICATED','PERMISSION_DENIED'].includes(code)?code:'native_delivery';success=false;continue;}}
          await checked(admin.from('chat_push_receipts').upsert({message_id:message,endpoint}));
        }
        stage='browser_delivery';
        const subscriptions=await checked(admin.from('web_push_subscriptions').select('endpoint,p256dh,auth').eq('user_id',recipient).limit(100));
        if(subscriptions?.length&&(!publicKey||!privateKey))success=false;
        if(publicKey&&privateKey)for(const subscription of subscriptions??[]){
          if(done.has(subscription.endpoint))continue;
          const current=await checked(admin.from('web_push_subscriptions').select('endpoint').eq('user_id',recipient).eq('endpoint',subscription.endpoint).maybeSingle());if(!current)continue;
          if(!await checked(admin.rpc('chat_push_delivery_allowed',{p_message:message,p_recipient:recipient})))continue;
          try{await webpush.sendNotification({endpoint:subscription.endpoint,keys:{p256dh:subscription.p256dh,auth:subscription.auth}},JSON.stringify({title,body,url,tag:`chat-${job.thread_id}`,icon:avatar??'/icons/Icon-192.png',badge:'/icons/Icon-192.png'}),{timeout:10000,TTL:300});}
          catch(error){const status=(error as {statusCode?:number}).statusCode;if(status!==404&&status!==410){success=false;continue;}await checked(admin.from('web_push_subscriptions').delete().eq('user_id',recipient).eq('endpoint',subscription.endpoint));}
          await checked(admin.from('chat_push_receipts').upsert({message_id:message,endpoint:subscription.endpoint}));
        }
      }catch(_){success=false;failure=stage;}
      await checked(admin.from('chat_push_jobs').update({last_error:success?null:failure??stage}).eq('message_id',job.message_id).eq('lease_id',job.lease_id));
      await checked(admin.rpc('chat_finish_push',{p_message:job.message_id,p_lease:job.lease_id,p_success:success}));
    }
    return Response.json({ok:true});
  }catch(_){return Response.json({error:'Unable to process private chat'},{status:500});}
});
