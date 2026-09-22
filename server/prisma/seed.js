import bcrypt from 'bcryptjs';
import crypto from 'node:crypto';
import { prisma } from '../src/prisma.js';

export async function seedAndMigrateData() {
  try {
    // 1. Seed Default Admin
    const adminEmail = 'admin@assetflow.local';
    const existing = await prisma.appUser.findUnique({ where: { email: adminEmail } });
    if (!existing) {
      const passwordHash = await bcrypt.hash('admin123', 10);
      await prisma.appUser.create({
        data: {
          email: adminEmail,
          fullName: 'System Administrator',
          role: 'ADMIN',
          status: 'ACTIVE',
          passwordHash,
        }
      });
      console.log('✅ Default admin user verified: admin@assetflow.local / admin123');
    }

    // 2. Backfill existing Workstation userNames into Personnel entity
    const workstationsWithUsers = await prisma.workstation.findMany({
      where: {
        userName: { not: null }
      }
    });

    for (const ws of workstationsWithUsers) {
      const name = ws.userName?.trim();
      if (!name) continue;

      let person = await prisma.personnel.findFirst({
        where: { fullName: name }
      });

      if (!person) {
        person = await prisma.personnel.create({
          data: {
            id: crypto.randomUUID(),
            fullName: name,
            department: 'General',
            notes: 'Migrated from workstation assignment'
          }
        });
        console.log(`👤 Created Personnel record for: ${name}`);
      }

      if (!ws.personnelId || ws.personnelId !== person.id) {
        await prisma.workstation.update({
          where: { workstationTag: ws.workstationTag },
          data: { personnelId: person.id }
        });
      }
    }

    // 3. Initialize default settings if missing
    const defaultSettings = [
      { key: 'companyName', value: 'AssetFlow Enterprise' },
      { key: 'companyAddress', value: 'Headquarters, Innovation Way' },
      { key: 'companyLogo', value: '' },
      { key: 'tagPrefixWs', value: 'WS' },
      { key: 'tagPrefixPer', value: 'PER' },
      { key: 'tagSeqLength', value: '4' },
      { key: 'tagSeqStart', value: '1001' },
      { key: 'tagSeparator', value: '-' },
      { key: 'themeMode', value: 'dark' },
      { key: 'accentColor', value: '#6366f1' },
    ];

    for (const s of defaultSettings) {
      const exists = await prisma.appSetting.findUnique({ where: { key: s.key } });
      if (!exists) {
        await prisma.appSetting.create({ data: s });
      }
    }

  } catch (err) {
    console.warn('⚠️ Error during database initialization / seed:', err.message);
  }
}

