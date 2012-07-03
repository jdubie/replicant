async = require('async')
debug = require('debug')('lifeswap:replicant')
nano = require('nano')('http://tester:tester@localhost:5985')

replicant = {}

replicant.getHello = () ->
  return 'helro, world'

replicant.signup = ({userId},callback) ->
  nano.db.create(userId,callback)

replicant.swapEvent = ({swapId, userId}, callback) ->
  getGuest = (_callback) ->
    _callback(null, userId) # @todo replace with getting this from cookies
  getHosts = (_callback) ->
    db = nano.db.use('lifeswap')
    db.get swapId, (err, swapDoc) ->
      _callback(err, [swapDoc.host]) # @todo swapDoc.host should will be array in future
  createMapping = (users, _callback) ->
    users.push(userId) # @todo this logic may change
    mapper = nano.db.use('mapper')
    mapper.insert {users}, (err, res) ->
      swapEventId = res.id
      ok = true
      _callback(err, {swapEventId, users, ok})

  async.waterfall [
    (next) -> getGuest(next)
    (result, next) -> getHosts(next)
    (result, next) -> createMapping(result, next)
  ], callback


module.exports = replicant

# shut down SMTP connection
process.on 'SIGINT', () ->
  #debug 'shutting down SMTP connection'
  #smtpTransport.close()
  # TODO close db connection
  process.exit()
