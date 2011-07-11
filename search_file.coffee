exports.FileSearcher = class FileSearcher
  constructor: (@regex) ->

  search: (dir, level, callback) ->
    fs = require 'fs'
    path = require 'path'
    fs.readdir dir, (err, files) =>
      i = 0
      interval = setInterval(=>
        f = files[i]
        i += 1
        if i == files.length
          clearInterval interval
        f_path = path.join dir, f
        try
          fs.stat f_path, (err, f_stat) =>
            if f_stat.isDirectory()
              if level > 0
                this.search f_path, level-1, callback
              else if level == -1
                this.search f_path, level, callback
            else
              if f.match @regex
                callback(err, f_path)
        catch error
          console.log error
      , 300)
