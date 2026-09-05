import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, writeFileSync, chmodSync, readFileSync, statSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { AppServer, CONFIG, serverArgs, safeText, validateResponse, userError, teachingInstructions } from '../bin/terminal-ai-chat.mjs';

const fixture = resolve('tests/fixtures/fake-app-server.mjs');
const client = resolve('bin/terminal-ai-chat.mjs');
const originalPath = process.env.PATH;

async function ask(mode, prompt = 'General question', previous = null, options = {}) {
  const oldMode = process.env.MTU_FAKE_MODE;
  process.env.MTU_FAKE_MODE = mode;
  const server = new AppServer({ cwd: tmpdir(), command: process.execPath, args: [fixture], timeoutMs: 1500, ...options });
  if (oldMode === undefined) delete process.env.MTU_FAKE_MODE; else process.env.MTU_FAKE_MODE = oldMode;
  try { return await server.ask(prompt, previous); } finally { server.stop(); }
}

test('questions produce explanations with no command', async () => {
  const answer = await ask('success');
  assert.equal(answer.command, null);
  assert.match(answer.answer, /General question/);
});
test('follow-ups resume the exact conversation', async () => {
  assert.equal((await ask('require-resume', 'follow-up', 'test-thread')).threadId, 'test-thread');
});
test('suggestions stay inert text', async () => {
  assert.equal((await ask('success', 'suggest')).command, "printf 'MTU_EXECUTED_MARKER\\n'");
});
test('no terminal escape or multiline command reaches the UI', async () => {
  const result = await ask('escape');
  assert.equal(result.answer, 'Visible answer');
  assert.equal(result.command, null);
  assert.equal(safeText('a\r\x1b[2Jb\u202ec'), 'abc');
});
for (const mode of ['approval', 'tool', 'malformed', 'exit', 'invalid-answer', 'error', 'inject-error']) {
  test(`${mode} fails closed`, async () => {
    await assert.rejects(ask(mode));
  });
}
test('timeout is bounded and stops the client', async () => {
  const start = Date.now();
  await assert.rejects(ask('hang', 'question', null, { timeoutMs: 100 }), /timed out/);
  assert.ok(Date.now() - start < 1500);
});
test('cancellation rejects the request', async () => {
  const controller = new AbortController();
  const result = ask('hang', 'question', null, { signal: controller.signal });
  setTimeout(() => controller.abort(), 75);
  await assert.rejects(result, /cancelled/);
});
test('cancelled before startup is also handled', async () => {
  const controller = new AbortController(); controller.abort();
  await assert.rejects(ask('success', 'question', null, { signal: controller.signal }), /cancelled/);
});
test('configuration is scoped to the child; no prompt enters argv', () => {
  const args = serverArgs();
  assert.equal(args.includes('--listen'), true);
  assert.equal(args.includes('stdio://'), true);
  assert.equal(args.includes('mcp_servers={}'), true);
  assert.equal(CONFIG.features.shell_tool, false);
  assert.equal(CONFIG.features.hooks, false);
  assert.equal(CONFIG.web_search, 'disabled');
  assert.equal(CONFIG.approval_policy, 'never');
  assert.ok(!args.some(arg => arg.includes('General question')));
});
test('errors distinguish auth, quota, network, configuration and timeout', () => {
  assert.match(userError(new Error('401 Unauthorized')), /authentication failed/);
  assert.match(userError(new Error('429 rate limit')), /usage limit/);
  assert.match(userError(new Error('network disconnected')), /connection failed/);
  assert.match(userError(new Error('invalid schema')), /do not reset your login/);
  assert.match(userError(new Error('timed out')), /timed out/);
});
test('response validation rejects wrong fields and strips unstageable commands', () => {
  for (const value of ['null', '{}', '{"answer":"","command":null}', '{"answer":"ok","command":false}', '{"answer":"ok","command":null,"execute":true}']) assert.throws(() => validateResponse(value));
  for (const command of ['# recurse', 'ls\nwhoami', 'ls\t.', 'ls\u2028whoami', 'ls\x1b[31m']) assert.equal(validateResponse(JSON.stringify({ answer: 'ok', command })).command, null);
  // Shell metacharacters are allowed as visible, unverified suggestions, never evaluated.
  assert.equal(validateResponse(JSON.stringify({ answer: 'Review carefully', command: "find . -name '*.pdf'" })).command, "find . -name '*.pdf'");
});

