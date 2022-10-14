def parse_args
  options = {
    tributary_args: {
      redis_host: '127.0.0.1',
      redis_port: 6379,
    }
  }

  OptionParser.new do |opts|
    opts.banner = 'Usage: [options]'

    opts.on('-hHOST', '--redis-host=HOST', String, 'redis-host') do |v|
      options[:tributary_args][:redis_host] = v
    end

    opts.on('-pPORTS', '--redis-port=PORT', Integer, 'redis-port') do |v|
      options[:tributary_args][:redis_port] = v
    end

    opts.on('-iID', '--node-id=ID', 'node-id') do |v|
      options[:node_id] = v
    end

    opts.on('-nCOUNT', '--node-count=COUNT', Integer, 'node-count') do |v|
      options[:node_count] = v
    end
  end.parse!

  puts 'Options:', options
  options
end
