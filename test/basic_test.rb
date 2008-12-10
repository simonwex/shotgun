require 'test/unit'

$: << "#{File.dirname(__FILE__)}/../lib"

require 'rubygems'
require 'shotgun'
require 'net/http'

class BasicTest < Test::Unit::TestCase
  
  def test_stuff
    if server_process = fork
      begin
        sleep 1
        url = URI.parse('http://0.0.0.0:3000/')
        req = Net::HTTP::Get.new(url.path)
        assert_equal("Hello from a block", Net::HTTP.start(url.host, url.port) {|http|
          http.request(req)
        }.body)
        puts "server_process: #{server_process}"
      ensure
        Process.kill(9, server_process)
        Process.wait
      end
    else
      Shotgun.start(:port => 3000) do |request, response|
        response.content = "Hello from a block"
        response.send_response
      end
    end
  end
  

  def test_error
    if server_process = fork
      begin
        sleep 1
        url = URI.parse('http://0.0.0.0:3000/')
        req = Net::HTTP::Get.new(url.path)
        body = Net::HTTP.start(url.host, url.port) {|http|
          http.request(req)
        }.body
      
        assert(body =~ /Crap 12334/)

        puts "server_process: #{server_process}"
      ensure
        Process.kill(9, server_process)
        Process.wait
      end
      
    else
      Shotgun.start(:port => 3000) do |request, response|
        raise "Crap 12334"
      end
    end
  end
end
