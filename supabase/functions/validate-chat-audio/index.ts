import { createClient } from 'npm:@supabase/supabase-js@2';
import { inspectChatAudio } from '../_shared/chat-audio.ts';

const headers={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,x-client-info,apikey,content-type','Access-Control-Allow-Methods':'POST,OPTIONS'};
const json=(body:unknown,status=200)=>Response.json(body,{status,headers});
Deno.serve(async request=>{
  if(request.method==='OPTIONS')return new Response('',{headers});
  if(request.method!=='POST')return json({error:'Método inválido.'},405);
  const token=request.headers.get('authorization')?.replace(/^Bearer\s+/i,'');
  if(!token)return json({error:'Entre na sua conta.'},401);
  const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const {data:{user},error}=await admin.auth.getUser(token);
  if(error||!user?.email_confirmed_at)return json({error:'Entre na sua conta.'},401);
  try {
    const body=await request.json();const path=body.path;
    if(typeof path!=='string'||path.length>160||!path.startsWith(user.id+'/'))return json({error:'Anexo indisponível.'},403);
    const {data:reservation,error:lookup}=await admin.from('chat_media_cleanup').select('audio_format').eq('path',path).eq('owner_id',user.id).eq('bucket','chat-audio').is('claim_token',null).gt('not_before',new Date().toISOString()).maybeSingle();
    if(lookup||!reservation)return json({error:'Anexo indisponível.'},403);
    const {data:file,error:download}=await admin.storage.from('chat-audio').download(path);
    if(download||!file)return json({error:'Não foi possível abrir o áudio.'},400);
    if(file.size>1048576)return json({error:'O áudio deve ter até 1 MB.'},400);
    const result=inspectChatAudio(new Uint8Array(await file.arrayBuffer()),reservation.audio_format);
    const {error:verify}=await admin.rpc('chat_verify_audio',{p_owner:user.id,p_path:path,p_duration:result.durationMs,p_size:file.size,p_format:reservation.audio_format});
    if(verify)return json({error:'Anexo indisponível.'},409);
    return json({duration_ms:result.durationMs});
  } catch(_){return json({error:'Gravação inválida ou com mais de dois minutos. Grave novamente.'},400);}
});
