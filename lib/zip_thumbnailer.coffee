{spawn} = require 'child_process'
zipfile = require 'zipfile'

class ZipThumbnailer
  constructer: (@filename) ->
    @zf = new zipfile.ZipFile @filename
    if @zf.count > 5
      @targets = @zf.names.filter (name, i) =>
        (i % parseInt(@zf.count / 5)) == 0
    else
      @targets = @zf.names


