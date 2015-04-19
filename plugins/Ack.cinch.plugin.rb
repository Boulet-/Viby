# -*- coding: utf-8 -*-
class Ack
  include Cinch::Plugin

  match /ack(?: )?(add|rm|remove|list|help)?(?: )?([^ ]+)?(?: )?([^ ]+)?(?: (.*))?/i 
  set :help => '!ack <add|rm|remove|list> <host> [service] [ack_comment]. Use % as wildcard. !ack help for more informations.' 

  def initialize(*args)
    super
    @user = config['user']
    @password = config['password']
  end

  def execute(m, action, host, service, comment)
    debug("Action #{action}")
    debug("Host #{host}")
    debug("service #{service}")
    return short_help(m) if host.nil? and action != "help"

    case action
    when "help"
      return help(m)
    when "list"
      service = '%' if service.nil?
      acks = search_acks(host,service)

      if acks.empty?
        m.reply("#{m.user.nick}: 0 ack found.")
      elsif acks.length < 6
        m.reply("#{m.user.nick}: List of acks matching:")
        acks.each{|a|
          m.reply("- #{a[:host]} - #{a[:service]}")
        }
      else
        m.user.send("List of acks matching:")
        acks.each{|a|
          m.user.send("- #{a[:host]} - #{a[:service]}")
        }  
      end                                                 
    when "remove","rm"                                  
      return short_help(m) if service.nil?
      acks = search_acks(host,service)
      if acks.empty?
        m.reply("#{m.user.nick}: 0 ack found.")
      else
        acks.each{|a|
          remove_ack(a[:host],a[:service])
        }
        m.reply("#{m.user.nick}: Acks [#{acks.map{|a| a[:service]}.join(',')}] on #{host} will be removed soon.")
      end
    else
      return short_help(m) if service.nil?
      comment = 'ack from IRC' if comment.nil?
      host.downcase!

      if service =~ /%/
        alerts = search_alerts(host, service)

        if alerts.empty?
          m.reply("#{m.user.nick}: 0 alert found.")
        else
          alerts.each{|a|
            ack(a[:host],a[:service],m.user.nick, comment)
          }
          m.reply("#{m.user.nick}: [#{alerts.map{|a| a[:service]}.join(',')}] on #{host} will be acked soon.")
        end
      else
        service.upcase!
        ack(host, service, m.user.nick, comment)
        m.reply("#{m.user.nick}: I'll try to ack : #{service} on #{host}.")
      end
    end
  end

  def search_alerts host, service
    return search('alerts', host, service)
  end

  def search_acks host, service
    return search('ack', host, service)
  end


  def search type, host, service
    if type == 'ack'
      options = 'serviceprops=4'
    elsif type == 'alerts'
      options = 'servicestatustypes=28'
    else
      error("type unknown")
      exit
    end
    a = []
    `curl  -u #{@user}:#{@password} -k 'https://nagios2.typhon.net/cgi-bin/nagios3/status.cgi?host=all&#{options}' 2>/dev/null`.split("\n").each { |line|
      if line =~ /^<TD ALIGN=LEFT valign=center CLASS='statusBG([^']+)'><A HREF='extinfo.cgi\?type=2\&host=([^\&]+)\&service=([^']+)'/
        a << {:host=> $2, :service=> $3}
      end
    }
    host.gsub!(/%/,'.*')
    service.gsub!(/%/,'.*')
    return a.select{|a| a[:host] =~ /^#{host}$/ and a[:service] =~ /^#{service}$/}
  end

  def short_help m
    m.reply("!ack <add|rm|remove|list> <host> [service] [ack_comment]. Use % as wildcard. !ack help for more informations.")
  end

  def help m
    m.user.send("!ack <add|rm|remove|list> <host> [service] [ack_comment]. Use % as wildcard")
    m.user.send("Usage:")
    m.user.send("!ack add <host> <service> [ack_comment]")
    m.user.send("!ack (rm|remove) <host> <service>")
    m.user.send("!ack list <host> [service]")
    m.user.send("")
    m.user.send("Examples: !ack nagios2 ABEL  or  !ack list %tea (list of ack on %tea)  or  !ack rm lb1 % (remove all acks on lb1)")
  end

  def ack host, service, user, comment
    comment += " - By #{user}"
    `curl -u #{@user}:#{@password} -k 'https://nagios2.typhon.net/cgi-bin/nagios3/cmd.cgi?cmd_mod=2&btnSubmit=Commit&send_notification=1&sticky_ack=1&cmd_typ=34&host=#{host}&service=#{service}&com_data=#{URI.escape(comment)}'`
    #`/usr/bin/printf '[%lu] ACKNOWLEDGE_SVC_PROBLEM;#{host};#{service};2;1;0;#{user};#{comment}\n' $(date +%s) >> /tmp/jeremy.log`
  end

  def remove_ack host, service
    `curl -u #{@user}:#{@password} -k 'https://nagios2.typhon.net/cgi-bin/nagios3/cmd.cgi?cmd_mod=2&btnSubmit=Commit&send_notification=1&sticky_ack=1&cmd_typ=52&host=#{host}&service=#{service}'`
  end
end
