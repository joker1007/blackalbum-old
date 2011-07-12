var FFMPEGTHUMBNAILER, FFmpegThumbnailer, events, exec, thumbnailer;
var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
  for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
  function ctor() { this.constructor = child; }
  ctor.prototype = parent.prototype;
  child.prototype = new ctor;
  child.__super__ = parent.prototype;
  return child;
}, __slice = Array.prototype.slice;
exec = require('child_process').exec;
events = require('events');
FFMPEGTHUMBNAILER = 'ffmpegthumbnailer';
FFmpegThumbnailer = (function() {
  __extends(FFmpegThumbnailer, events.EventEmitter);
  function FFmpegThumbnailer() {}
  FFmpegThumbnailer.prototype.create = function() {
    var args, callback, input, offset, options, output, size, _i, _ref, _ref2;
    input = arguments[0], output = arguments[1], options = 4 <= arguments.length ? __slice.call(arguments, 2, _i = arguments.length - 1) : (_i = 2, []), callback = arguments[_i++];
    try {
      size = (_ref = options[0]) != null ? _ref : "160x120";
      offset = (_ref2 = options[1]) != null ? _ref2 : "10%";
      args = {
        input: input,
        output: output,
        size: size,
        offset: offset
      };
      if (!output.match(/\.(png|jpe?g)$/)) {
        throw new Error("Output Format Error");
      }
      return exec("" + FFMPEGTHUMBNAILER + " -q 10 -s " + size + " -t " + offset + " -i \"" + input + "\" -o \"" + output + "\"", {
        maxBuffer: 1000 * 1024
      }, function(err, stdout, stderr) {
        return callback(err, args, stdout, stderr);
      });
    } catch (error) {
      console.log("Create Thumbnail Error: " + input);
      return callback(error, args);
    }
  };
  FFmpegThumbnailer.prototype.multi_create = function() {
    var args, callback, count, finish_count, i, input, offset_base, options, output, seq_output, size, _i, _ref, _results;
    count = arguments[0], input = arguments[1], output = arguments[2], options = 5 <= arguments.length ? __slice.call(arguments, 3, _i = arguments.length - 1) : (_i = 3, []), callback = arguments[_i++];
    size = (_ref = options[0]) != null ? _ref : "160x120";
    offset_base = parseInt(100 / count);
    finish_count = 0;
    args = {
      count: count,
      input: input,
      output: output,
      size: size,
      offset: "" + offset_base + "%"
    };
    _results = [];
    for (i = 1; 1 <= count ? i <= count : i >= count; 1 <= count ? i++ : i--) {
      seq_output = output.replace(/(.*)\.(png|jpe?g)$/, "$1-" + i + ".$2");
      _results.push(this.create(input, seq_output, size, "" + (i * offset_base) + "%", function(err, args2, stdout, stderr) {
        if (err) {
          console.log("Multi Create Thumbnail Error: " + input);
        }
        finish_count += 1;
        if (finish_count === count) {
          return callback(err, args, stdout, stderr);
        }
      }));
    }
    return _results;
  };
  return FFmpegThumbnailer;
})();
thumbnailer = new FFmpegThumbnailer;
module.exports = thumbnailer;