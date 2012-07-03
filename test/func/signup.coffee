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

      #it 'should signup user correctly', (done) ->
      #  opts =
      #    url: 'http://localhost:3000/signup' # @todo get port from server
      #    headers: cookie: cookie
      #  request.post(opts, done)

      #it 'should return 403 Forbidden if user is not authenticated', () ->
      #  opts =
      #    url: 'http://localhost:3000/signup'
      #    cookie: 'AuthSession=baddcjE6NEZGMjRCNkM6lkgZRSt2jUVNaZeDXjpjRavr0Mg; Version=1; Path=/; HttpOnly'
      #  request.post opts, (err) ->
      #    should.exist(err)
      #    err.status.should.equal(403)

  # @todo shutdown couch for this?
  #it 'should return 500 when fails to create user db', () ->
  #  opts =
  #    url: 'http://localhost:3000/signup'
  #    cookie: cookie
  #  request.post opts, (err) ->
  #    should.exist(err)
  #    err.status.should.equal(500)
