{Range} = require 'atom'

getView = (model) ->
  atom.views.getView(model)

setConfig = (name, value) ->
  atom.config.set("paner.#{name}", value)

openFile = (filePath, options={}, fn=null) ->
  waitsForPromise ->
    atom.workspace.open(filePath, options).then (e) ->
      fn?(e)

getVisibleBufferRowRange = (e) ->
  getView(e).getVisibleRowRange().map (row) ->
    e.bufferRowForScreenRow row

getVisibleBufferRange = (editor) ->
  [startRow, endRow] = getVisibleBufferRowRange()
  new Range([startRow, 0], [endRow, Infinity])

module.exports = {
  setConfig, openFile,
  getVisibleBufferRowRange, getVisibleBufferRange,
  getView,
}
