_       = require('underscore')
h       = require('lib/helpers')
config  = require('config')
async   = require('async')
debug   = require('debug')('replicant/lib/test_models')

m = {}

# createUser
#
#
m.TestUser = class TestUser
  @attributes: [
    '_id'       # doc id
    '_rev'      # revision number
    'type'      # document type
    'name'      # userCtx.name
    'user_id'   # user id
    'ctime'     # created time
    'mtime'     # last modified
    'first_name'
    'last_name'
    'image_original'
    'image_huge'
    'image_big'
    'image_medium'
    'image_thumbnail'
    'image_small'
    'image_narrow'
    'gender'
    'birthday'
    'zipcode'
    'city'
    'state'
    'occupation'
    'interests'
  ]

  attributes: ->
    result = {}
    for key in @constructor.attributes when key of this
      result[key] = @[key]
    result._id = @_id if @_id
    result



  constructor: (id, opts) ->

    def =
      _id: id
      type: 'user'
      ctime: 12345
      mtime: 12345
      email_address: "#{id}@thelifeswap.com"
      password: "#{id}pass"
      roles: []
      
    opts ?= {}
    _.defaults(opts, def)
    _.extend(this, opts)

    @name = h.hash(@email_address)

    @mainDb = config.nanoAdmin.db.use('lifeswap')
    @usersDb = config.nanoAdmin.db.use('_users')
    @userDbName = h.getUserDbName(userId: @_id)
    @couchUser = "org.couchdb.user:#{@name}"

  create: (callback) =>

    insertUser = (callback) =>
      async.parallel
        _userDoc: (cb) =>
          userDoc =
            _id: @couchUser
            type: 'user'
            name: @name
            password: @password
            roles: @roles
            user_id: @_id
          debug "#_userDoc", @_id
          @usersDb.insert(userDoc, cb)
        _rev: (cb) =>
          @mainDb.insert this.attributes(), @_id, (err, res) ->
            return cb(err) if err
            cb(null, res.rev)
        admin: (cb) =>
          config.nanoAdmin.db.create("users_#{@_id}", cb)
          #, _callback
      , (err, res) ->
        debug '#createUser err, res', err, res
        callback(err, res)

    authUser = (res, callback) =>
      {_rev} = res
      @_rev = _rev
      config.nano.auth @name, @password, (err, body, hdr) =>
        debug '#createUser err, body, hdr', err, body, hdr
        return callback(err) if err
        cookie = hdr['set-cookie'][0] if hdr['set-cookie']
        return callback('no cookie') unless cookie
        debug '#createUser cookie, _rev', cookie, _rev
        @cookie = cookie
        callback()

    async.waterfall([insertUser, authUser], callback)


  destroy: (callback) =>

    destroyUser = (callback) =>
      @usersDb.get @couchUser, (err, userDoc) =>
        return callback() if err?   # should error
        @usersDb.destroy(@couchUser, userDoc._rev, callback)
    destroyLifeswapUser = (callback) =>
      @mainDb.get @_id, (err, userDoc) =>
        return callback() if err?   # should error
        @mainDb.destroy(@_id, userDoc._rev, callback)
    destroyUserDb = (callback) =>
      config.nanoAdmin.db.list (err, dbs) =>
        return callback() if not (@userDbName in dbs)  # should callback
        config.nanoAdmin.db.destroy(@userDbName, callback)

    async.parallel [
      destroyUser
      destroyLifeswapUser
      destroyUserDb
    ], callback


module.exports = m
