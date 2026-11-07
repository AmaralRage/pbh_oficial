import fs from 'node:fs/promises';
import {stripTypeScriptTypes} from 'node:module';
import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
const source=await fs.readFile(new URL('../supabase/functions/_shared/chat-audio.ts',import.meta.url),'utf8');
const {inspectChatAudio}=await import(`data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(source)).toString('base64')}`);
const u32=n=>{const b=Buffer.alloc(4);b.writeUInt32BE(n);return b;};
const atom=(type,...parts)=>{const data=Buffer.concat(parts);return Buffer.concat([u32(data.length+8),Buffer.from(type),data]);};
function m4a(seconds=1,sampleSeconds=seconds){
  const rate=24000,header=Buffer.alloc(24);header.writeUInt32BE(rate,12);header.writeUInt32BE(Math.round(seconds*rate),16);
  const description=Buffer.alloc(28);description.writeUInt32BE(rate*65536,24);
  const stts=atom('stts',u32(0),u32(1),u32(Math.floor(sampleSeconds*rate/1024)),u32(1024));
  return Buffer.concat([atom('ftyp',Buffer.from('M4A ')),atom('mdat',Buffer.from([1,2,3])),atom('moov',atom('trak',atom('mdia',atom('mdhd',header),atom('hdlr',u32(0),u32(0),Buffer.from('soun')),atom('minf',atom('stbl',stts,atom('stsd',u32(0),u32(1),atom('mp4a',description)))))))]);
}
function ebml(id,body){const data=Buffer.from(body);let size=data.length<127?Buffer.from([128+data.length]):Buffer.from([0x40+(data.length>>8),data.length&255]);return Buffer.concat([Buffer.from(id,'hex'),size,data]);}
function webm({duration=1000,clusterTime=0}={}){
  const ms=Buffer.alloc(8);ms.writeDoubleBE(duration);
  const timestamp=Buffer.alloc(3);timestamp.writeUIntBE(clusterTime,0,3);
  return Buffer.concat([ebml('1a45dfa3',ebml('4282',Buffer.from('webm'))),ebml('18538067',Buffer.concat([
    ebml('1549a966',Buffer.concat([ebml('2ad7b1',[0x0f,0x42,0x40]),ebml('4489',ms)])),
    ebml('1654ae6b',ebml('ae',Buffer.concat([ebml('83',[2]),ebml('86',Buffer.from('A_OPUS'))]))),
    ebml('1f43b675',Buffer.concat([ebml('e7',timestamp),ebml('a3',[0x81,0,0,0x80,0xf8,0xff,0xfe])])),
  ]))]);
}
test('validates AAC/MP4 and Opus/WebM without trusting client duration',()=>{
  assert.equal(inspectChatAudio(m4a(),'m4a').durationMs,1000);
  assert.equal(inspectChatAudio(webm(),'webm').durationMs,1000);
  assert.equal(inspectChatAudio(m4a(120),'m4a').durationMs,120000);
  assert.equal(inspectChatAudio(webm({duration:120000}),'webm').durationMs,120000);
});
test('rejects recordings above two minutes, including contradictory timing',()=>{
  assert.throws(()=>inspectChatAudio(m4a(121),'m4a'));
  assert.throws(()=>inspectChatAudio(m4a(1,121),'m4a'));
  assert.throws(()=>inspectChatAudio(webm({duration:120001}),'webm'));
  assert.throws(()=>inspectChatAudio(webm({duration:1000,clusterTime:120000}),'webm'));
});
test('rejects oversized, truncated, unrelated and malformed files',()=>{
  assert.throws(()=>inspectChatAudio(Buffer.alloc(1048577),'webm'));
  assert.throws(()=>inspectChatAudio(Buffer.from('<html>not audio</html>'),'m4a'));
  for(const data of [m4a(),webm()])for(let i=1;i<Math.min(data.length,100);i++)assert.throws(()=>inspectChatAudio(data.subarray(0,i),data[0]===0x1a?'webm':'m4a'));
  assert.throws(()=>inspectChatAudio(webm(),'wav'));
  assert.throws(()=>inspectChatAudio(webm({duration:NaN}),'webm'));
});

test('audio validator requires a confirmed account, owns the upload and verifies actual bytes',async()=>{
  const edge=(await fs.readFile(new URL('../supabase/functions/validate-chat-audio/index.ts',import.meta.url),'utf8')).replace(/^import .*;\r?\n/gm,'');
  let handler,clients=0,downloads=0,verifications=0,file=m4a(),denied=false;
  const admin={auth:{getUser:async token=>({data:{user:token==='valid'?{id:'fixture-user',email_confirmed_at:'2026-11-07'}:null},error:null})},
    from:(table)=>{assert.equal(table,'chat_media_cleanup');const filters=[];const q={select:()=>q,eq:(k,v)=>{filters.push([k,v]);return q;},is:()=>q,gt:()=>q,maybeSingle:async()=>{assert.ok(filters.some(([k,v])=>k==='owner_id'&&v==='fixture-user'));return {data:{audio_format:'m4a'},error:null};}};return q;},
    storage:{from:bucket=>{assert.equal(bucket,'chat-audio');return {download:async()=>{downloads++;return {data:new Blob([file]),error:null};}};}},
    rpc:async(name,args)=>{assert.equal(name,'chat_verify_audio');assert.equal(args.p_owner,'fixture-user');assert.equal(args.p_duration,1000);verifications++;return {error:denied?'reservation changed':null};}
  };
  vm.runInNewContext(stripTypeScriptTypes(edge),{Response,Date,JSON,Uint8Array,inspectChatAudio,Deno:{env:{get:()=>''},serve:fn=>handler=fn},createClient:()=>{clients++;return admin;}});
  const request=(token,path='fixture-user/thread/message.m4a')=>new Request('https://fixture.invalid',{method:'POST',headers:{...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify({path})});
  assert.equal((await handler(request(null))).status,401);assert.equal(clients,0);
  assert.equal((await handler(request('invalid'))).status,401);assert.equal(downloads,0);
  assert.equal((await handler(request('valid','someone-else/thread/message.m4a'))).status,403);assert.equal(downloads,0);
  assert.equal((await handler(request('valid'))).status,200);assert.equal(verifications,1);
  file=m4a(121);assert.equal((await handler(request('valid'))).status,400);assert.equal(verifications,1);
  file=m4a();denied=true;assert.equal((await handler(request('valid'))).status,409);
});
