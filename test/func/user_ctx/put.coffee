should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nano, nanoAdmin, dbUrl} = require('config')
{hash} = require('lib/helpers')

describe 'PUT /user_ctx', () ->

  getCouchUser = (name) -> "org.couchdb.user:#{name}"

  _name = 'put_userctx'
  _oldPass = 'password'
  _user =
    _id: getCouchUser(_name)
    name: _name
    type: 'user'
    roles: []
    password: _oldPass

  _newPass = 'passnew'
  cookie = null

  usersDb = nanoAdmin.db.use('_users')

  describe 'correctness:', () ->

    ##  Start the app
    before (ready) ->
      # start webserver
      app = require('app')
      async.series [
        (next) ->
          usersDb.insert(_user, _user._id, next)
        (next) ->
          nano.auth _name, _oldPass, (err, body, headers) ->
            should.not.exist(err)
            should.exist(headers and headers['set-cookie'])
            cookie = headers['set-cookie'][0]
            next()
      ], ready

    after (finished) ->
      usersDb.get getCouchUser(_name), (err, userDoc) ->
        should.not.exist(err)
        usersDb.destroy(getCouchUser(_name), userDoc._rev, finished)

    it 'should pass back a \'set-cookie\' header', (done) ->
      opts =
        url: 'http://localhost:3001/user_ctx'
        method: 'PUT'
        json:
          name: _name
          oldPass: _oldPass
          newPass: _newPass
        headers: {cookie}
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.statusCode.should.eql(201)
        res.headers.should.have.property('set-cookie')
        cookie = res.headers['set-cookie']
        done()

    it 'should get the correct userCtx from _session', (done) ->
      opts =
        url: "#{dbUrl}/_session"
        method: 'GET'
        json: true
        headers: {cookie}
      request opts, (err, res, body) ->
        should.not.exist(err)
        body.should.have.property('userCtx')
        body.userCtx.should.eql(name: _name, roles: [])
        done()
