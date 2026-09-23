import fs from 'node:fs/promises';
import path from 'node:path';
import {databasePath,serverDir} from '../src/runtime-config.js';
import {prisma} from '../src/prisma.js';
import {seedAndMigrateData} from '../prisma/seed.js';
try {
  if(await fs.stat(databasePath).then(()=>true).catch(e=>{if(e.code==='ENOENT')return false;throw e;})) {const error=new Error();error.code='EEXIST';throw error;}
  if(!process.env.INITIAL_ADMIN_PASSWORD || process.env.INITIAL_ADMIN_PASSWORD.length<12) throw new Error('Set INITIAL_ADMIN_PASSWORD before initialization.');
  await fs.mkdir(path.dirname(databasePath),{recursive:true});
  const handle=await fs.open(databasePath,'wx',0o600);await handle.close();
  const sql=await fs.readFile(path.join(serverDir,'prisma/initial-schema.sql'),'utf8');
  await prisma.$transaction(async tx=>{for(const statement of sql.split(';').map(s=>s.trim()).filter(Boolean)) await tx.$executeRawUnsafe(statement);});
  await seedAndMigrateData();
  console.info('New database initialized. Existing installations should use npm start, never db:init.');
} catch(error) {
  console.error(error.code==='EEXIST'?'Database already exists. Initialization refused; no data was changed.':'Database initialization failed. Check the configured path and schema.');
  process.exitCode=1;
} finally {await prisma.$disconnect();}