function setup() {
  const root = mkdtempSync(join(tmpdir(), 'mtu-ai-test.'));
  chmodSync(root, 0o700);
  const fakeBin = join(root, 'bin'); mkdirSync(fakeBin, { mode: 0o700 });
  symlinkSync(fixture, join(fakeBin, 'codex'));
  return { root, env: { ...process.env, PATH: `${fakeBin}:${originalPath}`, PWD: root, MTU_FAKE_MODE: 'success' } };
}
function run(setup, prompt, additions = {}) {
  return spawnSync(process.execPath, [client, '--state-dir', setup.root], {
    input: prompt, encoding: 'utf8', env: { ...setup.env, ...additions }, timeout: 5000,
  });
}
test('stdin prompts, private state, fresh-process resume, and reset', () => {
  const setupData = setup();
  const initial = run(setupData, 'suggest');
  assert.equal(initial.status, 0, initial.stderr);
  const stateFile = join(setupData.root, 'conversation.json');
  assert.equal(statSync(stateFile).mode & 0o777, 0o600);
  assert.equal(JSON.parse(readFileSync(stateFile)).threadId, 'test-thread');
  assert.equal(run(setupData, 'follow-up', { MTU_FAKE_MODE: 'require-resume' }).status, 0);
  assert.equal(run(setupData, '/new').status, 0);
  assert.deepEqual(JSON.parse(readFileSync(stateFile)), { mode: 'learn' });
});
test('command staging requires explicit control and the same directory', () => {
  const setupData = setup();
  const result = JSON.parse(run(setupData, 'suggest').stdout);
  assert.equal(result.stage, undefined);
  assert.equal(JSON.parse(run(setupData, '/command').stdout).stage, true);
  assert.equal(JSON.parse(run(setupData, '/command', { PWD: '/' }).stdout).command, null);
});
test('a failed request clears any previously staged suggestion', () => {
  const setupData = setup();
  assert.equal(run(setupData, 'suggest').status, 0);
  assert.equal(run(setupData, 'fail', { MTU_FAKE_MODE: 'error' }).status, 1);
  assert.equal(JSON.parse(run(setupData, '/command').stdout).command, null);
});
test('symlink or public state is rejected without overwriting its target', () => {
  const setupData = setup();
  const target = join(setupData.root, 'untouched');
  writeFileSync(target, '{}', { mode: 0o600 });
  symlinkSync(target, join(setupData.root, 'conversation.json'));
  assert.equal(run(setupData, '/new').status, 1);
  assert.equal(readFileSync(target, 'utf8'), '{}');
  const other = setup(); chmodSync(other.root, 0o755);
  assert.equal(run(other, '/new').status, 1);
});
test('oversized and empty prompts do not start a model request', () => {
  const setupData = setup();
  assert.equal(run(setupData, 'x'.repeat(8001)).status, 1);
  assert.equal(run(setupData, '').status, 1);
});
test('unsupported old Codex versions cannot silently ignore safety fields', () => {
  const setupData = setup();
  const result = run(setupData, 'question', { MTU_FAKE_VERSION: '0.152.0' });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /0.153.2 or newer/);
});
test('reset recovers malformed private state without loosening file permissions', () => {
  const setupData = setup();
  const file = join(setupData.root, 'conversation.json');
  writeFileSync(file, '{broken', { mode: 0o600 });
  assert.equal(run(setupData, 'question').status, 1);
  assert.equal(run(setupData, '/new').status, 0);
  assert.deepEqual(JSON.parse(readFileSync(file)), { mode: 'learn' });
  assert.equal(statSync(file).mode & 0o777, 0o600);
});

test('learning instructions teach command parts, recall, platform differences and side effects', () => {
  const learning = teachingInstructions();
  for (const phrase of ['Learning mode is active', 'each argument/flag', 'ONE tiny recall challenge', 'macOS/BSD', 'updates timestamps', 'Never claim that the command has already run']) assert.ok(learning.includes(phrase));
  const brief = teachingInstructions('brief');
  assert.match(brief, /Brief mode is active/);
  assert.ok(!brief.includes('Learning mode is active'));
  assert.throws(() => teachingInstructions('unsafe'), /Invalid conversation state/);
});
test('learning is default; local mode switches persist across processes and reset', () => {
  const setupData = setup();
  assert.equal(run(setupData, 'question', { MTU_EXPECT_TEACHING: 'Learning' }).status, 0);
  assert.equal(run(setupData, 'suggest').status, 0);
  // Local controls work without starting the deliberately failing fake service.
  assert.equal(run(setupData, '/brief', { MTU_FAKE_MODE: 'error' }).status, 0);
  assert.equal(JSON.parse(run(setupData, '/command').stdout).command, null);
  assert.equal(run(setupData, 'question', { MTU_EXPECT_TEACHING: 'Brief' }).status, 0);
  assert.equal(run(setupData, '/new').status, 0);
  assert.equal(run(setupData, 'question', { MTU_EXPECT_TEACHING: 'Brief' }).status, 0);
  assert.equal(run(setupData, '/learn', { MTU_FAKE_MODE: 'error' }).status, 0);
  assert.equal(run(setupData, 'question', { MTU_EXPECT_TEACHING: 'Learning' }).status, 0);
});
test('quiz uses context and never stages a model-provided solution', () => {
  const setupData = setup();
  const empty = run(setupData, '/quiz', { MTU_FAKE_MODE: 'error' });
  assert.equal(empty.status, 0);
  assert.match(JSON.parse(empty.stdout).answer, /Ask about a command first/);
  assert.equal(run(setupData, 'suggest').status, 0);
  const quiz = run(setupData, '/quiz', { MTU_FAKE_MODE: 'quiz' });
  assert.equal(quiz.status, 0, quiz.stderr);
  assert.equal(JSON.parse(quiz.stdout).command, null);
  assert.equal(JSON.parse(run(setupData, '/command').stdout).command, null);
});
test('invalid learning preferences fail closed and reset recovers them', () => {
  const setupData = setup();
  const file = join(setupData.root, 'conversation.json');
  writeFileSync(file, JSON.stringify({ mode: 'execute' }), { mode: 0o600 });
  assert.equal(run(setupData, 'question').status, 1);
  assert.equal(run(setupData, '/new').status, 0);
  assert.equal(run(setupData, 'question', { MTU_EXPECT_TEACHING: 'Learning' }).status, 0);
});
test('learner input remains a user message, never trusted application instructions', async () => {
  const prompt = 'UNTRUSTED_LEARNER_INPUT_123';
  assert.match((await ask('separate-input', prompt)).answer, /UNTRUSTED_LEARNER_INPUT_123/);
});
