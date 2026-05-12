#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';

const repoRoot = new URL('../..', import.meta.url);
const packageDir = new URL('.', import.meta.url);
const defaultNixPath = new URL('default.nix', packageDir);
const lockfilePath = new URL('package-lock.json', packageDir);
const registryCache = new Map();

// Version Selection
async function getVersion() {
  const argVersion = process.argv[2];
  if (argVersion) return argVersion.replace(/^v/, '');

  const defaultNix = await fs.readFile(defaultNixPath, 'utf8');
  const match = defaultNix.match(/version\s*=\s*"([^"]+)";/);
  if (!match) throw new Error(`Unable to find version in ${defaultNixPath.pathname}`);
  return match[1];
}

// Package Name Extraction
function packageNameFromLockPath(lockPath) {
  const parts = lockPath.split('/');
  const idx = parts.lastIndexOf('node_modules');
  if (idx < 0 || idx + 1 >= parts.length) return null;

  const first = parts[idx + 1];
  if (first.startsWith('@')) return `${first}/${parts[idx + 2]}`;
  return first;
}

// Registry Fetching
function registryUrl(name, version) {
  const encodedName = name.startsWith('@') ? name.replace('/', '%2f') : name;
  return `https://registry.npmjs.org/${encodedName}/${version}`;
}

async function fetchPackageMetadata(name, version) {
  const key = `${name}@${version}`;
  if (registryCache.has(key)) return registryCache.get(key);

  const response = await fetch(registryUrl(name, version), {
    headers: { accept: 'application/json' },
  });
  if (!response.ok) {
    throw new Error(`Failed to fetch ${key}: HTTP ${response.status}`);
  }

  const metadata = await response.json();
  const dist = metadata.dist;
  if (!dist?.tarball || !dist?.integrity) {
    throw new Error(`Missing dist.tarball/dist.integrity for ${key}`);
  }

  registryCache.set(key, dist);
  return dist;
}

// Lockfile Enrichment
async function enrichLockfile(lock) {
  let updated = 0;

  for (const [lockPath, entry] of Object.entries(lock.packages ?? {})) {
    if (!lockPath || entry.link || !entry.version || entry.resolved) continue;
    if (!lockPath.includes('node_modules')) continue;

    const name = packageNameFromLockPath(lockPath);
    if (!name) continue;

    const dist = await fetchPackageMetadata(name, entry.version);
    entry.resolved = dist.tarball;
    entry.integrity = dist.integrity;
    updated += 1;
  }

  return updated;
}

// Main
const version = await getVersion();
const lockUrl = `https://raw.githubusercontent.com/earendil-works/pi-mono/v${version}/package-lock.json`;
const response = await fetch(lockUrl, { headers: { accept: 'application/json' } });
if (!response.ok) throw new Error(`Failed to fetch ${lockUrl}: HTTP ${response.status}`);

const lock = await response.json();
const updated = await enrichLockfile(lock);
await fs.writeFile(lockfilePath, JSON.stringify(lock, null, 2) + '\n');

const displayPath = path.relative(repoRoot.pathname, lockfilePath.pathname);
console.error(`Wrote ${displayPath} for v${version}; restored metadata for ${updated} entries.`);
