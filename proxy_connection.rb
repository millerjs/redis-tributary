class ProxyConnection
  def initialize(client)
    puts 'Connect received.'
    @client = client
  end

  def readlines(&block)
    while (line = @client.gets)
      puts "received: #{line.strip}"
      yield(line)
    end
  end

  def proxy_to_downstream(upstream)
    Thread.new do
      while (response = upstream.gets)
        @client.puts(response)
      end
    end
  end
end
