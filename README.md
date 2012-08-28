replicant
=========

```
ReplicateSwapEvent swapEventId, session
  This service triggers replications between users databases
  @todo rename
  @possibleName Replicant
  @param swapEventId {string} id of swap event to filter on
  @param session {cookie} authenicates user

  ids = GET /mapper/swapEventId
  src = getIdFromSession()
  ids.each (dst) -
    replicate src, dst, filter(swapEventId)

CreateEvent swapId, session
  This service creates a swapEventId and initializes involed users 
  @todo rename
  @param swapId {string} swap for which swapEvent is being created
  @param session {cookie} authenicates user

  hosts = GET /lifeswap/swapId
  guest = getIdFromSession()
  swapEventId = POST /mapper {guest,hosts}
  return swapEventId

CreateUser session
  This creates a user database and preliminary doc after user signups on client
  using user.signup and session.login on client
  @param session {cookie} authenicates user
  @method POST /user

  userId = getIdFromSession()
  POST / userId # creates users database
  POST /userId {firstname, lastname, ...}
  replicate /userId /lifeswap filter(public)

clientSignup
  This calls to the server signup to create user db for new user

  POST /_users    # handled by 'users' package
  POST /_session  # login handled by 'session' package
  POST /Signup cookie   # for server to create user db

clientCreateUser swapId
  Creates swapEventId and writes preliminary documents
  @param swapId {string} swap for which swapEvent is being created

  swapEventId = Creator(swapId, session)
  doc = createPriminaryDoc(swapId)
  clientMessage(swapEventId, doc)

clientMessage swapEventId, doc
  Writes document to user's database in the context of swapEvent to shared
  @param swapEventId {string} unique id for swapEvent
  @param doc {Object.<string, >} document to share

  userId = getIdFromSession()
  POST /userId {swapEventId, doc}
  Replicator(swapEventId)
```
