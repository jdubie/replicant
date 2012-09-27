should  = require('should')
async   = require('async')
request = require('request')

{TestUser, TestShortlink} = require('lib/test_models')

describe 'GET /shortlinks', () ->

  user1      = new TestUser('get_shortlinks_user1')
  user2      = new TestUser('get_shortlinks_user2')
  shortlink1 = new TestShortlink('get_shortlinks1', user1)
  shortlink2 = new TestShortlink('get_shortlinks2', user2)

  before (ready) ->
    # start webserver
    app = require('app')
    ## insert shortlinks
    async.parallel [
      shortlink1.create
      shortlink2.create
    ], ready

  after (finished) ->
    ## destroy shortlinks
    async.parallel [
      shortlink1.destroy
      shortlink2.destroy
    ], finished

  it 'should provide a list of all the correct shortlinks', (done) ->
    opts =
      method: 'GET'
      url: 'http://localhost:3001/shortlinks'
      json: true
    request opts, (err, res, shortlinks) ->
      should.not.exist(err)
      shortlinksNano = [shortlink1.attributes(), shortlink2.attributes()]
      shortlinks.should.eql(shortlinksNano)
      done()
