export function chatNotificationPresentation(job:Record<string,unknown>,projectUrl:string){
  const clean=(value:unknown,max:number)=>typeof value==='string'?value.replace(/[\s\u0000-\u001f]+/g,' ').trim().slice(0,max):'';
  const title=clean(job.sender_name,40)||'Membro';
  let body:string;
  if(typeof job.audio_duration_ms==='number'&&Number.isFinite(job.audio_duration_ms)&&job.audio_duration_ms>0){
    const seconds=Math.max(1,Math.min(120,Math.ceil(job.audio_duration_ms/1000))),minutes=Math.floor(seconds/60),remaining=seconds%60;
    body=`Mensagem de áudio · ${minutes?`${minutes} min${remaining?` ${remaining} s`:''}`:`${seconds} s`}`;
  }else{
    const text=clean(job.content,241);
    body=job.has_image?`Foto${text?`: ${text}`:''}`:text||'Nova mensagem';
    if(body.length>240)body=body.slice(0,239)+'…';
  }
  let avatar:string|null=null;
  try {
    const value=new URL(clean(job.sender_avatar,2048)),project=new URL(projectUrl);
    if(value.protocol==='https:'&&value.origin===project.origin&&!value.username&&!value.password&&value.href.length<=2048&&value.pathname.startsWith(`/storage/v1/object/public/profile-avatars/${job.sender_id}/`))avatar=value.href;
  }catch{/* A missing public photo uses the verified founder or app fallback. */}
  if(!avatar&&job.sender_founder===true)avatar='https://pbh-oficial.vercel.app/assets/assets/images/perfil.png';
  return {title,body,avatar};
}
