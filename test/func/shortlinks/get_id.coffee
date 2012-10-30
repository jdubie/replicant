should  = require('should')
async   = require('async')
request = require('request').defaults(jar: false)

{TestUser, TestShortlink} = require('lib/test_models')

describe 'GET /shortlinks/:id', () ->

  user      = new TestUser('get_shortlinks_id_user')
  shortlink = new TestShortlink('get_shortlinks_id', user)

  before (ready) ->
    ## start webserver
    app = require('app')
    async.series [
      user.create
      shortlink.create
    ], ready

  after (finished) ->
    async.series [
      shortlink.destroy
      user.destroy
    ], finished

  it 'should get the correct url', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/shortlinks/#{shortlink._id}"
      json: true
    request opts, (err, res, _shortlink) ->
      should.not.exist(err)
      _shortlink.should.eql(shortlink.attributes())
      done()
