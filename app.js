(function() {
  /*
   Module dependencies.
  */  var FileSearcher, Movie, MovieFactory, Player, Schema, Watch, app, crypto, db_update, events, exec, express, ffmpeg_info, fs, io, mongoose, movieModel, path, playerModel, spawn, thumbnailer, watchModel;
  express = require('express');
  mongoose = require('mongoose');
  Schema = mongoose.Schema;
  fs = require('fs');
  path = require('path');
  crypto = require('crypto');
  events = require('events');
  exec = require('child_process').exec;
  spawn = require('child_process').spawn;
  FileSearcher = require('./search_file').FileSearcher;
  MovieFactory = require('./movie_factory').MovieFactory;
  thumbnailer = require('./ffmpegthumbnailer');
  ffmpeg_info = require('./ffmpeg_info');
  Watch = require('./watch').Watch;
  Movie = require('./movie').Movie;
  Player = require('./player').Player;
  /*
    Model define
  */
  watchModel = mongoose.model('Watch', Watch);
  movieModel = mongoose.model('Movie', Movie);
  movieModel.prototype.length_str = function() {
    var hour, min, sec;
    if (this.length) {
      hour = parseInt(this.length / 3600);
      hour = hour < 10 ? "0" + hour : "" + hour;
      min = parseInt((this.length % 3600) / 60);
      min = min < 10 ? "0" + min : "" + min;
      sec = this.length % 60;
      sec = sec < 10 ? "0" + sec : "" + sec;
      return "" + hour + ":" + min + ":" + sec;
    } else {
      return "00:00:00";
    }
  };
  movieModel.prototype.play = function(player, args) {
    var pl;
    pl = spawn(player, args);
    return pl.on('exit', function(code) {
      var msg;
      msg = "Player process exited with code " + code;
      console.log(msg);
      return io.sockets.emit('player_exit', msg);
    });
  };
  playerModel = mongoose.model('Player', Player);
  playerModel.prototype.form_action_url = function() {
    if (this.isNew) {
      return "/player";
    } else {
      return "/player/" + this._id;
    }
  };
  playerModel.prototype.form_mode = function() {
    if (this.isNew) {
      return "new";
    } else {
      return "edit";
    }
  };
  io = require('socket.io').listen(8765);
  io.sockets.on('connection', function(socket) {
    console.log("Get Connection from Browser");
    return socket.on('disconnect', function() {
      return console.log("Disconnect");
    });
  });
  app = module.exports = express.createServer();
  app.configure(function() {
    app.set('views', __dirname + '/views');
    app.register('.coffee', require('coffeekup'));
    app.set('view engine', 'jade');
    app.use(express.logger());
    app.use(express.bodyParser());
    app.use(express.methodOverride());
    app.use(express.compiler({
      src: __dirname + '/public',
      enable: ['sass']
    }));
    app.use(app.router);
    return app.use(express.static(__dirname + '/public'));
  });
  app.configure('development', function() {
    app.use(express.errorHandler({
      dumpExceptions: true,
      showStack: true
    }));
    return mongoose.connect('mongodb://localhost/blackalbum_dev');
  });
  app.configure('production', function() {
    app.use(express.errorHandler());
    return mongoose.connect('mongodb://localhost/blackalbum');
  });
  app.dynamicHelpers({
    req: function(req, res) {
      return req;
    },
    hostname: function() {
      return "localhost";
    }
  });
  db_update = function(target) {
    var count, em, factory_callback, fsearch, queue;
    count = 0;
    queue = [];
    factory_callback = function(movie) {
      if (movie.isNew || movie.isModified()) {
        return movie.save(function(err) {
          if (!err) {
            console.log("Save: " + movie.path);
            io.sockets.emit('save_movie', {
              name: movie.name,
              path: movie.path
            });
          } else {
            console.log(err.message);
          }
          count -= 1;
          return em.emit('process_complete');
        });
      } else {
        return em.emit('process_complete');
      }
    };
    em = new events.EventEmitter;
    em.on("process_complete", function() {
      var f, movie_factory;
      f = queue.shift();
      if (f) {
        count += 1;
        movie_factory = new MovieFactory(f);
        return movie_factory.get_movie(6, factory_callback);
      } else {
        console.log("All Updated: " + target);
        return io.sockets.emit('all_updated', target);
      }
    });
    fsearch = new FileSearcher(/\.(mp4|flv|mpe?g|mkv|ogm|wmv|asf|avi|mov|rmvb)$/);
    return fsearch.search(target, 0, function(err, f) {
      var Iconv, conv, movie_factory;
      if (require('os').type() === 'Darwin') {
        Iconv = require('iconv').Iconv;
        conv = new Iconv('UTF-8-MAC', 'UTF-8');
        f = conv.convert(f).toString('utf-8');
      }
      if (count < 4) {
        count += 1;
        movie_factory = new MovieFactory(f);
        return movie_factory.get_movie(6, factory_callback);
      } else {
        return queue.push(f);
      }
    });
  };
  app.get('/', function(req, res) {
    return res.redirect('/movies');
  });
  app.get('/updatedb', function(req, res) {
    return watchModel.find({}, function(err, watches) {
      var w, _i, _len;
      if (!err) {
        for (_i = 0, _len = watches.length; _i < _len; _i++) {
          w = watches[_i];
          db_update(w.dir);
        }
        return res.send("Update Start");
      }
    });
  });
  app.get('/watch', function(req, res) {
    var watch;
    watch = new watchModel;
    return res.render('watches/new', {
      title: 'New Watch List',
      watch: watch
    });
  });
  app.post('/watch', function(req, res) {
    var watch;
    watch = new watchModel(req.body.watch);
    return watch.save(function(err) {
      if (!err) {
        return res.render('watches/watch', {
          layout: false,
          watch: watch
        });
      } else {
        console.log(err);
        return res.send(err.message, 422);
      }
    });
  });
  app.get('/watch/:id', function(req, res) {
    return watchModel.findById(req.params.id, function(err, watch) {
      if (!err) {
        return res.render('watches/form', {
          layout: false,
          watch: watch
        });
      } else {
        return res.redirect('/watches', {
          err: err
        });
      }
    });
  });
  app.put('/watch/:id', function(req, res) {
    return watchModel.findById(req.params.id, function(err, watch) {
      if (!err) {
        watch.dir = req.body.watch.dir;
        return watch.save(function(err2) {
          if (!err2) {
            return res.send(watch);
          } else {
            return res.send(err2.message, 422);
          }
        });
      } else {
        return res.send(err.message, 404);
      }
    });
  });
  app.del('/watch/:id', function(req, res) {
    return watchModel.findById(req.params.id, function(err, watch) {
      if (!err) {
        return watch.remove(function(err) {
          if (!err) {
            return res.send(watch);
          } else {
            console.log(err);
            return res.send("Delete Failed", 422);
          }
        });
      }
    });
  });
  app.get('/watches', function(req, res) {
    return watchModel.find({}, function(err, watches) {
      if (req.query.xhr) {
        return res.render('watches/index', {
          layout: false,
          watches: watches
        });
      } else {
        return res.render('watches/index', {
          title: 'Watch List',
          watches: watches
        });
      }
    });
  });
  app.get('/player/:id', function(req, res) {
    return playerModel.findById(req.params.id, function(err, player) {
      if (!err) {
        return res.render('players/form', {
          layout: false,
          player: player
        });
      }
    });
  });
  app.put('/player/:id', function(req, res) {
    return playerModel.findById(req.params.id, function(err, player) {
      if (!err) {
        player.name = req.body.player.name;
        player.path = req.body.player.path;
        return player.save(function(err2) {
          if (!err2) {
            return res.send(player);
          } else {
            return res.send(err2.message, 422);
          }
        });
      } else {
        return res.send(err.message, 404);
      }
    });
  });
  app.del('/player/:id', function(req, res) {
    return playerModel.findById(req.params.id, function(err, player) {
      if (!err) {
        return player.remove(function(err2) {
          if (!err2) {
            return res.send(player);
          } else {
            return res.send(err2.message, 422);
          }
        });
      } else {
        return res.send(err.message, 404);
      }
    });
  });
  app.get('/player', function(req, res) {
    var player;
    player = new playerModel;
    return res.render('players/form', {
      layout: false,
      player: player
    });
  });
  app.post('/player', function(req, res) {
    var player;
    player = new playerModel(req.body.player);
    return player.save(function(err) {
      if (!err) {
        return res.send(player);
      } else {
        return res.send(err.message, 422);
      }
    });
  });
  app.get('/movie/:id/play', function(req, res) {
    return playerModel.findById(req.query.pid, function(err, player) {
      var args, cmd;
      if (!err) {
        cmd = "open";
        args = ["-a", "" + player.path];
        return movieModel.findById(req.params.id, function(err2, movie) {
          if (!err2) {
            args.push("" + movie.path);
            movie.play(cmd, args);
            return res.send(movie);
          } else {
            return res.send("Cannot Start Play", 422);
          }
        });
      } else {
        return res.send("No Player Selected", 404);
      }
    });
  });
  app.get('/movies/:page?', function(req, res) {
    return playerModel.find({}, function(err, players) {
      var page, paginate, per_page, player_options, _ref;
      player_options = players.reduce(function(html, p) {
        return html += "<option value=\"" + p._id + "\">" + p.name + "</option>";
      }, "");
      per_page = ((_ref = req.body) != null ? _ref.per_page : void 0) ? parseInt(req.body.per_page) : 200;
      page = req.params.page ? parseInt(req.params.page) : 1;
      paginate = require('paginate-js');
      return movieModel.count({}, function(err, count) {
        var p;
        p = paginate({
          count_elements: count,
          elements_per_page: per_page
        });
        return movieModel.find({}).sort('name', 1).skip((page - 1) * per_page).limit(per_page).execFind(function(err, movies) {
          if (req.query.xhr) {
            return res.render('movies/index', {
              layout: false,
              movies: movies,
              p: p,
              page: page,
              player_options: player_options
            });
          } else {
            return res.render('movies/index', {
              title: 'Movie List',
              movies: movies,
              p: p,
              page: page,
              player_options: player_options
            });
          }
        });
      });
    });
  });
  app.post('/movies/search/:page?', function(req, res) {
    return playerModel.find({}, function(err, players) {
      var page, paginate, per_page, player_options, q, query, _ref;
      player_options = players.reduce(function(html, p) {
        return html += "<option value=\"" + p._id + "\">" + p.name + "</option>";
      }, "");
      per_page = ((_ref = req.body) != null ? _ref.per_page : void 0) ? parseInt(req.body.per_page) : 200;
      page = req.params.page ? parseInt(req.params.page) : 1;
      paginate = require('paginate-js');
      q = req.body.q;
      if (q.substr(0, 1) === '!') {
        query = {
          tag: q.substr(1)
        };
      } else {
        query = {
          '$or': [
            {
              name: new RegExp(q, "i")
            }, {
              tag: q
            }
          ]
        };
      }
      return movieModel.count(query, function(err, count) {
        var p;
        console.log(count);
        p = paginate({
          count_elements: count,
          elements_per_page: per_page
        });
        return movieModel.find(query).sort('name', 1).skip((page - 1) * per_page).limit(per_page).execFind(function(err, movies) {
          if (req.query.xhr) {
            return res.render('movies/index', {
              layout: false,
              movies: movies,
              p: p,
              page: page,
              player_options: player_options
            });
          } else {
            return res.render('movies/index', {
              title: "Search: " + q,
              movies: movies,
              p: p,
              page: page,
              player_options: player_options
            });
          }
        });
      });
    });
  });
  app.listen(4000);
  console.log("Express server listening on port %d in %s mode", app.address().port, app.settings.env);
}).call(this);
