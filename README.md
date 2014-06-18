# diminactive.vim

This is a plugin for Vim to dim inactive windows.

## Methods

It provides two methods, which can be used independent:

### The `colorcolumn` method

With this method `colorcolumn` gets set to a list containing every column for
the inactive windows, effectively resulting in a different background color
(see `hl-CursorColumn`).

This is enabled by default and can be disabled, e.g. if you want to use the
syntax method only:

    let g:diminactive_use_colorcolumn = 0

### The `syntax` method

There is an option to disable syntax highlighting for inactive windows. It is
disabled by default, and you can enable it using:

    let g:diminactive_use_syntax = 1

## Credits

It is based on an [idea from Paul Isambert][1], which got turned into a
[StackOverflow answer][2] and then into a plugin, incorporating the
suggestions made by joeytwiddle.

![Screenshot](screenshot.png)

## Caveats
* It might slow down redrawing of windows.
* It will only work with lines containing text (i.e. not `~` (non-lines)).

## Related plugins

* The [cursorcross.vim](https://github.com/mtth/cursorcross.vim) plugin
  provides automatic and "refreshingly sane `cursorcolumn` and `cursorline`
  handling".
* The [ZoomWin](http://drchip.org/astronaut/vim/index.html#ZOOMWIN) plugin
  allows to (un-)maximize the current window.
* [goyo.vim](https://github.com/junegunn/goyo.vim) provides distraction-free
  writing in Vim.

[1]: https://groups.google.com/d/msg/vim_use/IJU-Vk-QLJE/xz4hjPjCRBUJ
[2]: http://stackoverflow.com/a/12519572/15690

