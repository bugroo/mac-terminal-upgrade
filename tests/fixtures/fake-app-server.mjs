#!/usr/bin/env node
// Protocol fixture: no network, credentials, shell commands, or user files.
import { createInterface } from 'node:readline';
if (process.argv.includes('--version')) {
  console.log(`codex-cli ${process.env.MTU_FAKE_VERSION || '0.153.2'}`);
  process.exit(0);
}
const mode = process.env.MTU_FAKE_MODE || 'success';
let currentInstructions = '';
const send = value => process.stdout.write(`${JSON.stringify(value)}\n`);
const reader = createInterface({ input: process.stdin });
reader.on('line', line => {
  const message = JSON.parse(line);
  if (!message.id) return;
  if (mode === 'hang') return;
  if (mode === 'malformed') { process.stdout.write('not json\n'); return; }
  if (mode === 'exit') { process.exit(1); }
  if (message.method === 'initialize') {
    if (mode === 'error') { send({ id: message.id, error: { message: 'Invalid configuration' } }); return; }
    send({ id: message.id, result: {} });
  } else if (message.method === 'thread/start' || message.method === 'thread/resume') {
    if (message.params.environments.length !== 0 || message.params.approvalPolicy !== 'never' || message.params.sandbox !== 'read-only' || Object.keys(message.params.config.mcp_servers).length) process.exit(8);
    if (message.params.config.features.shell_tool !== false || message.params.config.features.hooks !== false) process.exit(9);
    if (mode === 'require-resume' && message.method !== 'thread/resume') process.exit(10);
    send({ id: message.id, result: { thread: { id: 'test-thread' }, sandbox: { type: 'readOnly' }, approvalPolicy: 'never' } });
  } else if (message.method === 'thread/inject_items') {
    if (mode === 'inject-error') { send({ id: message.id, error: { message: 'Unsupported instruction injection' } }); return; }
    const item = message.params.items[0];
    if (item.role !== 'developer' || item.type !== 'message' || item.content[0].type !== 'input_text') process.exit(11);
    currentInstructions = item.content[0].text;
    if (process.env.MTU_EXPECT_TEACHING && !currentInstructions.includes(`${process.env.MTU_EXPECT_TEACHING} mode is active`)) process.exit(12);
    if (mode === 'quiz' && !currentInstructions.includes('Ask exactly ONE recall question')) process.exit(13);
    send({ id: message.id, result: {} });
  } else if (message.method === 'turn/start') {
    if (!currentInstructions.startsWith('Current interaction settings for the next response only.')) process.exit(14);
    const prompt = message.params.input[0].text;
    if (mode === 'separate-input' && currentInstructions.includes(prompt)) process.exit(15);
    if (prompt === 'cancel-me') return;
    send({ id: message.id, result: { turn: { id: 'test-turn' } } });
    const params = { threadId: 'test-thread', turnId: 'test-turn' };
    if (mode === 'approval') {
      send({ method: 'item/commandExecution/requestApproval', id: 99, params }); return;
    }
    if (mode === 'tool') {
      send({ method: 'item/started', params: { ...params, item: { type: 'commandExecution' } } }); return;
    }
    let answer = { answer: `Test answer: ${prompt}`, command: null };
    if (prompt === 'suggest') answer = { answer: 'This prints a harmless marker.', command: "printf 'MTU_EXECUTED_MARKER\\n'" };
    if (mode === 'invalid-answer') answer = { answer: 'Invalid', command: ['ls'] };
    if (mode === 'escape') answer = { answer: '\x1b]52;c;fake\x07Visible answer\x1b[31m', command: 'ls\nwhoami' };
    if (mode === 'quiz') answer = { answer: 'What command would you use? Reply with # followed by your attempt.', command: 'touch answer.txt' };
    send({ method: 'item/completed', params: { ...params, item: { type: 'agentMessage', text: JSON.stringify(answer) } } });
    send({ method: 'turn/completed', params: { threadId: 'test-thread', turn: { id: 'test-turn', status: 'completed' } } });
  }
});
