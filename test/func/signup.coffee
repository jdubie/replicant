request = require('request')
nano = require('nano')('http://lifeswaptest:5985')
should = require('should')

describe 'func #signup', () ->

  user = 'user1'
  password = 'pass1'
  cookie = null

  app = null

  before (ready) ->
    # @todo setup webserver
    app = require('../../app.coffee')
    nano.auth user, password, (err, body, headers) ->
      should.not.exist(err)
      should.exist(headers and headers['set-cookie'])
      cookie = headers['set-cookie'][0]
      ready()

  it 'should parse the cookies correctly', (done) ->
    app.setController controller: 'signup', ({userId}, callback) ->
      userId.should.equal(user)
      callback()
    opts =
      url: 'http://localhost:3000/signup' # @todo get port from server
      headers: cookie: cookie
    request.post(opts, done)

  it 'should return 403 Forbidden if user is not authenticated', () ->
    app.setController controller: 'signup', ({userId}, callback) ->
      callback(status: 403)
    opts =
      url: 'http://localhost:3000/signup'
      cookie: 'AuthSession=baddcjE6NEZGMjRCNkM6lkgZRSt2jUVNaZeDXjpjRavr0Mg; Version=1; Path=/; HttpOnly'
    request.post opts, (err) ->
      should.exist(err)
      err.status.should.equal(403)

  # @todo maybe this should be another error to prevent browser
  it 'should return 401 Unauthorized if user has no session', () ->
    app.setController controller: 'signup', ({userId}, callback) ->
      callback(status: 401)
    opts =
      url: 'http://localhost:3000/signup'
    request.post opts, (err) ->
      should.exist(err)
      err.status.should.equal(401)

  it 'should return 500 when fails to create user db', () ->
    app.setController controller: 'signup', ({userId}, callback) ->
      callback(status: 500)
    opts =
      url: 'http://localhost:3000/signup'
      cookie: cookie
    request.post opts, (err) ->
      should.exist(err)
      err.status.should.equal(500)
