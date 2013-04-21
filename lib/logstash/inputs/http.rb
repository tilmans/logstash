require 'logstash/inputs/base'
require 'logstash/namespace'
require 'logstash/util/socket_peer'
require 'webrick'

# Receive events via HTTP POST
#
# Like stdin and file inputs, each event is assumed to be one line of text.
class LogStash::Inputs::HTTP < LogStash::Inputs::Base
  class Interrupted < StandardError;
  end
  config_name 'http'
  plugin_status 'beta'

  config :host, :validate => :string, :default => "0.0.0.0"

  config :port, :validate => :number, :required => true

  def initialize(*args)
    super(*args)
  end

  def register
    require 'webrick'
    @server = WEBrick::HTTPServer.new :Port => @port, :BindAddress => @host
    trap('INT') { server.stop }
  end

  public
  def run(output_queue)
    @server.mount '/', LogHandle, output_queue, self, @logger
    @server.start
    @server.unmount '/'
  end

  def teardown
    @server.stop
  end

# def teardown

  def to_event(line, tags)
    event = super line, 'HTTP'
    event.tags = tags
    event
  end

  class LogHandle < WEBrick::HTTPServlet::AbstractServlet
    def initialize(server, output_queue, logstash, logger)
      super server
      @output_queue = output_queue
      @logstash = logstash
      @logger = logger
    end

    def do_POST(req, res)
      tags = req['tags'].split ','
      res.body << "Tags: #{tags}\n"
      lines = 0
      req.body.each_line do |line|
        @output_queue << @logstash.to_event(line, tags)
        lines += 1
      end
      res.body << "Lines: #{lines}\n"
      @logger.debug "HTTP Input: Added #{lines} lines with tags #{tags}"
    end
  end
end

