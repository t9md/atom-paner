# Paner [![Build Status](https://travis-ci.org/t9md/atom-paner.svg)](https://travis-ci.org/t9md/atom-paner)

Missing pane manipulation utilities.

![gif](https://raw.githubusercontent.com/t9md/t9md/4407eb697d1f83a8ce6a16ce096a98a270980c3b/img/atom-paner.gif)

# Feature

Although this package provide several utility command, the killer feature is move-to-very-xxx command.

- move to VERY top/bottom/right/left: Move Pane to **very** top, bottom, right, left like Vim's `ctrl-w H` and its cousin.
- Swap pane item with adjacent pane like Vim's `ctrl-w x`. Adjacent means choose swap `target` within same PaneAxis(`horizontal` or `vertical`).
- Maximize: Maximize pane. Well know as **Zen mode**. Automatically exit Maximized mode if Active Pane changed.
- Split with synching scroll state of original pane item.

# Commands

## Move pane to VERY far direction

- `paner:very-top`: Move pane to very top position.
- `paner:very-bottom`: Move pane to very bottom position.
- `paner:very-right`: Move pane to very right position.
- `paner:very-left`: Move pane to very left position.

## Swap Pane
- `paner:swap-pane`: Swap pane with adjacent pane.

## Pane item manipulation

- `paner:swap-item`: Swap item with adjacent pane's.
- `paner:send-item`: Send active item to adjacent Pane.
- `paner:merge-item`: Same as `paner:send-item` but it activate target pane.

## Zen-mode

- `paner:maximize`: Maximize or unMaximize current pane item.

## Split with keeping scroll ratio

- `paner:split-up`: Keep scroll state for newly opened editor so you won't loose sight of cursor.
- `paner:split-down`: Keep scroll state for newly opened editor.
- `paner:split-right`: Keep scroll state for newly opened editor.
- `paner:split-left`: Keep scroll state for newly opened editor.

# Keymap example.

No default keymap.

* For normal user.

```coffeescript
'atom-workspace:not([mini])':
  'cmd-k x': 'paner:swap-item'
  'cmd-k X': 'paner:send-item'
  'cmd-enter': 'paner:maximize'
  'cmd-k cmd-up': 'paner:very-top'
  'cmd-k cmd-down': 'paner:very-bottom'
  'cmd-k cmd-left': 'paner:very-left'
  'cmd-k cmd-right': 'paner:very-right'

  'cmd-k up': 'paner:split-up'
  'cmd-k down': 'paner:split-down'
  'cmd-k left': 'paner:split-left'
  'cmd-k right': 'paner:split-right'
```

* [vim-mode-plus](https://atom.io/packages/vim-mode-plus) user.

If you want to manipulate pane which is not instance of TextEdior(e.g. settings-view), you need to set keymap on `atom-workspace` not on `atom-text-editor`.

```coffeescript
'atom-text-editor.vim-mode-plus.normal-mode':
  'ctrl-w x': 'paner:swap-pane'
  'ctrl-w X': 'paner:send-item'
  # 'ctrl-w enter': 'paner:maximize' # maximize feature is already bundled in vmp
  'ctrl-w K': 'paner:very-top'
  'ctrl-w J': 'paner:very-bottom'
  'ctrl-w H': 'paner:very-left'
  'ctrl-w L': 'paner:very-right'
  'ctrl-w v': 'paner:split-left'
```

* Mine.

```coffeescript
'atom-workspace:not([mini])':
  'cmd-x': 'paner:swap-pane'
  'cmd-X': 'paner:send-item'
  'cmd-K': 'paner:very-top'
  'cmd-J': 'paner:very-bottom'
  'cmd-H': 'paner:very-left'
  'cmd-L': 'paner:very-right'

'atom-text-editor.vim-mode-plus.normal-mode':
  # Override default cmd-L(editor:split-selections-into-lines)
  'cmd-L': 'paner:very-right'
```
