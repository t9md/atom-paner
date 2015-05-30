{CompositeDisposable} = require 'atom'
_ = require 'underscore-plus'

module.exports =
  PaneAxis: null
  Pane:     null

  activate: (state) ->
    @disposables = new CompositeDisposable

    @disposables.add atom.commands.add 'atom-workspace',
      'paner:maximize':    => @maximize()
      'paner:swap-item':   => @swapItem()
      'paner:very-top':    => @very('top')
      'paner:very-bottom': => @very('bottom')
      'paner:very-left':   => @very('left')
      'paner:very-right':  => @very('right')
      'paner:test':        => @test()

  maximize: ->
    workspaceElement = atom.views.getView(atom.workspace)
    workspaceElement.classList.toggle('paner-maximize')

    @disposables.add @getActivePane().onDidChangeActive ->
      workspaceElement.classList.remove('paner-maximize')

  getPanes: ->
    atom.workspace.getPanes()

  getActivePane: ->
    atom.workspace.getActivePane()

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

  # Like Vim's `ctrl-w x`, select pane within current PaneAxis.
  #
  # * Choose next Pane if exists.
  # * If next Pane doesn't exits, choose previous Pane.
  getAdjacentPane: ->
    activePane = @getActivePane()
    parent     = activePane.getParent()
    children   = parent.getChildren()
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

    src.pane.moveItemToPane src.item, dst.pane, dst.index
    dst.pane.moveItemToPane dst.item, src.pane, src.index
    src.pane.activateItem dst.item
    src.pane.activate()

    # Revert original setting
    atom.config.set('core.destroyEmptyPanes', configDestroyEmptyPanes)

  deactivate: ->
    @disposables.dispose()

  movePane: (srcPane, dstPane) ->
    for item, i in srcPane.getItems()
      srcPane.moveItemToPane item, dstPane, i
    srcPane.destroy()

  copyPaneAxis: (paneAxis) ->
    {container, orientation} = paneAxis
    new paneAxis.constructor({container, orientation, children: paneAxis.getChildren()})

    # clone = atom.deserializers.deserialize(paneAxis.serialize())
    # container = paneAxis.getContainer()
    # clone.setContainer(container)
    # clone.children.forEach (child) ->
    #   child.setContainer(container)
    #   child.setParent(clone)

  # [FIXME]
  # Occasionally blank pane, remain on original pane position.
  # Clicking this blank pane cause Uncaught Error: Pane has bee destroyed.
  # This issue is already reported to
  #  https://github.com/atom/atom/issues/4643
  very: (direction) ->
    return if @getPanes().length is 1
    thisPane = @getActivePane()
    paneInfo = @getPaneInfo thisPane
    {parent, index, root, container} = paneInfo
    orientation = @getOrientation direction
    @Pane      ?= thisPane.constructor
    @PaneAxis  ?= root.constructor

    if root.getOrientation() isnt orientation
      console.log "Different orientation"
      # root.unsubscribeFromChild(child)
      origRoot = new @PaneAxis({
        container,
        orientation: root.getOrientation(),
        children: root.getChildren()
        })

      for child in root.getChildren()
        root.removeChild(child)
      root.destroy()
      root  = new @PaneAxis({container, orientation, children: [origRoot]})

    newPane = new @Pane()
    switch direction
      when 'top', 'left'
        root.addChild(newPane, 0)
      when 'right', 'bottom'
        root.addChild(newPane)
    @movePane thisPane, newPane

    if root isnt paneInfo.root
      container.setRoot(root)
      @reparentChildren root, orientation

    container.destroyEmptyPanes()
    newPane.activateItemAtIndex index
    newPane.activate()

  isEqualOrientationAxis: (axis, orientation) ->
    (axis instanceof @PaneAxis) and (axis.getOrientation() is orientation)

  reparentChildren: (parent, orientation) ->
    console.log "Reparent"
    for axis in parent.children when @isEqualOrientationAxis(axis, orientation)
      console.log "Reparent: found"
      children   = axis.getChildren()
      firstChild = children.shift()
      firstChild.setFlexScale()
      parent.replaceChild(axis, firstChild)
      while children.length
        parent.insertChildAfter(firstChild, children.shift())
      axis.destroy()

  # reparent
  # if paneInfo.root.getOrientation() isnt orientation
  #   for child in root.children when (child instanceof @PaneAxis) and (child.getOrientation() is orientation)
  #     console.log "reParent!!"
  #     children  = child.getChildren()
  #     child.reparentLastChild()
  #     children.shift()
  #     while children.length
  #       root.addChild(children.shift())
  #     child.destroy()
