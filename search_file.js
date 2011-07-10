var FileSearcher;
var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
exports.FileSearcher = FileSearcher = (function() {
  function FileSearcher(regex) {
    this.regex = regex;
  }
  FileSearcher.prototype.search = function(path, level, callback) {
    return require('fs').readdir(path, __bind(function(err, files) {
      var f, f_path, f_stat, _i, _len, _results;
      _results = [];
      for (_i = 0, _len = files.length; _i < _len; _i++) {
        f = files[_i];
        f_path = "" + path + "/" + f;
        f_stat = require('fs').statSync(f_path);
        _results.push(f_stat.isDirectory() ? level > 0 ? this.search(f_path, level - 1, callback) : level === -1 ? this.search(f_path, level, callback) : void 0 : f.match(this.regex) ? callback(err, f_path) : void 0);
      }
      return _results;
    }, this));
  };
  return FileSearcher;
})();