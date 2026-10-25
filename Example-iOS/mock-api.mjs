// Local-only deterministic API fixture. Contains no production data or credentials.
import { createServer } from 'node:http'

const tokens = {
  submitted: '11111111-1111-4111-8111-111111111111',
  legacy: '22222222-2222-4222-8222-222222222222',
  saved: '33333333-3333-4333-8333-333333333333',
  older: '44444444-4444-4444-8444-444444444444',
}
const date = '2026-10-25T00:00:00Z'
let stats, threads
function reset() {
  stats = { legacyCalls: 0, lookupCalls: 0, threadReads: 0, replyCalls: 0, submissions: 0, unreadCount: 0 }
  threads = new Map([
    [tokens.legacy, makeThread(tokens.legacy, 'Historical feedback from previous SDK', 'legacy@example.com', true)],
    [tokens.older, makeThread(tokens.older, 'Older historical feedback', 'legacy@example.com', false, '2026-10-24T00:00:00Z')],
    [tokens.saved, makeThread(tokens.saved, 'Saved conversation from previous SDK', 'saved@example.com', true)],
  ])
}
function makeThread(token, message, email, unread, createdAt = date) {
  return { feedback: { id: token, conversation_token: token, name: 'SDK Tester', email, category: 'bug', message,
    metadata: null, reply_count: 1, last_reply_at: date, created_at: createdAt },
    replies: [{ id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', sender_type: 'developer', message: 'Thanks for the report!', created_at: date }], unread }
}
function summary(thread) {
  const f = thread.feedback
  return { id: f.id, conversation_token: f.conversation_token, category: f.category, message: f.message,
    reply_count: f.reply_count, last_reply_at: f.last_reply_at, has_unread_reply: thread.unread, created_at: f.created_at }
}
function data(res, value, status = 200) { res.writeHead(status); res.end(JSON.stringify({ data: value, error: null })) }
function error(res, status, code, message) { res.writeHead(status); res.end(JSON.stringify({ data: null, error: { code, message } })) }
async function body(req) {
  let raw = ''
  for await (const chunk of req) raw += chunk
  try { return JSON.parse(raw) } catch { return null }
}
reset()

createServer(async (req, res) => {
  res.setHeader('Content-Type', 'application/json')
  res.setHeader('Cache-Control', 'no-store')
  const url = new URL(req.url, 'http://127.0.0.1:8766')
  if (url.pathname === '/__qa/reset' && req.method === 'POST') {
    reset(); res.end(JSON.stringify(stats)); return
  }
  if (url.pathname === '/__qa/state') { res.end(JSON.stringify(stats)); return }
  const strict = url.pathname.startsWith('/strict/')
  const path = strict ? url.pathname.slice('/strict'.length) : url.pathname
  if (path.startsWith('/offline')) return error(res, 503, 'UNAVAILABLE', 'Test offline response')
  if (path === '/release-note') {
    res.setHeader('Content-Type', 'text/html')
    res.end('<!doctype html><meta name="viewport" content="width=device-width, initial-scale=1"><style>body{font:17px -apple-system;padding:20px;color:light-dark(#222,#eee);color-scheme:light dark}</style><h2>Built for iPhone and iPad</h2><ul><li>Send feedback with files</li><li>Continue conversations</li><li>Read what changed after an update</li></ul>')
    return
  }
  if (req.headers.authorization !== 'Bearer sp_live_ui_test') return error(res, 401, 'INVALID_API_KEY', 'Test key required')
  if (path === '/api/v1/releases') {
    return data(res, { id: 'release-test', version: url.searchParams.get('version'), content: '- Native feedback on iOS',
      published_at: '2026-10-25', app_name: 'SDK Test App', release_note_url: 'http://127.0.0.1:8766/release-note', releases_url: 'http://127.0.0.1:8766/releases' })
  }
  if (path === '/api/v1/feedback' && req.method === 'POST') {
    const submitted = await body(req)
    if (!submitted?.metadata?.os_version?.startsWith('iOS ') || submitted.message !== 'The feedback form works on iOS.') return error(res, 400, 'TEST_FAILURE', 'Unexpected feedback payload')
    const thread = makeThread(tokens.submitted, submitted.message, submitted.email, true)
    threads.set(tokens.submitted, thread); stats.submissions++
    return data(res, { id: thread.feedback.id, conversation_token: tokens.submitted, category: 'bug', created_at: date }, 201)
  }
  if (path === '/api/v1/conversations' && req.method === 'GET') {
    stats.legacyCalls++
    if (strict) return error(res, 403, 'USER_TOKEN_REQUIRED', 'Legacy migration window closed')
    const matching = [...threads.values()].filter(t => t.feedback.email === url.searchParams.get('email'))
      .sort((a, b) => b.feedback.created_at.localeCompare(a.feedback.created_at))
    const page = Number(url.searchParams.get('page') || 1)
    const selected = matching.slice(page - 1, page)
    return data(res, { conversations: selected.map(summary), total: matching.length, page, per_page: 1 })
  }
  if (path === '/api/v1/conversations/lookup' && req.method === 'POST') {
    stats.lookupCalls++
    const input = await body(req)
    if (!Array.isArray(input?.tokens) || input.tokens.length > 100 || input.email !== undefined) return error(res, 400, 'VALIDATION_ERROR', 'Capabilities required')
    const allowed = [...new Set(input.tokens.map(t => t.toLowerCase()))]
    const items = allowed.flatMap(token => threads.has(token) ? [summary(threads.get(token))] : [])
      .sort((a, b) => b.created_at.localeCompare(a.created_at))
    stats.unreadCount = items.filter(x => x.has_unread_reply).length
    return data(res, { conversations: items, total: items.length, page: 1, per_page: 100 })
  }
  const match = path.match(/^\/api\/v1\/conversations\/([0-9a-f-]{36})(\/reply)?$/)
  if (match) {
    const thread = threads.get(match[1])
    if (!thread) return error(res, 404, 'NOT_FOUND', 'Missing controlled thread')
    if (match[2] === '/reply' && req.method === 'POST') {
      const input = await body(req)
      if (!input?.message?.trim()) return error(res, 400, 'VALIDATION_ERROR', 'A reply is required')
      stats.replyCalls++
      const reply = { id: `user-reply-${stats.replyCalls}`, sender_type: 'user', message: input.message, created_at: date }
      thread.replies.push(reply); thread.feedback.reply_count++
      return data(res, reply, 201)
    }
    if (req.method === 'GET') {
      stats.threadReads++; thread.unread = false
      return data(res, { feedback: thread.feedback, replies: thread.replies })
    }
  }
  error(res, 404, 'NOT_FOUND', 'Unknown controlled fixture route')
}).listen(8766, '127.0.0.1', () => console.log('Local Swift SDK UI fixture ready on 127.0.0.1:8766'))
