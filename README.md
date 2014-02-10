# diminactive.vim

This is a simple plugin for Vim to dim inactive windows.

It works by setting `colorcolumn` to a list containing every column for
inactive windows, effectively resulting in another background color
(using `hl-CursorColumn`).

It is based on an [idea from Paul Isambert][1], which got turned into a
[StackOverflow answer][2] and then into a plugin, incorporating the
suggestions made by joeytwiddle.

![Screenshot](screenshot.png)

## Caveats
* It tends to slow down redrawing of windows.
* It will only work with lines containing text (i.e. not `~` (non-lines)).

[1]: https://groups.google.com/d/msg/vim_use/IJU-Vk-QLJE/xz4hjPjCRBUJ
[2]: http://stackoverflow.com/a/12519572/15690

## Related plugins

* The [cursorcross.vim](https://github.com/mtth/cursorcross.vim) provides
automatic and "refreshingly sane `cursorcolumn` and `cursorline` handling".
* The [ZoomWin](http://drchip.org/astronaut/vim/index.html#ZOOMWIN) allows to
  (un-)maximize the current window.
