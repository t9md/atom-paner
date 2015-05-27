{CompositeDisposable} = require 'atom'
_ = require 'underscore-plus'

module.exports =
  PaneAxis: null
  Pane:     null

  activate: (state) ->
    @disposables = new CompositeDisposable

    @disposables.add atom.commands.add 'atom-workspace',
      'paner:swap':   => @swap('next')
      'paner:very-bottom': => @very('bottom')
      'paner:maximize':    => @maximize()
      'paner:very-top':    => @very('top')
      'paner:very-left':   => @very('left')
      'paner:very-right':  => @very('right')

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
    pane:  pane
    item:  pane.getActiveItem()
    index: pane.getActiveItemIndex()

  getOrientation: (direction) ->
    if direction in ['top', 'bottom']
      'vertical'
    else
      'horizontal'

  very: (direction) ->
    # [FIXME]
    # Occasionally blank pane, remain on original pane position.
    # Clicking this blank pane cause Uncaught Error: Pane has bee destroyed.
    # This issue is already reported to
    #  https://github.com/atom/atom/issues/4643
    return if @getPanes().length is 1
    activePane       = @getActivePane()
    activeItemIndex  = activePane.getActiveItemIndex()
    container        = activePane.getContainer()
    rootOrg          = container.getRoot()
    @Pane           ?= activePane.constructor
    @PaneAxis       ?= rootOrg.constructor
    orientation      = @getOrientation direction

    newPane = new @Pane()
    newPane.setContainer container

    if rootOrg.getOrientation() is orientation
      root = rootOrg
    else
      root = new @PaneAxis({container, orientation, children: [rootOrg]})

    switch direction
      when 'top', 'left'
        root.addChild(newPane, 0)
      when 'right', 'bottom'
        root.addChild(newPane)

    for item, i in activePane.getItems()
      activePane.moveItemToPane item, newPane, i

    if root isnt rootOrg
      container.setRoot(root)

    activePane.destroy()
    # activePane.close()
    # console.log "alive? #{activePane.isAlive()}"
    # console.log "destroyed? #{activePane.isDestroyed()}"
    # found = container.getPanes().indexOf activePane
    # console.log "found? #{found}"

    newPane.activateItemAtIndex activeItemIndex
    newPane.activate()

  getAdjacentPane: ->
    # Like Vim's `ctrl-w x`, select pane within current PaneAxis.
    #
    # * Choose next Pane if exists.
    # * If next Pane doesn't exits, choose previous Pane.

    activePane = @getActivePane()
    parent     = activePane.getParent()
    children   = parent.getChildren()
    index      = children.indexOf(activePane)

    _.chain([children[index-1], children[index+1]])
      .filter((pane) -> pane?.constructor.name is 'Pane')
      .last()
      .value()

  swap: (direction) ->
    src = @getPaneInfo @getActivePane()

    adjacentPane = @getAdjacentPane()
    return unless adjacentPane
    dst = @getPaneInfo adjacentPane

    configDestroyEmptyPanes = atom.config.get('core.destroyEmptyPanes')
    # Temporarily disable to avoid pane itself destroyed.
    atom.config.set('core.destroyEmptyPanes', false)

    src.pane.moveItemToPane src.item, dst.pane, dst.index
    dst.pane.moveItemToPane dst.item, src.pane, src.index
    src.pane.activateItem dst.item
    src.pane.activate()

    # Revert original setting
    atom.config.set('core.destroyEmptyPanes', configDestroyEmptyPanes)
    # moveItemToPane

  deactivate: ->
    @disposables.dispose()
