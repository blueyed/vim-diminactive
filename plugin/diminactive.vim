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

" Callback to decide if a window should get dimmed. {{{2
" The default disables dimming for &diff windows.
if !exists('g:DimInactiveCallback')
  fun! DimInactiveCallback(tabnr, winnr)
    if gettabwinvar(a:tabnr, a:winnr, '&diff')
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
  call s:Debug('SetupWindows')
  for i in range(1, tabpagewinnr(tabnr, '$'))
    if !g:diminactive || i == winnr()
      call s:Enter(i, tabnr)
    else
      call s:Leave(i, tabnr)
    endif
  endfor
endfun

" Restore 'colorcolumn' in the given window.
fun! s:Enter(...)
  let winnr = a:0 ? a:1 : winnr()
  let tabnr = a:0 > 1 ? a:2 : tabpagenr()

  " Set colorcolumn: falls back to "", which is required, when an existing
  " buffer gets opened again in a new window: Vim then uses the last
  " colorcolumn setting (which might come from our s:Leave!)
  let cuc = gettabwinvar(tabnr, winnr, 'diminactive_orig_cuc')
  call s:Debug('Enter: restoring for', tabnr, winnr, cuc)
  call settabwinvar(tabnr, winnr, '&colorcolumn', cuc)
  " After restoring the original setting, pick up any user changes again.
  call settabwinvar(tabnr, winnr, 'diminactive_stored_orig', 0)
endfun

" Setup 'colorcolumn' in the given window.
fun! s:Leave(...)
  let winnr = a:0 ? a:1 : winnr()
  let tabnr = a:0 > 1 ? a:2 : tabpagenr()

  let cb_r = 1
  if exists("*DimInactiveCallback")
    let cb_r = DimInactiveCallback(tabnr, winnr)
    if !cb_r
      call s:Debug('Callback returned '.string(cb_r).': not dimming', tabnr, winnr)
      return
    endif
  endif

  " Store original &colorcolumn setting, but not on VimResized / until we have
  " entered the buffer again.
  if ! gettabwinvar(tabnr, winnr, 'diminactive_stored_orig')
    let orig_cuc = gettabwinvar(tabnr, winnr, '&colorcolumn')
    call s:Debug('Leave: storing orig setting for', tabnr, winnr)
    call settabwinvar(tabnr, winnr, 'diminactive_orig_cuc', orig_cuc)
    call settabwinvar(tabnr, winnr, 'diminactive_stored_orig', 1)
  endif

  " NOTE: default return value for `gettabwinvar` requires Vim v7-3-831.
  let cur_cuc = gettabwinvar(tabnr, winnr, '&colorcolumn')

  call s:Debug('Leave', tabnr, winnr, cur_cuc)

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
  call s:Debug('Dimming', tabnr, winnr)
  call settabwinvar(tabnr, winnr, '&colorcolumn', l:range)
endfun

" Setup autocommands and init dimming.
fun! s:Setup(...)
  if a:0
    let g:diminactive = a:1
  endif
  " Delegate window setup to VimEnter event on startup.
  if has('vim_starting')
    au VimEnter * call s:Setup()
    return
  endif

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

    " Loop through all tabs (especially with DimInactiveOff).
    " (starting with the current tab)
    let mytab = tabpagenr()
    for tab in [mytab] + range(1,tabpagenr('$'))
      call s:SetupWindows(tab)
    endfor
  augroup END
endfun
" }}}1

" Commands {{{1
command! DimInactive        call s:Setup(1)
command! DimInactiveOff     call s:Setup(0)
command! DimInactiveToggle  call s:Setup(!g:diminactive)
" }}}1

call s:Setup()

" Local settings {{{1
let &cpo = s:save_cpo
" vim: ft=vim sw=2 et:
" }}}1
