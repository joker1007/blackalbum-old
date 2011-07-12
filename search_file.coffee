exports.FileSearcher = class FileSearcher
  constructor: (@regex) ->

  search: (dir, level, callback) ->
    fs = require 'fs'
    path = require 'path'
    fs.readdir dir, (err, files) =>
      for f in files
        f_path = path.join dir, f
        f_stat = fs.statSync f_path
        if f_stat.isDirectory()
          if level > 0
            this.search f_path, level-1, callback
          else if level == -1
            this.search f_path, level, callback
        else
          if f.match @regex
            callback(err, f_path)
