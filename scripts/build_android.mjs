import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

export function androidBuildArgs(args) {
  // Flutter tests register dev plugins; release builds must regenerate that list.
  if (args.includes('--no-pub')) throw Error('Android builds must refresh plugin registration. Remove --no-pub.');
  const platform = args.some(arg => arg === '--target-platform' || arg.startsWith('--target-platform='));
  return ['build', 'apk', '--release',
    ...(!platform ? ['--target-platform=android-arm64'] : []),
    ...(!args.includes('--split-per-abi') ? ['--split-per-abi'] : []), ...args];
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = androidBuildArgs(process.argv.slice(2));
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const env = {...process.env};
  const credentials = path.join(root, '.release-secrets/android-signing.json');
  // CI uses android/key.properties; local builds may use the existing project key.
  if (!env.MODU_ANDROID_KEYSTORE && !fs.existsSync(path.join(root, 'android/key.properties')) && fs.existsSync(credentials)) {
    let saved;
    try { saved = JSON.parse(fs.readFileSync(credentials, 'utf8')); }
    catch { throw Error('Unable to read local Android signing credentials.'); }
    const {alias, password} = saved;
    if (typeof alias !== 'string' || !alias || typeof password !== 'string' || !password)
      throw Error('Local Android signing credentials are incomplete.');
    env.MODU_ANDROID_KEYSTORE = path.join(root, '.release-secrets/modu-release.jks');
    env.MODU_ANDROID_KEY_ALIAS = alias;
    env.MODU_ANDROID_KEY_PASSWORD = password;
  }
  const result = spawnSync('flutter', args, {
    cwd: root, env, stdio: 'inherit',
  });
  if (result.error) console.error(result.error.message);
  process.exit(result.status ?? 1);
}
