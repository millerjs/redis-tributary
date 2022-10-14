class RedisCommandBuffer
  def initialize
    reset
  end

  def push(token)
    reset if complete?

    if @arg_count.nil?
      start_command(token)
    elsif @arg_length.nil?
      start_arg(token)
    else
      fill_arg(token)
      next_arg
    end
  end

  def command
    @args[0]
  end

  def arguments
    @args[1..]
  end

  def complete?
    @arg_count == @args.length
  end

  private

  def fill_arg(token)
    @args << token.slice(0, @arg_length)
  end

  def start_arg(token)
    _, length = token.split('$')
    raise 'malformed arg' if length.nil?

    @arg_length = length.strip.to_i
  end

  def start_command(token)
    _, length = token.split('*')
    raise 'malformed comand' if length.nil?

    @arg_count = length.strip.to_i
  end

  def reset
    next_command
    next_arg
  end

  def next_command
    @arg_count = nil
    @args = []
  end

  def next_arg
    @arg_length = nil
  end
end
