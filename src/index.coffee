Kefir = require 'kefir'

# Connect to the Socket.io server

# socket = io.connect(socketio_base_url or null)
socket = io.connect()
exports.socket = socket

# Call a remote service's method

exports.remote = (service, method, args..., cb) ->
    socket.emit 'remote', service, method, args..., cb

# Kefir version

exports.remote$ = (service, method, args...) ->
    Kefir.stream (emitter) ->
        exports.remote service, method, args..., (err, result) ->
            if err
                emitter.error(err)
            else
                emitter.emit(result)
            emitter.end()

# Subscribe to a service's events

subscriptions = {}
exports.subscribe = (service, type, args..., cb) ->
    subscriptions[service] ||= {}
    subscriptions[service][type] ||= []
    subscriptions[service][type].push cb
    socket.emit 'subscribe', service, type, args...

exports.unsubscribe = (service, type) ->
    socket.emit 'unsubscribe', service, type

# Kefir version

exports.subscribe$ = (service, type, args...) ->
    Kefir.stream (emitter) ->
        exports.subscribe service, type, args..., (result) ->
            emitter.emit(result)

# Handle published events

socket.on 'event', (service, type, event) ->
    if cbs = subscriptions[service]?[type]
        try
            cbs.map (cb) -> cb event
        catch e
            console.error "[socket.on event] #{service} #{type} Error:", e.stack
    else
        console.log "[socket.on event] No such subscription #{service} #{type}"

# Resubscribe when reconnecting

first_connect = true

reSubscribe = ->
    # Prevent re-connecting on initial load
    return if first_connect
    # Re-connect known subscriptions
    for service, types of subscriptions
        for type, fns of types
            socket.emit 'subscribe', service, type

# Without auth
# hello -> hello, subscribes immediately
# ------------------------------------------------------------------------------

didConnect = ->
    console.log '[didConnect] Connected...'
    socket.emit 'hello'
    reSubscribe()
    first_connect = false

exports.connect = (cb) ->
    socket.on 'hello', didConnect

# With auth
# hello -> hello -> welcome(user), subscribes after welcome
# ------------------------------------------------------------------------------

didConnectAuth = (token) -> ->
    console.log '[didConnectAuthenticate] Connected...'
    socket.emit 'hello', token

didAuthenticate = (cb) -> (user) ->
    console.log '[didAuthenticate] Authenticated as', user
    if first_connect
        cb(null, user)
    reSubscribe()
    first_connect = false

exports.authenticate = (token, cb) ->
    socket.on 'hello', didConnectAuth token
    socket.on 'welcome', didAuthenticate cb

