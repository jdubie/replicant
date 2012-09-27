should  = require('should')
async   = require('async')
request = require('request')

config = require('config')
{TestUser, TestShortlink} = require('lib/test_models')


describe 'DELETE /shortlinks/:id', () ->

  user = new TestUser('delete_shortlinks_id_user')
  shortlink = new TestShortlink('delete_shortlinks_id', user)

  mainDb = config.db.main()

  before (ready) ->
    app = require('app')
    async.parallel([user.create, shortlink.create], ready)

  after (finished) ->
    async.parallel([user.destroy, shortlink.destroy], finished)


  it 'should 400 on bad input', (done) ->
    json = shortlink.attributes()
    verifyField = (field, callback) ->
      value = json[field]
      delete json[field]
      opts =
        url: "http://localhost:3001/shortlinks/#{shortlink._id}"
        method: 'DELETE'
        json: json
        headers: cookie: user.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 400)
        body.should.have.keys(['error', 'reason'])
        body.reason.should.have.property(field)

        json[field] = value
        callback()
    async.map(['_rev'], verifyField, done)

  it 'should return a 200', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/shortlinks/#{shortlink._id}"
      headers: cookie: user.cookie
      json: shortlink.attributes()
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.equal(200)
      body.should.have.property('ok', true)
      body.should.have.property('id', shortlink._id)
      body.should.have.property('rev')
      done()


  it 'should actually remove document', (done) ->
    mainDb.get shortlink._id, (err, shortlinkDoc) ->
      should.not.exist(shortlinkDoc)
      should.exist(err)
      err.should.have.property('status_code', 404)
      done()
