_ = require 'underscore-plus'

{setConfig, getPath, addProject, openFile} = require './spec-helper'

getVisibleBufferRowRange = (e) ->
  e.getVisibleRowRange().map (row) ->
    e.bufferRowForScreenRow row

describe "paner", ->
  [main, view, workspaceElement] = []
  # [editor, editorElement] = []
  [pathSample1, pathSample2] = []

  dispatchCommand = (command) ->
    atom.commands.dispatch(workspaceElement, "paner:#{command}")

  addCustomMatchers = (spec) ->
    spec.addMatchers
      toHaveSampeParent: (expected) ->
        @actual.getParent() is expected.getParent()
      toHaveScrollTop: (expected) ->
        @actual.getScrollTop() is expected
      toHaveVisibleBufferRowRange: (expected) ->
        _.isEqual(getVisibleBufferRowRange(@actual), expected)

      # toHaveOrientation: (expected) ->
      #   @actual.getOrientation() is expected

  beforeEach ->
    addCustomMatchers(this)
    activationPromise = null
    runs ->
      workspaceElement = atom.views.getView(atom.workspace)
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
      e.setScrollTop(e.getHeight())

    rowsPerPage = 10
    setEditorProperties = (e) ->
      e.setLineHeightInPixels(lineHeightInPixels)
      e.setHeight(rowsPerPage * lineHeightInPixels)

    setRowsPerPage = (e, num) ->
      e.setHeight(num * e.getLineHeightInPixels())

    onDidSplit = (fn) ->
      main.emitter.preempt 'did-pane-split', fn

    beforeEach ->
      pathSample = atom.project.resolvePath("sample")
      waitsForPromise ->
        atom.workspace.open(pathSample).then (e) ->
          editor = e
          setRowsPerPage(editor, rowsPerPage)
          editorElement = atom.views.getView(editor)

      runs ->
        scroll(editor)
        # console.log editor.getScrollTop()
        editor.setCursorBufferPosition [16, 0]
        # console.log getVisibleBufferRowRange(editor)

    describe "split up/down", ->
      [newPane, oldPane, originalScrollTop] = []
      beforeEach ->
        originalScrollTop = editor.getScrollTop()
        onDidSplit (args) ->
          {newPane, oldPane} = args
          newEditor = newPane.getActiveEditor()
          setRowsPerPage(newEditor, rowsPerPage/2)

      afterEach ->
        expect(newPane).toHaveSampeParent(oldPane)
        expect(newPane.getParent().getOrientation()).toBe 'vertical'
        expect(editor).toHaveScrollTop newEditor.getScrollTop()
        expect(newEditor).toHaveVisibleBufferRowRange [14, 18]

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
        originalScrollTop = editor.getScrollTop()
        onDidSplit (args) ->
          {newPane, oldPane} = args
          newEditor = newPane.getActiveEditor()
          setRowsPerPage(newEditor, rowsPerPage)

      afterEach ->
        expect(newPane).toHaveSampeParent(oldPane)
        expect(newPane.getParent().getOrientation()).toBe 'horizontal'
        expect(editor).toHaveScrollTop newEditor.getScrollTop()
        expect(editor).toHaveScrollTop originalScrollTop
        expect(editor).toHaveVisibleBufferRowRange [10, 19]

      describe "split left", ->
        it "split-left with keeping scroll ratio", ->
          dispatchCommand('split-left')
          expect(atom.workspace.getPanes()).toEqual [newPane, oldPane]

      describe "split-right", ->
        it "split-right with keeping scroll ratio", ->
          dispatchCommand('split-right')
          expect(atom.workspace.getPanes()).toEqual [oldPane, newPane]

  describe "moveToVery direction", ->
    describe "very-top", ->
    describe "very-bottom", ->
    describe "very-left", ->
    describe "very-right", ->
