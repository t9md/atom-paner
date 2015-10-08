{CompositeDisposable} = require 'atom'
_ = require 'underscore-plus'

PaneAxis = null
Pane     = null

Config =
  debug:
    type: 'boolean'
    default: false
  mergeSameOrientaion:
    type: 'boolean'
    default: true
    description: "When moving very far, merge child PaneAxis to Parent if orientaion is same"

module.exports =
  config: Config

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    Pane = atom.workspace.getActivePane().constructor

    @subscriptions.add atom.commands.add 'atom-workspace',
      'paner:maximize':    => @maximize()
      'paner:swap-item':   => @swapItem()
      'paner:merge-item':  => @mergeItem activate: true
      'paner:send-item':   => @mergeItem activate: false

      'paner:very-top':    => @very 'top'
      'paner:very-bottom': => @very 'bottom'
      'paner:very-left':   => @very 'left'
      'paner:very-right':  => @very 'right'

      'paner:split-up':    => @split 'up'
      'paner:split-down':  => @split 'down'
      'paner:split-right': => @split 'right'
      'paner:split-left':  => @split 'left'

  deactivate: ->
    @subscriptions.dispose()
    Pane     = null
    PaneAxis = null

  # Simply add/remove css class, actual maximization effect is done by CSS.
  maximize: ->
    workspaceElement = atom.views.getView(atom.workspace)
    workspaceElement.classList.toggle('paner-maximize')

    @subscriptions.add @getActivePane().onDidChangeActive ->
      workspaceElement.classList.remove('paner-maximize')

  _split: (pane, direction) ->
    pane["split#{_.capitalize(direction)}"](copyActiveItem: true, activate: false)

  split: (direction) ->
    switch direction
      when 'right', 'left'
        pane = @getActivePane()
        newPane = @_split pane, direction
        if editor = pane.getActiveEditor()
          newPane.getActiveItem().setScrollTop(editor.getScrollTop())
      when 'up', 'down'
        pane = @getActivePane()
        unless editor = pane.getActiveEditor()
          @_split pane, direction
          return

        scrollTop   = editor.getScrollTop()
        point       = editor.getCursorScreenPosition()
        cursorPixel = atom.views.getView(editor).pixelPositionForScreenPosition(point).top
        ratio       = (cursorPixel - scrollTop) / editor.getHeight()

        newPane = @_split pane, direction

        newEditor = newPane.getActiveEditor()
        newHeight = newEditor.getHeight()

        scrolloff = 2
        lineHeightPixel = editor.getLineHeightInPixels()

        offsetTop    = lineHeightPixel * scrolloff
        offsetBottom = newHeight - lineHeightPixel * (scrolloff+1)
        offsetCursor = newHeight * ratio
        scrollTop    = cursorPixel - Math.min(Math.max(offsetCursor, offsetTop), offsetBottom)
        editor.setScrollTop(scrollTop)
        newEditor.setScrollTop(scrollTop)

  # Get nearest pane within current PaneAxis.
  #  * Choose next Pane if exists.
  #  * If next Pane doesn't exits, choose previous Pane.
  getAdjacentPane: ->
    thisPane = @getActivePane()
    return unless children = thisPane.getParent().getChildren?()
    index = children.indexOf thisPane

    _.chain([children[index-1], children[index+1]])
      .filter (pane) ->
        pane instanceof Pane
      .last()
      .value()

  swapItem: ->
    return unless adjacentPane = @getAdjacentPane()
    src = @getPaneInfo @getActivePane()
    dst = @getPaneInfo adjacentPane

    # In case there is only one item in pane, we need to avoid pane itself
    # destroyed while swapping.
    configDestroyEmptyPanes = atom.config.get('core.destroyEmptyPanes')
    try
      atom.config.set('core.destroyEmptyPanes', false)
      @movePaneItem src.pane, src.item, dst.pane, dst.index
      @movePaneItem dst.pane, dst.item, src.pane, src.index if dst.item?
      src.pane.activateItem dst.item if dst.item?
      src.pane.activate()
    finally
      # Revert original setting
      atom.config.set('core.destroyEmptyPanes', configDestroyEmptyPanes)

  mergeItem: ({activate}={}) ->
    return unless adjacentPane = @getAdjacentPane()

    src = @getPaneInfo @getActivePane()
    dst = @getPaneInfo adjacentPane

    @movePaneItem src.pane, src.item, dst.pane, dst.index
    dst.pane.activateItem src.item
    dst.pane.activate() if activate

  movePaneItem: (srcPane, srcItem, dstPane, dstIndex) ->
    @clearPreviewTabForPane dstPane
    srcPane.moveItemToPane srcItem, dstPane, dstIndex
    @clearPreviewTabForPane dstPane

  # This code is result of try&error to get desirble result.
  #  * I couldn't understand why @copyRoot is necessary, but without copying PaneAxis,
  #    it seem to PaneAxis detatched from View element and not reflect model change.
  #  * Simply changing order of children by splicing children of PaneAxis or similar
  #    kind of direct manupilation to Pane or PaneAxis won't work, it easily bypassing
  #    event callback and produce bunch of Exception.
  #  * I wanted to use `thisPane` instead of `new Pane() and @moveAllPaneItems`, but I gave up to
  #    solve a lot of exception caused by removeChild(thisPane). So I took @moveAllPaneItems() approarch.
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
  # Event callbacks. Ideally it should be done without @copyRoot()?
  very: (direction) ->
    return if @getPanes().length is 1
    thisPane = @getActivePane()
    paneInfo = @getPaneInfo thisPane
    {parent, index, root, container} = paneInfo
    orientation = @getOrientation direction

    # If there is multiple pane in window, root is always instance of PaneAxis
    PaneAxis ?= root.constructor

    if root.getOrientation() isnt orientation
      @debug "Different orientation"
      root = new PaneAxis {container, orientation, children: [@copyRoot(root)]}
      container.setRoot(root)

    newPane = new Pane()
    switch direction
      when 'top', 'left'     then root.addChild(newPane, 0)
      when 'right', 'bottom' then root.addChild(newPane)

    # [NOTE] Order is matter.
    # Calling @moveAllPaneItems() before calling setRoot() cause
    #  first item blank even after activateItemAtIndex 0.
    @moveAllPaneItems thisPane, newPane
    container.destroyEmptyPanes()

    if atom.config.get('paner.mergeSameOrientaion')
      for paneAxis in @getAllPaneAxis(root)
        @reparentPaneAxis paneAxis

    newPane.activateItemAtIndex index
    newPane.activate()

  reparentPaneAxis: (paneAxis) ->
    @debug "Reparent: start"
    parent = paneAxis.getParent()
    if parent.getOrientation() is paneAxis.getOrientation()
      @debug "Reparenting!!"
      children   = paneAxis.getChildren()
      firstChild = children.shift()
      firstChild.setFlexScale()
      parent.replaceChild(paneAxis, firstChild)
      while children.length
        parent.insertChildAfter firstChild, children.shift()
      paneAxis.destroy()
      parent

  getPaneInfo: (pane) ->
    pane:      pane
    item:      pane.getActiveItem()
    index:     pane.getActiveItemIndex()
    container: pane.getContainer()
    root:      pane.getContainer().getRoot()
    parent:    pane.getParent()

  getOrientation: (direction) ->
    if direction in ['top', 'bottom']
      'vertical'
    else
      'horizontal'

  clearPreviewTabForPane: (pane) ->
    @clearPreviewTabForPaneElement atom.views.getView(pane)

  clearPreviewTabForPaneElement: (paneElement) ->
    paneElement.getElementsByClassName('preview-tab')[0]?.clearPreview()

  moveAllPaneItems: (srcPane, dstPane) ->
    dstPaneElement = atom.views.getView(dstPane)
    for item, i in srcPane.getItems()
      srcPane.moveItemToPane item, dstPane, i
      @clearPreviewTabForPaneElement dstPaneElement
    srcPane.destroy()

  getAllPaneAxis: (root, results=[]) ->
    for child in root.getChildren()
      if child instanceof PaneAxis
        results.push child
        @getAllPaneAxis child, results
    results

  copyPaneAxis: (paneAxis) ->
    for child in paneAxis.getChildren()
      paneAxis.unsubscribeFromChild(child)

    {container, orientation} = paneAxis
    new PaneAxis {container, orientation, children: paneAxis.getChildren()}

  copyRoot: (root) ->
    newRoot = @copyPaneAxis(root)
    root.destroy()
    for paneAxis in @getAllPaneAxis(newRoot)
      newPaneAxis = @copyPaneAxis paneAxis
      paneAxis.getParent().replaceChild paneAxis, newPaneAxis
      paneAxis.destroy()
    newRoot

  # Utility
  getPanes: ->
    atom.workspace.getPanes()

  getActivePane: ->
    atom.workspace.getActivePane()

  debug: (msg) ->
    return unless atom.config.get('paner.debug')
    console.log msg
