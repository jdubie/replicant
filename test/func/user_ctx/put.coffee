should  = require('should')
async   = require('async')
request = require('request')

config = require('config')
{TestUser} = require('lib/test_models')

describe 'yyy PUT /user_ctx', () ->

  user = new TestUser('put_user_ctx')

  _oldPass = user.password
  _newPass = "#{user.password}_new"

  describe 'correctness:', () ->

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
        method: 'PUT'
        json:
          name: user.name
          oldPass: _oldPass
          newPass: _newPass
        headers: cookie: user.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 201)
        res.headers.should.have.property('set-cookie')
        user.cookie = res.headers['set-cookie']
        done()

    it 'should get the correct userCtx from _session', (done) ->
      opts =
        url: "#{config.dbUrl}/_session"
        method: 'GET'
        json: true
        headers: cookie: user.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        body.should.have.property('userCtx')
        body.userCtx.should.eql(name: user.name, roles: user.roles)
        done()
