_ = require 'underscore-plus'

{
  setConfig, openFile,
  getVisibleBufferRowRange, getVisibleBufferRange,
  getView,
} = require './spec-helper'


describe "paner", ->
  [main, view, workspaceElement] = []
  [pathSample1, pathSample2] = []

  dispatchCommand = (command) ->
    atom.commands.dispatch(workspaceElement, "paner:#{command}")

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

  beforeEach ->
    addCustomMatchers(this)

    activationPromise = null
    runs ->
      workspaceElement = getView(atom.workspace)
      pathSample1 = atom.project.resolvePath "sample-1.coffee"
      pathSample2 = atom.project.resolvePath "sample-2.coffee"
      jasmine.attachToDOM(workspaceElement)
      activationPromise = atom.packages.activatePackage('paner').then (pack) ->
        main = pack.mainModule
      dispatchCommand('swap-item')

    waitsForPromise ->
      activationPromise

  describe "paner:maximize", ->
    describe "when maximized", ->
      it 'set css class to workspace element', ->
        dispatchCommand('maximize')
        expect(workspaceElement.classList.contains('paner-maximize')).toBe(true)

    describe "when maximized again", ->
      beforeEach ->
        dispatchCommand('maximize')
        expect(workspaceElement.classList.contains('paner-maximize')).toBe(true)

      it 'remove css class from workspace element', ->
        dispatchCommand('maximize')
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
        expect(paneL.getActiveItem()).toBe e1
        expect(paneR.getActiveItem()).toBe e2
        expect(atom.workspace.getActivePane()).toBe paneR

    describe "swap-item", ->
      it "swap activeItem to adjacent pane's activeItem", ->
        dispatchCommand('swap-item')
        expect(paneL.getActiveItem()).toBe e2
        expect(paneR.getActiveItem()).toBe e1
        expect(atom.workspace.getActivePane()).toBe paneR

    describe "merge-item", ->
      it "move active item to adjacent pane and activate adjacent pane", ->
        dispatchCommand('merge-item')
        expect(paneL.getItems()).toEqual [e1, e2]
        expect(paneR.getItems()).toEqual []
        expect(paneL.getActiveItem()).toBe e2
        expect(atom.workspace.getActivePane()).toBe paneL
    describe "send-item", ->
      it "move active item to adjacent pane and don't change active pane", ->
        dispatchCommand('send-item')
        expect(paneL.getItems()).toEqual [e1, e2]
        expect(paneR.getItems()).toEqual []
        expect(paneL.getActiveItem()).toBe e2
        expect(atom.workspace.getActivePane()).toBe paneR

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
        # expect(newEditor).toHaveVisibleBufferRowRange [14, 18]

      describe "split-up", ->
        it "split-up with keeping scroll ratio", ->
          dispatchCommand('split-up')
          setRowsPerPage(editor, rowsPerPage/2)
          expect(atom.workspace.getPanes()).toEqual [newPane, oldPane]

      describe "split-down", ->
        it "split-down with keeping scroll ratio", ->
          dispatchCommand('split-down')
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
        # expect(editor).toHaveVisibleBufferRowRange [10, 19]

      describe "split left", ->
        it "split-left with keeping scroll ratio", ->
          dispatchCommand('split-left')
          expect(atom.workspace.getPanes()).toEqual [newPane, oldPane]

      describe "split-right", ->
        it "split-right with keeping scroll ratio", ->
          dispatchCommand('split-right')
          expect(atom.workspace.getPanes()).toEqual [oldPane, newPane]

  describe "moveToVery direction", ->
    [p1, p2, p3] = []
    [f1, f2, f3] = []
    split = (direction) ->
      e = atom.workspace.getActiveTextEditor()
      atom.commands.dispatch(getView(e), "pane:split-#{direction}")

    getPanePaths = ->
      atom.workspace.getPanes().map((p) -> p.getActiveItem().getPath())

    getPaneOrientations = ->
      atom.workspace.getPanes().map((p) -> p.getParent().getOrientation())

    expectPanePaths = ({active, command, paths, orientaions}) ->
      active.activate()
      dispatchCommand(command)
      expect(getPanePaths()).toEqual paths
      if orientaions?
        expect(getPaneOrientations()).toEqual orientaions

    beforeEach ->
      f1 = atom.project.resolvePath("file1")
      f2 = atom.project.resolvePath("file2")
      f3 = atom.project.resolvePath("file3")

    describe "all horizontal", ->
      beforeEach ->
        waitsForPromise -> atom.workspace.open(f1)
        runs -> split('right')
        waitsForPromise -> atom.workspace.open(f2)
        runs -> split('right')
        waitsForPromise -> atom.workspace.open(f3)

        runs ->
          panes = atom.workspace.getPanes()
          expect(panes).toHaveLength 3
          [p1, p2, p3] = panes
          expect(p1.getParent().getOrientation()).toBe 'horizontal'
          expect(atom.workspace.getActivePane()).toBe p3
          expect(getPanePaths()).toEqual [f1, f2, f3]

      describe "very-top", ->
        command = 'very-top'
        orientations = ['vertical', 'horizontal', 'horizontal']
        describe "when p1 is active", ->
          it "move to very top", ->
            expectPanePaths({active: p1, command, paths: [f1, f2, f3], orientations})
        describe "when p2 is active", ->
          it "move to very top", ->
            expectPanePaths({active: p2, command, paths: [f2, f1, f3], orientations})
        describe "when p3 is active", ->
          it "move to very top", ->
            expectPanePaths({active: p3, command, paths: [f3, f1, f2], orientations})

      describe "very-bottom", ->
        command = 'very-bottom'
        orientations = ['horizontal', 'horizontal', 'vertical']
        describe "when p1 is active", ->
          it "move to very bottom", ->
            expectPanePaths({active: p1, command, paths: [f2, f3, f1], orientations})
        describe "when p2 is active", ->
          it "move to very bottom", ->
            expectPanePaths({active: p2, command, paths: [f1, f3, f2], orientations})
        describe "when p3 is active", ->
          it "move to very bottom", ->
            expectPanePaths({active: p3, command, paths: [f1, f2, f3], orientations})

      describe "very-left", ->
        command = 'very-left'
        describe "when p1 is active", ->
          it "move to very left", ->
            expectPanePaths({active: p1, command, paths: [f1, f2, f3]})
        describe "when p2 is active", ->
          it "move to very left", ->
            expectPanePaths({active: p2, command, paths: [f2, f1, f3]})
        describe "when p3 is active", ->
          it "move to very left", ->
            expectPanePaths({active: p3, command, paths: [f3, f1, f2]})

      describe "very-right", ->
        command = 'very-right'
        describe "when p1 is active", ->
          it "move to very right", ->
            expectPanePaths({active: p1, command, paths: [f2, f3, f1]})
        describe "when p2 is active", ->
          it "move to very right", ->
            expectPanePaths({active: p2, command, paths: [f1, f3, f2]})
        describe "when p3 is active", ->
          it "move to very right", ->
            expectPanePaths({active: p3, command, paths: [f1, f2, f3]})

    describe "all vertical", ->
      beforeEach ->
        waitsForPromise -> atom.workspace.open(f1)
        runs -> split('down')
        waitsForPromise -> atom.workspace.open(f2)
        runs -> split('down')
        waitsForPromise -> atom.workspace.open(f3)

        runs ->
          panes = atom.workspace.getPanes()
          expect(panes).toHaveLength 3
          [p1, p2, p3] = panes
          expect(p1.getParent().getOrientation()).toBe 'vertical'
          expect(atom.workspace.getActivePane()).toBe p3
          expect(getPanePaths()).toEqual [f1, f2, f3]

      describe "very-top", ->
        command = 'very-top'
        describe "when p1 is active", ->
          it "move to very top", ->
            expectPanePaths({active: p1, command, paths: [f1, f2, f3]})
        describe "when p2 is active", ->
          it "move to very top", ->
            expectPanePaths({active: p2, command, paths: [f2, f1, f3]})
        describe "when p3 is active", ->
          it "move to very top", ->
            expectPanePaths({active: p3, command, paths: [f3, f1, f2]})
      describe "very-bottom", ->
        command = 'very-bottom'
        describe "when p1 is active", ->
          it "move to very bottom", ->
            expectPanePaths({active: p1, command, paths: [f2, f3, f1]})
        describe "when p2 is active", ->
          it "move to very bottom", ->
            expectPanePaths({active: p2, command, paths: [f1, f3, f2]})
        describe "when p3 is active", ->
          it "move to very bottom", ->
            expectPanePaths({active: p3, command, paths: [f1, f2, f3]})

      describe "very-left", ->
        command = 'very-left'
        orientations = ['horizontal', 'vertical', 'vertical']
        describe "when p1 is active", ->
          it "move to very left", ->
            expectPanePaths({active: p1, command, paths: [f1, f2, f3], orientations})
        describe "when p2 is active", ->
          it "move to very left", ->
            expectPanePaths({active: p2, command, paths: [f2, f1, f3], orientations})
        describe "when p3 is active", ->
          it "move to very left", ->
            expectPanePaths({active: p3, command, paths: [f3, f1, f2], orientations})

      describe "very-right", ->
        command = 'very-right'
        orientations = ['horizontal', 'vertical', 'vertical']
        describe "when p1 is active", ->
          it "move to very right", ->
            expectPanePaths({active: p1, command, paths: [f2, f3, f1], orientations})
        describe "when p2 is active", ->
          it "move to very right", ->
            expectPanePaths({active: p2, command, paths: [f1, f3, f2], orientations})
        describe "when p3 is active", ->
          it "move to very right", ->
            expectPanePaths({active: p3, command, paths: [f1, f2, f3], orientations})
