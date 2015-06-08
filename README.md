# Paner

Missing pane manipulation helpers.

![gif](https://raw.githubusercontent.com/t9md/t9md/476f9dc48cd2d3e8fce7ee0935f04d36d0fc04c0/img/atom-paner.gif)

# Feature

* Swap Pane Item: Exchange PaneItem with adjacent pane like Vim's `ctrl-w x`. Adjacent means choose swap `target` within same PaneAxis(`horizontal` or `vertical`).

* Maximize: Maximize pane. Well know as **Zen mode**.
Automatically exit Maximized mode if Active Pane changed.

* VERY-top: Move Pane to **very** top, bottom, right, left like Vim's `ctrl-w H` and its cousin.

# How to use

* `paner:swap-item` to swap Pane Item with Adjacent pane Item.
* `paner:maximize` to Maximize or de-Maximize current Pane Item.
* `paner:very-top`, `paner:very-bottom`, `paner:very-right`, `paner:very-left` to move current Pane to very far direction.

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
  'cmd-enter':       'paner:maximize'
  'cmd-k cmd-up':    'paner:very-top'
  'cmd-k cmd-down':  'paner:very-bottom'
  'cmd-k cmd-left':  'paner:very-left'
  'cmd-k cmd-right': 'paner:very-right'
```

* [vim-mode](https://atom.io/packages/vim-mode) user.

```coffeescript
'atom-text-editor.vim-mode.command-mode':
  'ctrl-w x':     'paner:swap-item'
  'ctrl-w enter': 'paner:maximize'
  'ctrl-w K':     'paner:very-top'
  'ctrl-w J':     'paner:very-bottom'
  'ctrl-w H':     'paner:very-left'
  'ctrl-w L':     'paner:very-right'
```

* Mine.

```coffeescript
'atom-text-editor.vim-mode.command-mode':
  'cmd-x':     'paner:swap-item'
  'cmd-enter': 'paner:maximize'
  'cmd-K':     'paner:very-top'
  'cmd-J':     'paner:very-bottom'
  'cmd-H':     'paner:very-left'
  'cmd-L':     'paner:very-right'
```
