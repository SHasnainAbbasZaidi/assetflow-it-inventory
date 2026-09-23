import {databasePath} from '../src/runtime-config.js';
import {prisma} from '../src/prisma.js';
import {upgradeDatabase} from '../src/services/database-upgrade.js';
try {await upgradeDatabase(prisma,databasePath);console.info('Database verified; existing records preserved.');}
catch(error) {console.error(error.message);process.exitCode=1;}
finally {await prisma.$disconnect();}
