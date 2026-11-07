// Optional Windows integration check: Chrome records a synthetic microphone.
// No account, messages or external services are used.
import http from 'node:http';
import {spawn} from 'node:child_process';
import fs from 'node:fs/promises';
import path from 'node:path';
import {stripTypeScriptTypes} from 'node:module';
import assert from 'node:assert/strict';
const server=http.createServer((_,res)=>{res.writeHead(200,{'Content-Type':'text/html'});res.end('<html><body>PBH audio integration fixture</body></html>');});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const origin=`http://127.0.0.1:${server.address().port}`;
const chrome=spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',['--headless=new','--no-first-run','--no-default-browser-check','--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream','--remote-debugging-port=9235',`--user-data-dir=${path.resolve('build/chat-audio-browser-profile')}`,origin],{windowsHide:true,stdio:'ignore'});
let socket;
try{
  let target;
  for(let i=0;i<80&&!target;i++){
    try{target=(await(await fetch('http://127.0.0.1:9235/json/list')).json()).find(p=>p.url.startsWith(origin));}catch{}
    if(!target)await new Promise(resolve=>setTimeout(resolve,100));
  }
  assert.ok(target,'Chrome debugging target must open');
  socket=new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve,reject)=>{socket.addEventListener('open',resolve,{once:true});socket.addEventListener('error',reject,{once:true});});
  let id=0;const pending=new Map();
  socket.addEventListener('message',event=>{const message=JSON.parse(event.data);if(message.id){pending.get(message.id)?.(message);pending.delete(message.id);}});
  const send=(method,params={})=>new Promise(resolve=>{const n=++id;pending.set(n,resolve);socket.send(JSON.stringify({id:n,method,params}));});
  const result=await send('Runtime.evaluate',{awaitPromise:true,returnByValue:true,expression:`(async()=>{
    const stream=await navigator.mediaDevices.getUserMedia({audio:true});
    const recorder=new MediaRecorder(stream,{mimeType:'audio/webm;codecs=opus',audioBitsPerSecond:32000});
    const chunks=[];recorder.ondataavailable=e=>chunks.push(e.data);
    const done=new Promise(resolve=>recorder.onstop=resolve);recorder.start(200);
    await new Promise(resolve=>setTimeout(resolve,1100));recorder.stop();await done;stream.getTracks().forEach(t=>t.stop());
    return await new Promise(resolve=>{const reader=new FileReader();reader.onload=()=>resolve(reader.result.split(',')[1]);reader.readAsDataURL(new Blob(chunks,{type:'audio/webm'}));});
  })()`});
  assert.equal(result.result?.exceptionDetails,undefined,'Browser recording must succeed');
  const bytes=Buffer.from(result.result.result.value,'base64');
  const source=await fs.readFile(new URL('../supabase/functions/_shared/chat-audio.ts',import.meta.url),'utf8');
  const {inspectChatAudio}=await import(`data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(source)).toString('base64')}`);
  const inspected=inspectChatAudio(bytes,'webm');
  assert.ok(inspected.durationMs>=500&&inspected.durationMs<3000);
  await fs.mkdir('build/security-tests',{recursive:true});await fs.writeFile('build/security-tests/browser-voice.webm',bytes);
  console.log(JSON.stringify({recorded:true,bytes:bytes.length,...inspected}));
  socket.send(JSON.stringify({id:++id,method:'Browser.close'}));
}finally{
  socket?.close();
  if(chrome.exitCode===null){await Promise.race([new Promise(resolve=>chrome.once('exit',resolve)),new Promise(resolve=>setTimeout(resolve,2000))]);if(chrome.exitCode===null)chrome.kill();}
  await new Promise(resolve=>server.close(resolve));
}
