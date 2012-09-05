should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{hash} = require('lib/helpers')


describe 'PUT /requests/:id', () ->

  ## from toy data
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _request =
    _id: 'putrequestsid'
    type: 'request'
    name: _username
    user_id: _userId
    title: 'PUT Request'
    ctime: _ctime
    mtime: _mtime
    foo: 'bar'

  cookie = null

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('app')
    ## authenticate user
    authUser = (callback) ->
      nano.auth _username, _password, (err, body, headers) ->
        should.not.exist(err)
        should.exist(headers and headers['set-cookie'])
        cookie = headers['set-cookie'][0]
        callback()
    ## insert request
    insertRequest = (callback) ->
      mainDb.insert _request, (err, res) ->
        should.not.exist(err)
        _request._rev = res.rev
        callback()
    ## in parallel
    async.series [
      authUser
      insertRequest
    ], ready


  after (finished) ->
    ## destroy request
    mainDb.destroy(_request._id, _request._rev, finished)


  it 'should return _rev and mtime', (done) ->
    _request.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/requests/#{_request._id}"
      json: _request
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      should.exist(res)
      res.should.have.property('statusCode')
      res.statusCode.should.eql(200)
      body.should.have.keys(['_rev', 'mtime'])
      for key, val of body
        _request[key] = val
      done()

  it 'should modify the document in the DB', (done) ->
    mainDb.get _request._id, (err, requestDoc) ->
      should.not.exist(err)
      requestDoc.should.eql(_request)
      done()
