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
  fun! DimInactiveCallback(tabnr, winnr)
    if gettabwinvar(a:tabnr, a:winnr, '&diff')
      return 0
    endif
    if &buftype != ''
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
  let g:diminactive_use_colorcolumn = 0
endif

" Use ':syntax clear' for inactive buffers?
if !exists('g:diminactive_use_syntax')
  let g:diminactive_use_syntax = 1
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
  echom string(a:000)
endfun
" }}}1

" Functions {{{1

" Setup windows: call s:Enter/s:Leave on all windows.
" With g:diminactive=0, it will call s:Enter on all of them.
fun! s:SetupWindows(...)
  let tabnr = a:0 ? a:1 : tabpagenr()
  call s:Debug('SetupWindows', tabnr, a:0)

  for winnr in range(1, tabpagewinnr(tabnr, '$'))
    if ! s:should_get_dimmed(winnr, tabnr) || winnr == tabpagewinnr(tabnr)
      call s:Enter(winnr, tabnr)
    else
      call s:Leave(winnr, tabnr)
    endif
  endfor
endfun


fun! s:bufnr(...)
  let winnr = a:0 ? a:1 : winnr()
  let tabnr = a:0 > 1 ? a:2 : tabpagenr()
  return get(tabpagebuflist(tabnr), winnr-1)
endfun


fun! s:set_syntax(b, s)
  call s:Debug('set_syntax', a:b, a:s)
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


fun! s:should_get_dimmed(winnr, tabnr)
  let cb_r = 1
  if exists("*DimInactiveCallback")
    let cb_r = DimInactiveCallback(a:tabnr, a:winnr)
    if !cb_r
      call s:Debug('should_get_dimmed: callback returned '.string(cb_r)
            \ .': not dimming', a:tabnr, a:winnr)
      return 0
    endif
  endif

  if ! getbufvar(s:bufnr(a:winnr, a:tabnr), 'diminactive', 1)
    call s:Debug('b:diminactive is false: not dimming', a:tabnr, a:winnr)
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
  let winnr = a:0 ? a:1 : winnr()
  let tabnr = a:0 > 1 ? a:2 : tabpagenr()
  let bufnr = s:bufnr(winnr, tabnr)

  call s:Debug('Enter', tabnr, winnr, bufnr)

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
      if b != bufnr && s:should_get_dimmed(w, tabnr)
        call s:set_syntax(b, 0)
      endif
      let w = w+1
      let checked += [b]
    endfor
  endif
  " Always make sure to activate/reset syntax, e.g. after
  " g:diminactive_use_syntax=0 has been set manually.
  call s:set_syntax(bufnr, 1)


  if ! gettabwinvar(tabnr, winnr, 'diminactive_stored_orig')
    " Nothing to restore (yet).
    return
  endif

  if g:diminactive_use_colorcolumn
    " Set colorcolumn: falls back to "", which is required, when an existing
    " buffer gets opened again in a new window: Vim then uses the last
    " colorcolumn setting (which might come from our s:Leave!)
    let cuc = gettabwinvar(tabnr, winnr, 'diminactive_orig_cuc')
    call s:Debug('Enter: restoring for', tabnr, winnr, cuc)
    call settabwinvar(tabnr, winnr, '&colorcolumn', cuc)
  endif

  " After restoring the original setting, pick up any user changes again.
  call settabwinvar(tabnr, winnr, 'diminactive_stored_orig', 0)
endfun


" Setup 'colorcolumn', 'syntax' etc in the given window.
fun! s:Leave(...)
  let winnr = a:0 ? a:1 : winnr()
  let tabnr = a:0 > 1 ? a:2 : tabpagenr()

  call s:Debug('Leave', tabnr, winnr)

  if get(g:, 'SessionLoad', 0)
    call s:DelegateForSessionLoad()
    return
  endif

  if ! s:should_get_dimmed(winnr, tabnr)
    return
  endif

  " Store original settings, but not on VimResized / until we have
  " entered the buffer again.
  if ! gettabwinvar(tabnr, winnr, 'diminactive_stored_orig')
    if g:diminactive_use_colorcolumn
      let orig_cuc = gettabwinvar(tabnr, winnr, '&colorcolumn')
      call s:Debug('Leave: storing orig setting for', tabnr, winnr)
      call settabwinvar(tabnr, winnr, 'diminactive_orig_cuc', orig_cuc)
    endif

    call settabwinvar(tabnr, winnr, 'diminactive_stored_orig', 1)
  endif

  if g:diminactive_use_colorcolumn
    " NOTE: default return value for `gettabwinvar` requires Vim v7-3-831.
    let cur_cuc = gettabwinvar(tabnr, winnr, '&colorcolumn')

    let wrap = gettabwinvar(tabnr, winnr, '&wrap')
    if wrap
      " HACK: when wrapping lines is enabled, we use the maximum number
      " of columns getting highlighted. This might get calculated by
      " looking for the longest visible line and using a multiple of
      " winwidth().
      let l:width=g:diminactive_max_cols
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
    call settabwinvar(tabnr, winnr, '&colorcolumn', l:range)
  else
    let cur_cuc = 'cuc: skipped'
  endif

  if g:diminactive_use_syntax
      call s:set_syntax(s:bufnr(winnr, tabnr), 0)
  endif

  call s:Debug('Leave: cur_cuc', cur_cuc)
endfun


" Setup autocommands and init dimming.
fun! s:Setup(...)
  if a:0
    let g:diminactive = a:1
  endif
  let init_all_tabs = a:0

  call s:Debug('Setup', g:diminactive, init_all_tabs)

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

  " Init tabs: only the current one by default.
  call s:Debug('Setup: SetupWindows tab loop.')
  let curtab = tabpagenr()

  let tabs = [curtab]
  if init_all_tabs
    " Loop through all tabs (especially with DimInactiveOff).
    " (starting with the current tab)
    let _ = range(1, tabpagenr('$'))
    call remove(_, curtab-1)
    let tabs = [curtab] + _
  endif

  for tab in tabs
    call s:SetupWindows(tab)
  endfor


  " Setup autogroups, after initializing windows.
  augroup DimInactive
    au!
    if g:diminactive
      au WinLeave             * call s:Leave()
      " Using BufWinEnter additionally, because otherwise an existing buffer
      " in a new (tab) window will be dimmed. Somehow the &colorcolumn gets
      " re-used then (Vim 7.4.192).
      " NOTE: previously used BufEnter, but that might be too much / not
      " required.
      au WinEnter,BufWinEnter * call s:Enter()
      au VimResized           * call s:SetupWindows()
    endif
  augroup END
endfun
" }}}1


" Commands {{{1
command! DimInactive          call s:Setup(1)
command! DimInactiveOff       call s:Setup(0)
command! DimInactiveToggle    call s:Setup(!g:diminactive)
command! DimInactiveBufferOff call s:Enter() | let b:diminactive=0
command! DimInactiveBufferOn  call s:Enter() | unlet! b:diminactive
" }}}1

call s:Setup()

" Local settings {{{1
let &cpo = s:save_cpo
" vim: ft=vim sw=2 et:
" }}}1
