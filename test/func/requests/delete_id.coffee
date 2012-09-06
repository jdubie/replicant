should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nano, nanoAdmin} = require('config')
{hash} = require('lib/helpers')


describe 'DELETE /requests/:id', () ->

  ## simple test - for now should just 403 (forbidden)

  ## from toy data
  _username = hash('user2@test.com')
  _userId = 'user2_id'
  _password = 'pass2'
  _ctime = _mtime = 12345
  _request =
    _id: 'deleterequest'
    type: 'request'
    name: _username
    user_id: _userId
    title: 'Delete Request'
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

    async.series [
      authUser
      insertRequest
    ], ready


  after (finished) ->
    ## destroy request
    mainDb.destroy(_request._id, _request._rev, finished)


  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/requests/#{_request._id}"
      json: true
      headers: cookie: cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()


  it 'should not delete \'request\' type entry in lifeswap db', (done) ->
    mainDb.get _request._id, (err, requestDoc) ->
      should.not.exist(err)
      requestDoc.should.eql(_request)
      done()
