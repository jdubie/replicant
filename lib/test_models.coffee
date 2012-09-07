_       = require('underscore')
h       = require('lib/helpers')
config  = require('config')
async   = require('async')
debug   = require('debug')('replicant/lib/test_models')

class TestType
  @attributes: => [
    '_id'       # doc id
    '_rev'      # revision number
    'type'      # document type
    'name'      # userCtx.name
    'user_id'   # user id
    'ctime'     # created time
    'mtime'     # last modified
  ]

  attributes: =>
    result = {}
    for key in @constructor.attributes() when key of this
      result[key] = @[key]
    result

  defaults: => {
    _id: @_id
    name: @user.name
    user_id: @user._id
    ctime: 12345
    mtime: 12345
  }

  setDbs: (userId) =>
    @mainDb      = config.db.main()
    @_usersDb    = config.db._users()
    @userDb      = config.db.user(h.getUserDbName({userId}))
    @constableDb = config.db.constable()
    @mapperDb    = config.db.mapper()

  constructor: (id, @user, opts) ->
    @_id = "#{id}_#{Math.round(Math.random() * 100)}"

    opts ?= {}
    _.defaults(opts, @defaults())
    _.extend(this, opts)

    @setDbs(@user_id)

  create: =>

  destroy: =>


class TestTypePublic extends TestType
  create: (callback) =>
    @mainDb.insert @attributes(), @_id, (err, res) =>
      return callback(err) if err
      @_rev = res.rev
      callback()

  destroy: (callback) =>
    @mainDb.get @_id, (err, doc) =>
      return callback() if err
      @mainDb.destroy(@_id, doc._rev, callback)


class TestTypePrivate extends TestType
  create: (callback) =>
    async.series
      rev: (next) =>
        cb = (err, res) ->
          return next(err) if err
          next(null, res.rev)
        @constableDb.insert(@attributes(), @_id, h.nanoCallback(cb))
      replicate: (next) =>
        h.replicateOut([@user_id], [@_id], next)
    , (err, res) =>
      return callback(err) if err
      @_rev = res.rev
      callback()

  destroy: (callback) =>
    async.parallel [
      (cb) =>
        @userDb.get @_id, (err, doc) =>
          return cb() if err?   # should error
          @userDb.destroy(@_id, doc._rev, cb)
      (cb) =>
        @constableDb.get @_id, (err, doc) =>
          return cb() if err?
          @constableDb.destroy(@_id, doc._rev, cb)
    ], callback


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
    @userDb = config.nanoAdmin.db.use(@userDbName)

  create: (callback) =>

    userDdocDbName = 'userddocdb'
    userDdocName = 'userddoc'

    insertUser = (callback) =>
      async.parallel
        flush: (cb) -> config.jobs.client.flushall(cb)
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
          config.nanoAdmin.db.create "users_#{@_id}", (err) =>
            return cb(err) if err
            config.nanoAdmin.db.replicate(userDdocDbName, @userDbName, cb)
      , callback

      #, (err, res) ->
      # debug '#createUser err, res', err, res
      # callback(err, res)

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
    flushRedis = (callback) -> config.jobs.client.flushall(callback)

    async.parallel [
      destroyUser
      destroyLifeswapUser
      destroyUserDb
      flushRedis
    ], callback

  getAllMessages: (callback) =>
    @userDb.view 'userddoc', 'docs_by_type', key: 'message', include_docs: true, (err, body) ->
      msgs = _.map body.rows, (row) -> row.doc
      callback(err, msgs)

  getAllReadDocs: (callback) =>
    @userDb.view 'userddoc', 'docs_by_type', key: 'read', include_docs: true, (err, body) ->
      read_docs = _.map body.rows, (row) -> row.doc
      callback(err, read_docs)

  getMessages: (callback) =>
    async.parallel {@getAllMessages, @getAllReadDocs}, (err, res) =>
      return callback(err) if err

      messages = res.getAllMessages
      readDocs = res.getAllReadDocs

      for message in messages
        message.read = false

      for message in messages
        for readDoc in readDocs
          if message._id is readDoc.message_id
            message.read = true

      callback(null, messages)


