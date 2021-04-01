let s:stat = {}
let s:stat.win_id = snatch#status#new(0)
let s:stat.insert_pos = snatch#status#new([])
let s:stat.prev_mode = snatch#status#new('NONE')
let s:stat.snatch_by = snatch#status#new([])
let s:stat.is_sneaking = snatch#status#new(v:false)

augroup snatch/watch
  " For the simplicity, keep `is_sneaking` managed within this augroup.

  autocmd!
  autocmd User SnatchStartPost call s:stat.is_sneaking.set(v:true)
  autocmd User SnatchStopPost  call s:stat.is_sneaking.set(v:false)

  autocmd User SnatchCancelledPost  call s:stat.is_sneaking.set(v:false)
augroup END

function! s:save_state(config) abort
  call s:stat.win_id.set(win_getid())
  call s:stat.prev_mode.set(a:config.prev_mode)
  call s:stat.snatch_by.set(a:config.snatch_by)
endfunction

function! snatch#common#prepare(config) abort
  doautocmd User SnatchStartPre

  call s:save_state(a:config)

  const pre_keys = a:config.pre_keys
  if pre_keys !=# ''
    exe 'norm!' pre_keys
  endif
endfunction

function! s:parse_snatch_events() abort
  const snatch_by = deepcopy(s:stat.snatch_by.get())
  let s:use_register = index(snatch_by, 'register') >= 0
  let s:recursive_motion = index(snatch_by, 'any_motion') >= 0 ? 'none'
        \ : index(snatch_by, 'horizontal_motion') >= 0 ? 'vertical'
        \ : 'any'
endfunction

function! snatch#common#wait() abort
  call s:parse_snatch_events()

  if s:recursive_motion !=# 'any'
    call snatch#motion#wait()
  endif

  if s:use_register
    call snatch#register#wait()
  endif

  if g:snatch#timeoutlen > -1
    const callback = 'snatch#common#cancel'
    call timer_start(g:snatch#timeoutlen, callback)
  endif
  doautocmd User SnatchStartPost
endfunction

function! snatch#common#stop() abort
  " for key in keys(s:stat)
  "   call s:stat[key].reset()
  " endfor
  call snatch#augroup#clear()
endfunction

function! snatch#common#abort(...) abort
  if !s:stat.is_sneaking.get()
    return v:false
  endif

  doautocmd User SnatchAbortedPre
  call snatch#common#stop()
  doautocmd User SnatchAbortedPost
  return v:true
endfunction

function! snatch#common#cancel(...) abort
  if !s:stat.is_sneaking.get()
    return v:false
  endif

  if s:stat.prev_mode ==# 'insert'
    doautocmd User SnatchCancelledPre
    call snatch#common#stop()
    call snatch#ins#restore_pos()
  elseif s:stat.prev_mode ==# 'cmdline'
    doautocmd User SnatchCancelledPre
    call snatch#common#stop()
    call snatch#cmd#restore_pos()
  else
    call snatch#utils#throw('the previous mode cannot be identified')
  endif

  doautocmd User SnatchCancelledPost
  return v:true
endfunction

function! snatch#common#insert(chars) abort
  doautocmd User SnatchStopPre

  const prev_mode = s:stat.prev_mode.get()
  if prev_mode ==? 'insert'
    call snatch#ins#insert(a:chars)
  elseif prev_mode ==? 'cmdline'
    call snatch#cmd#insert(a:chars)
  else
    call snatch#utils#throw('unexpected usage')
  endif

  call snatch#common#stop()
  doautocmd User SnatchStopPost
endfunction

function! snatch#common#status() abort
  let stat = {}
  for key in keys(s:stat)
    let val = s:stat[key].get()
    let stat[key] = val
  endfor
  return stat
endfunction