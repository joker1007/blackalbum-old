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
ffmpeg_info = require './lib/ffmpeg_info'

{Watch} = require './model/watch'
{Movie} = require './model/movie'
{Player} = require './model/player'
{Book} = require './model/book'


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
playerModel = mongoose.model('Player', Player)
bookModel = mongoose.model('Book', Book)


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
db_update = (target, em) ->
  fsearch = new FileSearcher(/\.(mp4|flv|mpe?g|mkv|ogm|wmv|asf|avi|mov|rmvb|zip)$/)
  Seq()
    .seq_((next) ->
      fsearch.search target, 0, next
    )
    .flatten()
    .parEach(16, (f) ->
      next = this
      if require('os').type() == 'Darwin'
        {Iconv} = require 'iconv'
        conv = new Iconv 'UTF-8-MAC', 'UTF-8'
        f = conv.convert(f).toString 'utf-8'
      entry_update = (f) ->
        Seq()
          .seq_((next2) ->
            if f.match(/zip$/)
              bookModel.find_or_new f, next2
            else
              movieModel.find_or_new f, next2
          )
          .seq_((next2, entry) ->
            if entry.isNew
              entry.get_md5 next2
            else
              next2(null, entry)
          )
          .seq_((next2, entry) ->
            if entry.isNew and typeof entry.get_info == "function"
              entry.get_info next2
            else
              next2(null, entry)
          )
          .seq_((next2, entry) ->
            entry.create_thumbnail 6, "200x150", next2
          )
          .seq_((next2, entry) ->
            if entry.isNew or entry.isModified()
              entry.save next2.into("entry")
            else
              next2("Already Exist: #{entry.path}")
          )
          .seq_((next2) ->
            console.log "Save: #{next2.vars.entry.path}"
            io.sockets.emit 'save_entry', {name: next2.vars.entry.name, path: next2.vars.entry.path}
            next(null, f)
          )
          .catch((err) ->
            console.log err
            next(null, f)
          )
      entry_update(f)
    )
    .seq_((next) ->
      console.log "All Updated: #{target}"
      io.sockets.emit 'all_updated', target
      em.emit 'db_update_end' if em
    )
    .catch((err) ->
      console.log err
      em.emit 'db_update_end' if em
    )


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
  Seq()
    .seq_((next) ->
      watchModel.find {}, next
    )
    .seq_((next, watches) ->
      em = new events.EventEmitter
      em.on 'db_update_end', ->
        w = watches.shift()
        if w
          db_update(w.dir, em)

      em.emit 'db_update_end'
    )
    .catch((err) ->
      console.err
    )
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
  else if q.substr(0, 1) == '#'
    query = {path : new RegExp(q.substr(1), "i")}
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

app.del '/movie/:id', (req, res) ->
  Seq()
    .seq_((next) ->
      movieModel.findById req.params.id, next
    )
    .seq_((next, movie) ->
      movie.remove next
    )
    .seq_((next) ->
      if req.query.xhr
        res.send req.params.id
      else
        res.redirect '/movies'
    )
    .catch((err) ->
      res.send err.message, 422
    )

## Books
app.get '/book/:id/play', (req, res) ->
  Seq()
    .par_((next) ->
      playerModel.findById req.query.pid, next
    )
    .par_((next) ->
      bookModel.findById req.params.id, next
    )
    .seq_((next, player, book) ->
      cmd = "open"
      args = ["-a", "#{player.path}"]
      args.push "#{book.path}"
      book.play(cmd, args)
      res.send book
    )
    .catch((err) ->
      res.send("Cannot Start Play", 422)
    )

app.get '/books/:page?', (req, res) ->
  per_page = if req.body?.per_page then parseInt(req.body.per_page) else 200
  page = if req.params.page then parseInt req.params.page else 1
  paginate = require 'paginate-js'
  order_check(req)

  Seq()
    .par_((next) ->
      playerModel.find {}, next
    )
    .par_((next) ->
      bookModel.count {}, next
    )
    .seq_((next, players, count) ->
      player_options = players.reduce((html, p) ->
        html += "<option value=\"#{p._id}\">#{p.name}</option>"
      , "")
      p = paginate {count_elements: count, elements_per_page: per_page}
      next(null, player_options, count, p)
    )
    .seq_((next, player_options, count, p) ->
      bookModel.find({}).sort(req.session.order[0], req.session.order[1]).skip((page-1) * per_page).limit(per_page).execFind (err, books) ->
        if req.query.xhr && req.params.page
          res.render 'books/list', {layout: false, books: books, p: p, count: count, page: page, player_options: player_options}
        else if req.query.xhr
          res.render 'books/index', {layout: false, books: books, p: p, count: count, page: page, player_options: player_options}
        else
          res.render 'books/index', {books: books, p: p, count: count, page: page, player_options: player_options}
    )

search_books = (req, res, q) ->
  per_page = if req.body?.per_page then parseInt(req.body.per_page) else 200
  page = if req.params.page then parseInt req.params.page else 1
  paginate = require 'paginate-js'
  order_check(req)
  if q.substr(0, 1) == '!'
    query = {tag : q.substr(1)}
  else if q.substr(0, 1) == '#'
    query = {path : new RegExp(q.substr(1), "i")}
  else
    query = {'$or' : [{name : new RegExp(q, "i")}, {tag : q}]}

  Seq()
    .par_((next) ->
      playerModel.find {}, next
    )
    .par_((next) ->
      bookModel.count query, next
    )
    .seq_((next, players, count) ->
      player_options = players.reduce((html, p) ->
        html += "<option value=\"#{p._id}\">#{p.name}</option>"
      , "")
      p = paginate {count_elements: count, elements_per_page: per_page}
      next(null, player_options, count, p)
    )
    .seq_((next, player_options, count, p) ->
      bookModel.find(query).sort(req.session.order[0], req.session.order[1]).skip((page-1) * per_page).limit(per_page).execFind (err, books) ->
        if req.query.xhr
          res.render 'books/list', {layout: false, books: books, p: p, count: count, page: page, player_options: player_options, search: true}
        else
          res.render 'books/index', {books: books, p: p, count: count, page: page, player_options: player_options, search: true}
    )

app.get '/books/search/:page?', (req, res) ->
  q = req.query.q
  req.q = q
  search_books req, res, q

app.post '/books/search/:page?', (req, res) ->
  q = req.body.q
  req.q = q
  search_books req, res, q

app.del '/book/:id', (req, res) ->
  Seq()
    .seq_((next) ->
      bookModel.findById req.params.id, next
    )
    .seq_((next, book) ->
      book.remove next
    )
    .seq_((next) ->
      if req.query.xhr
        res.send req.params.id
      else
        res.redirect '/books'
    )
    .catch((err) ->
      res.send err.message, 422
    )

port = if opts.get 'port' then parseInt(opts.get('port')) else 4000
app.listen port
console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env


## Socket.IO
io = require('socket.io').listen(app)
io.sockets.on 'connection', (socket) ->
  console.log "Get Connection from Browser"

  socket.on 'disconnect', ->
    console.log "Disconnect"