m.TestSwap = class TestSwap extends TestTypePublic
  @attributes: =>
    attrs = super
    [].concat attrs, [
      'status'
      'title'
      'zipcode'
      'city'
      'state'
      'entity'
      'website'
      'industry'
      'description'
      'highlights'
      'duration'
      'price'
      'extra_info'
      'num_guests'
      'require_approval'
      'image_original'
      'image_huge'
      'image_big'
      'image_medium'
      'image_thumbnail'
      'image_small'
      'image_narrow'
      'availability'
      'tags'
      'address'
      'parking'
      'dresscode'
    ]

  defaults: =>
    def = super
    _.extend def, {
      type: 'swap'
      status: 'pending'
      title: "#{@_id} Swap"
      zipcode: '94305'
      industry: 'Agriculture'
    }


m.TestRequest = class TestRequest
  @attributes: [
    '_id'
    '_rev'
    'type'
    'name'
    'user_id'
    'ctime'
    'mtime'
    'title'
    'description'
    'reason'
    'zipcode'
    'city'
    'state'
    'price'
  ]

  attributes: =>
    result = {}
    for key in @constructor.attributes when key of this
      result[key] = @[key]
    result

  constructor: (id, user, opts) ->

    def =
      _id: id
      name: user.name
      user_id: user._id
      type: 'request'
      ctime: 12345
      mtime: 12345
      title: "#{id} Request"
      
    opts ?= {}
    _.defaults(opts, def)
    _.extend(this, opts)

    @mainDb = config.nanoAdmin.db.use('lifeswap')

  create: (callback) =>
    @mainDb.insert @attributes(), @_id, (err, res) =>
      return callback(err) if err
      @_rev = res.rev
      callback()

  destroy: (callback) =>
    @mainDb.get @_id, (err, userDoc) =>
      return callback() if err?   # should error
      @mainDb.destroy(@_id, userDoc._rev, callback)

m.TestReview = class TestReview
  @attributes: [
    '_id'
    '_rev'
    'type'
    'name'
    'user_id'
    'ctime'
    'mtime'
    'review_type'
    'reviewee_id'
    'swap_id'
    'rating'
    'review'
    'fb_id'
  ]

  attributes: =>
    result = {}
    for key in @constructor.attributes when key of this
      result[key] = @[key]
    result._id = @_id if @_id
    result

  constructor: (id, user, opts) ->

    user ?= {}
    user.name ?= "user_name_#{id}"
    user._id ?= "user_id_#{id}"

    def =
      _id: id
      type: 'review'
      name: user.name
      user_id: user._id
      ctime: 12345
      mtime: 12345
      review_type: 'guest'
      reviewee_id: user._id
      swap_id: 'swap1'
      rating: 3
      review: 'sucit'
      fb_id: 'wefwefwewef'
      
    opts ?= {}
    _.defaults(opts, def)
    _.extend(this, opts)

    @mainDb = config.nanoAdmin.db.use('lifeswap')

  create: (callback) =>
    @mainDb.insert @attributes(), @_id, (err, res) =>
      return callback(err) if err
      @_rev = res.rev
      callback()

  destroy: (callback) =>
    @mainDb.get @_id, (err, userDoc) =>
      return callback() if err?   # should error
      @mainDb.destroy(@_id, userDoc._rev, callback)

m.TestEmailAddress = class TestEmailAddress extends TestTypePrivate
  @attributes: =>
    attrs = super
    [].concat attrs, [
      'email_address'
    ]

  defaults: =>
    def = super
    _.extend def, {
      type: 'email_address'
      email_address: "#{@_id}@thelifeswap.com"
    }


