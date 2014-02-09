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
" }}}1

" Functions {{{1

" Setup windows: call s:Enter/s:Leave on all windows.
" With g:diminactive=0, it will call s:Enter on all of them.
fun! s:SetupWindows(...)
  for i in range(1, tabpagewinnr(tabpagenr(), '$'))
    if !g:diminactive || i == winnr()
      call s:Enter(i)
    else
      call s:Leave(i)
    endif
  endfor
endfun

" Reset 'colorcolumn' in the given window.
fun! s:Enter(...)
  let winnr = a:0 ? a:1 : winnr()
  call setwinvar(winnr, '&colorcolumn', '')
endfun

" Setup 'colorcolumn' in the given window.
fun! s:Leave(...)
  let winnr = a:0 ? a:1 : winnr()
  if getwinvar(winnr, '&colorcolumn', '') != ''
    " Dimmed already.
    return
  endif
  let l:range = ""
  let wrap = getwinvar(winnr, '&wrap')
  if wrap
    " HACK: when wrapping lines is enabled, we use the maximum number
    " of columns getting highlighted. This might get calculated by
    " looking for the longest visible line and using a multiple of
    " winwidth().
    let l:width=256 " max
  else
    let l:width=winwidth(winnr)
  endif
  let l:range = join(range(1, l:width), ',')
  call setwinvar(winnr, '&colorcolumn', l:range)
endfun

" Setup autocommands and init dimming.
fun! s:Setup(...)
  if a:0
    let g:diminactive = a:1
  endif
  augroup DimInactive
    au!
    if g:diminactive
      au WinLeave * call s:Leave()
      " NOTES: WinEnter is not triggered for a second ':h foo'
      au WinEnter,BufEnter * call s:Enter()
    endif
    " Delegate window setup to VimEnter event on startup.
    if has('vim_starting')
      au VimEnter * call s:SetupWindows()
    else
      call s:SetupWindows()
    endif
  augroup END
endfun
" }}}1

" Commands {{{1
command! DimInactive        call s:Setup(1)
command! DimInactiveOff     call s:Setup(0)
command! DimInactiveToggle  call s:Setup(!g:diminactive)

" Useful/necessary after window layout (width) changed.
command! DimInactiveRefresh call s:SetupWindows()
" }}}1

call s:Setup()

" Local settings {{{1
let &cpo = s:save_cpo
" vim: ft=vim sw=2 et:
" }}}1
