require('dripcap/type')
{EventEmitter} = require('events')
Packet = require('dripcap/packet')
net = require('net')
temp = require('temp')
msgpack = require('msgcap')
remote = require('remote')
BrowserWindow = remote.require('browser-window')

class Session extends EventEmitter
  constructor: (@_filterPath) ->
    sock = temp.path(suffix: '.sock')

    @_window = new BrowserWindow(show: false)
    @_window.loadURL 'file://' + __dirname + '/session.html'

    @_loaded = new Promise (res) =>
      @_window.webContents.once 'did-finish-load', -> res()
    .then =>
      new Promise (res) =>
        @_server = net.createServer (c) =>
          @_msgenc = new msgpack.Encoder(c)
          @_msgdec = new msgpack.Decoder(c)
          @_msgdec.on 'data', (packet) =>
            @emit 'packet', new Packet packet
          res()
        @_server.listen sock
        arg = JSON.stringify @_filterPath
        @_window.webContents.executeJavaScript("session.filterPath = #{arg}")
        arg = JSON.stringify sock
        @_window.webContents.executeJavaScript("session.connect(#{arg})")

  addCapture: (iface, options = {}) ->
    @_loaded.then =>
      settings = {iface: iface, options: options}
      arg = JSON.stringify settings
      @_window.webContents.executeJavaScript("session.capture(#{arg})")
      dripcap.pubsub.pub 'core:capturing-settings', settings

  addDecoder: (decoder) ->
    @_loaded.then =>
      arg = JSON.stringify decoder
      @_window.webContents.executeJavaScript("session.load(#{arg})")

  decode: (packet) ->
    @_loaded.then =>
      @_msgenc.encode packet

  start: ->
    @_loaded.then =>
      @_window.webContents.executeJavaScript('session.stop()')
      @_window.webContents.executeJavaScript('session.start()')
      dripcap.pubsub.pub 'core:capturing-status', true

  stop: ->
    @_loaded.then =>
      @_window.webContents.executeJavaScript('session.stop()')
      dripcap.pubsub.pub 'core:capturing-status', false

  close: ->
    @_loaded.then =>
      @_server.close()
      @_window.close()

module.exports = Session