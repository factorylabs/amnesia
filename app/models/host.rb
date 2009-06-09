class Host
  include DataMapper::Resource
  
  property :id, Serial
  property :hostname, String
  property :port, String
  property :username, String
  property :password, String
  
  def alive? 
    return true
  end
  
  def method_missing(method, *args)
    return stats[method.to_s] if stats.has_key? method.to_s
  end
  
  def stats
    processed_stats || {}
  end
  
  private
  
  def raw_remote_stats
    result = ''
    Net::SSH.start(self.hostname, self.username, :password => self.password, :port => self.port) do |ssh|
      result = ssh.exec!("/usr/bin/memcached-tool 127.0.0.1:11211 stats")
    end
    result
  end
  
  def processed_stats
    stats = {}
    raw_remote_stats.each_line do |line|
      next if line =~ /#/
      match = /(\S+)(?:\s+)(\S+)/.match(line)
      
      name  = match[1]
      value = match[2]
      
      stats[name] = case name
                    when 'version'
                      value
                    when 'rusage_user', 'rusage_system' then
                      seconds, microseconds = value.split(/:/, 2)
                      microseconds ||= 0
                      Float(seconds) + (Float(microseconds) / 1_000_000)
                    else
                      if value =~ /\A\d+\Z/ then
                        value.to_i
                      else
                        value
                      end
                    end
    end
    stats
  end
  
end
