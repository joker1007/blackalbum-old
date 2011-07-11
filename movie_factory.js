var FileSearcher, Movie, MovieFactory, crypto, events, exec, ffmpeg_info, fs, mongoose, movieModel, path, thumbnailer;
var __hasProp = Object.prototype.hasOwnProperty, __extends = function(child, parent) {
  for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; }
  function ctor() { this.constructor = child; }
  ctor.prototype = parent.prototype;
  child.prototype = new ctor;
  child.__super__ = parent.prototype;
  return child;
}, __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
FileSearcher = require('./search_file').FileSearcher;
thumbnailer = require('./ffmpegthumbnailer');
ffmpeg_info = require('./ffmpeg_info');
fs = require('fs');
path = require('path');
events = require('events');
crypto = require('crypto');
exec = require('child_process').exec;
mongoose = require('mongoose');
Movie = require('./movie').Movie;
movieModel = mongoose.model('Movie', Movie);
MovieFactory = (function() {
  __extends(MovieFactory, events.EventEmitter);
  function MovieFactory(filename) {
    this.filename = filename;
    this.movie = new movieModel;
    this.stats_finish = false;
    this.md5_finish = false;
    this.info_finish = false;
  }
  MovieFactory.prototype.get_movie = function(thumbnail_count, callback) {
    this.on('stats_finish', function() {
      this.stats_finish = true;
      if (this.stats_finish && this.md5_finish && this.info_finish) {
        return this.create_thumbnail(thumbnail_count);
      }
    });
    this.on('md5_finish', function() {
      this.md5_finish = true;
      if (this.stats_finish && this.md5_finish && this.info_finish) {
        return this.create_thumbnail(thumbnail_count);
      }
    });
    this.on('info_finish', function() {
      this.info_finish = true;
      if (this.stats_finish && this.md5_finish && this.info_finish) {
        return this.create_thumbnail(thumbnail_count);
      }
    });
    this.on('thumbnail_finish', function() {
      return callback(this.movie);
    });
    this.get_stats();
    this.get_md5_hash();
    return this.get_info();
  };
  MovieFactory.prototype.get_stats = function() {
    return fs.stat(this.filename, __bind(function(err, stats) {
      this.movie.path = this.filename;
      this.movie.name = path.basename(this.filename);
      this.movie.title = path.basename(this.filename).replace(/\.[a-zA-Z0-9]+$/, "");
      this.movie.size = stats.size;
      this.movie.regist_date = Date.now();
      return this.emit('stats_finish');
    }, this));
  };
  MovieFactory.prototype.get_md5_hash = function() {
    var md5sum, rs;
    md5sum = crypto.createHash('md5');
    rs = fs.createReadStream(this.filename, {
      start: 0,
      end: 100 * 1024
    });
    rs.on('data', function(d) {
      return md5sum.update(d);
    });
    return rs.on('end', __bind(function() {
      var md5;
      md5 = md5sum.digest('hex');
      this.movie.md5_hash = md5;
      return this.emit('md5_finish');
    }, this));
  };
  MovieFactory.prototype.get_info = function() {
    try {
      return ffmpeg_info.get_info(this.filename, __bind(function(err, info) {
        var _ref, _ref2, _ref3, _ref4;
        this.movie.container = (_ref = info.container) != null ? _ref : "Unknown";
        this.movie.video_codec = (_ref2 = info.video_codec) != null ? _ref2 : "Unknown";
        this.movie.audio_codec = (_ref3 = info.audio_codec) != null ? _ref3 : "Unknown";
        this.movie.length = (_ref4 = info.length) != null ? _ref4 : 0;
        this.movie.video_bitrate = info.video_bitrate;
        this.movie.audio_bitrate = info.audio_bitrate;
        this.movie.audio_sample = info.audio_sample;
        return this.emit('info_finish');
      }, this));
    } catch (error) {
      console.log("[Failed] Get Info: " + this.filename);
      return this.emit('info_finish');
    }
  };
  MovieFactory.prototype.create_thumbnail = function(count) {
    return fs.stat("thumbs/" + this.movie.title + "-" + this.movie.md5_hash + ".jpg", __bind(function(err) {
      var j;
      if (err) {
        try {
          return thumbnailer.multi_create(count, this.filename, "thumbs/" + this.movie.title + ".jpg", "200x150", __bind(function(err2, args) {
            if (err2) {
              return console.log("[Failed] Create Thumbnail: " + this.filename);
            } else {
              console.log("[Success] Create Thumbnail: " + this.filename);
              return this.merge_thumbnail(args.count);
            }
          }, this));
        } catch (error) {
          console.log(error);
          for (j = 1; 1 <= count ? j <= count : j >= count; 1 <= count ? j++ : j--) {
            fs.unlink("thumbs/" + this.movie.title + "-" + j + ".jpg", __bind(function(err4) {
              if (err4) {
                return console.log(err4);
              }
            }, this));
          }
          return this.emit('thumbnail_finish');
        }
      } else {
        console.log("Thumbnail Already Exist: " + this.filename);
        return this.emit('thumbnail_finish');
      }
    }, this));
  };
  MovieFactory.prototype.merge_thumbnail = function(count) {
    var files, i;
    files = '';
    for (i = 1; 1 <= count ? i <= count : i >= count; 1 <= count ? i++ : i--) {
      files += "\"thumbs/" + this.movie.title + "-" + i + ".jpg\" ";
    }
    return exec("convert +append " + files + " \"thumbs/" + this.movie.title + "-" + this.movie.md5_hash + ".jpg\"", __bind(function(err3, stdout, stderr) {
      var j;
      try {
        if (err3) {
          throw "[Failed] Merge Thumbnails: " + this.filename;
        }
        return console.log("[Success] Merge Thumbnails: " + this.filename);
      } catch (errmsg) {
        return console.log(errmsg);
      } finally {
        for (j = 1; 1 <= count ? j <= count : j >= count; 1 <= count ? j++ : j--) {
          fs.unlink("thumbs/" + this.movie.title + "-" + j + ".jpg", __bind(function(err4) {
            if (err4) {
              return console.log(err4);
            }
          }, this));
        }
        this.emit('thumbnail_finish');
      }
    }, this));
  };
  return MovieFactory;
})();
exports.MovieFactory = MovieFactory;