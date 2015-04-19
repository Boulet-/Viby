# -*- coding: utf-8 -*-
class Ack
  include Cinch::Plugin

  match /ack (.+) (.+) (?:.+)/i 
  set :help => '!ack <host> <service> [ack_comment]' 

#  def initialize(*args)
#    super
#  end

  def execute m, host, service, comment
    comment = 'ack' if comment.nil?
    
    m.reply("Service #{service} on #{host} is acked by #{m} : #{comment}")
  end
end