m.TestLike = class TestLike
  @attributes: [
    '_id'
    '_rev'
    'type'
    'name'
    'user_id'
    'ctime'
    'mtime'
    'swap_id'     # the liked swap id
  ]

  attributes: =>
    result = {}
    for key in @constructor.attributes when key of this
      result[key] = @[key]
    result._id = @_id if @_id
    result

  constructor: (id, user, opts) ->

    user ?= {}
    user.name ?= "user_name_#{id}"
    user._id ?= "user_id_#{id}"

    def =
      _id: id
      type: 'like'
      name: user.name
      user_id: user._id
      ctime: 12345
      mtime: 12345
      swap_id: "swap_id_#{id}"
      
    opts ?= {}
    _.defaults(opts, def)
    _.extend(this, opts)

    @mainDb = config.nanoAdmin.db.use('lifeswap')

  create: (callback) =>
    @mainDb.insert @attributes(), @_id, (err, res) =>
      debug 'err', err
      return callback(err) if err
      @_rev = res.rev
      callback()

  destroy: (callback) =>
    @mainDb.get @_id, (err, userDoc) =>
      return callback() if err?   # should error
      @mainDb.destroy(@_id, userDoc._rev, callback)


m.TestPhoneNumber = class TestPhoneNumber extends TestTypePrivate
  @attributes: =>
    attrs = super
    [].concat(attrs, [
      'phone_number'
    ])

  defaults: =>
    def = super
    _.extend def, {
      type: 'phone_number'
      phone_number: "8602097765"
    }


m.TestPayment = class TestPayment
  @attributes: [
    '_id'
    '_rev'
    'type'
    'name'
    'user_id'
    'event_id'
    'card_id'
    'amount'
    'status'
    'ctime'
    'mtime'
  ]

  attributes: =>
    result = {}
    for key in @constructor.attributes when key of this
      result[key] = @[key]
    result

  constructor: (id, user, opts) ->

    def =
      _id: id
      name: user.name
      user_id: user._id
      type: 'payment'
      ctime: 12345
      mtime: 12345
      event_id: "event_id_#{id}"
      card_id: "card_id_#{id}"
      amount: 69
      status: '2'     # unpaid
      
    opts ?= {}
    _.defaults(opts, def)
    _.extend(this, opts)

    @userDb = config.nanoAdmin.db.use("users_#{user._id}")

  create: (callback) =>
    @userDb.insert @attributes(), @_id, (err, res) =>
      debug 'err, res', err, res
      return callback(err) if err
      @_rev = res.rev
      callback()

  destroy: (callback) =>
    @userDb.get @_id, (err, userDoc) =>
      return callback() if err?   # should error
      @userDb.destroy(@_id, userDoc._rev, callback)


m.TestCard = class TestCard extends TestTypePrivate
  @attributes: =>
    attrs = super
    [].concat(attrs, [
      'balanced_url'      # token url for balanced
      'full_name'
      'expiration_month'
      'expiration_year'
      'street_address'
      'postal_code'
      'country_code'
      'city'
      'state'
      'card_type'
      'last_four'         # server-only
      'card_number'
      'security_code'
      'card_type'
    ])

  defaults: =>
    def = super
    _.extend def, {
      type: 'card'
      balanced_url: '/url/to/pluto'
      full_name: 'dack jubie'
      expiration_month: 11
      expiration_year: 2013
      street_address: '4123 Yeeee-ooohhh'
      postal_code: '05452'
      country_code: 'USA'
      city: 'Paradise'
      state: 'VT'
      card_type: 'VISA'
      last_four: '1233'
    }


