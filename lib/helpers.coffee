request = require('request')
debug = require('debug')('lifeswap:helpers')
config = require('config')
crypto = require('crypto')
{nano} = config

helpers = {}

###
  @param userId {string}
  @return {string}
###
helpers.getUserDbName = ({userId}) ->
  return "users_#{userId}"

###
  @param userId {string}
  @param callback {function}
  @callback {array} email addresses for user
###
helpers.getEmailForUser = ({userId}, callback) ->
  db = nano.db.use(helpers.getUserDbName({userId}))
  db.view 'userddoc', 'email_addresses', (err, userEmailAddresses) ->
    userEmail = userEmailAddresses?.rows?[0]?.value
    callback(err, userEmail)

###
  getUserIdFromSession - helper that extracts userId from session
  @params headers {object.<string, {string|object}>} http headers object
###
helpers.getUserIdFromSession = ({headers}, callback) ->
  unless headers?.cookie? # will trigger 403
    callback(true)
    return
  opts =
    method: 'get'
    url: "#{config.dbUrl}/_session"
    headers: headers
  request opts, (err, res, body) ->
    userId = JSON.parse(body)?.userCtx?.name
    if userId? then callback(null, {userId})
    else callback(true) # will trigger 403

###
  @param message {string}
  @return {string}
###
helpers.hash = (message) ->
  shasum = crypto.createHash('sha1')
  shasum.update(message)
  return shasum.digest('hex')

module.exports = helpers
