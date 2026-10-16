// Local-only API fixture for simulator UI tests. It never contacts StorePal production.
import { createServer } from 'node:http'
const feedback = { id: 'feedback-test', name: 'SDK Tester', email: 'sdk-test@example.com', category: 'bug', message: 'The feedback form works on iOS.', metadata: null, reply_count: 1, last_reply_at: null, created_at: '2026-10-16T00:00:00Z' }
const reply = { id: 'reply-test', sender_type: 'developer', message: 'Thanks for the report!', created_at: '2026-10-16T00:00:00Z' }
let replies = [reply]
createServer(async (req, res) => {
  const url = new URL(req.url, 'http://127.0.0.1:8766')
  res.setHeader('Content-Type', 'application/json')
  if (url.pathname.startsWith('/offline')) {
    res.writeHead(503)
    res.end(JSON.stringify({ data: null, error: { code: 'UNAVAILABLE', message: 'Test offline response' } }))
    return
  }
  let data
  if (url.pathname === '/api/v1/releases') {
    data = { id: 'release-test', version: url.searchParams.get('version'), content: '- Native feedback on iOS', published_at: '2026-10-16', app_name: 'SDK Test App', release_note_url: 'http://127.0.0.1:8766/release-note', releases_url: 'http://127.0.0.1:8766/releases' }
  } else if (url.pathname === '/api/v1/feedback') {
    let raw = ''
    for await (const chunk of req) raw += chunk
    const body = JSON.parse(raw)
    if (!body.metadata?.os_version?.startsWith('iOS ') || body.message !== feedback.message) {
      res.writeHead(400); res.end(JSON.stringify({ data: null, error: { code: 'TEST_FAILURE', message: 'Unexpected feedback payload' } })); return
    }
    replies = [reply]
    data = { id: feedback.id, conversation_token: 'test-token', category: 'bug', created_at: feedback.created_at }
  } else if (url.pathname === '/api/v1/conversations') {
    data = { conversations: [{ ...feedback, conversation_token: 'test-token', has_unread_reply: true }], total: 1, page: 1, per_page: 20 }
  } else if (url.pathname === '/api/v1/conversations/test-token/reply') {
    let raw = ''
    for await (const chunk of req) raw += chunk
    const body = JSON.parse(raw)
    data = { ...reply, id: `user-reply-${replies.length}`, sender_type: 'user', message: body.message }
    replies.push(data)
  } else if (url.pathname === '/api/v1/conversations/test-token') {
    data = { feedback, replies }
  } else if (url.pathname === '/release-note') {
    res.setHeader('Content-Type', 'text/html')
    res.end('<!doctype html><meta name="viewport" content="width=device-width, initial-scale=1"><style>body{font:17px -apple-system;padding:20px;color:light-dark(#222,#eee);color-scheme:light dark}</style><h2>Built for iPhone and iPad</h2><ul><li>Send feedback with files</li><li>Continue conversations</li><li>Read what changed after an update</li></ul>')
    return
  } else { res.writeHead(404); res.end('{}'); return }
  res.end(JSON.stringify({ data, error: null }))
}).listen(8766, '127.0.0.1', () => console.log('Local SDK fixture ready on port 8766'))
