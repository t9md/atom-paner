_ = require 'underscore-plus'
{CompositeDisposable, Emitter} = require 'atom'

# Utils
getView = (model) ->
  atom.views.getView(model)

getActivePane = ->
  atom.workspace.getActivePane()

debug = (msg) ->
  console.log msg
  return unless atom.config.get('paner.debug')

splitPane = (pane, direction, params) ->
  method = "split#{_.capitalize(direction)}"
  pane[method](params)

withConfig = (scope, value, fn) ->
  origialValue = atom.config.get(scope)
  unless origialValue is value
    atom.config.set(scope, value)
    restoreConfig = ->
      atom.config.set(scope, origialValue)
  try
    fn()
  finally
    restoreConfig?()

# Return adjacent pane within current PaneAxis.
#  * return next Pane if exists.
#  * return previous pane if next pane was not exits.
getAdjacentPane = (pane) ->
  return unless children = pane.getParent().getChildren?()
  index = children.indexOf(pane)
  [prev, next] = [children[index-1], children[index+1]]
  _.last(_.compact([prev, next]))

# Move active item from srcPane to dstPane's last index
moveActivePaneItem = (srcPane, dstPane) ->
  item = srcPane.getActiveItem()
  index = dstPane.getItems().length
  srcPane.moveItemToPane(item, dstPane, index)
  dstPane.activateItem(item)

# [FIXME] after swapped, dst pane have no focus, but cursor is still visible.
# I can manually cursor.setVisible(false) but this cause curor is not visible
# after pane got focus again.
swapActiveItem = (srcPane, dstPane) ->
  srcIndex = null
  if (srcItem  = srcPane.getActiveItem())?
    srcIndex = srcPane.getActiveItemIndex()

  dstIndex = null
  if (dstItem  = dstPane.getActiveItem())?
    dstIndex = srcPane.getActiveItemIndex()

  if srcItem?
    srcPane.moveItemToPane(srcItem, dstPane, dstIndex)

  if dstItem?
    dstPane.moveItemToPane(dstItem, srcPane, srcIndex)
    srcPane.activateItem(dstItem)
  srcPane.activate()

reparent = (paneAxis) ->
  debug("reparent")
  parent = paneAxis.getParent()
  for child, i in paneAxis.getChildren()
    if i is 0
      parent.replaceChild(paneAxis, child)
    else
      parent.insertChildAfter(anchor, child)
    anchor = child
  paneAxis.destroy()

getAllPaneAxis = (paneAxis, results=[]) ->
  for child in paneAxis.getChildren() when child instanceof PaneAxis
    results.push(child)
    getAllPaneAxis(child, results)
  results

PaneAxis = null
Pane = null

module.exports =
  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @workspaceElement = getView(atom.workspace)
    Pane = getActivePane().constructor
    @emitter = new Emitter

    @subscriptions.add atom.commands.add 'atom-workspace',
      'paner:maximize': => @maximize()
      'paner:swap-item': => @swapItem()
      'paner:merge-item': => @mergeItem(activate: true)
      'paner:send-item': => @mergeItem(activate: false)


      'paner:split-up': => @splitPane('up')
      'paner:split-down': => @splitPane('down')
      'paner:split-left': => @splitPane('left')
      'paner:split-right': => @splitPane('right')

      'paner:swap-pane': => @swapPane()

      'paner:very-top': => @movePaneToVery('top')
      'paner:very-bottom': => @movePaneToVery('bottom')
      'paner:very-left': => @movePaneToVery('left')
      'paner:very-right': => @movePaneToVery('right')

    @onDidPaneSplit ({oldPane, newPane, direction, options}) ->
      return unless oldEditor = oldPane.getActiveEditor()
      oldEditorElement = getView(oldEditor)
      newEditor = newPane.getActiveEditor()
      newEditorElement = getView(newEditor)
      switch direction
        when 'right', 'left'
          newEditorElement.setScrollTop(oldEditorElement.getScrollTop())

        when 'up', 'down'
          {pixelTop, ratio} = options
          newHeight = newEditorElement.getHeight()
          scrolloff = 2
          lineHeightInPixels = oldEditor.getLineHeightInPixels()

          offsetTop = lineHeightInPixels * scrolloff
          offsetBottom = newHeight - lineHeightInPixels * (scrolloff+1)
          offsetCursor = newHeight * ratio
          scrollTop = pixelTop - Math.min(Math.max(offsetCursor, offsetTop), offsetBottom)

          oldEditorElement.setScrollTop(scrollTop)
          newEditorElement.setScrollTop(scrollTop)

  deactivate: ->
    @subscriptions.dispose()
    {@workspaceElement} = {}

  onDidPaneSplit: (callback) ->
    @emitter.on 'did-pane-split', callback

  # Simply add/remove css class, actual maximization effect is done by CSS.
  maximize: ->
    @workspaceElement.classList.toggle('paner-maximize')
    subs = getActivePane().onDidChangeActive =>
      @workspaceElement.classList.remove('paner-maximize')
      subs.dispose()

  getCursorPositionInfo: (editor) ->
    editorElement = getView(editor)
    point = editor.getCursorScreenPosition()
    pixelTop = editorElement.pixelPositionForScreenPosition(point).top
    ratio = (pixelTop - editorElement.getScrollTop()) / editorElement.getHeight()
    {pixelTop, ratio}

  splitPane: (direction) ->
    oldPane = getActivePane()
    options = null
    if direction in ['up', 'down']
      options = @getCursorPositionInfo(oldPane.getActiveEditor())
    newPane = splitPane(oldPane, direction, copyActiveItem: true, activate: false)
    @emitter.emit 'did-pane-split', {oldPane, newPane, direction, options}

  swapItem: ->
    currentPane = getActivePane()
    if adjacentPane = getAdjacentPane(currentPane)
      # In case there is only one item in pane, we need to avoid pane itself
      # destroyed while swapping.
      withConfig 'core.destroyEmptyPanes', false, ->
        swapActiveItem(currentPane, adjacentPane)

  mergeItem: ({activate}={}) ->
    currentPane = getActivePane()
    if dstPane = getAdjacentPane(currentPane)
      moveActivePaneItem(currentPane, dstPane)
      dstPane.activate() if activate

  swapPane: ->
    pane = getActivePane()
    parent = pane.getParent()

    return unless children = parent.getChildren?()

    index = children.indexOf(pane)
    if index is (children.length - 1)
      adjacentPane = children[index - 1]
      parent.removeChild(pane, true)
      parent.insertChildBefore(adjacentPane, pane)
    else
      adjacentPane = children[index + 1]
      parent.removeChild(pane, true)
      parent.insertChildAfter(adjacentPane, pane)

    pane.activate()

  movePaneToVery: (direction) ->
    return if atom.workspace.getPanes().length < 2
    pane = getActivePane()
    container = pane.getContainer()
    root = container.getRoot()
    orientation = if direction in ['top', 'bottom'] then 'vertical' else 'horizontal'

    # If there is multiple pane in window, root is always instance of PaneAxis
    PaneAxis ?= root.constructor
    parent = pane.getParent()
    if root.getOrientation() isnt orientation
      container.setRoot(root = new PaneAxis({container, orientation, children: [root]}))
      parent.removeChild(pane)
    else
      parent.removeChild(pane, true)

    switch direction
      when 'top', 'left' then root.addChild(pane, 0)
      when 'right', 'bottom' then root.addChild(pane)

    for axis in getAllPaneAxis(root)
      if axis.getOrientation() is axis.getParent().getOrientation()
        reparent(axis)

    pane.activate()
