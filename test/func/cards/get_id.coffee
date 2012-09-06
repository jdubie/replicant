should = require('should')
async = require('async')
util = require('util')
request = require('request')

{TestUser, TestCard} = require('lib/test_models')
{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'y GET /cards/:id', () ->

  user = new TestUser('get_card_id_user')
  card = new TestCard('get_card_id', user)

  before (ready) ->
    app = require('app')
    async.series([user.create, card.create], ready)

  after (finished) ->
    user.destroy(finished)

  it 'should GET the card', (done) ->
    opts =
      method: 'GET'
      url: "http://localhost:3001/cards/#{card._id}"
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, cardDoc) ->
      should.not.exist(err)
      res.statusCode.should.eql(200)
      cardDoc.should.eql(card.attributes())
      done()
