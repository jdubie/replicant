should  = require('should')
async   = require('async')
request = require('request')

config  = require('config')
{TestUser, TestShortlink} = require('lib/test_models')


describe 'PUT /shortlinks/:id', () ->

  user     = new TestUser('put_shortlinks_id_user')
  shortlink = new TestShortlink('put_shortlinks_id', user)

  mainDb = config.db.main()

  before (ready) ->
    app = require('app')
    async.parallel([user.create, shortlink.create], ready)

  after (finished) ->
    async.parallel([user.destroy, shortlink.destroy], finished)

  it 'should return _rev and mtime', (done) ->
    shortlink.target_url = '/swaps/swap2'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/shortlinks/#{shortlink._id}"
      json: shortlink.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      should.exist(res)
      res.should.have.property('statusCode', 200)
      body.should.have.keys(['_rev', 'mtime'])
      for key, val of body
        shortlink[key] = val
      done()

  it 'should modify the document in the DB', (done) ->
    mainDb.get shortlink._id, (err, shortlinkDoc) ->
      should.not.exist(err)
      shortlinkDoc.should.eql(shortlink.attributes())
      done()
