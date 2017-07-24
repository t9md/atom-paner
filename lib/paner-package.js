const {CompositeDisposable} = require("atom")
let PaneAxis = null

// Return adjacent pane of activePane within current PaneAxis.
//  * return next Pane if exists.
//  * return previous pane if next pane was not exits.
function getAdjacentPane(pane) {
  const activePane = atom.workspace.getActivePane()
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

module.exports = class PanerPackage {
  activate() {
    this.subscriptions = new CompositeDisposable()

    this.subscriptions.add(
      atom.commands.add("atom-workspace", {
        "paner:send-pane-item": () => this.sendPaneItem(),

        "paner:exchange-pane": () => this.exchangePane(),

        "paner:split-pane-up": () => this.splitPane("Up"),
        "paner:split-pane-down": () => this.splitPane("Down"),
        "paner:split-pane-left": () => this.splitPane("Left"),
        "paner:split-pane-right": () => this.splitPane("Right"),

        "paner:split-pane-up-keep-active-pane": () => this.splitPane("Up", {keepActivePane: true}),
        "paner:split-pane-down-keep-active-pane": () => this.splitPane("Down", {keepActivePane: true}),
        "paner:split-pane-left-keep-active-pane": () => this.splitPane("Left", {keepActivePane: true}),
        "paner:split-pane-right-keep-active-pane": () => this.splitPane("Right", {keepActivePane: true}),

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
  splitPane(direction, {keepActivePane = false} = {}) {
    const activePane = atom.workspace.getActivePane()
    const activeEditor = activePane.getActiveEditor()
    const newPane = activePane[`split${direction}`]({copyActiveItem: true})

    // Currently Pane cannot be created without initially activate.
    // So I revert activate pane manually if needed.
    if (keepActivePane) {
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

  sendPaneItem() {
    const activePane = atom.workspace.getActivePane()
    const adjacentPane = getAdjacentPane(activePane)
    if (adjacentPane) {
      const activeItem = activePane.getActiveItem()
      activePane.moveItemToPane(activeItem, adjacentPane, adjacentPane.getItems().length)
      adjacentPane.activateItem(activeItem)
    }
  }

  // Exchange activePane with adjacentPane
  // Original adjacentPane become activePane finally.
  exchangePane() {
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
