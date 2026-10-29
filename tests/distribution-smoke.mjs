// Limited packaging smoke: no attach, semantic actions, exploration or E2E runner.
import {readFile,writeFile,mkdir,mkdtemp,copyFile,readdir} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {resolve,join} from 'node:path';
import {tmpdir} from 'node:os';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const root=resolve(import.meta.dirname,'..'),source=resolve(process.argv[2]??join(root,'dist'));
const output=join(root,'artifacts/distribution-smoke');
await mkdir(output,{recursive:true});
const staging=await mkdtemp(join(tmpdir(),'facility-3d-smoke-'));
const hash=data=>createHash('sha256').update(data).digest('hex');
const exe=await readFile(join(source,'FacilityEscape.exe'));
const dll=await readFile(join(source,'gua_godot.windows.release.x86_64.dll'));
const official=await readFile(join(root,'addons/gua/bin/gua_godot.windows.release.x86_64.dll'));
function amd64(data){assert.equal(data.toString('ascii',0,2),'MZ');const pe=data.readUInt32LE(0x3c);assert.equal(data.toString('ascii',pe,pe+4),'PE\0\0');assert.equal(data.readUInt16LE(pe+4),0x8664);}
amd64(exe);amd64(dll);assert.equal(hash(dll),hash(official),'official Gua 1.1.2 release DLL');
assert.equal(exe.toString('ascii',exe.length-4),'GDPC');
const packSize=Number(exe.readBigUInt64LE(exe.length-12)),packOffset=exe.length-12-packSize;
assert.ok(packOffset>1024*1024&&packSize>1024);
assert.equal(exe.toString('ascii',packOffset,packOffset+4),'GDPC');
assert.equal(exe.readUInt32LE(packOffset+8),4);assert.equal(exe.readUInt32LE(packOffset+12),7);
for(const name of ['FacilityEscape.exe','gua_godot.windows.release.x86_64.dll'])await copyFile(join(source,name),join(staging,name));
const appdata=join(output,'appdata');await mkdir(appdata,{recursive:true});
let stdout='',stderr='',timedOut=false;
const child=spawn(join(staging,'FacilityEscape.exe'),['--headless','--max-fps','60','--quit-after','30'],{
 cwd:staging,windowsHide:true,env:{...process.env,APPDATA:appdata,GUA_BRIDGE_PORT:'18732',GUA_NATIVE_DIR:'',GUA_RUNTIME_NATIVE_DIR:''}
});
child.stdout.on('data',x=>stdout+=x);child.stderr.on('data',x=>stderr+=x);
const timer=setTimeout(()=>{timedOut=true;child.kill();},10000);
let code;
try {code=await new Promise((res,rej)=>{child.on('error',rej);child.on('exit',res);});}
finally {clearTimeout(timer);}
await writeFile(join(output,'stdout.txt'),stdout);await writeFile(join(output,'stderr.txt'),stderr);
const report={kind:'limited-distribution-smoke',exeSha256:hash(exe),dllSha256:hash(dll),officialDllMatch:true,peArchitecture:'AMD64',packSize,packOffset,
 files:await readdir(staging),exitCode:code,timedOut,bridgeStartupMessage:stdout.includes('listening on ws://127.0.0.1:18732'),
 notVerified:['No protocol connection/attach','No gameplay actions or clear','No Scenario/budget/cleanup integration','No Trace/Recording/Replay','No rendered or physical-input acceptance','No clean Windows runtime compatibility']};
await writeFile(join(output,'result.json'),JSON.stringify(report,null,2));
assert.equal(timedOut,false);assert.equal(code,0);assert.equal(report.bridgeStartupMessage,true);
assert.ok(!/SCRIPT ERROR|Failed to load|Can't open GDExtension/i.test(stderr));
console.log(JSON.stringify(report));
