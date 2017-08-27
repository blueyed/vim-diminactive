" diminactive.vim - highlight current window by dimming inactive ones.
"
" Author: Daniel Hahler <http://daniel.hahler.de/>
" Source:	https://github.com/blueyed/vim-diminactive
" License: This file is placed in the public domain.

" TODO: hook into window layout changes (e.g. CTRL_W-L) and redraw all windows.
"       Not possible because of lacking autocommand support?!
" NOTE: default return value for `gettabwinvar` requires Vim v7-3-831.

" NOTE: uses 'noautocmd settabwinvar' as workaround for Vim 7.3.429
"       (used on Travis). This might trigger autocommands when used on
"       non-current tab/win. See test "Syntax with new".

" Plugin boilerplate {{{1
if exists('g:loaded_diminactive')
  finish
endif
let g:loaded_diminactive = 1

let s:save_cpo = &cpoptions
set cpoptions&vim
" }}}1

" Global configuration variables {{{1
if !exists('g:diminactive')
  let g:diminactive = has('gui_running') || &t_Co >= 256
endif

" Set 'colorcolumn' for inactive buffers?
if !exists('g:diminactive_use_colorcolumn')
  let g:diminactive_use_colorcolumn = has('gui_running') || &t_Co >= 256
endif

" Use ':syntax clear' for inactive buffers?
if !exists('g:diminactive_use_syntax')
  let g:diminactive_use_syntax = !(exists('+colorcolumn') && (has('gui_running') || &t_Co >= 256))
endif

" Blacklist.
if !exists('g:diminactive_buftype_blacklist')
  let g:diminactive_buftype_blacklist = ['nofile', 'nowrite', 'acwrite', 'quickfix', 'help']
endif
if !exists('g:diminactive_filetype_blacklist')
  let g:diminactive_filetype_blacklist = ['startify']
endif

" Whitelist, overriding blacklist.
if !exists('g:diminactive_buftype_whitelist')
  let g:diminactive_buftype_whitelist = []
endif
if !exists('g:diminactive_filetype_whitelist')
  let g:diminactive_filetype_whitelist = ['dirvish']
endif

" Callback to decide if a window should get dimmed. {{{2
" The default disables dimming for &diff windows, and non-normal buffers.
if !exists('g:DimInactiveCallback')
  fun! DimInactiveCallback(tabnr, winnr, bufnr)
    if gettabwinvar(a:tabnr, a:winnr, '&diff')
      call s:Debug('Not dimming diff window.')
      return 0
    endif
    let bt = getbufvar(a:bufnr, '&buftype')
    let ft = getbufvar(a:bufnr, '&filetype')
    if (index(g:diminactive_buftype_blacklist, bt) != -1
          \ || index(g:diminactive_filetype_blacklist, ft) != -1)
          \ && (index(g:diminactive_buftype_whitelist, bt) == -1
          \     && index(g:diminactive_filetype_whitelist, ft) == -1)
      call s:Debug('Not dimming for buftype='.bt.', filetype='.ft.'.')
      return 0
    endif
    return 1
  endfun
endif

if !exists('g:diminactive_debug')
  let g:diminactive_debug = 0
endif

" Maximum number of entries in &colorcolumn, when &wrap is enabled.
" NOTE: A maximum of 256 columns can be highlighted (Vim limitation; 7.4.192).
if !exists('g:diminactive_max_cols')
  let g:diminactive_max_cols = 256
endif

" Enable dimming inactive window on FocusLost and FocusGained event
" NOTE: If you're using tmux, you should install the 'tmux-plugins/vim-tmux-focus-events'
" plugin for Vim and add 'set -g focus-events on' to your ~/.tmux.conf to enable
" better support for FocusLost/FocusGained events when running Vim inside tmux.
if !exists('g:diminactive_enable_focus')
  let g:diminactive_enable_focus = 0
endif
" }}}1

" Functions {{{1

" Dict of &cc setting per buffer, used when it gets hidden.
let s:buffer_cc = {}

