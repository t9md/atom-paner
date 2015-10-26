# Paner [![Build Status](https://travis-ci.org/t9md/atom-paner.svg)](https://travis-ci.org/t9md/atom-paner)

Missing pane manipulation utilities.

![gif](https://raw.githubusercontent.com/t9md/t9md/4407eb697d1f83a8ce6a16ce096a98a270980c3b/img/atom-paner.gif)

# Feature

* Swap PaneItem: Exchange PaneItem with adjacent pane like Vim's `ctrl-w x`. Adjacent means choose swap `target` within same PaneAxis(`horizontal` or `vertical`).

* Send PaneItem: Send active PaneItem to adjacent PaneItem.

* Maximize: Maximize pane. Well know as **Zen mode**.
Automatically exit Maximized mode if Active Pane changed.

* move to VERY top/bottom/right/left: Move Pane to **very** top, bottom, right, left like Vim's `ctrl-w H` and its cousin.

* Split with synching scroll state of original paneItem.

# How to use

* `paner:swap-item` to swap PaneItem with adjacent PaneItem.
* `paner:send-item` to send active PaneItem to adjacent Pane.
* `paner:merge-item` same as `paner:send-item` but it activate sent item.
* `paner:maximize` to Maximize or de-Maximize current PaneItem.
* `paner:very-top`, `paner:very-bottom`, `paner:very-right`, `paner:very-left` to move current Pane to very far direction.
* `paner:split-up` and its friends: similar to Atom's `pane:split-up` but it sync scroll state to original item so that you don't lose sight of cursor position after split.

# NOTE

From atom 0.206.0, PreviewTab feature is introduces.  
If user enabled this feature, tab not modified or dblclicked is treated as preview, temporary tab which is replaced when opening another file.  
This tab characteristic don't well work with paner since is move tab(paneItem) from pane to pane.  
To workaround this, paner manually clear(or reset) preview state of tab for the pane which is subject to manipulation. See [#1](https://github.com/t9md/atom-paner/issues/1).  

# Keymap
No keymap by default.

* For everyone.

```coffeescript
'atom-workspace:not([mini])':
  'cmd-k x':         'paner:swap-item'
  'cmd-k X':         'paner:send-item'
  'cmd-enter':       'paner:maximize'
  'cmd-k cmd-up':    'paner:very-top'
  'cmd-k cmd-down':  'paner:very-bottom'
  'cmd-k cmd-left':  'paner:very-left'
  'cmd-k cmd-right': 'paner:very-right'

  'cmd-k up':    'paner:split-up'
  'cmd-k down':  'paner:split-down'
  'cmd-k left':  'paner:split-left'
  'cmd-k right': 'paner:split-right'
```

* [vim-mode](https://atom.io/packages/vim-mode) user.

If you want to manipulate pane which is not instance of TextEdior(e.g. settings-view), you need to set keymap on `atom-workspace` not on `atom-text-editor`.

```coffeescript
'atom-text-editor.vim-mode.normal-mode':
  'ctrl-w x':     'paner:swap-item'
  'ctrl-w X':     'paner:send-item'
  'ctrl-w enter': 'paner:maximize'
  'ctrl-w K':     'paner:very-top'
  'ctrl-w J':     'paner:very-bottom'
  'ctrl-w H':     'paner:very-left'
  'ctrl-w L':     'paner:very-right'
  'ctrl-w s':     'paner:split-up'
  'ctrl-w v':     'paner:split-left'
```

* Mine.

```coffeescript
'atom-workspace:not([mini])':
  'cmd-x':     'paner:swap-item'
  'cmd-X':     'paner:send-item'
  'cmd-enter': 'paner:maximize'
  'cmd-K':     'paner:very-top'
  'cmd-J':     'paner:very-bottom'
  'cmd-H':     'paner:very-left'
  'cmd-L':     'paner:very-right'
  'cmd-2':     'paner:split-up'
  'cmd-3':     'paner:split-left'
```
