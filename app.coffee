###
 Module dependencies.
###

express = require 'express'
mongoose = require 'mongoose'
Schema = mongoose.Schema
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
events = require 'events'
opts = require 'opts'
Seq = require 'seq'
{exec} = require 'child_process'
{spawn} = require 'child_process'

{FileSearcher} = require './lib/search_file'
{MovieFactory} = require './lib/movie_factory'
thumbnailer = require './lib/ffmpegthumbnailer'
ffmpeg_info = require './lib/ffmpeg_info'

{Watch} = require './lib/watch'
{Movie} = require './lib/movie'
{Player} = require './lib/player'


###
  Command option parse
###

options = [
  {
    short: 'p'
    long: 'port'
    description: 'Server port'
    value: true
  },
]
opts.parse(options, true)


###
  Model define
###

watchModel = mongoose.model('Watch', Watch)

movieModel = mongoose.model('Movie', Movie)
movieModel.prototype.length_str = ->
  if this.length
    hour = parseInt(this.length / 3600)
    hour = if hour < 10 then "0#{hour}" else "#{hour}"
    min = parseInt((this.length % 3600) / 60)
    min = if min < 10 then "0#{min}" else "#{min}"
    sec = this.length % 60
    sec = if sec < 10 then "0#{sec}" else "#{sec}"
    return "#{hour}:#{min}:#{sec}"
  else
    return "00:00:00"

movieModel.prototype.play = (player, args) ->
  pl = spawn player, args
  pl.on 'exit', (code) ->
    msg = "Player process exited with code #{code}"
    console.log msg
    io.sockets.emit 'player_exit', msg

playerModel = mongoose.model('Player', Player)
playerModel.prototype.form_action_url = ->
  if this.isNew
    return "/player"
  else
    return "/player/#{this._id}"
playerModel.prototype.form_mode = ->
  if this.isNew
    return "new"
  else
    return "edit"


## Express
app = module.exports = express.createServer()

app.configure ->
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.use express.logger()
  app.use express.bodyParser()
  app.use express.cookieParser()
  app.use express.session({ secret: "blackalbum438aGdajgkdsl48DDagjkbmz" })
  app.use express.methodOverride()
  app.use express.compiler({ src: __dirname + '/public', enable: ['sass'] })
  app.use app.router
  app.use express.static(__dirname + '/public')
  mongoose.connect('mongodb://localhost/blackalbum')

app.configure 'development', ->
  app.use express.errorHandler({ dumpExceptions: true, showStack: true })

app.configure 'production', ->
  app.use express.errorHandler()


## dynamicHelper

app.dynamicHelpers {
  req: (req, res) ->
    return req
  session: (req, res) ->
    return req.session
  order_options: (req, res) ->
    html = ""
    html += '<option id="order_name-asc" value="name-asc">ファイル名(昇順)</option>'
    html += '<option id="order_name-desc" value="name-desc">ファイル名(降順)</option>'
    html += '<option id="order_regist_date-asc" value="regist_date-asc">登録日(昇順)</option>'
    html += '<option id="order_regist_date-desc" value="regist_date-desc">登録日(降順)</option>'
    html += '<option id="order_path-asc" value="path-asc">ファイルパス(昇順)</option>'
    html += '<option id="order_path-desc" value="path-desc">ファイルパス(降順)</option>'
    return html
  hostname: ->
    "localhost:#{opts.get('port')}"
}


