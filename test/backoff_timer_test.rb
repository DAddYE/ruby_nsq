require 'minitest/autorun'
require 'nsq/backoff_timer'

describe ::NSQ::BackoffTimer do
  before do
    @timer = ::NSQ::BackoffTimer.new(0.1, 120, 0.25, 10, 1000)
  end

  describe "" do
    it "should return the proper interval on successes and failures" do
      assert_equal '%0.4f' % @timer.interval, '0.1000', @timer.inspect
      @timer.success
      assert_equal '%0.4f' % @timer.interval, '0.1000', @timer.inspect
      @timer.failure
      assert_equal '%0.2f' % @timer.interval, '3.19', @timer.inspect
      assert_equal '%0.4f' % @timer.min_interval, '0.1000', @timer.inspect
      assert_equal '%0.4f' % @timer.short_interval, '2.9975', @timer.inspect
      assert_equal '%0.6f' % @timer.long_interval, '0.089925', @timer.inspect
      @timer.failure
      assert_equal '%0.2f' % @timer.interval, '6.27', @timer.inspect
      @timer.success
      assert_equal '%0.2f' % @timer.interval, '3.19', @timer.inspect
      25.times { @timer.failure }
      assert_equal '%0.2f' % @timer.interval, '32.41', @timer.inspect
    end
  end
end
