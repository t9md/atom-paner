{CompositeDisposable} = require 'atom'
_ = require 'underscore-plus'

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
  PaneAxis: null
  Pane:     null

  activate: (state) ->
    @disposables = new CompositeDisposable

    @disposables.add atom.commands.add 'atom-workspace',
      'paner:maximize':     => @maximize()
      'paner:swap-item':    => @swapItem()
      'paner:very-top':     => @very('top')
      'paner:very-bottom':  => @very('bottom')
      'paner:very-left':    => @very('left')
      'paner:very-right':   => @very('right')
      'paner:toggle-debug': => @toggleDebug()

  maximize: ->
    workspaceElement = atom.views.getView(atom.workspace)
    workspaceElement.classList.toggle('paner-maximize')

    @disposables.add @getActivePane().onDidChangeActive ->
      workspaceElement.classList.remove('paner-maximize')

  toggleDebug: ->
    atom.config.toggle('paner.debug')
    state = atom.config.get('paner.debug') and "enabled" or "disabled"
    console.log "paner: debug #{state}"

  # Get nearest pane within current PaneAxis.
  #  * Choose next Pane if exists.
  #  * If next Pane doesn't exits, choose previous Pane.
  getAdjacentPane: ->
    activePane = @getActivePane()
    children   = activePane.getParent().getChildren()
    index      = children.indexOf(activePane)

    _.chain([children[index-1], children[index+1]])
      .filter((pane) -> pane?.constructor.name is 'Pane')
      .last()
      .value()

  swapItem: ->
    return unless adjacentPane = @getAdjacentPane()
    src = @getPaneInfo @getActivePane()
    dst = @getPaneInfo adjacentPane

    # Temporarily disable to avoid pane itself destroyed.
    configDestroyEmptyPanes = atom.config.get('core.destroyEmptyPanes')
    atom.config.set('core.destroyEmptyPanes', false)

    @clearPreviewTabForPane src.pane
    @clearPreviewTabForPane dst.pane
    src.pane.moveItemToPane src.item, dst.pane, dst.index
    dst.pane.moveItemToPane dst.item, src.pane, src.index
    @clearPreviewTabForPane src.pane
    @clearPreviewTabForPane dst.pane

    src.pane.activateItem dst.item
    src.pane.activate()

    # Revert original setting
    atom.config.set('core.destroyEmptyPanes', configDestroyEmptyPanes)

  # This code is result of try&error to get desirble result.
  #  * I couldn't understand why @copyRoot is necessary, but without copying PaneAxis,
  #    it seem to PaneAxis detatched from View element and not reflect model change.
  #  * Simply changing order of children by splicing children of PaneAxis or similar
  #    kind of direct manupilation to Pane or PaneAxis won't work, it easily bypassing
  #    event callback and produce bunch of Exception.
  #  * I wanted to use `thisPane` instead of `new Pane() and @movePane`, but I gave up to
  #    solve lot of Exception caused by removeChild(thisPane). So I took @movePane() approarch.
  #  * So as conclusion, code is far from ideal, I took dirty try&erro approarch,
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
    @Pane      ?= thisPane.constructor
    @PaneAxis  ?= root.constructor

    if root.getOrientation() isnt orientation
      @debug "Different orientation"
      root = new @PaneAxis({container, orientation, children: [@copyRoot(root)]})
      container.setRoot(root)

    newPane = new @Pane()
    switch direction
      when 'top', 'left'
        root.addChild(newPane, 0)
      when 'right', 'bottom'
        root.addChild(newPane)

    # [NOTE] Order is matter.
    # Calling @movePane() before calling setRoot() cause
    #  first item blank even after activateItemAtIndex 0.
    @movePane thisPane, newPane
    container.destroyEmptyPanes()

    if atom.config.get('paner.mergeSameOrientaion')
      @reparentPaneAxis(axis) for axis in @getAllAxis(root)

    newPane.activateItemAtIndex index
    newPane.activate()

  reparentPaneAxis: (axis) ->
    @debug "Reparent: start"
    parent = axis.getParent()
    if parent.getOrientation() is axis.getOrientation()
      @debug "Reparenting!!"
      children   = axis.getChildren()
      firstChild = children.shift()
      firstChild.setFlexScale()
      parent.replaceChild(axis, firstChild)
      while children.length
        parent.insertChildAfter(firstChild, children.shift())
      axis.destroy()
      parent

  # Utility
  deactivate:    -> @disposables.dispose()
  getPanes:      -> atom.workspace.getPanes()
  getActivePane: -> atom.workspace.getActivePane()

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

  debug: (msg) ->
    return unless atom.config.get('paner.debug')
    console.log msg

  clearPreviewTabForPane: (pane) ->
    paneElement = atom.views.getView(pane)
    paneElement.getElementsByClassName('preview-tab')[0]?.clearPreview()

  movePane: (srcPane, dstPane) ->
    for item, i in srcPane.getItems()
      srcPane.moveItemToPane item, dstPane, i
      @clearPreviewTabForPane dstPane
    srcPane.destroy()

  getAllAxis: (root, list=[]) ->
    for child in root.getChildren()
      if child instanceof @PaneAxis
        list.push child
        @getAllAxis child, list
    return list

  copyPaneAxis: (paneAxis) ->
    # unsubscribe before copy
    paneAxis.unsubscribeFromChild(child) for child in paneAxis.getChildren()

    {container, orientation} = paneAxis
    new paneAxis.constructor({container, orientation, children: paneAxis.getChildren()})

  copyRoot: (root) ->
    newRoot = @copyPaneAxis(root)
    root.destroy()
    for thisAxis in @getAllAxis(newRoot)
      newPaneAxis = @copyPaneAxis thisAxis
      thisAxis.getParent().replaceChild thisAxis, newPaneAxis
      thisAxis.destroy()
    newRoot
