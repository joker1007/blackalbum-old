var FileSearcher;
var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
exports.FileSearcher = FileSearcher = (function() {
  function FileSearcher(regex) {
    this.regex = regex;
  }
  FileSearcher.prototype.search = function(dir, level, callback) {
    var fs, path;
    fs = require('fs');
    path = require('path');
    return fs.readdir(dir, __bind(function(err, files) {
      var i, interval;
      i = 0;
      return interval = setInterval(__bind(function() {
        var f, f_path;
        f = files[i];
        i += 1;
        if (i === files.length) {
          clearInterval(interval);
        }
        f_path = path.join(dir, f);
        try {
          return fs.stat(f_path, __bind(function(err, f_stat) {
            if (f_stat.isDirectory()) {
              if (level > 0) {
                return this.search(f_path, level - 1, callback);
              } else if (level === -1) {
                return this.search(f_path, level, callback);
              }
            } else {
              if (f.match(this.regex)) {
                return callback(err, f_path);
              }
            }
          }, this));
        } catch (error) {
          return console.log(error);
        }
      }, this), 300);
    }, this));
  };
  return FileSearcher;
})();