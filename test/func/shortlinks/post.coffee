should  = require('should')
async   = require('async')
request = require('request').defaults(jar: false)

config  = require('config')
{TestUser, TestShortlink} = require('lib/test_models')


describe 'POST /shortlinks', () ->

  user = new TestUser('postshortlinkuser')
  shortlink = new TestShortlink('postshortlink', user)

  mainDb = config.db.main()

  before (ready) ->
    app = require('app')
    user.create(ready)

  after (finished) ->
    async.parallel([user.destroy, shortlink.destroy], finished)

  it 'should return _rev, mtime, ctime', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/shortlinks"
      json: shortlink.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      body.should.have.keys(['_rev', 'mtime', 'ctime'])
      for key, val of body
        shortlink[key] = val
      done()

  it 'should actually put the document in the DB', (done) ->
    mainDb.get shortlink._id, (err, shortlinkDoc) ->
      should.not.exist(err)
      shortlinkDoc.should.eql(shortlink.attributes())
      done()
