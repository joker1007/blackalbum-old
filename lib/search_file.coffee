Seq = require 'seq'
exports.FileSearcher = class FileSearcher
  constructor: (@regex) ->

  search: (dir, level, callback) ->
    fs = require 'fs'
    path = require 'path'
    Seq()
      .seq_((next) ->
        fs.readdir dir, next
      )
      .flatten()
      .parEach_((next, f) ->
        f_path = path.join dir, f
        fs.stat f_path, next.into(f_path)
      )
      .seq_((next) =>
        for f_path, stat of next.vars
          if stat.isDirectory()
            if level > 0
              this.search f_path, level-1, callback
            else if level ==  -1
              this.search f_path, level, callback
          else
            if path.basename(f_path).match @regex
              callback(null, f_path)
      )
      .catch((err) ->
        callback(err)
      )
