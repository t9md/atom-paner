_ = require 'underscore-plus'

getView = (model) ->
  atom.views.getView(model)

getActivePane = ->
  atom.workspace.getActivePane()

debug = (msg) ->
  return unless atom.config.get('paner.debug')
  console.log msg

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
  # resetPreviewStateForPane(dstPane)
  srcPane.moveItemToPane(item, dstPane, index)
  dstPane.activateItem(item)
  # resetPreviewStateForPane(dstPane)

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

moveAllPaneItems = (srcPane, dstPane) ->
  activeItem = srcPane.getActiveItem() # remember ActiveItem
  srcPane.moveItemToPane(item, dstPane, i) for item, i in srcPane.getItems()
  dstPane.activateItem(activeItem)

mergeToParentPaneAxis = (paneAxis) ->
  parent = paneAxis.getParent()
  children = paneAxis.getChildren()
  firstChild = children.shift()
  firstChild.setFlexScale()
  parent.replaceChild(paneAxis, firstChild)
  while (child = children.shift())
    parent.insertChildAfter(firstChild, child)
  paneAxis.destroy()

PaneAxis = null
getAllPaneAxis = (paneAxis, results=[]) ->
  PaneAxis ?= paneAxis.constructor
  for child in paneAxis.getChildren()
    if child instanceof PaneAxis
      results.push(child)
      getAllPaneAxis(child, results)
  results

copyPaneAxis = (paneAxis) ->
  PaneAxis ?= paneAxis.constructor

  children = paneAxis.getChildren()
  paneAxis.unsubscribeFromChild(c) for c in children

  container = paneAxis.getContainer()
  orientation = paneAxis.getOrientation()

  new PaneAxis({container, orientation, children})

copyRoot = (root) ->
  newRoot = copyPaneAxis(root)
  for axis in getAllPaneAxis(newRoot)
    axis.getParent().replaceChild(axis, copyPaneAxis(axis))
    axis.destroy()
  newRoot

module.exports = {
  getView
  getActivePane
  debug
  splitPane
  withConfig
  getAdjacentPane
  moveActivePaneItem
  swapActiveItem
  moveAllPaneItems
  mergeToParentPaneAxis
  getAllPaneAxis
  copyPaneAxis
  copyRoot
}
