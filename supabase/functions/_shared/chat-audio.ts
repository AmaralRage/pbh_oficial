// Bounded parsers for recordings produced by the app. No client duration is trusted.
export function inspectChatAudio(bytes: Uint8Array, format: string): {durationMs:number; contentType:string} {
  if(!bytes.length || bytes.length>1048576) throw Error('Áudio deve ter até 1 MB.');
  const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
  const text=(a:number,b:number)=>new TextDecoder().decode(bytes.subarray(a,b));
  let elements=0;
  const bounded=()=>{if(++elements>20000)throw Error('Arquivo de áudio inválido.');};
  let duration=0;
  if(format==='m4a') {
    type Atom={type:string;start:number;end:number};
    function atoms(start:number,end:number):Atom[]{
      const result:Atom[]=[];
      while(start<end){bounded();if(start+8>end)throw Error('MP4 incompleto.');
        let size=view.getUint32(start),header=8;
        if(size===1){if(start+16>end)throw Error('MP4 incompleto.');size=Number(view.getBigUint64(start+8));header=16;}
        else if(size===0)size=end-start;
        if(!Number.isSafeInteger(size)||size<header||start+size>end)throw Error('MP4 inválido.');
        result.push({type:text(start+4,start+8),start:start+header,end:start+size});start+=size;
      }return result;
    }
    const top=atoms(0,bytes.length),movie=top.find(a=>a.type==='moov');
    if(!top.some(a=>a.type==='ftyp')||!top.some(a=>a.type==='mdat'&&a.end>a.start)||!movie)throw Error('Gravação M4A inválida.');
    const tracks=atoms(movie.start,movie.end).filter(a=>a.type==='trak');
    if(tracks.length!==1)throw Error('Somente uma faixa de voz é permitida.');
    const media=atoms(tracks[0].start,tracks[0].end).find(a=>a.type==='mdia');if(!media)throw Error('Faixa inválida.');
    const parts=atoms(media.start,media.end),header=parts.find(a=>a.type==='mdhd'),handler=parts.find(a=>a.type==='hdlr'),minf=parts.find(a=>a.type==='minf');
    if(!header||!handler||!minf||handler.start+12>handler.end||text(handler.start+8,handler.start+12)!=='soun')throw Error('Somente áudio é permitido.');
    const v=bytes[header.start],offset=v===0?12:v===1?20:-1;
    if(offset<0||header.start+offset+(v===0?8:12)>header.end)throw Error('Duração inválida.');
    const scale=view.getUint32(header.start+offset),ticks=v===0?view.getUint32(header.start+offset+4):Number(view.getBigUint64(header.start+offset+4));
    if(!scale||!Number.isSafeInteger(ticks))throw Error('Duração inválida.');
    duration=ticks*1000/scale;
    const stbl=atoms(minf.start,minf.end).find(a=>a.type==='stbl');if(!stbl)throw Error('Amostras ausentes.');
    const tables=atoms(stbl.start,stbl.end),timing=tables.find(a=>a.type==='stts'),description=tables.find(a=>a.type==='stsd');
    if(!timing||!description||timing.start+8>timing.end||description.start+8>description.end)throw Error('Amostras inválidas.');
    const codecs=atoms(description.start+8,description.end);if(codecs.length!==1||codecs[0].type!=='mp4a')throw Error('Use áudio AAC.');
    if(codecs[0].start+28>codecs[0].end)throw Error('Descrição AAC inválida.');
    const sampleRate=view.getUint32(codecs[0].start+24)>>>16;
    if(sampleRate!==scale)throw Error('Taxa de áudio inválida.');
    const count=view.getUint32(timing.start+4);if(count<1||count>4096||timing.start+8+count*8!==timing.end)throw Error('Amostras inválidas.');
    let sampleTicks=0,samples=0;
    for(let i=0;i<count;i++){const n=view.getUint32(timing.start+8+i*8);samples+=n;sampleTicks+=n*view.getUint32(timing.start+12+i*8);}
    duration=Math.max(duration,sampleTicks*1000/scale,samples*1024*1000/sampleRate);
  } else if(format==='webm') {
    let scale=1000000,declared=0,lastEnd=0,packetDuration=0,audio=false,opus=false,blocks=0;
    function vint(at:number,id=false){
      if(at>=bytes.length||bytes[at]===0)throw Error('WebM inválido.');
      let length=1,mask=128;while(!(bytes[at]&mask)){length++;mask>>=1;}
      if(length>(id?4:8)||at+length>bytes.length)throw Error('WebM inválido.');
      let value=id?bytes[at]:bytes[at]&(mask-1),unknown=!id&&value===mask-1;
      for(let i=1;i<length;i++){value=value*256+bytes[at+i];unknown=unknown&&bytes[at+i]===255;}
      return {value,length,unknown};
    }
    function uint(a:number,b:number){if(b-a>6)throw Error('WebM inválido.');let n=0;for(;a<b;a++)n=n*256+bytes[a];return n;}
    function packetMs(start:number,end:number){if(start>=end)throw Error('Pacote vazio.');const toc=bytes[start],config=toc>>3;
      const frame=config>=16?2.5*2**(config&3):config>=12?10*2**(config&1):(config&3)===3?60:10*2**(config&3);
      const code=toc&3,frames=code===0?1:code===3?(bytes[start+1]??0)&63:2;
      if(!frames||frame*frames>120)throw Error('Pacote Opus inválido.');return frame*frames;
    }
    function walk(start:number,end:number,depth=0,cluster=0){
      if(depth>10)throw Error('WebM inválido.');
      while(start<end){bounded();const id=vint(start,true),size=vint(start+id.length),body=start+id.length+size.length;
        const stop=size.unknown?end:body+size.value;if(stop>end||stop<body||(!size.unknown&&!Number.isSafeInteger(size.value)))throw Error('WebM incompleto.');
        const tag=id.value;
        if(tag===0x2ad7b1){if(blocks)throw Error('WebM inválido.');scale=uint(body,stop);}
        else if(tag===0x4489){if(stop-body!==4&&stop-body!==8)throw Error('Duração inválida.');declared=stop-body===4?view.getFloat32(body):view.getFloat64(body);}
        else if(tag===0x83){if(uint(body,stop)!==2)throw Error('Somente voz é permitida.');audio=true;}
        else if(tag===0x86){if(text(body,stop)!=='A_OPUS')throw Error('Use áudio Opus.');opus=true;}
        else if(tag===0xe7)cluster=uint(body,stop);
        else if(tag===0xa3||tag===0xa1){const track=vint(body);const at=body+track.length;if(track.value!==1||at+3>=stop||(bytes[at+2]&6)!==0)throw Error('Bloco de áudio inválido.');
          const time=(cluster+view.getInt16(at))*scale/1000000,ms=packetMs(at+3,stop);packetDuration+=ms;lastEnd=Math.max(lastEnd,time+ms);blocks++;
        }else if([0x1a45dfa3,0x18538067,0x1549a966,0x1654ae6b,0xae,0x1f43b675,0xa0].includes(tag))walk(body,stop,depth+1,tag===0x1f43b675?0:cluster);
        start=stop;
      }
    }
    if(bytes.length<4||view.getUint32(0)!==0x1a45dfa3)throw Error('WebM inválido.');
    walk(0,bytes.length);
    if(!audio||!opus||!blocks||!Number.isFinite(scale)||scale<=0)throw Error('Gravação Opus inválida.');
    duration=Math.max(declared*scale/1000000,lastEnd,packetDuration);
  }else throw Error('Formato de áudio não permitido.');
  if(!Number.isFinite(duration)||duration<250||duration>120000)throw Error('O áudio deve ter entre um instante e dois minutos.');
  return {durationMs:Math.ceil(duration),contentType:format==='m4a'?'audio/mp4':'audio/webm'};
}
