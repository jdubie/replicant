should  = require('should')
async   = require('async')
request = require('request')

config  = require('config')

describe 'GET /shortlinks/:id', () ->

  couch = config.couch()
  db    = couch.use('shortlinks')
  shortlink =
    _id: 'yadda'
    url: '/swaps/swap1'

  before (ready) ->
    ## start webserver
    app = require('app')
    async.series [
      (cb) -> couch.db.create('shortlinks', cb)
      (cb) ->
        db.insert shortlink, shortlink._id, (err, res) ->
          shortlink._rev = res.rev
          cb()
    ], ready

  after (finished) ->
    couch.db.destroy('shortlinks', finished)

  it 'should get the correct url', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/shortlinks/#{shortlink._id}"
      json: true
    request opts, (err, res, body) ->
      should.not.exist(err)
      body.should.have.property('url', shortlink.url)
      done()
