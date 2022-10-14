require 'matrix'

class TimestampVector < Vector
  def increment(index)
    self[index] += 1
  end

  def <(other)
    each2(other).all? { |a, b| a < b }
  end

  def >(other)
    each2(other).all? { |a, b| a > b }
  end

  def ==(other)
    each2(other).all? { |a, b| a == b }
  end

  def |(other)
    !(self == other || self > other || self < other)
  end
end

class VectorClock
  def initialize(node_index, node_count)
    @node_index = node_index
    @node_count = node_count
    @timestamps = TimestampVector.zero(node_count)
  end

  def receive(other_timestamps)
    merge(other_timestamps)
    increment
  end

  def increment
    @timestamps.increment(@node_index)
  end

  def merge(other_timestamps)
    @node_index.times.each do |i|
      @timestamps[i] = [@timestamps[i], other_timestamps[i]].max
    end
  end
end

TimestampVector.zero(4) < TimestampVector.zero(4)
TimestampVector.zero(4) == TimestampVector.zero(4)
TimestampVector.zero(4) > TimestampVector.zero(4)
