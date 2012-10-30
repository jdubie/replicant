should  = require('should')
async   = require('async')
request = require('request').defaults(jar: false)

config = require('config')
{TestUser, TestRequest} = require('lib/test_models')


describe 'DELETE /requests/:id', () ->

  user = new TestUser('deleterequestuser')
  _request = new TestRequest('deleterequest', user)

  mainDb = config.db.main()

  before (ready) ->
    ## start webserver
    app = require('app')
    ## insert user and request
    async.parallel([user.create, _request.create], ready)

  after (finished) ->
    ## destroy user and request
    async.parallel([user.destroy, _request.destroy], finished)

  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/requests/#{_request._id}"
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()

  it 'should not delete \'request\' type entry in lifeswap db', (done) ->
    mainDb.get _request._id, (err, requestDoc) ->
      should.not.exist(err)
      requestDoc.should.eql(_request.attributes())
      done()