" Debug helper {{{2
let s:counter_bufs=0
let s:counter_wins=0
let s:debug_indent=0
fun! s:Debug(...)
  if ! g:diminactive_debug
    return
  endif

  let winid = -1
  let bufid = -1
  if a:0 > 1
    let idinfo = a:2
    if has_key(idinfo, 'b')
      let bufid = DimInactiveBufId(idinfo['b'])
    end
    if has_key(idinfo, 'w')
      let winid = DimInactiveWinId(idinfo['w'], get(idinfo, 't', -1))
    end
  endif

  let msg ='diminactive: '
  if s:debug_indent > 0
    for _ in range(1, s:debug_indent)
      let msg .= '  '
    endfor
  endif
  if a:0 > 1 && type(a:1) == type([])
    let msg .= string(a:000)
  else
    let msg .= a:1
  endif
  if winid != -1
    let msg .= ' ['.winid.']'
  endif
  if bufid != -1
    let msg .= ' ['.bufid.']'
  endif
  echom msg
endfun
fun! s:DebugIndent(...)
  call call('s:Debug', a:000)
  let s:debug_indent += 1
endfun

let s:buffer_ids = {}
fun! DimInactiveBufId(...)
  let b = a:0 ? a:1 : bufnr('%')
  let bufid = get(s:buffer_ids, b)  " Use a dict, because buffers cannot store a setting when hidden.
  if bufid ==# ''
    let s:counter_bufs+=1
    let bufid = s:counter_bufs
    let s:buffer_ids[b] = bufid
  endif
  return 'b:'.bufid
endfun

" Optional 2nd arg: tabnr (-1 skips it, too).
fun! DimInactiveWinId(...)
  let w = a:0 ? a:1 : winnr()
  if a:0 > 1 && a:2 != -1
    let winid = gettabwinvar(a:1, w, 'diminactive_id')
  else
    let winid = getwinvar(w, 'diminactive_id')
  endif
  if winid ==# ''
    let s:counter_wins+=1
    let winid = s:counter_wins
    if a:0 > 1 && a:2 != -1
      noautocmd call settabwinvar(a:1, w, 'diminactive_id', winid)
    else
      call setwinvar(w, 'diminactive_id', winid)
    endif
  endif
  return 'w:'.winid
endfun

" Setup windows: call s:Enter/s:Leave on all windows.
" With g:diminactive=0, it will call s:Enter on all of them.
fun! s:SetupWindows(...)
  let tabnr = a:0 ? a:1 : tabpagenr()
  let refresh = a:0 > 1 ? a:2 : 0

  call s:Debug('SetupWindows: tab: '.tabnr.', refresh: '.refresh)

  let windows = range(1, tabpagewinnr(tabnr, '$'))
  for winnr in windows
    if ! s:should_get_dimmed(tabnr, winnr) || winnr == tabpagewinnr(tabnr)
      call s:Enter(tabnr, winnr)
    else
      if refresh
        call s:Enter(tabnr, winnr)
      endif
      call s:Leave(tabnr, winnr)
    endif
  endfor
endfun

fun! s:SetupTabs(...)
  let refresh = a:0 ? a:1 : 0
  " Init tabs: only the current one by default.
  call s:Debug('SetupTabs: SetupWindows tab loop.')
  let curtab = tabpagenr()

  " Loop through all tabs (especially with DimInactiveOff),
  " starting at the current tab.
  let _ = range(1, tabpagenr('$'))
  call remove(_, index(_, curtab))
  let tabs = [curtab] + _

  for tab in tabs
    call s:SetupWindows(tab, refresh)
  endfor
endfun

" Might return 0 if the tabpage went away.
fun! s:bufnr(...)
  let tabnr = a:0 > 0 ? a:1 : tabpagenr()
  let winnr = a:0 > 1 ? a:2 : winnr()
  let tabbuflist = tabpagebuflist(tabnr)
  if type(tabbuflist) == type(0)
    return 0
  endif
  return get(tabbuflist, winnr-1)
endfun

