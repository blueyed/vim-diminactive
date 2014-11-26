" diminactive.vim - highlight current window by dimming inactive ones.
"
" Author: Daniel Hahler <http://daniel.hahler.de/>
" Source:	https://github.com/blueyed/vim-diminactive
" License: This file is placed in the public domain.

" TODO: hook into window layout changes (e.g. CTRL_W-L) and redraw all windows.
"       Not possible because of lacking autocommand support?!

" Plugin boilerplate {{{1
if exists("g:loaded_diminactive")
  finish
endif
let g:loaded_diminactive = 1

let s:save_cpo = &cpo
set cpo&vim
" }}}1

if !exists('+colorcolumn')
  " TODO: error
endif

" Global configuration variables {{{1
if !exists('g:diminactive')
  let g:diminactive = 1
endif

" State of buffers original &syntax setting.
if !exists('g:diminactive_orig_syntax')
  let g:diminactive_orig_syntax = {}
endif

" Callback to decide if a window should get dimmed. {{{2
" The default disables dimming for &diff windows, and non-normal buffers.
if !exists('g:DimInactiveCallback')
  fun! DimInactiveCallback(tabnr, winnr, bufnr)
    if gettabwinvar(a:tabnr, a:winnr, '&diff')
      return 0
    endif
    if getbufvar(a:bufnr, '&buftype') != ''
          \ && getbufvar(a:bufnr, '&filetype') != 'startify'
      return 0
    endif
    return 1
  endfun
endif

if !exists('g:diminactive_debug')
  let g:diminactive_debug = 0
endif

" Set 'colorcolumn' for inactive buffers?
if !exists('g:diminactive_use_colorcolumn')
  let g:diminactive_use_colorcolumn = 1
endif

" Use ':syntax clear' for inactive buffers?
if !exists('g:diminactive_use_syntax')
  let g:diminactive_use_syntax = 0
endif

" Maximum number of entries in &colorcolumn, when &wrap is enabled.
" NOTE: A maximum of 256 columns can be highlighted (Vim limitation; 7.4.192).
if !exists('g:diminactive_max_cols')
  let g:diminactive_max_cols = 256
endif

" Debug helper {{{2
fun! s:Debug(...)
  if ! g:diminactive_debug
    return
  endif
  if a:0 == 1 && type(a:1) == type("")
    echom 'diminactive: '.a:1
  else
    echom 'diminactive: '.string(a:000)
  endif
endfun
" }}}1

" Functions {{{1

" Setup windows: call s:Enter/s:Leave on all windows.
" With g:diminactive=0, it will call s:Enter on all of them.
fun! s:SetupWindows(...)
  let tabnr = a:0 ? a:1 : tabpagenr()
  call s:Debug('SetupWindows', tabnr, a:0)

  for winnr in range(1, tabpagewinnr(tabnr, '$'))
    if ! s:should_get_dimmed(tabnr, winnr) || winnr == tabpagewinnr(tabnr)
      call s:Enter(tabnr, winnr)
    else
      call s:Leave(tabnr, winnr)
    endif
  endfor
endfun


fun! s:SetupTabs(...)
  " Init tabs: only the current one by default.
  call s:Debug('SetupTabs: SetupWindows tab loop.')
  let curtab = tabpagenr()

  " Loop through all tabs (especially with DimInactiveOff),
  " starting at the current tab.
  let _ = range(1, tabpagenr('$'))
  call remove(_, index(_, curtab))
  let tabs = [curtab] + _

  for tab in tabs
    call s:Debug("LOOP TAB: ".tab)
    call s:SetupWindows(tab)
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
  call s:Debug('set_syntax', 'buf: '.a:b, 'set: '.a:s)
  if a:s
    let orig_syntax = get(g:diminactive_orig_syntax, a:b, '')
    if len(orig_syntax)
      call s:Debug('Restoring orig_syntax', a:b, orig_syntax)
      call setbufvar(a:b, '&syntax', orig_syntax)
      call remove(g:diminactive_orig_syntax, a:b)
    else
      call s:Debug('set_syntax: nothing to restore!', a:b, orig_syntax)
    endif
  else
    let orig_syntax = get(g:diminactive_orig_syntax, a:b, '')
    if orig_syntax
      call s:Debug('set_syntax: off: should be off already!', a:b, orig_syntax)
    else
      let syntax = getbufvar(a:b, '&syntax')
      if syntax != 'off'
        call s:Debug('set_syntax: storing', a:b, syntax)
        let g:diminactive_orig_syntax[a:b] = syntax
        call setbufvar(a:b, '&syntax', 'off')
      else
        call s:Debug('set_syntax: already off!', a:b)
      endif
    endif
  endif
