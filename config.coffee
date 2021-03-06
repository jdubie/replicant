debug = require('debug')('replicant:config')
nodemailer = require('nodemailer')
url = require('url')
kue = require('kue')
redis = require('redis')

# Db connection
switch process.env.ENV
  when 'PROD'
    protocol = 'http:'
    auth = "replicant:#{process.env.REPLICANT_PWD}"
    hostname = 'localhost'
    port = process.env.REPLICANT_PROD_PORT_COUCH
  when 'STAGE'
    protocol = 'http:'
    auth = "replicant:#{process.env.REPLICANT_PWD}"
    hostname = 'localhost'
    port = process.env.REPLICANT_STAGE_PORT_COUCH
  when 'DEV', 'TEST'
    protocol = 'http:'
    auth = 'replicant:replicant'
    hostname = 'localhost'
    port = 5985
  else
    console.error 'You must set ENV environment variable'
    process.exit()

module.exports.dbUrl = url.format({protocol,hostname,port})
module.exports.nano = require('nano')(url.format({protocol,hostname,port}))
module.exports.nanoAdmin = require('nano')(url.format({protocol,hostname,port,auth}))

# Admins - todo rethink this
switch process.env.ENV
  when 'PROD', 'STAGE'
    ADMINS = []
  else
    ADMINS = ['tester_id']    # the user_id!

module.exports.ADMINS = ADMINS

# Work Queue

switch process.env.ENV
  when 'PROD', 'STAGE'
    # todo add server redis settings
    kue.redis.createClient = () ->
      client = redis.createClient(process.env.REDIS_PORT, '127.0.0.1')
      client.auth(process.env.REDIS_PASSWORD)
      return client
  when 'DEV', 'TEST'
    kue.redis.createClient = () ->
      client = redis.createClient(6379, '127.0.0.1')
      return client
  else
    console.error 'You must set ENV environment variable'
    process.exit()

module.exports.jobs = kue.createQueue()
#module.exports.redis = redis.createClient()

switch process.env.ENV
  when 'TEST'
    exports.port = 3001
  when 'STAGE'
    exports.port = 3002
  when 'PROD'
    exports.port = 3000
  when 'DEV'
    exports.port = 3000
  else
    console.error 'You must set ENV environment variable'
    process.exit()

#gmailSmtpOptions =
#  service: 'Gmail'
#  auth:
#    user: process.env.GMAIL_USER
#    pass: process.env.GMAIL_PWD
#
#mailjetSmtpOptions =
#  host: 'in.mailjet.com'
#  port: 587
#  auth:
#    user: process.env.MAILJET_KEY
#    pass: process.env.MAILJET_SECRET
#
#if process.env.PROD
#  smtpOptions = mailjetSmtpOptions
#else
#  smtpOptions = # testing
#    host: 'localhost'
#    port: testEmailPort
#
#module.exports.smtp = nodemailer.createTransport('SMTP', smtpOptions)
#module.exports.testEmailPort = testEmailPort
