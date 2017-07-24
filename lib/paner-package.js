'use babel'

const {CompositeDisposable} = require("atom")
let PaneAxis = null

// Return adjacent pane of activePane within current PaneAxis.
//  * return next Pane if exists.
//  * return previous pane if next pane was not exits.
function getAdjacentPane(pane) {
  const parent = pane.getParent()
  if (!parent || !parent.getChildren) return
  const children = pane.getParent().getChildren()
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

module.exports = class PanerPackage {
  activate() {
    this.subscriptions = new CompositeDisposable()

    this.subscriptions.add(
      atom.commands.add("atom-workspace", {
        "paner:move-pane-item": () => this.movePaneItem(),
        "paner:move-pane-item-stay": () => this.movePaneItem({stay: true}),

        "paner:exchange-pane": () => this.exchangePane(),
        "paner:exchange-pane-stay": () => this.exchangePane({stay: true}),

        "paner:split-pane-up": () => this.splitPane("Up"),
        "paner:split-pane-down": () => this.splitPane("Down"),
        "paner:split-pane-left": () => this.splitPane("Left"),
        "paner:split-pane-right": () => this.splitPane("Right"),

        "paner:split-pane-up-stay": () => this.splitPane("Up", {stay: true}),
        "paner:split-pane-down-stay": () => this.splitPane("Down", {stay: true}),
        "paner:split-pane-left-stay": () => this.splitPane("Left", {stay: true}),
        "paner:split-pane-right-stay": () => this.splitPane("Right", {stay: true}),

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
  splitPane(direction, {stay = false} = {}) {
    const activePane = atom.workspace.getActivePane()
    const activeEditor = activePane.getActiveEditor()
    const newPane = activePane[`split${direction}`]({copyActiveItem: true})

    // Currently Pane cannot be created without initially activate.
    // So I revert activate pane manually if needed.
    if (stay) {
      activePane.activate()
    }

    if (!activeEditor) return

    const oldEditor = activeEditor
    const newEditor = newPane.getActiveEditor()
    switch (direction) {
      case "Right":
      case "Left":
        // FIXME: Not perfectly work when lastBufferRow is visible.
        const firstVisibleScreenRow = oldEditor.getFirstVisibleScreenRow()
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

  movePaneItem({stay = false} = {}) {
    const activePane = atom.workspace.getActivePane()
    const adjacentPane = getAdjacentPane(activePane)
    if (adjacentPane) {
      const activeItem = activePane.getActiveItem()
      activePane.moveItemToPane(activeItem, adjacentPane, adjacentPane.getItems().length)
      adjacentPane.activateItem(activeItem)
      if (!stay) {
        adjacentPane.activate()
      }
    }
  }

  // Exchange activePane with adjacentPane
  exchangePane({stay = false} = {}) {
    const activePane = atom.workspace.getActivePane()
    const adjacentPane = getAdjacentPane(activePane)
    if (!adjacentPane) return
    if (stay && adjacentPane.children) {
      // adjacent was paneAxis
      return
    }

    const parent = activePane.getParent()
    const children = parent.getChildren()

    if (children.indexOf(activePane) < children.indexOf(adjacentPane)) {
      parent.removeChild(activePane, true)
      parent.insertChildAfter(adjacentPane, activePane)
    } else {
      parent.removeChild(activePane, true)
      parent.insertChildBefore(adjacentPane, activePane)
    }

    if (stay) {
      adjacentPane.activate()
    } else {
      activePane.activate()
    }
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

    for (const paneAxis of getAllPaneAxis(root)) {
      const parent = paneAxis.getParent()
      if (parent instanceof PaneAxis && paneAxis.getOrientation() === parent.getOrientation()) {
        let lastChild
        for (const child of paneAxis.getChildren()) {
          if (!lastChild) {
            parent.replaceChild(paneAxis, child)
          } else {
            parent.insertChildAfter(lastChild, child)
          }
          lastChild = child
        }
        paneAxis.destroy()
      }
    }

    activePane.activate()
  }
}
