user = 'hedwig'
if process.env.PROD then pwd = process.env.HEDWIG_PWD
else pwd = 'hedwig'
credentials = {user,pwd}
{nano} = require('../../config')
db = nano.db.use('lifeswap')

describe 'adminNotifications', () ->

