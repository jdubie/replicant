should  = require('should')
async   = require('async')
request = require('request')

{TestUser, TestPhoneNumber} = require('lib/test_models')
config = require('config')


describe 'DELETE /phone_numbers/:id', () ->

  owner     = new TestUser('delete_phone_id_owner')
  badguy    = new TestUser('delete_phone_id_badguy')
  phoneOne  = new TestPhoneNumber('delete_phone_id_1', owner)
  phoneTwo  = new TestPhoneNumber('delete_phone_id_2', owner)
  constable = new TestUser('delete_phone_id_constable', roles: ['constable'])

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
          phoneOne.create
          phoneTwo.create
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
        url: "http://localhost:3001/phone_numbers/#{phoneOne._id}"
        json: true
        headers: cookie: badguy.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        # 401 error from the '_security' doc of user DB
        # (cannot access the DB)
        res.should.have.property('statusCode', 401)
        done()

    it 'should not delete \'phone_number\' type entry in user db', (done) ->
      ownerDb.get phoneOne._id, (err, phoneDoc) ->
        should.not.exist(err)
        phoneDoc.should.eql(phoneOne.attributes())
        done()

    it 'should not delete entry in constable db', (done) ->
      constableDb.get phoneOne._id, (err, phoneDoc) ->
        should.not.exist(err)
        phoneDoc.should.eql(phoneOne.attributes())
        done()


  describe 'normal user', () ->

    it 'should return a 200', (done) ->
      opts =
        method: 'DELETE'
        url: "http://localhost:3001/phone_numbers/#{phoneOne._id}"
        json: true
        headers: cookie: owner.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        done()

    it 'should delete the entry in the user db', (done) ->
      ownerDb.get phoneOne._id, (err, phoneDoc) ->
        should.exist(err)
        done()

    it 'should delete the entry in the constable db', (done) ->
      constableDb.get phoneOne._id, (err, phoneDoc) ->
        should.exist(err)
        done()


  describe 'constable', () ->

    it 'should return a 200', (done) ->
      opts =
        method: 'DELETE'
        url: "http://localhost:3001/phone_numbers/#{phoneTwo._id}"
        json: true
        headers: cookie: constable.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        done()

    it 'should delete the entry in the user db', (done) ->
      ownerDb.get phoneTwo._id, (err, phoneDoc) ->
        should.exist(err)
        done()

    it 'should delete the entry in the constable db', (done) ->
      constableDb.get phoneTwo._id, (err, phoneDoc) ->
        should.exist(err)
        done()