m.TestEvent = class TestEvent
  @attributes: [
    '_id'
    '_rev'
    'type'
    'ctime'
    'mtime'
    'state'
    'swap_id'
    'date'
    #'hosts'  # client-side
    #'guests' # client-side
    'card_id'
  ]

  attributes: =>
    result = {}
    for key in @constructor.attributes when key of this
      result[key] = @[key]
    result

  constructor: (id, @guests, @hosts, @swap, opts) ->

    def =
      _id: id
      type: 'event'
      ctime: 12345
      mtime: 12345
      state: 'requested'    # put EVENT_STATE.requested
      swap_id: swap._id
      
    opts ?= {}
    _.defaults(opts, def)
    _.extend(this, opts)

    @users = []
    @users.push(guest) for guest in @guests
    @users.push(host) for host in @hosts
    @mapperDb = config.nanoAdmin.db.use('mapper')


  create: (callback) =>
    createOneEvent = (user, callback) =>
      userDb = config.nanoAdmin.db.use("users_#{user._id}")
      userDb.insert @attributes(), @_id, (err, res) =>
        return callback(err) if err
        @_rev = res.rev
        callback()
    createEvent = (callback) =>
      async.map(@users, createOneEvent, callback)
    insertIntoMapper = (callback) =>
      mapperDoc =
        _id   : @_id
        guests: (guest._id for guest in @guests)
        hosts : (host._id for host in @hosts)
      @mapperDb.insert(mapperDoc, @_id, callback)

    async.parallel([createEvent, insertIntoMapper], callback)


  destroy: (callback) =>
    destroyOneEvent = (user, callback) =>
      userDb = config.nanoAdmin.db.use("users_#{user._id}")
      userDb.get @_id, (err, eventDoc) =>
        return callback() if err?
        userDb.destroy(@_id, eventDoc._rev, callback)
    destroyEvent = (callback) =>
      async.map(@users, destroyOneEvent, callback)
    removeFromMapper = (callback) =>
      @mapperDb.get @_id, (err, mapperDoc) =>
        return callback() if err?
        @mapperDb.destroy(@_id, mapperDoc._rev, callback)

    async.parallel([destroyEvent, removeFromMapper], callback)

m.TestMessage = class TestMessage
  @attributes: [
    '_id'
    '_rev'
    'type'
    'name'
    'user_id'
    'ctime'
    'mtime'
    'event_id'
    'message'
    'read'
  ]

  attributes: =>
    result = {}
    for key in @constructor.attributes when key of this
      result[key] = @[key]
    result

  constructor: (id, @user, @event, opts) ->

    def =
      _id: id
      type: 'message'
      name: @user.name
      user_id: @user._id
      ctime: 12345
      mtime: 12345
      event_id: @event._id
      message: 'test message'
      read: true
      
    opts ?= {}
    _.defaults(opts, def)
    _.extend(this, opts)

    @userDb = config.nanoAdmin.db.use("users_#{user._id}")

  getReadDoc: () =>
    doc =
      _id: Math.random().toString().substring(2) # HACK
      type: 'read'
      name: @user.name
      user_id: @user._id
      ctime: 12345
      mtime: 12345
      event_id: @event._id
      message_id: @_id

  create: (callback) =>
    # TODO: user mapper to get users?
    #mapperDb = nanoAdmin.db.use('mapper')

    insertMessage = (user, cb) =>
      debug 'user._id', user._id

      userDb = config.nanoAdmin.db.use(h.getUserDbName(userId: user._id))
      async.parallel [

        # write message doc
        (_cb) =>
          message = @attributes()
          delete message.read
          userDb.insert message, @_id, (err, res) =>
            debug 'insertMessage doc', err, res
            return _cb(err) if err
            @_rev = res.rev
            _cb()

        # conditionally insert read doc
        (_cb) =>
          debug '@getReadDoc()', @getReadDoc()
          debug '@read', @read
          if @read and @user_id is user._id
            readDoc = @getReadDoc()
            userDb.insert readDoc, readDoc._id, (err, res) ->
              debug 'insertRead doc', err, res
              return _cb(err) if err
              _cb(null ,res)
          else _cb()
      ], cb

    allUsers = _.union(@event.guests, @event.hosts)
    async.map(allUsers, insertMessage, callback)

  destroy: (callback) =>
    ## todo: destroy read document
    @userDb.get @_id, (err, userDoc) =>
      return callback() if err?   # should error
      @userDb.destroy(@_id, userDoc._rev, callback)

module.exports = m
