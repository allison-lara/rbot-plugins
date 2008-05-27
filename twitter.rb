require 'open-uri'

class TwitterPlugin < Plugin
  Irc::Bot::Config.register Irc::Bot::Config::StringValue.new("twitter.password", 
    :default => false, 
    :desc => "Password for bot's Twitter account")
  Irc::Bot::Config.register Irc::Bot::Config::StringValue.new("twitter.login",
    :default => false,
    :desc => "Username or email for bot's Twitter account")
  
  def initialize
    super
  end
  
  def status(m, params)
    user = params[:name]
    login = @bot.config['twitter.login']
    password = @bot.config['twitter.password']
    
    uri = "http://twitter.com/users/show/#{user}.xml"
    content = ""
    begin
      content = open(uri, :http_basic_authentication => [login, password] ).read
    rescue OpenURI::HTTPError => e
      case e.message
      when /^404/
        m.reply "#{user} does not exist" and return
      when /^401/
        m.reply "I can't read #{user}'s updates" and return
      end
    end
    doc = Hpricot.XML(content)
    u = (doc/:name).text
    s = (doc/:status/:text).text
    m.reply "#{s} (#{u})"
  end
end

plugin = TwitterPlugin.new
plugin.map "what is :name doing?", :action => "status"