endfun


" Optional 3rd arg: bufnr
fun! s:should_get_dimmed(tabnr, winnr, ...)
  let bufnr = a:0 ? a:1 : s:bufnr(a:tabnr, a:winnr)

  let cb_r = 1
  if exists("*DimInactiveCallback")
    let cb_r = DimInactiveCallback(a:tabnr, a:winnr, bufnr)
    if !cb_r
      call s:Debug('should_get_dimmed: callback returned '.string(cb_r)
            \ .': not dimming', a:tabnr, a:winnr)
      return 0
    endif
  endif

  if ! getbufvar(bufnr, 'diminactive', 1)
    call s:Debug('b:diminactive is false: not dimming', a:tabnr, a:winnr, bufnr)
    return 0
  endif

  if ! gettabwinvar(a:tabnr, a:winnr, 'diminactive', 1)
    call s:Debug('w:diminactive is false: not dimming', a:tabnr, a:winnr)
    return 0
  endif

  return g:diminactive
endfun


fun! s:DelegateForSessionLoad()
  call s:Debug('SessionLoad in effect, postponing setup until SessionLoadPost.')
  augroup DimInactive
    au!
    au SessionLoadPost * call s:Setup()
  augroup END
endfun


" Restore settings in the given window.
fun! s:Enter(...)
  let tabnr = a:0 > 0 ? a:1 : tabpagenr()
  let winnr = a:0 > 1 ? a:2 : winnr()
  let bufnr = a:0 > 2 ? a:3 : s:bufnr(tabnr, winnr)

  call s:Debug('Enter: tab: '.tabnr.', win: '.winnr
        \ .', buf: '.bufnr.' ['.fnamemodify(bufname(bufnr), ':t').']')

  if get(g:, 'SessionLoad', 0)
    call s:DelegateForSessionLoad()
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
      call s:Debug("CHECK", b, w, tabnr, string(checked))
      if b != bufnr && s:should_get_dimmed(tabnr, w, b)
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

  if ! gettabwinvar(tabnr, winnr, 'diminactive_stored_orig')
    let cuc = gettabwinvar(tabnr, winnr, 'diminactive_orig_cuc')
    if ! cuc
      return
    endif

    call s:Debug('Enter: colorcolumn: nothing to restore!')

    " EXPERIMENTAL: store the current setting.
    call s:store_orig_colorcolumn(tabnr, winnr, bufnr)
    " call s:Debug('diminactive_orig_cuc: '.gettabwinvar(tabnr, winnr, 'diminactive_orig_cuc'))
  endif
endfun


" Entering a window.
" This might get called with the previous buffer / window settings (with
" `:sp`), but gets then called again via s:Enter (for BufEnter).
fun! s:EnterWindow(...)
  if g:diminactive_use_colorcolumn
    let tabnr = a:0 > 0 ? a:1 : tabpagenr()
    let winnr = a:0 > 1 ? a:2 : winnr()
    let bufnr = a:0 > 2 ? a:3 : s:bufnr(tabnr, winnr)

    call s:Debug('EnterWindow: tab: '.tabnr.', win: '.winnr.', buf: '.bufnr)
    if !gettabwinvar(tabnr, winnr, 'diminactive_stored_orig')
      call s:Debug('EnterWindow: colorcolumn: nothing to restore!')
    else
      let cuc = gettabwinvar(tabnr, winnr, 'diminactive_orig_cuc')
      if ! cuc
        call s:Debug('EnterWindow: colorcolumn: nothing to restore!')
      else
        " Set colorcolumn: falls back to "", which is required, when an existing
        " buffer gets opened again in a new window: Vim then uses the last
        " colorcolumn setting (which might come from our s:Leave!)
        call s:Debug('EnterWindow: colorcolumn: restoring for tab: '.tabnr.', win: '.winnr.', &cc: '.cuc)
        call settabwinvar(tabnr, winnr, '&colorcolumn', cuc)

        " After restoring the original setting, pick up any user changes again.
        call settabwinvar(tabnr, winnr, 'diminactive_stored_orig', 0)
      endif
    endif
  endif


  " Handle left windows, after handling entering the new window, because
  " it might derive the last set &colorcolumn setting.
  call s:Debug('Handle left window(s)')
  for winnr in range(1, tabpagewinnr(tabnr, '$'))
    if gettabwinvar(tabnr, winnr, 'diminactive_left_window')
      call s:Leave(tabnr, winnr)
      call settabwinvar(tabnr, winnr, 'diminactive_left_window', 0)
    endif
  endfor
