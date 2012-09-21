should  = require('should')
async   = require('async')
request = require('request')

config  = require('config')
h       = require('lib/helpers')
{TestUser} = require('lib/test_models')


describe 'PUT /users/:id', () ->

  user = new TestUser('put_users_id', foo: 'put bar')

  mainDb = config.db.main()

  before (ready) ->
    ## start webserver
    app = require('app')
    user.create(ready)

  after (finished) ->
    user.destroy(finished)

  it 'should put the user\'s document correctly', (done) ->
    _userDoc = user.attributes()
    _userDoc.foo = 'c3p0'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/users/#{user._id}"
      json: _userDoc
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      body.should.have.keys(['_rev', 'mtime'])
      for key, val of body
        user[key] = val
      done()

  it 'should change the user document', (done) ->
    _userDoc = user.attributes()
    _userDoc.foo = 'c3p0'
    mainDb.get user._id, (err, userDoc) ->
      should.not.exist(err)
      userDoc.should.eql(_userDoc)
      done()
