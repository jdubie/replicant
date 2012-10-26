should  = require('should')
async   = require('async')
request = require('request').defaults(jar: false)

config = require('config')
h      = require('lib/helpers')
{TestUser, TestCard} = require('lib/test_models')


describe 'PUT /cards/:id', () ->

  user = new TestUser('put_card_id_user')
  card = new TestCard('put_card_id', user)
  userDb = config.db.user(user._id)

  before (ready) ->
    app = require('app')
    async.series([user.create, card.create], ready)

  after (finished) ->
    async.series([card.destroy, user.destroy], finished)

  it 'should not allow editing of balanced url on a card', (done) ->
    oldUrl = card.balanced_url
    card.balanced_url = '/different/one'
    opts =
      method: 'PUT'
      url: "http://localhost:3001/cards/#{card._id}"
      json: card.attributes()
      headers: cookie: user.cookie
    h.request opts, (err, body) ->
      should.exist(err)
      err.should.have.property('statusCode', 403)
      done()
    card.balanced_url = oldUrl

  it 'should not have modified card in db', (done) ->
    userDb.get card._id, (err, cardDoc) ->
      should.not.exist(err)
      cardDoc.should.eql(card.attributes())
      done()
