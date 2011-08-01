mongoose = require 'mongoose'
Schema = mongoose.Schema
{spawn} = require 'child_process'
zipfile = require 'zipfile'

Book = new Schema {
  name: {type: String, required: true, index: true}
  path: {type: String, required: true, index: {unique: true, dropDups: true}}
  size: {type: Number, required: true}
  regist_date: {type: Date, index: true}
  view_count: {type: Number, default: 0}
  container: {type: String}
  tag: [String]
  md5_hash: {type: String, required: true}
  title: {type: String}
  artist: {type: String}
  genre: {type: String}
}

Book.method {
  create_thumbnail: (count = 6) ->
    zf = new zipfile.ZipFile @path
    if zf.count > (count - 1)
      targets = zf.names.filter (name, i) ->
        (i % parseInt(zf.count / (count - 1))) == 0
    else
      targets = zf.names
}

exports.Book = Book
