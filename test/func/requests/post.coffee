should = require('should')
util = require('util')
request = require('request')

{nanoAdmin} = require('config')


describe 'POST /requests', () ->

  _request =
    _id: 'postrequests'
    type: 'request'
  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('../../../app')
    ready()


  after (finished) ->
    mainDb.destroy(_request._id, _request._rev, finished)

  it 'should return _rev, mtime, ctime', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/swaps"
      json: _request
    request opts, (err, res, body) ->
      should.not.exist(err)
      body.should.have.keys(['_rev', 'mtime', 'ctime'])
      for key, val of body
        _request[key] = val
      done()

  it 'should actually put the document in the DB', (done) ->
    mainDb.get _request._id, (err, requestDoc) ->
      should.not.exist(err)
      requestDoc.should.eql(_request)
      done()
