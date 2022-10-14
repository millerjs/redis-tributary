def parse_args
  options = {
    tributary_args: {
      redis_host: '127.0.0.1',
      redis_port: 6379,
    }
  }

  required = [
    :node_id,
    :node_count,
    :tributary_hosts,
    :tributary_ports
  ]

  OptionParser.new do |opts|
    opts.banner = 'Usage: [options]'

    opts.on('-hHOST', '--redis-host=HOST') do |v|
      options[:tributary_args][:redis_host] = v
    end

    opts.on('-pPORTS', '--redis-port=PORT') do |v|
      options[:tributary_args][:redis_port] = v.to_i
    end

    opts.on('-iID', '--node-id=ID') do |v|
      options[:node_id] = v.to_i
    end

    opts.on('-nCOUNT', '--node-count=COUNT') do |v|
      options[:node_count] = v.to_i
    end

    opts.on('--tributary-hosts=hosts') do |v|
      options[:tributary_hosts] = v.split(',')
    end

    opts.on('--tributary-ports=ports') do |v|
      options[:tributary_ports] = v.split(',')
    end
  end.parse!

  required.each do |key|
    unless options[key]
      puts "Missing required argument: #{key}"
      exit
    end
  end

  puts 'Options:', options
  options
end
