{CompositeDisposable} = require 'atom'
_ = require 'underscore-plus'

PaneAxis = null
Pane     = null

module.exports =
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

  getActivePaneAxis: (pane) ->
    @getActivePane().parent()

  getActivePane: ->
    atom.workspace.getActivePane()

  getPaneInfo: (pane) ->
    pane:  pane
    item:  pane.getActiveItem()
    index: pane.getActiveItemIndex()

  very: (direction) ->
    return if @getPanes().length is 1
    activePane      = @getActivePane()
    activeItemIndex = activePane.getActiveItemIndex()
    container       = activePane.getContainer()
    rootOrg         = container.getRoot()
    Pane            = activePane.constructor
    PaneAxis        = rootOrg.constructor

    orientation =
      if direction in ['top', 'bottom']
        'vertical'
      else
        'horizontal'

    newPane = new Pane()
    newPane.setContainer container

    if rootOrg.getOrientation() is orientation
      root = rootOrg
    else
      root = new PaneAxis({container, orientation, children: [rootOrg]})

    switch direction
      when 'top', 'left'
        root.addChild(newPane, 0)
      when 'right', 'bottom'
        root.addChild(newPane)

    for item, i in activePane.getItems()
      activePane.moveItemToPane item, newPane, i

    activePane?.close()

    if root isnt rootOrg
      container.setRoot(root)

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

  getNextPane: ->
    panes        = @getPanes()
    currentIndex = panes.indexOf @getActivePane()
    nextIndex    = (currentIndex + 1) % panes.length
    panes[nextIndex]

  deactivate: ->
    @disposables.dispose()
