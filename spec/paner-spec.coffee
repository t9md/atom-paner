# _path = require 'path'

{setConfig, getPath, addProject, openFile} = require './spec-helper'

describe "paner", ->
  [main, view, workspaceElement] = []
  # [editor, editorElement] = []
  [pathSample1, pathSample2] = []

  dispatchCommand = (command) ->
    atom.commands.dispatch(workspaceElement, "paner:#{command}")

  addCustomMatchers = (spec) ->
    spec.addMatchers
      # toBeEqualItem: (expected) ->
      #   line1 = @actual.find('div').eq(0).text()
      #   line2 = @actual.find('div').eq(1).text()
      #   (line1 is _path.basename(expected)) and (line2 is getPath(expected, true))

  beforeEach ->
    # addCustomMatchers(this)
    workspaceElement = atom.views.getView(atom.workspace)
    pathSample1 = atom.project.resolvePath "sample-1.coffee"
    pathSample2 = atom.project.resolvePath "sample-2.coffee"
    jasmine.attachToDOM(workspaceElement)
    activationPromise = null
    runs ->
      activationPromise = atom.packages.activatePackage('paner').then (pack) ->
        main = pack.mainModule
      dispatchCommand('swap-item')

    waitsForPromise -> activationPromise

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
    [editor, editorElement, pathSample] = []
    lineHeightPx = 10
    rowsPerPage = 10
    scroll = (editor) ->
      editor.setScrollTop(editor.getScrollTop() + editor.getHeight())

    getVisibleBufferRowRange = (editor) ->
      editor.getVisibleRowRange().map (row) ->
        editor.bufferRowForScreenRow row

    beforeEach ->
      pathSample = atom.project.resolvePath("sample")
      waitsForPromise ->
        atom.workspace.open(pathSample).then (e) ->
          editor = e
          editor.setLineHeightInPixels(lineHeightPx)
          editor.setHeight(rowsPerPage * lineHeightPx)
          editorElement = atom.views.getView(editor)
      runs ->
        scroll(editor)
        editor.setCursorBufferPosition [16, 0]
        expect(getVisibleBufferRowRange(editor)).toEqual [10, 19]

    describe "split-up", ->
      # dispatchCommand('split-up')
    describe "split-down", ->
    describe "split-left", ->
      it "split-left with keeping scroll ratio", ->
        # dispatchCommand('split-left')
        # expect(getVisibleBufferRowRange(editor)).toEqual [10, 19]
        # panes = atom.workspace.getPanes()
        # expect(panes).toHaveLength 2
        # [paneL, paneR] = panes
        # expect(paneR.getItems()).toEqual [editor]
        # expect(paneL.getItems()).toHaveLength 1
        # newItem = paneL.getActiveItem()
        # expect(newItem.getPath()).toBe pathSample
        # expect(getVisibleBufferRowRange(editor)).toEqual [10, 19]
        # expect(getVisibleBufferRowRange(newItem)).toEqual [10, 19]
        # expect(atom.workspace.getActivePane()).toBe paneL

    describe "split-right", ->

  describe "moveToVery direction", ->
    describe "very-top", ->
    describe "very-bottom", ->
    describe "very-left", ->
    describe "very-right", ->
