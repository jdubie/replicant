should  = require('should')
async   = require('async')
request = require('request')

config = require('config')
{TestUser, TestCard} = require('lib/test_models')


describe 'DELETE /cards/:id', () ->

  owner     = new TestUser('delete_card_id_owner')
  badguy    = new TestUser('delete_card_id_badguy')
  cardone   = new TestCard('delete_card_id_1', owner)
  cardtwo   = new TestCard('delete_card_id_2', owner)
  constable = new TestUser('delete_card_id_constable', roles: ['constable'])

  ownerDb     = config.db.user(owner._id)
  constableDb = config.db.constable()

  before (ready) ->
    app = require('app')
    async.series [
      (cb) ->
        async.parallel [
          owner.create
          badguy.create
          constable.create
        ], cb
      (cb) ->
        async.parallel [
          cardone.create
          cardtwo.create
        ], cb
    ], ready

  after (finished) ->
    async.parallel [
      owner.destroy
      badguy.destroy
      constable.destroy
    ], finished

  describe 'bad user', () ->

    it 'should return a 401 (forbidden)', (done) ->
      opts =
        method: 'DELETE'
        url: "http://localhost:3001/cards/#{cardone._id}"
        json: true
        headers: cookie: badguy.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        # 401 error from the '_security' doc of user DB
        # (cannot access the DB)
        res.should.have.property('statusCode', 401)
        done()

    it 'should not delete \'card\' type entry in user db', (done) ->
      ownerDb.get cardone._id, (err, cardDoc) ->
        should.not.exist(err)
        cardDoc.should.eql(cardone.attributes())
        done()

    it 'should not delete entry in constable db', (done) ->
      constableDb.get cardone._id, (err, cardDoc) ->
        should.not.exist(err)
        cardDoc.should.eql(cardone.attributes())
        done()


  describe 'normal user', () ->

    it 'should return a 200', (done) ->
      opts =
        method: 'DELETE'
        url: "http://localhost:3001/cards/#{cardone._id}"
        json: true
        headers: cookie: owner.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        done()

    it 'should delete the entry in the user db', (done) ->
      ownerDb.get cardone._id, (err, cardDoc) ->
        should.exist(err)
        done()

    it 'should delete the entry in the constable db', (done) ->
      constableDb.get cardone._id, (err, cardDoc) ->
        should.exist(err)
        done()


  describe 'constable', () ->

    it 'should return a 200', (done) ->
      opts =
        method: 'DELETE'
        url: "http://localhost:3001/cards/#{cardtwo._id}"
        json: true
        headers: cookie: constable.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        done()

    it 'should delete the entry in the user db', (done) ->
      ownerDb.get cardtwo._id, (err, cardDoc) ->
        should.exist(err)
        done()

    it 'should delete the entry in the constable db', (done) ->
      constableDb.get cardtwo._id, (err, cardDoc) ->
        should.exist(err)
        done()
