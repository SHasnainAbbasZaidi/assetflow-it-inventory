import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
export const serverDir = fileURLToPath(new URL('../', import.meta.url));
dotenv.config({path:process.env.ASSETFLOW_ENV_FILE || path.join(serverDir,'.env')});
export function resolveDatabasePath(url = process.env.DATABASE_URL) {
  if (!url?.startsWith('file:')) throw new Error('DATABASE_URL must point to the existing SQLite database (file:/absolute/path/assetflow.db).');
  const value=url.slice(5);
  if (!value || value.includes('?') || value===':memory:') throw new Error('A persistent SQLite database file is required.');
  return path.isAbsolute(value) ? path.normalize(value) : path.resolve(serverDir,'prisma',value);
}
export const databasePath = resolveDatabasePath();
process.env.DATABASE_URL='file:'+databasePath.replaceAll('\\','/');
