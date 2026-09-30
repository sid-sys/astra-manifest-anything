// Builds the public "build mirror" of this project, and refuses to finish if it
// would publish anything it should not.
//
//   node tool/sync_public.mjs [targetDir] [--commit]
//
// Why this exists: GitHub-hosted runners are free and unlimited on a public
// repository, and a macOS minute on a private one costs ten times a Linux
// minute. iOS can only be built on macOS. So the iOS build runs from a public
// repository — which means everything in that repository is public, forever,
// and cached by people who never asked. Publishing is the one step here that
// cannot be taken back, so it is the one step written as an allowlist with a
// gate on the end, rather than as "copy the project and remember to delete the
// private parts".
//
// The private repository stays the source of truth. The mirror is generated,
// and anything edited by hand in it is overwritten by the next run.
//
// What is copied is exactly what `flutter build ios` reads: the Dart source,
// the assets it bundles, the iOS project, the lockfile, and the workflow. What
// is not: the server (`functions/`, which holds the prompts and the pricing
// logic), the store listing, the docs, the tests, the Android project with its
// signing config, the security rules, and every credential.

import { spawnSync } from 'node:child_process';
import {
  cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const SOURCE = resolve(here, '..');

const args = process.argv.slice(2);
const commit = args.includes('--commit');
const TARGET = resolve(args.find((a) => !a.startsWith('--')) ?? join(SOURCE, '..', 'maya-ios-build'));

if (TARGET === SOURCE || TARGET.startsWith(SOURCE + sep)) {
  fail('The target must be a different folder from the project — it would copy into itself.');
}

// ------------------------------------------------------------------ allowlist

/** The only things that leave. Anything not named here is not copied. */
const ALLOW = [
  'lib',
  // Only the assets pubspec.yaml bundles — see bundledAssets(). The folder also
  // holds the raw logo source and the icon masters, which the build never
  // reads, and "required to build" is the whole test for what leaves.
  ...bundledAssets(),
  'ios',
  '.github/workflows/ios.yml',
  'pubspec.yaml',
  'pubspec.lock',
  'analysis_options.yaml',
];

/** Names skipped anywhere inside an allowed folder: generated, local, or noise. */
const SKIP_NAMES = new Set([
  '.DS_Store', 'Pods', '.symlinks', 'ephemeral', 'xcuserdata', 'DerivedData',
  'Generated.xcconfig', 'flutter_export_environment.sh', '.dart_tool', 'build',
]);

/** The asset paths pubspec.yaml lists under `flutter: assets:`. */
function bundledAssets() {
  const pubspec = readFileSync(join(SOURCE, 'pubspec.yaml'), 'utf8');
  const listed = [...pubspec.matchAll(/^\s+-\s+(assets\/\S+)\s*$/gm)].map((m) => m[1]);
  if (listed.length === 0) fail('Found no bundled assets in pubspec.yaml — the pattern needs updating.');
  return listed;
}

// ------------------------------------------------------------ the one rewrite

/**
 * The admin's own email address is a constant in the client. It is not a
 * secret — the server re-checks the account itself and refuses anyone else —
 * but a public repository with the admin's address, the admin screen and the
 * name of every admin endpoint next to each other is a map for a phishing
 * email, so the mirror gets an empty string instead.
 *
 * The consequence is that a build from the mirror has no admin panel, which is
 * right for an iOS build nobody administers from.
 *
 * Refuses if the line is not found exactly once. A refactor that renames this
 * constant must not silently start publishing the address again.
 */
const REWRITES = [
  {
    file: 'lib/services/admin_service.dart',
    pattern: /const adminEmail = '[^']+';/g,
    replacement: "const adminEmail = '';",
    expect: 1,
  },
];

// ----------------------------------------------------------------- the gate

/** A path containing any of these does not ship. Checked after copying. */
const FORBIDDEN_PATHS = [
  /(^|\/)(functions|store|docs|tool|test|android|web|\.claude|coverage)(\/|$)/,
  /(^|\/)\.env/,
  /\.(jks|keystore|p12|mobileprovision|p8|pem)$/i,
  /(^|\/)key\.properties$/,
  /(^|\/)google-services\.json$/,
  /(^|\/)GoogleService-Info\.plist$/,
  /(^|\/)(firebase\.json|\.firebaserc|firestore\.(rules|indexes\.json))$/,
];

