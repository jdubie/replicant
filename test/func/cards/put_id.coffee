should = require('should')
async = require('async')
util = require('util')
request = require('request')

{nanoAdmin, nano, dbUrl} = require('config')
{getUserDbName, hash} = require('lib/helpers')


describe 'yyyy PUT /cards/:id', () ->

  before (ready) ->
    app = require('app')
    ready()

  after (finished) ->
    finished()

    it 'should not let people edit ccard', () ->

    #  it 'should not allow card correctly', (done) ->
    #    opts =
    #      method: 'PUT'
    #      url: "http://localhost:3001/cards/#{_card._id}"
    #      json: _card
    #      headers: {cookie}
    #    request opts, (err, res, card) ->
    #      should.not.exist(err)
    #      res.should.have.property('statusCode', 201)
    #      card.should.have.keys(['_rev', 'mtime'])
    #      for key, val of card
    #        _card[key] = val
    #      done()
