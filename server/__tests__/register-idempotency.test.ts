import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import { mkdtempSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { createGitFixture, type GitFixture } from './helpers/git-fixture.js';
import { initStore, closeStore } from '../store.js';
import { SessionManager } from '../session-manager.js';
import { createApp } from '../app.js';

describe('POST /projects idempotency', () => {
  let fixture: GitFixture;
  let tmpDir: string;
  let app: ReturnType<typeof createApp>;
  let manager: SessionManager;

  beforeAll(() => {
    fixture = createGitFixture();
    tmpDir = mkdtempSync(join(tmpdir(), 'lgtm-idempotency-test-'));
    initStore(join(tmpDir, 'test.db'));
    manager = new SessionManager(9999);
    app = createApp(manager);
  });

  afterAll(() => {
    for (const project of manager.list()) {
      manager.deregister(project.slug);
    }
    closeStore();
    fixture.cleanup();
    rmSync(tmpDir, { recursive: true, force: true });
  });

  it('POST /projects is idempotent for same repoPath', async () => {
    const r1 = await request(app).post('/projects').send({ repoPath: fixture.repoPath }).expect(200);
    const r2 = await request(app).post('/projects').send({ repoPath: fixture.repoPath }).expect(200);
    const r3 = await request(app).post('/projects').send({ repoPath: fixture.repoPath }).expect(200);

    expect(r1.body.ok).toBe(true);
    expect(r2.body.slug).toBe(r1.body.slug);
    expect(r3.body.slug).toBe(r1.body.slug);

    const matches = manager.list().filter(p => p.slug === r1.body.slug);
    expect(matches).toHaveLength(1);
  });
});