endfun


fun! s:store_orig_colorcolumn(tabnr, winnr, bufnr)
  " Store original settings, but not on VimResized / until we have
  " entered the buffer again.
  if gettabwinvar(a:tabnr, a:winnr, 'diminactive_stored_orig')
        \ || ! g:diminactive_use_colorcolumn
    return 0
  endif

  let orig_cuc = gettabwinvar(a:tabnr, a:winnr, '&colorcolumn')
  call s:Debug('colorcolumn: storing orig setting for',
        \ 'tab: '.a:tabnr, 'win: '.a:winnr, 'buf: '.a:bufnr)
  call settabwinvar(a:tabnr, a:winnr, 'diminactive_orig_cuc', orig_cuc)

  " Save it also in a buffer local var to work around Vim applying
  " &colorcolumn (sometimes) to a new window for/from an existing buffer.
  call setbufvar(a:bufnr, 'diminactive_orig_cuc_bufbak', orig_cuc)

  call settabwinvar(a:tabnr, a:winnr, 'diminactive_stored_orig', 1)
  return 1
endfun


" Setup 'colorcolumn', 'syntax' etc in the given window.
fun! s:Leave(...)
  let tabnr = a:0 > 0 ? a:1 : tabpagenr()
  let winnr = a:0 > 1 ? a:2 : winnr()
  let bufnr = a:0 > 2 ? a:3 : s:bufnr(tabnr, winnr)

  call s:Debug('Leave: tab: '.tabnr.', win: '.winnr
        \ .', buf: '.bufnr.' ['.fnamemodify(bufname(bufnr), ':t').']')

  if get(g:, 'SessionLoad', 0)
    call s:DelegateForSessionLoad()
    return
  endif

  if ! s:should_get_dimmed(tabnr, winnr, bufnr)
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
    call s:Debug('Leave: setting colorcolumn.')
    call settabwinvar(tabnr, winnr, '&colorcolumn', l:range)
  else
    call s:Debug('Leave: colorcolumn: skipped/disabled.')
  endif

  if g:diminactive_use_syntax
    call s:set_syntax(bufnr, 0)
  endif
endfun


" Setup autocommands and init dimming.
fun! s:Setup(...)
  call s:Debug('Setup', g:diminactive)

  " Delegate setup to VimEnter event on startup.
  if has('vim_starting')
    call s:Debug('vim_starting: postponing Setup().')
    augroup DimInactive
      au!
      au VimEnter * call s:Setup()
    augroup END
    return
  endif

  " NOTE: we arrive here already with SessionLoad being not set.
  " call s:Debug('SessionLoad', exists('g:SessionLoad'))

  call s:SetupTabs()

  " Setup autogroups, after initializing windows.
  augroup DimInactive
    au!
    if g:diminactive
      " Mark left windows, and handle them in WinEnter, _after_ entering the
      " new one (otherwise &colorcolumn settings might get copied over).
      au WinLeave             * call s:Debug('EVENT: WinLeave')
            \ | let w:diminactive_left_window = 1
      " Using BufWinEnter additionally, because otherwise an existing buffer
      " in a new (tab) window will be dimmed. Somehow the &colorcolumn gets
      " re-used then (Vim 7.4.192).
      " NOTE: previously used BufEnter, but that might be too much / not
      " required.
      au BufEnter   * call s:Debug('EVENT: BufEnter') | call s:Enter()
      au WinEnter   * call s:Debug('EVENT: WinEnter') | call s:EnterWindow()
      au VimResized * call s:Debug('EVENT: VimResized') | call s:SetupWindows()
      au TabEnter   * call s:Debug('EVENT: TabEnter') | call s:SetupWindows()
    endif
  augroup END
endfun
" }}}1


" Commands {{{1
command! DimInactive          let g:diminactive=1  | call s:Setup()
command! DimInactiveOn        DimInactive
command! DimInactiveOff       let g:diminactive=0  | call s:Setup()
command! DimInactiveToggle    let g:diminactive=!g:diminactive | call s:Setup()

command! DimInactiveBufferOff let b:diminactive=0  | call s:Setup()
command! DimInactiveBufferOn  unlet! b:diminactive | call s:Setup()

command! DimInactiveWindowOff let w:diminactive=0  | call s:EnterWindow()
command! DimInactiveWindowOn  unlet! w:diminactive | call s:EnterWindow()
" }}}1

call s:Setup()

" Local settings {{{1
let &cpo = s:save_cpo
" vim: ft=vim sw=2 et:
" }}}1
