require 'faye/websocket'
require 'thread'
require 'redis'
require 'json'
require 'erb'

module Chat
  class Server
    KEEPALIVE_TIME = 2000 # in seconds
    CHANNEL        = "chat-room1"

    def initialize(app)
      @app     = app
      @clients = []
      uri = URI.parse('localhost')
      @redis = Redis.new(host: uri.host, port: uri.port)
      Thread.new do
        redis_sub = Redis.new(host: uri.host)
        redis_sub.subscribe(CHANNEL) do |on|
          on.message do |channel, msg|
            @clients.each {|ws| ws.send(msg) }
          end
        end
      end
    end

    def call(env)
      if Faye::WebSocket.websocket?(env)
        ws = Faye::WebSocket.new(env, nil, { ping: KEEPALIVE_TIME })
        ws.on :open do |event|
          p [:open, ws.object_id]
          @clients << ws
        end

        ws.on :message do |event|
          p [:message, event.data]
          @redis.publish(CHANNEL, sanitize(event.data))
        end

        ws.on :close do |event|
          p [:close, ws.object_id, event.code, event.reason]
          @clients.delete(ws)
          ws = nil
        end

        # Return async Rack response
        ws.rack_response

      else
        @app.call(env)
      end
    end

    private
    def sanitize(message)
      json = JSON.parse(message)
      json.each {|key, value| json[key] = ERB::Util.html_escape(value) }
      JSON.generate(json)
    end
  end
end
