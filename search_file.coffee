exports.FileSearcher = class FileSearcher
  constructor: (@regex) ->

  search: (path, level, callback) ->
    require('fs').readdir path, (err, files) =>
      for f in files
        f_path = "#{path}/#{f}"
        f_stat = require('fs').statSync f_path
        if f_stat.isDirectory()
          if level > 0
            this.search f_path, level-1, callback
          else if level == -1
            this.search f_path, level, callback
        else
          if f.match @regex
            callback(err, f_path)
