Seq = require 'seq'
Hash = require 'hashish'
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
        files = Hash(next.vars).filter((stat, f_path) ->
          !stat.isDirectory()
        ).keys.filter((f_path) =>
          path.basename(f_path).match @regex
        )
        dirs = Hash(next.vars).filter((stat, f_path) ->
          stat.isDirectory()
        ).keys

        dirs.forEach((f_path) =>
          if level > 0
            this.search f_path, level-1, callback
          else if level == -1
            this.search f_path, level, callback
        )

        if files.length >= 1
          callback(null, files)
      )
      .catch((err) ->
        callback(err)
      )