fun! s:set_syntax(b, s)
  call s:DebugIndent('set_syntax: set:'.a:s, {'b': a:b})
  let orig_syntax = getbufvar(a:b, '_diminactive_orig_syntax')
  if a:s
    if !empty(orig_syntax)
      call s:Debug('Restoring orig_syntax: '.orig_syntax, {'b': a:b})
      call setbufvar(a:b, '&syntax', orig_syntax)
      call setbufvar(a:b, '_diminactive_orig_syntax', '')
    else
      call s:Debug('set_syntax: nothing to restore!', {'b': a:b})
    endif
  else
    if !empty(orig_syntax)
      call s:Debug('set_syntax: off: should be off already!')
    else
      let syntax = getbufvar(a:b, '&syntax')
      if syntax !=# 'off'
        call s:Debug('set_syntax: storing')
        call setbufvar(a:b, '_diminactive_orig_syntax', syntax)
        call setbufvar(a:b, '&syntax', 'off')
      else
        call s:Debug('set_syntax: already off!')
      endif
    endif
  endif
  let s:debug_indent -= 1
endfun

" Optional 3rd arg: bufnr
" Return: 1 if buffer should get dimmed.
fun! s:should_get_dimmed(tabnr, winnr, ...)
  let bufnr = a:0 ? a:1 : s:bufnr(a:tabnr, a:winnr)

  let cb_r = 1
  if exists('*DimInactiveCallback')
    let cb_r = DimInactiveCallback(a:tabnr, a:winnr, bufnr)
    if !cb_r
      call s:Debug('should not get dimmed: callback returned '.string(cb_r),
            \ {'t':a:tabnr, 'w':a:winnr, 'b':bufnr})
      return 0
    endif
  endif

  let w = gettabwinvar(a:tabnr, a:winnr, 'diminactive')
  if type(w) != type('')
    call s:Debug('Use w:diminactive: '.w,
          \ {'t': a:tabnr, 'w': a:winnr, 'b': bufnr})
    return w
  endif

  " Backwards-compatible for: if !getbufvar(bufnr, 'diminactive', 1)
  let b = getbufvar(bufnr, 'diminactive')
  if type(b) != type('')
    call s:Debug('Use b:diminactive: '.b,
          \ {'t': a:tabnr, 'w': a:winnr, 'b': bufnr})
    return b
  endif

  return g:diminactive
endfun

fun! s:DelegateForSessionLoad()
  call s:Debug('SessionLoad in effect, postponing setup until SessionLoadPost.')
  augroup DimInactive
    autocmd!
    autocmd SessionLoadPost * call s:Setup()
  augroup END
endfun

" Restore settings in the given window.
fun! s:Enter(...)
  let tabnr = a:0 > 0 ? a:1 : tabpagenr()
  let winnr = a:0 > 1 ? a:2 : winnr()
  let bufnr = a:0 > 2 ? a:3 : s:bufnr(tabnr, winnr)

  call s:DebugIndent('Enter', {'t': tabnr, 'w': winnr, 'b': bufnr})

  if get(g:, 'SessionLoad', 0)
    call s:DelegateForSessionLoad()
    let s:debug_indent-=1
    return
  endif

  " Handle syntax on all visible buffers in the current tab.
  " NOTE: tabpagebuflist might have duplicate buffers.
  "       (using uniq would re-order the index (which is the window number))
  if g:diminactive_use_syntax
    let w = 1
    let checked = []
    for b in tabpagebuflist(tabnr)
      if index(checked, b) != -1
        continue
      endif
      if b != bufnr && b != winbufnr('%') && s:should_get_dimmed(tabnr, w, b)
        call s:set_syntax(b, 0)
      endif
      let w = w+1
      let checked += [b]
    endfor
  endif
  " Always make sure to activate/reset syntax, e.g. after
  " g:diminactive_use_syntax=0 has been set manually.
  call s:set_syntax(bufnr, 1)

  " Trigger WinEnter processing for (always) correct buffer in the window.
  call s:EnterWindow(tabnr, winnr)

  let s:debug_indent-=1
endfun

" Entering a window.
" This might get called with the previous buffer / window settings (with
" `:sp`), but gets then called again via s:Enter (for BufEnter).
fun! s:EnterWindow(...)
  let tabnr = a:0 > 0 ? a:1 : tabpagenr()
  let winnr = a:0 > 1 ? a:2 : winnr()
  let bufnr = a:0 > 2 ? a:3 : s:bufnr(tabnr, winnr)

  call s:DebugIndent('EnterWindow', {'t': tabnr, 'w': winnr, 'b': bufnr})

  call s:restore_colorcolumn(tabnr, winnr, bufnr)

  " Handle left windows, after handling entering the new window, because
  " it might derive the last set &colorcolumn setting.
  call s:Debug('Handle left window(s)')
  for w in range(1, tabpagewinnr(tabnr, '$'))
    if gettabwinvar(tabnr, w, 'diminactive_left_window')
      if w != winnr
        call s:Leave(tabnr, w)
      endif
      noautocmd call settabwinvar(tabnr, w, 'diminactive_left_window', 0)
    endif
  endfor
  let s:debug_indent-=1
