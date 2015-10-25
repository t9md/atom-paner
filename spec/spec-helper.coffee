{Range} = require 'atom'

setConfig = (name, value) ->
  atom.config.set("paner.#{name}", value)

openFile = (filePath, options={}, fn=null) ->
  waitsForPromise ->
    atom.workspace.open(filePath, options).then (e) ->
      fn?(e)

getVisibleBufferRange = (editor) ->
  [startRow, endRow] = editor.getVisibleRowRange().map (row) ->
    editor.bufferRowForScreenRow row
  new Range([startRow, 0], [endRow, Infinity])

module.exports = {setConfig, openFile, getVisibleBufferRange}
