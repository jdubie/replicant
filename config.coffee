debug = require('debug')('replicant:config')
nodemailer = require('nodemailer')
url = require('url')

# Db connection
if process.env.PROD
  protocol = 'http:'
  auth = "replicant:#{process.env.REPLICANT_PWD}"
  hostname = 'localhost'
  port = 5984
else
  protocol = 'http:'
  auth = 'replicant:replicant'
  hostname = 'localhost'
  port = 5985

module.exports.dbUrl = url.format({protocol,hostname,port})
module.exports.nano = require('nano')(url.format({protocol,hostname,port}))
module.exports.nanoAdmin = require('nano')(url.format({protocol,hostname,port,auth}))


# Admins
if process.env.PROD
  ADMINS = ['shawntuteja', 'jdubie', 'mike', 'bastiaan', 'aotimme']
else
  ADMINS = ['tester_id']    # the user_id!

module.exports.ADMINS = ADMINS


# SMTP transport
testEmailPort = 8000

gmailSmtpOptions =
  service: 'Gmail'
  auth:
    user: process.env.GMAIL_USER
    pass: process.env.GMAIL_PWD

mailjetSmtpOptions =
  host: 'in.mailjet.com'
  port: 587
  auth:
    user: process.env.MAILJET_KEY
    pass: process.env.MAILJET_SECRET

if process.env.PROD
  smtpOptions = mailjetSmtpOptions
else
  smtpOptions = # testing
    host: 'localhost'
    port: testEmailPort

switch process.env.ENV
  when 'test'
    exports.port = 3001
  else
    exports.port = 3000

module.exports.smtp = nodemailer.createTransport('SMTP', smtpOptions)
module.exports.testEmailPort = testEmailPort
