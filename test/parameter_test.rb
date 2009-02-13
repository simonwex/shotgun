require 'test/unit'

$: << "#{File.dirname(__FILE__)}/../lib"

require 'rubygems'
require 'shotgun'
require 'net/http'

class ParameterTest < Test::Unit::TestCase
  
  def test_stacking_of_multiple_key
    if server_process = fork
      begin
        sleep 1

        req = Net::HTTP::Get.new('/asdf?tag=the_first&tag=the_second')
        assert_equal("the_first\nthe_second", Net::HTTP.start("0.0.0.0", 3000) {|http|
          http.request(req)
        }.body)
        puts "server_process: #{server_process}"
      ensure
        Process.kill(9, server_process)
        Process.wait
      end
    else
      Shotgun.start(:port => 3000) do 
        response.content = request.params[:tag].join("\n")
        response.send_response
      end
    end
  end
  
end
