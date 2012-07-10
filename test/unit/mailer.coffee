should = require('should')
emaillisten = require('email-listener')
{Mailer} = require('../../lib/mailer')

describe 'class Mailer', () ->

  before () ->
    emaillisten.start(2500)

  after () ->
    emaillisten.stop()

  it 'send simple email', (done) ->
    done()
    #emaillisten.once 'msg', (recipient, rawbody, parsed) ->
    #  console.error recipient, rawbody, parsed
    #  done()

    #mailer = new Mailer(to: 'wefwef')
    #mailer.send({})
