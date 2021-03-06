OldValue = require('../lib/autoprefixer/old-value')

describe 'OldValue', ->

  describe '.check()', ->

    it 'checks value in string', ->
      old = new OldValue('-o-calc')
      old.check('1px -o-calc(1px)').should.be.true
      old.check('1px calc(1px)').should.be.false

    it 'allows custom checks', ->
      old = new OldValue('-o-calc', 'calc', /calc/)
      old.check('1px calc(1px)').should.be.true
