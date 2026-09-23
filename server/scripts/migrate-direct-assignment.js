import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import path from 'node:path';
const prisma = new PrismaClient();
try {
  const columns = await prisma.$queryRawUnsafe('PRAGMA table_info(peripherals)');
  if (!columns.length) throw Error('Existing peripherals table is required. Initialize a fresh database with Prisma first.');
  if (columns.some(column => column.name === 'personnel_id')) {
    console.log('Direct assignment migration already applied.');
  } else {
    const backup = path.resolve(`assignment-backup-${Date.now()}.db`);
    await prisma.$executeRawUnsafe('VACUUM INTO ?', backup);
    await prisma.$transaction(async tx => {
      await tx.$executeRawUnsafe('ALTER TABLE peripherals ADD COLUMN personnel_id TEXT REFERENCES personnel(id) ON DELETE SET NULL');
      await tx.$executeRawUnsafe('CREATE INDEX IF NOT EXISTS peripherals_personnel_id_idx ON peripherals(personnel_id)');
    });
    console.log(`Added optional peripheral owner. Backup: ${backup}`);
  }
} finally { await prisma.$disconnect(); }
