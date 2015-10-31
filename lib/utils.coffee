_ = require 'underscore-plus'

getView = (model) ->
  atom.views.getView(model)

getActivePane = ->
  atom.workspace.getActivePane()

debug = (msg) ->
  return unless atom.config.get('paner.debug')
  console.log msg

splitPane = (pane, direction) ->
  method = "split#{_.capitalize(direction)}"
  pane[method]({copyActiveItem: true, activate: false})

resetPreviewStateForPane = (pane) ->
  paneElement = atom.views.getView(pane)
  paneElement.getElementsByClassName('preview-tab')[0]?.clearPreview()

# Return function to restore origial value.
setConfig = (scope, value) ->
  origialValue = atom.config.get(scope)
  if origialValue isnt value
    atom.config.set(scope, value)
    -> # return function to restore original value
      atom.config.set(scope, origialValue)

# Return adjacent pane within current PaneAxis.
#  * return next Pane if exists.
#  * return previous pane if next pane was not exits.
getAdjacentPane = (pane) ->
  return unless children = pane.getParent().getChildren?()
  index = children.indexOf pane
  [prev, next] = [children[index-1], children[index+1]]
  _.last(_.compact([prev, next]))

# Move active item from srcPane to dstPane's last index
moveActivePaneItem = (srcPane, dstPane) ->
  item = srcPane.getActiveItem()
  index = dstPane.getItems().length
  resetPreviewStateForPane(dstPane)
  srcPane.moveItemToPane(item, dstPane, index)
  dstPane.activateItem(item)
  resetPreviewStateForPane(dstPane)

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
  for item, i in srcPane.getItems()
    srcPane.moveItemToPane item, dstPane, i
    resetPreviewStateForPane(dstPane)
  dstPane.activateItem(activeItem)

isSameOrientationAsParent = (paneAxis) ->
  parent = paneAxis.getParent()
  paneAxis.getOrientation() is parent.getOrientation()

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
      getAllPaneAxis child, results
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
  resetPreviewStateForPane
  setConfig
  getAdjacentPane
  moveActivePaneItem
  swapActiveItem
  moveAllPaneItems
  mergeToParentPaneAxis
  getAllPaneAxis
  copyPaneAxis
  copyRoot
  isSameOrientationAsParent
}
