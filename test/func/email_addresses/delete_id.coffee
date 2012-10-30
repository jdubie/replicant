should  = require('should')
async   = require('async')
request = require('request').defaults(jar: false)

{TestUser, TestEmailAddress} = require('lib/test_models')
config = require('config')


describe 'DELETE /email_addresses/:id', () ->

  owner     = new TestUser('delete_email_id_owner')
  badguy    = new TestUser('delete_email_id_badguy')
  emailOne  = new TestEmailAddress('delete_email_id_1', owner)
  emailTwo  = new TestEmailAddress('delete_email_id_2', owner)
  constable = new TestUser('delete_email_id_constable', roles: ['constable'])

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
          emailOne.create
          emailTwo.create
        ], cb
    ], ready

  after (finished) ->
    async.parallel [
      owner.destroy
      badguy.destroy
      constable.destroy
    ], finished

  describe 'bad user', () ->

    it 'should return a 403 (forbidden)', (done) ->
      opts =
        method: 'DELETE'
        url: "http://localhost:3001/email_addresses/#{emailOne._id}"
        json: true
        headers: cookie: badguy.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        # 401 error from the '_security' doc of user DB
        # (cannot access the DB)
        # BUT with middle-tier validation statusCode: 403
        res.should.have.property('statusCode', 403)
        done()

    it 'should not delete \'email_address\' type entry in user db', (done) ->
      ownerDb.get emailOne._id, (err, emailDoc) ->
        should.not.exist(err)
        emailDoc.should.eql(emailOne.attributes())
        done()

    it 'should not delete entry in constable db', (done) ->
      constableDb.get emailOne._id, (err, emailDoc) ->
        should.not.exist(err)
        emailDoc.should.eql(emailOne.attributes())
        done()


  describe 'normal user', () ->

    it 'should return a 200', (done) ->
      opts =
        method: 'DELETE'
        url: "http://localhost:3001/email_addresses/#{emailOne._id}"
        json: true
        headers: cookie: owner.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        done()

    it 'should delete the entry in the user db', (done) ->
      ownerDb.get emailOne._id, (err, emailDoc) ->
        should.exist(err)
        done()

    it 'should delete the entry in the constable db', (done) ->
      constableDb.get emailOne._id, (err, emailDoc) ->
        should.exist(err)
        done()


  describe 'constable', () ->

    it 'should return a 200', (done) ->
      opts =
        method: 'DELETE'
        url: "http://localhost:3001/email_addresses/#{emailTwo._id}"
        json: true
        headers: cookie: constable.cookie
      request opts, (err, res, body) ->
        should.not.exist(err)
        res.should.have.property('statusCode', 200)
        done()

    it 'should delete the entry in the user db', (done) ->
      ownerDb.get emailTwo._id, (err, emailDoc) ->
        should.exist(err)
        done()

    it 'should delete the entry in the constable db', (done) ->
      constableDb.get emailTwo._id, (err, emailDoc) ->
        should.exist(err)
        done()
