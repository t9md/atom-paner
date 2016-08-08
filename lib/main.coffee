_ = require 'underscore-plus'
{CompositeDisposable, Emitter} = require 'atom'
{
  debug
  getView
  getActivePane
  splitPane
  withConfig
  getAdjacentPane
  moveActivePaneItem
  swapActiveItem
  moveAllPaneItems
  mergeToParentPaneAxis
  getAllPaneAxis
  copyPaneAxis
  copyRoot
} = require './utils'

buildPane = ->
  new Pane({
    applicationDelegate: atom.applicationDelegate,
    config: atom.config,
    deserializerManager: atom.deserializers,
    notificationManager: atom.notifications
  })

PaneAxis = null
Pane = null

module.exports =
  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @workspaceElement = getView(atom.workspace)
    Pane = atom.workspace.getActivePane().constructor
    @emitter = new Emitter

    @subscriptions.add atom.commands.add 'atom-workspace',
      'paner:maximize': => @maximize()
      'paner:swap-item': => @swapItem()
      'paner:merge-item': => @mergeItem(activate: true)
      'paner:send-item': => @mergeItem(activate: false)

      'paner:split-up': => @split('up')
      'paner:split-down': => @split('down')
      'paner:split-left': => @split('left')
      'paner:split-right': => @split('right')

      'paner:very-top': => @moveToVery('top')
      'paner:very-bottom': => @moveToVery('bottom')
      'paner:very-left': => @moveToVery('left')
      'paner:very-right': => @moveToVery('right')

    @onDidPaneSplit ({oldPane, newPane, direction, options}) ->
      return unless oldEditor = oldPane.getActiveEditor()
      oldEditorElement = getView(oldEditor)
      newEditor = newPane.getActiveEditor()
      newEditorElement = getView(newEditor)
      switch direction
        when 'right', 'left'
          newEditorElement.setScrollTop(oldEditorElement.getScrollTop())

        when 'up', 'down'
          {pixelTop, ratio} = options
          newHeight = newEditorElement.getHeight()
          scrolloff = 2
          lineHeightInPixels = oldEditor.getLineHeightInPixels()

          offsetTop = lineHeightInPixels * scrolloff
          offsetBottom = newHeight - lineHeightInPixels * (scrolloff+1)
          offsetCursor = newHeight * ratio
          scrollTop = pixelTop - Math.min(Math.max(offsetCursor, offsetTop), offsetBottom)

          oldEditorElement.setScrollTop(scrollTop)
          newEditorElement.setScrollTop(scrollTop)

  deactivate: ->
    @subscriptions.dispose()
    {Pane, PaneAxis, @workspaceElement} = {}

  onDidPaneSplit: (callback) ->
    @emitter.on 'did-pane-split', callback

  # Simply add/remove css class, actual maximization effect is done by CSS.
  maximize: ->
    @workspaceElement.classList.toggle('paner-maximize')
    subs = getActivePane().onDidChangeActive =>
      @workspaceElement.classList.remove('paner-maximize')
      subs.dispose()

  getCursorPositionInfo: (editor) ->
    editorElement = getView(editor)
    point = editor.getCursorScreenPosition()
    pixelTop = editorElement.pixelPositionForScreenPosition(point).top
    ratio = (pixelTop - editorElement.getScrollTop()) / editorElement.getHeight()
    {pixelTop, ratio}

  split: (direction) ->
    oldPane = getActivePane()
    options = null
    if direction in ['up', 'down']
      options = @getCursorPositionInfo(oldPane.getActiveEditor())
    newPane = splitPane(oldPane, direction, copyActiveItem: true, activate: false)
    @emitter.emit 'did-pane-split', {oldPane, newPane, direction, options}

  swapItem: ->
    currentPane = getActivePane()
    if adjacentPane = getAdjacentPane(currentPane)
      # In case there is only one item in pane, we need to avoid pane itself
      # destroyed while swapping.
      withConfig 'core.destroyEmptyPanes', false, ->
        swapActiveItem(currentPane, adjacentPane)

  mergeItem: ({activate}={}) ->
    currentPane = getActivePane()
    if dstPane = getAdjacentPane(currentPane)
      moveActivePaneItem(currentPane, dstPane)
      dstPane.activate() if activate

  # This code is result of try&error to get desirble result.
  #  * I couldn't understand why copyRoot is necessary, but without copying PaneAxis,
  #    it seem to PaneAxis detatched from View element and not reflect model change.
  #  * Simply changing order of children by splicing children of PaneAxis or similar
  #    kind of direct manupilation to Pane or PaneAxis won't work, it easily bypassing
  #    event callback and produce bunch of Exception.
  #  * I wanted to use `currentPane` directly, instead of `new Pane() then moveAllPaneItems`, but I gave up to
  #    solve a lot of exception caused by removeChild(currentPane). So I took moveAllPaneItems() approarch.
  #  * So as conclusion, code is far from ideal, I took dirty try&error approarch,
  #    need to be improved in future. There must be better way.
  #
  # [FIXME]
  # Occasionally blank pane remain on original pane position.
  # Clicking this blank pane cause Uncaught Error: Pane has bee destroyed.
  # This issue is already reported to https://github.com/atom/atom/issues/4643
  #
  # [TODO]
  # Understand Pane, PaneAxis, PaneContainer and its corresponding ViewElement and surrounding
  # Event callbacks. Ideally it should be done without copyRoot()?
  moveToVery: (direction) ->
    return if atom.workspace.getPanes().length < 2
    currentPane = getActivePane()
    container = currentPane.getContainer()
    root = container.getRoot()
    orientation = if direction in ['top', 'bottom'] then 'vertical' else 'horizontal'

    # If there is multiple pane in window, root is always instance of PaneAxis
    PaneAxis ?= root.constructor

    if root.getOrientation() isnt orientation
      debug("Different orientation")
      children = [copyRoot(root)]
      root.destroy()
      container.setRoot(root = new PaneAxis({container, orientation, children}))

    newPane = buildPane()
    switch direction
      when 'top', 'left' then root.addChild(newPane, 0)
      when 'right', 'bottom' then root.addChild(newPane)

    # [NOTE] Order is matter.
    # Calling moveAllPaneItems() before setRoot() cause first item blank
    moveAllPaneItems(currentPane, newPane)
    currentPane.destroy()

    if atom.config.get('paner.mergeSameOrientaion')
      for axis in getAllPaneAxis(root) when axis.getOrientation() is axis.getParent().getOrientation()
        debug("merge to parent!!")
        mergeToParentPaneAxis(axis)

    newPane.activate()
