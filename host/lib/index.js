/**
 * dsh-screen-agent - Host plugin
 * Registers POST /api/screen for desktop/web UI automation.
 * Body: { op: 'capture'|'ocr'|'click'|'double'|'right'|'drag'|'type'|'key'|'activate', ... } -> JSON
 *   capture         -> { ok, path, base64 }          (full-screen PNG; path for OCR/agent)
 *   ocr {path?}     -> { ok, lines: [{x,y,text}] }  (Windows OCR: text + pixel coords)
 *   click/double/right {x, y}     -> { ok }
 *   drag {x1,y1,x2,y2}            -> { ok }
 *   type {text}                   -> { ok }  (clipboard + Ctrl+V, Chinese-safe)
 *   key {keys}                    -> { ok }  (SendKeys syntax)
 *   activate {title}              -> { ok, window? }
 * Backed by PowerShell scripts (Windows user32 / System.Drawing / WinRT OCR), no native deps.
 */
import { spawn } from 'node:child_process'
import { mkdirSync, readFileSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import os from 'node:os'

const name = 'screen-agent'
/** Services required before routes can be registered. */
const inject = ['webServer']

const scriptsDir = fileURLToPath(new URL('./scripts/', import.meta.url))
const shotDir = path.join(os.homedir(), '.dsh', 'screenshots')

/** Run a PowerShell script file with args; resolves stdout text (or throws on exit != 0). */
function runPs(script, args) {
  return new Promise((resolve, reject) => {
    const ps = spawn(
      'powershell.exe',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', path.join(scriptsDir, script), ...args],
      { windowsHide: true }
    )
    let out = ''
    let err = ''
    ps.stdout.on('data', (c) => { out += c })
    ps.stderr.on('data', (c) => { err += c })
    ps.on('error', (e) => reject(e))
    ps.on('close', (code) => {
      if (code !== 0) reject(new Error(`ps ${script} exit ${code}: ${err}`))
      else resolve(out.trim())
    })
  })
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = ''
    req.on('data', (c) => { data += c })
    req.on('end', () => {
      try { resolve(JSON.parse(data || '{}')) } catch (e) { reject(e) }
    })
    req.on('error', reject)
  })
}

function send(res, obj) {
  res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' })
  res.end(JSON.stringify(obj))
}

function num(v) { return typeof v === 'number' && Number.isFinite(v) ? Math.round(v) : NaN }

export function apply(ctx) {
  const webServer = ctx.webServer

  async function handleCapture(res) {
    try {
      if (!existsSync(shotDir)) mkdirSync(shotDir, { recursive: true })
      const ts = new Date().toISOString().replace(/[:.]/g, '-')
      const file = path.join(shotDir, `shot-${ts}.png`)
      await runPs('capture.ps1', [file])
      const b64 = readFileSync(file).toString('base64')
      send(res, { ok: true, path: file, base64: b64 })
    } catch (e) {
      send(res, { error: String((e && e.message) || e) })
    }
  }

  return webServer.register({
    kind: 'exact',
    path: '/api/screen',
    handler: async (req, res) => {
      try {
        const b = await readBody(req)
        const op = b.op
        if (op === 'capture') return await handleCapture(res)

        if (op === 'ocr') {
          const p = String(b.path ?? '')
          if (!p) { send(res, { error: 'need path' }); return }
          const out = await runPs('ocr.ps1', [p, String(b.lang || 'zh-CN')])
          const lines = []
          for (const ln of out.split(/\r?\n/)) {
            const m = ln.match(/^(-?\d+)\|(-?\d+)\|(.*)$/)
            if (m) lines.push({ x: Number(m[1]), y: Number(m[2]), text: m[3] })
          }
          return send(res, { ok: true, lines })
        }

        if (op === 'click' || op === 'double' || op === 'right') {
          const x = num(b.x), y = num(b.y)
          if (Number.isNaN(x) || Number.isNaN(y)) { send(res, { error: 'need numeric x,y' }); return }
          await runPs('mouse.ps1', [op, String(x), String(y), '0', '0'])
          return send(res, { ok: true, op })
        }
        if (op === 'drag') {
          const x1 = num(b.x1), y1 = num(b.y1), x2 = num(b.x2), y2 = num(b.y2)
          if ([x1, y1, x2, y2].some(Number.isNaN)) { send(res, { error: 'need numeric x1,y1,x2,y2' }); return }
          await runPs('mouse.ps1', ['drag', String(x1), String(y1), String(x2), String(y2)])
          return send(res, { ok: true, op: 'drag' })
        }
        if (op === 'type') {
          const text = String(b.text ?? '')
          if (!text) { send(res, { error: 'empty text' }); return }
          await runPs('type.ps1', [text])
          return send(res, { ok: true, op: 'type', len: text.length })
        }
        if (op === 'key') {
          const keys = String(b.keys ?? '')
          if (!keys) { send(res, { error: 'empty keys' }); return }
          await runPs('key.ps1', [keys])
          return send(res, { ok: true, op: 'key' })
        }
        if (op === 'activate') {
          const title = String(b.title ?? '')
          if (!title) { send(res, { error: 'empty title' }); return }
          const out = await runPs('activate.ps1', [title])
          const ok = out.startsWith('ok:')
          return send(res, ok ? { ok: true, op: 'activate', window: out.slice(3) } : { ok: false, error: '窗口未找到: ' + title })
        }
        send(res, { error: 'unknown op: ' + op })
      } catch (e) {
        send(res, { error: String((e && e.message) || e) })
      }
    }
  })
}

export { name, inject }
