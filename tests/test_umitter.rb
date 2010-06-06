require 'test/unit'
require 'umitter'

class TC_Umitter < Test::Unit::TestCase
  def setup
    @umitter = Umitter.new
  end

  def test_twitter_write
    res = nil
    assert_nothing_raised do
      @umitter.twitter_write("てすとー#{Time.now}")
    end
    puts res.class
    assert_equal(200, res)
  end
end
