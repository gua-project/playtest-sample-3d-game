// Open-ended probe runner. Input lines are JSON {click, count?, waitMs?, note?}
// or {observe:true}, {screenshot:true}, {quit:true}. It exposes no game shortcuts.
import {spawn} from 'node:child_process';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {createInterface} from 'node:readline';
import {resolve,join} from 'node:path';
import {createHash} from 'node:crypto';
const root=resolve(import.meta.dirname,'..'),out=resolve(process.env.EVIDENCE_DIR??join(root,'artifacts/exploration'));
await mkdir(join(out,'appdata'),{recursive:true});
const exe=join(root,'dist/FacilityEscape.exe'),port=process.env.GUA_BRIDGE_PORT??'18732';
const headed=process.env.HEADED==='1';
const child=spawn(exe,headed?['--max-fps','60']:['--headless','--max-fps','60'],{cwd:root,env:{...process.env,APPDATA:join(out,'appdata'),GUA_BRIDGE_PORT:port},windowsHide:!headed});
let log='',socket,sequence=1;
child.stdout.on('data',x=>log+=x);child.stderr.on('data',x=>log+=x);
const sleep=ms=>new Promise(r=>setTimeout(r,ms)),pending=new Map(),events=[];
function request(type,args={}){
  const id=sequence++;
  return new Promise((res,rej)=>{
    const timer=setTimeout(()=>{pending.delete(id);rej(Error('timeout '+type));},8000);
    pending.set(id,{res,rej,timer});socket.send(JSON.stringify({id,type,...args}));
  });
}
try{
  for(let i=0;i<150&&!log.includes('listening on');i++)await sleep(100);
  socket=new WebSocket('ws://127.0.0.1:'+port);
  await new Promise((res,rej)=>{socket.addEventListener('open',res,{once:true});socket.addEventListener('error',rej,{once:true});});
  socket.addEventListener('message',event=>{
    const d=JSON.parse(String(event.data)),p=pending.get(d.id);if(!p)return;
    pending.delete(d.id);clearTimeout(p.timer);if(d.ok)p.res(d.result);else p.rej(Error(JSON.stringify(d.error)));
  });
  console.log('READY',JSON.stringify(await request('get_version')));
  const input=createInterface({input:process.stdin,crlfDelay:Infinity});
  for await(const line of input){
    if(!line.trim())continue;
    const cmd=JSON.parse(line);
    if(cmd.quit)break;
    for(let i=0;i<(cmd.count??1);i++){
      let receipt,completion;
      if(cmd.click){
        receipt=await request('click_node',{nodeId:cmd.click});
        if(!receipt?.requestId)throw Error('missing action receipt');
        for(let j=0;j<150;j++){
          completion=await request('poll_events',{requestId:receipt.requestId});
          if(completion)break;await sleep(20);
        }
        if(!completion?.succeeded)throw Error('action did not complete');
      }
      await sleep(cmd.waitMs??(cmd.click&&['forward','back','left','right'].includes(cmd.click)?285:70));
      const observed=await request('get_ui_tree');
      events.push({command:cmd,receipt,completion,observed});
      if(cmd.screenshot){
        const shot=await request('get_screenshot'),data=shot.dataUri??shot.data_uri;
        if(!data?.startsWith('data:image/png;base64,'))throw Error('screenshot unavailable');
        await writeFile(join(out,`frame-${events.length}.png`),Buffer.from(data.split(',')[1],'base64'));
      }
      console.log(JSON.stringify({screen:observed.screen,text:observed.nodes.filter(n=>['status','target','notice','menu_message'].includes(n.id)).map(n=>({id:n.id,text:n.text})),buttons:observed.nodes.filter(n=>n.role==='button'&&n.visible).map(n=>n.id)}));
      await writeFile(join(out,'history.json'),JSON.stringify(events,null,2));
    }
  }
}catch(error){console.error(error);process.exitCode=1;}
finally{
  socket?.close();child.kill();await sleep(250);
  await writeFile(join(out,'engine.log'),log);
  await writeFile(join(out,'session.json'),JSON.stringify({scenario:'facility-r1',seed:3001,sha256:createHash('sha256').update(await readFile(exe)).digest('hex'),objective:'Explore collision, occlusion, input and recovery through ordinary player controls; report observed outcomes, without a fixed clear route.',mode:headed?'rendered-exe':'headless-exe',events:events.length},null,2));
}
