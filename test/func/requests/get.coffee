should = require('should')
util = require('util')
async = require('async')
request = require('request')

{nanoAdmin} = require('config')
{hash} = require('lib/helpers')


describe 'GET /requests', () ->

  _ctime = _mtime = 12345
  _requests = [
    {
      _id: 'getrequests1'
      type: 'request'
      name: hash('user1@test.com')
      user_id: 'user1_id'
      ctime: _ctime
      mtime: _mtime
      foo: 'bar'
    }
    {
      _id: 'getrequests2'
      type: 'request'
      name: hash('user2@test.com')
      user_id: 'user2_id'
      ctime: _ctime
      mtime: _mtime
      foo: 'bar'
    }
  ]

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    # start webserver
    app = require('app')
    ## insert request
    insertRequest = (_request, cb) ->
      mainDb.insert _request, _request._id, (err, res) ->
        _request._rev = res.rev
        cb()
    async.map(_requests, insertRequest, ready)

  after (finished) ->
    destroyRequest = (_request, cb) ->
      mainDb.destroy(_request._id, _request._rev, cb)
    async.map(_requests, destroyRequest, finished)

  it 'should provide a list of all the correct requests', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/requests'
      json: true
    request opts, (err, res, requests) ->
      should.not.exist(err)
      requests.should.eql(_requests)
      done()
