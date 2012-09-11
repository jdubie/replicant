should  = require('should')
async   = require('async')
request = require('request')

{nanoAdmin} = require('config')
{TestUser, TestRequest} = require('lib/test_models')


describe 'POST /requests', () ->

  user = new TestUser('postrequestuser')
  _request = new TestRequest('postrequest', user)

  mainDb = nanoAdmin.db.use('lifeswap')

  before (ready) ->
    app = require('app')
    user.create(ready)

  after (finished) ->
    async.parallel([user.destroy, _request.destroy], finished)

  it 'should return _rev, mtime, ctime', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/requests"
      json: _request.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      body.should.have.keys(['_rev', 'mtime', 'ctime'])
      for key, val of body
        _request[key] = val
      done()

  it 'should actually put the document in the DB', (done) ->
    mainDb.get _request._id, (err, requestDoc) ->
      should.not.exist(err)
      requestDoc.should.eql(_request.attributes())
      done()
