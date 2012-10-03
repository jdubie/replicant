should  = require('should')
async   = require('async')
request = require('request')

config = require('config')
{TestUser, TestLike} = require('lib/test_models')


describe 'DELETE /likes/:id', () ->

  user = new TestUser('delete_likes_id_user')
  like = new TestLike('delete_likes_id', user)

  mainDb = config.db.main()

  before (ready) ->
    app = require('app')
    async.parallel([user.create, like.create], ready)

  after (finished) ->
    async.parallel([user.destroy, like.destroy], finished)


  it 'should 400 on bad input', (done) ->
    json = like.attributes()
    verifyField = (field, callback) ->
      value = json[field]
      delete json[field]
      opts =
        url: "http://localhost:3001/likes/#{like._id}"
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
      url: "http://localhost:3001/likes/#{like._id}"
      headers: cookie: user.cookie
      json: like.attributes()
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.statusCode.should.equal(200)
      body.should.have.property('_rev')
      done()


  it 'should actually remove document', (done) ->
    mainDb.get like._id, (err, likeDoc) ->
      should.not.exist(likeDoc)
      should.exist(err)
      err.should.have.property('status_code', 404)
      done()
