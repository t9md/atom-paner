const {CompositeDisposable, Emitter} = require("atom")

// Utils
function debug(msg) {
  if (atom.config.get("paner.debug")) {
    console.log(msg)
  }
}

function splitPane(pane, direction, params) {
  direction = direction.charAt(0).toUpperCase() + direction.slice(1)
  return pane[`split${direction}`](params)
}

function withConfig(scope, value, fn) {
  let restoreConfig
  const origialValue = atom.config.get(scope)
  if (origialValue !== value) {
    atom.config.set(scope, value)
    restoreConfig = () => atom.config.set(scope, origialValue)
  }

  try {
    fn()
  } finally {
    if (restoreConfig) restoreConfig()
  }
}

// Return adjacent pane within current PaneAxis.
//  * return next Pane if exists.
//  * return previous pane if next pane was not exits.
function getAdjacentPane(pane) {
  const children = pane.getParent().getChildren()
  if (!children) return

  const index = children.indexOf(pane)
  const [previousPane, nextPane] = [children[index - 1], children[index + 1]]
  return nextPane || previousPane
}

// Move active item from srcPane to dstPane's last index
function moveActivePaneItem(srcPane, dstPane) {
  const item = srcPane.getActiveItem()
  const index = dstPane.getItems().length
  srcPane.moveItemToPane(item, dstPane, index)
  return dstPane.activateItem(item)
}

// [FIXME] after swapped, dst pane have no focus, but cursor is still visible.
// I can manually cursor.setVisible(false) but this cause curor is not visible
// after pane got focus again.
function swapActiveItem(srcPane, dstPane) {
  let dstItem, srcItem
  let srcIndex = null
  if ((srcItem = srcPane.getActiveItem()) != null) {
    srcIndex = srcPane.getActiveItemIndex()
  }

  let dstIndex = null
  if ((dstItem = dstPane.getActiveItem()) != null) {
    dstIndex = srcPane.getActiveItemIndex()
  }

  if (srcItem != null) {
    srcPane.moveItemToPane(srcItem, dstPane, dstIndex)
  }

  if (dstItem != null) {
    dstPane.moveItemToPane(dstItem, srcPane, srcIndex)
    srcPane.activateItem(dstItem)
  }
  return srcPane.activate()
}

function reparent(paneAxis) {
  debug("reparent")
  const parent = paneAxis.getParent()
  let anchor = null
  for (let child of paneAxis.getChildren()) {
    if (anchor == null) {
      parent.replaceChild(paneAxis, child)
    } else {
      parent.insertChildAfter(anchor, child)
    }
    anchor = child
  }
  return paneAxis.destroy()
}

function getAllPaneAxis(paneAxis, results = []) {
  for (let child of paneAxis.getChildren()) {
    if (child instanceof PaneAxis) {
      results.push(child)
      getAllPaneAxis(child, results)
    }
  }
  return results
}

let PaneAxis = null
let Pane = null

