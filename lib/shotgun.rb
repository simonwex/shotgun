def passenger_path
  Gem::all_load_paths.each{|dir| return File.dirname(dir) if dir =~ /\/passenger/}
end

already_retried = false
begin
  require 'eventmachine' 
  require "#{File.dirname(__FILE__)}/case_insensitive_hash"
  require 'evma_httpserver' # eventmachine_httpserver gem
  require 'time'
  require 'passenger/html_template' unless defined?(HTMLTemplate)
  require 'passenger/platform_info' unless defined?(PlatformInfo)
  require 'cgi'
rescue LoadError => load_error
  require 'rubygems'
  $: << passenger_path
  if already_retried
    raise load_error
  else
    already_retried = true
    retry
  end
end

class EventMachine::DelegatedHttpResponse
  alias :send :send_response
end


module Shotgun
  class HTMLTemplate < Passenger::HTMLTemplate
    
    def initialize(template_path, options = {})
  		@buffer = ''
  		# TODO: Implement some caching somewhere, mabe a singleton internal class.
  		@template_dir = File.dirname(template_path)
  		@template = ERB.new(File.read(template_path), nil, nil, '@buffer')
  		options.each_pair do |name, value|
  			self[name] = value
  		end
  	end
  	
  	def layout(template_name, options = {})
  		options.each_pair do |name, value|
  			self[name] = value
  		end
  		
  		layout_template = ERB.new(File.read("#{@template_dir}/#{template_name}.html.erb"))
  		b = get_binding do
  			old_size = @buffer.size
  			yield
  			@buffer.slice!(old_size .. @buffer.size)
  		end
  		@buffer << layout_template.result(b)
  	end
  	def include(filename)
  		return File.read("#{@template_dir}/#{filename}")
  	end
  end
  
  def self.start(options = {}, &block)
    handler_class = options[:handler_class] || options['handler_class']
    if handler_class.nil?
      handler_class = AnonymousHttpRequestHandler
      handler_class.block = block

      handler_class.instance_eval do
        options.each_pair do |name, value|
    			self[name] = value
    		end
    	end
    end
    host = options.delete(:host) || options.delete('host') || "0.0.0.0"
    port = [options.delete(:port).to_i, options.delete('port').to_i, 80].max
    EventMachine::run do
      EventMachine.epoll
      if socket = options.delete(:socket)
        EventMachine::start_unix_domain_server(socket, AnonymousHttpRequestHandler)
        puts "Listening to: #{socket}..."
      else
        EventMachine::start_server(host, port, AnonymousHttpRequestHandler)
        portstr = port == 80 ? '' : ":#{port}"
        puts "Listening to: http://#{host}#{portstr}..."
      end
      
    end
  end
  
  class Logger
    def call(request)
      (Kernel.const_defined?('LOGOUT') ? LOGOUT : STDOUT).puts("#{request.method} #{request.uri}?#{request.query_string} #{Time.now.httpdate}")
    end
  end
  
  class HTTPRequestHandler < EventMachine::Connection
    
    include EventMachine::HttpServer
    
    def self.start(options = {})
      Shotgun.start(options, self)
    end
    
    def self.server_asset_dir
      @server_asset_dir = File.expand_path("#{File.dirname(__FILE__)}/../assets/")
    end

    class << self
      attr_accessor :logger, :app_name, :template_dir
    end
    
  	def self.[]=(name, value)
  		instance_variable_set("@#{name}".to_sym, value)
  		return self
  	end
    

    def self.logger
      return @logger if @logger
      @logger = Shotgun::Logger.new
    end
    
    attr_reader :http_content_type, 
                :http_cookie, 
                :http_headers, 
                :http_if_none_match, 
                :http_path_info, 
                :http_post_content, 
                :http_protocol, 
                :http_query_string, 
                :http_request_method, 
                :http_request_uri, 
                :signature,
                :request,
                :response
  
  
    class Request
      def initialize(handler)
        @handler = handler
      end

      def uri
        @handler.http_request_uri
      end

      def method
        @handler.http_request_method
      end
      
      def post_content
        @handler.http_post_content
      end
      
      def query_string
        @handler.http_query_string
      end

      def params
        if @params.nil?
          @params = {}
          data = @handler.http_query_string.split('&')
          
          if method == 'POST' && @handler.http_content_type == 'application/x-www-form-urlencoded'
            data += @handler.http_post_content.split('&')
          end

          if data
            pairs = data.map{|pair| pair.split('=').map{|s| CGI.unescape(s)}}
            
            pairs.each do |pair|
              key = pair[0].to_sym
              if @params.has_key?(key)
                @params[key] = [@params[key], pair[1]].flatten
              else
                @params[key] = pair[1]
              end
            end
          end
        end
        @params
      end
      
      def headers
        @headers ||= CaseInsensitiveHash[*@handler.http_headers.split("\000").map do |header|
          header.split(': ')
        end.flatten]
      end
    end
    
    def render(template_path, options = {})
      begin
      	response.content = HTMLTemplate.new("#{self.class.template_dir}/#{template_path}", options).result
      	response.send
      rescue Errno::ENOENT
        response.status = 404
        if File.exist?("#{self.class.template_dir}/404.html")
          response.content = File.read("#{self.class.template_dir}/404.html")
        	response.send
        elsif File.exist?("#{self.class.template_dir}/404.html.erb")
          render("404.html.erb")
        else
          response.content = HTMLTemplate.new("#{self.class.server_asset_dir}/404.html.erb", :path => "#{self.class.template_dir}/#{template_path}").result
          response.send
        end
      end
    end
    
    def render_error(options)
    	response.content = HTMLTemplate.new("#{self.class.server_asset_dir}/error.html.erb", options).result
    	response.send
    end
    
    def handle
      response.content = "I CAN HAS SOMETHING MORE USEFUL TO DO?"
    end
 
    def process_http_request
      @request = Request.new(self)
      @response = EventMachine::DelegatedHttpResponse.new(self)
      
      self.class.logger.call(@request)
      
      @response.status = 200
      @response.headers["Content-type"] = 'text/html'
      begin
        handle
      rescue Exception => e
        puts(e)
        puts("  #{e.backtrace.join("\n  ")}")
        @response.status = 500
        @response.content = "An error occured\n#{e.message}\n#{e.backtrace.join("\n")}"
        send_error_page('error', :error => e, :app_name => self.class.app_name || self.class.name)
      end
      
    end
    
    def send_error_page(template_name, options = {})
    	@response.status = 500
    	render_error(options)
    end
  end
  
  class AnonymousHttpRequestHandler < HTTPRequestHandler
    @block
    def self.block=(block)
      @block = block
    end
    def self.block
      @block
    end
    def handle
      self.instance_eval(&self.class.block)
    end
  end

end