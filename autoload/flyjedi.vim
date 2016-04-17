let s:pyserver = expand('<sfile>:p:h:h') . '/flyjedi'
let s:handlers = []

function! flyjedi#set_root(fname) abort
  let file = findfile(a:fname, escape(expand('<afile>:p:h'), ' ') . ';')
  if l:file != ''
    let b:flyjedi_root_dir = substitute(l:file, '/setup.py$', '', 'g' )
  endif
endfunction

function! flyjedi#is_running() abort
  if exists('s:port')
    return v:true
  else
    return v:false
  endif
endfunction

function! s:setup_channel() abort
  let ch = ch_open('localhost:' . s:port, {'mode': 'json', 'waittime': 3})
  let st = ch_status(ch)
  if st !=# 'open'
    echoerr 'channel error: ' . st
  endif
  return ch
endfunction

function! s:init_msg() abort
  let msg = {}
  let msg.line = line('.')
  let msg.col = col('.')
  let msg.text = getline(0, '$')
  let msg.path = expand('%:p')
  let msg.root = get(b:, 'flyjedi_root_dir')
  return msg
endfunction

function! s:send(ch, msg, ...) abort
  if a:0 > 0
    let cb = a:1
  else
    let cb = {}
  endif
  call ch_sendexpr(a:ch, a:msg, cb)
  call s:ch_clear()
  let s:handlers = [a:ch]
endfunction

function! flyjedi#complete_cb(ch, msg) abort
  call ch_close(a:ch)
  if mode() ==# 'i' && expand('%:p') ==# a:msg[2]
    call complete(a:msg[0], a:msg[1])
  endif
  let ind = index(s:handlers, a:ch)
  if ind >= 0
    call remove(s:handlers, ind)
  endif
endfunction

function! s:complete() abort
  if flyjedi#is_running()
    let ch = s:setup_channel()
    let msg = s:init_msg()
    let msg['mode'] = 'completion'
    let msg.detail = get(b:, 'flyjedi_detail_info', get(g:, 'flyjedi_detail_info'))
    let msg.fuzzy = get(b:, 'flyjedi_fuzzy_match', get(g:, 'flyjedi_fuzzy_match'))
    let msg.icase = get(b:, 'flyjedi_ignore_case', get(g:, 'flyjedi_ignore_case'))
    call s:send(ch, msg, {'callback': 'flyjedi#complete_cb'})
  endif
  return ''
endfunction

function! flyjedi#complete() abort
  call s:complete()
  return ''
endfunction

" goto is not implemented
function! flyjedi#goto_assignments_cb(ch, msg) abort
  call ch_close(a:ch)
endfunction

" goto is not implemented
function! flyjedi#goto_assignments() abort
  if flyjedi#is_running()
    let ch = s:setup_channel()
    let msg = s:init_msg()
    let msg['mode'] = 'goto_assignments'
    call s:send(ch, msg, {'callback': 'flyjedi#goto_assignments_cb'})
  endif
endfunction

function! flyjedi#clear_cache() abort
  if flyjedi#is_running()
    let ch = ch_open('localhost:' . s:port, {'mode': 'json'})
    let st = ch_status(ch)
    if st ==# 'open'
      let msg = {'clear_cache':1}
      call ch_sendexpr(ch, msg)
    else
      echomsg 'channel error: ' . st
    endif
  endif
  return ''
endfunction

function! s:ch_clear() abort
  for ch in s:handlers
    if ch_status(ch) ==# 'open'
      call ch_close(ch)
    endif
  endfor
endfunction

function! flyjedi#server_started(ch, msg) abort
  if a:msg =~ '\m^\d\+$'
    let s:port = str2nr(a:msg)
  elseif a:msg == '' || a:msg ==# 'DETACH'
    return
  else
    echomsg 'FlyJediServer message: ' . string(a:msg)
  endif
endfunction

function! flyjedi#wrap_ce(s) abort
  return "\<C-e>" . a:s
endfunction

let s:closepum=' <C-r>=pumvisible()?flyjedi#wrap_ce("'
function! s:map(s) abort
  let cmd = 'inoremap <buffer><silent> ' . a:s . s:closepum . a:s . '"):"' . a:s . '"<CR>'
  execute cmd
endfunction

function! flyjedi#mapping() abort
  for k in split('abcdefghijklmnopqrstuvwxyz', '\zs')
    call s:map(k)
    call s:map(toupper(k))
  endfor
  for k in split('123456789', '\zs')
    call s:map(k)
  endfor
  call s:map('_')
  call s:map('@')
  call s:map('\<BS>')
  call s:map('\<C-h>')
endfunction

function! flyjedi#start_server() abort
  let ch = ch_open('localhost:8891', {'waittime': 10})
  if ch_status(ch) ==# 'open'
    " for debug
    let s:port = 8891
    echomsg 'flyjedi: use debug server at localhost:8891'
    call ch_close(ch)
  else
    let cmd = ['python3', s:pyserver]
    let s:server = job_start(cmd, {'callback': 'flyjedi#server_started'})
  endif
endfunction
