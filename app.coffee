###
 Module dependencies.
###

express = require 'express'
mongoose = require 'mongoose'
Schema = mongoose.Schema
fs = require 'fs'
path = require 'path'
crypto = require 'crypto'
{exec} = require 'child_process'

{FileSearcher} = require './search_file'
{MovieFactory} = require './movie_factory'
thumbnailer = require './ffmpegthumbnailer'
ffmpeg_info = require './ffmpeg_info'

{Watch} = require './watch'
{Movie} = require './movie'

watchModel = mongoose.model('Watch', Watch)
movieModel = mongoose.model('Movie', Movie)

app = module.exports = express.createServer()

app.configure ->
  app.set 'views', __dirname + '/views'
  app.register '.coffee',  require('coffeekup')
  app.set 'view engine', 'jade'
  app.use express.logger()
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use express.compiler({ src: __dirname + '/public', enable: ['sass'] })
  app.use app.router
  app.use express.static(__dirname + '/public')

app.configure 'development', ->
  app.use express.errorHandler({ dumpExceptions: true, showStack: true })
  mongoose.connect('mongodb://localhost/blackalbum_dev')

app.configure 'production', ->
  app.use express.errorHandler()
  mongoose.connect('mongodb://localhost/blackalbum')


## dynamicHelper

app.dynamicHelpers {
  req: (req, res) ->
    return req
}

db_update = (target) ->
  fsearch = new FileSearcher(/\.(mp4|flv|mpe?g|mkv|ogm|wmv|asf|avi|mov|rmvb)$/)
  fsearch.search target, 0, (err, f) ->
    movie_factory = new MovieFactory f
    movie_factory.get_movie 6, (movie) ->
      movie.save (err) ->
        if !err
          console.log "Save: #{movie.path}"

## Routes

app.get '/', (req, res) ->
  res.render 'index', {
    title: 'Express'
  }

app.get '/updatedb', (req, res) ->
  db_update('/Volumes/bacchus_data/freenas_files/お笑い')
  res.send "Update Start"

app.get '/watch', (req, res) ->
  watch = new watchModel
  res.render 'watches/new', {title: 'New Watch List', watch: watch}

app.post '/watch', (req, res) ->
  watch = new watchModel req.body.watch
  watch.save (err) ->
    if !err
      res.render 'watches/watch', {layout: false, watch: watch}
    else
      console.log err
      res.send err.message, 422

app.get '/watch/:id', (req, res) ->
  watch = watchModel.findById req.params.id, (err, watch) ->
    if !err
      res.render 'watches/form', {layout: false, watch: watch}
    else
      res.redirect('/watches', err: err)

app.put '/watch/:id', (req, res) ->
  watch = watchModel.findById req.params.id, (err, watch) ->
    if !err
      watch.dir = req.body.watch.dir
      watch.save (err2) ->
        if !err2
          res.send watch
        else
          res.send err2.message, 422

app.del '/watch/:id', (req, res) ->
  watch = watchModel.findById req.params.id, (err, watch) ->
    if !err
      watch.remove (err) ->
        if !err
          res.send watch
        else
          console.log err
          res.send("Delete Failed", 422)

app.get '/watches', (req, res) ->
  watchModel.find {}, (err, watches) ->
    res.render 'watches/index', {title: 'Watch List', watches: watches}

app.listen 4000
console.log "Express server listening on port %d in %s mode", app.address().port, app.settings.env