## function define
db_update = (target) ->
  count = 0
  queue = []
  factory_callback = (movie) ->
    if movie.isNew or movie.isModified()
      movie.save (err) ->
        if !err
          console.log "Save: #{movie.path}"
          io.sockets.emit('save_movie', {name: movie.name, path:movie.path})
        else
          console.log err.message
        count -= 1
        em.emit 'process_complete'
    else
      em.emit 'process_complete'

  em = new events.EventEmitter
  em.on "process_complete", ->
    f = queue.shift()
    if f
      count += 1
      movie_factory = new MovieFactory f
      movie_factory.get_movie 6, false, factory_callback
    else
      console.log "All Updated: #{target}"
      io.sockets.emit 'all_updated', target

  fsearch = new FileSearcher(/\.(mp4|flv|mpe?g|mkv|ogm|wmv|asf|avi|mov|rmvb)$/)
  fsearch.search target, 0, (err, f) ->
    if !err
      if require('os').type() == 'Darwin'
        {Iconv} = require 'iconv'
        conv = new Iconv 'UTF-8-MAC', 'UTF-8'
        f = conv.convert(f).toString 'utf-8'
      if count < 8
        count += 1
        movie_factory = new MovieFactory f
        movie_factory.get_movie 6, false, factory_callback
      else
        queue.push f
    else
      console.log err

order_check = (req) ->
  req.session.order ?= ['name', 1, 'name-asc']
  switch req.query?.order
    when 'name-asc'
      req.session.order = ['name', 1, 'name-asc']
    when 'name-desc'
      req.session.order = ['name', -1, 'name-desc']
    when 'regist_date-asc'
      req.session.order = ['regist_date', 1, 'regist_date-asc']
    when 'regist_date-desc'
      req.session.order = ['regist_date', -1, 'regist_date-desc']
    when 'path-asc'
      req.session.order = ['path', 1, 'path-asc']
    when 'path-desc'
      req.session.order = ['path', -1, 'path-desc']

## Routes

app.get '/', (req, res) ->
  res.redirect '/movies'

app.get '/updatedb', (req, res) ->
  watchModel.find {}, (err, watches) ->
    if !err
      for w in watches
        db_update(w.dir)
      res.send "Update Start"

## Watch
app.get '/watch', (req, res) ->
  watch = new watchModel
  res.render 'watches/new', {watch: watch}

app.post '/watch', (req, res) ->
  watch = new watchModel req.body.watch
  watch.save (err) ->
    if !err
      res.render 'watches/watch', {layout: false, watch: watch}
    else
      console.log err
      res.send err.message, 422

app.get '/watch/:id', (req, res) ->
  watchModel.findById req.params.id, (err, watch) ->
    if !err
      res.render 'watches/form', {layout: false, watch: watch}
    else
      res.redirect('/watches', err: err)

app.put '/watch/:id', (req, res) ->
  Seq()
    .seq_((next) ->
      watchModel.findById req.params.id, next
    )
    .seq_((next, watch) ->
      console.log watch
      watch.dir = req.body.watch.dir
      next.stack.push watch
      watch.save next
    )
    .seq_((next, watch) ->
      res.send watch
    )
    .catch((err) ->
      res.send err.message, 422
    )

app.del '/watch/:id', (req, res) ->
  Seq()
    .seq_((next) ->
      watchModel.remove { _id: req.params.id }, next
    )
    .seq_((next, watch) ->
      res.send {_id: req.params.id}
    )
    .catch((err) ->
      console.log err
      res.send "Delete Failed", 422
    )

app.get '/watches', (req, res) ->
  watchModel.find {}, (err, watches) ->
    if req.query.xhr
      res.render 'watches/index', {layout: false, watches: watches}
    else
      res.render 'watches/index', {watches: watches}

## Player
app.get '/player/:id', (req, res) ->
  playerModel.findById req.params.id, (err, player) ->
    if !err
      res.render 'players/form', {layout: false, player: player}
    else
      res.send err.message, 422

app.put '/player/:id', (req, res) ->
  Seq()
    .seq_((next) ->
      playerModel.findById req.params.id, next
    )
    .seq_((next, player) ->
      player.name = req.body.player.name
      player.path = req.body.player.path
      next.stack.push player
      player.save next
    )
    .seq_((next, player) ->
      res.send player
    )
    .catch((err) ->
      res.send err.message, 422
    )

app.del '/player/:id', (req, res) ->
  Seq()
    .seq_((next) ->
      playerModel.findById req.params.id, next
    )
    .seq_((next, player) ->
      next.stack.push player
      player.remove next
    )
    .seq_((next, player) ->
      res.send player
    )
    .catch((err) ->
      res.send err.message, 422
    )


