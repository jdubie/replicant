should = require('should')
async = require('async')
util = require('util')
request = require('request')

{TestUser, TestCard} = require('lib/test_models')
{nanoAdmin, nano} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'yyyy GET /cards', () ->

  user = new TestUser('get_cards_user')
  cards = (new TestCard(id, user) for id in ['get_card1', 'get_card2', 'get_card3'])

  describe 'correctness:', () ->

    before (ready) ->
      app = require('app')
      createCards = (cb) ->
        create = (card, callback) -> card.create(callback)
        async.map(cards, create, cb)
      async.series([user.create, createCards], ready)

    after (finished) ->
      user.destroy(finished)

    it 'should GET all cards', (done) ->
      opts =
        method: 'GET'
        url: "http://localhost:3001/cards"
        json: true
        headers: cookie: user.cookie
      request opts, (err, res, cardDocs) ->
        should.not.exist(err)
        res.statusCode.should.eql(200)
        cardDocs.should.eql(card.attributes() for card in cards)
        done()
