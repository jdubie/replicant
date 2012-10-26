should  = require('should')
async   = require('async')
request = require('request').defaults(jar: false)

config = require('config')
{TestUser} = require('lib/test_models')


describe 'DELETE /user_ctx', () ->

  user = new TestUser('delete_user_ctx')

  ##  Start the app
  before (ready) ->
    # start webserver
    app = require('app')
    user.create(ready)

  after (finished) ->
    user.destroy(finished)

  it 'should reset the cookie', (done) ->
    opts =
      url: "http://localhost:3001/user_ctx"
      method: 'DELETE'
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 200)
      done()

  it 'should reset cookie even when not logged in', (done) ->
    opts =
      url: "http://localhost:3001/user_ctx"
      method: 'DELETE'
      json: true
      headers: cookie: "AuthSession=ZTZmMTY3NzQ1MzU0NTczMzE0ZGQzYmZlOWQ3ZGE0M2IzMjgzZjc4OTo1MDZGOEQ4MDoTqAbMVcaTeA2KbK2o2KU9j_Ia0w; Version=1; Path=/; HttpOnly"
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 200)
      done()
