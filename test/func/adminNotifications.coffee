#ms = require('smtp-tester')
#should = require('should')
#{testEmailPort, nano}  = require('../../config')
#
#describe 'adminNotifications', () ->
#
#  mailserver = null
#  app = null
#
#  before (done) ->
#    mailserver = ms.init(testEmailPort)
#    app = require('../../app')
#    done()
#
#  after () ->
#    app.close()
#    mailserver.stop()
#
#  it 'should send and email when someone saves a swap', (done) ->
#    handler = (addr, id, email) ->
#      addr.should.equal('admin@thelifeswap.com')
#      email.should.have.property('sender','notifications@thelifeswap.com')
#      should.exist(email.body.match(/\/admin\/swaps\/swaps\/testadminid/))
#      done()
#    mailserver.bind('admin@thelifeswap.com', handler)
#
#    ## trigger notification
#    db = nano.db.use('lifeswap')
#    db.insert({type: 'swap'}, 'testadminid')


