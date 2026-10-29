import {mkdir,readFile,writeFile,copyFile} from 'node:fs/promises';
import {resolve,join} from 'node:path';
const root=resolve(import.meta.dirname,'..');
for(const run of process.argv.slice(2)){
  if(!/^[a-z][a-z0-9-]*$/.test(run))throw Error('Invalid run name');
  const source=join(root,'artifacts',run),target=join(root,'docs/evidence',run);
  if(run==='exploration'){
    const session=JSON.parse(await readFile(join(source,'session.json'),'utf8'));
    const history=JSON.parse(await readFile(join(source,'history.json'),'utf8'));
    await mkdir(target,{recursive:true});
    await writeFile(join(target,'session.json'),JSON.stringify(session,null,2));
    const text=(tree,id)=>tree.nodes.find(n=>n.id===id)?.text;
    await writeFile(join(target,'operations.jsonl'),history.map((h,index)=>JSON.stringify({index,command:h.command,receipt:h.receipt,completion:h.completion,screen:h.observed.screen,status:text(h.observed,'status'),target:text(h.observed,'target'),notice:text(h.observed,'notice'),menu:text(h.observed,'menu_message')})).join('\n')+'\n');
    await copyFile(join(source,'engine.log'),join(target,'engine.txt'));
    console.log(run,session.sha256,session.events+' exploratory observations; see assessment.md');
    continue;
  }
  const summary=JSON.parse(await readFile(join(source,'summary.json'),'utf8'));
  const history=JSON.parse(await readFile(join(source,'history.json'),'utf8'));
  await mkdir(target,{recursive:true});
  await writeFile(join(target,'summary.json'),JSON.stringify({...summary,exe:'dist/FacilityEscape.exe'},null,2));
  await copyFile(join(source,'gua-version.json'),join(target,'gua-version.json'));
  const text=(tree,id)=>tree.nodes.find(n=>n.id===id)?.text;
  const compact=history.map((h,index)=>({index,action:h.action,testSetup:h.testSetup,fixtureSha256:h.fixtureSha256,activeBugsBefore:h.activeBugsBefore,activeBugs:h.activeBugs??[],requestId:h.receipt?.requestId,completion:h.completion,screen:h.observed.screen,status:text(h.observed,'status'),target:text(h.observed,'target'),notice:text(h.observed,'notice'),menu:text(h.observed,'menu_message')}));
  await writeFile(join(target,'operations.jsonl'),compact.map(x=>JSON.stringify(x)).join('\n')+'\n');
  await copyFile(join(source,'engine.log'),join(target,'engine.txt'));
  console.log(run,summary.sha256,summary.results.map(r=>r.id+':'+r.status).join(', '));
}