endfun

fun! s:restore_colorcolumn(tabnr, winnr, bufnr)
  call s:Debug('restore_colorcolumn: winbufnr: '.winbufnr(a:winnr),
        \ {'t': a:tabnr, 'w': a:winnr, 'b': a:bufnr})
  if !gettabwinvar(a:tabnr, a:winnr, 'diminactive_stored_orig')
    if !has_key(s:buffer_cc, a:bufnr)
      call s:Debug('restore_colorcolumn: nothing stored!')
      return
    end
    call s:Debug('restore_colorcolumn: using stored cc from buffer.')
    let cc = s:buffer_cc[a:bufnr]
  else
    let cc = gettabwinvar(a:tabnr, a:winnr, 'diminactive_orig_cc')
  endif

  " Set colorcolumn: falls back to "", which is required, when an existing
  " buffer gets opened again in a new window: Vim then uses the last
  " colorcolumn setting (which might come from our s:Leave!)
  call s:Debug('restore_colorcolumn: '.cc, {'t': a:tabnr, 'w': a:winnr})
  noautocmd call settabwinvar(a:tabnr, a:winnr, '&colorcolumn', cc)

  " After restoring the original setting, pick up any user changes again.
  noautocmd call settabwinvar(a:tabnr, a:winnr, 'diminactive_stored_orig', 0)
  silent! unlet s:buffer_cc[a:bufnr]
endfun

fun! s:store_orig_colorcolumn(tabnr, winnr, bufnr)
  " Store original settings, but not on VimResized / until we have
  " entered the buffer again.
  if ! g:diminactive_use_colorcolumn
    call s:Debug('store_orig_colorcolumn: do not store: deactivated.')
  endif
  let orig_cc = gettabwinvar(a:tabnr, a:winnr, '&colorcolumn')
  let saved_cc = gettabwinvar(a:tabnr, a:winnr, 'diminactive_stored_orig')
  if saved_cc
        " \ || getbufvar(a:bufnr, 'diminactive_stored_orig')
    call s:Debug('store_orig_colorcolumn: do not store. saved: '.saved_cc.'.')
    return 0
  endif

  call s:Debug('store_orig_colorcolumn: &cc: '.orig_cc,
        \ {'t': a:tabnr, 'w': a:winnr, 'b': a:bufnr})
  noautocmd call settabwinvar(a:tabnr, a:winnr, 'diminactive_orig_cc', orig_cc)
  " Save it also for the buffer, which is required for 'new | only | b#'.
  let s:buffer_cc[a:bufnr] = orig_cc

  noautocmd call settabwinvar(a:tabnr, a:winnr, 'diminactive_stored_orig', 1)
  return 1
endfun

" Setup 'colorcolumn', 'syntax' etc in the given window.
fun! s:Leave(...)
  let tabnr = a:0 > 0 ? a:1 : tabpagenr()
  let winnr = a:0 > 1 ? a:2 : winnr()
  let bufnr = a:0 > 2 ? a:3 : s:bufnr(tabnr, winnr)

  call s:DebugIndent('Leave', {'t': tabnr, 'w': winnr, 'b': bufnr})

  if get(g:, 'SessionLoad', 0)
    call s:DelegateForSessionLoad()
    let s:debug_indent-=1
    return
  endif

  if ! s:should_get_dimmed(tabnr, winnr, bufnr)
    let s:debug_indent-=1
    return
  endif

  if g:diminactive_use_colorcolumn
    call s:store_orig_colorcolumn(tabnr, winnr, bufnr)

    let wrap = gettabwinvar(tabnr, winnr, '&wrap')
    if wrap
      " HACK: when wrapping lines is enabled, we use the maximum number
      " of columns getting highlighted. This might get calculated by
      " looking for the longest visible line and using a multiple of
      " winwidth().
      let l:width = g:diminactive_max_cols
    else
      " let l:width=winwidth(winnr)
      " Use window width for number of columns to dim.
      " This is too much with vertical splits, but I assume Vim to be smart
      " enough, so that won't have a negative impact on performance.
      " This has the benefit that window re-arrangement should not cause windows
      " to be not fully dimmed anymore.
      let l:width = &columns
    endif

    " Build &colorcolumn setting.
    let l:range = join(range(1, l:width), ',')
    call s:Debug('Applying colorcolumn')
    noautocmd call settabwinvar(tabnr, winnr, '&colorcolumn', l:range)
  else
    call s:Debug('Leave: colorcolumn: skipped/disabled.')
  endif

  if g:diminactive_use_syntax && bufnr != winbufnr('%')
    call s:set_syntax(bufnr, 0)
  endif
  let s:debug_indent-=1
