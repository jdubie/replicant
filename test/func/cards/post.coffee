should  = require('should')
async   = require('async')
request = require('request')

config  = require('config')
{TestUser, TestCard} = require('lib/test_models')


describe 'POST /cards', () ->

  user = new TestUser('post_card_user')
  card = new TestCard('post_card', user)

  userDb = config.db.user(user._id)

  before (ready) ->
    app = require('app')
    user.create(ready)

  after (finished) ->
    async.series([card.destroy, user.destroy], finished)


  it 'should 400 on bad input', (done) ->
    json = card.attributes()
    verifyField = (field, callback) ->
      value = json[field]
      delete json[field]
      opts =
        method: 'POST'
        url: "http://localhost:3001/cards"
        json: json
        headers: cookie: user.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 400)
        body.should.have.keys(['error', 'reason'])
        body.reason.should.have.property(field)

        json[field] = value
        callback()
    async.map(['_id', 'user_id'], verifyField, done)


  it 'should POST the card correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/cards"
      json: card.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, cardDoc) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 201)
      cardDoc.should.have.keys(['_id', '_rev', 'mtime', 'ctime'])
      card[key] = value for key, value of cardDoc
      done()

  it 'should actually be there', (done) ->
    userDb.get card._id, (err, cardDoc) ->
      should.not.exist(err)
      cardDoc.should.eql(card.attributes())
      done()
