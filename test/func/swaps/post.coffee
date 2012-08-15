should = require('should')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')
{createUser} = require('lib/replicant')


mainDb = nanoAdmin.db.use('lifeswap')


describe 'POST /swaps', () ->

  _swapDoc =
    _id: 'postswaps'
    type: 'swap'

  before (ready) ->
    ## start webserver
    app = require('../../../app')
    ready()


  after (finished) ->
    mainDb.get _swapDoc._id, (err, swapDoc) ->
      should.not.exist(err)
      swapDoc.should.eql(_swapDoc)
      mainDb.destroy swapDoc._id, swapDoc._rev, (err, res) ->
        should.not.exist(err)
        finished()

  it 'should POST the swap correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/swaps"
      json: _swapDoc
    request opts, (err, res, body) ->
      should.not.exist(err)
      body.should.have.keys(['_rev', 'mtime', 'ctime'])
      for key, val of body
        _swapDoc[key] = val
      done()
