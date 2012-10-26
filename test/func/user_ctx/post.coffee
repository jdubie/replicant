should  = require('should')
async   = require('async')
request = require('request')

config = require('config')
{TestUser} = require('lib/test_models')

describe 'yyy POST /user_ctx (login)', () ->

  user = new TestUser('post_user_ctx')

  ##  Start the app
  before (ready) ->
    # start webserver
    app = require('app')
    user.create(ready)

  after (finished) ->
    user.destroy(finished)

  it 'should pass back a \'set-cookie\' header', (done) ->
    opts =
      url: 'http://localhost:3001/user_ctx'
      method: 'POST'
      json:
        username: user.email_address
        password: user.password
    request opts, (err, res, body) ->
      should.not.exist(err)
      body.should.eql(
        name: user.name, roles: user.roles, user_id: user._id
      )
      res.should.have.property('statusCode', 200)
      res.headers.should.have.property('set-cookie')
      user.cookie = res.headers['set-cookie']
      done()

  it 'should 400 on bad input', (done) ->
    json =
      username: user.email_address
      password: user.password
    verifyField = (field, callback) ->
      value = json[field]
      delete json[field]
      opts =
        url: 'http://localhost:3001/user_ctx'
        method: 'POST'
        json: json
        headers: cookie: user.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 400)
        body.should.have.keys(['error', 'reason'])
        body.reason.should.have.property(field)

        json[field] = value
        callback()
    async.map(['username', 'password'], verifyField, done)
