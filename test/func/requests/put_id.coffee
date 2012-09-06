should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano} = require('config')
{hash} = require('lib/helpers')
{TestUser, TestRequest} = require('lib/test_models')


describe 'yyy PUT /requests/:id', () ->

  user = new TestUser('deleterequestuser')
  _request = new TestRequest('deleterequest', user)

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user and request
    async.parallel([user.create, _request.create], ready)

  after (finished) ->
    ## insert user and request
    async.parallel([user.destroy, _request.destroy], finished)


  it 'should return _rev and mtime', (done) ->
    _request.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/requests/#{_request._id}"
      json: _request.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      should.exist(res)
      res.should.have.property('statusCode', 200)
      body.should.have.keys(['_rev', 'mtime'])
      for key, val of body
        _request[key] = val
      done()

  it 'should modify the document in the DB', (done) ->
    mainDb.get _request._id, (err, requestDoc) ->
      should.not.exist(err)
      requestDoc.should.eql(_request.attributes())
      done()