endfun

" Setup autocommands and init dimming.
fun! s:Setup(...)
  let refresh = a:0 ? a:1 : 0

  call s:DebugIndent('Setup: g:diminactive: '.g:diminactive.', refresh:'.refresh)

  " Delegate setup to VimEnter event on startup.
  if has('vim_starting')
    call s:Debug('vim_starting: postponing Setup().')
    augroup DimInactive
      autocmd!
      exec 'autocmd VimEnter * call s:Setup('.refresh.')'
    augroup END
    let s:debug_indent-=1
    return
  endif

  " NOTE: we arrive here already with SessionLoad being not set.
  " call s:Debug('SessionLoad', exists('g:SessionLoad'))

  call s:SetupTabs(refresh)

  " Setup autogroups, after initializing windows.
  augroup DimInactive
    autocmd!
    if g:diminactive
      " Mark left windows, and handle them in WinEnter, _after_ entering the
      " new one (otherwise &colorcolumn settings might get copied over).
      autocmd WinLeave   * call s:Debug('EVENT: WinLeave', {'w': winnr()})
            \ | let w:diminactive_left_window = 1
      autocmd BufEnter   * call s:Debug('EVENT: BufEnter', {'b': bufnr('%')})
            \ | call s:Enter()
      autocmd WinEnter   * call s:Debug('EVENT: WinEnter', {'w': winnr()})
            \ | call s:EnterWindow()
      autocmd VimResized * call s:Debug('EVENT: VimResized')
            \ | call s:SetupWindows()
      autocmd TabEnter   * call s:Debug('EVENT: TabEnter')
            \ | call s:SetupWindows()

      if g:diminactive_enable_focus
        autocmd FocusGained * call s:Debug('EVENT: FocusGained', {'b': bufnr('%')}) | call s:Enter()
        autocmd FocusLost   * call s:Debug('EVENT: FocusLost', {'b': bufnr('%')})   | call s:Leave()
      endif
    endif
  augroup END
  let s:debug_indent-=1
endfun
" }}}1

" Commands {{{1
command! DimInactive          let g:diminactive=1  | call s:Setup()
command! DimInactiveOn        DimInactive
command! DimInactiveOff       let g:diminactive=0  | call s:Setup()
command! DimInactiveToggle    let g:diminactive=!g:diminactive | call s:Setup()

command! DimInactiveBufferOff let b:diminactive=0  | call s:Setup()
command! DimInactiveBufferOn  let b:diminactive=1 | call s:Setup()
command! DimInactiveBufferReset silent! unlet b:diminactive | call s:Setup()

command! DimInactiveWindowOff let w:diminactive=0  | call s:EnterWindow()
command! DimInactiveWindowOn  let w:diminactive=1 | call s:EnterWindow()
command! DimInactiveWindowReset silent! unlet w:diminactive | call s:Setup()

command! DimInactiveSyntaxOn  let g:diminactive_use_syntax=1 | call s:Setup(1)
command! DimInactiveSyntaxOff let g:diminactive_use_syntax=0 | call s:Setup(1)

command! DimInactiveColorcolumnOn  let g:diminactive_use_colorcolumn=1 | call s:Setup(1)
command! DimInactiveColorcolumnOff let g:diminactive_use_colorcolumn=0 | call s:Setup(1)
" }}}1

call s:Setup()

" Local settings {{{1
let &cpoptions = s:save_cpo
" vim: ft=vim sw=2 et:
" }}}1
