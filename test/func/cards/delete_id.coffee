should = require('should')
async = require('async')
util = require('util')
request = require('request')

{TestUser, TestCard} = require('lib/test_models')
{nanoAdmin, nano, dbUrl, ADMINS} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'yyy DELETE /cards/:id', () ->

  user = new TestUser('delete_card_id_user')
  card = new TestCard('delete_card_id', user)
  userDb = nanoAdmin.db.use(getUserDbName(userId: user._id))

  before (ready) ->
    app = require('app')
    async.series([user.create, card.create], ready)

  after (finished) ->
    async.series([card.destroy, user.destroy], finished)

  it 'should return a 403 (forbidden)', (done) ->
    opts =
      method: 'DELETE'
      url: "http://localhost:3001/cards/#{user._id}"
      json: true
      headers: cookie: user.cookie
    request opts, (err, res, body) ->
      should.not.exist(err)
      res.should.have.property('statusCode', 403)
      done()

  it 'should not delete \'card\' type entry in user db', (done) ->
    userDb.get card._id, (err, cardDoc) ->
      should.not.exist(err)
      cardDoc.should.eql(card.attributes())
      done()
