import {spawn} from 'node:child_process';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {resolve,join} from 'node:path';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';

const root=resolve(import.meta.dirname,'..');
const exe=resolve(process.argv[2]??join(root,'dist/FacilityEscape.exe'));
const output=resolve(process.env.EVIDENCE_DIR??join(root,'artifacts/acceptance'));
const headed=process.env.HEADED==='1';
const port=process.env.GUA_BRIDGE_PORT??'18732';
const appdata=join(output,'appdata');
await mkdir(appdata,{recursive:true});
await mkdir(join(output,'tmp'),{recursive:true});
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const history=[],results=[];
let stdout='',stderr='',socket,sequence=1;
const pending=new Map();
const child=spawn(exe,headed?['--max-fps','60']:['--headless','--max-fps','60'],{cwd:root,env:{...process.env,APPDATA:appdata,TEMP:join(output,'tmp'),TMP:join(output,'tmp'),GUA_BRIDGE_PORT:port},windowsHide:!headed});
child.stdout.on('data',x=>stdout+=x);
child.stderr.on('data',x=>stderr+=x);
function request(type,args={}) {
  const id=sequence++;
  return new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>{pending.delete(id);reject(Error('Timeout '+type));},8000);
    pending.set(id,{resolve,reject,timer});
    socket.send(JSON.stringify({id,type,...args}));
  });
}
async function tree(){return request('get_ui_tree');}
function text(t,id){return t.nodes.find(n=>n.id===id)?.text??'';}
async function click(id,delay=55){
  const receipt=await request('click_node',{nodeId:id});
  assert.ok(receipt?.requestId>0,'receipt '+id);
  let completion;
  for(let i=0;i<150;i++){
    completion=await request('poll_events',{requestId:receipt.requestId});
    if(completion)break;
    await sleep(20);
  }
  assert.equal(completion?.requestId,receipt.requestId);
  assert.equal(completion.succeeded,true,'action '+id);
  await sleep(delay);
  const observed=await tree();
  history.push({action:id,receipt,completion,observed});
  return observed;
}
async function state(){
  const t=await tree();
  assert.equal(t.screen,'play','state must be observed in play screen');
  const match=text(t,'target').match(/xyz=\(([-\d.]+),([-\d.]+),([-\d.]+)\) yaw=([-\d.]+) pitch=([-\d.]+)/);
  assert.ok(match,'HUD position '+JSON.stringify(t));
  return {x:+match[1],y:+match[2],z:+match[3],yaw:+match[4],pitch:+match[5],tree:t};
}
const angle=x=>((x+180)%360+360)%360-180;
async function face(yaw=0,pitch=0){
  for(let i=0;i<25;i++){
    const s=await state(),d=angle(yaw-s.yaw);
    if(Math.abs(d)<=7.6)break;
    await click(d>0?'turn_left':'turn_right',20);
  }
  for(let i=0;i<15;i++){
    const s=await state(),d=pitch-s.pitch;
    if(Math.abs(d)<=5.1)break;
    await click(d>0?'look_up':'look_down',20);
  }
}
async function go(x,z){
  await face();
  for(const axis of ['x','z']){
    const goal=axis==='x'?x:z;
    let done=false;
    for(let i=0;i<60;i++){
      const s=await state(),d=goal-s[axis];
      if(Math.abs(d)<0.44){done=true;break;}
      await click(axis==='x'?(d>0?'right':'left'):(d>0?'back':'forward'),285);
      const after=await state();
      if(Math.abs(after[axis]-s[axis])<0.05)throw Error(`Blocked moving ${axis} toward ${goal}: ${JSON.stringify(after)}`);
    }
    assert.ok(done,`waypoint ${x},${z}`);
  }
}
async function aim(x,y,z){
  const s=await state(),dx=x-s.x,dz=z-s.z,dy=y-(s.y+(text(s.tree,'status').includes('CROUCH')?.8:1.45));
  await face(Math.atan2(-dx,-dz)*180/Math.PI,Math.atan2(dy,Math.hypot(dx,dz))*180/Math.PI);
}
async function use(id,x,y,z){
  await aim(x,y,z);
  const s=await state();
  assert.ok(text(s.tree,'target').includes('対象: '+id)||text(s.tree,'target').includes('Target: '+id),`target ${id}: ${text(s.tree,'target')}`);
  return click('interact',80);
}
async function checkpoint(name){
  const t=await tree();
  await writeFile(join(output,name+'.json'),JSON.stringify(t,null,2));
  if(headed){
    const shot=await request('get_screenshot');
    const data=shot.dataUri??shot.data_uri;
    assert.ok(data?.startsWith('data:image/png;base64,'),'rendered screenshot');
    await writeFile(join(output,name+'.png'),Buffer.from(data.split(',')[1],'base64'));
  }
}
async function check(id,fn){
  const start=history.length;
  try{await fn();results.push({id,status:'passed',actions:[start,history.length-1]});console.log('PASS',id);}
  catch(error){results.push({id,status:'failed',error:String(error),actions:[start,history.length-1]});throw error;}
}
try{
  for(let i=0;i<150&&!stdout.includes('listening on');i++){
    if(child.exitCode!==null)throw Error('EXE exited '+child.exitCode+' '+stderr);
    await sleep(100);
  }
  socket=new WebSocket('ws://127.0.0.1:'+port);
  await new Promise((res,rej)=>{socket.addEventListener('open',res,{once:true});socket.addEventListener('error',rej,{once:true});});
  socket.addEventListener('message',event=>{
    const data=JSON.parse(String(event.data)),p=pending.get(data.id);
    if(!p)return;
    clearTimeout(p.timer);pending.delete(data.id);
    if(data.ok)p.resolve(data.result);else p.reject(Error(JSON.stringify(data.error)));
  });
  const version=await request('get_version');
  await writeFile(join(output,'gua-version.json'),JSON.stringify(version,null,2));
  console.log('Gua',JSON.stringify(version));
  assert.equal(version.coreVersion,'1.1.2');
  assert.equal(version.runtimeVersion,'1.1.2');
  assert.equal(version.godotPluginVersion,'1.1.2');
  if(process.env.TEST_SUITE!=='bugs'){
  await check('T01-title-start',async()=>{
    assert.equal((await tree()).screen,'title');
    await checkpoint('title');
    assert.equal((await click('start')).screen,'play');
    assert.ok(text(await tree(),'status').includes('A:false B:false'));
  });
  await check('T02-pickups',async()=>{
    await go(-3,6.5);await use('tool',-3,1,5);
    await go(3,6.5);await use('battery',3,1,5);
    assert.ok(text(await tree(),'status').includes('tool')&&text(await tree(),'status').includes('battery'));
    await click('interact');
    assert.ok(!text(await tree(),'target').includes('対象: battery'));
  });
  await check('T03-card-checkpoint',async()=>{
    await go(0,2);await go(0,-.8);await go(-8,-.8);await use('key',-8,1,-2);
    assert.ok(text(await tree(),'status').includes('key'));
    const before=await state();
    await click('pause');await click('save');await click('load');
    const after=await state();
    assert.ok(text(after.tree,'status').includes('key'));
    assert.ok(Math.abs(after.x-before.x)<.05&&Math.abs(after.z-before.z)<.05);
    await checkpoint('card-restored');
  });
  await check('T04-reverse-power-order',async()=>{
    await go(-9.5,-.8);await go(-9.5,-6.6);await go(-6,-6.6);await use('auxiliary',-6,1,-8);
    assert.ok(text(await tree(),'status').includes('A:false B:true'));
    await go(-9.5,-6.6);await go(-9.5,-2);await go(-2,-2);await go(4,-2);
    await go(4,-7);await use('generator',6,1,-7);
    assert.ok(text(await tree(),'status').includes('A:true B:true'));
    assert.ok(!text(await tree(),'status').includes('battery'));
    await checkpoint('power-online');
  });
  await check('T05-door',async()=>{
    await go(4,-8.5);await use('door',4,1,-10);
    await go(6,-8.5);await go(6,-13.5);
    assert.ok((await state()).z < -12);
  });
  await check('T06-lift-pause-save-load',async()=>{
    await go(8,-15.5);await go(7.3,-16.8);
    await use('lift',8,.6,-18);
    await sleep(400);
    await click('pause');await click('save');
    const file=JSON.parse(await readFile(join(appdata,'facility-escape-3d/checkpoint.json'),'utf8'));
    assert.ok(file.lift_y>0&&file.lift_y<3,'saved in motion');
    await sleep(600);
    await click('save');
    const paused=JSON.parse(await readFile(join(appdata,'facility-escape-3d/checkpoint.json'),'utf8'));
    assert.equal(paused.lift_y,file.lift_y,'pause freezes lift');
    await click('load');await sleep(3200);
    assert.ok((await state()).y>2.8,'rider carried to upper deck');
    await checkpoint('lift-restored');
  });
  await check('T07-exit-replay',async()=>{
    await go(7,-20.5);await go(8,-20.5);await use('exit',8,4.1,-22);
    assert.equal((await tree()).screen,'result');await checkpoint('escaped');
    await click('start');assert.ok(text(await tree(),'status').includes('A:false B:false'));
    assert.ok(!text(await tree(),'status').includes('key'));
  });
  await check('T08-language-size-reset',async()=>{
    await click('pause');await click('language');
    assert.ok(text(await tree(),'instructions').includes('WASD move'));
    await click('resize');await checkpoint('english-small');
    await click('reset');assert.equal((await tree()).screen,'play');
    await click('pause');await click('load');assert.equal((await tree()).screen,'play');
  });
  } else {
    async function fresh(active){
      if((await tree()).screen==='play')await click('pause');
      for(const id of ['lost_key','through_wall','door_jam']){
        const on=text(await tree(),'bug_'+id).startsWith('[ON]');
        if(on!==(id===active))await click('bug_'+id);
      }
      await click('reset');
    }
    await check('T09-lost-key-differential',async()=>{
      for(const enabled of [false,true]){
        await fresh(enabled?'lost_key':null);
        await go(0,-.8);await go(-8,-.8);await use('key',-8,1,-2);
        assert.ok(text(await tree(),'status').includes('key'));
        await click('pause');await click('save');await click('load');
        assert.equal((await tree()).screen,'play');
        assert.equal(text(await tree(),'status').includes('key'),!enabled);
        await checkpoint('lost-key-'+enabled);
      }
    });
    await check('T10-wall-distance-differential',async()=>{
      for(const enabled of [false,true]){
        await fresh(enabled?'through_wall':null);
        await go(3,6.5);await use('battery',3,1,5);
        await go(0,2);await go(0,-2);await go(6,-3.5);
        await aim(6,1,-7);await click('interact');
        assert.ok(text(await tree(),'status').includes('A:false'),'range blocks both builds');
        await go(6,-5);await aim(6,1,-7);await click('interact');
        assert.equal(text(await tree(),'status').includes('A:true'),enabled,'occlusion differential');
        assert.equal(text(await tree(),'status').includes('battery'),!enabled,'battery consumption differential');
        await checkpoint('wall-'+enabled);
      }
    });
    await check('T11-door-jam-differential-retry',async()=>{
      for(const enabled of [false,true]){
        await fresh(enabled?'door_jam':null);
        await go(3,6.5);await use('battery',3,1,5);
        await go(0,2);await go(0,-.8);await go(-8,-.8);await use('key',-8,1,-2);
        await go(-2,-2);await go(4,-2);await go(4,-7);await use('generator',6,1,-7);
        await go(4,-8.5);await use('door',4,1,-10);
        await go(6,-8.5);await go(6,-11.5);
        const before=await state();
        assert.ok(Math.abs(before.z+12)<1,'inside door occupancy band');
        await sleep(4500);
        await face();await click('right',285);
        const after=await state();
        assert.equal(after.x-before.x>.5,!enabled,'movement after closure');
        await checkpoint('door-jam-'+enabled);
      }
      await click('pause');await click('reset');
      const before=await state();await click('forward',285);
      assert.ok((await state()).z<before.z-.5,'reset recovers from jam');
    });
  }
}catch(error){console.error(error);process.exitCode=1;}
finally{
  if(socket?.readyState===WebSocket.OPEN){try{await writeFile(join(output,'final-tree.json'),JSON.stringify(await tree(),null,2));}catch{}socket.close();}
  child.kill();await sleep(300);
  await writeFile(join(output,'engine.log'),stdout+'\nSTDERR\n'+stderr);
  await writeFile(join(output,'history.json'),JSON.stringify(history,null,2));
  await writeFile(join(output,'summary.json'),JSON.stringify({scenario:'facility-r1',seed:3001,bugs:[],mode:headed?'rendered-exe':'headless-exe',exe,sha256:createHash('sha256').update(await readFile(exe)).digest('hex'),results,unverified:['Audio subjective quality','Human physical keyboard full run','Unlisted geometry boundaries and exploratory coverage']},null,2));
  for(const p of pending.values()){clearTimeout(p.timer);p.reject(Error('test closed'));}
}