app.get '/player', (req, res) ->
  player = new playerModel
  res.render 'players/form', {layout: false, player: player}

app.post '/player', (req, res) ->
  player = new playerModel req.body.player
  player.save (err) ->
    if !err
      res.send player
    else
      res.send err.message, 422


## Movie
app.get '/movie/:id/play', (req, res) ->
  Seq()
    .par_((next) ->
      playerModel.findById req.query.pid, next
    )
    .par_((next) ->
      movieModel.findById req.params.id, next
    )
    .seq_((next, player, movie) ->
      cmd = "open"
      args = ["-a", "#{player.path}"]
      args.push "#{movie.path}"
      movie.play(cmd, args)
      res.send movie
    )
    .catch((err) ->
      res.send("Cannot Start Play", 422)
    )

app.get '/movies/:page?', (req, res) ->
  per_page = if req.body?.per_page then parseInt(req.body.per_page) else 200
  page = if req.params.page then parseInt req.params.page else 1
  paginate = require 'paginate-js'
  order_check(req)

  Seq()
    .par_((next) ->
      playerModel.find {}, next
    )
    .par_((next) ->
      movieModel.count {}, next
    )
    .seq_((next, players, count) ->
      player_options = players.reduce((html, p) ->
        html += "<option value=\"#{p._id}\">#{p.name}</option>"
      , "")
      p = paginate {count_elements: count, elements_per_page: per_page}
      next(null, player_options, count, p)
    )
    .seq_((next, player_options, count, p) ->
      movieModel.find({}).sort(req.session.order[0], req.session.order[1]).skip((page-1) * per_page).limit(per_page).execFind (err, movies) ->
        if req.query.xhr && req.params.page
          res.render 'movies/list', {layout: false, movies: movies, p: p, count: count, page: page, player_options: player_options}
        else if req.query.xhr
          res.render 'movies/index', {layout: false, movies: movies, p: p, count: count, page: page, player_options: player_options}
        else
          res.render 'movies/index', {movies: movies, p: p, count: count, page: page, player_options: player_options}
    )

search_movies = (req, res, q) ->
  per_page = if req.body?.per_page then parseInt(req.body.per_page) else 200
  page = if req.params.page then parseInt req.params.page else 1
  paginate = require 'paginate-js'
  order_check(req)
  if q.substr(0, 1) == '!'
    query = {tag : q.substr(1)}
  else
    query = {'$or' : [{name : new RegExp(q, "i")}, {tag : q}]}

  Seq()
    .par_((next) ->
      playerModel.find {}, next
    )
    .par_((next) ->
      movieModel.count query, next
    )
    .seq_((next, players, count) ->
      player_options = players.reduce((html, p) ->
        html += "<option value=\"#{p._id}\">#{p.name}</option>"
      , "")
      p = paginate {count_elements: count, elements_per_page: per_page}
      next(null, player_options, count, p)
    )
    .seq_((next, player_options, count, p) ->
      movieModel.find(query).sort(req.session.order[0], req.session.order[1]).skip((page-1) * per_page).limit(per_page).execFind (err, movies) ->
        if req.query.xhr
          res.render 'movies/list', {layout: false, movies: movies, p: p, count: count, page: page, player_options: player_options, search: true}
        else
          res.render 'movies/index', {movies: movies, p: p, count: count, page: page, player_options: player_options, search: true}
    )

app.get '/movies/search/:page?', (req, res) ->
  q = req.query.q
  req.q = q
  search_movies req, res, q

app.post '/movies/search/:page?', (req, res) ->
  q = req.body.q
  req.q = q
  search_movies req, res, q


port = if opts.get 'port' then parseInt(opts.get('port')) else 4000
app.listen port
console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env


## Socket.IO
io = require('socket.io').listen(app)
io.sockets.on 'connection', (socket) ->
  console.log "Get Connection from Browser"

  socket.on 'disconnect', ->
    console.log "Disconnect"