/** A file whose text matches any of these blocks the run. */
const BLOCK_CONTENT = [
  [/sk-ant-[A-Za-z0-9_-]{10,}/, 'an Anthropic API key'],
  [/sk-[A-Za-z0-9]{32,}/, 'an OpenAI-style API key'],
  [/-----BEGIN (RSA |EC |OPENSSH |ENCRYPTED |)PRIVATE KEY-----/, 'a private key'],
  [/gh[pousr]_[A-Za-z0-9]{30,}/, 'a GitHub token'],
  [/github_pat_[A-Za-z0-9_]{30,}/, 'a GitHub token'],
  [/AKIA[0-9A-Z]{16}/, 'an AWS access key'],
  [/xox[bap]-[A-Za-z0-9-]{10,}/, 'a Slack token'],
  [/(store|key)Password\s*=\s*[^\s"'$)]/, 'a keystore password'],
  [/xi-api-key['"]?\s*[:=]\s*['"][A-Za-z0-9]{20,}/, 'an ElevenLabs key'],
  // Your own machine, leaking out through generated files.
  [/[A-Za-z]:\\+Users\\+[A-Za-z0-9._-]+/, 'a Windows user path'],
  [/\/Users\/[A-Za-z0-9._-]+\//, 'a macOS user path'],
  // Identity and business detail that has no business in a public repository.
  [/sidharthbabu/i, "the admin's email address"],
  [/coreinteractivestudio/i, "the owner's account email"],
  [/\$0\.161\b|\$0\.112\b/, 'the cost of a manifestation'],
  [/per (thousand|million) (characters|tokens)/i, 'a vendor unit cost'],
];

/** Worth a line in the report, not worth stopping for. */
const WARN_CONTENT = [
  [/AIza[0-9A-Za-z_-]{35}/g, 'Firebase API key (a client identifier, meant to ship in the app — but restrict it in Google Cloud)'],
  [/support@[a-z0-9.-]+\.[a-z]+/gi, 'support email address'],
];

const BINARY = /\.(png|jpe?g|webp|gif|ico|icns|mp3|wav|m4a|ttf|otf|woff2?|jar|so|a|zip|gz|pdf|car|storyboardc|nib)$/i;

// -------------------------------------------------------------------- run

function fail(message) {
  console.error(`\nREFUSED: ${message}\n`);
  process.exit(1);
}

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    if (name === '.git') continue;
    const full = join(dir, name);
    if (statSync(full).isDirectory()) walk(full, out);
    else out.push(full);
  }
  return out;
}

const posix = (p) => p.split(sep).join('/');

// Clear the target, keeping its .git, so a file deleted in the source is
// deleted in the mirror too. Without this a removed secret would survive there.
mkdirSync(TARGET, { recursive: true });
for (const name of readdirSync(TARGET)) {
  if (name === '.git') continue;
  rmSync(join(TARGET, name), { recursive: true, force: true });
}

for (const entry of ALLOW) {
  const from = join(SOURCE, entry);
  if (!existsSync(from)) fail(`"${entry}" is on the allowlist but does not exist in the project.`);

  cpSync(from, join(TARGET, entry), {
    recursive: true,
    filter: (src) => !SKIP_NAMES.has(src.split(sep).pop()),
  });
}

for (const rewrite of REWRITES) {
  const path = join(TARGET, rewrite.file);
  const text = readFileSync(path, 'utf8');
  const hits = text.match(rewrite.pattern)?.length ?? 0;
  if (hits !== rewrite.expect) {
    fail(
      `${rewrite.file}: expected ${rewrite.expect} match for the admin-email rewrite, found ${hits}. ` +
        'The line was probably renamed — update REWRITES, do not publish until it matches.',
    );
  }
  writeFileSync(path, text.replace(rewrite.pattern, rewrite.replacement));
}

writeFileSync(
  join(TARGET, '.gitignore'),
  [
    '# Generated, local, or a credential. None of these belong in a public repo.',
    'build/', '.dart_tool/', '.flutter-plugins-dependencies',
    'ios/Pods/', 'ios/.symlinks/', 'ios/Flutter/Generated.xcconfig',
    'ios/Flutter/flutter_export_environment.sh', 'ios/Flutter/ephemeral/',
    '.DS_Store', '.env', '.env.*',
    '*.p12', '*.p8', '*.mobileprovision', '*.jks', '*.keystore',
    'GoogleService-Info.plist', 'google-services.json', '',
  ].join('\n'),
);

writeFileSync(
  join(TARGET, 'README.md'),
  `# Maya — iOS build mirror

This repository exists to build the iOS version of **Personal Manifestation:
Maya** on GitHub's free macOS runners. It is generated from a private source
repository; it is not where the app is developed, and anything changed here by
hand is overwritten by the next sync.

- Build: **Actions → iOS build → Run workflow**, or push to \`main\`.
- It compiles the app with \`--no-codesign\` and uploads nothing.
- No issues or pull requests are read.

Published by Tetradevelopers.
`,
);

// ---------------------------------------------------------------- the gate

const files = walk(TARGET);
const blockers = [];
const warnings = new Map();

for (const file of files) {
  const rel = posix(relative(TARGET, file));

  for (const forbidden of FORBIDDEN_PATHS) {
    if (forbidden.test(rel)) blockers.push(`${rel}  —  forbidden path (${forbidden})`);
  }

  if (BINARY.test(file)) continue;
  let text;
  try {
    text = readFileSync(file, 'utf8');
  } catch {
    continue;
  }

  for (const [pattern, what] of BLOCK_CONTENT) {
    const line = text.split('\n').findIndex((l) => pattern.test(l));
    if (line !== -1) blockers.push(`${rel}:${line + 1}  —  contains ${what}`);
  }

  for (const [pattern, what] of WARN_CONTENT) {
    const n = text.match(pattern)?.length ?? 0;
    if (n) warnings.set(what, (warnings.get(what) ?? 0) + n);
  }
}

// ------------------------------------------------------------------ report

const bytes = files.reduce((sum, f) => sum + statSync(f).size, 0);
const byTop = new Map();
for (const f of files) {
  const top = posix(relative(TARGET, f)).split('/')[0];
  byTop.set(top, (byTop.get(top) ?? 0) + 1);
}
const biggest = files
  .map((f) => [statSync(f).size, posix(relative(TARGET, f))])
  .sort((a, b) => b[0] - a[0])
  .slice(0, 4);

console.log(`Mirror: ${TARGET}`);
console.log(`${files.length} files, ${(bytes / 1048576).toFixed(1)} MB`);
for (const [top, n] of [...byTop].sort()) console.log(`  ${top.padEnd(26)} ${n} files`);
console.log('Largest:');
for (const [size, name] of biggest) console.log(`  ${(size / 1048576).toFixed(2).padStart(6)} MB  ${name}`);

if (warnings.size) {
  console.log('\nFor your attention (does not block):');
  for (const [what, n] of warnings) console.log(`  ${n} × ${what}`);
}

if (blockers.length) {
  console.error('\nBLOCKED — the mirror was built but must not be published:\n');
  for (const b of blockers) console.error(`  ✗ ${b}`);
  console.error(`\n${blockers.length} problem(s). Nothing was committed.`);
  process.exit(1);
}

console.log('\nGate passed: no secret, credential, private path or forbidden folder found.');

// ------------------------------------------------------------------ commit

if (commit) {
  const git = (...a) => spawnSync('git', ['-C', TARGET, ...a], { encoding: 'utf8' });

  if (!existsSync(join(TARGET, '.git'))) git('init', '-b', 'main');

  const sha = spawnSync('git', ['-C', SOURCE, 'rev-parse', '--short', 'HEAD'], { encoding: 'utf8' })
    .stdout.trim();

  git('add', '-A');
  if (git('status', '--porcelain').stdout.trim() === '') {
    console.log('Nothing changed since the last sync. No commit made.');
  } else {
    const result = git('commit', '-q', '-m', `Mirror of source ${sha}`);
    if (result.status !== 0) fail(`git commit failed: ${result.stderr}`);
    console.log(`Committed "Mirror of source ${sha}". Not pushed.`);
  }
}
