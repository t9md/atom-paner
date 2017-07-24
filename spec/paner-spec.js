'use babel'

const {Range} = require("atom")
const {
  it,
  fit,
  ffit,
  fffit,
  emitterEventPromise,
  beforeEach,
  afterEach,
} = require("./async-spec-helpers")

function getView(model) {
  return atom.views.getView(model)
}

function dispatchCommand(commandName) {
  atom.commands.dispatch(atom.workspace.getElement(), commandName)
}

describe("paner", function() {
  beforeEach(() => {
    // `destroyEmptyPanes` is default true, but atom's spec-helper reset to `false`
    // So set it to `true` again here to test with default value.
    atom.config.set("core.destroyEmptyPanes", true)
    jasmine.attachToDOM(atom.workspace.getElement())

    const activationPromise = atom.packages.activatePackage("paner")
    dispatchCommand("paner:exchange-pane")
    return activationPromise
  })

  describe("pane item manipulation", () => {
    let e1, e2, e3, e4, p1, p2
    beforeEach(async () => {
      e1 = await atom.workspace.open("file1")
      e2 = await atom.workspace.open("file2")
      e3 = await atom.workspace.open("file3", {split: "right"})
      e4 = await atom.workspace.open("file4")
      const panes = atom.workspace.getCenter().getPanes()
      expect(panes).toHaveLength(2)
      ;[p1, p2] = panes

      p1.activate()
      p1.activateItem(e1)
      p2.activateItem(e3)

      expect(p1.getItems()).toEqual([e1, e2])
      expect(p1.getActiveItem()).toBe(e1)
      expect(p2.getItems()).toEqual([e3, e4])
      expect(p2.getActiveItem()).toBe(e3)
      expect(atom.workspace.getActivePane()).toBe(p1)
    })

    describe("move-pane-item family", () => {
      describe("move-pane-item", () => {
        it("move active item to adjacent pane and don't change active pane", async () => {
          dispatchCommand("paner:move-pane-item")
          expect(p1.getItems()).toEqual([e2])
          expect(p1.getActiveItem()).toBe(e2)
          expect(p2.getItems()).toEqual([e3, e4, e1])
          expect(p2.getActiveItem()).toBe(e1)
          expect(atom.workspace.getActivePane()).toBe(p2)

          dispatchCommand("paner:move-pane-item")
          expect(p1.getItems()).toEqual([e2, e1])
          expect(p1.getActiveItem()).toBe(e1)
          expect(p2.getItems()).toEqual([e3, e4])
          expect(p2.getActiveItem()).toBe(e4)
          expect(atom.workspace.getActivePane()).toBe(p1)
        })
      })

      describe("move-pane-item-stay", () => {
        it("move active item to adjacent pane and don't change active pane", async () => {
          dispatchCommand("paner:move-pane-item-stay")
          expect(p1.getItems()).toEqual([e2])
          expect(p1.getActiveItem()).toBe(e2)
          expect(p2.getItems()).toEqual([e3, e4, e1])
          expect(p2.getActiveItem()).toBe(e1)
          expect(atom.workspace.getActivePane()).toBe(p1)

          dispatchCommand("paner:move-pane-item-stay")
          expect(p2.getItems()).toEqual([e3, e4, e1, e2])
          expect(p2.getActiveItem()).toBe(e2)
          expect(atom.workspace.getActivePane()).toBe(p2)
          expect(p1.isAlive()).toBe(false)
        })
      })
    })
  })

  xdescribe("split", () => {
    let [editor, editorElement, subs, newEditor] = Array.from([])

    const scroll = function(e) {
      const el = getView(e)
      return el.setScrollTop(el.getHeight())
    }

    const rowsPerPage = 10

    const setRowsPerPage = (e, num) => getView(e).setHeight(num * e.getLineHeightInPixels())

    const onDidSplit = fn => main.emitter.preempt("did-split-pane", fn)

    beforeEach(async () => {
      const pathSample = atom.project.resolvePath("sample")
      waitsForPromise(() =>
        atom.workspace.open(pathSample).then(function(e) {
          editor = e
          setRowsPerPage(editor, rowsPerPage)
          return (editorElement = getView(editor))
        })
      )

      return runs(function() {
        scroll(editor)
        return editor.setCursorBufferPosition([16, 0])
      })
    })

    fdescribe("split up/down", function() {
      let [newPane, oldPane, originalScrollTop] = Array.from([])
      beforeEach(function() {
        originalScrollTop = editorElement.getScrollTop()
        return onDidSplit(function(args) {
          ;({newPane, oldPane} = args)
          newEditor = newPane.getActiveEditor()
          return setRowsPerPage(newEditor, rowsPerPage / 2)
        })
      })

      afterEach(function() {
        expect(newPane).toHaveSampeParent(oldPane)
        expect(newPane.getParent().getOrientation()).toBe("vertical")
        const newEditorElement = getView(newEditor)
        return expect(editor).toHaveScrollTop(newEditorElement.getScrollTop())
      })

      describe("split-up", () =>
        it("split-up with keeping scroll ratio", function() {
          dispatchCommand("paner:split-pane-up")
          setRowsPerPage(editor, rowsPerPage / 2)
          return expect(atom.workspace.getPanes()).toEqual([newPane, oldPane])
        }))

      return describe("split-down", () =>
        it("split-down with keeping scroll ratio", function() {
          dispatchCommand("paner:split-down")
          setRowsPerPage(editor, rowsPerPage / 2)
          return expect(atom.workspace.getPanes()).toEqual([oldPane, newPane])
        }))
    })

    return describe("split left/right", function() {
      let [newPane, oldPane, originalScrollTop] = Array.from([])
      beforeEach(function() {
        originalScrollTop = editorElement.getScrollTop()
        return onDidSplit(function(args) {
          ;({newPane, oldPane} = args)
          newEditor = newPane.getActiveEditor()
          return setRowsPerPage(newEditor, rowsPerPage)
        })
      })

      afterEach(function() {
        expect(newPane).toHaveSampeParent(oldPane)
        expect(newPane.getParent().getOrientation()).toBe("horizontal")
        const newEditorElement = getView(newEditor)
        expect(editor).toHaveScrollTop(newEditorElement.getScrollTop())
        return expect(editor).toHaveScrollTop(originalScrollTop)
      })

      describe("split left", () =>
        it("split-left with keeping scroll ratio", function() {
          dispatchCommand("paner:split-left")
          return expect(atom.workspace.getPanes()).toEqual([newPane, oldPane])
        }))

      return describe("split-right", () =>
        it("split-right with keeping scroll ratio", function() {
          dispatchCommand("paner:split-right")
          return expect(atom.workspace.getPanes()).toEqual([oldPane, newPane])
        }))
    })
  })

  describe("moveToVery direction", function() {
    function ensurePaneLayout(layout) {
      const root = atom.workspace.getActivePane().getContainer().getRoot()
      expect(paneLayoutFor(root)).toEqual(layout)
    }

    function paneLayoutFor(root) {
      const layout = {}
      layout[root.getOrientation()] = root.getChildren().map(child => {
        switch (child.constructor.name) {
          case "Pane":
            return child.getItems()
          case "PaneAxis":
            return paneLayoutFor(child)
        }
      })
      return layout
    }

    describe("all horizontal", () => {
      let e1, e2, e3, p1, p2, p3
      beforeEach(async () => {
        e1 = await atom.workspace.open("file1")
        e2 = await atom.workspace.open("file2", {split: "right"})
        e3 = await atom.workspace.open("file3", {split: "right"})
        const panes = atom.workspace.getCenter().getPanes()
        expect(panes).toHaveLength(3)
        ;[p1, p2, p3] = panes
        ensurePaneLayout({horizontal: [[e1], [e2], [e3]]})
        expect(atom.workspace.getActivePane()).toBe(p3)
      })

      describe("very-top", () => {
        it("case 1", () => {
          p1.activate()
          dispatchCommand("paner:move-pane-to-very-top")
          ensurePaneLayout({vertical: [[e1], {horizontal: [[e2], [e3]]}]})
        })
        it("case 2", () => {
          p2.activate()
          dispatchCommand("paner:move-pane-to-very-top")
          ensurePaneLayout({vertical: [[e2], {horizontal: [[e1], [e3]]}]})
        })
        it("case 3", () => {
          p3.activate()
          dispatchCommand("paner:move-pane-to-very-top")
          ensurePaneLayout({vertical: [[e3], {horizontal: [[e1], [e2]]}]})
        })
      })

      describe("very-bottom", () => {
        it("case 1", () => {
          p1.activate()
          dispatchCommand("paner:move-pane-to-very-bottom")
          ensurePaneLayout({vertical: [{horizontal: [[e2], [e3]]}, [e1]]})
        })
        it("case 2", () => {
          p2.activate()
          dispatchCommand("paner:move-pane-to-very-bottom")
          ensurePaneLayout({vertical: [{horizontal: [[e1], [e3]]}, [e2]]})
        })
        it("case 3", () => {
          p3.activate()
          dispatchCommand("paner:move-pane-to-very-bottom")
          ensurePaneLayout({vertical: [{horizontal: [[e1], [e2]]}, [e3]]})
        })
      })

      describe("very-left", () => {
        it("case 1", () => {
          p1.activate()
          dispatchCommand("paner:move-pane-to-very-left")
          ensurePaneLayout({horizontal: [[e1], [e2], [e3]]})
        })
        it("case 2", () => {
          p2.activate()
          dispatchCommand("paner:move-pane-to-very-left")
          ensurePaneLayout({horizontal: [[e2], [e1], [e3]]})
        })
        it("case 3", () => {
          p3.activate()
          dispatchCommand("paner:move-pane-to-very-left")
          ensurePaneLayout({horizontal: [[e3], [e1], [e2]]})
        })
      })

      describe("very-right", () => {
        it("case 1", () => {
          p1.activate()
          dispatchCommand("paner:move-pane-to-very-right")
          ensurePaneLayout({horizontal: [[e2], [e3], [e1]]})
        })
        it("case 2", () => {
          p2.activate()
          dispatchCommand("paner:move-pane-to-very-right")
          ensurePaneLayout({horizontal: [[e1], [e3], [e2]]})
        })
        it("case 3", () => {
          p3.activate()
          dispatchCommand("paner:move-pane-to-very-right")
          ensurePaneLayout({horizontal: [[e1], [e2], [e3]]})
        })
      })

      describe("complex operation", () => {
        it("case 1", () => {
          p1.activate()
          dispatchCommand("paner:move-pane-to-very-top")
          ensurePaneLayout({vertical: [[e1], {horizontal: [[e2], [e3]]}]})
          dispatchCommand("paner:move-pane-to-very-left")
          ensurePaneLayout({horizontal: [[e1], [e2], [e3]]})
          dispatchCommand("paner:move-pane-to-very-bottom")
          ensurePaneLayout({vertical: [{horizontal: [[e2], [e3]]}, [e1]]})
          dispatchCommand("paner:move-pane-to-very-right")
          ensurePaneLayout({horizontal: [[e2], [e3], [e1]]})
        })
      })
    })

    describe("all vertical", () => {
      let e1, e2, e3, p1, p2, p3
      beforeEach(async () => {
        e1 = await atom.workspace.open("file1")
        e2 = await atom.workspace.open("file2", {split: "down"})
        e3 = await atom.workspace.open("file3", {split: "down"})
        const panes = atom.workspace.getCenter().getPanes()
        expect(panes).toHaveLength(3)
        ;[p1, p2, p3] = panes
        ensurePaneLayout({vertical: [[e1], [e2], [e3]]})
        expect(atom.workspace.getActivePane()).toBe(p3)
      })

      describe("very-top", () => {
        it("case 1", () => {
          p1.activate()
          dispatchCommand("paner:move-pane-to-very-top")
          ensurePaneLayout({vertical: [[e1], [e2], [e3]]})
        })
        it("case 2", () => {
          p2.activate()
          dispatchCommand("paner:move-pane-to-very-top")
          ensurePaneLayout({vertical: [[e2], [e1], [e3]]})
        })
        it("case 3", () => {
          p3.activate()
          dispatchCommand("paner:move-pane-to-very-top")
          ensurePaneLayout({vertical: [[e3], [e1], [e2]]})
        })
      })

      describe("very-bottom", () => {
        it("case 1", () => {
          p1.activate()
          dispatchCommand("paner:move-pane-to-very-bottom")
          ensurePaneLayout({vertical: [[e2], [e3], [e1]]})
        })
        it("case 2", () => {
          p2.activate()
          dispatchCommand("paner:move-pane-to-very-bottom")
          ensurePaneLayout({vertical: [[e1], [e3], [e2]]})
        })
        it("case 3", () => {
          p3.activate()
          dispatchCommand("paner:move-pane-to-very-bottom")
          ensurePaneLayout({vertical: [[e1], [e2], [e3]]})
        })
      })

      describe("very-left", () => {
        it("case 1", () => {
          p1.activate()
          dispatchCommand("paner:move-pane-to-very-left")
          ensurePaneLayout({horizontal: [[e1], {vertical: [[e2], [e3]]}]})
        })
        it("case 2", () => {
          p2.activate()
          dispatchCommand("paner:move-pane-to-very-left")
          ensurePaneLayout({horizontal: [[e2], {vertical: [[e1], [e3]]}]})
        })
        it("case 3", () => {
          p3.activate()
          dispatchCommand("paner:move-pane-to-very-left")
          ensurePaneLayout({horizontal: [[e3], {vertical: [[e1], [e2]]}]})
        })
      })

      describe("very-right", () => {
        it("case 1", () => {
          p1.activate()
          dispatchCommand("paner:move-pane-to-very-right")
          ensurePaneLayout({horizontal: [{vertical: [[e2], [e3]]}, [e1]]})
        })
        it("case 2", () => {
          p2.activate()
          dispatchCommand("paner:move-pane-to-very-right")
          ensurePaneLayout({horizontal: [{vertical: [[e1], [e3]]}, [e2]]})
        })
        it("case 3", () => {
          p3.activate()
          dispatchCommand("paner:move-pane-to-very-right")
          ensurePaneLayout({horizontal: [{vertical: [[e1], [e2]]}, [e3]]})
        })
      })

      describe("complex operation", () =>
        it("case 1", () => {
          p1.activate()
          dispatchCommand("paner:move-pane-to-very-top")
          ensurePaneLayout({vertical: [[e1], [e2], [e3]]})
          dispatchCommand("paner:move-pane-to-very-left")
          ensurePaneLayout({horizontal: [[e1], {vertical: [[e2], [e3]]}]})
          dispatchCommand("paner:move-pane-to-very-bottom")
          ensurePaneLayout({vertical: [[e2], [e3], [e1]]})
          dispatchCommand("paner:move-pane-to-very-right")
          ensurePaneLayout({horizontal: [{vertical: [[e2], [e3]]}, [e1]]})
        }))
    })

    describe("exchange-pane family", function() {
      let p1, p2, p3, items
      beforeEach(async () => {
        const e1 = await atom.workspace.open("file1")
        const e2 = await atom.workspace.open("file2", {split: "right"})
        const e3 = await atom.workspace.open("file3")
        const e4 = await atom.workspace.open("file4", {split: "down"})
        const panes = atom.workspace.getCenter().getPanes()
        expect(panes).toHaveLength(3)
        ;[p1, p2, p3] = panes
        items = {
          p1: p1.getItems(),
          p2: p2.getItems(),
          p3: p3.getItems(),
        }
        expect(items).toEqual({
          p1: [e1],
          p2: [e2, e3],
          p3: [e4],
        })

        ensurePaneLayout({horizontal: [items.p1, {vertical: [items.p2, items.p3]}]})
        expect(atom.workspace.getActivePane()).toBe(p3)
      })

      describe("exchange-pane", () => {
        it("[adjacent is pane]: exchange pane, follow active pane", () => {
          dispatchCommand("paner:exchange-pane")
          ensurePaneLayout({horizontal: [items.p1, {vertical: [items.p3, items.p2]}]})
          expect(atom.workspace.getActivePane()).toBe(p3)

          dispatchCommand("paner:exchange-pane")
          ensurePaneLayout({horizontal: [items.p1, {vertical: [items.p2, items.p3]}]})
          expect(atom.workspace.getActivePane()).toBe(p3)
        })

        it("[adjacent is paneAxis]: exchange pane, when follow active pane", () => {
          p1.activate()
          dispatchCommand("paner:exchange-pane")
          ensurePaneLayout({horizontal: [{vertical: [items.p2, items.p3]}, items.p1]})
          expect(atom.workspace.getActivePane()).toBe(p1)

          dispatchCommand("paner:exchange-pane")
          ensurePaneLayout({horizontal: [items.p1, {vertical: [items.p2, items.p3]}]})
          expect(atom.workspace.getActivePane()).toBe(p1)
        })
      })

      describe("exchange-pane-stay", () => {
        it("[adjacent is pane]: exchange pane and and stay active pane", () => {
          dispatchCommand("paner:exchange-pane-stay")
          ensurePaneLayout({horizontal: [items.p1, {vertical: [items.p3, items.p2]}]})
          expect(atom.workspace.getActivePane()).toBe(p2)

          dispatchCommand("paner:exchange-pane-stay")
          ensurePaneLayout({horizontal: [items.p1, {vertical: [items.p2, items.p3]}]})
          expect(atom.workspace.getActivePane()).toBe(p3)
        })

        it("[adjacent is paneAxis]: Do nothing when adjacent was paneAxis", () => {
          p1.activate()
          dispatchCommand("paner:exchange-pane-stay")
          ensurePaneLayout({horizontal: [items.p1, {vertical: [items.p2, items.p3]}]})
          expect(atom.workspace.getActivePane()).toBe(p1)
        })
      })
    })
  })
})
