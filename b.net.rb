
require 'curb'
require_relative 'b.log.rb'

module N
  class Error < StandardError
    attr_accessor :sample
    def initialize message, sample:nil
      @sample = sample
      super message
    end
  end

  DEFAULT_TIMEOUT   = 600
  DEFAULT_TRY       = 5
  DEFAULT_INTERVAL  = 5

  def self.get(
    url,
    referer:  nil,
    agent:    nil,
    cookie:   nil,
    timeout:  DEFAULT_TIMEOUT,
    try:      DEFAULT_TRY,
    interval: DEFAULT_INTERVAL,
    log:      Log.new(STDERR)
  )
    counter = 0
    exception = nil
    begin
      counter += 1
      if try < counter
        exception = N::Error.new "try limit (#{try}) reached"
      else
        result = self.get_onetime(url,
                                  referer: referer,
                                  agent:   agent,
                                  cookie:  cookie,
                                  timeout: timeout
                                 )
      end
    rescue N::Error => e
      log.e %Q`"#{url}" returns "#{e.sample.response_code}"`
      s = interval.to_f
      sleep s
      retry
    rescue Curl::Err::TimeoutError
      log.e "connection timeout (#{timeout}sec) #{url}"
      retry
    end
    raise exception unless exception.nil?
    return result
  end

  def self.get_onetime(
    url,
    referer: nil,
    agent:   nil,
    cookie:  nil,
    timeout: DEFAULT_TIMEOUT
  )
    # result is_instance_of Curl::Easy
    result = Curl.get url do |x|
      x.connect_timeout = timeout
      x.follow_location = true
      x.max_redirects = 10
      unless cookie.nil?
        x.enable_cookies = true
        x.cookie = cookie
        x.cookiejar  = cookie
      end
      x.headers["Referer"]    = referer unless referer.nil?
      x.headers["User-Agent"] = agent   unless agent.nil?
    end

    if result.response_code == 200
      return result.body
    else
      raise N::Error.new('code is not 200', sample:result)
    end
  end
end
