_ = require 'underscore-plus'
{Range} = require 'atom'

getView = (model) -> atom.views.getView(model)

openFile = (filePath, options={}, fn=null) ->
  waitsForPromise ->
    atom.workspace.open(filePath, options).then (e) ->
      fn?(e)

getVisibleBufferRowRange = (e) ->
  getView(e).getVisibleRowRange().map (row) ->
    e.bufferRowForScreenRow row

splitPane = (direction) ->
  e = atom.workspace.getActiveTextEditor()
  atom.commands.dispatch(getView(e), "pane:split-#{direction}")

addCustomMatchers = (spec) ->
  spec.addMatchers
    toHaveSampeParent: (expected) ->
      @actual.getParent() is expected.getParent()

    toHaveScrollTop: (expected) ->
      getView(@actual).getScrollTop() is expected

    toHaveVisibleBufferRowRange: (expected) ->
      notText = if @isNot then " not" else ""
      actualRowRange = getVisibleBufferRowRange(@actual)
      this.message = ->
        "Expected object with visible row range #{jasmine.pp(actualRowRange)} to#{notText} have visible row range #{jasmine.pp(expected)}"
      _.isEqual(actualRowRange, expected)

describe "paner", ->
  [main, view, workspaceElement] = []
  [pathSample1, pathSample2] = []

  dispatchCommand = (command) ->
    atom.commands.dispatch(workspaceElement, command)

  beforeEach ->
    addCustomMatchers(this)

    activationPromise = null
    runs ->
      workspaceElement = getView(atom.workspace)
      pathSample1 = atom.project.resolvePath("sample-1.coffee")
      pathSample2 = atom.project.resolvePath("sample-2.coffee")
      jasmine.attachToDOM(workspaceElement)
      activationPromise = atom.packages.activatePackage('paner').then (pack) ->
        main = pack.mainModule
      dispatchCommand('paner:swap-item')

    waitsForPromise ->
      activationPromise

  describe "paner:maximize", ->
    describe "when maximized", ->
      it 'set css class to workspace element', ->
        dispatchCommand('paner:maximize')
        expect(workspaceElement.classList.contains('paner-maximize')).toBe(true)

    describe "when maximized again", ->
      beforeEach ->
        dispatchCommand('paner:maximize')
        expect(workspaceElement.classList.contains('paner-maximize')).toBe(true)

      it 'remove css class from workspace element', ->
        dispatchCommand('paner:maximize')
        expect(workspaceElement.classList.contains('paner-maximize')).toBe(false)

  describe "pane item manipulation", ->
    [panes, paneL, paneR, e1, e2] = []
    beforeEach ->
      openFile pathSample1, {}, (e) -> e1 = e
      openFile pathSample2, {split: 'right', activatePane: true}, (e) -> e2 = e

      runs ->
        panes = atom.workspace.getPanes()
        expect(panes).toHaveLength 2
        [paneL, paneR] = panes
        expect(paneL.getActiveItem()).toBe(e1)
        expect(paneR.getActiveItem()).toBe(e2)
        expect(atom.workspace.getActivePane()).toBe(paneR)

    describe "swap-item", ->
      it "swap activeItem to adjacent pane's activeItem", ->
        dispatchCommand('paner:swap-item')
        expect(paneL.getActiveItem()).toBe(e2)
        expect(paneR.getActiveItem()).toBe(e1)
        expect(atom.workspace.getActivePane()).toBe(paneR)

    describe "merge-item", ->
      it "move active item to adjacent pane and activate adjacent pane", ->
        dispatchCommand('paner:merge-item')
        expect(paneL.getItems()).toEqual([e1, e2])
        expect(paneR.getItems()).toEqual([])
        expect(paneL.getActiveItem()).toBe(e2)
        expect(atom.workspace.getActivePane()).toBe(paneL)
    describe "send-item", ->
      it "move active item to adjacent pane and don't change active pane", ->
        dispatchCommand('paner:send-item')
        expect(paneL.getItems()).toEqual([e1, e2])
        expect(paneR.getItems()).toEqual([])
        expect(paneL.getActiveItem()).toBe(e2)
        expect(atom.workspace.getActivePane()).toBe(paneR)

  describe "split", ->
    [editor, editorElement, pathSample, subs, newEditor] = []

    scroll = (e) ->
      el = getView(e)
      el.setScrollTop(el.getHeight())

    rowsPerPage = 10

    setRowsPerPage = (e, num) ->
      getView(e).setHeight(num * e.getLineHeightInPixels())

    onDidSplit = (fn) ->
      main.emitter.preempt 'did-pane-split', fn

    beforeEach ->
      pathSample = atom.project.resolvePath("sample")
      waitsForPromise ->
        atom.workspace.open(pathSample).then (e) ->
          editor = e
          setRowsPerPage(editor, rowsPerPage)
          editorElement = getView(editor)

      runs ->
        scroll(editor)
        editor.setCursorBufferPosition [16, 0]

    describe "split up/down", ->
      [newPane, oldPane, originalScrollTop] = []
      beforeEach ->
        originalScrollTop = editorElement.getScrollTop()
        onDidSplit (args) ->
          {newPane, oldPane} = args
          newEditor = newPane.getActiveEditor()
          setRowsPerPage(newEditor, rowsPerPage/2)

      afterEach ->
        expect(newPane).toHaveSampeParent(oldPane)
        expect(newPane.getParent().getOrientation()).toBe 'vertical'
        newEditorElement = getView(newEditor)
        expect(editor).toHaveScrollTop newEditorElement.getScrollTop()

      describe "split-up", ->
        it "split-up with keeping scroll ratio", ->
          dispatchCommand('paner:split-up')
          setRowsPerPage(editor, rowsPerPage/2)
          expect(atom.workspace.getPanes()).toEqual [newPane, oldPane]

      describe "split-down", ->
        it "split-down with keeping scroll ratio", ->
          dispatchCommand('paner:split-down')
          setRowsPerPage(editor, rowsPerPage/2)
          expect(atom.workspace.getPanes()).toEqual [oldPane, newPane]

    describe "split left/right", ->
      [newPane, oldPane, originalScrollTop] = []
      beforeEach ->
        originalScrollTop = editorElement.getScrollTop()
        onDidSplit (args) ->
          {newPane, oldPane} = args
          newEditor = newPane.getActiveEditor()
          setRowsPerPage(newEditor, rowsPerPage)

      afterEach ->
        expect(newPane).toHaveSampeParent(oldPane)
        expect(newPane.getParent().getOrientation()).toBe 'horizontal'
        newEditorElement = getView(newEditor)
        expect(editor).toHaveScrollTop newEditorElement.getScrollTop()
        expect(editor).toHaveScrollTop originalScrollTop

      describe "split left", ->
        it "split-left with keeping scroll ratio", ->
          dispatchCommand('paner:split-left')
          expect(atom.workspace.getPanes()).toEqual [newPane, oldPane]

      describe "split-right", ->
        it "split-right with keeping scroll ratio", ->
          dispatchCommand('paner:split-right')
          expect(atom.workspace.getPanes()).toEqual [oldPane, newPane]

  describe "moveToVery direction", ->
    [p1, p2, p3] = []
    [f1, f2, f3, f4] = []
    [e1, e2, e3, e4] = []

    moveToVery = ({initialPane, command}) ->
      initialPane.activate()
      dispatchCommand(command)

    ensurePaneLayout = (layout) ->
      pane = atom.workspace.getActivePane()
      root = pane.getContainer().getRoot()
      expect(paneLayoutFor(root)).toEqual(layout)

    paneLayoutFor = (root) ->
      layout = {}
      layout[root.getOrientation()] = root.getChildren().map (child) ->
        switch child.constructor.name
          when 'Pane' then child.getItems()
          when 'PaneAxis' then paneLayoutFor(child)
      layout

    beforeEach ->
      f1 = atom.project.resolvePath("file1")
      f2 = atom.project.resolvePath("file2")
      f3 = atom.project.resolvePath("file3")
      f4 = atom.project.resolvePath("file4")

    describe "all horizontal", ->
      beforeEach ->
        waitsForPromise -> atom.workspace.open(f1).then (e) -> e1 = e
        runs -> splitPane('right')
        waitsForPromise -> atom.workspace.open(f2).then (e) -> e2 = e
        runs -> splitPane('right')
        waitsForPromise -> atom.workspace.open(f3).then (e) -> e3 = e

        runs ->
          panes = atom.workspace.getPanes()
          expect(panes).toHaveLength(3)
          [p1, p2, p3] = panes
          ensurePaneLayout(horizontal: [[e1], [e2], [e3]])
          expect(atom.workspace.getActivePane()).toBe(p3)

      describe "very-top", ->
        it "case 1", ->
          moveToVery(initialPane: p1, command: 'paner:very-top')
          ensurePaneLayout(vertical: [[e1], {horizontal: [[e2], [e3]]}])
        it "case 2", ->
          moveToVery(initialPane: p2, command: 'paner:very-top')
          ensurePaneLayout(vertical: [[e2], {horizontal: [[e1], [e3]]}])
        it "case 3", ->
          moveToVery(initialPane: p3, command: 'paner:very-top')
          ensurePaneLayout(vertical: [[e3], {horizontal: [[e1], [e2]]}])

      describe "very-bottom", ->
        it "case 1", ->
          moveToVery(initialPane: p1, command: 'paner:very-bottom')
          ensurePaneLayout(vertical: [{horizontal: [[e2], [e3]]}, [e1]])
        it "case 2", ->
          moveToVery(initialPane: p2, command: 'paner:very-bottom')
          ensurePaneLayout(vertical: [{horizontal: [[e1], [e3]]}, [e2]])
        it "case 3", ->
          moveToVery(initialPane: p3, command: 'paner:very-bottom')
          ensurePaneLayout(vertical: [{horizontal: [[e1], [e2]]}, [e3]])

      describe "very-left", ->
        it "case 1", ->
          moveToVery(initialPane: p1, command: 'paner:very-left')
          ensurePaneLayout(horizontal: [[e1], [e2], [e3]])
        it "case 2", ->
          moveToVery(initialPane: p2, command: 'paner:very-left')
          ensurePaneLayout(horizontal: [[e2], [e1], [e3]])
        it "case 3", ->
          moveToVery(initialPane: p3, command: 'paner:very-left')
          ensurePaneLayout(horizontal: [[e3], [e1], [e2]])

      describe "very-right", ->
        it "case 1", ->
          moveToVery(initialPane: p1, command: 'paner:very-right')
          ensurePaneLayout(horizontal: [[e2], [e3], [e1]])
        it "case 2", ->
          moveToVery(initialPane: p2, command: 'paner:very-right')
          ensurePaneLayout(horizontal: [[e1], [e3], [e2]])
        it "case 3", ->
          moveToVery(initialPane: p3, command: 'paner:very-right')
          ensurePaneLayout(horizontal: [[e1], [e2], [e3]])

      describe "complex operation", ->
        it "case 1", ->
          p1.activate()
          dispatchCommand('paner:very-top')
          ensurePaneLayout(vertical: [[e1], {horizontal: [[e2], [e3]]}])
          dispatchCommand('paner:very-left')
          ensurePaneLayout(horizontal: [[e1], [e2], [e3]])
          dispatchCommand('paner:very-bottom')
          ensurePaneLayout(vertical: [{horizontal: [[e2], [e3]]}, [e1]])
          dispatchCommand('paner:very-right')
          ensurePaneLayout(horizontal: [[e2], [e3], [e1]])

    describe "all vertical", ->
      beforeEach ->
        waitsForPromise -> atom.workspace.open(f1).then (e) -> e1 = e
        runs -> splitPane('down')
        waitsForPromise -> atom.workspace.open(f2).then (e) -> e2 = e
        runs -> splitPane('down')
        waitsForPromise -> atom.workspace.open(f3).then (e) -> e3 = e

        runs ->
          panes = atom.workspace.getPanes()
          expect(panes).toHaveLength(3)
          [p1, p2, p3] = panes
          ensurePaneLayout(vertical: [[e1], [e2], [e3]])
          expect(atom.workspace.getActivePane()).toBe(p3)

      describe "very-top", ->
        it "case 1", ->
          moveToVery(initialPane: p1, command: 'paner:very-top')
          ensurePaneLayout(vertical: [[e1], [e2], [e3]])
        it "case 2", ->
          moveToVery(initialPane: p2, command: 'paner:very-top')
          ensurePaneLayout(vertical: [[e2], [e1], [e3]])
        it "case 3", ->
          moveToVery(initialPane: p3, command: 'paner:very-top')
          ensurePaneLayout(vertical: [[e3], [e1], [e2]])

      describe "very-bottom", ->
        it "case 1", ->
          moveToVery(initialPane: p1, command: 'paner:very-bottom')
          ensurePaneLayout(vertical: [[e2], [e3], [e1]])
        it "case 2", ->
          moveToVery(initialPane: p2, command: 'paner:very-bottom')
          ensurePaneLayout(vertical: [[e1], [e3], [e2]])
        it "case 3", ->
          moveToVery(initialPane: p3, command: 'paner:very-bottom')
          ensurePaneLayout(vertical: [[e1], [e2], [e3]])

      describe "very-left", ->
        it "case 1", ->
          moveToVery(initialPane: p1, command: 'paner:very-left')
          ensurePaneLayout(horizontal: [[e1], {vertical: [[e2], [e3]]}])
        it "case 2", ->
          moveToVery(initialPane: p2, command: 'paner:very-left')
          ensurePaneLayout(horizontal: [[e2], {vertical: [[e1], [e3]]}])
        it "case 3", ->
          moveToVery(initialPane: p3, command: 'paner:very-left')
          ensurePaneLayout(horizontal: [[e3], {vertical: [[e1], [e2]]}])

      describe "very-right", ->
        it "case 1", ->
          moveToVery(initialPane: p1, command: 'paner:very-right')
          ensurePaneLayout(horizontal: [{vertical: [[e2], [e3]]}, [e1]])
        it "case 2", ->
          moveToVery(initialPane: p2, command: 'paner:very-right')
          ensurePaneLayout(horizontal: [{vertical: [[e1], [e3]]}, [e2]])
        it "case 3", ->
          moveToVery(initialPane: p3, command: 'paner:very-right')
          ensurePaneLayout(horizontal: [{vertical: [[e1], [e2]]}, [e3]])

      describe "complex operation", ->
        it "case 1", ->
          p1.activate()
          dispatchCommand('paner:very-top')
          ensurePaneLayout(vertical: [[e1], [e2], [e3]])
          dispatchCommand('paner:very-left')
          ensurePaneLayout(horizontal: [[e1], {vertical: [[e2], [e3]]}])
          dispatchCommand('paner:very-bottom')
          ensurePaneLayout(vertical: [[e2], [e3], [e1]])
          dispatchCommand('paner:very-right')
          ensurePaneLayout(horizontal: [{vertical: [[e2], [e3]]}, [e1]])

    describe "swapPane", ->
      beforeEach ->
        waitsForPromise -> atom.workspace.open(f1).then (e) -> e1 = e
        runs -> splitPane('right')
        waitsForPromise -> atom.workspace.open(f2).then (e) -> e2 = e
        waitsForPromise -> atom.workspace.open(f3).then (e) -> e3 = e
        runs -> splitPane('down')
        waitsForPromise -> atom.workspace.open(f4).then (e) -> e4 = e

        runs ->
          panes = atom.workspace.getPanes()
          expect(panes).toHaveLength(3)
          [p1, p2, p3] = panes
          ensurePaneLayout
            horizontal: [
              [e1]
              vertical: [[e2, e3], [e4]]
            ]
          expect(atom.workspace.getActivePane()).toBe(p3)
          expect(atom.workspace.getActiveTextEditor()).toBe(e4)

      it "case 1", ->
        dispatchCommand('paner:swap-pane')
        ensurePaneLayout
          horizontal: [
            [e1]
            vertical: [[e4], [e2, e3]]
          ]
        expect(atom.workspace.getActiveTextEditor()).toBe(e4)

        dispatchCommand('paner:swap-pane')
        ensurePaneLayout
          horizontal: [
            [e1]
            vertical: [[e2, e3], [e4]]
          ]
        expect(atom.workspace.getActiveTextEditor()).toBe(e4)

        p1.activate() # p1 is pane represented as [e1]
        dispatchCommand('paner:swap-pane')
        ensurePaneLayout
          horizontal: [
            vertical: [[e2, e3], [e4]]
            [e1]
          ]
        expect(atom.workspace.getActiveTextEditor()).toBe(e1)

        dispatchCommand('paner:swap-pane')
        ensurePaneLayout
          horizontal: [
            [e1]
            vertical: [[e2, e3], [e4]]
          ]
        expect(atom.workspace.getActiveTextEditor()).toBe(e1)