module.exports = class PanerPackage {
  activate() {
    this.subscriptions = new CompositeDisposable()
    this.workspaceElement = atom.workspace.getElement()
    Pane = atom.workspace.getActivePane().constructor
    this.emitter = new Emitter()

    this.subscriptions.add(
      atom.commands.add("atom-workspace", {
        "paner:maximize": () => this.maximize(),

        "paner:swap-item": () => this.swapItem(),
        "paner:merge-item": () => this.mergeItem({activate: true}),
        "paner:send-item": () => this.mergeItem({activate: false}),

        "paner:split-up": () => this.splitPane("up"),
        "paner:split-down": () => this.splitPane("down"),
        "paner:split-left": () => this.splitPane("left"),
        "paner:split-right": () => this.splitPane("right"),

        "paner:swap-pane": () => this.swapPane(),

        "paner:very-top": () => this.movePaneToVery("top"),
        "paner:very-bottom": () => this.movePaneToVery("bottom"),
        "paner:very-left": () => this.movePaneToVery("left"),
        "paner:very-right": () => this.movePaneToVery("right"),
      })
    )

    return this.onDidPaneSplit(function({oldPane, newPane, direction, options}) {
      let oldEditor
      if (!(oldEditor = oldPane.getActiveEditor())) {
        return
      }
      const oldEditorElement = oldEditor.element
      const newEditor = newPane.getActiveEditor()
      const newEditorElement = newEditor.element
      switch (direction) {
        case "right":
        case "left":
          return newEditorElement.setScrollTop(oldEditorElement.getScrollTop())

        case "up":
        case "down":
          const {pixelTop, ratio} = options
          const newHeight = newEditorElement.getHeight()
          const scrolloff = 2
          const lineHeightInPixels = oldEditor.getLineHeightInPixels()

          const offsetTop = lineHeightInPixels * scrolloff
          const offsetBottom = newHeight - lineHeightInPixels * (scrolloff + 1)
          const offsetCursor = newHeight * ratio
          const scrollTop = pixelTop - Math.min(Math.max(offsetCursor, offsetTop), offsetBottom)

          oldEditorElement.setScrollTop(scrollTop)
          return newEditorElement.setScrollTop(scrollTop)
      }
    })
  }

  deactivate() {
    this.subscriptions.dispose()
    return ({workspaceElement: this.workspaceElement} = {})
  }

  onDidPaneSplit(callback) {
    return this.emitter.on("did-pane-split", callback)
  }

  // Simply add/remove css class, actual maximization effect is done by CSS.
  maximize() {
    let subs
    this.workspaceElement.classList.toggle("paner-maximize")
    return (subs = atom.workspace.getActivePane().onDidChangeActive(() => {
      this.workspaceElement.classList.remove("paner-maximize")
      return subs.dispose()
    }))
  }

  getCursorPositionInfo(editor) {
    const editorElement = editor.element
    const point = editor.getCursorScreenPosition()
    const pixelTop = editorElement.pixelPositionForScreenPosition(point).top
    const ratio = (pixelTop - editorElement.getScrollTop()) / editorElement.getHeight()
    return {pixelTop, ratio}
  }

  splitPane(direction) {
    const oldPane = atom.workspace.getActivePane()
    let options = null
    if (["up", "down"].includes(direction)) {
      options = this.getCursorPositionInfo(oldPane.getActiveEditor())
    }
    const newPane = splitPane(oldPane, direction, {copyActiveItem: true, activate: false})
    return this.emitter.emit("did-pane-split", {oldPane, newPane, direction, options})
  }

  swapItem() {
    const activePane = atom.workspace.getActivePane()
    const adjacentPane = getAdjacentPane(activePane)
    if (adjacentPane) {
      // In case there is only one item in pane, we need to avoid pane itself
      // destroyed while swapping.
      withConfig("core.destroyEmptyPanes", false, () => swapActiveItem(activePane, adjacentPane))
    }
  }

  mergeItem({activate} = {}) {
    let dstPane
    const currentPane = atom.workspace.getActivePane()
    if ((dstPane = getAdjacentPane(currentPane))) {
      moveActivePaneItem(currentPane, dstPane)
      if (activate) {
        return dstPane.activate()
      }
    }
  }

  swapPane() {
    const activePane = atom.workspace.getActivePane()
    const adjacentPane = getAdjacentPane(activePane)

    if (adjacentPane) {
      const parent = activePane.getParent()
      const children = parent.getChildren()

      if (children.indexOf(activePane) < children.indexOf(adjacentPane)) {
        parent.removeChild(activePane, true)
        parent.insertChildAfter(adjacentPane, activePane)
      } else {
        parent.removeChild(activePane, true)
        parent.insertChildBefore(adjacentPane, activePane)
      }
      console.log("CALLEd")
      activePane.activate()
    }
  }

  movePaneToVery(direction) {
    if (atom.workspace.getPanes().length < 2) {
      return
    }
    const pane = atom.workspace.getActivePane()
    const container = pane.getContainer()
    let root = container.getRoot()
    const orientation = (() => {
      switch (direction) {
        case "top":
        case "bottom":
          return "vertical"
        case "right":
        case "left":
          return "horizontal"
      }
    })()

    // If there is multiple pane in window, root is always instance of PaneAxis
    if (PaneAxis == null) {
      PaneAxis = root.constructor
    }
    const parent = pane.getParent()

    if (root.getOrientation() !== orientation) {
      container.setRoot((root = new PaneAxis({container, orientation, children: [root]})))
      parent.removeChild(pane)
    } else {
      parent.removeChild(pane, true)
    }

    switch (direction) {
      case "top":
      case "left":
        root.addChild(pane, 0)
        break
      case "right":
      case "bottom":
        root.addChild(pane)
        break
    }

    for (let axis of getAllPaneAxis(root)) {
      if (axis.getOrientation() === axis.getParent().getOrientation()) {
        reparent(axis)
      }
    }

    return pane.activate()
  }
}
