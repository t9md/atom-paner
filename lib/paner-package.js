const {CompositeDisposable} = require("atom")

// Utils
function debug(msg) {
  if (atom.config.get("paner.debug")) {
    console.log(msg)
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

function getAllPaneAxis(root, result = []) {
  if (root.children) {
    result.push(root)
    for (const child of root.children) {
      getAllPaneAxis(child, result)
    }
  }
  return result
}

let PaneAxis = null
let Pane = null

module.exports = class PanerPackage {
  activate() {
    this.subscriptions = new CompositeDisposable()
    Pane = atom.workspace.getActivePane().constructor

    this.subscriptions.add(
      atom.commands.add("atom-workspace", {
        "paner:swap-item": () => this.swapItem(),
        "paner:send-item": () => this.sendItem(),
        "paner:swap-pane": () => this.swapPane(),

        "paner:split-up": () => this.splitPane("Up"),
        "paner:split-down": () => this.splitPane("Down"),
        "paner:split-left": () => this.splitPane("Left"),
        "paner:split-right": () => this.splitPane("Right"),

        "paner:move-pane-to-very-top": () => this.movePaneToVery("top"),
        "paner:move-pane-to-very-bottom": () => this.movePaneToVery("bottom"),
        "paner:move-pane-to-very-left": () => this.movePaneToVery("left"),
        "paner:move-pane-to-very-right": () => this.movePaneToVery("right"),
      })
    )
  }

  deactivate() {
    this.subscriptions.dispose()
  }

  // Valid direction: ["Up", "Down", "Left", "Right"]
  splitPane(direction) {
    const activePane = atom.workspace.getActivePane()
    const activeEditor = activePane.getActiveEditor()
    const newPane = activePane[`split${direction}`]({copyActiveItem: true, activate: false})

    if (!activeEditor) return

    const oldEditor = activeEditor
    const newEditor = newPane.getActiveEditor()
    switch (direction) {
      case "Right":
      case "Left":
        // FIXME: not working without adding 0 msec delay
        // Because someone explicitly set scrollTop after split.
        const firstVisibleScreenRow = oldEditor.getFirstVisibleScreenRow()
        // setTimeout(function () {
        //   newEditor.setFirstVisibleScreenRow(firstVisibleScreenRow)
        // }, 0);
        newEditor.setFirstVisibleScreenRow(firstVisibleScreenRow)
        return

      case "Up":
      case "Down":
        const pixelTop = oldEditor.element.pixelPositionForScreenPosition(
          oldEditor.getCursorScreenPosition()
        ).top
        const ratio = (pixelTop - oldEditor.element.getScrollTop()) / oldEditor.element.getHeight()

        const newHeight = newEditor.element.getHeight()
        const scrolloff = 2
        const lineHeightInPixels = oldEditor.getLineHeightInPixels()
        const offsetTop = lineHeightInPixels * scrolloff
        const offsetBottom = newHeight - lineHeightInPixels * (scrolloff + 1)
        const offsetCursor = newHeight * ratio
        const scrollTop = pixelTop - Math.min(Math.max(offsetCursor, offsetTop), offsetBottom)

        oldEditor.element.setScrollTop(scrollTop)
        newEditor.element.setScrollTop(scrollTop)
        return
    }
  }

  swapItem() {
    const activePane = atom.workspace.getActivePane()
    const adjacentPane = getAdjacentPane(activePane)
    if (!adjacentPane) return

    let configModified = false
    const destroyEmptyPanes = atom.config.get("core.destroyEmptyPanes")
    if (destroyEmptyPanes) {
      atom.config.set("core.destroyEmptyPanes", false)
      let configModified = true
    }

    const [srcPane, dstPane] = [activePane, adjacentPane]
    const [srcItem, srcIndex] = [srcPane.getActiveItem(), srcPane.getActiveItemIndex()]
    const [dstItem, dstIndex] = [dstPane.getActiveItem(), dstPane.getActiveItemIndex()]

    if (srcItem) {
      srcPane.moveItemToPane(srcItem, dstPane, dstIndex >= 0 ? dstIndex : undefined)
    }
    if (dstItem) {
      dstPane.moveItemToPane(dstItem, srcPane, srcIndex >= 0 ? srcIndex : undefined)
      srcPane.activateItem(dstItem)
    }
    srcPane.activate()
    if (configModified) {
      atom.config.set("core.destroyEmptyPanes", destroyEmptyPanes)
    }
  }

  sendItem() {
    const activePane = atom.workspace.getActivePane()
    const adjacentPane = getAdjacentPane(activePane)
    if (!activeEditor) return

    const activeItem = activePane.getActiveItem()
    activePane.moveItemToPane(activeItem, adjacentPane, adjacentPane.getItems().length)
    adjacentPane.activateItem(activeItem)
  }

  // Swap activePane with adjacentPane
  // Original adjacentPane become activePane finally.
  swapPane() {
    const activePane = atom.workspace.getActivePane()
    const adjacentPane = getAdjacentPane(activePane)
    if (!adjacentPane) return

    const parent = activePane.getParent()
    const children = parent.getChildren()

    if (children.indexOf(activePane) < children.indexOf(adjacentPane)) {
      parent.removeChild(activePane, true)
      parent.insertChildAfter(adjacentPane, activePane)
    } else {
      parent.removeChild(activePane, true)
      parent.insertChildBefore(adjacentPane, activePane)
    }
    adjacentPane.activate()
  }

  // Valid direction ["top", "bottom", "left", "right"]
  movePaneToVery(direction) {
    if (atom.workspace.getCenter().getPanes().length < 2) return

    const activePane = atom.workspace.getActivePane()
    const container = activePane.getContainer()
    const parent = activePane.getParent()

    const originalRoot = container.getRoot()
    let root = originalRoot
    // If there is multiple pane in window, root is always instance of PaneAxis
    if (!PaneAxis) PaneAxis = root.constructor

    const finalOrientation = ["top", "bottom"].includes(direction) ? "vertical" : "horizontal"

    if (root.getOrientation() !== finalOrientation) {
      root = new PaneAxis({orientation: finalOrientation, children: [root]}, atom.views)
      container.setRoot(root)
    }

    // avoid automatic reparenting by pssing 2nd arg(= replacing ) to `true`.
    parent.removeChild(activePane, true)

    const indexToAdd = ["top", "left"].includes(direction) ? 0 : undefined
    root.addChild(activePane, indexToAdd)

    if (parent.getChildren().length === 1) {
      parent.reparentLastChild()
    }

    if (root !== originalRoot) {
      for (const paneAxis of getAllPaneAxis(root)) {
        const parent = paneAxis.getParent()
        if (parent instanceof PaneAxis && paneAxis.orientation === parent.orientation) {
          for (const [index, child] of paneAxis.getChildren().entries()) {
            if (index === 0) {
              parent.replaceChild(paneAxis, child)
            } else {
              parent.addChild(child, index)
            }
          }
          paneAxis.destroy()
        }
      }
    }

    activePane.activate()
  }
}
