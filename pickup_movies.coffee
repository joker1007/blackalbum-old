{FileSearcher} = require './search_file'
path = '/Users/Joker'
fs = require 'fs'

fsearch = new FileSearcher(/\.(mp4|flv|mpe?g|mkv|ogm|wmv|asf|avi|mov|rmvb)$/)

fsearch.search path, 0, (err, f) ->
  fs.open f, 'r', (err, fd) ->
    buffer = ''
    fs.read fd, buffer, 0, 300 * 1024, 0, (err, bytesRead, buffer) ->
