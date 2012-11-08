_       = require('underscore')
h       = require('lib/helpers')
config  = require('config')
async   = require('async')
debug   = require('debug')('replicant/lib/test_models')
request = require('request').defaults(jar: false)

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
    @userDb      = config.db.user(userId)
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
      @_rev = res?.rev
      callback(err, res)

  destroy: (callback) =>
    @mainDb.get @_id, (err, doc) =>
      return callback() if err
      @mainDb.destroy(@_id, doc._rev, callback)


class TestTypePrivate extends TestType
  create: (callback) =>
    debug '#create TestTypePrivate: id', @_id
    async.series
      rev: (next) =>
        cb = (err, res) ->
          return next(err) if err
          next(null, res.rev)
        @constableDb.insert(@attributes(), @_id, h.nanoCallback(cb))
      replicate: (next) =>
        h.replicateOut([@user_id], [@_id], next)
    , (err, res) =>
      console.error 'CREATE ERROR: TestTypePrivate: id', @_id if err
      @_rev = res?.rev
      callback(err, res)

  destroy: (callback) =>
    debug '#destroy TestTypePrivate: id', @_id
    async.parallel [
      (cb) =>
        @userDb.get @_id, (err, doc) =>
          if err
            debug "#destroy error getting #{@_id} from userdb", err
            return cb()
          @userDb.destroy(@_id, doc._rev, cb)
      (cb) =>
        @constableDb.get @_id, (err, doc) =>
          if err
            debug "#destroy error getting #{@_id} from drunk_tank"
            return cb()
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
    result

  constructor: (id, opts) ->

    _id = "#{id}_#{Math.round(Math.random()*100000)}"
    def =
      _id: _id
      user_id: _id
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

    @mainDb = config.db.main()
    @usersDb = config.db._users()
    @userDbName = h.getUserDbName(userId: @_id)
    @couchUser = "org.couchdb.user:#{@name}"
    @userDb = config.db.user(@_id)

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
          async.series [
            (next) =>
              config.couch().db.create(@userDbName, next)
            (next) =>
              security =
                admins: names: [], roles: []
                members: names: [@name], roles: []
              @userDb.insert(security, '_security', next)
            (next) =>
              config.couch().db.replicate(userDdocDbName, @userDbName, next)
          ], cb
      , callback

    authUser = (res, callback) =>
      {_rev} = res
      @_rev = _rev
      opts =
        url: 'http://localhost:3001/user_ctx'
        method: 'POST'
        json:
          username: @email_address
          password: @password
      request opts, (err, res, body) =>
        hdr = res.headers
        debug '#createUser err, body, hdr', err, body, hdr
        cookie = hdr['set-cookie'][0] if hdr['set-cookie']
        return callback('no cookie') unless cookie
        debug "#createUser cooke, _rev", cookie, _rev
        @cookie = cookie
        callback()

    async.waterfall([insertUser, authUser], callback)


  destroy: (callback) =>

    destroyUser = (callback) =>
      @usersDb.get @couchUser, (err, userDoc) =>
        return callback(err) if err
        @usersDb.destroy(@couchUser, userDoc._rev, callback)
    destroyLifeswapUser = (callback) =>
      @mainDb.get @_id, (err, userDoc) =>
        return callback(err) if err
        @mainDb.destroy(@_id, userDoc._rev, callback)
    destroyUserDb = (callback) =>
      config.couch().db.list (err, dbs) =>
        return callback("#{@userDbName} not in DBs") if not (@userDbName in dbs)
        config.couch().db.destroy(@userDbName, callback)
    flushRedis = (callback) -> config.jobs.client.flushall(callback)

    async.parallel [
      destroyUser
      destroyLifeswapUser
      destroyUserDb
      flushRedis
    ], (err, res) ->
      console.error "DESTROY USER ERROR", err if err
      callback(err, res)

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


m.TestLike = class TestLike extends TestTypePublic
  @attributes: =>
    attrs = super
    [].concat attrs, [
      'swap_id'     # the liked swap id
    ]

  defaults: =>
    def = super
    _.extend def, {
      type: 'like'
      swap_id: "swap_id_#{@_id}"
    }


m.TestApplication = class TestApplication extends TestTypePublic
  @attributes: =>
    attrs = super
    [].concat attrs, [
      'swap_id'     # the liked swap id
      'text'
      'status'
    ]

  defaults: =>
    def = super
    _.extend def, {
      type: 'application'
      swap_id: "swap_id_#{@_id}"
      status: 'pending'
      text: "My Application"
    }


m.TestShortlink = class TestShortlink extends TestTypePublic
  @attributes: =>
    [].concat super, [
      'target_url'     # the shortlink target url
    ]

  defaults: =>
    def = super
    _.extend def, {
      type      : 'shortlink'
      target_url: '/swaps/swap1'
    }


m.TestRequest = class TestRequest extends TestTypePublic
  @attributes: =>
    attrs = super
    [].concat attrs, [
      'title'
      'description'
      'reason'
      'zipcode'
      'city'
      'state'
      'price'
    ]

  defaults: =>
    def = super
    _.extend def, {
      type: 'request'
      title: "#{@_id} Request"
    }


m.TestReview = class TestReview extends TestTypePublic
  @attributes: =>
    attrs = super
    [].concat attrs, [
      'review_type'
      'reviewee_id'
      'swap_id'
      'rating'
      'review'
      'fb_id'
    ]

  defaults: =>
    def = super
    _.extend def, {
      type: 'review'
      review_type: 'swap'
      reviewee_id: @user._id
      swap_id: 'swap1'
      rating: 3
      review: 'sucit'
      fb_id: 'wefwefwewef'
    }


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


m.TestPhoneNumber = class TestPhoneNumber extends TestTypePrivate
  @attributes: =>
    attrs = super
    [].concat attrs, [
      'phone_number'
    ]

  defaults: =>
    def = super
    _.extend def, {
      type: 'phone_number'
      phone_number: "8602097765"
    }


m.TestPayment = class TestPayment extends TestTypePrivate
  @attributes: =>
    attrs = super
    [].concat attrs, [
      'phone_number'
      'status'
      'event_id'
      'card_id'
      'amount'
    ]

  defaults: =>
    def = super
    _.extend def, {
      type: 'payment'
      phone_number: "8602097765"
      event_id: "event_id_#{@_id}"
      card_id: "card_id_#{@_id}"
      amount: 69
      status: '2'     # unpaid
    }


m.TestCard = class TestCard extends TestTypePrivate
  @attributes: =>
    attrs = super
    [].concat attrs, [
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
    ]

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


m.TestReferEmail = class TestReferEmail extends TestTypePrivate
  @attributes: =>
    attrs = super
    [].concat attrs, [
      'request_id'
      'email_address'
      'personal_message'
    ]

  defaults: =>
    def = super
    _.extend def, {
      type: 'refer_email'
      request_id: "#{@_id}_request_id"
      email_address: "#{@_id}@emailAddress.com"
      personal_message: "#{@_id}_personal_message"
    }


m.TestEvent = class TestEvent
  @attributes: =>
    attrs = [
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
    # use crossing-guard!
    attrs.push("#{state}_time") for state in [
      'preevent'
      'prefilter'
      'predenied'
      'requested'
      'declined'
      'pending'
      'confirmed'
      'scheduled'
      'overdue'
      'completed'
      'cancelled'
    ]
    attrs

  attributes: =>
    result = {}
    for key in @constructor.attributes() when key of this
      result[key] = @[key]
    result

  constructor: (id, @guests, @hosts, @swap, opts) ->

    def =
      _id: "#{id}_#{Math.round(Math.random()*1000)}"
      type: 'event'
      ctime: 12345
      mtime: 12345
      state: 'requested'    # put EVENT_STATE.requested
      swap_id: @swap._id
      
    opts ?= {}
    _.defaults(opts, def)
    _.extend(this, opts)

    @users = [].concat(@guests, @hosts)
    @mapperDb = config.db.mapper()

  create: (callback) =>

    mapperDoc =
      _id   : @_id
      guests: (guest._id for guest in @guests)
      hosts : (host._id for host in @hosts)

    async.series [

      (cb) =>
        config.db.constable().insert @attributes(), @_id, (err, res) =>
          return cb(err) if err
          @_rev = res.rev
          cb()

      (cb) =>
        @mapperDb.insert(mapperDoc, @_id, cb)

      (cb) =>
        h.replicateOut(_.union(mapperDoc.guests, mapperDoc.hosts), [@_id], cb)

    ], callback

  destroy: (callback) =>
    destroyOneEvent = (user, callback) =>
      userDb = config.db.user(user._id)
      userDb.get @_id, (err, eventDoc) =>
        return callback(err) if err
        userDb.destroy(@_id, eventDoc._rev, callback)
    destroyEvent = (callback) =>
      async.map(@users, destroyOneEvent, callback)
    removeFromMapper = (callback) =>
      @mapperDb.get @_id, (err, mapperDoc) =>
        return callback(err) if err
        @mapperDb.destroy(@_id, mapperDoc._rev, callback)
    removeFromConstable = (callback) =>
      config.db.constable().get @_id, (err, body) =>
        return callback(err) if err
        config.db.constable().destroy(@_id, body._rev, callback)

    async.parallel [
      destroyEvent
      removeFromMapper
      removeFromConstable
    ], (err, res) ->
      console.error "EVENT DESTROY ERROR", err if err
      callback(err, res)

m.TestMessage = class TestMessage extends TestType
  @attributes: =>
    attrs = super
    [].concat attrs, [
      'event_id'
      'message'
      'read'
    ]

  defaults: =>
    def = super
    _.extend def, {
      type: 'message'
      event_id: @event._id
      message: 'test message'
      read: true
    }

  constructor: (id, @user, @event, opts) ->
    super(id, @user, opts)

  getReadDoc: =>
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

    async.series [

      (callback) =>
        debug 'inserting message into drunk_tank'
        message = @attributes()
        delete message.read
        @constableDb.insert message, @_id, (err, res) =>
          @_rev = res?.rev
          callback(err, res)

      (callback) =>
        allUsers = _.union(@event.guests, @event.hosts)
        userIds = (user._id for user in allUsers)
        debug 'replicating message to users', userIds
        h.replicateOut(userIds, [@_id], callback)

      (callback) =>
        return callback() if not @read
        readDoc = @getReadDoc()
        @userDb.insert(readDoc, readDoc._id, callback)

    ], (err, res) =>
      console.error "CREATE MESSAGE ERROR", err if err
      callback(err, res)



  destroy: (callback) =>
    ## todo: destroy read document
    removeUserMessage = (user, cb) =>
      userDb = config.db.user(user._id)
      userDb.get @_id, (err, doc) =>
        return cb(err) if err
        userDb.destroy(@_id, doc._rev, cb)
    removeConstableMessage = (cb) =>
      @constableDb.get @_id, (err, doc) =>
        return cb(err) if err
        @constableDb.destroy(@_id, doc._rev, cb)
    async.parallel [
      removeConstableMessage
      (cb) =>
        allUsers = _.union(@event.guests, @event.hosts)
        async.map(allUsers, removeUserMessage, cb)
    ], (err, res) ->
      console.error "MESSAGE DESTROY ERROR", err if err
      callback(err, res)


m.TestNotification = class TestNotification extends TestTypePrivate
  @attributes: =>
    attrs = super
    [].concat attrs, [
      'subject_id'
      'action'
      'object_type'
      'object_id'
      'read'
    ]

  defaults: =>
    def = super
    _.extend def, {
      type        : 'notification'
      subject_id  : @subject._id
      action      : 'approved'
      object_type : @object.type
      object_id   : @object._id
      read        : false
    }

  constructor: (id, @user, @subject, @object, opts) ->
    super(id, @user, opts)

  getReadDoc: =>
    doc =
      _id       : Math.random().toString().substring(2) # HACK
      type      : 'read'
      name      : @user.name
      user_id   : @user._id
      ctime     : 12345
      message_id: @_id

  create: (callback) =>
    # don't want to send up with the 'read' field
    _attributes = @attributes
    @attributes = () =>
      attrs = _attributes()
      delete attrs.read
      attrs
    super (err, res) =>
      @attributes = _attributes
      # insert 'read' doc if read is 'true'
      return callback(err, res) if not @read
      readDoc = @getReadDoc()
      @userDb.insert(readDoc, readDoc._id, callback)


module.exports = m
