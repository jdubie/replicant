should = require('should')
util = require('util')
request = require('request')

{TestUser, TestCard} = require('lib/test_models')
config = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'y POST /cards', () ->

  user = new TestUser('post_card_user')
  card = new TestCard('post_card', user)
  userDb = config.nanoAdmin.db.use("users_#{user._id}")

  before (ready) ->
    app = require('app')
    user.create(ready)

  after (finished) ->
    user.destroy(finished)

  it 'should POST the card correctly', (done) ->
    opts =
      method: 'POST'
      url: "http://localhost:3001/cards"
      json: card.attributes()
      headers: cookie: user.cookie
    request opts, (err, res, cardDoc) ->
      should.not.exist(err)
      res.statusCode.should.eql(201)
      cardDoc.should.have.keys(['_id', '_rev', 'mtime', 'ctime'])
      card[key] = value for key, value of cardDoc
      done()

  it 'should actually be there', (done) ->
    userDb.get card._id, (err, cardDoc) ->
      should.not.exist(err)
      cardDoc.should.eql(card.attributes())
      done()


