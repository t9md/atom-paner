# Paner [![Build Status](https://travis-ci.org/t9md/atom-paner.svg)](https://travis-ci.org/t9md/atom-paner)

Missing pane manipulation utilities.  

- This package include several pane manipulation commands
- But why I created this package is for `move-pane-to-very-XXX` commands.  
- Which is equivalent feature of Vim's `ctrl-w K`, `ctrl-w J`, `ctrl-w H`, `ctrl-w L`.  

![gif](https://raw.githubusercontent.com/t9md/t9md/3a96be08b9bc5661f4a7dc2154380bc08789a226/img/atom-paner.gif)

# Commands

### Move pane to far-most direction.

- `paner:move-pane-to-very-top`:
- `paner:move-pane-to-very-bottom`:
- `paner:move-pane-to-very-left`:
- `paner:move-pane-to-very-right`:

### Move pane item to adjacent pane

- `paner:move-pane-item`: Adjacent pane become active.
- `paner:move-pane-item-stay`: Doesn't change active pane.

### Exchange current pane with adjacent pane.

- `paner:exchange-pane`
- `paner:exchange-pane-stay`

### Split with keeping scroll ratio

Respect original scroll ratio when open new item so that you won't loose sight of cursor.

- `paner:split-pane-up`
- `paner:split-pane-down`
- `paner:split-pane-left`
- `paner:split-pane-right`

Doesn't activate new pane.

- `paner:split-pane-up-stay`
- `paner:split-pane-down-stay`
- `paner:split-pane-left-stay`
- `paner:split-pane-right-stay`

# Keymap example.

No default keymap.

* For normal user.

```coffeescript
'atom-workspace:not([mini])':
  'cmd-k x': 'paner:exchange-pane'
  'cmd-k cmd-up': 'paner:move-pane-to-very-top'
  'cmd-k cmd-down': 'paner:move-pane-to-very-bottom'
  'cmd-k cmd-right': 'paner:move-pane-to-very-right'
  'cmd-k cmd-left': 'paner:move-pane-to-very-left'

  'cmd-k up': 'paner:split-up'
  'cmd-k down': 'paner:split-down'
```

* [vim-mode-plus](https://atom.io/packages/vim-mode-plus) user.

If you want to manipulate pane which is not instance of TextEdior(e.g. settings-view), you need to set keymap on `atom-workspace` not on `atom-text-editor`.

```coffeescript
'atom-text-editor.vim-mode-plus.normal-mode':
  'ctrl-w x': 'paner:exchange-pane-stay'
  'ctrl-w K': 'paner:move-pane-to-very-top'
  'ctrl-w J': 'paner:move-pane-to-very-bottom'
  'ctrl-w H': 'paner:move-pane-to-very-left'
  'ctrl-w L': 'paner:move-pane-to-very-right'
  'ctrl-w s': 'paner:split-pane-down-stay'
  'ctrl-w v': 'paner:split-pane-right-stay'
```

* Mine.

```coffeescript
'atom-workspace:not([mini])':
  'cmd-x': 'paner:exchange-pane-stay'
  'cmd-X': 'paner:move-pane-item'

  'cmd-K': 'paner:move-pane-to-very-top'
  'cmd-J': 'paner:move-pane-to-very-bottom'
  'cmd-H': 'paner:move-pane-to-very-left'
  'cmd-L': 'paner:move-pane-to-very-right'

  'cmd-2': 'paner:split-pane-down-stay'
  'cmd-3': 'paner:split-pane-right-stay'

'atom-text-editor.vim-mode-plus.normal-mode':
  # Override default cmd-L(editor:split-selections-into-lines)
  'cmd-L': 'paner:move-pane-to-very-right'
```
