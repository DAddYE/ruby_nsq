module NSQ
	class Error < StandardError
		Invalid    = Class.new(self)
		BadTopic   = Class.new(self)
		BadMessage = Class.new(self)
		PutFailed  = Class.new(self)
	end
end
