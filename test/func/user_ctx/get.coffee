should  = require('should')
async   = require('async')
request = require('request')

config = require('config')
{TestUser} = require('lib/test_models')


describe 'GET /user_ctx', () ->

  user = new TestUser('get_user_ctx')

  ##  Start the app
  before (ready) ->
    # start webserver
    app = require('app')
    user.create(ready)

  after (finished) ->
    user.destroy(finished)

  it 'should pass back a userCtx object', (done) ->
    opts =
      url: "http://localhost:3001/user_ctx"
      method: 'GET'
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      res.should.have.property('statusCode', 200)
      should.not.exist(err)
      body.should.have.keys('name', 'roles', 'user_id')
      body.name.should.eql user.name
      body.roles.should.eql user.roles
      body.user_id.should.eql user._id
      done()

  it 'should get back empty userCtx if not logged in', (done) ->
    opts =
      url: "http://localhost:3001/user_ctx"
      method: 'GET'
      json: true
      headers: cookie: "AuthSession=ZTZmMTY3NzQ1MzU0NTczMzE0ZGQzYmZlOWQ3ZGE0M2IzMjgzZjc4OTo1MDZGOEQ4MDoTqAbMVcaTeA2KbK2o2KU9j_Ia0w; Version=1; Path=/; HttpOnly"
    request opts, (err, res, body) ->
      res.should.have.property('statusCode', 200)
      should.not.exist(err)
      body.should.eql(name: null, roles: [])
      done()
