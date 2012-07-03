debug = require('debug')('lifeswap:replicant')
nano = require('nano')('http://tester:tester@localhost:5985')

replicant = {}

replicant.signup = (userId,callback) ->
  nano.db.create(userId,callback)

replicant.swapEvent = ({swapId,userId}, callback) ->
  db = nano.db.use('lifeswap')

  callback()


module.exports = replicant

# shut down SMTP connection
process.on 'SIGINT', () ->
  #debug 'shutting down SMTP connection'
  #smtpTransport.close()
  # TODO close db connection
  process.exit()
